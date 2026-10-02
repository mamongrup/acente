BEGIN;
-- Presentation-only SEO records; canonical listing contract is unchanged.
CREATE TABLE IF NOT EXISTS agency.listing_seo (
 tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
 listing_id uuid PRIMARY KEY REFERENCES agency.listings(id) ON DELETE CASCADE,
 stable_slug text NOT NULL, title text NOT NULL DEFAULT '', description text NOT NULL DEFAULT '', noindex boolean NOT NULL DEFAULT false,
 updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,stable_slug)
);
GRANT SELECT,INSERT,UPDATE ON agency.listing_seo TO agency_app;
CREATE OR REPLACE FUNCTION agency.ensure_listing_seo() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public,agency AS $$ DECLARE slug text; BEGIN
 IF EXISTS(SELECT 1 FROM agency.listing_seo WHERE listing_id=NEW.id) THEN RETURN NEW; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(NEW.tenant_id::text,247));
 slug:=regexp_replace(regexp_replace(translate(lower(translate(NEW.title,'ÇĞİIÖŞÜ','CGIIOSU')),'çğıöşü','cgiosu'),'[^a-z0-9]+','-','g'),'(^-+|-+$)','','g');
 IF slug='' THEN slug:=NEW.id::text; END IF;
 IF EXISTS(SELECT 1 FROM agency.listing_seo WHERE tenant_id=NEW.tenant_id AND stable_slug=slug AND listing_id<>NEW.id) THEN slug:=slug||'-'||left(NEW.id::text,8); END IF;
 INSERT INTO agency.listing_seo(tenant_id,listing_id,stable_slug) VALUES(NEW.tenant_id,NEW.id,slug) ON CONFLICT(listing_id) DO NOTHING;
 RETURN NEW; END $$;
DROP TRIGGER IF EXISTS listing_seo_create ON agency.listings;
CREATE TRIGGER listing_seo_create AFTER INSERT OR UPDATE OF title ON agency.listings FOR EACH ROW EXECUTE FUNCTION agency.ensure_listing_seo();
-- Backfill only SEO rows; existing listings and publication validations stay untouched.
WITH base AS (SELECT id,tenant_id,coalesce(nullif(regexp_replace(regexp_replace(translate(lower(translate(title,'ÇĞİIÖŞÜ','CGIIOSU')),'çğıöşü','cgiosu'),'[^a-z0-9]+','-','g'),'(^-+|-+$)','','g'),''),id::text) slug FROM agency.listings), ranked AS (SELECT *,row_number() OVER(PARTITION BY tenant_id,slug ORDER BY id) n FROM base)
INSERT INTO agency.listing_seo(tenant_id,listing_id,stable_slug) SELECT tenant_id,id,CASE WHEN n=1 THEN slug ELSE slug||'-'||left(id::text,8) END FROM ranked ON CONFLICT(listing_id) DO NOTHING;
CREATE OR REPLACE FUNCTION agency.seo_listing_data(p_tenant uuid,p_id uuid,p_lang text) RETURNS jsonb LANGUAGE sql STABLE SET search_path=pg_catalog,public,agency AS $$
 SELECT jsonb_build_object('id',l.id,'sourceTitle',l.title,'category',l.category,'locality',l.locality,'stableSlug',s.stable_slug,'title',coalesce(nullif(s.title,''),nullif(l.metadata->>'seo_title',''),l.title),'description',coalesce(nullif(s.description,''),nullif(l.metadata->>'seo_description',''),left(regexp_replace(l.description,'<[^>]+>',' ','g'),180)),'body',l.description,'noindex',s.noindex,'updatedAt',l.updated_at,'images',l.images,'metadata',l.metadata,'currency',trim(l.currency),'priceMinor',l.price_minor,'translated',coalesce(l.metadata->'extra_metadata'->'translations'->p_lang,'{}'::jsonb)||coalesce((SELECT jsonb_object_agg(field_name,value) FROM agency.translations WHERE tenant_id=p_tenant AND entity_id=l.id AND entity_type='listing' AND language_code=p_lang AND field_name IN ('title','description','seo_title','seo_description','seo_keywords') AND trim(value)<>''),'{}'::jsonb))
 FROM agency.listings l JOIN agency.listing_seo s ON s.listing_id=l.id AND s.tenant_id=l.tenant_id WHERE l.tenant_id=p_tenant AND l.id=p_id AND l.status='published'
 $$;
GRANT EXECUTE ON FUNCTION agency.ensure_listing_seo(),agency.seo_listing_data(uuid,uuid,text) TO agency_app;
COMMIT;
