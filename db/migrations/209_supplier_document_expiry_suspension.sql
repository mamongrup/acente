-- Recheck approved applications after calendar date changes, even without a
-- reviewer action or a new document upload.
CREATE OR REPLACE FUNCTION agency.suspend_expired_supplier_applications(p_tenant uuid,p_reviewer uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_count integer;
BEGIN
  IF NOT agency.supplier_review_actor_allowed(p_tenant,p_reviewer) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  WITH invalid AS (
    SELECT a.id
    FROM agency.applications a
    WHERE a.tenant_id=p_tenant AND a.type='supplier' AND a.status='approved'
      AND EXISTS (
        SELECT 1 FROM agency.supplier_onboarding_contract_items r
        LEFT JOIN LATERAL (
          SELECT d.status,s.status AS source_status,s.id AS source_id,s.tenant_id,
            s.supplier_user_id,s.document_type,s.expires_on
          FROM agency.application_documents d
          LEFT JOIN agency.supplier_documents s ON s.id=d.supplier_document_id
          WHERE d.application_id=a.id AND d.document_type=r.code
          ORDER BY d.revision DESC LIMIT 1
        ) latest ON true
        WHERE r.kind='required_document'
          AND (latest.status IS DISTINCT FROM 'approved'
            OR latest.source_status IS DISTINCT FROM 'approved'
            OR latest.source_id IS NULL OR latest.tenant_id IS DISTINCT FROM p_tenant
            OR latest.supplier_user_id IS DISTINCT FROM a.user_id
            OR latest.document_type IS DISTINCT FROM r.code
            OR (latest.expires_on IS NOT NULL AND latest.expires_on<current_date))
      )
    FOR UPDATE OF a SKIP LOCKED
  ), changed AS (
    UPDATE agency.applications a SET status='suspended',updated_at=now(),reviewed_by=p_reviewer
    FROM invalid i WHERE a.id=i.id RETURNING a.id
  ), audited AS (
    INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    SELECT p_tenant,p_reviewer,'supplier_application.auto_suspended','application',c.id,
      jsonb_build_object('reason','required_document_invalid') FROM changed c
    RETURNING 1
  ) SELECT count(*) INTO v_count FROM audited;
  RETURN v_count;
END $$;

REVOKE ALL ON FUNCTION agency.suspend_expired_supplier_applications(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.suspend_expired_supplier_applications(uuid,uuid) TO agency_app;
