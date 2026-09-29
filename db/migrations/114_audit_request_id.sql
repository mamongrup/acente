ALTER TABLE agency.audit_logs
  ADD COLUMN IF NOT EXISTS request_id text NOT NULL DEFAULT '';

ALTER TABLE agency.audit_log_archives
  ADD COLUMN IF NOT EXISTS request_id text NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS agency_audit_logs_request_idx
  ON agency.audit_logs(tenant_id,request_id,created_at DESC)
  WHERE request_id <> '';

COMMENT ON COLUMN agency.audit_logs.request_id IS
  'HTTP correlation/request id for tracing an operation across logs and integrations.';

