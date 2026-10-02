BEGIN;
DO $$
DECLARE t uuid; a uuid; c uuid; u uuid; l uuid; target uuid; r uuid; campaign uuid;
  journey jsonb; claim text; order_row record; customer_email text; checkout_key text;
BEGIN
  IF (SELECT count(DISTINCT source_category) FROM agency.journey_question_rules)<>17 THEN
    RAISE EXCEPTION 'canonical_category_coverage_missing'; END IF;
  SELECT tenant_id,id INTO t,a FROM agency.users WHERE membership_type='admin' AND active LIMIT 1;
  IF t IS NULL THEN
    -- Self-seeding: admin yoksa ilk tenant'a tohumlanir.
    SELECT id INTO t FROM agency.tenants ORDER BY created_at LIMIT 1;
    IF t IS NULL THEN RAISE EXCEPTION 'tenant fixture missing'; END IF;
    INSERT INTO agency.users(tenant_id,email,display_name,membership_type)
      VALUES(t,'seed-admin-'||gen_random_uuid()::text||'@example.test','Seed Admin','admin')
      RETURNING id INTO a;
  END IF;
  INSERT INTO agency.users(tenant_id,email,display_name,membership_type)
    VALUES(t,'journey-'||gen_random_uuid()::text||'@example.test','Journey Test','customer')
    RETURNING id INTO u;
  INSERT INTO agency.customers(tenant_id,full_name,email)
    SELECT t,'Journey Test',email FROM agency.users WHERE id=u RETURNING id INTO c;
  INSERT INTO agency.listings(tenant_id,code,category,title,locality,description,images,metadata,status,price_minor)
    VALUES(t,'journey-flight-'||gen_random_uuid()::text,'flight','Test uçuşu','Bodrum','Bodrum uçuş testi',
      '["https://example.test/flight.jpg"]'::jsonb,
      jsonb_build_object('contract_fields',coalesce((select jsonb_object_agg(f.field_key,'test')
        from agency.category_fields f join agency.categories cat ON cat.id=f.category_id
        where cat.tenant_id=t and cat.code='flight' and f.required),'{}'::jsonb)
        || jsonb_build_object('route_to','Bodrum')),
      'published',200000)
    RETURNING id INTO l;
  INSERT INTO agency.listings(tenant_id,code,category,title,locality,description,images,metadata,status,price_minor)
    VALUES(t,'journey-car-'||gen_random_uuid()::text,'car','Bodrum test aracı','Bodrum','Bodrum araç testi',
      '["https://example.test/car.jpg"]'::jsonb,
      jsonb_build_object('contract_fields',coalesce((select jsonb_object_agg(f.field_key,'test')
        from agency.category_fields f join agency.categories cat ON cat.id=f.category_id
        where cat.tenant_id=t and cat.code='car' and f.required),'{}'::jsonb)),
      'published',50000)
    RETURNING id INTO target;
  INSERT INTO agency.reservations(tenant_id,customer_id,listing_id,reference_code,status,check_in,check_out)
    VALUES(t,c,l,'JOURNEY-'||gen_random_uuid()::text,'confirmed',current_date+3,current_date+5)
    RETURNING id INTO r;
  journey:=agency.customer_journey_recommendations(t,u);
  IF jsonb_array_length(journey)<5 OR NOT EXISTS(
    SELECT 1 FROM jsonb_array_elements(journey) x
    WHERE x->>'targetCategory'='car' AND x->'suggestion'->>'id'=target::text
      AND x->'offer'='null'::jsonb) THEN RAISE EXCEPTION 'journey_candidates_missing'; END IF;
  IF NOT agency.answer_journey_question(t,u,r,'car','yes')
    OR agency.answer_journey_question(gen_random_uuid(),u,r,'car','yes')
    OR agency.answer_journey_question(t,u,r,'visa','yes') THEN
    RAISE EXCEPTION 'journey_answer_scope_failed'; END IF;
  IF NOT agency.save_customer_journey_lead_followup(t,a,u,r,'car','contacted','Araç teklifi görüşüldü')
    OR agency.save_customer_journey_lead_followup(gen_random_uuid(),a,u,r,'car','closed','')
    OR agency.save_customer_journey_lead_followup(t,u,u,r,'car','closed','') THEN
    RAISE EXCEPTION 'lead_followup_scope_failed'; END IF;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(agency.customer_journey_leads(t,a)) x
    WHERE x->>'reservationId'=r::text AND x->>'status'='contacted') THEN
    RAISE EXCEPTION 'lead_followup_missing'; END IF;
  campaign:=agency.save_customer_cross_sell_campaign(t,a,'Araç kampanyası','flight','car',10,
    current_date,current_date+10);
  PERFORM agency.activate_customer_cross_sell_campaign(t,a,campaign);
  journey:=agency.customer_journey_recommendations(t,u);
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(journey) x WHERE
    x->>'targetCategory'='car' AND x->>'answer'='yes' AND x->'offer'->>'percent'='10.00') THEN
    RAISE EXCEPTION 'journey_campaign_missing'; END IF;
  claim:=agency.claim_customer_journey_discount(t,u,r,target);
  SELECT email INTO customer_email FROM agency.users WHERE id=u;
  checkout_key:='journey-checkout-'||gen_random_uuid()::text;
  SELECT * INTO order_row FROM agency.checkout_order_with_journey_discount(t,'Journey Test',customer_email,
    '',target,'JOURNEY-ORDER-'||gen_random_uuid()::text,current_date+3,current_date+4,2,
    checkout_key,u,claim);
  IF order_row.total_minor<>45000 OR NOT EXISTS(SELECT 1 FROM agency.orders o
    JOIN agency.reservations reservation ON reservation.id=o.reservation_id
    WHERE o.id=order_row.id AND o.subtotal_minor=50000 AND o.discount_minor=5000
      AND o.total_minor=45000 AND reservation.total_minor=45000) THEN
    RAISE EXCEPTION 'checkout_discount_not_applied'; END IF;
  IF (SELECT x.total_minor FROM agency.checkout_order_with_journey_discount(t,'Journey Test',customer_email,
    '',target,'UNUSED-REF',current_date+3,current_date+4,2,checkout_key,u,claim) x)<>45000 THEN
    RAISE EXCEPTION 'discount_retry_not_idempotent'; END IF;
  BEGIN
    PERFORM agency.checkout_order_with_journey_discount(t,'Journey Test',customer_email,
      '',target,'ANOTHER-REF',current_date+3,current_date+4,2,
      'other-'||gen_random_uuid()::text,u,claim);
    RAISE EXCEPTION 'discount_claim_reused';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='discount_claim_reused' THEN RAISE; END IF;
  END;
  PERFORM agency.set_customer_cross_sell_campaign_status(t,a,campaign,'paused');
  BEGIN
    PERFORM agency.checkout_order_with_journey_discount(t,'Journey Test',customer_email,
      '',target,'PAUSED-REF',current_date+3,current_date+4,2,
      'paused-'||gen_random_uuid()::text,u,claim);
    RAISE EXCEPTION 'paused_discount_accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='paused_discount_accepted' THEN RAISE; END IF;
  END;
  journey:=agency.customer_journey_recommendations(t,u);
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(journey) x WHERE
    x->>'targetCategory'='car' AND x->'offer'<>'null'::jsonb) THEN
    RAISE EXCEPTION 'paused_campaign_still_visible'; END IF;
  PERFORM agency.set_customer_cross_sell_campaign_status(t,a,campaign,'active');
  RAISE NOTICE 'customer journey and conditional campaign passed';
END $$;
ROLLBACK;
