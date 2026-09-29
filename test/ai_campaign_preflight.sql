BEGIN;
DO $$
DECLARE
  v_tenant uuid;
  v_user uuid;
  v_campaign uuid;
  v_run uuid;
  v_result record;
BEGIN
  SELECT id INTO STRICT v_tenant FROM agency.tenants ORDER BY id LIMIT 1;
  INSERT INTO agency.users(tenant_id,email,display_name,membership_type,active)
  VALUES(v_tenant,'ai-campaign-smoke@example.invalid','Campaign Test','customer',true)
  RETURNING id INTO v_user;
  INSERT INTO agency.campaigns(tenant_id,name,kind,active)
  VALUES(v_tenant,'Campaign Test','period',true) RETURNING id INTO v_campaign;
  INSERT INTO agency.ai_campaign_runs(tenant_id,campaign_id,channel,audience,offer,status,scheduled_at)
  VALUES(v_tenant,v_campaign,'email',jsonb_build_object('user_ids',jsonb_build_array(v_user)),
    '{"message":"Seyahat fırsatı"}'::jsonb,'scheduled',now()-interval '1 minute')
  RETURNING id INTO v_run;

  SELECT * INTO v_result FROM agency.ai_campaign_preflight(v_tenant,v_run);
  IF v_result.reason <> 'audience_consent_missing' THEN RAISE EXCEPTION 'consent_gate_missing'; END IF;

  INSERT INTO agency.customer_notification_preferences(tenant_id,user_id,marketing_email)
  VALUES(v_tenant,v_user,true);
  SELECT * INTO v_result FROM agency.ai_campaign_preflight(v_tenant,v_run);
  IF v_result.ready IS DISTINCT FROM true OR v_result.eligible_count<>1 THEN
    RAISE EXCEPTION 'consented_audience_rejected';
  END IF;

  UPDATE agency.ai_campaign_runs SET channel='social' WHERE id=v_run;
  SELECT * INTO v_result FROM agency.ai_campaign_preflight(v_tenant,v_run);
  IF v_result.reason <> 'channel_executor_unavailable' THEN RAISE EXCEPTION 'unsupported_channel_accepted'; END IF;

  SELECT * INTO v_result FROM agency.ai_campaign_preflight(
    (SELECT id FROM agency.tenants WHERE id<>v_tenant ORDER BY id LIMIT 1),v_run);
  IF v_result.reason <> 'run_not_found' THEN RAISE EXCEPTION 'tenant_boundary_failed'; END IF;
  RAISE NOTICE 'AI campaign preflight passed';
END $$;
ROLLBACK;
