-- A run is queued once, with one notification per consented user.
CREATE TABLE IF NOT EXISTS agency.ai_campaign_notifications (
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  run_id uuid NOT NULL REFERENCES agency.ai_campaign_runs(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  notification_id uuid NOT NULL UNIQUE REFERENCES agency.notifications(id) ON DELETE CASCADE,
  PRIMARY KEY(run_id,user_id)
);

CREATE OR REPLACE FUNCTION agency.ai_campaign_notification_scope_guard()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM agency.ai_campaign_runs r WHERE r.id=NEW.run_id AND r.tenant_id=NEW.tenant_id)
     OR NOT EXISTS (SELECT 1 FROM agency.users u WHERE u.id=NEW.user_id AND u.tenant_id=NEW.tenant_id)
     OR NOT EXISTS (SELECT 1 FROM agency.notifications n WHERE n.id=NEW.notification_id
       AND n.tenant_id=NEW.tenant_id AND n.user_id=NEW.user_id AND n.template='ai.campaign') THEN
    RAISE EXCEPTION 'Campaign notification tenant or recipient mismatch';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS ai_campaign_notification_scope_guard ON agency.ai_campaign_notifications;
CREATE TRIGGER ai_campaign_notification_scope_guard
  BEFORE INSERT OR UPDATE ON agency.ai_campaign_notifications
  FOR EACH ROW EXECUTE FUNCTION agency.ai_campaign_notification_scope_guard();

CREATE OR REPLACE FUNCTION agency.ai_campaign_enqueue_email(p_tenant uuid, p_run uuid)
RETURNS integer LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE v_run agency.ai_campaign_runs%ROWTYPE; v_ready record; v_count integer;
BEGIN
  SELECT * INTO v_run FROM agency.ai_campaign_runs
    WHERE id=p_run AND tenant_id=p_tenant FOR UPDATE;
  IF NOT FOUND THEN RETURN 0; END IF;
  SELECT * INTO v_ready FROM agency.ai_campaign_preflight(p_tenant,p_run);
  IF NOT v_ready.ready OR NOT agency.module_execution_allowed(p_tenant,'campaigns')
     OR NOT agency.module_execution_allowed(p_tenant,'notifications') THEN RETURN 0; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM agency.integrations i WHERE i.tenant_id=p_tenant
      AND i.provider='smtp' AND i.active
      AND nullif(i.credentials->>'host','') IS NOT NULL
      AND nullif(i.credentials->>'username','') IS NOT NULL
      AND (nullif(i.credentials->>'password_sealed','') IS NOT NULL
        OR nullif(i.credentials->>'password','') IS NOT NULL)
  ) THEN RETURN 0; END IF;

  WITH recipients AS (
    SELECT DISTINCT u.id,u.email
    FROM jsonb_array_elements_text(v_run.audience->'user_ids') ids(value)
    JOIN agency.users u ON u.id::text=ids.value AND u.tenant_id=p_tenant AND u.active
    JOIN agency.customer_notification_preferences pref
      ON pref.user_id=u.id AND pref.tenant_id=p_tenant AND pref.marketing_email
  ), queued AS (
    INSERT INTO agency.notifications(tenant_id,user_id,channel,template,payload,status)
    SELECT p_tenant,r.id,'email','ai.campaign',
      jsonb_build_object('email',r.email,'message',v_run.offer->>'message','campaign_run_id',p_run),
      'queued' FROM recipients r
    RETURNING id,user_id
  ), linked AS (
    INSERT INTO agency.ai_campaign_notifications(tenant_id,run_id,user_id,notification_id)
    SELECT p_tenant,p_run,q.user_id,q.id FROM queued q RETURNING 1
  ) SELECT count(*) INTO v_count FROM linked;
  UPDATE agency.ai_campaign_runs SET status='running',
    metrics=coalesce(metrics,'{}'::jsonb)||jsonb_build_object('queued',v_count,'queued_at',now())
    WHERE id=p_run AND tenant_id=p_tenant;
  RETURN v_count;
END $$;

CREATE OR REPLACE FUNCTION agency.ai_campaign_reconcile(p_tenant uuid, p_run uuid)
RETURNS text LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE v_total integer; v_sent integer; v_failed integer; v_cancelled integer; v_status text;
BEGIN
  PERFORM 1 FROM agency.ai_campaign_runs
    WHERE id=p_run AND tenant_id=p_tenant AND status='running' FOR UPDATE;
  IF NOT FOUND THEN RETURN 'unchanged'; END IF;
  SELECT count(*),count(*) FILTER(WHERE n.status='sent'),count(*) FILTER(WHERE n.status='failed'),
    count(*) FILTER(WHERE n.status='cancelled')
  INTO v_total,v_sent,v_failed,v_cancelled
  FROM agency.ai_campaign_notifications link
  JOIN agency.notifications n ON n.id=link.notification_id AND n.tenant_id=link.tenant_id
  WHERE link.tenant_id=p_tenant AND link.run_id=p_run;
  v_status := CASE WHEN v_total=0 THEN 'paused'
    WHEN v_failed>0 OR v_cancelled>0 THEN 'paused'
    WHEN v_sent=v_total THEN 'completed' ELSE 'running' END;
  UPDATE agency.ai_campaign_runs SET status=v_status,
    metrics=coalesce(metrics,'{}'::jsonb)||jsonb_build_object(
      'queued',v_total,'submitted',v_sent,'failed',v_failed,'cancelled',v_cancelled,'reconciled_at',now())
    WHERE id=p_run AND tenant_id=p_tenant;
  RETURN v_status;
END $$;

GRANT SELECT,INSERT,UPDATE,DELETE ON agency.ai_campaign_notifications TO agency_app;
REVOKE ALL ON FUNCTION agency.ai_campaign_enqueue_email(uuid,uuid),
  agency.ai_campaign_reconcile(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.ai_campaign_enqueue_email(uuid,uuid),
  agency.ai_campaign_reconcile(uuid,uuid) TO agency_app;
