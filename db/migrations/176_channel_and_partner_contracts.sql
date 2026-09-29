-- Local channel and B2B contract ledger. Provider delivery is asynchronous and
-- optional; unavailable integrations never block the agency's own inventory.
CREATE TABLE IF NOT EXISTS agency.sales_channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  channel_key text NOT NULL CHECK(channel_key ~ '^[a-z0-9_]{2,60}$'),
  label text NOT NULL,
  mode text NOT NULL DEFAULT 'disabled' CHECK(mode IN ('disabled','test','live')),
  last_success_at timestamptz,
  last_error text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,channel_key), UNIQUE(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS agency.channel_product_maps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  channel_id uuid NOT NULL,
  listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  rate_plan_id uuid REFERENCES agency.rate_plans(id) ON DELETE SET NULL,
  external_product_key text NOT NULL CHECK(length(trim(external_product_key)) BETWEEN 1 AND 160),
  enabled boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(tenant_id,channel_id) REFERENCES agency.sales_channels(tenant_id,id) ON DELETE CASCADE,
  UNIQUE(tenant_id,channel_id,external_product_key), UNIQUE(tenant_id,channel_id,listing_id)
);
CREATE TABLE IF NOT EXISTS agency.channel_sync_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  channel_id uuid NOT NULL,
  listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  event_key text NOT NULL CHECK(length(event_key) BETWEEN 8 AND 180),
  event_type text NOT NULL CHECK(event_type IN ('availability','price','restriction','reservation_status')),
  payload jsonb NOT NULL CHECK(jsonb_typeof(payload)='object'),
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','sending','sent','failed','cancelled')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK(attempt_count>=0),
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  last_error text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  FOREIGN KEY(tenant_id,channel_id) REFERENCES agency.sales_channels(tenant_id,id) ON DELETE CASCADE,
  UNIQUE(tenant_id,channel_id,event_key)
);
CREATE INDEX IF NOT EXISTS channel_sync_pending_idx ON agency.channel_sync_outbox(status,next_attempt_at)
  WHERE status IN ('pending','failed');

