CREATE SCHEMA IF NOT EXISTS agency_auth;
CREATE TABLE IF NOT EXISTS agency_auth.sessions (
  token_digest text PRIMARY KEY, user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE, expires_at timestamptz NOT NULL
);
CREATE OR REPLACE FUNCTION agency_auth.login(p_email text,p_password text,p_token text)
RETURNS TABLE(tenant_id text,user_id text,display_name text,membership_type text) LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency,agency_auth AS $$
DECLARE u agency.users%ROWTYPE;
BEGIN SELECT * INTO u FROM agency.users WHERE lower(email)=lower(trim(p_email)) AND active FOR UPDATE;
 IF NOT FOUND OR u.password_hash IS NULL OR crypt(p_password,u.password_hash)<>u.password_hash THEN RETURN; END IF;
 INSERT INTO agency_auth.sessions(token_digest,user_id,expires_at) VALUES(encode(digest(p_token,'sha256'),'hex'),u.id,now()+interval '8 hours') ON CONFLICT(token_digest) DO UPDATE SET expires_at=excluded.expires_at,user_id=excluded.user_id;
 RETURN QUERY SELECT u.tenant_id::text,u.id::text,u.display_name,u.membership_type;
END $$;
CREATE OR REPLACE FUNCTION agency_auth.session(p_token text) RETURNS TABLE(tenant_id text,user_id text,display_name text,membership_type text) LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,agency_auth AS $$ SELECT u.tenant_id::text,u.id::text,u.display_name,u.membership_type FROM agency_auth.sessions s JOIN agency.users u ON u.id=s.user_id WHERE s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active $$;
CREATE OR REPLACE FUNCTION agency_auth.logout(p_token text) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,agency_auth AS $$ DELETE FROM agency_auth.sessions WHERE token_digest=encode(digest(p_token,'sha256'),'hex') $$;
GRANT USAGE ON SCHEMA agency_auth TO nexus_owner;
GRANT SELECT,INSERT,UPDATE,DELETE ON agency_auth.sessions TO nexus_owner;
GRANT EXECUTE ON FUNCTION agency_auth.login(text,text,text),agency_auth.session(text),agency_auth.logout(text) TO nexus_owner;
