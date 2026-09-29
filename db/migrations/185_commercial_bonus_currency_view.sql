-- Include currency and cap in the tenant-scoped commercial workspace.
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
      'category',category_code,'rate',rate_percent,'currency',currency,'cap',max_bonus_minor,'status',status,'from',starts_on,
      'until',ends_on) ORDER BY created_at DESC),'[]'::jsonb)
      FROM agency.partner_bonus_campaigns WHERE tenant_id=p_tenant)
  ) INTO v_result;
  RETURN v_result;
END $$;

