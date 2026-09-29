-- AI SEO üretimi: manuel alanlar her zaman önceliklidir; yalnızca eksik alanlar kuyruğa alınır.
CREATE TABLE IF NOT EXISTS agency.seo_generation_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  language_code varchar(10) NOT NULL DEFAULT 'tr',
  missing_fields jsonb NOT NULL DEFAULT '["title","description","keywords"]'::jsonb,
  source_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','processing','completed','failed','cancelled')),
  provider text NOT NULL DEFAULT 'auto',
  attempts int NOT NULL DEFAULT 0,
  generated jsonb NOT NULL DEFAULT '{}'::jsonb,
  error text NOT NULL DEFAULT '',
  available_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, entity_type, entity_id, language_code, status)
);
CREATE INDEX IF NOT EXISTS agency_seo_queue_ready_idx
  ON agency.seo_generation_queue(status, available_at);
GRANT SELECT, INSERT, UPDATE ON agency.seo_generation_queue TO agency_app;
