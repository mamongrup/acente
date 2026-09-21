CREATE TABLE IF NOT EXISTS agency.roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  code text NOT NULL, name text NOT NULL, permissions jsonb NOT NULL DEFAULT '[]'::jsonb, UNIQUE(tenant_id,code)
);
CREATE TABLE IF NOT EXISTS agency.user_roles (
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE, role_id uuid NOT NULL REFERENCES agency.roles(id) ON DELETE CASCADE,
  PRIMARY KEY(user_id,role_id)
);
CREATE TABLE IF NOT EXISTS agency.applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE, type text NOT NULL CHECK(type IN ('supplier','sub_agency','staff')),
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected','deleted')), identity_status text NOT NULL DEFAULT 'pending' CHECK(identity_status IN ('pending','verified','manual_review','failed')),
  submitted_at timestamptz NOT NULL DEFAULT now(), reviewed_at timestamptz, reviewed_by uuid REFERENCES agency.users(id), note text NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS agency.application_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), application_id uuid NOT NULL REFERENCES agency.applications(id) ON DELETE CASCADE,
  document_type text NOT NULL, media_id uuid REFERENCES agency.media(id) ON DELETE SET NULL, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')), note text NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS agency.identity_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'nvi', national_id_hash text NOT NULL, full_name text NOT NULL, result text NOT NULL CHECK(result IN ('verified','failed','unavailable','manual_review')),
  response jsonb NOT NULL DEFAULT '{}'::jsonb, checked_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid REFERENCES agency.tenants(id) ON DELETE CASCADE, user_id uuid REFERENCES agency.users(id) ON DELETE SET NULL,
  action text NOT NULL, entity_type text NOT NULL, entity_id uuid, ip inet, metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_applications_review_idx ON agency.applications(tenant_id,status,submitted_at);
CREATE INDEX IF NOT EXISTS agency_documents_status_idx ON agency.application_documents(application_id,status);
CREATE INDEX IF NOT EXISTS agency_audit_logs_tenant_idx ON agency.audit_logs(tenant_id,created_at DESC);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.roles,agency.user_roles,agency.applications,agency.application_documents,agency.identity_checks,agency.audit_logs TO agency_app;
