-- Tüm otomasyon modülleri için ortak manuel/otomatik kontrol ve raporlama.
CREATE TABLE IF NOT EXISTS agency.module_control_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  module_key text NOT NULL,
  mode text NOT NULL DEFAULT 'manual' CHECK (mode IN ('manual','automatic')),
  enabled boolean NOT NULL DEFAULT true,
  daily_limit integer NOT NULL DEFAULT 0 CHECK (daily_limit >= 0),
  weekly_limit integer NOT NULL DEFAULT 0 CHECK (weekly_limit >= 0),
  monthly_limit integer NOT NULL DEFAULT 0 CHECK (monthly_limit >= 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, module_key)
);
CREATE TABLE IF NOT EXISTS agency.module_run_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  module_key text NOT NULL,
  operation text NOT NULL,
  status text NOT NULL DEFAULT 'started' CHECK (status IN ('started','completed','failed','skipped')),
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS agency_module_runs_report_idx
  ON agency.module_run_events(tenant_id, module_key, started_at DESC);
GRANT SELECT, INSERT, UPDATE, DELETE ON agency.module_control_policies, agency.module_run_events TO agency_app;
