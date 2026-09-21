-- Executed in a rolled-back transaction by scripts/test-parampos.ps1.
DO $$
DECLARE
  tenant uuid; listing uuid; o record; repeated record; session uuid; fresh uuid;
  total int; mismatch boolean := false; failed boolean := false;
BEGIN
  SELECT id INTO STRICT tenant FROM agency.tenants LIMIT 1;
  INSERT INTO agency.listings(tenant_id,code,category,title,price_minor,status)
    VALUES(tenant,'parampos-test-'||gen_random_uuid(),'hotel','Payment test',12345,'published') RETURNING id INTO listing;
  SELECT * INTO STRICT o FROM agency.checkout_order(tenant,'Test','parampos-test@example.invalid','',listing,'TEST-'||gen_random_uuid(),CURRENT_DATE+1,CURRENT_DATE+4,2,'parampos-test-'||listing);
  ASSERT o.total_minor=37035, 'server price must include nights';
  SELECT * INTO STRICT repeated FROM agency.checkout_order(tenant,'Test','parampos-test@example.invalid','',listing,'ignored',CURRENT_DATE+1,CURRENT_DATE+4,2,'parampos-test-'||listing);
  ASSERT repeated.id=o.id, 'retry must reuse order';
  SELECT count(*) INTO total FROM agency.reservations WHERE listing_id=listing;
  ASSERT total=1, 'retry must not leave another reservation';
  BEGIN
    PERFORM agency.checkout_order(tenant,'Changed','parampos-test@example.invalid','',listing,'ignored',CURRENT_DATE+1,CURRENT_DATE+4,2,'parampos-test-'||listing);
  EXCEPTION WHEN raise_exception THEN mismatch:=true;
  END;
  ASSERT mismatch, 'changed payload must be rejected';
  session:=agency.checkout_session(tenant,o.id);
  ASSERT agency.checkout_session(tenant,o.id)=session, 'reuse active session';
  ASSERT agency.parampos_transition(session,'claim_start'), 'claim first start';
  ASSERT NOT agency.parampos_transition(session,'claim_start'), 'duplicate start blocked';
  ASSERT agency.parampos_transition(session,'initiated','guid-expired'), 'record start';
  UPDATE agency.payment_sessions SET expires_at=now()-interval '1 second' WHERE id=session;
  ASSERT NOT agency.parampos_transition(session,'claim_pay'), 'expired callback blocked';
  fresh:=agency.checkout_session(tenant,o.id);
  ASSERT fresh<>session, 'expired session replaced';
  ASSERT (SELECT status='failed' FROM agency.payments WHERE order_id=o.id AND provider_reference='guid-expired'), 'expired payment closed';
  session:=fresh;
  ASSERT agency.parampos_transition(session,'claim_start');
  ASSERT agency.parampos_transition(session,'initiated','guid-failed');
  ASSERT agency.parampos_transition(session,'failed_3d');
  ASSERT NOT agency.parampos_transition(session,'claim_pay'), 'failed 3D never charges';
  ASSERT (SELECT payment_status='pending' FROM agency.reservations WHERE id=o.reservation_id), 'failed 3D cannot confirm reservation';
  session:=agency.checkout_session(tenant,o.id);
  ASSERT agency.parampos_transition(session,'claim_start');
  ASSERT agency.parampos_transition(session,'initiated','guid-paid');
  ASSERT agency.parampos_transition(session,'claim_pay');
  ASSERT NOT agency.parampos_transition(session,'claim_pay'), 'duplicate callback cannot charge';
  UPDATE agency.payment_sessions SET expires_at=now()-interval '1 second' WHERE id=session;
  ASSERT agency.checkout_session(tenant,o.id)=session, 'ambiguous charge cannot be replaced after timeout';
  -- A persistence failure must roll back the payment update as well.
  UPDATE agency.reservations SET status='cancelled' WHERE id=o.reservation_id;
  BEGIN
    PERFORM agency.parampos_transition(session,'paid','','98765');
  EXCEPTION WHEN raise_exception THEN failed:=true;
  END;
  ASSERT failed;
  ASSERT (SELECT status='pending' FROM agency.payments WHERE provider_reference='guid-paid' AND order_id=o.id), 'failed confirmation rolls back payment';
  UPDATE agency.reservations SET status='option' WHERE id=o.reservation_id;
  ASSERT agency.parampos_transition(session,'paid','','98765');
  ASSERT agency.parampos_transition(session,'paid','','98765'), 'success callback is idempotent';
  ASSERT (SELECT status='confirmed' FROM agency.orders WHERE id=o.id);
  ASSERT (SELECT status='confirmed' AND payment_status='paid' FROM agency.reservations WHERE id=o.reservation_id);
  failed:=false;
  BEGIN
    PERFORM agency.checkout_session(tenant,o.id);
  EXCEPTION WHEN raise_exception THEN failed:=true;
  END;
  ASSERT failed, 'paid order cannot get a fresh payment session';
END $$;
