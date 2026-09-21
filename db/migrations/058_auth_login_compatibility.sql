-- 058: preserve the original three-argument auth.login contract for existing
-- callers while the four-argument form supports an optional tenant slug.
CREATE OR REPLACE FUNCTION auth.login(p_email text, p_password text, p_token text)
RETURNS TABLE(tenant_id text, user_id text, display_name text, membership_type text, error_code text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth
AS $$
  SELECT * FROM auth.login(p_email, p_password, p_token, NULL::text)
$$;

GRANT EXECUTE ON FUNCTION auth.login(text, text, text) TO agency_app;
