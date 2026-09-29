-- Merkezi modül çalışma kararı: tüm worker'lar aynı manuel/otomatik ve kota kurallarını kullanır.
CREATE OR REPLACE FUNCTION agency.module_execution_allowed(
  p_tenant_id uuid,
  p_module_key text
) RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce((
    SELECT p.enabled
      AND p.mode = 'automatic'
      AND (p.daily_limit = 0 OR (SELECT count(*) FROM agency.module_run_events e WHERE e.tenant_id=p_tenant_id AND e.module_key=p_module_key AND e.started_at >= date_trunc('day',now()) AND e.status IN ('started','completed')) < p.daily_limit)
      AND (p.weekly_limit = 0 OR (SELECT count(*) FROM agency.module_run_events e WHERE e.tenant_id=p_tenant_id AND e.module_key=p_module_key AND e.started_at >= date_trunc('week',now()) AND e.status IN ('started','completed')) < p.weekly_limit)
      AND (p.monthly_limit = 0 OR (SELECT count(*) FROM agency.module_run_events e WHERE e.tenant_id=p_tenant_id AND e.module_key=p_module_key AND e.started_at >= date_trunc('month',now()) AND e.status IN ('started','completed')) < p.monthly_limit)
    FROM agency.module_control_policies p
    WHERE p.tenant_id=p_tenant_id AND p.module_key=p_module_key
  ), false);
$$;

CREATE OR REPLACE FUNCTION agency.module_run_start(
  p_tenant_id uuid,
  p_module_key text,
  p_operation text,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT agency.module_execution_allowed(p_tenant_id,p_module_key) THEN
    INSERT INTO agency.module_run_events(tenant_id,module_key,operation,status,finished_at,metadata)
    VALUES(p_tenant_id,p_module_key,p_operation,'skipped',now(),p_metadata);
    RETURN NULL;
  END IF;
  INSERT INTO agency.module_run_events(tenant_id,module_key,operation,status,metadata)
  VALUES(p_tenant_id,p_module_key,p_operation,'started',p_metadata)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION agency.module_run_finish(
  p_run_id uuid,
  p_status text,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_status NOT IN ('completed','failed','skipped') THEN
    RAISE EXCEPTION 'invalid module run status';
  END IF;
  UPDATE agency.module_run_events
     SET status=p_status, finished_at=now(), metadata=metadata || p_metadata
   WHERE id=p_run_id;
END;
$$;

GRANT EXECUTE ON FUNCTION agency.module_execution_allowed(uuid,text),
  agency.module_run_start(uuid,text,text,jsonb),
  agency.module_run_finish(uuid,text,jsonb) TO agency_app;
