BEGIN;
DO $$
DECLARE v_tenant uuid; v_admin uuid; v_listing uuid; v_reservation uuid;
  v_task uuid; v_category text; v_count integer;
BEGIN
  -- Self-seeding: migration-seeded tenant/listing uzerinden admin ve ilan
  -- garanti edilir; canli veri fixture'i gerektirmez.
  SELECT l.tenant_id,l.id,l.category INTO v_tenant,v_listing,v_category
  FROM agency.listings l ORDER BY l.created_at LIMIT 1;
  IF v_listing IS NULL THEN
    SELECT id INTO v_tenant FROM agency.tenants ORDER BY created_at LIMIT 1;
    IF v_tenant IS NULL THEN RAISE EXCEPTION 'tenant fixture missing'; END IF;
    INSERT INTO agency.listings(tenant_id,code,category,title,locality,description,images,metadata,status,price_minor)
    VALUES(v_tenant,'seed-svc-'||gen_random_uuid()::text,'hotel','Seed hizmet ilani','Test','Test ilani',
      '[{"url":"https://example.test/seed.jpg"}]'::jsonb,
      jsonb_build_object('contract_fields',coalesce((select jsonb_object_agg(f.field_key,'test')
        from agency.category_fields f join agency.categories cat ON cat.id=f.category_id
        where cat.tenant_id=v_tenant and cat.code='hotel' and f.required),'{}'::jsonb)),
      'published',100000)
    RETURNING id,category INTO v_listing,v_category;
  END IF;
  SELECT id INTO v_admin FROM agency.users
    WHERE tenant_id=v_tenant AND membership_type='admin' AND active LIMIT 1;
  IF v_admin IS NULL THEN
    INSERT INTO agency.users(tenant_id,email,display_name,membership_type)
      VALUES(v_tenant,'seed-admin-'||gen_random_uuid()::text||'@example.test','Seed Admin','admin')
      RETURNING id INTO v_admin;
  END IF;
  INSERT INTO agency.reservations(tenant_id,listing_id,reference_code,status)
    VALUES(v_tenant,v_listing,'service-test-'||gen_random_uuid()::text,'confirmed')
    RETURNING id INTO v_reservation;
  SELECT agency.start_reservation_service(v_tenant,v_admin,v_reservation) INTO v_count;
  IF v_count<>3 THEN RAISE EXCEPTION 'expected 3 category tasks, got %',v_count; END IF;
  SELECT agency.start_reservation_service(v_tenant,v_admin,v_reservation) INTO v_count;
  IF v_count<>0 THEN RAISE EXCEPTION 'service start not idempotent'; END IF;
  SELECT id INTO v_task FROM agency.reservation_service_tasks
    WHERE tenant_id=v_tenant AND reservation_id=v_reservation ORDER BY position LIMIT 1;
  PERFORM agency.finish_reservation_service_task(v_tenant,v_admin,v_task,'done','test');
  IF NOT EXISTS(SELECT 1 FROM agency.reservation_service_tasks
    WHERE id=v_task AND status='done' AND completed_by=v_admin) THEN
    RAISE EXCEPTION 'task completion failed'; END IF;
  BEGIN
    PERFORM agency.finish_reservation_service_task(gen_random_uuid(),v_admin,v_task,'done','');
    RAISE EXCEPTION 'cross-tenant completion accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='cross-tenant completion accepted' THEN RAISE; END IF;
  END;
  RAISE NOTICE 'category % service workflow passed',v_category;
END $$;
ROLLBACK;
