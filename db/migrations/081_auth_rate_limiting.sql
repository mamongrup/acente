-- Rate limiting for failed login attempts
-- Adds tracking columns to agency.users and updates the login function.

-- 1. Add tracking columns to users table
ALTER TABLE agency.users ADD COLUMN IF NOT EXISTS failed_login_attempts integer NOT NULL DEFAULT 0;
ALTER TABLE agency.users ADD COLUMN IF NOT EXISTS locked_until timestamptz NULL;

-- 2. Update the login function with rate limiting logic
DROP FUNCTION IF EXISTS auth.login(text,text,text);
CREATE OR REPLACE FUNCTION auth.login(p_email text, p_password text, p_token text)
RETURNS TABLE(tenant_id text, user_id text, display_name text, membership_type text, error_code text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth
AS $$
DECLARE
  u agency.users%ROWTYPE;
  max_attempts constant integer := 5;
  lockout_minutes constant integer := 15;
BEGIN
  -- Find the user
  SELECT * INTO u FROM agency.users WHERE lower(email) = lower(trim(p_email)) AND active FOR UPDATE;

  IF NOT FOUND THEN
    error_code := 'invalid_credentials';
    RETURN NEXT;
    RETURN;
  END IF;

  -- Check if account is locked
  IF u.locked_until IS NOT NULL AND u.locked_until > now() THEN
    error_code := 'account_locked';
    RETURN NEXT;
    RETURN;
  END IF;

  -- Reset lockout if expired
  IF u.locked_until IS NOT NULL AND u.locked_until <= now() THEN
    UPDATE agency.users SET failed_login_attempts = 0, locked_until = NULL WHERE id = u.id;
    u.failed_login_attempts := 0;
    u.locked_until := NULL;
  END IF;

  -- Verify password
  IF u.password_hash IS NULL OR crypt(p_password, u.password_hash) <> u.password_hash THEN
    -- Increment failed attempts
    u.failed_login_attempts := u.failed_login_attempts + 1;

    IF u.failed_login_attempts >= max_attempts THEN
      -- Lock the account
      UPDATE agency.users
      SET failed_login_attempts = u.failed_login_attempts,
          locked_until = now() + (lockout_minutes || ' minutes')::interval
      WHERE id = u.id;
      error_code := 'account_locked';
    ELSE
      UPDATE agency.users
      SET failed_login_attempts = u.failed_login_attempts
      WHERE id = u.id;
      error_code := 'invalid_credentials';
    END IF;

    RETURN NEXT;
    RETURN;
  END IF;

  -- Success: reset failed attempts and lockout
  UPDATE agency.users
  SET failed_login_attempts = 0, locked_until = NULL
  WHERE id = u.id;

  -- Create session
  INSERT INTO auth.sessions(token_digest, user_id, expires_at)
  VALUES(encode(digest(p_token, 'sha256'), 'hex'), u.id, now() + interval '8 hours')
  ON CONFLICT(token_digest) DO UPDATE SET expires_at = excluded.expires_at, user_id = excluded.user_id;

  tenant_id := u.tenant_id::text;
  user_id := u.id::text;
  display_name := u.display_name;
  membership_type := u.membership_type;
  error_code := NULL;
  RETURN NEXT;
END $$;

-- 3. Update grants
GRANT EXECUTE ON FUNCTION auth.login(text,text,text) TO agency_app;

-- 4. Add index for cleanup queries
CREATE INDEX IF NOT EXISTS idx_users_locked_until ON agency.users(locked_until) WHERE locked_until IS NOT NULL;
