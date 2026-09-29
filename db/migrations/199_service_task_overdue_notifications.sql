-- Service reminders are local to each agency and keep working without NEXUS.
ALTER TABLE agency.reservation_service_tasks
  ADD COLUMN IF NOT EXISTS last_overdue_notified_at timestamptz;

CREATE OR REPLACE FUNCTION agency.queue_overdue_service_notifications(
  p_tenant uuid,p_actor uuid
) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_task record; v_count integer:=0;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users
    WHERE id=p_actor AND tenant_id=p_tenant AND active AND membership_type='admin') THEN
    RAISE EXCEPTION 'service_notification_forbidden';
  END IF;
  FOR v_task IN
    SELECT t.id,t.reservation_id,t.title_tr,r.reference_code,
      CASE WHEN t.stage='after' THEN coalesce(r.check_out,r.check_in)
           ELSE r.check_in END AS due_on,
      u.id AS recipient_id,u.email,u.display_name
    FROM agency.reservation_service_tasks t
    JOIN agency.reservations r ON r.id=t.reservation_id AND r.tenant_id=t.tenant_id
    JOIN agency.listings l ON l.id=t.listing_id AND l.tenant_id=t.tenant_id
    JOIN agency.users u ON u.id=l.owner_user_id AND u.tenant_id=t.tenant_id
    WHERE t.tenant_id=p_tenant AND t.status='open' AND t.owner_role='supplier'
      AND r.status IN ('confirmed','completed') AND u.active
      AND nullif(trim(u.email),'') IS NOT NULL
      AND (CASE WHEN t.stage='after' THEN coalesce(r.check_out,r.check_in)
                ELSE r.check_in END)<current_date
      AND (t.last_overdue_notified_at IS NULL
           OR t.last_overdue_notified_at<now()-interval '24 hours')
    ORDER BY r.check_in,t.position,t.id LIMIT 200
    FOR UPDATE OF t SKIP LOCKED
  LOOP
    INSERT INTO agency.notifications(tenant_id,user_id,channel,template,payload,status)
    VALUES(p_tenant,v_task.recipient_id,'email','service.overdue',
      jsonb_build_object('email',v_task.email,'name',v_task.display_name,
        'reservation_id',v_task.reservation_id,'reference',v_task.reference_code,
        'task_id',v_task.id,'due_on',v_task.due_on,
        'message','Rezervasyon '||v_task.reference_code||' için "'||v_task.title_tr||'" hizmet adımı bekliyor. Rezervasyonlarım ekranından kontrol edin.'),
      'queued');
    UPDATE agency.reservation_service_tasks SET last_overdue_notified_at=now()
      WHERE id=v_task.id AND tenant_id=p_tenant;
    v_count:=v_count+1;
  END LOOP;
  IF v_count>0 THEN
    INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,metadata)
    VALUES(p_tenant,p_actor,'service.overdue_notifications_queued',
      'reservation_service_task',jsonb_build_object('count',v_count));
  END IF;
  RETURN v_count;
END $$;

REVOKE ALL ON FUNCTION agency.queue_overdue_service_notifications(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.queue_overdue_service_notifications(uuid,uuid) TO agency_app;
