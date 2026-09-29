CREATE OR REPLACE FUNCTION agency.record_chat_recommendations(
  p_tenant uuid,p_user uuid,p_conversation uuid,p_message text,p_listing uuid DEFAULT NULL
) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_count integer;
BEGIN
  IF length(trim(coalesce(p_message,'')))<3 OR length(p_message)>4000
     OR NOT EXISTS(SELECT 1 FROM agency.users u WHERE u.id=p_user AND u.tenant_id=p_tenant AND u.active AND u.membership_type='customer')
     OR NOT EXISTS(
       SELECT 1 FROM agency.conversations c
       JOIN agency.customers x ON x.id=c.customer_id AND x.tenant_id=c.tenant_id
       JOIN agency.users u ON u.id=p_user AND u.tenant_id=c.tenant_id
       WHERE c.id=p_conversation AND c.tenant_id=p_tenant AND c.channel='web'
         AND lower(x.email)=lower(u.email)
         AND (c.claimed_user_id IS NULL OR c.claimed_user_id=p_user)
     )
  THEN RETURN 0; END IF;
  WITH terms AS (
    SELECT DISTINCT term FROM regexp_split_to_table(lower(p_message),'[^[:alnum:]ğüşıöç]+') term
    WHERE length(term)>=4 AND term NOT IN ('istiyorum','arıyorum','nasıl','olsun','için','bana','bütçe','kişilik','tatil','merhaba','teşekkür') LIMIT 24
  ), intent AS (
    SELECT region,category,start_date,end_date,guests,budget_minor FROM agency.customer_travel_intents
    WHERE tenant_id=p_tenant AND user_id=p_user
  ), candidates AS (
    SELECT l.id,l.category,
      (CASE WHEN l.id=p_listing THEN 100 ELSE 0 END)+
      (SELECT count(*)::integer*4 FROM terms t WHERE lower(concat_ws(' ',l.title,l.locality,l.category)) LIKE '%'||t.term||'%')+
      (CASE WHEN i.region<>'' AND lower(l.locality) LIKE '%'||lower(i.region)||'%' THEN 8 ELSE 0 END)+
      (CASE WHEN i.category<>'' AND l.category=i.category THEN 6 ELSE 0 END)+
      (CASE WHEN i.budget_minor IS NOT NULL AND l.price_minor<=i.budget_minor THEN 3 ELSE 0 END)+
      (SELECT count(*)::integer*3 FROM agency.customer_recommendation_feedback xf
        JOIN agency.listings xl ON xl.id=xf.listing_id AND xl.tenant_id=xf.tenant_id
        WHERE xf.tenant_id=p_tenant AND xf.user_id=p_user AND xf.choice='more_like' AND xl.category=l.category AND xl.id<>l.id)+
      (CASE WHEN f.choice='more_like' THEN 3 WHEN f.choice='not_interested' THEN -100 ELSE 0 END) AS score
    FROM agency.listings l LEFT JOIN intent i ON true
      LEFT JOIN agency.customer_recommendation_feedback f ON f.tenant_id=l.tenant_id AND f.user_id=p_user AND f.listing_id=l.id
    WHERE l.tenant_id=p_tenant AND l.status='published'
      AND (i.guests IS NULL OR coalesce(l.metadata->>'guest_capacity',l.metadata->>'capacity','') !~ '^[0-9]{1,3}$'
           OR coalesce(l.metadata->>'guest_capacity',l.metadata->>'capacity')::integer>=i.guests)
      AND NOT EXISTS(SELECT 1 FROM agency.availability a WHERE a.listing_id=l.id AND i.start_date IS NOT NULL AND i.end_date IS NOT NULL
        AND a.day>=i.start_date AND a.day<i.end_date AND (a.closed OR a.units_available<1))
  ), chosen AS (
    SELECT id FROM candidates WHERE score>0 ORDER BY score DESC,id LIMIT 3
  )
  INSERT INTO agency.customer_chat_recommendations(tenant_id,user_id,conversation_id,listing_id,request_excerpt)
    SELECT p_tenant,p_user,p_conversation,id,left(p_message,300) FROM chosen
    ON CONFLICT(tenant_id,user_id,conversation_id,listing_id)
      DO UPDATE SET request_excerpt=excluded.request_excerpt,created_at=now();
  GET DIAGNOSTICS v_count=ROW_COUNT;
  RETURN v_count;
END $$;
REVOKE ALL ON FUNCTION agency.record_chat_recommendations(uuid,uuid,uuid,text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.record_chat_recommendations(uuid,uuid,uuid,text,uuid) TO agency_app;
