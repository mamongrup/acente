BEGIN;
CREATE TABLE IF NOT EXISTS agency.customer_phone_outbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
 user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE, challenge_id uuid NOT NULL REFERENCES agency.customer_auth_challenges(id) ON DELETE CASCADE,
 phone text NOT NULL, code text NOT NULL, status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','sending','sent','failed','expired')),
 attempts integer NOT NULL DEFAULT 0, next_attempt_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), error_code text NOT NULL DEFAULT ''
);
REVOKE ALL ON agency.customer_phone_outbox FROM PUBLIC,agency_app;
CREATE OR REPLACE FUNCTION agency.customer_phone_claim()
RETURNS TABLE(job_id text,tenant text,phone text,code text,phone_id text,token_sealed text,template text,language text,api_version text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$ BEGIN
 UPDATE agency.customer_phone_outbox o SET status='expired',code='',updated_at=now() FROM agency.customer_auth_challenges c WHERE c.id=o.challenge_id AND o.status IN ('queued','sending') AND (c.expires_at<=now() OR c.consumed_at IS NOT NULL);
 RETURN QUERY WITH picked AS (SELECT o.id FROM agency.customer_phone_outbox o WHERE (o.status='queued' OR (o.status='sending' AND o.updated_at<now()-interval '2 minutes')) AND o.next_attempt_at<=now() ORDER BY o.next_attempt_at LIMIT 5 FOR UPDATE SKIP LOCKED), claimed AS (UPDATE agency.customer_phone_outbox o SET status='sending',attempts=o.attempts+1,updated_at=now() FROM picked WHERE o.id=picked.id RETURNING o.*)
 SELECT o.id::text,o.tenant_id::text,o.phone,o.code,coalesce(i.credentials->>'whatsapp_phone_id',''),coalesce(i.credentials->>'whatsapp_token_sealed',''),coalesce((SELECT value#>>'{}' FROM agency.settings WHERE tenant_id=o.tenant_id AND key='whatsapp_auth_template'),''),coalesce((SELECT value#>>'{}' FROM agency.settings WHERE tenant_id=o.tenant_id AND key='whatsapp_auth_language'),''),coalesce((SELECT value#>>'{}' FROM agency.settings WHERE tenant_id=o.tenant_id AND key='whatsapp_api_version'),'') FROM claimed o LEFT JOIN agency.integrations i ON i.tenant_id=o.tenant_id AND i.provider='sms_whatsapp' AND i.kind='notification' AND i.active;
 END $$;
CREATE OR REPLACE FUNCTION agency.customer_phone_finish(p_id uuid,p_result text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$ BEGIN
 UPDATE agency.customer_phone_outbox SET status=CASE WHEN p_result='sent' THEN 'sent' WHEN p_result='retry' AND attempts<3 THEN 'queued' ELSE 'failed' END,
 code=CASE WHEN p_result='sent' OR p_result<>'retry' OR attempts>=3 THEN '' ELSE code END,
 error_code=CASE WHEN p_result='sent' THEN '' WHEN p_result='retry' THEN 'temporary_provider_error' ELSE 'provider_error' END,
 next_attempt_at=now()+interval '1 minute',updated_at=now() WHERE id=p_id AND status='sending';
 END $$;
REVOKE ALL ON FUNCTION agency.customer_phone_claim(),agency.customer_phone_finish(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.customer_phone_claim(),agency.customer_phone_finish(uuid,text) TO agency_app;
CREATE OR REPLACE FUNCTION agency.customer_auth_request(p_tenant uuid,p_email text,p_purpose text,p_channel text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$
DECLARE u agency.users%ROWTYPE; code text; v agency.customer_verification%ROWTYPE; challenge uuid;
BEGIN
 IF p_purpose NOT IN ('email','phone','reset') OR (p_purpose IN ('email','reset') AND p_channel<>'email') OR (p_purpose='phone' AND p_channel NOT IN ('sms','whatsapp')) THEN RETURN 'invalid'; END IF;
 SELECT * INTO u FROM agency.users WHERE tenant_id=p_tenant AND lower(email)=lower(trim(p_email)) AND membership_type='customer' AND active FOR UPDATE;
 IF NOT FOUND THEN RETURN 'accepted'; END IF;
 SELECT * INTO v FROM agency.customer_verification WHERE user_id=u.id AND tenant_id=p_tenant;
 IF EXISTS(SELECT 1 FROM agency.customer_auth_challenges WHERE user_id=u.id AND purpose=p_purpose AND created_at>now()-interval '1 minute') THEN RETURN 'accepted'; END IF;
 IF (SELECT count(*) FROM agency.customer_auth_challenges WHERE user_id=u.id AND created_at>now()-interval '1 hour')>=10 THEN RETURN 'accepted'; END IF;
 -- Phone providers must be configured before offering their channel.
 IF p_purpose='phone' AND (p_channel<>'whatsapp' OR v.phone !~ '^\+[1-9][0-9]{7,14}$' OR NOT EXISTS(SELECT 1 FROM agency.integrations WHERE tenant_id=p_tenant AND provider='sms_whatsapp' AND kind='notification' AND active AND coalesce(credentials->>'whatsapp_phone_id','') ~ '^[0-9]{5,30}$' AND length(coalesce(credentials->>'whatsapp_token_sealed',''))>0) OR (SELECT count(*) FROM agency.settings WHERE tenant_id=p_tenant AND ((key='whatsapp_auth_template' AND value#>>'{}' ~ '^[a-z0-9_]+$' AND length(value#>>'{}')<=512) OR (key='whatsapp_auth_language' AND value#>>'{}' ~ '^[a-z]{2,3}(_[A-Z]{2})?$') OR (key='whatsapp_api_version' AND value#>>'{}' ~ '^v[0-9]{1,2}\.[0-9]$')))<>3) THEN RETURN 'provider_unavailable'; END IF;
 code:=lpad((get_byte(gen_random_bytes(1),0)*65536+get_byte(gen_random_bytes(1),0)*256+get_byte(gen_random_bytes(1),0))::text,8,'0');
 UPDATE agency.customer_auth_challenges SET consumed_at=now() WHERE user_id=u.id AND purpose=p_purpose AND consumed_at IS NULL;
 INSERT INTO agency.customer_auth_challenges(tenant_id,user_id,purpose,channel,code_hash,expires_at) VALUES(p_tenant,u.id,p_purpose,p_channel,encode(digest(code,'sha256'),'hex'),now()+interval '10 minutes') RETURNING id INTO challenge;
 IF p_purpose='phone' THEN
 INSERT INTO agency.customer_phone_outbox(tenant_id,user_id,challenge_id,phone,code) VALUES(p_tenant,u.id,challenge,v.phone,code);
 RETURN 'accepted';
 END IF;
 INSERT INTO agency.notifications(tenant_id,user_id,channel,template,payload,status) VALUES(p_tenant,u.id,'email','customer.auth.'||p_purpose,jsonb_build_object('to',u.email,'email',u.email,'subject',case when p_purpose='reset' then 'Parola yenileme kodunuz' else 'E-posta doğrulama kodunuz' end,'html','<p>Doğrulama kodunuz: <strong>'||code||'</strong></p><p>Kod 10 dakika geçerlidir. Bu işlemi siz başlatmadıysanız kodu paylaşmayın.</p>'),'queued');
 RETURN 'accepted';
END $$;
CREATE OR REPLACE FUNCTION agency.customer_phone_delivery_state(p_tenant uuid,p_user uuid) RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$ SELECT coalesce((SELECT o.status FROM agency.customer_phone_outbox o JOIN agency.users u ON u.id=o.user_id AND u.tenant_id=o.tenant_id JOIN agency.customer_auth_challenges c ON c.id=o.challenge_id WHERE o.tenant_id=p_tenant AND o.user_id=p_user AND u.membership_type='customer' ORDER BY c.created_at DESC,o.id DESC LIMIT 1),'') $$;
REVOKE ALL ON FUNCTION agency.customer_phone_delivery_state(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.customer_phone_delivery_state(uuid,uuid) TO agency_app;
COMMIT;
