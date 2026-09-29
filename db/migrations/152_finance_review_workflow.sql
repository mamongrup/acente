CREATE TABLE IF NOT EXISTS agency.payment_reconciliations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  payment_id uuid NOT NULL REFERENCES agency.payments(id) ON DELETE CASCADE,
  external_reference text NOT NULL CHECK(length(trim(external_reference)) BETWEEN 3 AND 160),
  amount_minor bigint NOT NULL CHECK(amount_minor > 0),
  note text NOT NULL DEFAULT '',
  recorded_by uuid NOT NULL REFERENCES agency.users(id),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,payment_id)
);
CREATE INDEX IF NOT EXISTS agency_payment_reconciliation_tenant_idx ON agency.payment_reconciliations(tenant_id,recorded_at DESC);

CREATE OR REPLACE FUNCTION agency.request_refund_review(
  p_tenant uuid,p_actor uuid,p_payment uuid,p_amount bigint,p_reason text
) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE paid_amount bigint; already_requested bigint; new_id uuid;
BEGIN
  IF p_amount <= 0 OR length(trim(p_reason)) NOT BETWEEN 3 AND 1000 THEN
    RAISE EXCEPTION 'invalid_refund_request';
  END IF;
  SELECT p.amount_minor INTO paid_amount FROM agency.payments p
    JOIN agency.orders o ON o.id=p.order_id
    WHERE p.id=p_payment AND o.tenant_id=p_tenant AND p.status='paid'
    FOR UPDATE OF p;
  IF paid_amount IS NULL THEN RAISE EXCEPTION 'payment_not_refundable'; END IF;
  SELECT coalesce(sum(amount_minor),0) INTO already_requested FROM agency.refunds
    WHERE payment_id=p_payment AND status IN ('pending','processed');
  IF already_requested+p_amount > paid_amount THEN RAISE EXCEPTION 'refund_amount_exceeded'; END IF;
  INSERT INTO agency.refunds(payment_id,amount_minor,reason,status)
    VALUES(p_payment,p_amount,trim(p_reason),'pending') RETURNING id INTO new_id;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'finance.refund_requested','refund',new_id,jsonb_build_object('paymentId',p_payment,'amountMinor',p_amount));
  RETURN new_id;
END $$;

CREATE OR REPLACE FUNCTION agency.record_payment_reconciliation(
  p_tenant uuid,p_actor uuid,p_payment uuid,p_external_reference text,p_note text
) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE amount bigint; new_id uuid;
BEGIN
  IF length(trim(p_external_reference)) NOT BETWEEN 3 AND 160 OR length(p_note)>1000 THEN
    RAISE EXCEPTION 'invalid_reconciliation';
  END IF;
  SELECT p.amount_minor INTO amount FROM agency.payments p
    JOIN agency.orders o ON o.id=p.order_id
    WHERE p.id=p_payment AND o.tenant_id=p_tenant AND p.status='paid'
    FOR UPDATE OF p;
  IF amount IS NULL THEN RAISE EXCEPTION 'payment_not_paid'; END IF;
  INSERT INTO agency.payment_reconciliations(tenant_id,payment_id,external_reference,amount_minor,note,recorded_by)
    VALUES(p_tenant,p_payment,trim(p_external_reference),amount,trim(p_note),p_actor)
    RETURNING id INTO new_id;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'finance.payment_reconciled','payment',p_payment,jsonb_build_object('reconciliationId',new_id,'externalReference',trim(p_external_reference)));
  RETURN new_id;
END $$;

GRANT SELECT,INSERT,UPDATE,DELETE ON agency.payment_reconciliations TO agency_app;
GRANT EXECUTE ON FUNCTION agency.request_refund_review(uuid,uuid,uuid,bigint,text),agency.record_payment_reconciliation(uuid,uuid,uuid,text,text) TO agency_app;
