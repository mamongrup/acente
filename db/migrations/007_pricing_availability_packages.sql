CREATE TABLE IF NOT EXISTS agency.rate_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  name text NOT NULL, currency char(3) NOT NULL DEFAULT 'TRY', base_minor bigint NOT NULL DEFAULT 0 CHECK(base_minor>=0),
  commission_percent numeric(8,3) NOT NULL DEFAULT 0, deposit_percent numeric(8,3) NOT NULL DEFAULT 100,
  min_nights int NOT NULL DEFAULT 1 CHECK(min_nights>0), cancellation_policy jsonb NOT NULL DEFAULT '{}'::jsonb, active boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS agency.rate_periods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), rate_plan_id uuid NOT NULL REFERENCES agency.rate_plans(id) ON DELETE CASCADE,
  starts_on date NOT NULL, ends_on date NOT NULL, price_minor bigint NOT NULL CHECK(price_minor>=0), min_nights int, UNIQUE(rate_plan_id,starts_on,ends_on)
);
CREATE TABLE IF NOT EXISTS agency.availability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  day date NOT NULL, units_total int NOT NULL DEFAULT 1 CHECK(units_total>=0), units_available int NOT NULL DEFAULT 1 CHECK(units_available>=0), closed boolean NOT NULL DEFAULT false,
  UNIQUE(listing_id,day)
);
CREATE TABLE IF NOT EXISTS agency.ical_feeds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  url text NOT NULL, day_offset int NOT NULL DEFAULT 0, active boolean NOT NULL DEFAULT true, last_synced_at timestamptz, last_error text NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS agency.packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  name text NOT NULL, description text NOT NULL DEFAULT '', currency char(3) NOT NULL DEFAULT 'TRY', price_minor bigint NOT NULL DEFAULT 0, active boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS agency.package_items (
  package_id uuid NOT NULL REFERENCES agency.packages(id) ON DELETE CASCADE, listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  required boolean NOT NULL DEFAULT false, sort_order int NOT NULL DEFAULT 0, PRIMARY KEY(package_id,listing_id)
);
CREATE INDEX IF NOT EXISTS agency_rate_periods_dates_idx ON agency.rate_periods(rate_plan_id,starts_on,ends_on);
CREATE INDEX IF NOT EXISTS agency_availability_day_idx ON agency.availability(listing_id,day);
CREATE INDEX IF NOT EXISTS agency_packages_tenant_idx ON agency.packages(tenant_id,active);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.rate_plans,agency.rate_periods,agency.availability,agency.ical_feeds,agency.packages,agency.package_items TO agency_app;
