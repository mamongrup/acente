-- Keep in-flight/ambiguous attempts active: they must never be retried as a
-- fresh charge just because the browser session expired.
ALTER TABLE agency.payment_sessions DROP CONSTRAINT payment_sessions_status_check;
ALTER TABLE agency.payment_sessions ADD CONSTRAINT payment_sessions_status_check
  CHECK(status IN ('created','starting','initiated','authorized','paid','failed','cancelled','expired'));
DROP INDEX agency.agency_payment_sessions_active_order_idx;
CREATE UNIQUE INDEX agency_payment_sessions_active_order_idx
  ON agency.payment_sessions(order_id)
  WHERE status IN ('created','starting','initiated','authorized');
ALTER TABLE agency.orders ADD COLUMN checkout_fingerprint text;

-- Serialize before reading, rather than inserting a reservation before an
-- order UPSERT (which used to leave orphan reservations on concurrent retries).
CREATE FUNCTION agency.checkout_order(
  tenant uuid, customer_name text, customer_email text, customer_phone text,
  listing uuid, reference text, arrival date, departure date, guests int, request_key text
) RETURNS TABLE(id uuid, number text, reservation_id uuid, total_minor bigint, currency char(3))
LANGUAGE plpgsql AS $$
DECLARE
  existing agency.orders%ROWTYPE;
  product agency.listings%ROWTYPE;
  customer uuid;
  reservation uuid;
  amount bigint;
  fingerprint text := jsonb_build_array(listing, customer_name, lower(customer_email), customer_phone, arrival, departure, guests)::text;
BEGIN
  IF request_key = '' OR length(request_key)>120 OR departure<=arrival OR guests<1 OR guests>50 THEN
    RAISE EXCEPTION 'invalid checkout';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(tenant::text || ':' || request_key, 0));
  SELECT o.* INTO existing FROM agency.orders o WHERE o.tenant_id=tenant AND o.idempotency_key=request_key;
  IF FOUND THEN
    IF existing.checkout_fingerprint IS DISTINCT FROM fingerprint THEN
      RAISE EXCEPTION 'idempotency key payload mismatch';
    END IF;
    RETURN QUERY SELECT existing.id,existing.number,existing.reservation_id,existing.total_minor,existing.currency;
    RETURN;
  END IF;
  SELECT l.* INTO STRICT product FROM agency.listings l WHERE l.id=listing AND l.tenant_id=tenant AND l.status='published' FOR SHARE;
  IF product.currency<>'TRY' OR product.price_minor<=0 OR arrival<CURRENT_DATE THEN
    RAISE EXCEPTION 'invalid price or dates';
  END IF;
  IF EXISTS(SELECT 1 FROM agency.availability a WHERE a.listing_id=listing AND a.day>=arrival AND a.day<departure AND (a.closed OR a.units_available<1)) THEN
    RAISE EXCEPTION 'unavailable dates';
  END IF;
  amount := product.price_minor * CASE WHEN product.category IN ('hotel','holiday_home','villa','yacht') THEN departure-arrival ELSE 1 END;
  INSERT INTO agency.customers(tenant_id,full_name,email,phone)
  VALUES(tenant,customer_name,CASE WHEN customer_email<>'' THEN lower(customer_email) ELSE 'checkout-' || regexp_replace(customer_phone,'[^0-9]','','g') || '@invalid.local' END,customer_phone)
  ON CONFLICT(tenant_id,email) DO UPDATE SET full_name=excluded.full_name,phone=excluded.phone RETURNING agency.customers.id INTO customer;
  INSERT INTO agency.reservations(tenant_id,listing_id,customer_id,reference_code,check_in,check_out,guest_count,total_minor,currency,status,payment_status)
  VALUES(tenant,listing,customer,reference,arrival,departure,guests,amount,'TRY','option','pending') RETURNING agency.reservations.id INTO reservation;
  RETURN QUERY INSERT INTO agency.orders(tenant_id,customer_id,number,status,currency,subtotal_minor,total_minor,reservation_id,idempotency_key,checkout_fingerprint)
  VALUES(tenant,customer,reference,'pending','TRY',amount,amount,reservation,request_key,fingerprint)
  RETURNING agency.orders.id,agency.orders.number,agency.orders.reservation_id,agency.orders.total_minor,agency.orders.currency;
END $$;

