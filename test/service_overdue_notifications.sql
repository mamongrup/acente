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
  IF v_listing IS NULL THEN
    -- Self-seeding: sahibi + e-postasi olan kullanici ve ilani tohumla
    -- (demo ilanlari owner_user_id'siz oldugu icin taze kurulumda bu
    -- fixture yoktur).
    SELECT id INTO v_tenant FROM agency.tenants ORDER BY created_at LIMIT 1;
    IF v_tenant IS NULL THEN RAISE EXCEPTION 'tenant fixture missing'; END IF;
    SELECT id INTO v_admin FROM agency.users
      WHERE tenant_id=v_tenant AND membership_type='admin' AND active
      AND nullif(trim(email),'') IS NOT NULL LIMIT 1;
    IF v_admin IS NULL THEN
      INSERT INTO agency.users(tenant_id,email,display_name,membership_type)
        VALUES(v_tenant,'seed-admin-'||gen_random_uuid()::text||'@example.test','Seed Admin','admin')
        RETURNING id INTO v_admin;
    END IF;
    INSERT INTO agency.listings(tenant_id,code,category,title,locality,description,images,metadata,status,source,price_minor,owner_user_id)
    VALUES(v_tenant,'seed-overdue-'||gen_random_uuid()::text,'hotel','Seed gecikme oteli','Test','Test ilani',
      jsonb_build_array(jsonb_build_object('url','https://example.test/seed.jpg')),
      jsonb_build_object('contract_fields',coalesce((select jsonb_object_agg(f.field_key,'test')
        from agency.category_fields f join agency.categories cat ON cat.id=f.category_id
        where cat.tenant_id=v_tenant and cat.code='hotel' and f.required),'{}'::jsonb)),
      'published','manual',100000,v_admin)
    RETURNING id INTO v_listing;
  END IF;
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
