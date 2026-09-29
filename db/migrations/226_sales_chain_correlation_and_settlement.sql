-- Migration 226: Sales chain correlation, cancellation-refund workflow and single identity tracking
-- Provides agency.cancel_and_refund_order and agency.get_sales_chain_details for Work Package 2.

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
    INSERT INTO agency.refunds(payment_id, amount_minor, reason, status)
    VALUES(v_payment.id, v_payment.amount_minor, p_reason, 'pending')
    RETURNING id INTO v_refund_id;

    UPDATE agency.orders SET status='refunded' WHERE id=v_order.id;
  END IF;

  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
  VALUES(p_tenant,p_actor,'sales_chain.order_cancelled_and_refunded','order',p_order,
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

CREATE OR REPLACE FUNCTION agency.get_sales_chain_details(
  p_tenant uuid,
  p_order_id uuid
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,agency,public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'order', jsonb_build_object(
      'id', o.id,
      'number', o.number,
      'status', o.status,
      'total_minor', o.total_minor,
      'currency', o.currency,
      'idempotency_key', o.idempotency_key
    ),
    'reservation', jsonb_build_object(
      'id', r.id,
      'reference_code', r.reference_code,
      'status', r.status,
      'payment_status', r.payment_status,
      'check_in', r.check_in,
      'check_out', r.check_out,
      'guest_count', r.guest_count
    ),
    'listing', jsonb_build_object(
      'id', l.id,
      'title', l.title,
      'category', l.category,
      'source', l.source,
      'nexus_listing_id', l.metadata->>'nexus_listing_id'
    ),
    'payment', (
      SELECT jsonb_build_object(
        'id', p.id,
        'provider', p.provider,
        'status', p.status,
        'amount_minor', p.amount_minor,
        'provider_reference', p.provider_reference
      )
      FROM agency.payments p WHERE p.order_id=o.id ORDER BY p.created_at DESC LIMIT 1
    ),
    'refund', (
      SELECT jsonb_build_object(
        'id', rf.id,
        'amount_minor', rf.amount_minor,
        'status', rf.status,
        'reason', rf.reason
      )
      FROM agency.payments p
      JOIN agency.refunds rf ON rf.payment_id=p.id
      WHERE p.order_id=o.id ORDER BY rf.created_at DESC LIMIT 1
    ),
    'delivery', (
      SELECT jsonb_build_object(
        'id', d.id,
        'event_type', d.event_type,
        'status', d.status,
        'attempts', d.attempts,
        'last_response', d.last_response
      )
      FROM agency.nexus_reservation_deliveries d
      WHERE d.reservation_id=r.id ORDER BY d.created_at DESC LIMIT 1
    ),
    'settlement', (
      SELECT jsonb_build_object(
        'id', s.id,
        'gross_minor', s.gross_minor,
        'commission_minor', s.commission_minor,
        'net_minor', s.net_minor,
        'status', s.status
      )
      FROM agency.supplier_settlements s
      WHERE s.reservation_id=r.id LIMIT 1
    )
  ) INTO v_result
  FROM agency.orders o
  LEFT JOIN agency.reservations r ON r.id=o.reservation_id
  LEFT JOIN agency.listings l ON l.id=r.listing_id
  WHERE o.id=p_order_id AND o.tenant_id=p_tenant;

  IF v_result IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'order_not_found');
  END IF;

  RETURN jsonb_build_object('ok', true, 'chain', v_result);
END $$;

REVOKE ALL ON FUNCTION agency.cancel_and_refund_order(uuid,uuid,uuid,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.get_sales_chain_details(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.cancel_and_refund_order(uuid,uuid,uuid,text) TO agency_app;
GRANT EXECUTE ON FUNCTION agency.get_sales_chain_details(uuid,uuid) TO agency_app;
