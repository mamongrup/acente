BEGIN;
DO $$
DECLARE
  v_tenant uuid; v_user uuid; v_user2 uuid; v_campaign uuid; v_run uuid;
  v_notification uuid; v_notification2 uuid; v_count integer; v_status text;
BEGIN
  SELECT id INTO STRICT v_tenant FROM agency.tenants ORDER BY id LIMIT 1;
  INSERT INTO agency.users(tenant_id,email,display_name,membership_type,active)
  VALUES(v_tenant,'ai-campaign-queue-smoke@example.invalid','Campaign Queue Test','customer',true)
  RETURNING id INTO v_user;
  INSERT INTO agency.customer_notification_preferences(tenant_id,user_id,marketing_email)
  VALUES(v_tenant,v_user,true);
  INSERT INTO agency.users(tenant_id,email,display_name,membership_type,active)
  VALUES(v_tenant,'ai-campaign-queue-smoke-2@example.invalid','Campaign Queue Test 2','customer',true)
  RETURNING id INTO v_user2;
  INSERT INTO agency.customer_notification_preferences(tenant_id,user_id,marketing_email)
  VALUES(v_tenant,v_user2,true);
  INSERT INTO agency.module_control_policies(tenant_id,module_key,mode,enabled)
  VALUES(v_tenant,'campaigns','automatic',true),(v_tenant,'notifications','automatic',true)
  ON CONFLICT(tenant_id,module_key) DO UPDATE SET mode='automatic',enabled=true;
  INSERT INTO agency.integrations(tenant_id,provider,kind,credentials,active)
  VALUES(v_tenant,'smtp','smtp','{"host":"smtp.example.invalid","username":"sender@example.invalid","password_sealed":"test-only"}'::jsonb,true)
  ON CONFLICT(tenant_id,provider,kind) DO UPDATE SET credentials=excluded.credentials,active=true;
  INSERT INTO agency.campaigns(tenant_id,name,kind,active)
  VALUES(v_tenant,'Queue Test','period',true) RETURNING id INTO v_campaign;
  INSERT INTO agency.ai_campaign_runs(tenant_id,campaign_id,channel,audience,offer,status,scheduled_at)
  VALUES(v_tenant,v_campaign,'email',jsonb_build_object('user_ids',jsonb_build_array(v_user,v_user2)),
    '{"message":"Seyahat fırsatı"}'::jsonb,'scheduled',now()-interval '1 minute')
  RETURNING id INTO v_run;
  SELECT agency.ai_campaign_enqueue_email(v_tenant,v_run) INTO v_count;
  IF v_count<>2 THEN RAISE EXCEPTION 'queue_count=%',v_count; END IF;
  SELECT agency.ai_campaign_enqueue_email(v_tenant,v_run) INTO v_count;
  IF v_count<>0 THEN RAISE EXCEPTION 'duplicate_queue'; END IF;
  SELECT notification_id INTO STRICT v_notification FROM agency.ai_campaign_notifications
    WHERE tenant_id=v_tenant AND run_id=v_run AND user_id=v_user;
  SELECT notification_id INTO STRICT v_notification2 FROM agency.ai_campaign_notifications
    WHERE tenant_id=v_tenant AND run_id=v_run AND user_id=v_user2;
  IF (SELECT status FROM agency.ai_campaign_runs WHERE id=v_run)<>'running' THEN
    RAISE EXCEPTION 'run_not_running';
  END IF;
  UPDATE agency.notifications SET status='running' WHERE id=v_notification2;
  IF agency.ai_campaign_delivery_allowed(v_tenant,v_notification2) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'consented_delivery_blocked';
  END IF;
  UPDATE agency.customer_notification_preferences SET marketing_email=false WHERE user_id=v_user2;
  IF agency.ai_campaign_delivery_allowed(v_tenant,v_notification2) IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'revoked_consent_allowed';
  END IF;
  UPDATE agency.customer_notification_preferences SET marketing_email=true WHERE user_id=v_user2;
  UPDATE agency.notifications SET status='sent' WHERE id=v_notification;
  SELECT agency.ai_campaign_reconcile(v_tenant,v_run) INTO v_status;
  IF v_status<>'running' THEN RAISE EXCEPTION 'pending_recipient_stopped'; END IF;
  UPDATE agency.notifications SET status='sent' WHERE id=v_notification2;
  SELECT agency.ai_campaign_reconcile(v_tenant,v_run) INTO v_status;
  IF v_status<>'completed' THEN RAISE EXCEPTION 'run_not_completed'; END IF;
  IF (SELECT metrics->>'submitted' FROM agency.ai_campaign_runs WHERE id=v_run)<>'2' THEN
    RAISE EXCEPTION 'submitted_metric_wrong';
  END IF;
  RAISE NOTICE 'AI campaign email queue passed';
END $$;
ROLLBACK;
