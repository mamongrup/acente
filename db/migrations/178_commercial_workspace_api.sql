-- Explicit tenant-scoped administrative entry points for commercial modules.
CREATE OR REPLACE FUNCTION agency.commercial_admin(p_tenant uuid,p_actor uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT EXISTS(SELECT 1 FROM agency.users u WHERE u.tenant_id=p_tenant
    AND u.id=p_actor AND u.membership_type='admin' AND u.active)
$$;

CREATE OR REPLACE FUNCTION agency.save_sales_channel(
  p_tenant uuid,p_actor uuid,p_key text,p_label text,p_mode text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'channel_access_denied'; END IF;
  IF p_key !~ '^[a-z0-9_]{2,60}$' OR length(trim(coalesce(p_label,''))) NOT BETWEEN 2 AND 100
    OR p_mode NOT IN ('disabled','test') THEN RAISE EXCEPTION 'invalid_channel'; END IF;
  INSERT INTO agency.sales_channels(tenant_id,channel_key,label,mode)
    VALUES(p_tenant,p_key,p_label,p_mode)
  ON CONFLICT(tenant_id,channel_key) DO UPDATE SET label=excluded.label,mode=excluded.mode
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.map_sales_channel_product(
  p_tenant uuid,p_actor uuid,p_channel uuid,p_listing uuid,p_external_key text,p_enabled boolean
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'channel_access_denied'; END IF;
  IF NOT EXISTS(SELECT 1 FROM agency.sales_channels WHERE tenant_id=p_tenant AND id=p_channel)
    OR NOT EXISTS(SELECT 1 FROM agency.listings WHERE tenant_id=p_tenant AND id=p_listing AND source<>'nexus')
    OR length(trim(coalesce(p_external_key,''))) NOT BETWEEN 1 AND 160 THEN
      RAISE EXCEPTION 'invalid_channel_map'; END IF;
  INSERT INTO agency.channel_product_maps
    (tenant_id,channel_id,listing_id,external_product_key,enabled)
    VALUES(p_tenant,p_channel,p_listing,p_external_key,coalesce(p_enabled,false))
  ON CONFLICT(tenant_id,channel_id,listing_id) DO UPDATE SET
    external_product_key=excluded.external_product_key,enabled=excluded.enabled
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.create_partner_sales_contract(
  p_tenant uuid,p_actor uuid,p_organization uuid,p_code text,
  p_from date,p_until date,p_currency char(3),p_commission numeric
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'contract_access_denied'; END IF;
  IF NOT EXISTS(SELECT 1 FROM agency.partner_organizations
      WHERE tenant_id=p_tenant AND id=p_organization AND status='active')
    OR length(trim(coalesce(p_code,''))) NOT BETWEEN 2 AND 80
    OR p_from IS NULL OR p_until<p_from OR p_until<current_date
    OR p_currency !~ '^[A-Z]{3}$' OR p_commission NOT BETWEEN 0 AND 100
    THEN RAISE EXCEPTION 'invalid_partner_contract'; END IF;
  INSERT INTO agency.partner_sales_contracts
    (tenant_id,organization_id,code,valid_from,valid_until,currency,commission_percent)
    VALUES(p_tenant,p_organization,p_code,p_from,p_until,p_currency,p_commission)
    RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.add_partner_contract_product(
  p_tenant uuid,p_actor uuid,p_contract uuid,p_listing uuid,
  p_price bigint,p_units integer,p_release integer
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'contract_access_denied'; END IF;
  IF NOT EXISTS(SELECT 1 FROM agency.partner_sales_contracts
      WHERE tenant_id=p_tenant AND id=p_contract AND status='draft')
    OR NOT EXISTS(SELECT 1 FROM agency.listings
      WHERE tenant_id=p_tenant AND id=p_listing AND status='published')
    OR p_price IS NULL OR p_price<0 OR p_units IS NULL OR p_units<1
    OR p_release IS NULL OR p_release NOT BETWEEN 0 AND 365
    THEN RAISE EXCEPTION 'invalid_contract_product'; END IF;
  INSERT INTO agency.partner_contract_products
    (tenant_id,contract_id,listing_id,net_price_minor,allotment_units,release_days)
    VALUES(p_tenant,p_contract,p_listing,p_price,p_units,p_release)
  ON CONFLICT(tenant_id,contract_id,listing_id) DO UPDATE SET
    net_price_minor=excluded.net_price_minor,allotment_units=excluded.allotment_units,
    release_days=excluded.release_days
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.create_partner_bonus_campaign(
  p_tenant uuid,p_actor uuid,p_name text,p_category text,p_from date,p_until date,
  p_rate numeric,p_cap bigint
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'bonus_access_denied'; END IF;
  IF length(trim(coalesce(p_name,''))) NOT BETWEEN 3 AND 120
    OR p_from IS NULL OR p_until<p_from OR p_until<current_date
    OR p_rate NOT BETWEEN 0.001 AND 100 OR (p_cap IS NOT NULL AND p_cap<1)
    OR (p_category IS NOT NULL AND NOT EXISTS(SELECT 1 FROM agency.category_service_steps
      WHERE category_code=p_category)) THEN RAISE EXCEPTION 'invalid_bonus_campaign'; END IF;
  INSERT INTO agency.partner_bonus_campaigns
    (tenant_id,name,category_code,starts_on,ends_on,rate_percent,max_bonus_minor,created_by)
    VALUES(p_tenant,p_name,p_category,p_from,p_until,p_rate,p_cap,p_actor)
    RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.commercial_workspace(p_tenant uuid,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'workspace_access_denied'; END IF;
  SELECT jsonb_build_object(
    'categorySteps',(SELECT coalesce(jsonb_agg(jsonb_build_object('category',category_code,
      'key',step_key,'stage',stage,'title',title_tr,'role',owner_role) ORDER BY category_code,position),'[]'::jsonb)
      FROM agency.category_service_steps),
    'channels',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'key',channel_key,
      'label',label,'mode',mode,'error',last_error) ORDER BY label),'[]'::jsonb)
      FROM agency.sales_channels WHERE tenant_id=p_tenant),
    'contracts',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',c.id,'code',c.code,
      'organization',o.name,'status',c.status,'from',c.valid_from,'until',c.valid_until,
      'products',(SELECT count(*) FROM agency.partner_contract_products p WHERE p.tenant_id=p_tenant AND p.contract_id=c.id))
      ORDER BY c.created_at DESC),'[]'::jsonb)
      FROM agency.partner_sales_contracts c JOIN agency.partner_organizations o
        ON o.id=c.organization_id AND o.tenant_id=c.tenant_id WHERE c.tenant_id=p_tenant),
    'priceProposals',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'listing',l.title,
      'old',p.baseline_minor,'new',p.proposed_minor,'currency',p.currency,'status',p.status,
      'reason',p.reason) ORDER BY p.created_at DESC),'[]'::jsonb)
      FROM agency.listing_price_proposals p JOIN agency.listings l ON l.id=p.listing_id
        AND l.tenant_id=p.tenant_id WHERE p.tenant_id=p_tenant),
    'bonusCampaigns',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,
      'category',category_code,'rate',rate_percent,'status',status,'from',starts_on,
      'until',ends_on) ORDER BY created_at DESC),'[]'::jsonb)
      FROM agency.partner_bonus_campaigns WHERE tenant_id=p_tenant)
  ) INTO v_result;
  RETURN v_result;
END $$;

REVOKE ALL ON FUNCTION agency.commercial_admin(uuid,uuid),
  agency.save_sales_channel(uuid,uuid,text,text,text),
  agency.map_sales_channel_product(uuid,uuid,uuid,uuid,text,boolean),
  agency.create_partner_sales_contract(uuid,uuid,uuid,text,date,date,char(3),numeric),
  agency.add_partner_contract_product(uuid,uuid,uuid,uuid,bigint,integer,integer),
  agency.create_partner_bonus_campaign(uuid,uuid,text,text,date,date,numeric,bigint),
  agency.commercial_workspace(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.save_sales_channel(uuid,uuid,text,text,text),
  agency.map_sales_channel_product(uuid,uuid,uuid,uuid,text,boolean),
  agency.create_partner_sales_contract(uuid,uuid,uuid,text,date,date,char(3),numeric),
  agency.add_partner_contract_product(uuid,uuid,uuid,uuid,bigint,integer,integer),
  agency.create_partner_bonus_campaign(uuid,uuid,text,text,date,date,numeric,bigint),
  agency.commercial_workspace(uuid,uuid) TO agency_app;
