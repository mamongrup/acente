-- AI çalışanları için orkestrasyon, bilgi, güvenlik ve ölçüm katmanı.
CREATE TABLE IF NOT EXISTS agency.ai_workflow_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  workflow_key text NOT NULL, trigger_type text NOT NULL DEFAULT 'scheduled', input jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','running','waiting_approval','completed','failed','cancelled')),
  current_step text NOT NULL DEFAULT '', outputs jsonb NOT NULL DEFAULT '{}'::jsonb, error text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.ai_policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  policy_key text NOT NULL, name text NOT NULL, rules jsonb NOT NULL DEFAULT '{}'::jsonb, active boolean NOT NULL DEFAULT true,
  version int NOT NULL DEFAULT 1, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,policy_key)
);
CREATE TABLE IF NOT EXISTS agency.ai_knowledge_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  source_type text NOT NULL, source_id uuid, language_code varchar(10) NOT NULL DEFAULT 'tr', title text NOT NULL DEFAULT '',
  content text NOT NULL DEFAULT '', embedding_ref text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','indexed','failed','archived')),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.ai_model_routes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  task_type text NOT NULL, provider text NOT NULL, model text NOT NULL, max_cost_minor bigint, priority int NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true, UNIQUE(tenant_id,task_type,provider,model)
);
CREATE TABLE IF NOT EXISTS agency.ai_usage_costs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  task_id uuid, provider text NOT NULL, model text NOT NULL, input_tokens int NOT NULL DEFAULT 0, output_tokens int NOT NULL DEFAULT 0,
  cost_minor bigint NOT NULL DEFAULT 0, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.ai_experiments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  experiment_key text NOT NULL, entity_type text NOT NULL, variants jsonb NOT NULL DEFAULT '[]'::jsonb, metric text NOT NULL DEFAULT 'conversion_rate',
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','running','paused','completed')), winner text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,experiment_key)
);
CREATE TABLE IF NOT EXISTS agency.ai_feedback_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  task_id uuid, reviewer_id uuid, decision text NOT NULL CHECK(decision IN ('accepted','edited','rejected','corrected')), feedback text NOT NULL DEFAULT '',
  original jsonb NOT NULL DEFAULT '{}'::jsonb, final jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.ai_security_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK(event_type IN ('prompt_injection','pii_detected','policy_violation','tool_abuse','unusual_cost','permission_denied')),
  severity text NOT NULL DEFAULT 'medium' CHECK(severity IN ('low','medium','high','critical')), details jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','reviewed','resolved')), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_ai_workflow_queue_idx ON agency.ai_workflow_runs(tenant_id,status,created_at);
CREATE INDEX IF NOT EXISTS agency_ai_knowledge_status_idx ON agency.ai_knowledge_documents(tenant_id,status,language_code);
CREATE INDEX IF NOT EXISTS agency_ai_cost_period_idx ON agency.ai_usage_costs(tenant_id,created_at);
CREATE INDEX IF NOT EXISTS agency_ai_security_open_idx ON agency.ai_security_events(tenant_id,status,severity);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.ai_workflow_runs,agency.ai_policies,agency.ai_knowledge_documents,agency.ai_model_routes,agency.ai_usage_costs,agency.ai_experiments,agency.ai_feedback_events,agency.ai_security_events TO agency_app;
