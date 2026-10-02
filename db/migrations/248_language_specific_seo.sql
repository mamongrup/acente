BEGIN;
CREATE TABLE IF NOT EXISTS agency.seo_locales (
 tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
 resource_key text NOT NULL, language_code text NOT NULL CHECK(language_code IN ('tr','en','de','ru','fr','zh')),
 source_path text NOT NULL, path text NOT NULL, path_custom boolean NOT NULL DEFAULT false,
 title text NOT NULL DEFAULT '', description text NOT NULL DEFAULT '', keywords text NOT NULL DEFAULT '',
 og_title text NOT NULL DEFAULT '', og_description text NOT NULL DEFAULT '', og_image text NOT NULL DEFAULT '',
 noindex boolean NOT NULL DEFAULT false, updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,resource_key,language_code), UNIQUE(tenant_id,path)
);
CREATE TABLE IF NOT EXISTS agency.seo_path_aliases (
 tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
 path text NOT NULL, resource_key text NOT NULL, language_code text NOT NULL,
 PRIMARY KEY(tenant_id,path), FOREIGN KEY(tenant_id,resource_key,language_code) REFERENCES agency.seo_locales ON DELETE CASCADE
);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.seo_locales,agency.seo_path_aliases TO agency_app;
CREATE OR REPLACE FUNCTION agency.seo_category_path(c text,lang text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE lang
 WHEN 'tr' THEN '/'||coalesce((jsonb_build_object('hotel','otel','holiday_home','tatil-evi','yacht','yat','tour','tur','activity','aktivite','flight','ucus','car','arac','cruise','kruvaziyer','pilgrimage','hac-umre','visa','vize','ferry','feribot','transfer','transfer','beach','sezlong','cinema','sinema','event','etkinlik','restaurant','restoran','bus','otobus')->>c),c)
 WHEN 'en' THEN '/'||replace(c,'_','-')
 WHEN 'de' THEN '/'||coalesce((jsonb_build_object('hotel','hotel','holiday_home','ferienhaus','yacht','yacht','tour','tour','activity','aktivitaet','flight','flug','car','auto','cruise','kreuzfahrt','pilgrimage','wallfahrt','visa','visum','ferry','faehre','transfer','transfer','beach','liegestuhl','cinema','kino','event','veranstaltung','restaurant','restaurant','bus','bus')->>c),c)
 WHEN 'ru' THEN '/'||coalesce((jsonb_build_object('hotel','otel','holiday_home','dom-otdyha','yacht','yahta','tour','tur','activity','aktivnost','flight','polet','car','avtomobil','cruise','kruiz','pilgrimage','palomnichestvo','visa','viza','ferry','parom','transfer','transfer','beach','lezhak','cinema','kino','event','sobytie','restaurant','restoran','bus','avtobus')->>c),c)
 WHEN 'fr' THEN '/'||coalesce((jsonb_build_object('hotel','hotel','holiday_home','maison-de-vacances','yacht','yacht','tour','circuit','activity','activite','flight','vol','car','voiture','cruise','croisiere','pilgrimage','pelerinage','visa','visa','ferry','ferry','transfer','transfert','beach','transat','cinema','cinema','event','evenement','restaurant','restaurant','bus','bus')->>c),c)
 ELSE '/'||coalesce((jsonb_build_object('hotel','jiudian','holiday_home','dujiawu','yacht','youting','tour','lvyou','activity','huodong','flight','hangban','car','zuche','cruise','youlun','pilgrimage','chaojing','visa','qianzheng','ferry','du-lun','transfer','jiesong','beach','shatan','cinema','dianying','event','huodong-event','restaurant','canting','bus','gongjiao')->>c),c) END
 $$;
CREATE OR REPLACE FUNCTION agency.seo_slug(t text,fallback text) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT coalesce(nullif(regexp_replace(regexp_replace(translate(lower(translate(t,'ÇĞİIÖŞÜ','CGIIOSU')),'çğıöşü','cgiosu'),'[^[:alnum:]]+','-','g'),'(^-+|-+$)','','g'),''),fallback)
 $$;
CREATE OR REPLACE FUNCTION agency.ensure_listing_seo_locales() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,agency,public AS $$
DECLARE c text; lang text; source text;
BEGIN
 SELECT category INTO c FROM agency.listings WHERE id=NEW.listing_id AND tenant_id=NEW.tenant_id;
 source:=agency.seo_category_path(c,'tr')||'/'||NEW.stable_slug;
 FOREACH lang IN ARRAY ARRAY['tr','en','de','ru','fr','zh'] LOOP
  INSERT INTO agency.seo_locales(tenant_id,resource_key,language_code,source_path,path)
  VALUES(NEW.tenant_id,'listing:'||NEW.listing_id::text,lang,source,CASE WHEN lang='tr' THEN source ELSE '/'||lang||agency.seo_category_path(c,lang)||'/'||NEW.stable_slug END) ON CONFLICT DO NOTHING;
  IF lang<>'tr' THEN PERFORM agency.refresh_translated_seo_path(NEW.tenant_id,NEW.listing_id,lang); END IF;
 END LOOP;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS listing_seo_locales ON agency.listing_seo;
CREATE TRIGGER listing_seo_locales AFTER INSERT ON agency.listing_seo FOR EACH ROW EXECUTE FUNCTION agency.ensure_listing_seo_locales();
INSERT INTO agency.seo_locales(tenant_id,resource_key,language_code,source_path,path)
SELECT l.tenant_id,'listing:'||l.id::text,v.lang,agency.seo_category_path(l.category,'tr')||'/'||s.stable_slug,
 CASE WHEN v.lang='tr' THEN agency.seo_category_path(l.category,'tr')||'/'||s.stable_slug ELSE '/'||v.lang||agency.seo_category_path(l.category,v.lang)||'/'||s.stable_slug END
 FROM agency.listings l JOIN agency.listing_seo s ON s.listing_id=l.id AND s.tenant_id=l.tenant_id CROSS JOIN unnest(ARRAY['tr','en','de','ru','fr','zh']) v(lang) ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION agency.ensure_page_seo_locales() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,agency,public AS $$
DECLARE lang text; source text;
BEGIN
 IF NEW.slug='home' OR NEW.slug LIKE 'category-%' OR NEW.slug ~ '^(admin|api|login|hesap|uye-ol|uye-girisi|rezervasyon|odeme|sepet)(/|$)' THEN RETURN NEW; END IF;
 source:='/'||NEW.slug;
 FOREACH lang IN ARRAY ARRAY['tr','en','de','ru','fr','zh'] LOOP
  INSERT INTO agency.seo_locales(tenant_id,resource_key,language_code,source_path,path)
  VALUES(NEW.tenant_id,'page:'||source,lang,source,CASE WHEN lang='tr' THEN source ELSE '/'||lang||source END) ON CONFLICT DO NOTHING;
 END LOOP;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS page_seo_locales ON agency.pages;
CREATE TRIGGER page_seo_locales AFTER INSERT ON agency.pages FOR EACH ROW EXECUTE FUNCTION agency.ensure_page_seo_locales();
INSERT INTO agency.seo_locales(tenant_id,resource_key,language_code,source_path,path)
 SELECT p.tenant_id,'page:/'||p.slug,v.lang,'/'||p.slug,CASE WHEN v.lang='tr' THEN '/'||p.slug ELSE '/'||v.lang||'/'||p.slug END FROM agency.pages p CROSS JOIN unnest(ARRAY['tr','en','de','ru','fr','zh']) v(lang)
 WHERE p.slug<>'home' AND p.slug NOT LIKE 'category-%' AND p.slug !~ '^(admin|api|login|hesap|uye-ol|uye-girisi|rezervasyon|odeme|sepet)(/|$)' ON CONFLICT DO NOTHING;
INSERT INTO agency.seo_locales(tenant_id,resource_key,language_code,source_path,path)
 SELECT t.id,'page:/',v.lang,'/',CASE WHEN v.lang='tr' THEN '/' ELSE '/'||v.lang||'/' END FROM agency.tenants t CROSS JOIN unnest(ARRAY['tr','en','de','ru','fr','zh']) v(lang) ON CONFLICT DO NOTHING;
INSERT INTO agency.seo_locales(tenant_id,resource_key,language_code,source_path,path)
 SELECT t.id,'page:'||agency.seo_category_path(c,'tr'),v.lang,agency.seo_category_path(c,'tr'),CASE WHEN v.lang='tr' THEN agency.seo_category_path(c,'tr') ELSE '/'||v.lang||agency.seo_category_path(c,v.lang) END FROM agency.tenants t CROSS JOIN unnest(ARRAY['hotel','holiday_home','yacht','tour','activity','flight','car','cruise','pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus']) a(c) CROSS JOIN unnest(ARRAY['tr','en','de','ru','fr','zh']) v(lang) ON CONFLICT DO NOTHING;
-- Seed the same public locale resources for newly installed, independent tenants.
CREATE OR REPLACE FUNCTION agency.ensure_tenant_seo_locales() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,agency,public AS $$
BEGIN
 INSERT INTO agency.seo_locales(tenant_id,resource_key,language_code,source_path,path)
 SELECT NEW.id,'page:'||r.source,lang,r.source,CASE WHEN lang='tr' THEN r.source ELSE '/'||lang||CASE WHEN r.code='' THEN '/' ELSE agency.seo_category_path(r.code,lang) END END
 FROM (SELECT '' code,'/' source UNION ALL SELECT c,agency.seo_category_path(c,'tr') FROM unnest(ARRAY['hotel','holiday_home','yacht','tour','activity','flight','car','cruise','pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus']) a(c)) r CROSS JOIN unnest(ARRAY['tr','en','de','ru','fr','zh']) b(lang) ON CONFLICT DO NOTHING;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS tenant_seo_locales ON agency.tenants;
CREATE TRIGGER tenant_seo_locales AFTER INSERT ON agency.tenants FOR EACH ROW EXECUTE FUNCTION agency.ensure_tenant_seo_locales();

-- Preserve every former locale path, including generated paths changed by translations.
CREATE OR REPLACE FUNCTION agency.remember_seo_locale_path() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,agency,public AS $$
BEGIN
 IF NEW.path<>OLD.path THEN
  IF EXISTS(SELECT 1 FROM agency.seo_path_aliases a WHERE a.tenant_id=NEW.tenant_id AND a.path=NEW.path AND (a.resource_key,a.language_code)<>(NEW.resource_key,NEW.language_code)) THEN RAISE EXCEPTION 'SEO URL already reserved' USING ERRCODE='23505'; END IF;
  INSERT INTO agency.seo_path_aliases(tenant_id,path,resource_key,language_code) VALUES(OLD.tenant_id,OLD.path,OLD.resource_key,OLD.language_code) ON CONFLICT DO NOTHING;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS seo_locale_path_history ON agency.seo_locales;
CREATE TRIGGER seo_locale_path_history BEFORE UPDATE OF path ON agency.seo_locales FOR EACH ROW EXECUTE FUNCTION agency.remember_seo_locale_path();
CREATE OR REPLACE FUNCTION agency.delete_listing_seo_locales() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,agency,public AS $$
BEGIN DELETE FROM agency.seo_locales WHERE tenant_id=OLD.tenant_id AND resource_key='listing:'||OLD.listing_id::text; RETURN OLD; END $$;
DROP TRIGGER IF EXISTS delete_listing_seo_locales ON agency.listing_seo;
CREATE TRIGGER delete_listing_seo_locales AFTER DELETE ON agency.listing_seo FOR EACH ROW EXECUTE FUNCTION agency.delete_listing_seo_locales();

-- Derive the first foreign slug from actual translated content, then keep it stable.
CREATE OR REPLACE FUNCTION agency.refresh_translated_seo_path(p_tenant uuid,p_id uuid,p_lang text) RETURNS void LANGUAGE plpgsql SET search_path=pg_catalog,agency,public AS $$
DECLARE translated_title text; translated_description text; c text;
BEGIN
 IF p_lang NOT IN ('en','de','ru','fr','zh') THEN RETURN; END IF;
 SELECT l.category,coalesce(nullif((SELECT value FROM agency.translations WHERE tenant_id=p_tenant AND entity_id=p_id AND entity_type='listing' AND language_code=p_lang AND field_name='title'),''),l.metadata->'extra_metadata'->'translations'->p_lang->>'title'),coalesce(nullif((SELECT value FROM agency.translations WHERE tenant_id=p_tenant AND entity_id=p_id AND entity_type='listing' AND language_code=p_lang AND field_name='description'),''),l.metadata->'extra_metadata'->'translations'->p_lang->>'description') INTO c,translated_title,translated_description FROM agency.listings l WHERE l.tenant_id=p_tenant AND l.id=p_id;
 IF nullif(trim(translated_title),'') IS NULL OR nullif(trim(translated_description),'') IS NULL THEN RETURN; END IF;
 UPDATE agency.seo_locales SET path='/'||p_lang||agency.seo_category_path(c,p_lang)||'/'||agency.seo_slug(translated_title,p_id::text)||'-'||left(p_id::text,8),path_custom=true,updated_at=now() WHERE tenant_id=p_tenant AND resource_key='listing:'||p_id::text AND language_code=p_lang AND NOT path_custom;
END $$;
CREATE OR REPLACE FUNCTION agency.translated_seo_path_changed() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,agency,public AS $$
BEGIN IF NEW.entity_type='listing' AND NEW.field_name IN ('title','description') THEN PERFORM agency.refresh_translated_seo_path(NEW.tenant_id,NEW.entity_id,NEW.language_code); END IF; RETURN NEW; END $$;
DROP TRIGGER IF EXISTS translated_seo_path_changed ON agency.translations;
CREATE TRIGGER translated_seo_path_changed AFTER INSERT OR UPDATE OF value ON agency.translations FOR EACH ROW EXECUTE FUNCTION agency.translated_seo_path_changed();
DO $$ DECLARE r record; BEGIN FOR r IN SELECT l.tenant_id,l.id,v.lang FROM agency.listings l CROSS JOIN unnest(ARRAY['en','de','ru','fr','zh']) v(lang) LOOP PERFORM agency.refresh_translated_seo_path(r.tenant_id,r.id,r.lang); END LOOP; END $$;

CREATE OR REPLACE FUNCTION agency.seo_listing_data(p_tenant uuid,p_id uuid,p_lang text) RETURNS jsonb LANGUAGE sql STABLE SET search_path=pg_catalog,public,agency AS $$
 SELECT jsonb_build_object('id',l.id,'sourceTitle',l.title,'category',l.category,'locality',l.locality,'stableSlug',s.stable_slug,'title',coalesce(nullif(s.title,''),nullif(l.metadata->>'seo_title',''),l.title),'description',coalesce(nullif(s.description,''),nullif(l.metadata->>'seo_description',''),left(regexp_replace(l.description,'<[^>]+>',' ','g'),180)),'body',l.description,'noindex',s.noindex,'updatedAt',l.updated_at,'images',l.images,'metadata',l.metadata,'currency',trim(l.currency),'priceMinor',l.price_minor,'translated',coalesce(l.metadata->'extra_metadata'->'translations'->p_lang,'{}'::jsonb)||coalesce((SELECT jsonb_object_agg(field_name,value) FROM agency.translations WHERE tenant_id=p_tenant AND entity_id=l.id AND entity_type='listing' AND language_code=p_lang AND field_name IN ('title','description','seo_title','seo_description','seo_keywords') AND trim(value)<>''),'{}'::jsonb))
 FROM agency.listings l JOIN agency.listing_seo s ON s.listing_id=l.id AND s.tenant_id=l.tenant_id WHERE l.tenant_id=p_tenant AND l.id=p_id AND l.status='published'
 $$;

GRANT EXECUTE ON FUNCTION agency.seo_category_path(text,text), agency.seo_slug(text,text), agency.ensure_listing_seo_locales(), agency.ensure_page_seo_locales(), agency.ensure_tenant_seo_locales(), agency.remember_seo_locale_path(), agency.delete_listing_seo_locales(), agency.refresh_translated_seo_path(uuid,uuid,text), agency.translated_seo_path_changed(), agency.seo_listing_data(uuid,uuid,text) TO agency_app;
COMMIT;
