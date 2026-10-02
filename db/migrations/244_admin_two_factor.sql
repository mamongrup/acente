BEGIN;
CREATE TABLE IF NOT EXISTS agency.admin_mfa(user_id uuid PRIMARY KEY REFERENCES agency.users(id) ON DELETE CASCADE,tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,secret_sealed text NOT NULL,enabled boolean NOT NULL DEFAULT false,last_counter bigint NOT NULL DEFAULT -1,backup_hashes text[] NOT NULL DEFAULT '{}',updated_at timestamptz NOT NULL DEFAULT now());
REVOKE ALL ON agency.admin_mfa FROM PUBLIC,agency_app;
CREATE OR REPLACE FUNCTION agency.admin_mfa_read(p_tenant uuid,p_user uuid) RETURNS TABLE(secret text,enabled text) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$ SELECT m.secret_sealed,m.enabled::text FROM agency.admin_mfa m JOIN agency.users u ON u.id=m.user_id AND u.tenant_id=m.tenant_id WHERE m.tenant_id=p_tenant AND m.user_id=p_user AND u.active AND u.membership_type='admin' $$;
CREATE OR REPLACE FUNCTION agency.admin_mfa_begin(p_tenant uuid,p_user uuid,p_password text,p_secret text,p_backups text[]) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_user AND tenant_id=p_tenant AND active AND membership_type='admin' AND crypt(p_password,password_hash)=password_hash) THEN RETURN 'forbidden'; END IF;
 IF EXISTS(SELECT 1 FROM agency.admin_mfa WHERE user_id=p_user AND enabled) THEN RETURN 'already_enabled'; END IF;
 INSERT INTO agency.admin_mfa(user_id,tenant_id,secret_sealed,backup_hashes) VALUES(p_user,p_tenant,p_secret,p_backups) ON CONFLICT(user_id) DO UPDATE SET secret_sealed=p_secret,backup_hashes=p_backups,last_counter=-1,updated_at=now(); RETURN 'pending'; END $$;
CREATE OR REPLACE FUNCTION agency.admin_mfa_claim(p_tenant uuid,p_user uuid,p_counter bigint,p_backup text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$ BEGIN
 IF p_counter>=0 THEN UPDATE agency.admin_mfa SET last_counter=p_counter,updated_at=now() WHERE tenant_id=p_tenant AND user_id=p_user AND last_counter<p_counter;
 ELSE UPDATE agency.admin_mfa SET backup_hashes=array_remove(backup_hashes,encode(digest(p_backup,'sha256'),'hex')),updated_at=now() WHERE tenant_id=p_tenant AND user_id=p_user AND encode(digest(p_backup,'sha256'),'hex')=ANY(backup_hashes); END IF;
 RETURN FOUND; END $$;
CREATE OR REPLACE FUNCTION agency.admin_mfa_set(p_tenant uuid,p_user uuid,p_password text,p_enabled boolean) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_user AND tenant_id=p_tenant AND membership_type='admin' AND active AND crypt(p_password,password_hash)=password_hash) THEN RETURN 'forbidden'; END IF;
 UPDATE agency.admin_mfa SET enabled=p_enabled,updated_at=now() WHERE tenant_id=p_tenant AND user_id=p_user;
 IF NOT FOUND THEN RETURN 'invalid'; END IF;
 INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata) VALUES(p_tenant,p_user,CASE WHEN p_enabled THEN 'admin.mfa.enabled' ELSE 'admin.mfa.disabled' END,'user',p_user,'{}');
 RETURN CASE WHEN p_enabled THEN 'enabled' ELSE 'disabled' END; END $$;
REVOKE ALL ON FUNCTION agency.admin_mfa_read(uuid,uuid),agency.admin_mfa_begin(uuid,uuid,text,text,text[]),agency.admin_mfa_claim(uuid,uuid,bigint,text),agency.admin_mfa_set(uuid,uuid,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.admin_mfa_read(uuid,uuid),agency.admin_mfa_begin(uuid,uuid,text,text,text[]),agency.admin_mfa_claim(uuid,uuid,bigint,text),agency.admin_mfa_set(uuid,uuid,text,boolean) TO agency_app;
ALTER TABLE agency.admin_mfa ADD COLUMN IF NOT EXISTS attempt_window timestamptz NOT NULL DEFAULT now();
ALTER TABLE agency.admin_mfa ADD COLUMN IF NOT EXISTS attempt_count integer NOT NULL DEFAULT 0;
CREATE OR REPLACE FUNCTION agency.admin_mfa_attempt(p_tenant uuid,p_user uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$ DECLARE n integer; BEGIN
 UPDATE agency.admin_mfa SET attempt_count=CASE WHEN attempt_window<now()-interval '1 minute' THEN 1 ELSE attempt_count+1 END,attempt_window=CASE WHEN attempt_window<now()-interval '1 minute' THEN now() ELSE attempt_window END WHERE tenant_id=p_tenant AND user_id=p_user RETURNING attempt_count INTO n; RETURN coalesce(n<=5,false); END $$;
CREATE OR REPLACE FUNCTION agency.admin_mfa_revoke_other_sessions(p_tenant uuid,p_user uuid,p_token text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth AS $$ BEGIN
 IF EXISTS(SELECT 1 FROM agency.users u JOIN auth.sessions s ON s.user_id=u.id WHERE u.id=p_user AND u.tenant_id=p_tenant AND u.membership_type='admin' AND s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now()) THEN
 DELETE FROM auth.sessions WHERE user_id=p_user AND token_digest<>encode(digest(p_token,'sha256'),'hex'); DELETE FROM agency_auth.sessions WHERE user_id=p_user AND token_digest<>encode(digest(p_token,'sha256'),'hex'); END IF; END $$;
REVOKE ALL ON FUNCTION agency.admin_mfa_attempt(uuid,uuid),agency.admin_mfa_revoke_other_sessions(uuid,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.admin_mfa_attempt(uuid,uuid),agency.admin_mfa_revoke_other_sessions(uuid,uuid,text) TO agency_app;
COMMIT;
