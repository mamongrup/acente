-- A capped partner bonus belongs to one currency; never mix TRY and EUR minor units.
ALTER TABLE agency.partner_bonus_campaigns ADD COLUMN IF NOT EXISTS currency char(3) NOT NULL DEFAULT 'TRY';
ALTER TABLE agency.partner_bonus_campaigns ADD CONSTRAINT partner_bonus_currency_iso
  CHECK(currency ~ '^[A-Z]{3}$');

CREATE OR REPLACE FUNCTION agency.create_partner_bonus_campaign(
  p_tenant uuid,p_actor uuid,p_name text,p_category text,p_from date,p_until date,
  p_rate numeric,p_cap bigint,p_currency char(3)
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'bonus_access_denied'; END IF;
  IF length(trim(coalesce(p_name,''))) NOT BETWEEN 3 AND 120
    OR p_from IS NULL OR p_until<p_from OR p_until<current_date
    OR p_rate NOT BETWEEN 0.001 AND 100 OR (p_cap IS NOT NULL AND p_cap<1)
    OR p_currency !~ '^[A-Z]{3}$'
    OR (p_category IS NOT NULL AND NOT EXISTS(SELECT 1 FROM agency.category_service_steps
      WHERE category_code=p_category)) THEN RAISE EXCEPTION 'invalid_bonus_campaign'; END IF;
  INSERT INTO agency.partner_bonus_campaigns
    (tenant_id,name,category_code,starts_on,ends_on,rate_percent,max_bonus_minor,created_by,currency)
    VALUES(p_tenant,p_name,p_category,p_from,p_until,p_rate,p_cap,p_actor,p_currency)
    RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.reconcile_partner_bonus(p_tenant uuid,p_reservation uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_res agency.reservations%ROWTYPE; v_category text; v_count integer:=0;
  v_campaign agency.partner_bonus_campaigns%ROWTYPE; v_bonus bigint;
BEGIN
  SELECT * INTO v_res FROM agency.reservations
    WHERE tenant_id=p_tenant AND id=p_reservation FOR UPDATE;
  IF NOT FOUND OR v_res.partner_organization_id IS NULL THEN RETURN 0; END IF;
  IF v_res.status<>'completed' OR v_res.payment_status<>'paid' THEN
    UPDATE agency.partner_bonus_ledger SET status='reversed',reversed_at=now()
      WHERE tenant_id=p_tenant AND reservation_id=p_reservation AND status='earned';
    GET DIAGNOSTICS v_count=ROW_COUNT;
    RETURN -v_count;
  END IF;
  SELECT category INTO v_category FROM agency.listings
    WHERE tenant_id=p_tenant AND id=v_res.listing_id;
  SELECT * INTO v_campaign FROM agency.partner_bonus_campaigns
    WHERE tenant_id=p_tenant AND status='active' AND currency=v_res.currency
      AND (category_code IS NULL OR category_code=v_category)
      AND v_res.created_at::date BETWEEN starts_on AND ends_on
    ORDER BY (category_code IS NOT NULL) DESC,created_at DESC,id DESC LIMIT 1;
  IF NOT FOUND THEN RETURN 0; END IF;
  v_bonus:=round(v_res.total_minor*v_campaign.rate_percent/100);
  IF v_campaign.max_bonus_minor IS NOT NULL THEN
    v_bonus:=least(v_bonus,v_campaign.max_bonus_minor);
  END IF;
  INSERT INTO agency.partner_bonus_ledger
    (tenant_id,organization_id,campaign_id,reservation_id,bonus_minor,currency)
  VALUES(p_tenant,v_res.partner_organization_id,v_campaign.id,p_reservation,v_bonus,v_res.currency)
  ON CONFLICT(tenant_id,reservation_id,campaign_id) DO UPDATE SET
    status='earned',reversed_at=NULL,bonus_minor=excluded.bonus_minor
    WHERE agency.partner_bonus_ledger.status='reversed'
  RETURNING 1 INTO v_count;
  RETURN coalesce(v_count,0);
END $$;

REVOKE ALL ON FUNCTION agency.create_partner_bonus_campaign(uuid,uuid,text,text,date,date,numeric,bigint,char(3)) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.create_partner_bonus_campaign(uuid,uuid,text,text,date,date,numeric,bigint,char(3)) TO agency_app;
