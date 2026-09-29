-- Long-term audit retention: keep recent rows in agency.audit_logs and move
-- older rows into an archive table. The function is tenant-safe and idempotent.

CREATE TABLE IF NOT EXISTS agency.audit_log_archives (
  id uuid PRIMARY KEY,
  tenant_id uuid REFERENCES agency.tenants(id) ON DELETE SET NULL,
  user_id uuid REFERENCES agency.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  ip inet,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL,
  archived_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS agency_audit_log_archives_tenant_idx
  ON agency.audit_log_archives(tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS agency_audit_log_archives_action_idx
  ON agency.audit_log_archives(action, created_at DESC);

CREATE OR REPLACE FUNCTION agency.archive_audit_logs(
  p_keep_days integer DEFAULT 365,
  p_batch_size integer DEFAULT 5000
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, agency
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  IF p_keep_days < 30 THEN
    RAISE EXCEPTION 'audit retention must keep at least 30 days';
  END IF;

  IF p_batch_size < 1 OR p_batch_size > 50000 THEN
    RAISE EXCEPTION 'audit archive batch size out of range';
  END IF;

  WITH moved AS (
    DELETE FROM agency.audit_logs a
     WHERE a.id IN (
       SELECT id
         FROM agency.audit_logs
        WHERE created_at < now() - make_interval(days => p_keep_days)
        ORDER BY created_at
        LIMIT p_batch_size
     )
     RETURNING a.*
  ), archived AS (
    INSERT INTO agency.audit_log_archives(
      id, tenant_id, user_id, action, entity_type, entity_id, ip, metadata, created_at, archived_at
    )
    SELECT id, tenant_id, user_id, action, entity_type, entity_id, ip, metadata, created_at, now()
      FROM moved
    ON CONFLICT (id) DO NOTHING
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM archived;

  RETURN v_count;
END;
$$;

GRANT SELECT ON agency.audit_log_archives TO agency_app;
GRANT EXECUTE ON FUNCTION agency.archive_audit_logs(integer, integer) TO agency_app;
