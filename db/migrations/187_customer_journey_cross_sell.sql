-- Reservation-led cross-sell stays local to the agency and is optional for every tenant.
CREATE TABLE IF NOT EXISTS agency.journey_question_rules (
  source_category text NOT NULL, target_category text NOT NULL,
  question_tr text NOT NULL, position integer NOT NULL,
  PRIMARY KEY(source_category,target_category)
);
INSERT INTO agency.journey_question_rules(source_category,target_category,question_tr,position) VALUES
('flight','transfer','Havalimanından konaklayacağınız yere transfer ister misiniz?',10),
('flight','car','Varış noktasında araç kiralamak ister misiniz?',20),
('flight','hotel','Nerede konaklayacaksınız? Otel seçeneklerine bakalım mı?',30),
('flight','holiday_home','Tatil evi seçeneklerini görmek ister misiniz?',40),
('flight','activity','Bölgede aktivite planlamak ister misiniz?',50),
('bus','transfer','Otogardan konaklayacağınız yere transfer ister misiniz?',10),
('bus','car','Varış noktasında araç kiralamak ister misiniz?',20),
('bus','hotel','Varış noktasında otel arıyor musunuz?',30),
('bus','holiday_home','Tatil evi seçeneklerini görmek ister misiniz?',40),
('bus','activity','Bölgede aktivite planlamak ister misiniz?',50),
('hotel','flight','Otele nasıl gideceksiniz? Uçuş seçeneklerine bakalım mı?',10),
('hotel','bus','Otobüsle ulaşım seçeneklerini görmek ister misiniz?',20),
('hotel','transfer','Otele transfer ister misiniz?',30),
('hotel','car','Konaklamanız boyunca araç kiralamak ister misiniz?',40),
('hotel','activity','Konakladığınız bölgede aktivite ister misiniz?',50),
('hotel','beach','Plaj ve şezlong seçeneklerini görmek ister misiniz?',60),
('holiday_home','flight','Tatil evine nasıl gideceksiniz? Uçuş ister misiniz?',10),
('holiday_home','bus','Otobüsle ulaşım seçeneklerini görmek ister misiniz?',20),
('holiday_home','transfer','Tatil evine transfer ister misiniz?',30),
('holiday_home','car','Konaklamanız boyunca araç kiralamak ister misiniz?',40),
('holiday_home','activity','Bölgede aktivite yapmak ister misiniz?',50),
('holiday_home','beach','Plaj ve şezlong seçeneklerini görmek ister misiniz?',60),
('yacht','transfer','Marinaya transfer ister misiniz?',10),('yacht','hotel','Seyir öncesi veya sonrası konaklama ister misiniz?',20),
('tour','transfer','Tur buluşma noktasına transfer ister misiniz?',10),('tour','hotel','Tur öncesi veya sonrası konaklama ister misiniz?',20),
('activity','transfer','Aktiviteye ulaşım için transfer ister misiniz?',10),('activity','restaurant','Aktivite sonrası restoran seçeneklerini görmek ister misiniz?',20),
('car','hotel','Seyahatinizde konaklama arıyor musunuz?',10),('car','activity','Araçla keşfedeceğiniz bölgede aktivite ister misiniz?',20),
('cruise','transfer','Liman transferi ister misiniz?',10),('cruise','hotel','Sefer öncesi veya sonrası konaklama ister misiniz?',20),
('pilgrimage','transfer','Havalimanı veya otel transferi ister misiniz?',10),('pilgrimage','hotel','Ek konaklama seçeneklerini görmek ister misiniz?',20),
('visa','flight','Vizeniz için planladığınız uçuşlara bakalım mı?',10),('visa','hotel','Seyahatiniz için konaklama ister misiniz?',20),
('ferry','transfer','Liman çıkışında transfer ister misiniz?',10),('ferry','car','Varış yerinde araç kiralamak ister misiniz?',20),
('transfer','hotel','Varış yerinde konaklama ister misiniz?',10),('transfer','activity','Bölgede aktivite planlamak ister misiniz?',20),
('beach','restaurant','Plaj yakınında restoran seçeneklerini görmek ister misiniz?',10),('beach','activity','Bölgede başka aktiviteler ister misiniz?',20),
('cinema','restaurant','Seans öncesi veya sonrası restoran ister misiniz?',10),('cinema','event','Yakındaki etkinlikleri görmek ister misiniz?',20),
('event','transfer','Etkinlik ulaşımı için transfer ister misiniz?',10),('event','restaurant','Etkinlik öncesi veya sonrası restoran ister misiniz?',20),
('restaurant','event','Yakındaki etkinlikleri görmek ister misiniz?',10),('restaurant','transfer','Dönüş için transfer ister misiniz?',20)
ON CONFLICT (source_category,target_category) DO UPDATE
  SET question_tr=excluded.question_tr, position=excluded.position;

CREATE TABLE IF NOT EXISTS agency.customer_journey_answers (
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL REFERENCES agency.reservations(id) ON DELETE CASCADE,
  target_category text NOT NULL,
  answer text NOT NULL CHECK(answer IN ('yes','no','later')),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(tenant_id,user_id,reservation_id,target_category)
);

