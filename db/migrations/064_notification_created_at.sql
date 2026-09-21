-- The notification UI and workers order by creation time. Older databases
-- lacked this column, which made the queue endpoint fail at runtime.
ALTER TABLE agency.notifications
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS agency_notifications_created_idx
  ON agency.notifications(tenant_id, created_at DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.notifications TO agency_app;
