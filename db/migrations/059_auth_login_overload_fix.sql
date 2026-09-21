-- 059: PostgreSQL cannot resolve a three-argument call when a four-argument
-- function has a default value. Keep both explicit arities instead.
DROP FUNCTION IF EXISTS auth.login(text, text, text, text);

CREATE FUNCTION auth.login(
  p_email text,
  p_password text,
  p_token text,
  p_tenant_slug text
)
RETURNS TABLE(tenant_id text, user_id text, display_name text, membership_type text, error_code text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth
AS $$
DECLARE
  u agency.users%ROWTYPE;
  normalized_email text := lower(trim(p_email));
  tenant_filter text := NULLIF(lower(trim(coalesce(p_tenant_slug, ''))), '');
  matching_accounts integer;
  max_attempts constant integer := 5;
  lockout_minutes constant integer := 15;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(normalized_email));

  SELECT count(*) INTO matching_accounts
  FROM agency.users x
  LEFT JOIN agency.tenants t ON t.id = x.tenant_id
  WHERE lower(x.email) = normalized_email
    AND x.active
    AND (tenant_filter IS NULL OR lower(t.slug) = tenant_filter);

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

  SELECT x.* INTO u
  FROM agency.users x
  LEFT JOIN agency.tenants t ON t.id = x.tenant_id
  WHERE lower(x.email) = normalized_email
    AND x.active
    AND (tenant_filter IS NULL OR lower(t.slug) = tenant_filter)
  LIMIT 1
  FOR UPDATE;

  IF u.locked_until IS NOT NULL AND u.locked_until > now() THEN
    error_code := 'account_locked';
    RETURN NEXT;
    RETURN;
  END IF;
  IF u.locked_until IS NOT NULL AND u.locked_until <= now() THEN
    UPDATE agency.users SET failed_login_attempts = 0, locked_until = NULL WHERE id = u.id;
    u.failed_login_attempts := 0;
    u.locked_until := NULL;
  END IF;

  IF u.password_hash IS NULL OR crypt(p_password, u.password_hash) <> u.password_hash THEN
    u.failed_login_attempts := u.failed_login_attempts + 1;
    IF u.failed_login_attempts >= max_attempts THEN
      UPDATE agency.users SET failed_login_attempts = u.failed_login_attempts, locked_until = now() + (lockout_minutes || ' minutes')::interval WHERE id = u.id;
      error_code := 'account_locked';
    ELSE
      UPDATE agency.users SET failed_login_attempts = u.failed_login_attempts WHERE id = u.id;
      error_code := 'invalid_credentials';
    END IF;
    RETURN NEXT;
    RETURN;
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

GRANT EXECUTE ON FUNCTION auth.login(text, text, text, text) TO agency_app;
