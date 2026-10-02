BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); x uuid:=gen_random_uuid(); source text; n int;
BEGIN
 INSERT INTO agency.tenants(id,legal_name,brand_name,slug) VALUES(t,'Locale SEO fixture','Locale SEO',t::text);
 SELECT count(*) INTO n FROM agency.seo_locales WHERE tenant_id=t AND resource_key LIKE 'page:%';
 IF n<108 THEN RAISE EXCEPTION 'Home + 17 categories must have six locale profiles'; END IF;
 INSERT INTO agency.listings(id,tenant_id,code,category,title,metadata) VALUES(x,t,'locale-fixture','yacht','Türkçe yat başlığı','{"extra_metadata":{"translations":{"en":{"title":"Gocek private yacht","description":"A private yacht in Gocek."},"zh":{"title":"私人游艇","description":"私人游艇旅行"}}}}');
 SELECT count(*) INTO n FROM agency.seo_locales WHERE tenant_id=t AND resource_key='listing:'||x::text;
 IF n<>6 THEN RAISE EXCEPTION 'New listing needs six locale profiles'; END IF;
 SELECT path INTO source FROM agency.seo_locales WHERE tenant_id=t AND resource_key='listing:'||x::text AND language_code='en';
 IF source NOT LIKE '/en/yacht/gocek-private-yacht-%' THEN RAISE EXCEPTION 'Use translated source title for foreign slug'; END IF;
 UPDATE agency.seo_locales SET path='/en/yacht/my-private-yacht' WHERE tenant_id=t AND resource_key='listing:'||x::text AND language_code='en';
 IF NOT EXISTS(SELECT 1 FROM agency.seo_path_aliases WHERE tenant_id=t AND path=source) THEN RAISE EXCEPTION 'Old URL must be retained'; END IF;
 DELETE FROM agency.listings WHERE id=x;
 IF EXISTS(SELECT 1 FROM agency.seo_locales WHERE tenant_id=t AND resource_key='listing:'||x::text) THEN RAISE EXCEPTION 'Deleted listing cannot leave locale profiles'; END IF;
END $$;
ROLLBACK;
