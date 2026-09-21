-- Keep coupons aligned with campaign audience routing for agency and supplier sales.
ALTER TABLE agency.coupons
  ADD COLUMN IF NOT EXISTS audience text NOT NULL DEFAULT 'all';

CREATE INDEX IF NOT EXISTS agency_coupons_audience_idx
  ON agency.coupons (tenant_id, audience, active, starts_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.coupons TO agency_app;
