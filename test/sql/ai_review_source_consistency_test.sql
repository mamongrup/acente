BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); src text;
BEGIN
 INSERT INTO agency.tenants(id,legal_name,brand_name,slug) VALUES(t,'Review fixture','Review fixture','review-'||t::text);
 INSERT INTO agency.users(id,tenant_id,email,display_name,membership_type,active,password_hash) VALUES(u,t,u::text||'@fixture.invalid','Review fixture','admin',true,'invalid');
 INSERT INTO agency.listings(id,tenant_id,code,title,description,locality,category,price_minor,currency,status,source) VALUES(p,t,'review-'||p::text,'Review gulet','Fixture content','Gocek','yacht',100000,'TRY','draft','manual');
 SELECT title || E'\n' || description || E'\nKategori: ' || category || E'\nKonum: ' || locality || E'\nÖzellikler: ' || coalesce(metadata->'contract_fields','{}'::jsonb)::text INTO src FROM agency.listings WHERE id=p;
 IF agency.save_listing_review(t,u,p,src,'{"summary":"Fixture","findings":[]}','fixture','fixture')<>'saved' THEN RAISE EXCEPTION 'review not saved'; END IF;
 UPDATE agency.listings SET description='Changed' WHERE id=p;
 IF agency.save_listing_review(t,u,p,src,'{"summary":"Fixture","findings":[]}','fixture','fixture')<>'stale_source' THEN RAISE EXCEPTION 'stale review accepted'; END IF;
 IF (SELECT count(*) FROM agency.ai_listing_content_reviews WHERE tenant_id=t)<>1 THEN RAISE EXCEPTION 'stale result persisted'; END IF;
 RAISE NOTICE 'agency AI source consistency passed';
END $$;
ROLLBACK;
