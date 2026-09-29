CREATE OR REPLACE FUNCTION auth.switch_role(p_token text,p_role text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_user uuid; v_tenant uuid;
BEGIN
  SELECT u.id,u.tenant_id INTO v_user,v_tenant FROM auth.sessions s
    JOIN agency.users u ON u.id=s.user_id
    WHERE s.token_digest=encode(public.digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active
    FOR UPDATE OF s;
  IF v_user IS NULL THEN RETURN false; END IF;
  IF p_role NOT IN ('admin','staff','supplier','sub_agency','customer') THEN RETURN false; END IF;
  IF NOT EXISTS (SELECT 1 FROM agency.user_roles ur JOIN agency.roles r ON r.id=ur.role_id
                 WHERE ur.user_id=v_user AND r.tenant_id=v_tenant AND r.code=p_role)
     AND NOT EXISTS (SELECT 1 FROM agency.users WHERE id=v_user AND membership_type=p_role)
  THEN RETURN false; END IF;
  UPDATE auth.sessions SET active_role=p_role WHERE token_digest=encode(public.digest(p_token,'sha256'),'hex');
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(v_tenant,v_user,'auth.role_switch','user',v_user,jsonb_build_object('role',p_role));
  RETURN true;
END $$;
