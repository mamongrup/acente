-- Sosyal medya otomasyon limitleri ve zaman pencereleri.
CREATE TABLE IF NOT EXISTS agency.social_automation_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  network text NOT NULL DEFAULT '*',
  language_code varchar(10) NOT NULL DEFAULT '*',
  market_code varchar(10) NOT NULL DEFAULT '*',
  daily_limit integer NOT NULL DEFAULT 5 CHECK (daily_limit >= 0 AND daily_limit <= 1000),
  auto_generate boolean NOT NULL DEFAULT true,
  approval_required boolean NOT NULL DEFAULT true,
  window_start time NOT NULL DEFAULT '00:00',
  window_end time NOT NULL DEFAULT '23:59',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, network, language_code, market_code)
);

CREATE INDEX IF NOT EXISTS agency_social_automation_active_idx
  ON agency.social_automation_policies(tenant_id, active, network, language_code);

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.social_automation_policies TO agency_app;
