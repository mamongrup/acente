-- A price recommendation changes nothing until a tenant admin approves it.
CREATE TABLE IF NOT EXISTS agency.listing_price_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  baseline_minor bigint NOT NULL CHECK(baseline_minor>=0),
  proposed_minor bigint NOT NULL CHECK(proposed_minor>=0),
  currency char(3) NOT NULL,
  reason text NOT NULL CHECK(length(trim(reason)) BETWEEN 10 AND 2000),
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb CHECK(jsonb_typeof(evidence)='object'),
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected','stale')),
  proposed_by uuid NOT NULL REFERENCES agency.users(id),
  reviewed_by uuid REFERENCES agency.users(id),
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS listing_price_proposals_queue_idx
  ON agency.listing_price_proposals(tenant_id,status,created_at DESC);

CREATE OR REPLACE FUNCTION agency.propose_listing_price(
  p_tenant uuid,p_actor uuid,p_listing uuid,p_price bigint,p_reason text,p_evidence jsonb DEFAULT '{}'::jsonb
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_listing agency.listings%ROWTYPE; v_id uuid;
BEGIN
  SELECT * INTO v_listing FROM agency.listings
    WHERE tenant_id=p_tenant AND id=p_listing FOR UPDATE;
  IF NOT FOUND OR v_listing.source='nexus' OR p_price IS NULL OR p_price<0
    OR p_price=v_listing.price_minor OR length(trim(coalesce(p_reason,''))) NOT BETWEEN 10 AND 2000
    OR jsonb_typeof(p_evidence)<>'object' THEN RAISE EXCEPTION 'invalid_price_proposal'; END IF;
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE tenant_id=p_tenant AND id=p_actor
    AND active AND (membership_type='admin' OR
      (membership_type='supplier' AND id=v_listing.owner_user_id))) THEN
    RAISE EXCEPTION 'price_access_denied'; END IF;
  INSERT INTO agency.listing_price_proposals
    (tenant_id,listing_id,baseline_minor,proposed_minor,currency,reason,evidence,proposed_by)
  VALUES(p_tenant,p_listing,v_listing.price_minor,p_price,v_listing.currency,
    p_reason,p_evidence,p_actor) RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.review_listing_price(
  p_tenant uuid,p_actor uuid,p_proposal uuid,p_decision text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_proposal agency.listing_price_proposals%ROWTYPE; v_listing agency.listings%ROWTYPE;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE tenant_id=p_tenant AND id=p_actor
    AND active AND membership_type='admin') THEN RAISE EXCEPTION 'price_review_denied'; END IF;
  SELECT * INTO v_proposal FROM agency.listing_price_proposals
    WHERE tenant_id=p_tenant AND id=p_proposal FOR UPDATE;
  IF NOT FOUND OR v_proposal.status<>'pending' OR p_decision NOT IN ('approved','rejected')
    THEN RAISE EXCEPTION 'invalid_price_review'; END IF;
  SELECT * INTO v_listing FROM agency.listings
    WHERE tenant_id=p_tenant AND id=v_proposal.listing_id FOR UPDATE;
  IF NOT FOUND OR v_listing.source='nexus' OR v_listing.currency<>v_proposal.currency
    OR v_listing.price_minor<>v_proposal.baseline_minor THEN
    UPDATE agency.listing_price_proposals SET status='stale',reviewed_by=p_actor,
      reviewed_at=now() WHERE id=p_proposal;
    RETURN p_proposal;
  END IF;
  IF p_decision='approved' THEN
    UPDATE agency.listings SET price_minor=v_proposal.proposed_minor,updated_at=now()
      WHERE id=v_listing.id AND tenant_id=p_tenant;
  END IF;
  UPDATE agency.listing_price_proposals SET status=p_decision,reviewed_by=p_actor,
    reviewed_at=now() WHERE id=p_proposal;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'pricing.proposal_'||p_decision,'listing',v_listing.id,
      jsonb_build_object('proposal',p_proposal,'old',v_proposal.baseline_minor,
        'new',v_proposal.proposed_minor));
  RETURN p_proposal;
END $$;

