CREATE TABLE IF NOT EXISTS agency.seo_metadata (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  entity_type text NOT NULL, entity_id uuid NOT NULL, language_code varchar(10) NOT NULL DEFAULT 'tr',
  title text NOT NULL DEFAULT '', description text NOT NULL DEFAULT '', keywords text NOT NULL DEFAULT '', canonical_url text NOT NULL DEFAULT '',
  UNIQUE(tenant_id,entity_type,entity_id,language_code)
);
CREATE TABLE IF NOT EXISTS agency.social_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  network text NOT NULL CHECK(network IN ('instagram','facebook','twitter','pinterest')), name text NOT NULL, body text NOT NULL DEFAULT '',
  media_id uuid REFERENCES agency.media(id) ON DELETE SET NULL, active boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS agency.social_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  entity_type text NOT NULL, entity_id uuid NOT NULL, network text NOT NULL, content text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','published','failed','cancelled')),
  scheduled_at timestamptz, published_at timestamptz, error text NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS agency.ai_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK(provider IN ('openai','deepseek','anthropic','google')), model text NOT NULL, token_encrypted text NOT NULL DEFAULT '', active boolean NOT NULL DEFAULT false,
  UNIQUE(tenant_id,provider,model)
);
CREATE TABLE IF NOT EXISTS agency.ai_assignments (
  provider_id uuid NOT NULL REFERENCES agency.ai_providers(id) ON DELETE CASCADE,
  scope text NOT NULL CHECK(scope IN ('title','description','seo','translation','image','support','social')), priority int NOT NULL DEFAULT 0, active boolean NOT NULL DEFAULT true,
  PRIMARY KEY(provider_id,scope)
);
CREATE INDEX IF NOT EXISTS agency_seo_entity_idx ON agency.seo_metadata(tenant_id,entity_type,entity_id,language_code);
CREATE INDEX IF NOT EXISTS agency_social_queue_idx ON agency.social_posts(tenant_id,status,scheduled_at);
CREATE INDEX IF NOT EXISTS agency_ai_active_idx ON agency.ai_providers(tenant_id,active);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.seo_metadata,agency.social_templates,agency.social_posts,agency.ai_providers,agency.ai_assignments TO agency_app;
