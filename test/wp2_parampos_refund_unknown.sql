-- A transport timeout has an unknown bank result. Never dispatch that refund twice.
BEGIN;
DO $$
DECLARE
  v_tenant uuid;
  v_admin uuid;
  v_listing uuid;
  v_order record;
  v_cancel jsonb;
  v_claim jsonb;
  v_blocked boolean := false;
BEGIN
  SELECT id INTO STRICT v_tenant FROM agency.tenants WHERE slug='nexus-demo';
  INSERT INTO agency.users(tenant_id,email,display_name,membership_type,active)
  VALUES(v_tenant,'wp2-unknown-'||gen_random_uuid()||'@example.invalid',
    'WP2 Refund Admin','admin',true) RETURNING id INTO v_admin;
  INSERT INTO agency.listings(
    tenant_id,code,category,title,locality,description,currency,price_minor,
    status,source,metadata,images,owner_info,cancellation_policy,owner_user_id
  ) VALUES (
    v_tenant,'wp2-unknown-'||gen_random_uuid(),'hotel','WP2 Unknown',
    'Antalya','Refund timeout fixture','TRY',10000,'published','manual',
    jsonb_build_object('property_type','Otel','room_types','Standart Oda',
      'board_type','Oda Kahvaltı','check_in_time','14:00','check_out_time','12:00'),
    jsonb_build_array(jsonb_build_object('url','/static/placeholder.jpg')),
    jsonb_build_object('provider','Test'),jsonb_build_object('policy','Test'),v_admin
  ) RETURNING id INTO v_listing;
  SELECT * INTO STRICT v_order FROM agency.checkout_order(
    v_tenant,'WP2 Customer','wp2-unknown-customer@example.invalid','',
    v_listing,'WP2-UNK-'||gen_random_uuid(),current_date+2,current_date+3,1,
    'wp2-unknown-'||gen_random_uuid()
  );
  INSERT INTO agency.payments(order_id,provider,provider_reference,amount_minor,currency,status)
  VALUES(v_order.id,'parampos','fixture-guid',10000,'TRY','paid');
  UPDATE agency.orders SET status='confirmed' WHERE id=v_order.id;
  UPDATE agency.reservations SET status='confirmed',payment_status='paid'
  WHERE id=v_order.reservation_id;
  UPDATE agency.orders SET status='cancelled' WHERE id=v_order.id;
  UPDATE agency.reservations SET status='cancelled' WHERE id=v_order.reservation_id;
  v_cancel := agency.cancel_and_refund_order(v_tenant,v_admin,v_order.id,'Timeout test');
  IF v_cancel->>'refund_id' IS NULL THEN
    RAISE EXCEPTION 'Previously cancelled paid order lost its refund request';
  END IF;
  v_claim := agency.claim_parampos_refund(
    v_tenant,v_admin,(v_cancel->>'refund_id')::uuid);
  PERFORM agency.finish_parampos_refund(v_tenant,v_admin,
    (v_claim->>'attempt_id')::uuid,'unknown','','Transport timeout');
  IF (SELECT status FROM agency.orders WHERE id=v_order.id)<>'cancelled'
    OR (SELECT status FROM agency.refunds WHERE id=(v_cancel->>'refund_id')::uuid)<>'pending'
    OR (SELECT status FROM agency.parampos_refund_attempts
      WHERE id=(v_claim->>'attempt_id')::uuid)<>'unknown' THEN
    RAISE EXCEPTION 'Unknown ParamPOS result was treated as completed';
  END IF;
  BEGIN
    PERFORM agency.claim_parampos_refund(v_tenant,v_admin,(v_cancel->>'refund_id')::uuid);
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%refund_dispatch_already_claimed%' THEN v_blocked := true; END IF;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'Unknown ParamPOS result can be dispatched again';
  END IF;
  RAISE NOTICE 'WP2 ParamPOS unknown-result guard passed';
END $$;
ROLLBACK;