-- Agency bonus is separate from customer points. No default discount exists:
-- the administrator explicitly sets a date range and rate for each campaign.
CREATE TABLE IF NOT EXISTS agency.partner_bonus_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  name text NOT NULL CHECK(length(trim(name)) BETWEEN 3 AND 120),
  category_code text,
  starts_on date NOT NULL,
  ends_on date NOT NULL CHECK(ends_on>=starts_on),
  rate_percent numeric(7,3) NOT NULL CHECK(rate_percent>0 AND rate_percent<=100),
  max_bonus_minor bigint CHECK(max_bonus_minor>0),
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','active','paused','closed')),
  created_by uuid NOT NULL REFERENCES agency.users(id),
  approved_by uuid REFERENCES agency.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS agency.partner_bonus_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL,
  campaign_id uuid NOT NULL,
  reservation_id uuid NOT NULL REFERENCES agency.reservations(id) ON DELETE CASCADE,
  bonus_minor bigint NOT NULL CHECK(bonus_minor>=0),
  currency char(3) NOT NULL,
  status text NOT NULL DEFAULT 'earned' CHECK(status IN ('earned','reversed')),
  earned_at timestamptz NOT NULL DEFAULT now(),
  reversed_at timestamptz,
  FOREIGN KEY(tenant_id,organization_id) REFERENCES agency.partner_organizations(tenant_id,id),
  FOREIGN KEY(tenant_id,campaign_id) REFERENCES agency.partner_bonus_campaigns(tenant_id,id),
  UNIQUE(tenant_id,reservation_id,campaign_id)
);
CREATE INDEX IF NOT EXISTS partner_bonus_ledger_org_idx
  ON agency.partner_bonus_ledger(tenant_id,organization_id,earned_at DESC);

CREATE OR REPLACE FUNCTION agency.activate_partner_bonus_campaign(
  p_tenant uuid,p_actor uuid,p_campaign uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE tenant_id=p_tenant AND id=p_actor
    AND active AND membership_type='admin') THEN RAISE EXCEPTION 'bonus_access_denied'; END IF;
  UPDATE agency.partner_bonus_campaigns SET status='active',approved_by=p_actor
    WHERE tenant_id=p_tenant AND id=p_campaign AND status='draft' AND ends_on>=current_date;
  IF NOT FOUND THEN RAISE EXCEPTION 'bonus_campaign_not_ready'; END IF;
  RETURN p_campaign;
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
    WHERE tenant_id=p_tenant AND status='active'
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

CREATE OR REPLACE FUNCTION agency.partner_bonus_reservation_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NEW.partner_organization_id IS NOT NULL AND
    (TG_OP='INSERT' OR NEW.status IS DISTINCT FROM OLD.status
      OR NEW.payment_status IS DISTINCT FROM OLD.payment_status) THEN
    PERFORM agency.reconcile_partner_bonus(NEW.tenant_id,NEW.id);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS agency_partner_bonus_reservation ON agency.reservations;
CREATE TRIGGER agency_partner_bonus_reservation AFTER INSERT OR UPDATE OF status,payment_status
  ON agency.reservations FOR EACH ROW EXECUTE FUNCTION agency.partner_bonus_reservation_trigger();

-- Tables are not directly writable by the application role. A later provider
-- adapter may receive only its scoped outbox claim/ack functions.
REVOKE ALL ON agency.sales_channels,agency.channel_product_maps,agency.channel_sync_outbox,
  agency.partner_sales_contracts,agency.partner_contract_products,
  agency.partner_reservation_allocations FROM agency_app;
REVOKE ALL ON agency.listing_price_proposals,agency.partner_bonus_campaigns,
  agency.partner_bonus_ledger FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.propose_listing_price(uuid,uuid,uuid,bigint,text,jsonb),
  agency.review_listing_price(uuid,uuid,uuid,text),
  agency.activate_partner_bonus_campaign(uuid,uuid,uuid),
  agency.reconcile_partner_bonus(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.propose_listing_price(uuid,uuid,uuid,bigint,text,jsonb),
  agency.review_listing_price(uuid,uuid,uuid,text),
  agency.activate_partner_bonus_campaign(uuid,uuid,uuid) TO agency_app;
