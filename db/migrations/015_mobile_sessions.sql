CREATE TABLE IF NOT EXISTS agency.refresh_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE, device_id uuid REFERENCES agency.devices(id) ON DELETE CASCADE, expires_at timestamptz NOT NULL, revoked_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.app_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), platform text NOT NULL CHECK(platform IN ('ios','android','web')), version text NOT NULL, min_supported_version text NOT NULL DEFAULT '', release_notes text NOT NULL DEFAULT '', active boolean NOT NULL DEFAULT true, released_at timestamptz NOT NULL DEFAULT now(), UNIQUE(platform,version)
);
CREATE INDEX IF NOT EXISTS agency_refresh_tokens_user_idx ON agency.refresh_tokens(user_id,revoked_at,expires_at);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.refresh_tokens,agency.app_versions TO agency_app;
