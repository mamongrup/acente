-- RAG indeksleri ve Google Merchant/kanal feed yaşam döngüsü.
CREATE TABLE IF NOT EXISTS agency.ai_knowledge_chunks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), document_id uuid NOT NULL REFERENCES agency.ai_knowledge_documents(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE, chunk_index int NOT NULL, content text NOT NULL,
  embedding_ref text NOT NULL DEFAULT '', metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(document_id,chunk_index)
);
CREATE TABLE IF NOT EXISTS agency.commerce_feeds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK(provider IN ('google_merchant','meta_catalog','yandex','baidu','wechat')),
  feed_type text NOT NULL DEFAULT 'products', url_slug text NOT NULL, locale varchar(10) NOT NULL DEFAULT 'tr', currency varchar(3) NOT NULL DEFAULT 'TRY',
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','ready','published','failed','paused')), item_count int NOT NULL DEFAULT 0,
  last_generated_at timestamptz, last_published_at timestamptz, last_error text NOT NULL DEFAULT '', UNIQUE(tenant_id,provider,locale,currency)
);
CREATE TABLE IF NOT EXISTS agency.ai_test_cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  suite_key text NOT NULL, name text NOT NULL, input jsonb NOT NULL DEFAULT '{}'::jsonb, expected jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_result text NOT NULL DEFAULT 'pending' CHECK(last_result IN ('pending','passed','failed')), last_run_at timestamptz, UNIQUE(tenant_id,suite_key,name)
);
CREATE INDEX IF NOT EXISTS agency_ai_chunks_tenant_idx ON agency.ai_knowledge_chunks(tenant_id,document_id);
CREATE INDEX IF NOT EXISTS agency_commerce_feeds_status_idx ON agency.commerce_feeds(tenant_id,provider,status);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.ai_knowledge_chunks,agency.commerce_feeds,agency.ai_test_cases TO agency_app;
