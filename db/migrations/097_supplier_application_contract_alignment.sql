-- Align agency-side supplier applications with the shared onboarding contract.
-- Existing rows are preserved; legacy `pending` rows become `submitted`.

ALTER TABLE agency.applications
  ADD COLUMN IF NOT EXISTS category_code text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS contract_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

UPDATE agency.applications
SET status = 'submitted',
    updated_at = now()
WHERE status = 'pending';

DO $$
DECLARE
  constraint_name text;
BEGIN
  SELECT conname INTO constraint_name
  FROM pg_constraint
  WHERE conrelid = 'agency.applications'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) LIKE '%status%'
    AND pg_get_constraintdef(oid) LIKE '%pending%'
  LIMIT 1;

  IF constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE agency.applications DROP CONSTRAINT %I', constraint_name);
  END IF;
END $$;

ALTER TABLE agency.applications
  ADD CONSTRAINT agency_applications_status_contract_chk
  CHECK(status IN ('draft','submitted','in_review','approved','rejected','suspended','deleted'));

CREATE TABLE IF NOT EXISTS agency.application_category_requests (
  application_id uuid NOT NULL REFERENCES agency.applications(id) ON DELETE CASCADE,
  category_code text NOT NULL,
  status text NOT NULL DEFAULT 'submitted'
    CHECK(status IN ('submitted','in_review','approved','rejected','suspended')),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES agency.users(id),
  note text NOT NULL DEFAULT '',
  PRIMARY KEY(application_id, category_code)
);

CREATE INDEX IF NOT EXISTS agency_application_categories_status_idx
  ON agency.application_category_requests(category_code,status);

CREATE OR REPLACE FUNCTION agency.supplier_application_contract_statuses()
RETURNS TABLE(data text[])
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT ARRAY[code, position::text]
  FROM agency.supplier_onboarding_contract_items
  WHERE kind = 'approval_status'
  ORDER BY position, code;
$$;

CREATE OR REPLACE FUNCTION agency.supplier_application_queue(p_tenant uuid)
RETURNS TABLE(data text[])
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT ARRAY[
    a.id::text,
    u.email,
    coalesce(u.display_name, ''),
    coalesce(nullif(a.category_code, ''), coalesce(string_agg(acr.category_code, ',' ORDER BY acr.category_code), '')),
    a.status,
    a.identity_status,
    coalesce(count(DISTINCT d.id), 0)::text,
    a.submitted_at::text,
    coalesce(a.reviewed_at::text, ''),
    a.note
  ]
  FROM agency.applications a
  JOIN agency.users u ON u.id = a.user_id
  LEFT JOIN agency.application_category_requests acr ON acr.application_id = a.id
  LEFT JOIN agency.application_documents d ON d.application_id = a.id
  WHERE a.tenant_id = p_tenant
    AND a.type = 'supplier'
    AND a.status <> 'deleted'
  GROUP BY a.id, u.email, u.display_name
  ORDER BY
    CASE a.status
      WHEN 'submitted' THEN 1
      WHEN 'in_review' THEN 2
      WHEN 'draft' THEN 3
      WHEN 'approved' THEN 4
      WHEN 'rejected' THEN 5
      WHEN 'suspended' THEN 6
      ELSE 7
    END,
    a.submitted_at DESC;
$$;

GRANT SELECT,INSERT,UPDATE,DELETE ON agency.application_category_requests TO agency_app;
GRANT EXECUTE ON FUNCTION agency.supplier_application_contract_statuses(),agency.supplier_application_queue(uuid) TO agency_app;
