-- Keep the standalone agency supplier onboarding contract in the database.
-- This is the local, versioned copy used when NEXUS is not connected.

CREATE TABLE IF NOT EXISTS agency.supplier_onboarding_contract_items (
  kind text NOT NULL CHECK (kind IN ('identity_field','business_field','required_document','approval_status')),
  code text NOT NULL,
  position int NOT NULL,
  PRIMARY KEY(kind, code)
);

DELETE FROM agency.supplier_onboarding_contract_items
WHERE kind IN ('identity_field','business_field','required_document','approval_status');

INSERT INTO agency.supplier_onboarding_contract_items(kind, code, position) VALUES
  ('identity_field','supplier_type',10),
  ('identity_field','legal_name',20),
  ('identity_field','display_name',30),
  ('identity_field','tax_country',40),
  ('identity_field','tax_office',50),
  ('identity_field','tax_number',60),
  ('identity_field','authorized_person_name',70),
  ('identity_field','authorized_person_email',80),
  ('identity_field','authorized_person_phone',90),

  ('business_field','business_category_codes',10),
  ('business_field','service_regions',20),
  ('business_field','default_currency',30),
  ('business_field','invoice_address',40),
  ('business_field','support_email',50),
  ('business_field','support_phone',60),

  ('required_document','tax_certificate',10),
  ('required_document','authorized_signature',20),
  ('required_document','trade_registry_or_chamber_record',30),
  ('required_document','service_license_if_required',40),
  ('required_document','bank_account_verification',50),

  ('approval_status','draft',10),
  ('approval_status','submitted',20),
  ('approval_status','in_review',30),
  ('approval_status','approved',40),
  ('approval_status','rejected',50),
  ('approval_status','suspended',60);

UPDATE agency.contract_versions
SET version='1.1.0', activated_at=now()
WHERE contract_name='nexus.supplier_listing';

CREATE OR REPLACE FUNCTION agency.supplier_onboarding_contract_items()
RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[kind, code, position::text]
  FROM agency.supplier_onboarding_contract_items
  ORDER BY kind, position, code;
$$;

GRANT EXECUTE ON FUNCTION agency.supplier_onboarding_contract_items() TO agency_app;
