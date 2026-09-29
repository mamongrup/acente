BEGIN;
DO $$
DECLARE v_tenant uuid; v_admin uuid; v_listing uuid; v_reservation uuid;
  v_count integer; v_notice_count integer;
BEGIN
  SELECT l.tenant_id,a.id,l.id INTO v_tenant,v_admin,v_listing
  FROM agency.listings l
  JOIN agency.users owner ON owner.id=l.owner_user_id AND owner.tenant_id=l.tenant_id
    AND owner.active AND nullif(trim(owner.email),'') IS NOT NULL
  JOIN agency.users a ON a.tenant_id=l.tenant_id AND a.membership_type='admin' AND a.active
  ORDER BY l.created_at LIMIT 1;
  IF v_listing IS NULL THEN RAISE EXCEPTION 'fixture_missing'; END IF;
  INSERT INTO agency.reservations(tenant_id,listing_id,reference_code,status,check_in,check_out)
  VALUES(v_tenant,v_listing,'service-alert-'||gen_random_uuid()::text,
    'confirmed',current_date-3,current_date-2) RETURNING id INTO v_reservation;
  PERFORM agency.start_reservation_service(v_tenant,v_admin,v_reservation);
  SELECT agency.queue_overdue_service_notifications(v_tenant,v_admin) INTO v_count;
  IF v_count<3 THEN RAISE EXCEPTION 'expected_service_alerts: %',v_count; END IF;
  SELECT count(*) INTO v_notice_count FROM agency.notifications
    WHERE tenant_id=v_tenant AND template='service.overdue'
      AND payload->>'reservation_id'=v_reservation::text;
  IF v_notice_count<>3 THEN RAISE EXCEPTION 'notification_count: %',v_notice_count; END IF;
  SELECT agency.queue_overdue_service_notifications(v_tenant,v_admin) INTO v_count;
  IF v_count<>0 THEN RAISE EXCEPTION 'duplicate_service_alert: %',v_count; END IF;
  BEGIN
    PERFORM agency.queue_overdue_service_notifications(gen_random_uuid(),v_admin);
    RAISE EXCEPTION 'cross_tenant_alert_accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='cross_tenant_alert_accepted' THEN RAISE; END IF;
  END;
END $$;
ROLLBACK;
