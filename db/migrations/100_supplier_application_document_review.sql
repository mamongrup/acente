-- Supplier application document review workflow.
-- Required document codes come from the shared onboarding contract and are
-- compared against uploaded application documents.

ALTER TABLE agency.application_documents
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES agency.users(id),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION agency.supplier_application_documents(p_tenant uuid)
RETURNS TABLE(data text[])
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  WITH required_documents AS (
    SELECT code, position
    FROM agency.supplier_onboarding_contract_items
    WHERE kind = 'required_document'
  ),
  supplier_applications AS (
    SELECT a.id, a.user_id, a.category_code, a.status AS application_status
    FROM agency.applications a
    WHERE a.tenant_id = p_tenant
      AND a.type = 'supplier'
      AND a.status <> 'deleted'
  )
  SELECT ARRAY[
    a.id::text,
    coalesce(d.id::text, ''),
    r.code,
    coalesce(d.status, 'missing'),
    coalesce(d.note, ''),
    coalesce(d.media_id::text, ''),
    coalesce(d.reviewed_at::text, ''),
    coalesce(d.reviewed_by::text, ''),
    a.application_status
  ]
  FROM supplier_applications a
  CROSS JOIN required_documents r
  LEFT JOIN agency.application_documents d
    ON d.application_id = a.id
   AND d.document_type = r.code
  ORDER BY a.id::text, r.position, r.code;
$$;

CREATE OR REPLACE FUNCTION agency.decide_supplier_application_document(
  p_tenant uuid,
  p_document uuid,
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
  normalized_decision text := lower(trim(coalesce(p_decision, '')));
  application_uuid uuid;
  old_status text;
BEGIN
  IF normalized_decision NOT IN ('approved','rejected','pending') THEN
    RETURN 'invalid_decision';
  END IF;

  SELECT d.application_id, d.status
  INTO application_uuid, old_status
  FROM agency.application_documents d
  JOIN agency.applications a ON a.id = d.application_id
  WHERE d.id = p_document
    AND a.tenant_id = p_tenant
    AND a.type = 'supplier'
    AND a.status <> 'deleted'
  FOR UPDATE OF d;

  IF application_uuid IS NULL THEN
    RETURN 'not_found';
  END IF;

  UPDATE agency.application_documents
  SET status = normalized_decision,
      note = coalesce(nullif(trim(p_note), ''), note),
      reviewed_at = CASE
        WHEN normalized_decision IN ('approved','rejected') THEN now()
        ELSE NULL
      END,
      reviewed_by = CASE
        WHEN normalized_decision IN ('approved','rejected') THEN p_reviewer
        ELSE NULL
      END,
      updated_at = now()
  WHERE id = p_document;

  UPDATE agency.applications
  SET status = CASE
        WHEN status = 'submitted' THEN 'in_review'
        ELSE status
      END,
      reviewed_by = p_reviewer,
      updated_at = now()
  WHERE id = application_uuid
    AND tenant_id = p_tenant;

  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
  VALUES(
    p_tenant,
    p_reviewer,
    'supplier_application_document.' || normalized_decision,
    'application_document',
    p_document,
    jsonb_build_object(
      'application_id', application_uuid,
      'previous_status', old_status,
      'decision', normalized_decision,
      'note', coalesce(p_note, '')
    )
  );

  RETURN 'ok';
END $$;

GRANT EXECUTE ON FUNCTION agency.supplier_application_documents(uuid),agency.decide_supplier_application_document(uuid,uuid,uuid,text,text) TO agency_app;
