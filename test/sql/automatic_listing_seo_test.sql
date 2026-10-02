BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); x uuid:=gen_random_uuid(); y uuid:=gen_random_uuid(); before_slug text; c text;
BEGIN
 INSERT INTO agency.tenants(id,legal_name,brand_name,slug) VALUES(t,'SEO transaction fixture','SEO fixture',t::text);
 FOREACH c IN ARRAY ARRAY['hotel','holiday_home','yacht','tour','activity','flight','car','cruise','pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus'] LOOP
  INSERT INTO agency.listings(tenant_id,code,category,title) VALUES(t,c,c,'SEO fixture '||c);
 END LOOP;
 IF (SELECT count(*) FROM agency.listing_seo WHERE tenant_id=t)<>17 THEN RAISE EXCEPTION 'All category inserts need automatic SEO'; END IF;
 INSERT INTO agency.listings(id,tenant_id,code,category,title) VALUES(x,t,'duplicate-a','yacht','Aynı başlık'),(y,t,'duplicate-b','yacht','Aynı başlık');
 IF (SELECT count(DISTINCT stable_slug) FROM agency.listing_seo WHERE listing_id IN (x,y))<>2 THEN RAISE EXCEPTION 'Duplicate titles must have unique slugs'; END IF;
 SELECT stable_slug INTO before_slug FROM agency.listing_seo WHERE listing_id=x;
 UPDATE agency.listings SET title='Başlığı güncelledim' WHERE id=x;
 IF (SELECT stable_slug FROM agency.listing_seo WHERE listing_id=x)<>before_slug THEN RAISE EXCEPTION 'Slug must survive title updates'; END IF;
 IF agency.seo_listing_data(t,x,'tr') IS NOT NULL THEN RAISE EXCEPTION 'Draft must not appear as public SEO data'; END IF;
END $$;
ROLLBACK;
