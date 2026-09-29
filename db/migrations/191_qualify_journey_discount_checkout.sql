-- Qualify campaign identity against the table; the set-returning function has an id output column.
CREATE OR REPLACE FUNCTION agency.checkout_order_with_journey_discount(
  p_tenant uuid,p_name text,p_email text,p_phone text,p_listing uuid,p_reference text,
  p_arrival date,p_departure date,p_guests integer,p_request_key text,
  p_user uuid,p_claim_code text
) RETURNS TABLE(id uuid,number text,reservation_id uuid,total_minor bigint,currency char(3))
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_claim agency.customer_journey_discount_claims%ROWTYPE;
  v_campaign agency.customer_cross_sell_campaigns%ROWTYPE;
  v_existing agency.orders%ROWTYPE; v_order agency.orders%ROWTYPE;
  v_discount bigint;
BEGIN
  IF coalesce(p_claim_code,'')='' THEN
    RETURN QUERY SELECT x.id,x.number,x.reservation_id,x.total_minor,x.currency
      FROM agency.checkout_order(p_tenant,p_name,p_email,p_phone,p_listing,p_reference,
        p_arrival,p_departure,p_guests,p_request_key) x;
    RETURN;
  END IF;
  IF p_user IS NULL OR p_claim_code !~ '^[0-9a-f]{36}$' THEN
    RAISE EXCEPTION 'journey_discount_login_required'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text||':'||p_request_key,0));
  SELECT * INTO v_claim FROM agency.customer_journey_discount_claims
    WHERE tenant_id=p_tenant AND claim_code=p_claim_code FOR UPDATE;
  SELECT * INTO v_campaign FROM agency.customer_cross_sell_campaigns
    WHERE tenant_id=p_tenant AND agency.customer_cross_sell_campaigns.id=v_claim.campaign_id;
  IF v_claim.id IS NULL OR v_claim.user_id<>p_user OR v_claim.target_listing_id<>p_listing
    OR v_campaign.status<>'active' OR current_date NOT BETWEEN v_campaign.starts_on AND v_campaign.ends_on
    OR NOT EXISTS(SELECT 1 FROM agency.users u WHERE u.id=p_user AND u.tenant_id=p_tenant
      AND u.active AND u.membership_type='customer' AND lower(u.email)=lower(p_email))
    OR NOT EXISTS(SELECT 1 FROM agency.reservations r
      JOIN agency.listings source_listing ON source_listing.id=r.listing_id AND source_listing.tenant_id=r.tenant_id
      JOIN agency.listings target ON target.id=p_listing AND target.tenant_id=r.tenant_id
      JOIN agency.customer_journey_answers answer ON answer.tenant_id=r.tenant_id
        AND answer.user_id=p_user AND answer.reservation_id=r.id
        AND answer.target_category=target.category AND answer.answer='yes'
      WHERE r.id=v_claim.source_reservation_id AND r.tenant_id=p_tenant
        AND r.status IN ('confirmed','completed') AND target.status='published'
        AND target.currency='TRY' AND target.category=v_campaign.target_category
        AND (v_campaign.source_category IS NULL OR v_campaign.source_category=source_listing.category))
  THEN RAISE EXCEPTION 'journey_discount_not_eligible'; END IF;
  SELECT * INTO v_existing FROM agency.orders WHERE tenant_id=p_tenant
    AND idempotency_key=p_request_key FOR UPDATE;
  IF v_existing.id IS NOT NULL AND v_claim.order_id IS DISTINCT FROM v_existing.id THEN
    RAISE EXCEPTION 'journey_discount_order_mismatch'; END IF;
  IF v_claim.order_id IS NOT NULL AND v_existing.id IS DISTINCT FROM v_claim.order_id THEN
    RAISE EXCEPTION 'journey_discount_already_used'; END IF;
  SELECT x.id,x.number,x.reservation_id,x.total_minor,x.currency
    INTO v_order.id,v_order.number,v_order.reservation_id,v_order.total_minor,v_order.currency
    FROM agency.checkout_order(p_tenant,p_name,p_email,p_phone,p_listing,p_reference,
      p_arrival,p_departure,p_guests,p_request_key) x;
  IF v_claim.order_id IS NULL THEN
    v_discount:=least(v_order.total_minor-1,
      round(v_order.total_minor*v_campaign.discount_percent/100)::bigint);
    IF v_discount<1 THEN RAISE EXCEPTION 'journey_discount_amount_invalid'; END IF;
    UPDATE agency.orders SET discount_minor=v_discount,total_minor=v_order.total_minor-v_discount
      WHERE agency.orders.id=v_order.id AND tenant_id=p_tenant;
    UPDATE agency.reservations SET total_minor=v_order.total_minor-v_discount
      WHERE agency.reservations.id=v_order.reservation_id AND tenant_id=p_tenant;
    UPDATE agency.customer_journey_discount_claims SET order_id=v_order.id,discount_minor=v_discount
      WHERE agency.customer_journey_discount_claims.id=v_claim.id;
    v_order.total_minor:=v_order.total_minor-v_discount;
  END IF;
  RETURN QUERY SELECT v_order.id,v_order.number,v_order.reservation_id,v_order.total_minor,v_order.currency;
END $$;
