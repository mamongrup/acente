-- Voucher identity and contracted net price are checked before an agency
-- reservation consumes a B2B allotment. This is local, provider-independent.
ALTER TABLE agency.partner_reservation_allocations
  ADD COLUMN IF NOT EXISTS contracted_net_minor bigint;
ALTER TABLE agency.partner_reservation_allocations
  ADD COLUMN IF NOT EXISTS currency char(3);

CREATE TABLE IF NOT EXISTS agency.partner_vouchers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL,
  reservation_id uuid NOT NULL REFERENCES agency.reservations(id) ON DELETE CASCADE,
  voucher_code text NOT NULL CHECK(length(trim(voucher_code)) BETWEEN 3 AND 80),
  supplier_reference text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','void')),
  created_by uuid NOT NULL REFERENCES agency.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(tenant_id,organization_id) REFERENCES agency.partner_organizations(tenant_id,id),
  UNIQUE(tenant_id,organization_id,voucher_code),
  UNIQUE(tenant_id,reservation_id)
);

CREATE OR REPLACE FUNCTION agency.allocate_partner_reservation(
  p_tenant uuid,p_actor uuid,p_contract_product uuid,p_reservation uuid,p_units integer
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_product agency.partner_contract_products%ROWTYPE;
  v_contract agency.partner_sales_contracts%ROWTYPE; v_res agency.reservations%ROWTYPE;
  v_used integer; v_id uuid;
BEGIN
  SELECT * INTO v_product FROM agency.partner_contract_products
    WHERE tenant_id=p_tenant AND id=p_contract_product FOR UPDATE;
  IF NOT FOUND OR v_product.stop_sale OR p_units IS NULL OR p_units<1 THEN
    RAISE EXCEPTION 'product_unavailable'; END IF;
  SELECT * INTO v_contract FROM agency.partner_sales_contracts
    WHERE tenant_id=p_tenant AND id=v_product.contract_id AND status='active';
  IF NOT FOUND THEN RAISE EXCEPTION 'contract_inactive'; END IF;
  SELECT * INTO v_res FROM agency.reservations
    WHERE tenant_id=p_tenant AND id=p_reservation FOR UPDATE;
  IF NOT FOUND OR v_res.listing_id<>v_product.listing_id
    OR v_res.partner_organization_id<>v_contract.organization_id
    OR v_res.status NOT IN ('inquiry','option','confirmed')
    OR v_res.check_in IS NULL OR v_res.check_in<v_contract.valid_from
    OR v_res.check_in>v_contract.valid_until
    OR v_res.check_in-current_date<v_product.release_days
    OR v_res.currency<>v_contract.currency
    OR v_res.total_minor<v_product.net_price_minor*p_units
    OR NOT agency.partner_can_access(p_tenant,p_actor,v_contract.organization_id) THEN
    RAISE EXCEPTION 'reservation_contract_mismatch'; END IF;
  IF EXISTS(SELECT 1 FROM agency.partner_reservation_allocations
    WHERE tenant_id=p_tenant AND reservation_id=p_reservation) THEN
    SELECT id INTO v_id FROM agency.partner_reservation_allocations
      WHERE tenant_id=p_tenant AND reservation_id=p_reservation
        AND contract_product_id=p_contract_product AND units=p_units;
    IF v_id IS NULL THEN RAISE EXCEPTION 'allocation_conflict'; END IF;
    RETURN v_id;
  END IF;
  SELECT coalesce(sum(a.units),0) INTO v_used FROM agency.partner_reservation_allocations a
    JOIN agency.reservations r ON r.id=a.reservation_id AND r.tenant_id=a.tenant_id
    WHERE a.tenant_id=p_tenant AND a.contract_product_id=p_contract_product
      AND r.check_in=v_res.check_in AND r.status<>'cancelled';
  IF v_used+p_units>v_product.allotment_units THEN RAISE EXCEPTION 'allotment_exhausted'; END IF;
  INSERT INTO agency.partner_reservation_allocations
    (tenant_id,contract_product_id,reservation_id,units,contracted_net_minor,currency)
    VALUES(p_tenant,p_contract_product,p_reservation,p_units,
      v_product.net_price_minor*p_units,v_contract.currency) RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.register_partner_voucher(
  p_tenant uuid,p_actor uuid,p_reservation uuid,p_code text,p_supplier_reference text DEFAULT ''
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_res agency.reservations%ROWTYPE; v_id uuid;
BEGIN
  SELECT * INTO v_res FROM agency.reservations
    WHERE tenant_id=p_tenant AND id=p_reservation FOR UPDATE;
  IF NOT FOUND OR v_res.partner_organization_id IS NULL
    OR v_res.status NOT IN ('option','confirmed','completed')
    OR length(trim(coalesce(p_code,''))) NOT BETWEEN 3 AND 80
    OR length(coalesce(p_supplier_reference,''))>160
    OR NOT EXISTS(SELECT 1 FROM agency.partner_reservation_allocations
      WHERE tenant_id=p_tenant AND reservation_id=p_reservation)
    OR NOT (agency.commercial_admin(p_tenant,p_actor) OR
      agency.partner_can_access(p_tenant,p_actor,v_res.partner_organization_id))
    THEN RAISE EXCEPTION 'voucher_access_or_allocation_missing'; END IF;
  INSERT INTO agency.partner_vouchers
    (tenant_id,organization_id,reservation_id,voucher_code,supplier_reference,created_by)
  VALUES(p_tenant,v_res.partner_organization_id,p_reservation,
    trim(p_code),coalesce(p_supplier_reference,''),p_actor)
  ON CONFLICT(tenant_id,reservation_id) DO UPDATE SET
    voucher_code=excluded.voucher_code,supplier_reference=excluded.supplier_reference
    WHERE agency.partner_vouchers.organization_id=excluded.organization_id
      AND agency.partner_vouchers.status='active'
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'voucher_conflict'; END IF;
  RETURN v_id;
END $$;

REVOKE ALL ON agency.partner_vouchers FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.register_partner_voucher(uuid,uuid,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.register_partner_voucher(uuid,uuid,uuid,text,text) TO agency_app;
