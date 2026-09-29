-- Records created by an agency user remain distinguishable from legacy or
-- storefront records. Unassigned records are visible only to tenant staff.
ALTER TABLE agency.customers ADD COLUMN IF NOT EXISTS created_by_user_id uuid REFERENCES agency.users(id) ON DELETE SET NULL;
ALTER TABLE agency.reservations ADD COLUMN IF NOT EXISTS created_by_user_id uuid REFERENCES agency.users(id) ON DELETE SET NULL;
ALTER TABLE agency.offers ADD COLUMN IF NOT EXISTS created_by_user_id uuid REFERENCES agency.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS agency_customers_owner_idx ON agency.customers(tenant_id, created_by_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS agency_reservations_owner_idx ON agency.reservations(tenant_id, created_by_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS agency_offers_owner_idx ON agency.offers(tenant_id, created_by_user_id, created_at DESC);
