CREATE TABLE IF NOT EXISTS agency.carts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES agency.customers(id) ON DELETE SET NULL, session_key text, status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','ordered','abandoned')),
  currency char(3) NOT NULL DEFAULT 'TRY', expires_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,session_key)
);
CREATE TABLE IF NOT EXISTS agency.cart_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), cart_id uuid NOT NULL REFERENCES agency.carts(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE, quantity int NOT NULL DEFAULT 1 CHECK(quantity>0), check_in date, check_out date, guests jsonb NOT NULL DEFAULT '{}'::jsonb,
  unit_minor bigint NOT NULL DEFAULT 0, total_minor bigint NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS agency.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES agency.customers(id) ON DELETE SET NULL, cart_id uuid REFERENCES agency.carts(id) ON DELETE SET NULL,
  number text NOT NULL, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','confirmed','cancelled','refunded','completed')),
  currency char(3) NOT NULL DEFAULT 'TRY', subtotal_minor bigint NOT NULL DEFAULT 0, discount_minor bigint NOT NULL DEFAULT 0, total_minor bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,number)
);
CREATE TABLE IF NOT EXISTS agency.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid NOT NULL REFERENCES agency.orders(id) ON DELETE CASCADE,
  provider text NOT NULL, provider_reference text, amount_minor bigint NOT NULL, currency char(3) NOT NULL DEFAULT 'TRY', status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','authorized','paid','failed','refunded')),
  raw_response jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.search_queries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  query text NOT NULL DEFAULT '', category_id uuid REFERENCES agency.categories(id) ON DELETE SET NULL, region_id uuid REFERENCES agency.regions(id) ON DELETE SET NULL,
  filters jsonb NOT NULL DEFAULT '{}'::jsonb, result_count int NOT NULL DEFAULT 0, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_cart_expiry_idx ON agency.carts(tenant_id,status,expires_at);
CREATE INDEX IF NOT EXISTS agency_orders_customer_idx ON agency.orders(tenant_id,customer_id,created_at DESC);
CREATE INDEX IF NOT EXISTS agency_payments_status_idx ON agency.payments(status,created_at);
CREATE INDEX IF NOT EXISTS agency_search_queries_idx ON agency.search_queries(tenant_id,created_at DESC);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.carts,agency.cart_items,agency.orders,agency.payments,agency.search_queries TO agency_app;
