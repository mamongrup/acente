ALTER TABLE agency.conversations ADD COLUMN IF NOT EXISTS claimed_user_id uuid REFERENCES agency.users(id) ON DELETE SET NULL;

CREATE TABLE agency.customer_recommendation_feedback (
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  choice text NOT NULL CHECK(choice IN ('interested','not_interested','more_like')),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(tenant_id,user_id,listing_id)
);
GRANT SELECT,INSERT,UPDATE ON agency.customer_recommendation_feedback TO agency_app;

CREATE OR REPLACE FUNCTION agency.save_recommendation_feedback(
  p_tenant uuid,p_user uuid,p_listing uuid,p_choice text
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF p_choice NOT IN ('interested','not_interested','more_like')
    OR NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_user AND tenant_id=p_tenant AND active AND membership_type='customer')
    OR NOT EXISTS(SELECT 1 FROM agency.listings l WHERE l.id=p_listing AND l.tenant_id=p_tenant)
    OR NOT EXISTS(SELECT 1 FROM agency.customer_chat_recommendations r WHERE r.tenant_id=p_tenant AND r.user_id=p_user AND r.listing_id=p_listing)
       AND NOT EXISTS(SELECT 1 FROM agency.notifications n WHERE n.tenant_id=p_tenant AND n.user_id=p_user AND n.template='travel.recommendation' AND n.status IN ('sent','delivered','read') AND n.payload->>'listing_id'=p_listing::text)
  THEN RETURN false; END IF;
  INSERT INTO agency.customer_recommendation_feedback(tenant_id,user_id,listing_id,choice)
    VALUES(p_tenant,p_user,p_listing,p_choice)
    ON CONFLICT(tenant_id,user_id,listing_id) DO UPDATE SET choice=excluded.choice,updated_at=now();
  RETURN true;
END $$;

CREATE OR REPLACE FUNCTION agency.claim_chat_conversation(p_tenant uuid,p_user uuid,p_conversation uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_count integer:=0; v_message text; v_user_email text;
BEGIN
  SELECT lower(email) INTO v_user_email FROM agency.users
    WHERE id=p_user AND tenant_id=p_tenant AND active AND membership_type='customer';
  IF v_user_email IS NULL OR NOT EXISTS(
    SELECT 1 FROM agency.conversations c JOIN agency.customers x ON x.id=c.customer_id AND x.tenant_id=c.tenant_id
    WHERE c.id=p_conversation AND c.tenant_id=p_tenant AND c.channel='web'
      AND lower(x.email)=v_user_email AND (c.claimed_user_id IS NULL OR c.claimed_user_id=p_user)
  ) THEN RETURN -1; END IF;
  UPDATE agency.conversations SET claimed_user_id=p_user WHERE id=p_conversation AND tenant_id=p_tenant;
  FOR v_message IN SELECT body FROM agency.messages
    WHERE conversation_id=p_conversation AND direction='inbound' ORDER BY created_at DESC LIMIT 10
  LOOP
    v_count:=v_count+agency.record_chat_recommendations(p_tenant,p_user,p_conversation,v_message,NULL);
  END LOOP;
  RETURN v_count;
END $$;
REVOKE ALL ON FUNCTION agency.save_recommendation_feedback(uuid,uuid,uuid,text),agency.claim_chat_conversation(uuid,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.save_recommendation_feedback(uuid,uuid,uuid,text),agency.claim_chat_conversation(uuid,uuid,uuid) TO agency_app;
