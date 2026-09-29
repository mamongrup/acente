-- Turizm ve e-ticaret ortak ticaret omurgası.
CREATE TABLE IF NOT EXISTS agency.travel_packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  title text NOT NULL, slug text NOT NULL, description text NOT NULL DEFAULT '', currency varchar(3) NOT NULL DEFAULT 'TRY',
  price_minor bigint NOT NULL DEFAULT 0, commission_minor bigint NOT NULL DEFAULT 0, status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published','paused','archived')),
  rules jsonb NOT NULL DEFAULT '{}'::jsonb, starts_at timestamptz, ends_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,slug)
);
CREATE TABLE IF NOT EXISTS agency.travel_package_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), package_id uuid NOT NULL REFERENCES agency.travel_packages(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL, item_type text NOT NULL, quantity int NOT NULL DEFAULT 1, price_minor bigint NOT NULL DEFAULT 0, sort_order int NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS agency.availability_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL, date date NOT NULL, capacity int NOT NULL DEFAULT 0, reserved int NOT NULL DEFAULT 0, blocked int NOT NULL DEFAULT 0,
  source text NOT NULL DEFAULT 'local', updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,listing_id,date)
);
CREATE TABLE IF NOT EXISTS agency.supplier_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  supplier_id uuid NOT NULL, quality_score numeric(5,4), response_score numeric(5,4), cancellation_score numeric(5,4), margin_score numeric(5,4),
  customer_score numeric(5,4), total_score numeric(5,4), evidence jsonb NOT NULL DEFAULT '{}'::jsonb, updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,supplier_id)
);
CREATE TABLE IF NOT EXISTS agency.commission_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  name text NOT NULL, supplier_id uuid, channel text NOT NULL DEFAULT 'direct', category_code text, percentage numeric(7,4), fixed_minor bigint NOT NULL DEFAULT 0,
  starts_at timestamptz, ends_at timestamptz, active boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS agency.commerce_customer_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL, locale varchar(10) NOT NULL DEFAULT 'tr', currency varchar(3) NOT NULL DEFAULT 'TRY', preferences jsonb NOT NULL DEFAULT '{}'::jsonb,
  consent jsonb NOT NULL DEFAULT '{}'::jsonb, lifetime_value_minor bigint NOT NULL DEFAULT 0, updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,customer_id)
);
CREATE TABLE IF NOT EXISTS agency.recommendation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  customer_id uuid, source text NOT NULL DEFAULT 'ai', placement text NOT NULL, items jsonb NOT NULL DEFAULT '[]'::jsonb,
  selected_item uuid, converted boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.channel_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK(channel IN ('web','mobile','b2b','whatsapp','email','sms','google','meta','yandex','baidu','wechat','xiaohongshu')),
  config jsonb NOT NULL DEFAULT '{}'::jsonb, active boolean NOT NULL DEFAULT false, last_sync_at timestamptz, last_error text NOT NULL DEFAULT '', UNIQUE(tenant_id,channel)
);
CREATE INDEX IF NOT EXISTS agency_package_status_idx ON agency.travel_packages(tenant_id,status,starts_at);
CREATE INDEX IF NOT EXISTS agency_availability_date_idx ON agency.availability_snapshots(tenant_id,listing_id,date);
CREATE INDEX IF NOT EXISTS agency_recommendation_customer_idx ON agency.recommendation_events(tenant_id,customer_id,created_at);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.travel_packages,agency.travel_package_items,agency.availability_snapshots,agency.supplier_scores,agency.commission_rules,agency.commerce_customer_profiles,agency.recommendation_events,agency.channel_connections TO agency_app;
