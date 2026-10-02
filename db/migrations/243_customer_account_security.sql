BEGIN;
CREATE TABLE IF NOT EXISTS agency.membership_request_limits(tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,client_digest text NOT NULL,window_start timestamptz NOT NULL,count integer NOT NULL DEFAULT 0,PRIMARY KEY(tenant_id,client_digest));
REVOKE ALL ON agency.membership_request_limits FROM PUBLIC,agency_app;
CREATE OR REPLACE FUNCTION agency.membership_request_allowed(p_tenant uuid,p_client text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$ DECLARE n integer; BEGIN
 INSERT INTO agency.membership_request_limits VALUES(p_tenant,encode(digest(p_tenant::text||left(p_client,128),'sha256'),'hex'),date_trunc('minute',now()),1)
 ON CONFLICT(tenant_id,client_digest) DO UPDATE SET count=CASE WHEN agency.membership_request_limits.window_start<date_trunc('minute',now()) THEN 1 ELSE agency.membership_request_limits.count+1 END,window_start=date_trunc('minute',now()) RETURNING count INTO n;
 DELETE FROM agency.membership_request_limits WHERE window_start<now()-interval '1 day'; RETURN n<=20; END $$;
CREATE OR REPLACE FUNCTION agency.customer_session_list(p_tenant uuid,p_user uuid,p_token text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth AS $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM agency.users u JOIN auth.sessions s ON s.user_id=u.id WHERE u.tenant_id=p_tenant AND u.id=p_user AND u.membership_type='customer' AND u.active AND s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now()) THEN RETURN '[]'; END IF;
 RETURN (SELECT coalesce(jsonb_agg(jsonb_build_object('id',encode(digest(s.token_digest||p_token,'sha256'),'hex'),'createdAt',s.created_at,'expiresAt',s.expires_at,'current',s.token_digest=encode(digest(p_token,'sha256'),'hex')) ORDER BY s.created_at DESC),'[]') FROM auth.sessions s WHERE s.user_id=p_user AND s.expires_at>now()); END $$;
CREATE OR REPLACE FUNCTION agency.customer_session_revoke(p_tenant uuid,p_user uuid,p_token text,p_id text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth AS $$ DECLARE target text; BEGIN
 IF agency.customer_session_list(p_tenant,p_user,p_token)='[]'::jsonb THEN RETURN 'forbidden'; END IF;
 SELECT token_digest INTO target FROM auth.sessions WHERE user_id=p_user AND encode(digest(token_digest||p_token,'sha256'),'hex')=p_id AND token_digest<>encode(digest(p_token,'sha256'),'hex');
 IF target IS NULL THEN RETURN 'invalid'; END IF;
 DELETE FROM auth.sessions WHERE user_id=p_user AND token_digest=target; DELETE FROM agency_auth.sessions WHERE user_id=p_user AND token_digest=target;
 INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata) VALUES(p_tenant,p_user,'customer.session.revoked','user',p_user,'{}'); RETURN 'revoked'; END $$;
ALTER TABLE agency.customer_auth_challenges DROP CONSTRAINT IF EXISTS customer_auth_challenges_purpose_check;
ALTER TABLE agency.customer_auth_challenges ADD CONSTRAINT customer_auth_challenges_purpose_check CHECK(purpose IN ('email','phone','reset','email_change','phone_change'));
ALTER TABLE agency.customer_auth_challenges ADD COLUMN IF NOT EXISTS target_value text;
CREATE OR REPLACE FUNCTION agency.customer_contact_request(p_tenant uuid,p_user uuid,p_kind text,p_target text,p_password text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$ DECLARE u agency.users%ROWTYPE; code text; cid uuid; result text; old_phone text; BEGIN
 SELECT * INTO u FROM agency.users WHERE id=p_user AND tenant_id=p_tenant AND active AND membership_type='customer' FOR UPDATE;
 IF NOT FOUND OR crypt(p_password,u.password_hash) IS DISTINCT FROM u.password_hash THEN RETURN 'invalid_password'; END IF;
 IF p_kind NOT IN ('email','phone') OR (p_kind='email' AND (length(p_target)>254 OR p_target !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')) OR (p_kind='phone' AND p_target !~ '^\+[1-9][0-9]{7,14}$') THEN RETURN 'invalid'; END IF;
 IF p_kind='email' AND EXISTS(SELECT 1 FROM agency.users WHERE tenant_id=p_tenant AND lower(email)=lower(trim(p_target))) THEN RETURN 'unavailable'; END IF;
 IF EXISTS(SELECT 1 FROM agency.customer_auth_challenges WHERE user_id=p_user AND created_at>now()-interval '1 minute') THEN RETURN 'rate_limited'; END IF;
 IF (SELECT count(*) FROM agency.customer_auth_challenges WHERE user_id=p_user AND created_at>now()-interval '1 hour')>=10 THEN RETURN 'rate_limited'; END IF;
 IF p_kind='phone' THEN
 -- Use the configured phone provider without changing the saved contact.
 SELECT phone INTO old_phone FROM agency.customer_verification WHERE user_id=p_user AND tenant_id=p_tenant;
 UPDATE agency.customer_auth_challenges SET consumed_at=now() WHERE user_id=p_user AND purpose='phone_change' AND consumed_at IS NULL;
 UPDATE agency.customer_verification SET phone=p_target WHERE user_id=p_user AND tenant_id=p_tenant;
 result:=agency.customer_auth_request(p_tenant,u.email,'phone','whatsapp');
 UPDATE agency.customer_verification SET phone=old_phone WHERE user_id=p_user AND tenant_id=p_tenant;
 IF result<>'accepted' THEN RETURN result; END IF;
 SELECT id INTO cid FROM agency.customer_auth_challenges WHERE user_id=p_user AND purpose='phone' AND consumed_at IS NULL ORDER BY created_at DESC LIMIT 1;
 UPDATE agency.customer_auth_challenges SET purpose='phone_change',target_value=p_target WHERE id=cid;
 ELSE
 code:=lpad((get_byte(gen_random_bytes(1),0)*65536+get_byte(gen_random_bytes(1),0)*256+get_byte(gen_random_bytes(1),0))::text,8,'0');
 UPDATE agency.customer_auth_challenges SET consumed_at=now() WHERE user_id=p_user AND purpose='email_change' AND consumed_at IS NULL;
 INSERT INTO agency.customer_auth_challenges(tenant_id,user_id,purpose,channel,code_hash,expires_at,target_value) VALUES(p_tenant,p_user,'email_change','email',encode(digest(code,'sha256'),'hex'),now()+interval '10 minutes',lower(trim(p_target))) RETURNING id INTO cid;
 INSERT INTO agency.notifications(tenant_id,user_id,channel,template,payload,status) VALUES(p_tenant,p_user,'email','customer.auth.email_change',jsonb_build_object('to',lower(trim(p_target)),'email',lower(trim(p_target)),'subject','E-posta değişikliği doğrulama kodu','html','<p>Doğrulama kodunuz: <strong>'||code||'</strong></p><p>Kod 10 dakika geçerlidir.</p>'),'queued');
 END IF;
 RETURN 'accepted'; END $$;
CREATE OR REPLACE FUNCTION agency.customer_contact_confirm(p_tenant uuid,p_user uuid,p_kind text,p_code text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$ DECLARE c agency.customer_auth_challenges%ROWTYPE; old_email text; BEGIN
 IF p_kind NOT IN ('email','phone') THEN RETURN 'invalid'; END IF;
 SELECT email INTO old_email FROM agency.users WHERE id=p_user AND tenant_id=p_tenant AND active AND membership_type='customer' FOR UPDATE;
 IF NOT FOUND THEN RETURN 'forbidden'; END IF;
 SELECT * INTO c FROM agency.customer_auth_challenges WHERE tenant_id=p_tenant AND user_id=p_user AND purpose=p_kind||'_change' AND consumed_at IS NULL ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
 IF NOT FOUND OR c.expires_at<=now() OR c.attempts>=5 THEN RETURN 'invalid_code'; END IF;
 IF c.code_hash<>encode(digest(p_code,'sha256'),'hex') THEN UPDATE agency.customer_auth_challenges SET attempts=attempts+1 WHERE id=c.id; RETURN 'invalid_code'; END IF;
 IF p_kind='email' THEN
 IF EXISTS(SELECT 1 FROM agency.users WHERE tenant_id=p_tenant AND lower(email)=c.target_value AND id<>p_user) THEN RETURN 'unavailable'; END IF;
 UPDATE agency.users SET email=c.target_value WHERE id=p_user AND tenant_id=p_tenant;
 UPDATE agency.customer_verification SET email_verified_at=now() WHERE user_id=p_user AND tenant_id=p_tenant;
 ELSE UPDATE agency.customer_verification SET phone=c.target_value,phone_verified_at=now() WHERE user_id=p_user AND tenant_id=p_tenant; END IF;
 UPDATE agency.customer_auth_challenges SET consumed_at=now() WHERE id=c.id;
 INSERT INTO agency.notifications(tenant_id,user_id,channel,template,payload,status) VALUES(p_tenant,p_user,'email','customer.contact.changed',jsonb_build_object('to',old_email,'email',old_email,'subject','Hesap iletişim bilginiz değiştirildi','html','<p>Hesabınızdaki iletişim bilgisi doğrulanarak değiştirildi. İşlemi siz yapmadıysanız acenteyle iletişime geçin.</p>'),'queued');
 INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata) VALUES(p_tenant,p_user,'customer.contact.'||p_kind||'.changed','user',p_user,'{}'); RETURN 'verified'; END $$;
REVOKE ALL ON FUNCTION agency.membership_request_allowed(uuid,text),agency.customer_session_list(uuid,uuid,text),agency.customer_session_revoke(uuid,uuid,text,text),agency.customer_contact_request(uuid,uuid,text,text,text),agency.customer_contact_confirm(uuid,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.membership_request_allowed(uuid,text),agency.customer_session_list(uuid,uuid,text),agency.customer_session_revoke(uuid,uuid,text,text),agency.customer_contact_request(uuid,uuid,text,text,text),agency.customer_contact_confirm(uuid,uuid,text,text) TO agency_app;
COMMIT;
