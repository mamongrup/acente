CREATE TABLE IF NOT EXISTS agency.analytics_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  event_name text NOT NULL, entity_type text, entity_id uuid, session_key text, user_id uuid REFERENCES agency.users(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb, occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.daily_metrics (
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE, metric_date date NOT NULL, metric_name text NOT NULL,
  metric_value numeric(18,4) NOT NULL DEFAULT 0, dimensions jsonb NOT NULL DEFAULT '{}'::jsonb, PRIMARY KEY(tenant_id,metric_date,metric_name)
);
CREATE INDEX IF NOT EXISTS agency_analytics_events_lookup_idx ON agency.analytics_events(tenant_id,event_name,occurred_at DESC);
CREATE INDEX IF NOT EXISTS agency_analytics_entity_idx ON agency.analytics_events(tenant_id,entity_type,entity_id,occurred_at DESC);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.analytics_events,agency.daily_metrics TO agency_app;
