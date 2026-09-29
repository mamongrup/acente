-- Keep the historical decision implementations, but make reviewer authorization
-- a database boundary as well as a router check.
ALTER FUNCTION agency.decide_supplier_application(uuid,uuid,uuid,text,text)
  RENAME TO decide_supplier_application_unchecked;
ALTER FUNCTION agency.decide_supplier_application_document(uuid,uuid,uuid,text,text)
  RENAME TO decide_supplier_application_document_unchecked;

REVOKE ALL ON FUNCTION agency.decide_supplier_application_unchecked(uuid,uuid,uuid,text,text) FROM PUBLIC, agency_app;
REVOKE ALL ON FUNCTION agency.decide_supplier_application_document_unchecked(uuid,uuid,uuid,text,text) FROM PUBLIC, agency_app;

CREATE FUNCTION agency.supplier_review_actor_allowed(p_tenant uuid, p_reviewer uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT EXISTS (
    SELECT 1 FROM agency.users AS reviewer
    WHERE reviewer.id = p_reviewer
      AND reviewer.tenant_id = p_tenant
      AND reviewer.active
      AND (
        reviewer.membership_type = 'admin'
        OR EXISTS (
          SELECT 1 FROM agency.user_roles AS assigned
          JOIN agency.roles AS role ON role.id = assigned.role_id
          WHERE assigned.user_id = reviewer.id
            AND role.tenant_id = p_tenant
            AND role.code = 'admin'
        )
      )
  );
$$;
REVOKE ALL ON FUNCTION agency.supplier_review_actor_allowed(uuid,uuid) FROM PUBLIC;

CREATE FUNCTION agency.decide_supplier_application(
  p_tenant uuid, p_application uuid, p_reviewer uuid, p_decision text, p_note text DEFAULT ''
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NOT agency.supplier_review_actor_allowed(p_tenant,p_reviewer) THEN
    RETURN 'forbidden';
  END IF;
  RETURN agency.decide_supplier_application_unchecked(
    p_tenant,p_application,p_reviewer,p_decision,p_note
  );
END $$;

CREATE FUNCTION agency.decide_supplier_application_document(
  p_tenant uuid, p_document uuid, p_reviewer uuid, p_decision text, p_note text DEFAULT ''
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NOT agency.supplier_review_actor_allowed(p_tenant,p_reviewer) THEN
    RETURN 'forbidden';
  END IF;
  RETURN agency.decide_supplier_application_document_unchecked(
    p_tenant,p_document,p_reviewer,p_decision,p_note
  );
END $$;

REVOKE ALL ON FUNCTION agency.decide_supplier_application(uuid,uuid,uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.decide_supplier_application_document(uuid,uuid,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.decide_supplier_application(uuid,uuid,uuid,text,text) TO agency_app;
GRANT EXECUTE ON FUNCTION agency.decide_supplier_application_document(uuid,uuid,uuid,text,text) TO agency_app;
