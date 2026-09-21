CREATE TABLE IF NOT EXISTS agency.connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  name text NOT NULL, provider text NOT NULL, base_url text NOT NULL DEFAULT '', credentials jsonb NOT NULL DEFAULT '{}'::jsonb,
  active boolean NOT NULL DEFAULT false, last_health_at timestamptz, last_error text NOT NULL DEFAULT '', UNIQUE(tenant_id,name)
);
CREATE TABLE IF NOT EXISTS agency.listing_channels (
  listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE, connection_id uuid NOT NULL REFERENCES agency.connections(id) ON DELETE CASCADE,
  external_id text, status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','published','paused','failed')), last_synced_at timestamptz, error text NOT NULL DEFAULT '', PRIMARY KEY(listing_id,connection_id)
);
CREATE TABLE IF NOT EXISTS agency.sync_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE, connection_id uuid REFERENCES agency.connections(id) ON DELETE SET NULL,
  job_type text NOT NULL CHECK(job_type IN ('import','export','availability','prices','health')), status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','running','success','failed')),
  started_at timestamptz, finished_at timestamptz, items_count int NOT NULL DEFAULT 0, error text NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS agency.report_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  report_type text NOT NULL, period_start date NOT NULL, period_end date NOT NULL, data jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,report_type,period_start,period_end)
);
CREATE INDEX IF NOT EXISTS agency_connections_active_idx ON agency.connections(tenant_id,active);
CREATE INDEX IF NOT EXISTS agency_channel_status_idx ON agency.listing_channels(status,last_synced_at);
CREATE INDEX IF NOT EXISTS agency_sync_queue_idx ON agency.sync_jobs(tenant_id,status,started_at);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.connections,agency.listing_channels,agency.sync_jobs,agency.report_snapshots TO agency_app;
