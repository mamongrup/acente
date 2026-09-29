-- Changing the primary membership must not erase a user's other assignments.
CREATE OR REPLACE FUNCTION agency.sync_user_membership_role()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,agency,public AS $$
BEGIN
  IF TG_OP='UPDATE' AND NEW.membership_type IS DISTINCT FROM OLD.membership_type THEN
    DELETE FROM agency.user_roles ur USING agency.roles r
      WHERE ur.role_id=r.id AND ur.user_id=NEW.id AND r.tenant_id=NEW.tenant_id
        AND r.code=OLD.membership_type;
    INSERT INTO agency.user_roles(user_id,role_id)
      SELECT NEW.id,r.id FROM agency.roles r
      WHERE r.tenant_id=NEW.tenant_id AND r.code=NEW.membership_type
      ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION agency.revoke_user_role(p_tenant uuid,p_actor uuid,p_user uuid,p_role text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_role uuid;
BEGIN
  IF p_role NOT IN ('admin','staff','supplier','sub_agency','customer') THEN RETURN false; END IF;
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_actor AND tenant_id=p_tenant AND membership_type='admin' AND active)
     OR NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_user AND tenant_id=p_tenant AND active AND membership_type<>p_role)
  THEN RETURN false; END IF;
  SELECT id INTO v_role FROM agency.roles WHERE tenant_id=p_tenant AND code=p_role;
  IF v_role IS NULL THEN RETURN false; END IF;
  DELETE FROM agency.user_roles WHERE user_id=p_user AND role_id=v_role;
  UPDATE auth.sessions SET active_role=NULL WHERE user_id=p_user AND active_role=p_role;
  UPDATE agency_auth.sessions SET active_role=NULL WHERE user_id=p_user AND active_role=p_role;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'auth.role_revoked','user',p_user,jsonb_build_object('role',p_role));
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION agency.revoke_user_role(uuid,uuid,uuid,text) TO agency_app;
