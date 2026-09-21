-- Supplier application decision workflow for the agency panel.
-- Keeps status transitions aligned with the shared onboarding contract.

CREATE OR REPLACE FUNCTION agency.decide_supplier_application(
  p_tenant uuid,
  p_application uuid,
  p_reviewer uuid,
  p_decision text,
  p_note text DEFAULT ''
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  current_status text;
  normalized_decision text := lower(trim(coalesce(p_decision, '')));
BEGIN
  IF normalized_decision NOT IN ('in_review','approved','rejected','suspended') THEN
    RETURN 'invalid_decision';
  END IF;

  SELECT status INTO current_status
  FROM agency.applications
  WHERE id = p_application
    AND tenant_id = p_tenant
    AND type = 'supplier'
    AND status <> 'deleted'
  FOR UPDATE;

  IF current_status IS NULL THEN
    RETURN 'not_found';
  END IF;

  IF normalized_decision = 'in_review' AND current_status NOT IN ('draft','submitted','rejected') THEN
    RETURN 'invalid_transition';
  END IF;

  IF normalized_decision = 'approved' AND current_status NOT IN ('submitted','in_review','suspended') THEN
    RETURN 'invalid_transition';
  END IF;

  IF normalized_decision = 'rejected' AND current_status NOT IN ('submitted','in_review') THEN
    RETURN 'invalid_transition';
  END IF;

  IF normalized_decision = 'suspended' AND current_status <> 'approved' THEN
    RETURN 'invalid_transition';
  END IF;

  UPDATE agency.applications
  SET status = normalized_decision,
      reviewed_at = CASE
        WHEN normalized_decision IN ('approved','rejected','suspended') THEN now()
        ELSE reviewed_at
      END,
      reviewed_by = p_reviewer,
      note = coalesce(nullif(trim(p_note), ''), note),
      updated_at = now()
  WHERE id = p_application
    AND tenant_id = p_tenant;

  UPDATE agency.application_category_requests
  SET status = CASE
        WHEN normalized_decision IN ('approved','rejected','suspended') THEN normalized_decision
        ELSE 'in_review'
      END,
      reviewed_at = CASE
        WHEN normalized_decision IN ('approved','rejected','suspended') THEN now()
        ELSE reviewed_at
      END,
      reviewed_by = p_reviewer,
      note = coalesce(nullif(trim(p_note), ''), note)
  WHERE application_id = p_application;

  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
  VALUES(
    p_tenant,
    p_reviewer,
    'supplier_application.' || normalized_decision,
    'application',
    p_application,
    jsonb_build_object(
      'previous_status', current_status,
      'decision', normalized_decision,
      'note', coalesce(p_note, '')
    )
  );

  RETURN 'ok';
END $$;

GRANT EXECUTE ON FUNCTION agency.decide_supplier_application(uuid,uuid,uuid,text,text) TO agency_app;
