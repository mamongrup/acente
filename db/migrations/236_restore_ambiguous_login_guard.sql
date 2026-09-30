-- Migration 081 replaced the three-argument login wrapper with a direct user
-- lookup, bypassing the tenant ambiguity guard in the four-argument function.
-- Keep the existing scoped login and its rate limiting as the single path.
CREATE OR REPLACE FUNCTION auth.login(p_email text, p_password text, p_token text)
RETURNS TABLE(tenant_id text, user_id text, display_name text, membership_type text, error_code text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth
AS $$
  SELECT * FROM auth.login(p_email, p_password, p_token, NULL::text)
$$;

REVOKE ALL ON FUNCTION auth.login(text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth.login(text,text,text) TO agency_app;
