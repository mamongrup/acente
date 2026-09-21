CREATE TABLE IF NOT EXISTS agency.task_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid REFERENCES agency.tenants(id) ON DELETE CASCADE, task_name text NOT NULL,
  status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','running','success','failed')), attempt int NOT NULL DEFAULT 0, locked_until timestamptz,
  started_at timestamptz, finished_at timestamptz, error text NOT NULL DEFAULT '', payload jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE IF NOT EXISTS agency.health_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid REFERENCES agency.tenants(id) ON DELETE CASCADE, component text NOT NULL,
  status text NOT NULL CHECK(status IN ('ok','degraded','down')), latency_ms int, details jsonb NOT NULL DEFAULT '{}'::jsonb, checked_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_task_runs_queue_idx ON agency.task_runs(status,locked_until,started_at);
CREATE INDEX IF NOT EXISTS agency_health_checks_component_idx ON agency.health_checks(tenant_id,component,checked_at DESC);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.task_runs,agency.health_checks TO agency_app;
