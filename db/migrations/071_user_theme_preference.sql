-- Tema tercihi kullanıcı hesabında saklanır (sunucu tarafı).
-- Session fonksiyonları tercihi 5. sütun olarak döndürür; NULL ise
-- uygulama varsayılanına (dark/Abyss) düşer.
ALTER TABLE agency.users ADD COLUMN IF NOT EXISTS theme_preference text NULL;

-- Postgres, RETURNS TABLE imzası değişen fonksiyona CREATE OR REPLACE
-- ile izin vermez; önce düşürmek gerekir.
DROP FUNCTION IF EXISTS auth.session(text);
DROP FUNCTION IF EXISTS agency_auth.session(text);

CREATE OR REPLACE FUNCTION auth.session(p_token text)
RETURNS TABLE(tenant_id text,user_id text,display_name text,membership_type text,theme_preference text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth AS $$
 SELECT u.tenant_id::text,u.id::text,u.display_name,u.membership_type,u.theme_preference
 FROM auth.sessions s JOIN agency.users u ON u.id=s.user_id
 WHERE s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active;
$$;

CREATE OR REPLACE FUNCTION agency_auth.session(p_token text)
RETURNS TABLE(tenant_id text,user_id text,display_name text,membership_type text,theme_preference text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,agency_auth AS $$
 SELECT u.tenant_id::text,u.id::text,u.display_name,u.membership_type,u.theme_preference
 FROM agency_auth.sessions s JOIN agency.users u ON u.id=s.user_id
 WHERE s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active;
$$;
