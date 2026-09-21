-- Dil tercihi kullanıcı hesabında saklanır (sunucu tarafı).
-- Session fonksiyonları tercihi 7. sütun olarak döndürür; NULL ise uygulama
-- varsayılanına (en) düşer. Kabul edilen değerler: tr, en, de, ru.
ALTER TABLE agency.users ADD COLUMN IF NOT EXISTS language_pref text NULL;

-- Postgres, RETURNS TABLE imzası değişen fonksiyona CREATE OR REPLACE
-- ile izin vermez; önce düşürmek gerekir.
DROP FUNCTION IF EXISTS auth.session(text);
DROP FUNCTION IF EXISTS agency_auth.session(text);

CREATE OR REPLACE FUNCTION auth.session(p_token text)
RETURNS TABLE(tenant_id text,user_id text,display_name text,membership_type text,theme_preference text,wizard_prefs jsonb,language_pref text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth AS $$
 SELECT u.tenant_id::text,u.id::text,u.display_name,u.membership_type,u.theme_preference,u.wizard_prefs,u.language_pref
 FROM auth.sessions s JOIN agency.users u ON u.id=s.user_id
 WHERE s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active;
$$;

CREATE OR REPLACE FUNCTION agency_auth.session(p_token text)
RETURNS TABLE(tenant_id text,user_id text,display_name text,membership_type text,theme_preference text,wizard_prefs jsonb,language_pref text)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,agency_auth AS $$
 SELECT u.tenant_id::text,u.id::text,u.display_name,u.membership_type,u.theme_preference,u.wizard_prefs,u.language_pref
 FROM agency_auth.sessions s JOIN agency.users u ON u.id=s.user_id
 WHERE s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active;
$$;
