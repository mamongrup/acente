CREATE TABLE IF NOT EXISTS agency.listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  code text NOT NULL,
  category text NOT NULL,
  title text NOT NULL,
  locality text NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  currency char(3) NOT NULL DEFAULT 'TRY',
  price_minor bigint NOT NULL DEFAULT 0 CHECK(price_minor >= 0),
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','review','published','paused','archived')),
  source text NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','nexus','api')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,code)
);
CREATE INDEX IF NOT EXISTS agency_listings_search_idx ON agency.listings(tenant_id,status,category,locality);
CREATE INDEX IF NOT EXISTS agency_listings_title_idx ON agency.listings USING gin(to_tsvector('simple',title||' '||locality));

CREATE TABLE IF NOT EXISTS agency.customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  full_name text NOT NULL,
  email text NOT NULL DEFAULT '',
  phone text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,email)
);
CREATE INDEX IF NOT EXISTS agency_customers_tenant_idx ON agency.customers(tenant_id,created_at DESC);

CREATE TABLE IF NOT EXISTS agency.reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES agency.listings(id) ON DELETE SET NULL,
  customer_id uuid REFERENCES agency.customers(id) ON DELETE SET NULL,
  reference_code text NOT NULL UNIQUE,
  check_in date,
  check_out date,
  guest_count int NOT NULL DEFAULT 1 CHECK(guest_count > 0),
  total_minor bigint NOT NULL DEFAULT 0 CHECK(total_minor >= 0),
  currency char(3) NOT NULL DEFAULT 'TRY',
  status text NOT NULL DEFAULT 'inquiry' CHECK(status IN ('inquiry','option','confirmed','cancelled','completed')),
  payment_status text NOT NULL DEFAULT 'unpaid' CHECK(payment_status IN ('unpaid','pending','paid','refunded')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_reservations_tenant_status_idx ON agency.reservations(tenant_id,status,created_at DESC);
