CREATE TABLE IF NOT EXISTS agency.content_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  entity_type text NOT NULL, entity_id uuid NOT NULL, version_no int NOT NULL, language_code varchar(10) NOT NULL DEFAULT 'tr', payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','pending_review','approved','published','rejected','archived')), created_by uuid REFERENCES agency.users(id) ON DELETE SET NULL, reviewed_by uuid REFERENCES agency.users(id) ON DELETE SET NULL, created_at timestamptz NOT NULL DEFAULT now(), published_at timestamptz,
  UNIQUE(tenant_id,entity_type,entity_id,language_code,version_no)
);
CREATE TABLE IF NOT EXISTS agency.moderation_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE, version_id uuid NOT NULL REFERENCES agency.content_versions(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')), reviewer_id uuid REFERENCES agency.users(id) ON DELETE SET NULL, note text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now(), reviewed_at timestamptz
);
CREATE INDEX IF NOT EXISTS agency_content_versions_current_idx ON agency.content_versions(tenant_id,entity_type,entity_id,language_code,status);
CREATE INDEX IF NOT EXISTS agency_moderation_queue_idx ON agency.moderation_queue(tenant_id,status,created_at);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.content_versions,agency.moderation_queue TO agency_app;
