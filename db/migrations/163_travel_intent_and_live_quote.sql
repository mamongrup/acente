CREATE TABLE agency.customer_travel_intents (
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  region text NOT NULL DEFAULT '',
  category text NOT NULL DEFAULT '',
  start_date date,
  end_date date,
  guests integer NOT NULL DEFAULT 2 CHECK(guests BETWEEN 1 AND 50),
  budget_minor bigint CHECK(budget_minor IS NULL OR budget_minor>0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(tenant_id,user_id),
  CHECK(end_date IS NULL OR start_date IS NULL OR end_date>start_date)
);
GRANT SELECT,INSERT,UPDATE ON agency.customer_travel_intents TO agency_app;

CREATE OR REPLACE FUNCTION agency.recommendation_live_quote(
  p_tenant uuid,p_listing uuid,p_start date,p_end date,p_guests integer
) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT jsonb_build_object(
    'price',coalesce((SELECT a.price_minor FROM agency.availability a WHERE a.listing_id=l.id AND a.day=p_start AND a.price_minor>0 LIMIT 1),l.price_minor),
    'currency',l.currency,
    'availability',CASE WHEN l.status<>'published' THEN 'unavailable'
      WHEN p_start IS NULL OR p_end IS NULL THEN 'unknown'
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

CREATE OR REPLACE FUNCTION agency.capture_chat_travel_intent(p_tenant uuid,p_user uuid,p_message text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_guests text; v_budget text; v_region text; v_category text;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_user AND tenant_id=p_tenant AND membership_type='customer' AND active)
    OR length(p_message)>4000 THEN RETURN false; END IF;
  SELECT (regexp_match(lower(p_message),'([0-9]{1,2})[[:space:]]*(kişi|misafir|yetişkin)'))[1] INTO v_guests;
  SELECT (regexp_match(lower(p_message),'([0-9]{2,8})[[:space:]]*(tl|₺)'))[1] INTO v_budget;
  SELECT l.locality INTO v_region FROM agency.listings l WHERE l.tenant_id=p_tenant AND l.status='published'
    AND l.locality<>'' AND lower(p_message) LIKE '%'||lower(l.locality)||'%' ORDER BY length(l.locality) DESC LIMIT 1;
  SELECT l.category INTO v_category FROM agency.listings l WHERE l.tenant_id=p_tenant AND l.status='published'
    AND lower(p_message) LIKE '%'||lower(l.category)||'%' LIMIT 1;
  IF v_guests IS NULL AND v_budget IS NULL AND v_region IS NULL AND v_category IS NULL THEN RETURN false; END IF;
  INSERT INTO agency.customer_travel_intents(tenant_id,user_id,region,category,guests,budget_minor)
    VALUES(p_tenant,p_user,coalesce(v_region,''),coalesce(v_category,''),least(50,greatest(1,coalesce(v_guests::integer,2))),v_budget::bigint*100)
    ON CONFLICT(tenant_id,user_id) DO UPDATE SET
      region=coalesce(nullif(excluded.region,''),agency.customer_travel_intents.region),
      category=coalesce(nullif(excluded.category,''),agency.customer_travel_intents.category),
      guests=CASE WHEN v_guests IS NULL THEN agency.customer_travel_intents.guests ELSE excluded.guests END,
      budget_minor=coalesce(excluded.budget_minor,agency.customer_travel_intents.budget_minor),updated_at=now();
  RETURN true;
END $$;
REVOKE ALL ON FUNCTION agency.capture_chat_travel_intent(uuid,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.capture_chat_travel_intent(uuid,uuid,text) TO agency_app;