CREATE TABLE IF NOT EXISTS agency.partner_sales_contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  organization_id uuid NOT NULL,
  code text NOT NULL,
  valid_from date NOT NULL,
  valid_until date NOT NULL CHECK(valid_until>=valid_from),
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','active','paused','expired')),
  currency char(3) NOT NULL DEFAULT 'TRY',
  commission_percent numeric(7,3) NOT NULL DEFAULT 0 CHECK(commission_percent BETWEEN 0 AND 100),
  approved_by uuid REFERENCES agency.users(id),
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(tenant_id,organization_id) REFERENCES agency.partner_organizations(tenant_id,id),
  UNIQUE(tenant_id,code), UNIQUE(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS agency.partner_contract_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  contract_id uuid NOT NULL,
  listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  net_price_minor bigint NOT NULL CHECK(net_price_minor>=0),
  allotment_units integer NOT NULL DEFAULT 0 CHECK(allotment_units>=0),
  release_days integer NOT NULL DEFAULT 0 CHECK(release_days BETWEEN 0 AND 365),
  stop_sale boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(tenant_id,contract_id) REFERENCES agency.partner_sales_contracts(tenant_id,id) ON DELETE CASCADE,
  UNIQUE(tenant_id,contract_id,listing_id), UNIQUE(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS agency.partner_reservation_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  contract_product_id uuid NOT NULL,
  reservation_id uuid NOT NULL REFERENCES agency.reservations(id) ON DELETE CASCADE,
  units integer NOT NULL CHECK(units>0),
  booked_on date NOT NULL DEFAULT current_date,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(tenant_id,contract_product_id) REFERENCES agency.partner_contract_products(tenant_id,id),
  UNIQUE(tenant_id,reservation_id)
);

-- The agency may queue only mapped local products. Dispatch adapters are
-- independent of this function and must acknowledge the same event_key.
CREATE OR REPLACE FUNCTION agency.queue_channel_update(
  p_tenant uuid,p_actor uuid,p_channel uuid,p_listing uuid,
  p_event_key text,p_event_type text,p_payload jsonb
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE tenant_id=p_tenant AND id=p_actor
    AND membership_type='admin' AND active) THEN RAISE EXCEPTION 'channel_access_denied'; END IF;
  IF p_event_type NOT IN ('availability','price','restriction','reservation_status')
    OR length(coalesce(p_event_key,'')) NOT BETWEEN 8 AND 180
    OR jsonb_typeof(p_payload)<>'object'
    OR NOT EXISTS(SELECT 1 FROM agency.channel_product_maps m
       JOIN agency.sales_channels c ON c.id=m.channel_id AND c.tenant_id=m.tenant_id
       JOIN agency.listings l ON l.id=m.listing_id AND l.tenant_id=m.tenant_id
       WHERE m.tenant_id=p_tenant AND m.channel_id=p_channel AND m.listing_id=p_listing
         AND m.enabled AND c.mode<>'disabled' AND l.source<>'nexus') THEN
    RAISE EXCEPTION 'channel_mapping_inactive';
  END IF;
  INSERT INTO agency.channel_sync_outbox
    (tenant_id,channel_id,listing_id,event_key,event_type,payload)
  VALUES(p_tenant,p_channel,p_listing,p_event_key,p_event_type,p_payload)
  ON CONFLICT(tenant_id,channel_id,event_key) DO UPDATE
    SET event_key=excluded.event_key
    WHERE agency.channel_sync_outbox.listing_id=excluded.listing_id
      AND agency.channel_sync_outbox.event_type=excluded.event_type
      AND agency.channel_sync_outbox.payload=excluded.payload
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'channel_event_key_conflict'; END IF;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.activate_partner_sales_contract(
  p_tenant uuid,p_actor uuid,p_contract uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_contract agency.partner_sales_contracts%ROWTYPE;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE tenant_id=p_tenant AND id=p_actor
    AND membership_type='admin' AND active) THEN RAISE EXCEPTION 'contract_access_denied'; END IF;
  SELECT * INTO v_contract FROM agency.partner_sales_contracts
    WHERE tenant_id=p_tenant AND id=p_contract FOR UPDATE;
  IF NOT FOUND OR v_contract.status<>'draft' OR v_contract.valid_until<current_date
    OR NOT EXISTS(SELECT 1 FROM agency.partner_contract_products p
       JOIN agency.listings l ON l.id=p.listing_id AND l.tenant_id=p.tenant_id
       WHERE p.tenant_id=p_tenant AND p.contract_id=p_contract AND l.status='published') THEN
    RAISE EXCEPTION 'contract_not_ready';
  END IF;
  UPDATE agency.partner_sales_contracts SET status='active',approved_by=p_actor,
    approved_at=now() WHERE id=p_contract;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'partner.contract_activated','partner_contract',p_contract,
      jsonb_build_object('organization',v_contract.organization_id));
  RETURN p_contract;
END $$;

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
  SELECT * INTO v_res FROM agency.reservations
    WHERE tenant_id=p_tenant AND id=p_reservation FOR UPDATE;
  IF NOT FOUND OR v_res.listing_id<>v_product.listing_id
    OR v_res.partner_organization_id<>v_contract.organization_id
    OR v_res.status NOT IN ('inquiry','option','confirmed')
    OR v_res.check_in IS NULL OR v_res.check_in<v_contract.valid_from
    OR v_res.check_in>v_contract.valid_until
    OR v_res.check_in-current_date<v_product.release_days
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
    (tenant_id,contract_product_id,reservation_id,units)
    VALUES(p_tenant,p_contract_product,p_reservation,p_units) RETURNING id INTO v_id;
  RETURN v_id;
END $$;

REVOKE ALL ON agency.sales_channels,agency.channel_product_maps,agency.channel_sync_outbox,
  agency.partner_sales_contracts,agency.partner_contract_products,
  agency.partner_reservation_allocations FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.queue_channel_update(uuid,uuid,uuid,uuid,text,text,jsonb),
  agency.activate_partner_sales_contract(uuid,uuid,uuid),
  agency.allocate_partner_reservation(uuid,uuid,uuid,uuid,integer) FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE ON agency.sales_channels,agency.channel_product_maps,
  agency.partner_sales_contracts,agency.partner_contract_products TO agency_app;
GRANT SELECT ON agency.channel_sync_outbox,agency.partner_reservation_allocations TO agency_app;
GRANT EXECUTE ON FUNCTION agency.queue_channel_update(uuid,uuid,uuid,uuid,text,text,jsonb),
  agency.activate_partner_sales_contract(uuid,uuid,uuid),
  agency.allocate_partner_reservation(uuid,uuid,uuid,uuid,integer) TO agency_app;
