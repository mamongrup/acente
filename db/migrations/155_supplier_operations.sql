CREATE TABLE IF NOT EXISTS agency.supplier_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  supplier_user_id uuid NOT NULL,
  document_type text NOT NULL,
  document_url text NOT NULL CHECK (document_url ~ '^https://[^[:space:]]{5,1000}$'),
  expires_on date,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  review_note text NOT NULL DEFAULT '',
  submitted_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid,
  FOREIGN KEY(tenant_id,supplier_user_id) REFERENCES agency.users(tenant_id,id) ON DELETE CASCADE,
  FOREIGN KEY(tenant_id,reviewed_by) REFERENCES agency.users(tenant_id,id)
);
CREATE UNIQUE INDEX IF NOT EXISTS agency_reservations_tenant_id_unique ON agency.reservations(tenant_id,id);
CREATE UNIQUE INDEX IF NOT EXISTS supplier_one_pending_document ON agency.supplier_documents(tenant_id,supplier_user_id,document_type) WHERE status='pending';
CREATE INDEX IF NOT EXISTS supplier_documents_expiry_idx ON agency.supplier_documents(tenant_id,expires_on) WHERE status='approved';

CREATE OR REPLACE FUNCTION agency.submit_supplier_document(p_tenant uuid,p_actor uuid,p_type text,p_url text,p_expires date)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM agency.users u WHERE u.id=p_actor AND u.tenant_id=p_tenant AND u.active
    AND (u.membership_type='supplier' OR EXISTS(SELECT 1 FROM agency.user_roles ur JOIN agency.roles r ON r.id=ur.role_id WHERE ur.user_id=u.id AND r.tenant_id=p_tenant AND r.code='supplier')))
     OR NOT EXISTS (SELECT 1 FROM agency.supplier_onboarding_contract_items WHERE kind='required_document' AND code=p_type)
     OR p_url !~ '^https://[^[:space:]]{5,1000}$'
     OR (p_expires IS NOT NULL AND p_expires<current_date)
  THEN RAISE EXCEPTION 'invalid_supplier_document'; END IF;
  INSERT INTO agency.supplier_documents(tenant_id,supplier_user_id,document_type,document_url,expires_on)
    VALUES(p_tenant,p_actor,p_type,p_url,p_expires) RETURNING id INTO v_id;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'supplier.document_submitted','supplier_document',v_id,jsonb_build_object('type',p_type,'expiresOn',p_expires));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.review_supplier_document(p_tenant uuid,p_actor uuid,p_document uuid,p_decision text,p_note text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM agency.users WHERE id=p_actor AND tenant_id=p_tenant AND membership_type='admin' AND active)
     OR p_decision NOT IN ('approved','rejected') OR length(p_note)>1000
  THEN RAISE EXCEPTION 'invalid_document_review'; END IF;
  UPDATE agency.supplier_documents SET status=p_decision,review_note=trim(p_note),reviewed_at=now(),reviewed_by=p_actor
    WHERE id=p_document AND tenant_id=p_tenant AND status='pending' RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'document_not_pending'; END IF;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'supplier.document_reviewed','supplier_document',v_id,jsonb_build_object('decision',p_decision));
  RETURN v_id;
END $$;

CREATE TABLE IF NOT EXISTS agency.supplier_settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL UNIQUE,
  supplier_user_id uuid NOT NULL,
  gross_minor bigint NOT NULL CHECK(gross_minor>0),
  commission_minor bigint NOT NULL CHECK(commission_minor>=0),
  net_minor bigint NOT NULL CHECK(net_minor>=0),
  currency char(3) NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','paid','cancelled')),
  due_on date NOT NULL,
  external_reference text NOT NULL DEFAULT '',
  created_by uuid NOT NULL,
  approved_by uuid,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(tenant_id,reservation_id) REFERENCES agency.reservations(tenant_id,id) ON DELETE RESTRICT,
  FOREIGN KEY(tenant_id,supplier_user_id) REFERENCES agency.users(tenant_id,id),
  FOREIGN KEY(tenant_id,created_by) REFERENCES agency.users(tenant_id,id),
  FOREIGN KEY(tenant_id,approved_by) REFERENCES agency.users(tenant_id,id)
);
CREATE INDEX IF NOT EXISTS supplier_settlements_due_idx ON agency.supplier_settlements(tenant_id,status,due_on);

