ALTER TABLE agency.customer_notification_preferences
  ADD COLUMN IF NOT EXISTS marketing_whatsapp boolean NOT NULL DEFAULT false;

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
