-- Allow tenant administrators to allocate their B2B contract inventory.
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
    OR NOT (agency.commercial_admin(p_tenant,p_actor) OR agency.partner_can_access(p_tenant,p_actor,v_contract.organization_id)) THEN
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

