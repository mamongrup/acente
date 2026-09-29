-- Çok dilli sosyal yayın, hesap yönlendirme ve ölçüm katmanı.
ALTER TABLE agency.social_posts
  ADD COLUMN IF NOT EXISTS language_code varchar(10) NOT NULL DEFAULT 'tr',
  ADD COLUMN IF NOT EXISTS market_code varchar(10) NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS quality_score numeric(5,2),
  ADD COLUMN IF NOT EXISTS moderation_status text NOT NULL DEFAULT 'pending';

ALTER TABLE agency.social_posts
  DROP CONSTRAINT IF EXISTS social_posts_moderation_status_check;
ALTER TABLE agency.social_posts
  ADD CONSTRAINT social_posts_moderation_status_check
  CHECK (moderation_status IN ('pending','approved','rejected'));

CREATE TABLE IF NOT EXISTS agency.social_post_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  social_post_id uuid NOT NULL REFERENCES agency.social_posts(id) ON DELETE CASCADE,
  language_code varchar(10) NOT NULL,
  market_code varchar(10) NOT NULL DEFAULT '',
  content text NOT NULL DEFAULT '',
  hashtags jsonb NOT NULL DEFAULT '[]'::jsonb,
  ai_generated boolean NOT NULL DEFAULT false,
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, social_post_id, language_code, market_code)
);

CREATE TABLE IF NOT EXISTS agency.social_account_routes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  network text NOT NULL,
  language_code varchar(10) NOT NULL,
  market_code varchar(10) NOT NULL DEFAULT '',
  account_link_id uuid NOT NULL REFERENCES agency.social_account_links(id) ON DELETE CASCADE,
  active boolean NOT NULL DEFAULT true,
  UNIQUE (tenant_id, network, language_code, market_code)
);

CREATE TABLE IF NOT EXISTS agency.social_post_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  social_post_id uuid NOT NULL REFERENCES agency.social_posts(id) ON DELETE CASCADE,
  network text NOT NULL,
  external_post_id text NOT NULL DEFAULT '',
  impressions bigint NOT NULL DEFAULT 0,
  reach bigint NOT NULL DEFAULT 0,
  likes bigint NOT NULL DEFAULT 0,
  comments bigint NOT NULL DEFAULT 0,
  shares bigint NOT NULL DEFAULT 0,
  clicks bigint NOT NULL DEFAULT 0,
  conversions bigint NOT NULL DEFAULT 0,
  captured_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agency.social_webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES agency.tenants(id) ON DELETE CASCADE,
  network text NOT NULL,
  event_key text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  processed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (network, event_key)
);

CREATE INDEX IF NOT EXISTS agency_social_variants_lookup_idx
  ON agency.social_post_variants(tenant_id, language_code, market_code);
CREATE INDEX IF NOT EXISTS agency_social_metrics_post_idx
  ON agency.social_post_metrics(tenant_id, social_post_id, captured_at DESC);
CREATE INDEX IF NOT EXISTS agency_social_webhook_pending_idx
  ON agency.social_webhook_events(network, processed_at, created_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.social_post_variants,
  agency.social_account_routes, agency.social_post_metrics,
  agency.social_webhook_events TO agency_app;
