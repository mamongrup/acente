-- Keep recommendations relevant and prevent accidental repeat campaigns.
CREATE OR REPLACE FUNCTION agency.queue_personal_recommendation(
  p_tenant uuid,p_actor uuid,p_customer uuid,p_listing uuid,p_channel text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_customer agency.customers%ROWTYPE; v_user uuid; v_title text; v_notification uuid;
  v_message text; v_html text;
BEGIN
  IF p_channel NOT IN ('email','whatsapp') OR
    NOT EXISTS(SELECT 1 FROM agency.users u WHERE u.id=p_actor AND u.tenant_id=p_tenant AND u.active AND u.membership_type IN ('admin','staff'))
  THEN RETURN NULL; END IF;
  SELECT * INTO v_customer FROM agency.customers WHERE id=p_customer AND tenant_id=p_tenant;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT u.id INTO v_user FROM agency.users u WHERE u.tenant_id=p_tenant AND u.active AND u.membership_type='customer'
    AND lower(u.email)=lower(v_customer.email) LIMIT 1;
  IF v_user IS NULL THEN RETURN NULL; END IF;
  SELECT title INTO v_title FROM agency.listings WHERE id=p_listing AND tenant_id=p_tenant AND status='published';
  IF v_title IS NULL THEN RETURN NULL; END IF;
  IF p_channel='email' AND (v_customer.email='' OR NOT EXISTS(
      SELECT 1 FROM agency.customer_notification_preferences p WHERE p.tenant_id=p_tenant AND p.user_id=v_user AND p.marketing_email))
  THEN RETURN NULL; END IF;
  IF p_channel='whatsapp' AND (v_customer.phone='' OR NOT EXISTS(
      SELECT 1 FROM agency.customer_notification_preferences p WHERE p.tenant_id=p_tenant AND p.user_id=v_user AND p.marketing_whatsapp))
  THEN RETURN NULL; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_tenant::text||':'||v_user::text||':'||p_listing::text||':'||p_channel,0));
  SELECT n.id INTO v_notification FROM agency.notifications n
    WHERE n.tenant_id=p_tenant AND n.user_id=v_user AND n.channel=p_channel
      AND n.template='travel.recommendation' AND n.payload->>'listing_id'=p_listing::text
      AND n.status IN ('queued','sending','sent','accepted','delivered','read')
      AND n.created_at>now()-interval '24 hours'
    ORDER BY n.created_at DESC LIMIT 1;
  IF v_notification IS NOT NULL THEN RETURN v_notification; END IF;
  v_message := 'Merhaba ' || v_customer.full_name || ', size önerdiğimiz seçenek: ' || v_title || '. Ayrıntıları hesabınızdaki Size özel öneriler bölümünde görebilirsiniz.';
  v_html := '<p>' || replace(replace(replace(v_message,'&','&amp;'),'<','&lt;'),'>','&gt;') || '</p>';
  INSERT INTO agency.notifications(tenant_id,user_id,channel,template,payload,status)
    VALUES(p_tenant,v_user,p_channel,'travel.recommendation',
      jsonb_build_object('listing_id',p_listing::text,'name',v_customer.full_name,'email',v_customer.email,
        'to',v_customer.email,'phone',v_customer.phone,'message',v_message,
        'subject','Size özel seyahat önerisi','html',v_html),'queued') RETURNING id INTO v_notification;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'customer.recommendation_queued','notification',v_notification,
      jsonb_build_object('customer_id',p_customer,'listing_id',p_listing,'channel',p_channel));
  RETURN v_notification;
END $$;
REVOKE ALL ON FUNCTION agency.queue_personal_recommendation(uuid,uuid,uuid,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.queue_personal_recommendation(uuid,uuid,uuid,uuid,text) TO agency_app;

CREATE OR REPLACE FUNCTION agency.recommendation_live_quote(
  p_tenant uuid,p_listing uuid,p_start date,p_end date,p_guests integer
) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT jsonb_build_object(
    'price',coalesce((SELECT a.price_minor FROM agency.availability a WHERE a.listing_id=l.id AND a.day=p_start AND a.price_minor>0 LIMIT 1),l.price_minor),
    'currency',l.currency,
    'availability',CASE WHEN l.status<>'published' OR
        (coalesce(l.metadata->>'guest_capacity',l.metadata->>'capacity','') ~ '^[0-9]{1,3}$'
          AND coalesce(l.metadata->>'guest_capacity',l.metadata->>'capacity')::integer<coalesce(p_guests,2)) THEN 'unavailable'
      WHEN p_start IS NULL OR p_end IS NULL OR p_end<=p_start THEN 'unknown'
      WHEN EXISTS(SELECT 1 FROM agency.availability a WHERE a.listing_id=l.id AND a.day>=p_start AND a.day<p_end AND (a.closed OR a.units_available<1)) THEN 'unavailable'
      WHEN (SELECT count(*) FROM agency.availability a WHERE a.listing_id=l.id AND a.day>=p_start AND a.day<p_end)=p_end-p_start THEN 'available'
      ELSE 'unknown' END,
    'capacity',CASE WHEN coalesce(l.metadata->>'guest_capacity',l.metadata->>'capacity','') ~ '^[0-9]{1,3}$'
      THEN coalesce(l.metadata->>'guest_capacity',l.metadata->>'capacity')::integer ELSE NULL END,
    'updatedAt',l.updated_at
  ) FROM agency.listings l WHERE l.id=p_listing AND l.tenant_id=p_tenant;
$$;
REVOKE ALL ON FUNCTION agency.recommendation_live_quote(uuid,uuid,date,date,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.recommendation_live_quote(uuid,uuid,date,date,integer) TO agency_app;
