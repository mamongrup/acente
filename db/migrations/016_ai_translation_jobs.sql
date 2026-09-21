CREATE TABLE IF NOT EXISTS agency.translation_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  entity_type text NOT NULL CHECK(entity_type IN ('region','listing','blog','page','category','menu')), entity_id uuid NOT NULL,
  source_language varchar(10) NOT NULL, target_languages jsonb NOT NULL DEFAULT '[]'::jsonb,
  provider_id uuid REFERENCES agency.ai_providers(id) ON DELETE SET NULL, status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','running','completed','partial','failed')),
  requested_by uuid REFERENCES agency.users(id) ON DELETE SET NULL, created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz, error text NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS agency.translation_outputs (
  job_id uuid NOT NULL REFERENCES agency.translation_jobs(id) ON DELETE CASCADE, language_code varchar(10) NOT NULL REFERENCES agency.languages(code),
  fields jsonb NOT NULL DEFAULT '{}'::jsonb, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','completed','failed')), error text NOT NULL DEFAULT '', PRIMARY KEY(job_id,language_code)
);
CREATE INDEX IF NOT EXISTS agency_translation_jobs_queue_idx ON agency.translation_jobs(tenant_id,status,created_at);
CREATE INDEX IF NOT EXISTS agency_translation_outputs_status_idx ON agency.translation_outputs(status);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.translation_jobs,agency.translation_outputs TO agency_app;
