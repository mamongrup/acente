-- The social delivery worker claims posts with a transient running state.
ALTER TABLE agency.social_posts
  DROP CONSTRAINT IF EXISTS social_posts_status_check;
ALTER TABLE agency.social_posts
  ADD CONSTRAINT social_posts_status_check
  CHECK (status IN ('queued', 'running', 'published', 'failed', 'cancelled'));
