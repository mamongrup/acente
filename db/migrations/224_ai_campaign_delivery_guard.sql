-- Keep a campaign running until every recipient has a terminal result.
CREATE OR REPLACE FUNCTION agency.ai_campaign_reconcile(p_tenant uuid, p_run uuid)
RETURNS text LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE v_total integer; v_sent integer; v_failed integer; v_cancelled integer;
  v_pending integer; v_status text;
BEGIN
  PERFORM 1 FROM agency.ai_campaign_runs
    WHERE id=p_run AND tenant_id=p_tenant AND status='running' FOR UPDATE;
  IF NOT FOUND THEN RETURN 'unchanged'; END IF;
  SELECT count(*),count(*) FILTER(WHERE n.status='sent'),
    count(*) FILTER(WHERE n.status='failed'),count(*) FILTER(WHERE n.status='cancelled'),
    count(*) FILTER(WHERE n.status NOT IN ('sent','failed','cancelled'))
  INTO v_total,v_sent,v_failed,v_cancelled,v_pending
  FROM agency.ai_campaign_notifications link
  JOIN agency.notifications n ON n.id=link.notification_id AND n.tenant_id=link.tenant_id
  WHERE link.tenant_id=p_tenant AND link.run_id=p_run;
  v_status := CASE WHEN v_total=0 THEN 'paused'
    WHEN v_pending>0 THEN 'running'
    WHEN v_failed>0 OR v_cancelled>0 THEN 'paused'
    ELSE 'completed' END;
  UPDATE agency.ai_campaign_runs SET status=v_status,
    metrics=coalesce(metrics,'{}'::jsonb)||jsonb_build_object(
      'queued',v_total,'submitted',v_sent,'failed',v_failed,
      'cancelled',v_cancelled,'pending',v_pending,'reconciled_at',now())
    WHERE id=p_run AND tenant_id=p_tenant;
  RETURN v_status;
END $$;

CREATE OR REPLACE FUNCTION agency.ai_campaign_delivery_allowed(p_tenant uuid, p_notification uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $$
  SELECT EXISTS (
    SELECT 1 FROM agency.ai_campaign_notifications link
    JOIN agency.ai_campaign_runs run ON run.id=link.run_id
      AND run.tenant_id=link.tenant_id AND run.status='running'
    JOIN agency.notifications n ON n.id=link.notification_id
      AND n.tenant_id=link.tenant_id AND n.user_id=link.user_id
      AND n.status='running' AND n.template='ai.campaign' AND n.channel='email'
    JOIN agency.users u ON u.id=link.user_id AND u.tenant_id=link.tenant_id AND u.active
    JOIN agency.customer_notification_preferences pref ON pref.user_id=u.id
      AND pref.tenant_id=u.tenant_id AND pref.marketing_email
    WHERE link.tenant_id=p_tenant AND link.notification_id=p_notification
  );
$$;
REVOKE ALL ON FUNCTION agency.ai_campaign_delivery_allowed(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.ai_campaign_delivery_allowed(uuid,uuid) TO agency_app;