CREATE FUNCTION agency.checkout_session(tenant uuid, target_order uuid) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE o agency.orders%ROWTYPE; s agency.payment_sessions%ROWTYPE;
BEGIN
  SELECT * INTO STRICT o FROM agency.orders WHERE id=target_order AND tenant_id=tenant FOR UPDATE;
  IF o.status<>'pending' OR EXISTS(SELECT 1 FROM agency.payments WHERE order_id=o.id AND status='paid') THEN
    RAISE EXCEPTION 'order already completed';
  END IF;
  SELECT * INTO s FROM agency.payment_sessions WHERE order_id=o.id AND status IN ('created','starting','initiated','authorized') FOR UPDATE;
  IF FOUND THEN
    IF s.status IN ('starting','authorized') OR s.expires_at>now() THEN RETURN s.id; END IF;
    UPDATE agency.payment_sessions SET status='expired',updated_at=now() WHERE id=s.id;
    UPDATE agency.payments SET status='failed' WHERE order_id=o.id AND provider='parampos' AND provider_reference=s.transaction_guid AND status='pending';
  END IF;
  INSERT INTO agency.payment_sessions(tenant_id,order_id,amount_minor,currency) VALUES(tenant,o.id,o.total_minor,o.currency) RETURNING id INTO s.id;
  RETURN s.id;
END $$;

REVOKE ALL ON FUNCTION agency.checkout_order(uuid,text,text,text,uuid,text,date,date,int,text), agency.checkout_session(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.checkout_order(uuid,text,text,text,uuid,text,date,date,int,text), agency.checkout_session(uuid,uuid) TO agency_app;

CREATE FUNCTION agency.parampos_transition(session uuid, action text, guid text DEFAULT '', receipt text DEFAULT '', response jsonb DEFAULT '{}') RETURNS boolean
LANGUAGE plpgsql AS $$
DECLARE s agency.payment_sessions%ROWTYPE; o agency.orders%ROWTYPE;
BEGIN
  -- Use the same order -> session lock order as checkout_session.
  SELECT orders.* INTO o FROM agency.orders orders JOIN agency.payment_sessions ps ON ps.order_id=orders.id WHERE ps.id=session FOR UPDATE OF orders;
  SELECT * INTO s FROM agency.payment_sessions WHERE id=session FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  IF action='claim_start' THEN
    IF s.status<>'created' OR s.expires_at<=now() OR o.status<>'pending' THEN RETURN false; END IF;
    UPDATE agency.payment_sessions SET status='starting',updated_at=now() WHERE id=session;
  ELSIF action='initiated' THEN
    IF s.status<>'starting' OR guid='' THEN RETURN false; END IF;
    INSERT INTO agency.payments(order_id,provider,provider_reference,amount_minor,currency,status)
    VALUES(s.order_id,'parampos',guid,s.amount_minor,s.currency,'pending');
    UPDATE agency.payment_sessions SET status='initiated',transaction_guid=guid,updated_at=now() WHERE id=session;
  ELSIF action='claim_pay' THEN
    IF s.status<>'initiated' OR s.expires_at<=now() OR o.status<>'pending' THEN RETURN false; END IF;
    UPDATE agency.payment_sessions SET status='authorized',updated_at=now() WHERE id=session;
  ELSIF action IN ('failed_start','failed_3d','failed_pay') THEN
    IF s.status<>(CASE action WHEN 'failed_start' THEN 'starting' WHEN 'failed_3d' THEN 'initiated' ELSE 'authorized' END) THEN RETURN false; END IF;
    UPDATE agency.payments SET status='failed' WHERE order_id=s.order_id AND provider='parampos' AND provider_reference=s.transaction_guid AND status='pending';
    UPDATE agency.payment_sessions SET status='failed',updated_at=now() WHERE id=session;
  ELSIF action='paid' THEN
    IF s.status='paid' THEN RETURN true; END IF;
    IF s.status<>'authorized' OR receipt='' OR receipt='0' THEN RETURN false; END IF;
    UPDATE agency.payments SET status='paid',raw_response=response || jsonb_build_object('receiptId',receipt)
      WHERE order_id=s.order_id AND provider='parampos' AND provider_reference=s.transaction_guid AND status='pending';
    IF NOT FOUND THEN RAISE EXCEPTION 'matching payment missing'; END IF;
    UPDATE agency.orders SET status='confirmed' WHERE id=s.order_id AND status='pending';
    IF NOT FOUND THEN RAISE EXCEPTION 'order cannot be confirmed'; END IF;
    UPDATE agency.reservations SET status='confirmed',payment_status='paid' WHERE id=o.reservation_id AND status='option';
    IF NOT FOUND THEN RAISE EXCEPTION 'reservation cannot be confirmed'; END IF;
    UPDATE agency.payment_sessions SET status='paid',updated_at=now() WHERE id=session;
  ELSE RAISE EXCEPTION 'invalid transition';
  END IF;
  RETURN true;
END $$;
REVOKE ALL ON FUNCTION agency.parampos_transition(uuid,text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.parampos_transition(uuid,text,text,text,jsonb) TO agency_app;
