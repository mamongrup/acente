CREATE OR REPLACE FUNCTION agency.save_listing_review(p_tenant uuid,p_actor uuid,p_listing uuid,p_source text,p_review jsonb,p_provider text,p_model text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE actual text;
BEGIN
 IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'ai_access_denied'; END IF;
 SELECT title || E'\n' || description || E'\nKategori: ' || category || E'\nKonum: ' || locality || E'\nÖzellikler: ' || coalesce(metadata->'contract_fields','{}'::jsonb)::text INTO actual
 FROM agency.listings WHERE id=p_listing AND tenant_id=p_tenant FOR UPDATE;
 IF NOT FOUND OR actual IS DISTINCT FROM p_source THEN RETURN 'stale_source'; END IF;
 IF length(p_source)>12000 OR jsonb_typeof(p_review)<>'object' THEN RETURN 'invalid_review'; END IF;
 INSERT INTO agency.ai_listing_content_reviews(tenant_id,listing_id,actor_id,source_text,review,provider,model)
 VALUES(p_tenant,p_listing,p_actor,p_source,p_review,p_provider,p_model);
 RETURN 'saved';
END $$;
REVOKE ALL ON FUNCTION agency.save_listing_review(uuid,uuid,uuid,text,jsonb,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.save_listing_review(uuid,uuid,uuid,text,jsonb,text,text) TO agency_app;
