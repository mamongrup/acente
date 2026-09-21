-- Çoklu Gemini anahtar havuzu ve DeepSeek kota yedeği.
-- daily_limit = 0 sınırsız anlamına gelir; günlük sayaç UTC veritabanı gününde sıfırlanır.
CREATE TABLE IF NOT EXISTS agency.ai_key_pool (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('google','deepseek')),
  label text NOT NULL,
  api_key_encrypted text NOT NULL DEFAULT '',
  model text NOT NULL DEFAULT '',
  priority int NOT NULL DEFAULT 0,
  daily_limit int NOT NULL DEFAULT 0 CHECK (daily_limit >= 0),
  daily_used int NOT NULL DEFAULT 0 CHECK (daily_used >= 0),
  usage_day date NOT NULL DEFAULT current_date,
  active boolean NOT NULL DEFAULT true,
  last_error text NOT NULL DEFAULT '',
  cooldown_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, provider, label)
);

CREATE INDEX IF NOT EXISTS agency_ai_key_pool_available_idx
  ON agency.ai_key_pool (tenant_id, provider, active, usage_day, daily_used, priority);

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.ai_key_pool TO agency_app;