CREATE TABLE IF NOT EXISTS agency.customer_cross_sell_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  name text NOT NULL CHECK(length(trim(name)) BETWEEN 3 AND 120),
  source_category text,
  target_category text NOT NULL,
  discount_percent numeric(5,2) NOT NULL CHECK(discount_percent>0 AND discount_percent<=50),
  starts_on date NOT NULL, ends_on date NOT NULL CHECK(ends_on>=starts_on),
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','active','paused')),
  created_by uuid NOT NULL REFERENCES agency.users(id),
  approved_by uuid REFERENCES agency.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK(source_category IS NULL OR source_category<>target_category)
);
CREATE INDEX IF NOT EXISTS customer_cross_sell_active_idx ON agency.customer_cross_sell_campaigns(tenant_id,target_category,status,starts_on,ends_on);

CREATE OR REPLACE FUNCTION agency.answer_journey_question(p_tenant uuid,p_user uuid,p_reservation uuid,p_target text,p_answer text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF p_answer NOT IN ('yes','no','later') OR NOT EXISTS(
    SELECT 1 FROM agency.reservations r
    JOIN agency.customers c ON c.id=r.customer_id AND c.tenant_id=r.tenant_id
    JOIN agency.users u ON u.id=p_user AND u.tenant_id=r.tenant_id AND u.active
      AND u.membership_type='customer' AND lower(u.email)=lower(c.email)
    JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
    JOIN agency.journey_question_rules q ON q.source_category=l.category AND q.target_category=p_target
    WHERE r.id=p_reservation AND r.tenant_id=p_tenant AND r.status IN ('confirmed','completed')
  ) THEN RETURN false; END IF;
  INSERT INTO agency.customer_journey_answers(tenant_id,user_id,reservation_id,target_category,answer)
    VALUES(p_tenant,p_user,p_reservation,p_target,p_answer)
    ON CONFLICT(tenant_id,user_id,reservation_id,target_category)
    DO UPDATE SET answer=excluded.answer,updated_at=now();
  RETURN true;
END $$;

CREATE OR REPLACE FUNCTION agency.save_customer_cross_sell_campaign(
  p_tenant uuid,p_actor uuid,p_name text,p_source text,p_target text,
  p_discount numeric,p_starts date,p_ends date
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'campaign_access_denied'; END IF;
  IF NOT EXISTS(SELECT 1 FROM agency.category_service_steps WHERE category_code=p_target)
    OR (p_source IS NOT NULL AND NOT EXISTS(SELECT 1 FROM agency.journey_question_rules
      WHERE source_category=p_source AND target_category=p_target)) THEN
    RAISE EXCEPTION 'invalid_campaign_category'; END IF;
  INSERT INTO agency.customer_cross_sell_campaigns(tenant_id,name,source_category,target_category,
    discount_percent,starts_on,ends_on,created_by)
    VALUES(p_tenant,p_name,p_source,p_target,p_discount,p_starts,p_ends,p_actor)
    RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.activate_customer_cross_sell_campaign(p_tenant uuid,p_actor uuid,p_campaign uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'campaign_access_denied'; END IF;
  UPDATE agency.customer_cross_sell_campaigns SET status='active',approved_by=p_actor
    WHERE tenant_id=p_tenant AND id=p_campaign AND status='draft' AND ends_on>=current_date;
  IF NOT FOUND THEN RAISE EXCEPTION 'campaign_not_ready'; END IF;
  RETURN p_campaign;
END $$;

CREATE OR REPLACE FUNCTION agency.customer_journey_recommendations(p_tenant uuid,p_user uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  WITH owned AS (
    SELECT r.id,r.reference_code,r.check_in,r.check_out,r.created_at,l.category source_category,
      coalesce(nullif(i.region,''),nullif(l.metadata->>'destination_city',''),nullif(l.locality,''),'') region,
      l.title source_title,l.id source_listing
    FROM agency.reservations r
    JOIN agency.customers c ON c.id=r.customer_id AND c.tenant_id=r.tenant_id
    JOIN agency.users u ON u.id=p_user AND u.tenant_id=r.tenant_id AND u.active
      AND u.membership_type='customer' AND lower(u.email)=lower(c.email)
    JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
    LEFT JOIN agency.customer_travel_intents i ON i.tenant_id=r.tenant_id AND i.user_id=p_user
    WHERE r.tenant_id=p_tenant AND r.status IN ('confirmed','completed')
      AND (r.check_out IS NULL OR r.check_out>=current_date-30)
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

REVOKE ALL ON agency.journey_question_rules,agency.customer_journey_answers,
  agency.customer_cross_sell_campaigns FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.answer_journey_question(uuid,uuid,uuid,text,text),
  agency.save_customer_cross_sell_campaign(uuid,uuid,text,text,text,numeric,date,date),
  agency.activate_customer_cross_sell_campaign(uuid,uuid,uuid),
  agency.customer_journey_recommendations(uuid,uuid) FROM PUBLIC;
GRANT SELECT ON agency.journey_question_rules,agency.customer_cross_sell_campaigns TO agency_app;
GRANT EXECUTE ON FUNCTION agency.answer_journey_question(uuid,uuid,uuid,text,text),
  agency.save_customer_cross_sell_campaign(uuid,uuid,text,text,text,numeric,date,date),
  agency.activate_customer_cross_sell_campaign(uuid,uuid,uuid),
  agency.customer_journey_recommendations(uuid,uuid) TO agency_app;
