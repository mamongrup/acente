CREATE TABLE IF NOT EXISTS agency.api_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  label text NOT NULL, key_prefix text NOT NULL, secret_hash text NOT NULL, scopes jsonb NOT NULL DEFAULT '[]'::jsonb,
  last_used_at timestamptz, expires_at timestamptz, revoked_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,key_prefix)
);
CREATE TABLE IF NOT EXISTS agency.webhooks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  endpoint text NOT NULL, secret_encrypted text NOT NULL DEFAULT '', events jsonb NOT NULL DEFAULT '[]'::jsonb, active boolean NOT NULL DEFAULT true,
  last_delivered_at timestamptz, last_error text NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS agency.events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  event_key text NOT NULL, aggregate_type text NOT NULL, aggregate_id uuid, payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,event_key)
);
CREATE TABLE IF NOT EXISTS agency.webhook_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), webhook_id uuid NOT NULL REFERENCES agency.webhooks(id) ON DELETE CASCADE, event_id uuid NOT NULL REFERENCES agency.events(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','delivered','failed')), attempts int NOT NULL DEFAULT 0, next_attempt_at timestamptz, response_code int, error text NOT NULL DEFAULT '', UNIQUE(webhook_id,event_id)
);
CREATE INDEX IF NOT EXISTS agency_api_keys_active_idx ON agency.api_keys(tenant_id,revoked_at,expires_at);
CREATE INDEX IF NOT EXISTS agency_events_time_idx ON agency.events(tenant_id,occurred_at DESC);
CREATE INDEX IF NOT EXISTS agency_webhook_delivery_queue_idx ON agency.webhook_deliveries(status,next_attempt_at);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.api_keys,agency.webhooks,agency.events,agency.webhook_deliveries TO agency_app;
