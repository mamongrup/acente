-- A remote listing must have an accepted booking before any payment session
-- can be created or advanced. A queued webhook is not a booking confirmation.
CREATE OR REPLACE FUNCTION agency.nexus_reservation_ready(p_tenant uuid, p_reservation uuid)
RETURNS boolean LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_source text;
  v_reply jsonb;
BEGIN
  SELECT l.source INTO v_source
  FROM agency.reservations r
  JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
  WHERE r.id=p_reservation AND r.tenant_id=p_tenant;
  IF NOT FOUND THEN RETURN false; END IF;
  IF v_source<>'nexus' THEN RETURN true; END IF;

  SELECT d.last_response::jsonb INTO v_reply
  FROM agency.nexus_reservation_deliveries d
  WHERE d.tenant_id=p_tenant AND d.reservation_id=p_reservation
    AND d.event_type='reservation.created' AND d.status='sent';
  RETURN FOUND
    AND v_reply->'ok'='true'::jsonb
    AND v_reply->>'status' IN ('processed','duplicate_ignored')
    AND nullif(btrim(v_reply->>'booking_reference'),'') IS NOT NULL;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN false;
END $$;

CREATE OR REPLACE FUNCTION agency.checkout_session(tenant uuid, target_order uuid) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE o agency.orders%ROWTYPE; s agency.payment_sessions%ROWTYPE;
BEGIN
  SELECT * INTO STRICT o FROM agency.orders WHERE id=target_order AND tenant_id=tenant FOR UPDATE;
  IF o.status<>'pending' OR EXISTS(SELECT 1 FROM agency.payments WHERE order_id=o.id AND status='paid') THEN
    RAISE EXCEPTION 'order already completed';
  END IF;
  IF NOT agency.nexus_reservation_ready(tenant,o.reservation_id) THEN
    RAISE EXCEPTION 'nexus_fulfillment_pending';
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

-- Also protects sessions created before this migration from progressing to a
-- charge while the remote booking is unresolved.
CREATE OR REPLACE FUNCTION agency.guard_nexus_payment_session()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_reservation uuid;
BEGIN
  IF NEW.status IN ('created','starting','initiated','authorized') THEN
    SELECT o.reservation_id INTO v_reservation FROM agency.orders o
    WHERE o.id=NEW.order_id AND o.tenant_id=NEW.tenant_id;
    IF NOT agency.nexus_reservation_ready(NEW.tenant_id,v_reservation) THEN
      RAISE EXCEPTION 'nexus_fulfillment_pending';
    END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS agency_nexus_payment_session_guard ON agency.payment_sessions;
CREATE TRIGGER agency_nexus_payment_session_guard
BEFORE INSERT OR UPDATE OF status ON agency.payment_sessions
FOR EACH ROW EXECUTE FUNCTION agency.guard_nexus_payment_session();

REVOKE ALL ON FUNCTION agency.nexus_reservation_ready(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.nexus_reservation_ready(uuid,uuid) TO agency_app;
REVOKE ALL ON FUNCTION agency.checkout_session(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.checkout_session(uuid,uuid) TO agency_app;
