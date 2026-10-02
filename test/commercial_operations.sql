BEGIN;
DO $$
DECLARE v_tenant uuid; v_admin uuid; v_listing uuid; v_base bigint;
  v_proposal uuid; v_org uuid; v_contract uuid; v_product uuid;
  v_reservation uuid; v_campaign uuid; v_channel uuid; v_event uuid;
BEGIN
  -- Self-seeding: admin ve gecerli yayinlanmis kaynak ilan garantisi.
  SELECT tenant_id,id INTO v_tenant,v_admin FROM agency.users
    WHERE membership_type='admin' AND active LIMIT 1;
  IF v_tenant IS NULL THEN
    SELECT id INTO v_tenant FROM agency.tenants ORDER BY created_at LIMIT 1;
    IF v_tenant IS NULL THEN RAISE EXCEPTION 'tenant fixture missing'; END IF;
    INSERT INTO agency.users(tenant_id,email,display_name,membership_type)
      VALUES(v_tenant,'seed-admin-'||gen_random_uuid()::text||'@example.test','Seed Admin','admin')
      RETURNING id INTO v_admin;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM agency.listings l WHERE l.status='published'
      AND NOT EXISTS(SELECT 1 FROM agency.validate_listing_common_contract(l))
      AND NOT EXISTS(SELECT 1 FROM agency.validate_listing_contract(l.tenant_id,l.category,l.metadata))
  ) THEN
    INSERT INTO agency.listings(tenant_id,code,category,title,locality,description,currency,price_minor,status,source,images,owner_info,cancellation_policy,metadata)
    VALUES(v_tenant,'seed-commerce-'||gen_random_uuid()::text,'hotel','Seed ticari otel','Test Lokasyon','Test aciklama','TRY',250000,'published','manual',
      jsonb_build_array(jsonb_build_object('url','https://example.test/seed.jpg')),
      jsonb_build_object('provider','Seed'),
      jsonb_build_object('policy','Standart'),
      jsonb_build_object('contract_fields',coalesce((select jsonb_object_agg(f.field_key,'test')
        from agency.category_fields f join agency.categories cat ON cat.id=f.category_id
        where cat.tenant_id=v_tenant and cat.code='hotel' and f.required),'{}'::jsonb)));
  END IF;
  INSERT INTO agency.listings(tenant_id,code,category,title,locality,description,currency,
    price_minor,status,source,metadata,images,amenities,owner_info,cancellation_policy)
  SELECT v_tenant,'commerce-test-'||gen_random_uuid()::text,l.category,l.title,l.locality,
    l.description,l.currency,l.price_minor,'published','manual',l.metadata,l.images,
    l.amenities,l.owner_info,l.cancellation_policy
  FROM agency.listings l WHERE l.status='published'
    AND NOT EXISTS(SELECT 1 FROM agency.validate_listing_common_contract(l))
    AND NOT EXISTS(SELECT 1 FROM agency.validate_listing_contract(l.tenant_id,l.category,l.metadata))
  LIMIT 1 RETURNING id,price_minor INTO v_listing,v_base;
  IF v_listing IS NULL THEN RAISE EXCEPTION 'fixture_missing'; END IF;

  v_proposal:=agency.propose_listing_price(v_tenant,v_admin,v_listing,v_base+1000,
    'Ticari operasyon test fiyatı');
  PERFORM agency.review_listing_price(v_tenant,v_admin,v_proposal,'approved');
  IF NOT EXISTS(SELECT 1 FROM agency.listings WHERE tenant_id=v_tenant
    AND id=v_listing AND price_minor=v_base+1000) THEN RAISE EXCEPTION 'price_not_approved'; END IF;

  INSERT INTO agency.partner_organizations(tenant_id,name)
    VALUES(v_tenant,'Ticari test acentesi') RETURNING id INTO v_org;
  v_contract:=agency.create_partner_sales_contract(v_tenant,v_admin,v_org,
    'TEST-'||substr(gen_random_uuid()::text,1,8),current_date,current_date+30,'TRY',10);
  v_product:=agency.add_partner_contract_product(v_tenant,v_admin,v_contract,
    v_listing,5000,2,0);
  PERFORM agency.activate_partner_sales_contract(v_tenant,v_admin,v_contract);

  INSERT INTO agency.reservations(tenant_id,listing_id,reference_code,status,
    payment_status,partner_organization_id,check_in,total_minor)
    VALUES(v_tenant,v_listing,'commerce-test-'||gen_random_uuid()::text,
      'confirmed','paid',v_org,current_date+3,10000)
    RETURNING id INTO v_reservation;
  PERFORM agency.allocate_partner_reservation(v_tenant,v_admin,v_product,v_reservation,1);
  IF (SELECT count(*) FROM agency.partner_reservation_allocations
      WHERE tenant_id=v_tenant AND reservation_id=v_reservation)<>1 THEN
    RAISE EXCEPTION 'allotment_not_allocated'; END IF;
  PERFORM agency.register_partner_voucher(v_tenant,v_admin,v_reservation,'TEST-VOUCHER','operator-1');
  IF NOT EXISTS(SELECT 1 FROM agency.partner_vouchers WHERE tenant_id=v_tenant
      AND reservation_id=v_reservation AND voucher_code='TEST-VOUCHER') THEN
    RAISE EXCEPTION 'voucher_not_registered'; END IF;
  DECLARE
    v_low_reservation uuid;
  BEGIN
    INSERT INTO agency.reservations(tenant_id,listing_id,reference_code,status,
      partner_organization_id,check_in,total_minor)
      VALUES(v_tenant,v_listing,'low-test-'||gen_random_uuid()::text,
        'confirmed',v_org,current_date+3,4000)
      RETURNING id INTO v_low_reservation;
    BEGIN
      PERFORM agency.allocate_partner_reservation(v_tenant,v_admin,v_product,v_low_reservation,1);
      RAISE EXCEPTION 'below-contract-price accepted';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM='below-contract-price accepted' THEN RAISE; END IF;
    END;
  END;

  v_campaign:=agency.create_partner_bonus_campaign(v_tenant,v_admin,'Test bonusu',
    NULL,current_date,current_date+30,5,1000,'TRY');
  PERFORM agency.activate_partner_bonus_campaign(v_tenant,v_admin,v_campaign);
  UPDATE agency.reservations SET status='completed' WHERE id=v_reservation;
  IF NOT EXISTS(SELECT 1 FROM agency.partner_bonus_ledger WHERE tenant_id=v_tenant
      AND reservation_id=v_reservation AND campaign_id=v_campaign
      AND status='earned' AND bonus_minor=500) THEN RAISE EXCEPTION 'bonus_not_earned'; END IF;
  UPDATE agency.reservations SET payment_status='refunded' WHERE id=v_reservation;
  IF NOT EXISTS(SELECT 1 FROM agency.partner_bonus_ledger WHERE tenant_id=v_tenant
      AND reservation_id=v_reservation AND status='reversed') THEN
    RAISE EXCEPTION 'bonus_not_reversed'; END IF;
  DECLARE v_eur_reservation uuid;
  BEGIN
    INSERT INTO agency.reservations(tenant_id,listing_id,reference_code,status,
      payment_status,partner_organization_id,check_in,total_minor,currency)
      VALUES(v_tenant,v_listing,'eur-test-'||gen_random_uuid()::text,
        'completed','paid',v_org,current_date+3,10000,'EUR')
      RETURNING id INTO v_eur_reservation;
    IF EXISTS(SELECT 1 FROM agency.partner_bonus_ledger
      WHERE tenant_id=v_tenant AND reservation_id=v_eur_reservation) THEN
      RAISE EXCEPTION 'TRY bonus leaked into EUR reservation'; END IF;
  END;

  v_channel:=agency.save_sales_channel(v_tenant,v_admin,'test_channel','Test Kanalı','test');
  PERFORM agency.map_sales_channel_product(v_tenant,v_admin,v_channel,v_listing,'test-product',true);
  UPDATE agency.listings SET price_minor=v_base+2000,updated_at=now()
    WHERE tenant_id=v_tenant AND id=v_listing;
  INSERT INTO agency.availability(listing_id,day,units_total,units_available)
    VALUES(v_listing,current_date+3,2,2);
  IF (SELECT count(*) FROM agency.channel_sync_outbox
      WHERE tenant_id=v_tenant AND channel_id=v_channel
        AND event_type IN ('price','availability'))<>2 THEN
    RAISE EXCEPTION 'automatic_channel_outbox_missing'; END IF;
  v_event:=agency.queue_channel_update(v_tenant,v_admin,v_channel,v_listing,
    'price-'||v_proposal::text,'price',jsonb_build_object('priceMinor',v_base+1000));
  IF v_event<>agency.queue_channel_update(v_tenant,v_admin,v_channel,v_listing,
    'price-'||v_proposal::text,'price',jsonb_build_object('priceMinor',v_base+1000)) THEN
    RAISE EXCEPTION 'channel_outbox_not_idempotent'; END IF;
  DECLARE v_dual uuid; v_role uuid; v_dual_proposal uuid;
  BEGIN
    INSERT INTO agency.users(tenant_id,email,display_name,membership_type)
      VALUES(v_tenant,'dual-'||gen_random_uuid()::text||'@example.test','Dual role test','customer')
      RETURNING id INTO v_dual;
    INSERT INTO agency.roles(tenant_id,code,name)
      VALUES(v_tenant,'admin','Admin') ON CONFLICT(tenant_id,code)
      DO UPDATE SET name=excluded.name RETURNING id INTO v_role;
    INSERT INTO agency.user_roles(user_id,role_id) VALUES(v_dual,v_role);
    IF NOT agency.commercial_admin(v_tenant,v_dual)
      OR agency.commercial_admin(gen_random_uuid(),v_dual)
      OR agency.has_panel_role(v_tenant,v_dual,'supplier') THEN
      RAISE EXCEPTION 'secondary_role_scope_failed'; END IF;
    v_dual_proposal:=agency.propose_listing_price(v_tenant,v_dual,v_listing,v_base+3000,
      'Yetkilendirme ve ikincil rol testi');
    PERFORM agency.review_listing_price(v_tenant,v_dual,v_dual_proposal,'rejected');
    PERFORM agency.queue_channel_update(v_tenant,v_dual,v_channel,v_listing,
      'role-'||v_dual::text,'price',jsonb_build_object('priceMinor',v_base+2000));
  END;
  RAISE NOTICE 'commercial workflows passed';
END $$;
ROLLBACK;
