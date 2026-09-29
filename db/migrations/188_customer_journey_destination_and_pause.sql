-- Use arrival city for route products and hide expired trips.
CREATE OR REPLACE FUNCTION agency.customer_journey_recommendations(p_tenant uuid,p_user uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  WITH owned AS (
    SELECT r.id,r.reference_code,r.check_in,r.check_out,r.created_at,l.category source_category,
      coalesce(nullif(l.metadata->'contract_fields'->>'route_to',''),nullif(l.metadata->>'route_to',''),nullif(l.metadata->>'destination_city',''),nullif(i.region,''),nullif(l.locality,''),'') region,
      l.title source_title,l.id source_listing
    FROM agency.reservations r
    JOIN agency.customers c ON c.id=r.customer_id AND c.tenant_id=r.tenant_id
    JOIN agency.users u ON u.id=p_user AND u.tenant_id=r.tenant_id AND u.active
      AND u.membership_type='customer' AND lower(u.email)=lower(c.email)
    JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
    LEFT JOIN agency.customer_travel_intents i ON i.tenant_id=r.tenant_id AND i.user_id=p_user
    WHERE r.tenant_id=p_tenant AND r.status IN ('confirmed','completed')
      AND (coalesce(r.check_out,r.check_in,r.created_at::date)>=current_date-30)
    ORDER BY r.created_at DESC LIMIT 5
  ), matched AS (
    SELECT o.*,q.target_category,q.question_tr,q.position,coalesce(a.answer,'') answer,
      (SELECT jsonb_build_object('id',l.id,'title',l.title,'locality',l.locality,
         'price',quote.live->>'price','currency',quote.live->>'currency','availability',quote.live->>'availability')
       FROM agency.listings l
       CROSS JOIN LATERAL agency.recommendation_live_quote(p_tenant,l.id,o.check_in,
         coalesce(o.check_out,o.check_in+1),2) quote(live)
       WHERE l.tenant_id=p_tenant AND l.status='published' AND l.category=q.target_category
         AND l.id<>o.source_listing AND o.region<>''
         AND (lower(l.locality) LIKE '%'||lower(split_part(o.region,',',1))||'%'
           OR lower(o.region) LIKE '%'||lower(l.locality)||'%')
         AND quote.live->>'availability'<>'unavailable'
       ORDER BY l.updated_at DESC LIMIT 1) suggestion,
      (SELECT jsonb_build_object('name',x.name,'percent',x.discount_percent,'endsOn',x.ends_on)
       FROM agency.customer_cross_sell_campaigns x
       WHERE x.tenant_id=p_tenant AND x.status='active' AND x.target_category=q.target_category
         AND (x.source_category IS NULL OR x.source_category=o.source_category)
         AND current_date BETWEEN x.starts_on AND x.ends_on
       ORDER BY (x.source_category IS NOT NULL) DESC,x.discount_percent DESC LIMIT 1) offer
    FROM owned o JOIN agency.journey_question_rules q ON q.source_category=o.source_category
    LEFT JOIN agency.customer_journey_answers a ON a.tenant_id=p_tenant AND a.user_id=p_user
      AND a.reservation_id=o.id AND a.target_category=q.target_category
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('reservationId',id,'reference',reference_code,
    'sourceTitle',source_title,'sourceCategory',source_category,'region',region,
    'targetCategory',target_category,'question',question_tr,'answer',answer,
    'suggestion',suggestion,'offer',offer) ORDER BY created_at DESC,position),'[]'::jsonb)
  FROM matched
$$;

CREATE OR REPLACE FUNCTION agency.set_customer_cross_sell_campaign_status(
  p_tenant uuid,p_actor uuid,p_campaign uuid,p_status text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) OR p_status NOT IN ('active','paused') THEN
    RAISE EXCEPTION 'campaign_access_denied'; END IF;
  UPDATE agency.customer_cross_sell_campaigns SET status=p_status
    WHERE tenant_id=p_tenant AND id=p_campaign AND status IN ('active','paused')
      AND (p_status='paused' OR ends_on>=current_date);
  IF NOT FOUND THEN RAISE EXCEPTION 'campaign_status_invalid'; END IF;
  RETURN p_campaign;
END $$;
REVOKE ALL ON FUNCTION agency.set_customer_cross_sell_campaign_status(uuid,uuid,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.set_customer_cross_sell_campaign_status(uuid,uuid,uuid,text) TO agency_app;
