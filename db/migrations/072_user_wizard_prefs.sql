-- Wizard görünüm tercihleri: JSON metin olarak saklanır.
-- { "mode": "stepper", "accordion_open": [1,3] }
ALTER TABLE agency.users ADD COLUMN IF NOT EXISTS wizard_prefs jsonb NULL;

-- auth.session() fonksiyonunu wizard_prefs ile güncelle
CREATE OR REPLACE FUNCTION auth.session(p_token text)
RETURNS TABLE(tenant_id text,user_id text,display_name text,membership_type text,theme_preference text,wizard_prefs jsonb)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,auth AS $$
 SELECT u.tenant_id::text,u.id::text,u.display_name,u.membership_type,u.theme_preference,u.wizard_prefs
 FROM auth.sessions s JOIN agency.users u ON u.id=s.user_id
 WHERE s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active;
$$;

CREATE OR REPLACE FUNCTION agency_auth.session(p_token text)
RETURNS TABLE(tenant_id text,user_id text,display_name text,membership_type text,theme_preference text,wizard_prefs jsonb)
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,public,agency,agency_auth AS $$
 SELECT u.tenant_id::text,u.id::text,u.display_name,u.membership_type,u.theme_preference,u.wizard_prefs
 FROM agency_auth.sessions s JOIN agency.users u ON u.id=s.user_id
 WHERE s.token_digest=encode(digest(p_token,'sha256'),'hex') AND s.expires_at>now() AND u.active;
$$;
