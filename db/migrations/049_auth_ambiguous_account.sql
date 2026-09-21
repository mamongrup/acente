-- 049: deterministic multi-tenant login and role boundary support.
-- The UI has one e-mail field, so two active accounts sharing an e-mail cannot
-- be selected safely. Return a dedicated error instead of logging into an
-- arbitrary tenant.
DROP FUNCTION IF EXISTS auth.login(text, text, text);

CREATE FUNCTION auth.login(p_email text, p_password text, p_token text)
RETURNS TABLE(tenant_id text, user_id text, display_name text, membership_type text, error_code text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth
AS $$
DECLARE
  u agency.users%ROWTYPE;
  normalized_email text := lower(trim(p_email));
  matching_accounts integer;
  max_attempts constant integer := 5;
  lockout_minutes constant integer := 15;
BEGIN
  -- Serialize attempts for the same identifier and make duplicate-account
  -- handling deterministic under concurrent logins.
  PERFORM pg_advisory_xact_lock(hashtext(normalized_email));
  SELECT count(*) INTO matching_accounts
    FROM agency.users
   WHERE lower(email) = normalized_email
     AND active;

  IF matching_accounts = 0 THEN
    error_code := 'invalid_credentials';
    RETURN NEXT;
    RETURN;
  END IF;

  IF matching_accounts > 1 THEN
    error_code := 'ambiguous_account';
    RETURN NEXT;
    RETURN;
  END IF;

  SELECT * INTO u
    FROM agency.users
   WHERE lower(email) = normalized_email
     AND active
   LIMIT 1
   FOR UPDATE;

  IF u.locked_until IS NOT NULL AND u.locked_until > now() THEN
    error_code := 'account_locked';
    RETURN NEXT;
    RETURN;
  END IF;

  IF u.locked_until IS NOT NULL AND u.locked_until <= now() THEN
    UPDATE agency.users
       SET failed_login_attempts = 0, locked_until = NULL
     WHERE id = u.id;
    u.failed_login_attempts := 0;
    u.locked_until := NULL;
  END IF;

  IF u.password_hash IS NULL OR crypt(p_password, u.password_hash) <> u.password_hash THEN
    u.failed_login_attempts := u.failed_login_attempts + 1;
    IF u.failed_login_attempts >= max_attempts THEN
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

  UPDATE agency.users
     SET failed_login_attempts = 0, locked_until = NULL
   WHERE id = u.id;

  INSERT INTO auth.sessions(token_digest, user_id, expires_at)
  VALUES(encode(digest(p_token, 'sha256'), 'hex'), u.id, now() + interval '8 hours')
  ON CONFLICT(token_digest) DO UPDATE
    SET expires_at = excluded.expires_at, user_id = excluded.user_id;

  tenant_id := u.tenant_id::text;
  user_id := u.id::text;
  display_name := u.display_name;
  membership_type := u.membership_type;
  error_code := NULL;
  RETURN NEXT;
END $$;

GRANT EXECUTE ON FUNCTION auth.login(text, text, text) TO agency_app;
