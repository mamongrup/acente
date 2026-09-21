-- Add password_hash column that was missing from the original users table definition
-- but is required by the auth.login and agency_auth.login functions.
ALTER TABLE agency.users ADD COLUMN IF NOT EXISTS password_hash text;
