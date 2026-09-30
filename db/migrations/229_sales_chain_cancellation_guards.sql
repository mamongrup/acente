-- Migration 227: Preserve refund and settlement truth during cancellation.

CREATE OR REPLACE FUNCTION agency.cancel_and_refund_order(
  p_tenant uuid,
  p_actor uuid,
  p_order uuid,
  p_reason text DEFAULT 'Customer requested cancellation'
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,agency,public
AS $$
DECLARE
  v_order agency.orders%ROWTYPE;
  v_res agency.reservations%ROWTYPE;
  v_payment agency.payments%ROWTYPE;
  v_refund_id uuid;
  v_settlement_annulled boolean := false;
  v_refunded_minor bigint;
  v_settlement_status text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM agency.users
    WHERE id=p_actor AND tenant_id=p_tenant AND membership_type IN ('admin','agent') AND active
  ) THEN
    RAISE EXCEPTION 'unauthorized_actor';
  END IF;

  SELECT * INTO v_order FROM agency.orders
  WHERE id=p_order AND tenant_id=p_tenant FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'order_not_found';
  END IF;

  IF v_order.status IN ('cancelled','refunded') THEN
    RETURN jsonb_build_object('ok',true,'status','already_cancelled','order_id',p_order);
  END IF;

  IF v_order.status NOT IN ('pending','confirmed') THEN
    RAISE EXCEPTION 'order_not_cancellable';
  END IF;

  SELECT status INTO v_settlement_status FROM agency.supplier_settlements s
    WHERE s.tenant_id=p_tenant AND s.reservation_id=v_order.reservation_id FOR UPDATE;
  IF v_settlement_status='paid' THEN
    RAISE EXCEPTION 'paid_settlement_requires_manual_reversal';
  END IF;

  IF EXISTS (SELECT 1 FROM agency.payment_sessions ps
    WHERE ps.order_id=v_order.id AND ps.status IN ('starting','initiated','authorized')) THEN
    RAISE EXCEPTION 'payment_in_progress';
  END IF;

  SELECT * INTO v_res FROM agency.reservations
  WHERE id=v_order.reservation_id AND tenant_id=p_tenant FOR UPDATE;

  -- 1. Cancel order
  UPDATE agency.orders SET status='cancelled' WHERE id=v_order.id;

  -- 2. Cancel reservation (this automatically triggers agency_reservation_nexus_outbox_trg for connected listings)
  IF v_res.id IS NOT NULL THEN
    UPDATE agency.reservations SET status='cancelled' WHERE id=v_res.id;

    -- Annul pending supplier settlement if exists
    UPDATE agency.supplier_settlements
    SET status='cancelled'
    WHERE reservation_id=v_res.id AND tenant_id=p_tenant AND status IN ('pending','approved');
    IF FOUND THEN
      v_settlement_annulled := true;
    END IF;
  END IF;

  -- 3. If there is a completed payment, record refund request
  SELECT * INTO v_payment FROM agency.payments
  WHERE order_id=v_order.id AND status='paid'
  ORDER BY created_at DESC LIMIT 1;

  IF v_payment.id IS NOT NULL THEN
    SELECT coalesce(sum(amount_minor),0) INTO v_refunded_minor FROM agency.refunds
    WHERE payment_id=v_payment.id AND status IN ('pending','processed');
    IF v_refunded_minor > 0 THEN
      RAISE EXCEPTION 'refund_already_requested';
    END IF;
    INSERT INTO agency.refunds(payment_id, amount_minor, reason, status)
    VALUES(v_payment.id, v_payment.amount_minor, p_reason, 'pending')
    RETURNING id INTO v_refund_id;
  END IF;

  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
  VALUES(p_tenant,p_actor,'sales_chain.order_cancelled_refund_requested','order',p_order,
    jsonb_build_object(
      'order_id', p_order,
      'reservation_id', v_res.id,
      'refund_id', v_refund_id,
      'payment_id', v_payment.id,
      'settlement_annulled', v_settlement_annulled,
      'reason', p_reason
    ));

  RETURN jsonb_build_object(
    'ok', true,
    'order_id', p_order,
    'reservation_id', v_res.id,
    'refund_id', v_refund_id,
    'settlement_annulled', v_settlement_annulled,
    'status', 'cancelled'
  );
END $$;

REVOKE ALL ON FUNCTION agency.cancel_and_refund_order(uuid,uuid,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.cancel_and_refund_order(uuid,uuid,uuid,text) TO agency_app;

