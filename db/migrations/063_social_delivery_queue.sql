-- Social delivery supports the requested Threads channel and retry metadata.
ALTER TABLE agency.social_posts
  ADD COLUMN IF NOT EXISTS attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE agency.social_templates
  DROP CONSTRAINT IF EXISTS social_templates_network_check;
ALTER TABLE agency.social_templates
  ADD CONSTRAINT social_templates_network_check
  CHECK (network IN ('instagram','facebook','threads','pinterest'));

CREATE INDEX IF NOT EXISTS agency_social_delivery_idx
  ON agency.social_posts(status, scheduled_at, next_attempt_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.social_posts, agency.social_templates TO agency_app;
