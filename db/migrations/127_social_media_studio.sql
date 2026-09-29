-- Sosyal medya stüdyosu: şablon, AI planı, onay ve kanal analizleri.
-- Tüm kayıtlar tenant_id ile izole edilir; mevcut social_posts worker sözleşmesi korunur.
ALTER TABLE agency.social_templates
  ADD COLUMN IF NOT EXISTS language_code varchar(10) NOT NULL DEFAULT 'tr',
  ADD COLUMN IF NOT EXISTS post_type text NOT NULL DEFAULT 'feed',
  ADD COLUMN IF NOT EXISTS variables jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS ai_caption_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS approval_required boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE agency.social_posts
  ADD COLUMN IF NOT EXISTS template_id uuid REFERENCES agency.social_templates(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS media_keys jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS ai_generated boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS external_post_id text,
  ADD COLUMN IF NOT EXISTS failure_code text;

ALTER TABLE agency.social_templates
  DROP CONSTRAINT IF EXISTS social_templates_post_type_check;
ALTER TABLE agency.social_templates
  ADD CONSTRAINT social_templates_post_type_check
  CHECK (post_type IN ('feed','story','reel','carousel','short'));

CREATE TABLE IF NOT EXISTS agency.social_account_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  network text NOT NULL CHECK (network IN ('instagram','facebook','threads','pinterest','x','tiktok','youtube')),
  account_id text NOT NULL,
  account_name text NOT NULL DEFAULT '',
  access_token_encrypted text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  last_sync_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, network, account_id)
);

CREATE TABLE IF NOT EXISTS agency.social_post_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  social_post_id uuid NOT NULL REFERENCES agency.social_posts(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agency.instagram_shop_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL,
  instagram_media_id text NOT NULL,
  sync_enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, listing_id, instagram_media_id)
);

CREATE INDEX IF NOT EXISTS agency_social_templates_lookup_idx
  ON agency.social_templates(tenant_id, network, language_code, active);
CREATE INDEX IF NOT EXISTS agency_social_posts_approval_idx
  ON agency.social_posts(tenant_id, status, approved_at, scheduled_at);
CREATE INDEX IF NOT EXISTS agency_social_events_post_idx
  ON agency.social_post_events(tenant_id, social_post_id, created_at DESC);

-- Worker yeniden çalıştırıldığında aynı ilan/ağ/tür için mükerrer aktif iş üretme.
CREATE UNIQUE INDEX IF NOT EXISTS agency_social_active_entity_network_type_uq
  ON agency.social_posts(tenant_id, entity_type, entity_id, network,
    coalesce((metadata->>'post_type'), 'feed'))
  WHERE status IN ('queued', 'running');

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.social_account_links,
  agency.social_post_events, agency.instagram_shop_links TO agency_app;
