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
      id, tenant_id, user_id, action, entity_type, entity_id, ip,
      user_agent, request_id, metadata, created_at, archived_at
    )
    SELECT id, tenant_id, user_id, action, entity_type, entity_id, ip,
           user_agent, request_id, metadata, created_at, now()
      FROM moved
    ON CONFLICT (id) DO NOTHING
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM archived;

  RETURN v_count;
END;
$$;

