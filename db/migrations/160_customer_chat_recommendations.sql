-- Suggestions are owned by the authenticated customer, never by an unverified
-- email address entered into the public chat widget.
CREATE TABLE agency.customer_chat_recommendations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  conversation_id uuid NOT NULL REFERENCES agency.conversations(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  request_excerpt text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,user_id,conversation_id,listing_id)
);
CREATE INDEX customer_chat_recommendations_owner_idx
  ON agency.customer_chat_recommendations(tenant_id,user_id,created_at DESC);

CREATE OR REPLACE FUNCTION agency.record_chat_recommendations(
  p_tenant uuid,p_user uuid,p_conversation uuid,p_message text,p_listing uuid DEFAULT NULL
) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_count integer;
BEGIN
  IF length(trim(coalesce(p_message,''))) < 3 OR length(p_message)>4000
     OR NOT EXISTS(SELECT 1 FROM agency.users u WHERE u.id=p_user AND u.tenant_id=p_tenant AND u.active AND u.membership_type='customer')
     OR NOT EXISTS(SELECT 1 FROM agency.conversations c WHERE c.id=p_conversation AND c.tenant_id=p_tenant AND c.channel='web')
  THEN RETURN 0; END IF;
  WITH terms AS (
    SELECT DISTINCT term FROM regexp_split_to_table(lower(p_message),'[^[:alnum:]ğüşıöç]+') term
    WHERE length(term)>=4 AND term NOT IN ('istiyorum','arıyorum','nasıl','olsun','için','bana','bütçe','kişilik','tatil','merhaba','teşekkür')
    LIMIT 24
  ), candidates AS (
    SELECT l.id, CASE WHEN l.id=p_listing THEN 100 ELSE 0 END +
      (SELECT count(*)::integer FROM terms t WHERE lower(concat_ws(' ',l.title,l.locality,l.category)) LIKE '%' || t.term || '%') AS score
    FROM agency.listings l
    WHERE l.tenant_id=p_tenant AND l.status='published'
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
GRANT SELECT ON agency.customer_chat_recommendations TO agency_app;
