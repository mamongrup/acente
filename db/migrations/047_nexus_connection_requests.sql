-- Acente tarafında NEXUS bağlantı talebi ve son onay durumu.
CREATE TABLE IF NOT EXISTS agency.nexus_connection_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  remote_request_id text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','error')),
  message text NOT NULL DEFAULT '',
  requested_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id)
);
CREATE INDEX IF NOT EXISTS agency_nexus_connection_requests_status_idx
  ON agency.nexus_connection_requests(tenant_id,status,updated_at DESC);
GRANT SELECT, INSERT, UPDATE, DELETE ON agency.nexus_connection_requests TO agency_app;
