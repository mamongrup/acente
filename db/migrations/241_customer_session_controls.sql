BEGIN;
CREATE OR REPLACE FUNCTION agency.customer_revoke_other_sessions(p_tenant uuid,p_user uuid,p_token text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth AS $$
BEGIN
IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_user AND tenant_id=p_tenant AND membership_type='customer' AND active) THEN RETURN 'forbidden'; END IF;
IF NOT EXISTS(SELECT 1 FROM auth.sessions WHERE user_id=p_user AND token_digest=encode(digest(p_token,'sha256'),'hex') AND expires_at>now()) THEN RETURN 'forbidden'; END IF;
DELETE FROM auth.sessions WHERE user_id=p_user AND token_digest<>encode(digest(p_token,'sha256'),'hex');
DELETE FROM agency_auth.sessions WHERE user_id=p_user AND token_digest<>encode(digest(p_token,'sha256'),'hex');
INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata) VALUES(p_tenant,p_user,'customer.sessions.revoked','user',p_user,'{}');
RETURN 'revoked';
END $$;
REVOKE ALL ON FUNCTION agency.customer_revoke_other_sessions(uuid,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.customer_revoke_other_sessions(uuid,uuid,text) TO agency_app;
COMMIT;
