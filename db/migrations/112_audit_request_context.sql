ALTER TABLE agency.audit_logs
  ADD COLUMN IF NOT EXISTS user_agent text NOT NULL DEFAULT '';

ALTER TABLE agency.audit_log_archives
  ADD COLUMN IF NOT EXISTS user_agent text NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS agency_audit_logs_user_idx
  ON agency.audit_logs(tenant_id,user_id,created_at DESC);

COMMENT ON COLUMN agency.audit_logs.user_agent IS
  'Best-effort request user-agent for admin-visible audit context. Must not contain secrets.';
