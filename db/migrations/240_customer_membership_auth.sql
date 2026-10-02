BEGIN;
ALTER TABLE agency.customer_verification ADD COLUMN IF NOT EXISTS phone text NOT NULL DEFAULT '';
ALTER TABLE agency.customer_verification ADD COLUMN IF NOT EXISTS registration_email_required boolean NOT NULL DEFAULT false;
CREATE TABLE IF NOT EXISTS agency.customer_auth_challenges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
 user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
 purpose text NOT NULL CHECK(purpose IN ('email','phone','reset')), channel text NOT NULL CHECK(channel IN ('email','sms','whatsapp')),
 code_hash text NOT NULL, expires_at timestamptz NOT NULL, attempts integer NOT NULL DEFAULT 0,
 consumed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS customer_auth_challenge_idx ON agency.customer_auth_challenges(tenant_id,user_id,purpose,created_at DESC);
REVOKE ALL ON agency.customer_auth_challenges FROM PUBLIC,agency_app;
CREATE OR REPLACE FUNCTION agency.customer_auth_request(p_tenant uuid,p_email text,p_purpose text,p_channel text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$
DECLARE u agency.users%ROWTYPE; code text; v agency.customer_verification%ROWTYPE;
BEGIN
 IF p_purpose NOT IN ('email','phone','reset') OR (p_purpose IN ('email','reset') AND p_channel<>'email') OR (p_purpose='phone' AND p_channel NOT IN ('sms','whatsapp')) THEN RETURN 'invalid'; END IF;
 SELECT * INTO u FROM agency.users WHERE tenant_id=p_tenant AND lower(email)=lower(trim(p_email)) AND membership_type='customer' AND active FOR UPDATE;
 IF NOT FOUND THEN RETURN 'accepted'; END IF;
 SELECT * INTO v FROM agency.customer_verification WHERE user_id=u.id AND tenant_id=p_tenant;
 IF EXISTS(SELECT 1 FROM agency.customer_auth_challenges WHERE user_id=u.id AND purpose=p_purpose AND created_at>now()-interval '1 minute') THEN RETURN 'accepted'; END IF;
 IF (SELECT count(*) FROM agency.customer_auth_challenges WHERE user_id=u.id AND created_at>now()-interval '1 hour')>=10 THEN RETURN 'accepted'; END IF;
 -- Phone providers must be configured before offering their channel.
 IF p_purpose='phone' THEN RETURN 'provider_unavailable'; END IF;
 code:=lpad((get_byte(gen_random_bytes(1),0)*65536+get_byte(gen_random_bytes(1),0)*256+get_byte(gen_random_bytes(1),0))::text,8,'0');
 UPDATE agency.customer_auth_challenges SET consumed_at=now() WHERE user_id=u.id AND purpose=p_purpose AND consumed_at IS NULL;
 INSERT INTO agency.customer_auth_challenges(tenant_id,user_id,purpose,channel,code_hash,expires_at) VALUES(p_tenant,u.id,p_purpose,p_channel,encode(digest(code,'sha256'),'hex'),now()+interval '10 minutes');
 INSERT INTO agency.notifications(tenant_id,user_id,channel,template,payload,status) VALUES(p_tenant,u.id,'email','customer.auth.'||p_purpose,jsonb_build_object('to',u.email,'email',u.email,'subject',case when p_purpose='reset' then 'Parola yenileme kodunuz' else 'E-posta doğrulama kodunuz' end,'html','<p>Doğrulama kodunuz: <strong>'||code||'</strong></p><p>Kod 10 dakika geçerlidir. Bu işlemi siz başlatmadıysanız kodu paylaşmayın.</p>'),'queued');
 RETURN 'accepted';
END $$;
CREATE OR REPLACE FUNCTION agency.customer_register(p_tenant uuid,p_name text,p_email text,p_phone text,p_password text,p_terms boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$
DECLARE uid uuid;
BEGIN
 IF (SELECT count(*) FROM agency.settings WHERE tenant_id=p_tenant AND key IN ('contract_membership','contract_privacy_policy') AND length(trim(value#>>'{}'))>20)<2 THEN RETURN 'terms_unavailable'; END IF;
 IF NOT p_terms OR length(trim(p_name)) NOT BETWEEN 3 AND 120 OR length(p_email)>254 OR p_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' OR p_phone !~ '^\+[1-9][0-9]{7,14}$' OR length(p_password) NOT BETWEEN 12 AND 72 OR octet_length(p_password)>72 THEN RETURN 'invalid'; END IF;
 IF (SELECT count(*) FROM agency.users WHERE tenant_id=p_tenant AND membership_type='customer' AND created_at>now()-interval '1 hour')>=100 THEN RETURN 'rate_limited'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext(p_tenant::text||lower(trim(p_email))));
 IF EXISTS(SELECT 1 FROM agency.users WHERE tenant_id=p_tenant AND lower(email)=lower(trim(p_email))) THEN RETURN 'accepted'; END IF;
 INSERT INTO agency.users(tenant_id,email,display_name,membership_type,password_hash) VALUES(p_tenant,lower(trim(p_email)),trim(p_name),'customer',crypt(p_password,gen_salt('bf',12))) RETURNING id INTO uid;
 INSERT INTO agency.customer_verification(user_id,tenant_id,phone,registration_email_required) VALUES(uid,p_tenant,p_phone,true);
 INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata) VALUES(p_tenant,uid,'customer.registered','user',uid,jsonb_build_object('terms_version','2026-10-02','document_hashes',(select jsonb_object_agg(key,encode(digest(value::text,'sha256'),'hex')) from agency.settings where tenant_id=p_tenant and key in ('contract_membership','contract_privacy_policy'))));
 PERFORM agency.customer_auth_request(p_tenant,p_email,'email','email');
 RETURN 'accepted';
END $$;
CREATE OR REPLACE FUNCTION agency.customer_auth_confirm(p_tenant uuid,p_email text,p_purpose text,p_code text,p_password text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth AS $$
DECLARE c agency.customer_auth_challenges%ROWTYPE; uid uuid;
BEGIN
 SELECT id INTO uid FROM agency.users WHERE tenant_id=p_tenant AND lower(email)=lower(trim(p_email)) AND active AND membership_type='customer';
 SELECT * INTO c FROM agency.customer_auth_challenges WHERE tenant_id=p_tenant AND user_id=uid AND purpose=p_purpose AND consumed_at IS NULL ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND OR c.expires_at<=now() OR c.attempts>=5 THEN RETURN 'invalid_code'; END IF;
 IF c.code_hash<>encode(digest(p_code,'sha256'),'hex') THEN UPDATE agency.customer_auth_challenges SET attempts=attempts+1 WHERE id=c.id; RETURN 'invalid_code'; END IF;
 IF p_purpose='reset' AND (length(p_password) NOT BETWEEN 12 AND 72 OR octet_length(p_password)>72) THEN RETURN 'invalid_password'; END IF;
 UPDATE agency.customer_auth_challenges SET consumed_at=now() WHERE id=c.id;
 IF p_purpose='email' THEN UPDATE agency.customer_verification SET email_verified_at=now() WHERE user_id=uid AND tenant_id=p_tenant;
 ELSIF p_purpose='phone' THEN UPDATE agency.customer_verification SET phone_verified_at=now() WHERE user_id=uid AND tenant_id=p_tenant;
 ELSIF p_purpose='reset' THEN
 UPDATE agency.users SET password_hash=crypt(p_password,gen_salt('bf',12)),failed_login_attempts=0,locked_until=NULL WHERE id=uid AND tenant_id=p_tenant;
 DELETE FROM auth.sessions WHERE user_id=uid; DELETE FROM agency_auth.sessions WHERE user_id=uid;
 ELSE RETURN 'invalid'; END IF;
 INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata) VALUES(p_tenant,uid,'customer.auth.'||p_purpose||'.confirmed','user',uid,'{}');
 RETURN 'verified';
END $$;
REVOKE ALL ON FUNCTION agency.customer_register(uuid,text,text,text,text,boolean),agency.customer_auth_request(uuid,text,text,text),agency.customer_auth_confirm(uuid,text,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.customer_register(uuid,text,text,text,text,boolean),agency.customer_auth_request(uuid,text,text,text),agency.customer_auth_confirm(uuid,text,text,text,text) TO agency_app;
COMMIT;
