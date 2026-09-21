-- Delivery metadata makes queued notifications observable and safely retryable.
ALTER TABLE agency.notifications
  ADD COLUMN IF NOT EXISTS attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_error text NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS agency_notifications_delivery_idx
  ON agency.notifications(status, scheduled_at, next_attempt_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.notifications TO agency_app;
