-- Normalize auth.login after older installations kept the four-column return type.
-- CREATE OR REPLACE cannot change a function's OUT parameter type, so this is an
-- explicit forward migration and preserves the rate-limit behavior.
ALTER TABLE agency.users ADD COLUMN IF NOT EXISTS failed_login_attempts integer NOT NULL DEFAULT 0;
ALTER TABLE agency.users ADD COLUMN IF NOT EXISTS locked_until timestamptz NULL;

DROP FUNCTION IF EXISTS auth.login(text, text, text);

CREATE FUNCTION auth.login(p_email text, p_password text, p_token text)
RETURNS TABLE(tenant_id text, user_id text, display_name text, membership_type text, error_code text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth
AS $$
DECLARE
  u agency.users%ROWTYPE;
BEGIN
  SELECT * INTO u FROM agency.users
  WHERE lower(email) = lower(trim(p_email)) AND active
  FOR UPDATE;

  IF NOT FOUND THEN error_code := 'invalid_credentials'; RETURN NEXT; RETURN; END IF;
  IF u.locked_until IS NOT NULL AND u.locked_until > now() THEN
    error_code := 'account_locked'; RETURN NEXT; RETURN;
  END IF;
  IF u.locked_until IS NOT NULL AND u.locked_until <= now() THEN
    UPDATE agency.users SET failed_login_attempts = 0, locked_until = NULL WHERE id = u.id;
    u.failed_login_attempts := 0;
  END IF;

  IF u.password_hash IS NULL OR crypt(p_password, u.password_hash) <> u.password_hash THEN
    u.failed_login_attempts := u.failed_login_attempts + 1;
    IF u.failed_login_attempts >= 5 THEN
      UPDATE agency.users SET failed_login_attempts = u.failed_login_attempts,
        locked_until = now() + interval '15 minutes' WHERE id = u.id;
      error_code := 'account_locked';
    ELSE
      UPDATE agency.users SET failed_login_attempts = u.failed_login_attempts WHERE id = u.id;
      error_code := 'invalid_credentials';
    END IF;
    RETURN NEXT; RETURN;
  END IF;

  UPDATE agency.users SET failed_login_attempts = 0, locked_until = NULL WHERE id = u.id;
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

GRANT EXECUTE ON FUNCTION auth.login(text, text, text) TO agency_app;
