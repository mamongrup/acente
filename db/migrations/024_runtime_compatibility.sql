DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agency_app') THEN
    CREATE ROLE agency_app LOGIN PASSWORD 'change-this-agency-app-password';
  END IF;
END $$;
GRANT CONNECT ON DATABASE nexustraveltech TO agency_app;
GRANT USAGE ON SCHEMA agency,auth TO agency_app;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA agency TO agency_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA agency GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO agency_app;
ALTER TABLE IF EXISTS auth.sessions ADD COLUMN IF NOT EXISTS token_digest text;
ALTER TABLE IF EXISTS auth.sessions ADD COLUMN IF NOT EXISTS user_id uuid;
ALTER TABLE IF EXISTS auth.sessions ADD COLUMN IF NOT EXISTS expires_at timestamptz;
CREATE INDEX IF NOT EXISTS auth_sessions_token_digest_idx ON auth.sessions(token_digest);
