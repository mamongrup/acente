BEGIN;

DO $$
DECLARE
  v_tenant_a uuid := gen_random_uuid();
  v_tenant_b uuid := gen_random_uuid();
  v_admin_a uuid := gen_random_uuid();
  v_admin_b uuid := gen_random_uuid();
  v_dual_user uuid := gen_random_uuid();
  v_supplier_role uuid := gen_random_uuid();
  v_listing_a uuid := gen_random_uuid();
  v_listing_b uuid := gen_random_uuid();
  v_reservation_a uuid := gen_random_uuid();
  v_order_a record;
  v_task_count int;
  v_task_id uuid;
  v_blocked boolean;
BEGIN
  -- 1. İki yalıtılmış tenant oluştur
  INSERT INTO agency.tenants(id,legal_name,brand_name,slug)
  VALUES (v_tenant_a,'Tenant A Turizm Ltd','Acente A','tenant-a-'||replace(v_tenant_a::text,'-','')),
         (v_tenant_b,'Tenant B Turizm Ltd','Acente B','tenant-b-'||replace(v_tenant_b::text,'-',''));

  -- 2. Kullanıcıları oluştur
  INSERT INTO agency.users(id,tenant_id,email,display_name,membership_type,active)
  VALUES (v_admin_a,v_tenant_a,'admin-a@example.invalid','Admin A','admin',true),
         (v_admin_b,v_tenant_b,'admin-b@example.invalid','Admin B','admin',true),
         (v_dual_user,v_tenant_a,'dual-user@example.invalid','Dual Role User','customer',true);

  -- 3. Çoklu rol ataması: Dual role kullanıcısına Tenant A içinde ikincil rol olarak 'supplier' ver
  INSERT INTO agency.roles(id,tenant_id,code,name)
  VALUES (v_supplier_role,v_tenant_a,'supplier','Tedarikçi Rolü');

  INSERT INTO agency.user_roles(user_id,role_id)
  VALUES (v_dual_user,v_supplier_role);

  -- Tenant A içinde dual_user artık supplier yetkisine sahip olmalı
  IF NOT agency.has_panel_role(v_tenant_a,v_dual_user,'supplier') THEN
    RAISE EXCEPTION 'dual_user_tenant_a_supplier_role_missing';
  END IF;

  -- Aynı dual_user Tenant B'de kesinlikle supplier veya admin rolüne sahip olamaz
  IF agency.has_panel_role(v_tenant_b,v_dual_user,'supplier')
     OR agency.has_panel_role(v_tenant_b,v_dual_user,'admin') THEN
    RAISE EXCEPTION 'dual_user_cross_tenant_role_leak';
  END IF;

  -- 4. Yerel ilanlar oluştur (Tenant A ve Tenant B)
  INSERT INTO agency.listings(
    id,tenant_id,code,category,title,locality,description,currency,price_minor,
    status,source,metadata,images,owner_info,cancellation_policy,owner_user_id)
  VALUES (v_listing_a,v_tenant_a,'code-a-'||gen_random_uuid(),'hotel','Otel A','Antalya',
    'Acente A Yerel Otel','TRY',20000,'published','manual',
    jsonb_build_object('property_type','Otel','room_types','Suit','board_type','Her Şey Dahil',
      'check_in_time','14:00','check_out_time','12:00'),
    jsonb_build_array(jsonb_build_object('url','/static/hotel-a.jpg')),
    jsonb_build_object('provider','Yerel Tedarikçi A'),
    jsonb_build_object('policy','Standard'),v_dual_user);

  INSERT INTO agency.listings(
    id,tenant_id,code,category,title,locality,description,currency,price_minor,
    status,source,metadata,images,owner_info,cancellation_policy,owner_user_id)
  VALUES (v_listing_b,v_tenant_b,'code-b-'||gen_random_uuid(),'hotel','Otel B','Bodrum',
    'Acente B Yerel Otel','TRY',25000,'published','manual',
    jsonb_build_object('property_type','Otel','room_types','Villa','board_type','Oda Kahvaltı',
      'check_in_time','14:00','check_out_time','12:00'),
    jsonb_build_array(jsonb_build_object('url','/static/hotel-b.jpg')),
    jsonb_build_object('provider','Yerel Tedarikçi B'),
    jsonb_build_object('policy','Strict'),v_admin_b);

  -- 5. Tenant A için bağımsız sipariş/rezervasyon oluştur
  SELECT * INTO STRICT v_order_a FROM agency.checkout_order(
    v_tenant_a,'Müşteri Test','musteri@example.invalid','5551112233',
    v_listing_a,'REZ-A-'||gen_random_uuid(),current_date+5,current_date+10,2,
    'idemp-a-'||gen_random_uuid());

  v_reservation_a := v_order_a.reservation_id;

  -- Rezervasyonu onayla
  UPDATE agency.reservations SET status='confirmed', payment_status='paid'
  WHERE id=v_reservation_a AND tenant_id=v_tenant_a;

  -- 6. Servis görevlerini başlat (Tenant A'da admin başlatır)
  v_task_count := agency.start_reservation_service(v_tenant_a, v_admin_a, v_reservation_a);
  IF v_task_count <= 0 THEN
    RAISE EXCEPTION 'reservation_service_tasks_not_created';
  END IF;

  -- Bir görevi seç
  SELECT id INTO STRICT v_task_id FROM agency.reservation_service_tasks
  WHERE tenant_id=v_tenant_a AND reservation_id=v_reservation_a AND status='open'
  LIMIT 1;

  -- 7. NEGATİF TENANT TESTİ: Tenant B Admin'i Tenant A'nın görevini bitirmeye çalışır
  v_blocked := false;
  BEGIN
    PERFORM agency.finish_reservation_service_task(v_tenant_b, v_admin_b, v_task_id, 'done', 'İzinsiz işlem');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'invalid_service_task' OR SQLERRM = 'service_access_denied' THEN
      v_blocked := true;
    ELSE
      RAISE;
    END IF;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'cross_tenant_service_task_tampering_allowed';
  END IF;

  -- 8. İKİNCİL ROL TESTİ: Dual user (Tenant A supplier ve ilan sahibi) supplier görevini tamamlayabilir
  -- Görevin owner_role'ünü supplier yapıp deneyelim
  UPDATE agency.reservation_service_tasks SET owner_role='supplier' WHERE id=v_task_id;
  PERFORM agency.finish_reservation_service_task(v_tenant_a, v_dual_user, v_task_id, 'done', 'Tedarikçi tarafından tamamlandı');

  IF (SELECT status FROM agency.reservation_service_tasks WHERE id=v_task_id) <> 'done' THEN
    RAISE EXCEPTION 'dual_role_supplier_task_completion_failed';
  END IF;

  -- 9. NEGATİF TENANT TESTİ: Tenant B kullanıcısı Tenant A'nın ilanını doğrudan sipariş edemez
  v_blocked := false;
  BEGIN
    PERFORM agency.checkout_order(
      v_tenant_b,'Yabancı Müşteri','foreign@example.invalid','5550000000',
      v_listing_a,'REZ-CROSS-'||gen_random_uuid(),current_date+1,current_date+2,1,
      'cross-idemp-'||gen_random_uuid());
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'cross_tenant_listing_checkout_allowed';
  END IF;

  -- 10. NEGATİF TENANT TESTİ: Tenant B admini Tenant A ilanının fiyatını veya durumunu değiştiremez
  v_blocked := false;
  BEGIN
    PERFORM agency.propose_listing_price(v_tenant_b, v_admin_b, v_listing_a, 50000, 'Korsan fiyat');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'cross_tenant_listing_price_proposal_allowed';
  END IF;

  RAISE NOTICE 'tenant isolation and multi-role contracts passed';
END $$;

ROLLBACK;
