-- Make NEXUS reservation delivery claims recoverable after a worker crash.
ALTER TABLE agency.nexus_reservation_deliveries
  ADD COLUMN IF NOT EXISTS started_at timestamptz;

CREATE INDEX IF NOT EXISTS agency_nexus_reservation_delivery_processing_idx
  ON agency.nexus_reservation_deliveries(status, started_at)
  WHERE status = 'processing';

GRANT SELECT, INSERT, UPDATE ON agency.nexus_reservation_deliveries TO agency_app;
