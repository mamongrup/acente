-- Arama motoru ve Google Commerce bağlantılarının tenant bazlı yapılandırması.
-- Gizli token/JSON anahtarları bu tabloda tutulmaz; yalnızca secret_ref saklanır.
CREATE TABLE IF NOT EXISTS agency.search_engine_integrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('google_search_console','google_merchant','google_analytics','google_tag_manager','yandex_webmaster','baidu_search')),
  site_url text NOT NULL DEFAULT '',
  verification_code text NOT NULL DEFAULT '',
  account_id text NOT NULL DEFAULT '',
  merchant_country text NOT NULL DEFAULT 'TR',
  feed_url text NOT NULL DEFAULT '',
  secret_ref text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT false,
  last_sync_at timestamptz,
  last_error text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, provider)
);
CREATE INDEX IF NOT EXISTS agency_search_integrations_active_idx
  ON agency.search_engine_integrations(tenant_id, active);
GRANT SELECT, INSERT, UPDATE, DELETE ON agency.search_engine_integrations TO agency_app;
