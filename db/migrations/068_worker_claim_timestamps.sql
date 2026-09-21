-- Keep a durable claim timestamp so a crashed delivery worker can be recovered.
ALTER TABLE agency.notifications
  ADD COLUMN IF NOT EXISTS started_at timestamptz;

ALTER TABLE agency.social_posts
  ADD COLUMN IF NOT EXISTS started_at timestamptz;

CREATE INDEX IF NOT EXISTS agency_notifications_running_idx
  ON agency.notifications(status, started_at)
  WHERE status = 'running';

CREATE INDEX IF NOT EXISTS agency_social_running_idx
  ON agency.social_posts(status, started_at)
  WHERE status = 'running';

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.notifications, agency.social_posts TO agency_app;
