-- ParamPOS refund dispatch is claimed once. Ambiguous network outcomes require
-- reconciliation; they must never be retried automatically.
CREATE TABLE agency.parampos_refund_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  refund_id uuid NOT NULL UNIQUE REFERENCES agency.refunds(id) ON DELETE RESTRICT,
  order_id uuid NOT NULL REFERENCES agency.orders(id) ON DELETE RESTRICT,
  amount_minor bigint NOT NULL CHECK(amount_minor>0),
  action text NOT NULL CHECK(action IN ('IPTAL','IADE')),
  status text NOT NULL DEFAULT 'processing'
    CHECK(status IN ('processing','succeeded','declined','unknown')),
  provider_reference text NOT NULL DEFAULT '',
  response_summary text NOT NULL DEFAULT '',
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz
);
CREATE INDEX parampos_refund_attempts_tenant_status_idx
  ON agency.parampos_refund_attempts(tenant_id,status,started_at);

CREATE FUNCTION agency.claim_parampos_refund(
  p_tenant uuid,p_actor uuid,p_refund uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_order agency.orders%ROWTYPE;
  v_payment agency.payments%ROWTYPE;
  v_refund agency.refunds%ROWTYPE;
  v_paid_at timestamptz;
  v_action text;
  v_attempt uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM agency.users u
    WHERE u.id=p_actor AND u.tenant_id=p_tenant AND u.active
      AND u.membership_type='admin') THEN
    RAISE EXCEPTION 'unauthorized_actor';
  END IF;

  SELECT o.* INTO v_order FROM agency.orders o
  JOIN agency.payments p ON p.order_id=o.id
  JOIN agency.refunds f ON f.payment_id=p.id
  WHERE f.id=p_refund AND o.tenant_id=p_tenant FOR UPDATE OF o;
  IF NOT FOUND OR v_order.status<>'cancelled' THEN
    RAISE EXCEPTION 'order_not_cancelled';
  END IF;
  SELECT p.* INTO STRICT v_payment FROM agency.payments p
  JOIN agency.refunds f ON f.payment_id=p.id
  WHERE f.id=p_refund FOR UPDATE OF p;
  SELECT * INTO STRICT v_refund FROM agency.refunds WHERE id=p_refund FOR UPDATE;
  IF v_payment.provider<>'parampos' OR v_payment.status<>'paid'
    OR v_payment.currency<>'TRY' OR v_refund.status<>'pending'
    OR v_refund.amount_minor<>v_payment.amount_minor THEN
    RAISE EXCEPTION 'refund_not_dispatchable';
  END IF;
  IF EXISTS (SELECT 1 FROM agency.supplier_settlements s
    WHERE s.tenant_id=p_tenant AND s.reservation_id=v_order.reservation_id
      AND s.status='paid') THEN
    RAISE EXCEPTION 'paid_settlement_requires_manual_reversal';
  END IF;
  IF EXISTS (SELECT 1 FROM agency.parampos_refund_attempts a
    WHERE a.refund_id=p_refund) THEN
    RAISE EXCEPTION 'refund_dispatch_already_claimed';
  END IF;

  SELECT ps.updated_at INTO v_paid_at FROM agency.payment_sessions ps
  WHERE ps.order_id=v_order.id AND ps.status='paid'
  ORDER BY ps.updated_at DESC LIMIT 1;
  v_action := CASE
    WHEN v_paid_at IS NOT NULL
      AND (v_paid_at AT TIME ZONE 'Europe/Istanbul')::date
        = (clock_timestamp() AT TIME ZONE 'Europe/Istanbul')::date
    THEN 'IPTAL' ELSE 'IADE' END;

  INSERT INTO agency.parampos_refund_attempts(
    tenant_id,refund_id,order_id,amount_minor,action
  ) VALUES (p_tenant,p_refund,v_order.id,v_refund.amount_minor,v_action)
  RETURNING id INTO v_attempt;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
  VALUES(p_tenant,p_actor,'finance.parampos_refund_claimed','refund',p_refund,
    jsonb_build_object('attemptId',v_attempt,'action',v_action));
  RETURN jsonb_build_object(
    'attempt_id',v_attempt,'order_id',v_order.id,
    'amount_minor',v_refund.amount_minor,'action',v_action
  );
END $$;

CREATE FUNCTION agency.finish_parampos_refund(
  p_tenant uuid,p_actor uuid,p_attempt uuid,p_outcome text,
  p_reference text,p_summary text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_attempt agency.parampos_refund_attempts%ROWTYPE;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM agency.users u
    WHERE u.id=p_actor AND u.tenant_id=p_tenant AND u.active
      AND u.membership_type='admin') THEN
    RAISE EXCEPTION 'unauthorized_actor';
  END IF;
  IF p_outcome NOT IN ('succeeded','declined','unknown')
    OR (p_outcome='succeeded' AND length(btrim(p_reference)) NOT BETWEEN 3 AND 160) THEN
    RAISE EXCEPTION 'invalid_refund_outcome';
  END IF;
  SELECT * INTO v_attempt FROM agency.parampos_refund_attempts
  WHERE id=p_attempt AND tenant_id=p_tenant FOR UPDATE;
  IF NOT FOUND OR v_attempt.status<>'processing' THEN
    RAISE EXCEPTION 'refund_attempt_not_processing';
  END IF;
  UPDATE agency.parampos_refund_attempts SET status=p_outcome,
    provider_reference=left(btrim(coalesce(p_reference,'')),160),
    response_summary=left(coalesce(p_summary,''),500),finished_at=now()
  WHERE id=p_attempt;
  IF p_outcome='succeeded' THEN
    UPDATE agency.refunds SET status='processed',
      provider_reference=left(btrim(p_reference),160)
    WHERE id=v_attempt.refund_id AND status='pending';
    IF NOT FOUND THEN RAISE EXCEPTION 'refund_state_changed'; END IF;
    UPDATE agency.payments SET status='refunded'
    WHERE id=(SELECT payment_id FROM agency.refunds WHERE id=v_attempt.refund_id)
      AND status='paid';
    IF NOT FOUND THEN RAISE EXCEPTION 'payment_state_changed'; END IF;
    UPDATE agency.orders SET status='refunded'
    WHERE id=v_attempt.order_id AND tenant_id=p_tenant AND status='cancelled';
    IF NOT FOUND THEN RAISE EXCEPTION 'order_state_changed'; END IF;
    UPDATE agency.reservations SET payment_status='refunded'
    WHERE id=(SELECT reservation_id FROM agency.orders WHERE id=v_attempt.order_id)
      AND tenant_id=p_tenant AND status='cancelled';
  ELSIF p_outcome='declined' THEN
    UPDATE agency.refunds SET status='failed' WHERE id=v_attempt.refund_id;
  END IF;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
  VALUES(p_tenant,p_actor,'finance.parampos_refund_'||p_outcome,'refund',v_attempt.refund_id,
    jsonb_build_object('attemptId',p_attempt,'providerReference',left(btrim(coalesce(p_reference,'')),160)));
  RETURN jsonb_build_object('ok',true,'status',p_outcome,'refund_id',v_attempt.refund_id);
END $$;

REVOKE ALL ON agency.parampos_refund_attempts FROM PUBLIC;
GRANT SELECT ON agency.parampos_refund_attempts TO agency_app;
REVOKE ALL ON FUNCTION agency.claim_parampos_refund(uuid,uuid,uuid),
  agency.finish_parampos_refund(uuid,uuid,uuid,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.claim_parampos_refund(uuid,uuid,uuid),
  agency.finish_parampos_refund(uuid,uuid,uuid,text,text,text) TO agency_app;