CREATE OR REPLACE FUNCTION agency.propose_supplier_settlement(p_tenant uuid,p_actor uuid,p_reservation uuid,p_due date)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_res agency.reservations%ROWTYPE; v_listing agency.listings%ROWTYPE; v_commission bigint; v_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM agency.users WHERE id=p_actor AND tenant_id=p_tenant AND membership_type='admin' AND active)
     OR p_due<current_date THEN RAISE EXCEPTION 'invalid_settlement_request'; END IF;
  SELECT * INTO v_res FROM agency.reservations WHERE id=p_reservation AND tenant_id=p_tenant FOR UPDATE;
  IF v_res.id IS NULL OR v_res.status NOT IN ('confirmed','completed') OR v_res.payment_status<>'paid' OR v_res.total_minor<=0
     THEN RAISE EXCEPTION 'reservation_not_settleable'; END IF;
  SELECT * INTO v_listing FROM agency.listings WHERE id=v_res.listing_id AND tenant_id=p_tenant;
  IF v_listing.id IS NULL OR v_listing.owner_user_id IS NULL THEN RAISE EXCEPTION 'supplier_missing'; END IF;
  v_commission := agency.calculate_commission(p_tenant,v_listing.category,'direct',v_listing.owner_user_id,v_res.total_minor,v_res.created_at);
  IF v_commission IS NULL OR v_commission<0 OR v_commission>v_res.total_minor THEN RAISE EXCEPTION 'commission_rule_missing_or_invalid'; END IF;
  INSERT INTO agency.supplier_settlements(tenant_id,reservation_id,supplier_user_id,gross_minor,commission_minor,net_minor,currency,due_on,created_by)
    VALUES(p_tenant,p_reservation,v_listing.owner_user_id,v_res.total_minor,v_commission,v_res.total_minor-v_commission,v_res.currency,p_due,p_actor)
    ON CONFLICT(reservation_id) DO NOTHING RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'settlement_already_exists'; END IF;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'supplier.settlement_proposed','supplier_settlement',v_id,jsonb_build_object('grossMinor',v_res.total_minor,'commissionMinor',v_commission));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.advance_supplier_settlement(p_tenant uuid,p_actor uuid,p_settlement uuid,p_action text,p_reference text DEFAULT '')
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM agency.users WHERE id=p_actor AND tenant_id=p_tenant AND membership_type='admin' AND active)
     OR p_action NOT IN ('approved','paid','cancelled') THEN RAISE EXCEPTION 'invalid_settlement_action'; END IF;
  IF p_action='paid' AND length(trim(p_reference)) NOT BETWEEN 3 AND 160 THEN RAISE EXCEPTION 'payout_reference_required'; END IF;
  UPDATE agency.supplier_settlements SET status=p_action,
    approved_by=CASE WHEN p_action='approved' THEN p_actor ELSE approved_by END,
    external_reference=CASE WHEN p_action='paid' THEN trim(p_reference) ELSE external_reference END,
    paid_at=CASE WHEN p_action='paid' THEN now() ELSE paid_at END
  WHERE id=p_settlement AND tenant_id=p_tenant
    AND ((status='pending' AND p_action IN ('approved','cancelled')) OR (status='approved' AND p_action IN ('paid','cancelled')))
    AND (p_action<>'paid' OR EXISTS(SELECT 1 FROM agency.reservations r WHERE r.id=reservation_id AND r.tenant_id=p_tenant AND r.payment_status='paid' AND r.status IN ('confirmed','completed')))
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'settlement_transition_denied'; END IF;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'supplier.settlement_'||p_action,'supplier_settlement',v_id,jsonb_build_object('externalReference',trim(p_reference)));
  RETURN v_id;
END $$;

GRANT SELECT,INSERT,UPDATE,DELETE ON agency.supplier_documents,agency.supplier_settlements TO agency_app;
GRANT EXECUTE ON FUNCTION agency.submit_supplier_document(uuid,uuid,text,text,date),agency.review_supplier_document(uuid,uuid,uuid,text,text),agency.propose_supplier_settlement(uuid,uuid,uuid,date),agency.advance_supplier_settlement(uuid,uuid,uuid,text,text) TO agency_app;
