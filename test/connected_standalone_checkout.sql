BEGIN;
DO $$
DECLARE v_tenant uuid; v_local uuid; v_remote uuid; v_listing uuid;
  v_source text; v_order record; v_session uuid; v_delivery_count int;
  v_blocked boolean; v_actor uuid; v_customer_actor uuid; v_delivery uuid;
BEGIN
  SELECT id INTO STRICT v_tenant FROM agency.tenants WHERE slug='nexus-demo';
  INSERT INTO agency.users(tenant_id,email,display_name,membership_type,active)
  VALUES(v_tenant,'mode-check-admin@example.invalid','Mode Check Admin','admin',true)
  RETURNING id INTO v_actor;
  INSERT INTO agency.users(tenant_id,email,display_name,membership_type,active)
  VALUES(v_tenant,'mode-check-customer@example.invalid','Mode Check Customer','customer',true)
  RETURNING id INTO v_customer_actor;
  FOREACH v_source IN ARRAY ARRAY['manual','nexus'] LOOP
    INSERT INTO agency.listings(
      tenant_id,code,category,title,locality,description,currency,price_minor,
      status,source,metadata,images,owner_info,cancellation_policy)
    VALUES(v_tenant,'mode-check-'||v_source||'-'||gen_random_uuid(),
      'hotel','Reservation mode test','Antalya','Reservation mode test listing',
      'TRY',10000,'published',v_source,
      jsonb_build_object('property_type','Otel','room_types','Standart Oda',
        'board_type','Oda Kahvaltı','check_in_time','14:00',
        'check_out_time','12:00','nexus_listing_id',
        CASE WHEN v_source='nexus' THEN gen_random_uuid()::text ELSE '' END),
      jsonb_build_array(jsonb_build_object('url','/static/placeholder.jpg')),
      jsonb_build_object('provider','Reservation mode test'),
      jsonb_build_object('policy','Standard')) RETURNING id INTO v_listing;
    IF v_source='manual' THEN v_local:=v_listing; ELSE v_remote:=v_listing; END IF;
    SELECT * INTO STRICT v_order FROM agency.checkout_order(v_tenant,'Mode Test',
      'mode-test@example.invalid','',v_listing,'MODE-'||gen_random_uuid(),
      current_date+1,current_date+2,2,'mode-'||gen_random_uuid());
    IF v_order.total_minor<>10000 THEN RAISE EXCEPTION 'mode_checkout_amount'; END IF;
    IF v_source='nexus' THEN
      SELECT id INTO STRICT v_delivery FROM agency.nexus_reservation_deliveries
      WHERE reservation_id=v_order.reservation_id AND event_type='reservation.created';
      UPDATE agency.nexus_reservation_deliveries SET status='failed',attempts=8
      WHERE id=v_delivery;
      v_blocked:=false;
      BEGIN
        PERFORM agency.retry_nexus_reservation_delivery(v_tenant,v_customer_actor,v_delivery);
      EXCEPTION WHEN OTHERS THEN
        IF SQLERRM<>'delivery_retry_forbidden' THEN RAISE; END IF;
        v_blocked:=true;
      END;
      IF NOT v_blocked THEN RAISE EXCEPTION 'customer_delivery_retry_allowed'; END IF;
      IF agency.retry_nexus_reservation_delivery(v_tenant,v_actor,gen_random_uuid()) THEN
        RAISE EXCEPTION 'foreign_delivery_retry_allowed'; END IF;
      IF NOT agency.retry_nexus_reservation_delivery(v_tenant,v_actor,v_delivery) THEN
        RAISE EXCEPTION 'admin_delivery_retry_returned_false'; END IF;
      IF NOT EXISTS(SELECT 1 FROM agency.nexus_reservation_deliveries
          WHERE id=v_delivery AND status='pending' AND attempts=0
            AND next_attempt_at<=now()) THEN
        RAISE EXCEPTION 'admin_delivery_retry_status'; END IF;
      IF NOT EXISTS(SELECT 1 FROM agency.audit_logs
          WHERE tenant_id=v_tenant AND user_id=v_actor
            AND action='nexus.reservation_delivery.retry'
            AND metadata->>'delivery_id'=v_delivery::text
            AND metadata->>'previous_attempts'='8') THEN
        RAISE EXCEPTION 'admin_delivery_retry_audit'; END IF;
      IF agency.retry_nexus_reservation_delivery(v_tenant,v_actor,v_delivery) THEN
        RAISE EXCEPTION 'nonfailed_delivery_retried';
      END IF;
      UPDATE agency.nexus_reservation_deliveries SET status='failed',attempts=100
      WHERE id=v_delivery;
      IF agency.retry_nexus_reservation_delivery(v_tenant,v_actor,v_delivery) THEN
        RAISE EXCEPTION 'terminal_delivery_retried'; END IF;
      UPDATE agency.nexus_reservation_deliveries SET status='pending',attempts=0
      WHERE id=v_delivery;
      v_blocked:=false;
      BEGIN
        PERFORM agency.checkout_session(v_tenant,v_order.id);
      EXCEPTION WHEN OTHERS THEN
        IF SQLERRM<>'nexus_fulfillment_pending' THEN RAISE; END IF;
        v_blocked:=true;
      END;
      IF NOT v_blocked THEN RAISE EXCEPTION 'nexus_checkout_allowed_before_booking'; END IF;
      v_blocked:=false;
      BEGIN
        INSERT INTO agency.payment_sessions(tenant_id,order_id,amount_minor,currency)
        VALUES(v_tenant,v_order.id,v_order.total_minor,'TRY');
      EXCEPTION WHEN OTHERS THEN
        IF SQLERRM<>'nexus_fulfillment_pending' THEN RAISE; END IF;
        v_blocked:=true;
      END;
      IF NOT v_blocked THEN RAISE EXCEPTION 'nexus_direct_session_allowed_before_booking'; END IF;
      UPDATE agency.nexus_reservation_deliveries
      SET status='sent',last_response='{"ok":false,"status":"failed","booking_reference":"BAD"}'
      WHERE reservation_id=v_order.reservation_id AND event_type='reservation.created';
      IF agency.nexus_reservation_ready(v_tenant,v_order.reservation_id) THEN
        RAISE EXCEPTION 'failed_booking_receipt_accepted';
      END IF;
      UPDATE agency.nexus_reservation_deliveries
      SET last_response=jsonb_build_object('ok',true,'status','processed',
        'booking_reference',jsonb_build_object('error','booking_unavailable')::text)::text
      WHERE reservation_id=v_order.reservation_id AND event_type='reservation.created';
      IF agency.nexus_reservation_ready(v_tenant,v_order.reservation_id) THEN
        RAISE EXCEPTION 'json_booking_error_accepted';
      END IF;
      UPDATE agency.nexus_reservation_deliveries
      SET last_response='{"ok":true,"status":"processed","booking_reference":"error: booking_unavailable"}'
      WHERE reservation_id=v_order.reservation_id AND event_type='reservation.created';
      IF agency.nexus_reservation_ready(v_tenant,v_order.reservation_id) THEN
        RAISE EXCEPTION 'text_booking_error_accepted';
      END IF;
      UPDATE agency.nexus_reservation_deliveries
      SET last_response=jsonb_build_object('ok',true,'status','processed',
        'booking_reference',gen_random_uuid(),
        'total_minor',v_order.total_minor-1,'currency',v_order.currency,
        'expires_at',now()+interval '30 minutes')::text
      WHERE reservation_id=v_order.reservation_id AND event_type='reservation.created';
      IF agency.nexus_reservation_ready(v_tenant,v_order.reservation_id) THEN
        RAISE EXCEPTION 'mismatched_remote_price_accepted';
      END IF;
      UPDATE agency.nexus_reservation_deliveries
      SET last_response=jsonb_build_object('ok',true,'status','processed',
        'booking_reference',gen_random_uuid(),
        'total_minor',v_order.total_minor,'currency',v_order.currency,
        'expires_at',now()-interval '1 minute')::text
      WHERE reservation_id=v_order.reservation_id AND event_type='reservation.created';
      IF agency.nexus_reservation_ready(v_tenant,v_order.reservation_id) THEN
        RAISE EXCEPTION 'expired_remote_booking_accepted';
      END IF;
      UPDATE agency.nexus_reservation_deliveries
      SET last_response=jsonb_build_object('ok',true,'status','processed',
        'booking_reference',gen_random_uuid(),
        'total_minor',v_order.total_minor,'currency',v_order.currency,
        'expires_at',now()+interval '30 minutes')::text
      WHERE reservation_id=v_order.reservation_id AND event_type='reservation.created';
    END IF;
    v_session:=agency.checkout_session(v_tenant,v_order.id);
    IF NOT EXISTS(SELECT 1 FROM agency.payment_sessions
      WHERE id=v_session AND order_id=v_order.id AND amount_minor=10000) THEN
      RAISE EXCEPTION 'mode_payment_session'; END IF;
    IF v_source='nexus' THEN
      UPDATE agency.nexus_reservation_deliveries
      SET status='failed',last_response=''
      WHERE reservation_id=v_order.reservation_id AND event_type='reservation.created';
      v_blocked:=false;
      BEGIN
        UPDATE agency.payment_sessions SET status='starting' WHERE id=v_session;
      EXCEPTION WHEN OTHERS THEN
        IF SQLERRM<>'nexus_fulfillment_pending' THEN RAISE; END IF;
        v_blocked:=true;
      END;
      IF NOT v_blocked THEN RAISE EXCEPTION 'old_nexus_session_advanced_without_booking'; END IF;
      UPDATE agency.nexus_reservation_deliveries
      SET status='sent',last_response=jsonb_build_object('ok',true,'status','processed',
        'booking_reference',gen_random_uuid(),
        'total_minor',v_order.total_minor,'currency',v_order.currency,
        'expires_at',now()+interval '30 minutes')::text
      WHERE reservation_id=v_order.reservation_id AND event_type='reservation.created';
    END IF;
    SELECT count(*) INTO v_delivery_count FROM agency.nexus_reservation_deliveries
      WHERE reservation_id=v_order.reservation_id AND event_type='reservation.created';
    IF v_delivery_count<>(CASE WHEN v_source='nexus' THEN 1 ELSE 0 END) THEN
      RAISE EXCEPTION 'mode_delivery_scope: % %',v_source,v_delivery_count; END IF;
    IF v_source='nexus' THEN
      UPDATE agency.reservations SET status='confirmed'
      WHERE id=v_order.reservation_id;
      IF NOT EXISTS(SELECT 1 FROM agency.nexus_reservation_deliveries
        WHERE reservation_id=v_order.reservation_id
          AND event_type='reservation.status_changed'
          AND reservation_status='confirmed') THEN
        RAISE EXCEPTION 'mode_status_delivery'; END IF;
    END IF;
  END LOOP;
  INSERT INTO agency.listings(
    tenant_id,code,category,title,locality,description,currency,price_minor,
    status,source,metadata,images,owner_info,cancellation_policy)
  VALUES(v_tenant,'mode-check-connected-tour-'||gen_random_uuid(),
    'tour','Connected tour mode test','Antalya','Connected tour mode test listing',
    'TRY',10000,'published','nexus',jsonb_build_object('contract_fields',
      jsonb_build_object('tour_type','Kültür','duration','1 gün','start_point','Antalya')),
    jsonb_build_array(jsonb_build_object('url','/static/placeholder.jpg')),
    jsonb_build_object('provider','Reservation mode test'),
    jsonb_build_object('policy','Standard')) RETURNING id INTO v_listing;
  v_blocked:=false;
  BEGIN
    PERFORM agency.checkout_order(v_tenant,'Mode Test','tour-mode@example.invalid','',
      v_listing,'TOUR-'||gen_random_uuid(),current_date+1,current_date+2,2,
      'unsupported-tour-'||gen_random_uuid());
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM<>'nexus_booking_unavailable' THEN RAISE; END IF;
    v_blocked:=true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'unsupported_connected_category_order_created'; END IF;
  INSERT INTO agency.listings(
    tenant_id,code,category,title,locality,description,currency,price_minor,
    status,source,metadata,images,owner_info,cancellation_policy)
  VALUES(v_tenant,'mode-check-local-tour-'||gen_random_uuid(),
    'tour','Local tour mode test','Antalya','Local tour mode test listing',
    'TRY',10000,'published','manual',jsonb_build_object('contract_fields',
      jsonb_build_object('tour_type','Kültür','duration','1 gün','start_point','Antalya')),
    jsonb_build_array(jsonb_build_object('url','/static/placeholder.jpg')),
    jsonb_build_object('provider','Reservation mode test'),
    jsonb_build_object('policy','Standard')) RETURNING id INTO v_listing;
  SELECT * INTO STRICT v_order FROM agency.checkout_order(v_tenant,'Mode Test',
    'local-tour-mode@example.invalid','',v_listing,'LOCAL-TOUR-'||gen_random_uuid(),
    current_date+1,current_date+2,2,'local-tour-'||gen_random_uuid());
  v_session:=agency.checkout_session(v_tenant,v_order.id);
  IF NOT EXISTS(SELECT 1 FROM agency.payment_sessions
    WHERE id=v_session AND order_id=v_order.id) THEN
    RAISE EXCEPTION 'local_tour_payment_session_missing';
  END IF;
  IF v_local=v_remote THEN RAISE EXCEPTION 'mode_listing_collision'; END IF;
  RAISE NOTICE 'standalone and connected local checkout passed';
END $$;
ROLLBACK;
