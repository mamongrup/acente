CREATE TABLE IF NOT EXISTS agency.settings (
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  key text NOT NULL, value jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(tenant_id,key)
);
CREATE TABLE IF NOT EXISTS agency.integrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  provider text NOT NULL, kind text NOT NULL, credentials jsonb NOT NULL DEFAULT '{}'::jsonb,
  active boolean NOT NULL DEFAULT false, last_sync_at timestamptz, UNIQUE(tenant_id,provider,kind)
);
CREATE TABLE IF NOT EXISTS agency.pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  slug text NOT NULL, template text NOT NULL DEFAULT 'standard', status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published','archived')),
  seo jsonb NOT NULL DEFAULT '{}'::jsonb, published_at timestamptz, UNIQUE(tenant_id,slug)
);
CREATE TABLE IF NOT EXISTS agency.page_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), page_id uuid NOT NULL REFERENCES agency.pages(id) ON DELETE CASCADE,
  block_type text NOT NULL, sort_order int NOT NULL DEFAULT 0, content jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE IF NOT EXISTS agency.media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  object_key text NOT NULL, mime_type text NOT NULL, width int, height int, variants jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,object_key)
);
CREATE TABLE IF NOT EXISTS agency.menus (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  location text NOT NULL, label text NOT NULL, href text NOT NULL DEFAULT '#', parent_id uuid REFERENCES agency.menus(id) ON DELETE CASCADE,
  sort_order int NOT NULL DEFAULT 0, active boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS agency.campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  name text NOT NULL, kind text NOT NULL CHECK(kind IN ('early_booking','last_minute','period','coupon')),
  starts_at timestamptz, ends_at timestamptz, discount_percent numeric(8,3), active boolean NOT NULL DEFAULT false, rules jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE IF NOT EXISTS agency.coupons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  code text NOT NULL, discount_percent numeric(8,3), discount_minor bigint, usage_limit int, used_count int NOT NULL DEFAULT 0,
  starts_at timestamptz, ends_at timestamptz, active boolean NOT NULL DEFAULT true, UNIQUE(tenant_id,code)
);
CREATE TABLE IF NOT EXISTS agency.wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE, currency char(3) NOT NULL DEFAULT 'TRY', balance_minor bigint NOT NULL DEFAULT 0, UNIQUE(user_id,currency)
);
CREATE TABLE IF NOT EXISTS agency.wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), wallet_id uuid NOT NULL REFERENCES agency.wallets(id) ON DELETE CASCADE,
  amount_minor bigint NOT NULL, type text NOT NULL, reference text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES agency.listings(id) ON DELETE CASCADE, customer_id uuid REFERENCES agency.customers(id) ON DELETE SET NULL,
  rating smallint NOT NULL CHECK(rating BETWEEN 1 AND 5), body text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected','hidden')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid REFERENCES agency.users(id) ON DELETE CASCADE, channel text NOT NULL CHECK(channel IN ('email','sms','whatsapp','push')),
  template text NOT NULL, payload jsonb NOT NULL DEFAULT '{}'::jsonb, status text NOT NULL DEFAULT 'queued', scheduled_at timestamptz, sent_at timestamptz
);
CREATE INDEX IF NOT EXISTS agency_pages_status_idx ON agency.pages(tenant_id,status);
CREATE INDEX IF NOT EXISTS agency_campaigns_active_idx ON agency.campaigns(tenant_id,active,starts_at,ends_at);
CREATE INDEX IF NOT EXISTS agency_reviews_listing_idx ON agency.reviews(listing_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS agency_notifications_queue_idx ON agency.notifications(tenant_id,status,scheduled_at);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.settings,agency.integrations,agency.pages,agency.page_blocks,agency.media,agency.menus,agency.campaigns,agency.coupons,agency.wallets,agency.wallet_transactions,agency.reviews,agency.notifications TO agency_app;
