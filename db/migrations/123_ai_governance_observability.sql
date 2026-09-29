-- AI kurumsal gözlemleme, gizlilik ve geri alma katmanı.
CREATE TABLE IF NOT EXISTS agency.ai_worker_health (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  worker_key text NOT NULL, status text NOT NULL DEFAULT 'unknown' CHECK(status IN ('healthy','degraded','stopped','unknown')),
  last_heartbeat timestamptz, queue_depth int NOT NULL DEFAULT 0, error_count int NOT NULL DEFAULT 0, details jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,worker_key)
);
CREATE TABLE IF NOT EXISTS agency.ai_prompt_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  prompt_key text NOT NULL, version int NOT NULL DEFAULT 1, template text NOT NULL, model text NOT NULL DEFAULT '', active boolean NOT NULL DEFAULT false,
  created_by uuid, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,prompt_key,version)
);
CREATE TABLE IF NOT EXISTS agency.ai_budget_limits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  scope text NOT NULL, period text NOT NULL DEFAULT 'monthly', limit_minor bigint NOT NULL, used_minor bigint NOT NULL DEFAULT 0,
  alert_percent int NOT NULL DEFAULT 80, active boolean NOT NULL DEFAULT true, UNIQUE(tenant_id,scope,period)
);
CREATE TABLE IF NOT EXISTS agency.ai_privacy_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK(event_type IN ('pii_masked','consent_granted','consent_revoked','erasure_requested','erasure_completed','export_requested','export_completed')),
  subject_id uuid, fields jsonb NOT NULL DEFAULT '[]'::jsonb, status text NOT NULL DEFAULT 'recorded', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.ai_release_channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  module_key text NOT NULL, version text NOT NULL, channel text NOT NULL DEFAULT 'canary' CHECK(channel IN ('canary','stable','rollback')),
  audience jsonb NOT NULL DEFAULT '{}'::jsonb, active boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,module_key,version)
);
CREATE TABLE IF NOT EXISTS agency.ai_decision_audits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  task_id uuid, module_key text NOT NULL, prompt_version_id uuid, model text NOT NULL DEFAULT '', input_hash text NOT NULL DEFAULT '',
  decision jsonb NOT NULL DEFAULT '{}'::jsonb, rationale text NOT NULL DEFAULT '', confidence numeric(5,4), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_ai_health_status_idx ON agency.ai_worker_health(tenant_id,status,last_heartbeat);
CREATE INDEX IF NOT EXISTS agency_ai_privacy_subject_idx ON agency.ai_privacy_events(tenant_id,subject_id,created_at);
CREATE INDEX IF NOT EXISTS agency_ai_decision_module_idx ON agency.ai_decision_audits(tenant_id,module_key,created_at);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.ai_worker_health,agency.ai_prompt_versions,agency.ai_budget_limits,agency.ai_privacy_events,agency.ai_release_channels,agency.ai_decision_audits TO agency_app;
