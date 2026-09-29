-- A session selects one of the user's explicit roles. The primary membership
-- remains intact, and every request revalidates the selected role.
ALTER TABLE auth.sessions ADD COLUMN IF NOT EXISTS active_role text;
ALTER TABLE agency_auth.sessions ADD COLUMN IF NOT EXISTS active_role text;

CREATE OR REPLACE FUNCTION auth.session(p_token text)
RETURNS TABLE(tenant_id text,user_id text,display_name text,membership_type text,theme_preference text,wizard_prefs jsonb,language_pref text,currency_pref text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth AS $$
 SELECT u.tenant_id::text,u.id::text,u.display_name,
   coalesce((SELECT r.code FROM agency.user_roles ur JOIN agency.roles r ON r.id=ur.role_id
             WHERE ur.user_id=u.id AND r.tenant_id=u.tenant_id AND r.code=s.active_role
               AND r.code IN ('admin','staff','supplier','sub_agency','customer') LIMIT 1),u.membership_type),
   u.theme_preference,u.wizard_prefs,u.language_pref,u.currency_pref
 FROM auth.sessions s JOIN agency.users u ON u.id=s.user_id
 WHERE s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active;
$$;

CREATE OR REPLACE FUNCTION agency_auth.session(p_token text)
RETURNS TABLE(tenant_id text,user_id text,display_name text,membership_type text,theme_preference text,wizard_prefs jsonb,language_pref text,currency_pref text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,agency_auth AS $$
 SELECT u.tenant_id::text,u.id::text,u.display_name,
   coalesce((SELECT r.code FROM agency.user_roles ur JOIN agency.roles r ON r.id=ur.role_id
             WHERE ur.user_id=u.id AND r.tenant_id=u.tenant_id AND r.code=s.active_role
               AND r.code IN ('admin','staff','supplier','sub_agency','customer') LIMIT 1),u.membership_type),
   u.theme_preference,u.wizard_prefs,u.language_pref,u.currency_pref
 FROM agency_auth.sessions s JOIN agency.users u ON u.id=s.user_id
 WHERE s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active;
$$;

CREATE OR REPLACE FUNCTION auth.switch_role(p_token text,p_role text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_user uuid; v_tenant uuid;
BEGIN
  SELECT u.id,u.tenant_id INTO v_user,v_tenant FROM auth.sessions s
    JOIN agency.users u ON u.id=s.user_id
    WHERE s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active
    FOR UPDATE OF s;
  IF v_user IS NULL THEN RETURN false; END IF;
  IF p_role NOT IN ('admin','staff','supplier','sub_agency','customer') THEN RETURN false; END IF;
  IF NOT EXISTS (SELECT 1 FROM agency.user_roles ur JOIN agency.roles r ON r.id=ur.role_id
                 WHERE ur.user_id=v_user AND r.tenant_id=v_tenant AND r.code=p_role)
     AND NOT EXISTS (SELECT 1 FROM agency.users WHERE id=v_user AND membership_type=p_role)
  THEN RETURN false; END IF;
  UPDATE auth.sessions SET active_role=p_role WHERE token_digest=encode(digest(p_token,'sha256'),'hex');
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(v_tenant,v_user,'auth.role_switch','user',v_user,jsonb_build_object('role',p_role));
  RETURN true;
END $$;

CREATE OR REPLACE FUNCTION agency.grant_user_role(p_tenant uuid,p_actor uuid,p_user uuid,p_role text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_role uuid;
BEGIN
  IF p_role NOT IN ('admin','staff','supplier','sub_agency','customer') THEN RETURN false; END IF;
  IF NOT EXISTS (SELECT 1 FROM agency.users WHERE id=p_actor AND tenant_id=p_tenant AND membership_type='admin' AND active)
     OR NOT EXISTS (SELECT 1 FROM agency.users WHERE id=p_user AND tenant_id=p_tenant AND active)
  THEN RETURN false; END IF;
  SELECT id INTO v_role FROM agency.roles WHERE tenant_id=p_tenant AND code=p_role;
  IF v_role IS NULL THEN RETURN false; END IF;
  INSERT INTO agency.user_roles(user_id,role_id) VALUES(p_user,v_role) ON CONFLICT DO NOTHING;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'auth.role_granted','user',p_user,jsonb_build_object('role',p_role));
  RETURN true;
END $$;

GRANT EXECUTE ON FUNCTION auth.switch_role(text,text),agency.grant_user_role(uuid,uuid,uuid,text) TO agency_app;
