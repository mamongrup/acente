-- Preserve per-day prices received from the NEXUS inventory feed.
ALTER TABLE agency.availability
  ADD COLUMN IF NOT EXISTS price_minor bigint;

ALTER TABLE agency.availability
  DROP CONSTRAINT IF EXISTS agency_availability_price_minor_check;

ALTER TABLE agency.availability
  ADD CONSTRAINT agency_availability_price_minor_check
  CHECK (price_minor IS NULL OR price_minor >= 0);

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.availability TO agency_app;
