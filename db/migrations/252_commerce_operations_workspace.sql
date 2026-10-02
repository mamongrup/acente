CREATE OR REPLACE FUNCTION agency.commerce_operations_data(p_tenant uuid,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'operations_access_denied'; END IF;
 RETURN jsonb_build_object(
  'listings',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'title',title,'category',category,'source',source,'status',status) ORDER BY title) FROM agency.listings WHERE tenant_id=p_tenant),'[]'::jsonb),
  'feeds',coalesce((SELECT jsonb_agg(jsonb_build_object('id',f.id,'listingId',f.listing_id,'listing',l.title,
   'label',f.label,'host',split_part(split_part(f.url,'/',3),'?',1),'active',f.active,'timezone',f.timezone,
   'lastSync',f.last_synced_at,'nextSync',f.next_sync_at,'error',f.last_error,'failures',f.failure_count,
   'events',f.event_count,'working',f.claimed_at IS NOT NULL) ORDER BY f.label)
   FROM agency.external_calendar_feeds f JOIN agency.listings l ON l.id=f.listing_id AND l.tenant_id=f.tenant_id WHERE f.tenant_id=p_tenant),'[]'::jsonb),
  'conflicts',coalesce((SELECT jsonb_agg(x) FROM (SELECT DISTINCT r.reference_code AS reference,l.title AS listing,r.check_in AS arrival,r.check_out AS departure
   FROM agency.reservations r JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
   JOIN agency.external_calendar_feeds f ON f.listing_id=r.listing_id AND f.tenant_id=r.tenant_id AND f.active
   JOIN agency.external_calendar_blocks b ON b.feed_id=f.id AND b.starts_on<r.check_out AND b.ends_on>r.check_in
   WHERE r.tenant_id=p_tenant AND r.status IN ('option','confirmed') AND r.check_out>=current_date LIMIT 100) x),'[]'::jsonb),
  'channels',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'name',label,'key',channel_key,'mode',mode,'lastSync',last_success_at,'error',last_error)) FROM agency.sales_channels WHERE tenant_id=p_tenant),'[]'::jsonb),
  'channelQueue',agency.channel_delivery_summary(p_tenant,p_actor),
  'nexusQueue',coalesce((SELECT jsonb_object_agg(status,n) FROM (SELECT status,count(*) n FROM agency.nexus_reservation_deliveries WHERE tenant_id=p_tenant GROUP BY status) s),'{}'::jsonb),
  'finance',coalesce((SELECT jsonb_build_object('paymentProvider',payment_provider,'paymentStatus',payment_status,'documentProvider',document_provider,'documentStatus',document_status) FROM agency.finance_provider_settings WHERE tenant_id=p_tenant),'{}'::jsonb),
  'languages',coalesce((SELECT jsonb_agg(jsonb_build_object('language',language_code,'profiles',profiles,'filled',filled)) FROM
   (SELECT language_code,count(*) profiles,count(*) FILTER(WHERE title<>'' AND description<>'') filled FROM agency.seo_locales WHERE tenant_id=p_tenant GROUP BY language_code) s),'[]'::jsonb),
  'categories',coalesce((SELECT jsonb_agg(jsonb_build_object('code',code,'published',published,'connectedInquiryOnly',inquiry_only)) FROM
   (SELECT c.code,count(l.id) FILTER(WHERE l.status='published') published,count(l.id) FILTER(WHERE l.source='nexus' AND l.status='published' AND l.category NOT IN ('hotel','holiday_home','yacht')) inquiry_only
    FROM agency.categories c LEFT JOIN agency.listings l ON l.tenant_id=c.tenant_id AND l.category=c.code WHERE c.tenant_id=p_tenant AND c.parent_id IS NULL AND c.active GROUP BY c.code) s),'[]'::jsonb),
  'metrics',coalesce((SELECT jsonb_agg(jsonb_build_object('currency',currency,'bookings',n,'paidRevenueMinor',paid,'cancelled',cancelled)) FROM
   (SELECT currency,count(*) n,coalesce(sum(total_minor) FILTER(WHERE payment_status='paid' AND status IN ('confirmed','completed')),0) paid,
    count(*) FILTER(WHERE status='cancelled') cancelled FROM agency.reservations WHERE tenant_id=p_tenant AND created_at>=now()-interval '30 days' GROUP BY currency) s),'[]'::jsonb)
 );
END $$;
REVOKE ALL ON FUNCTION agency.commerce_operations_data(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.commerce_operations_data(uuid,uuid) TO agency_app;
