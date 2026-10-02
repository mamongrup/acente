BEGIN;
DO $$ DECLARE t uuid:=gen_random_uuid(); x uuid:=gen_random_uuid(); u uuid:=gen_random_uuid(); c uuid:=gen_random_uuid();
 l uuid:=gen_random_uuid(); f uuid; f2 uuid; claim uuid; reservation uuid; token text:=repeat('a',64); d jsonb;
BEGIN
 INSERT INTO agency.tenants(id,legal_name,brand_name,slug) VALUES(t,'Calendar test','Test',t::text),(x,'Other','Other',x::text);
 INSERT INTO agency.users(id,tenant_id,email,display_name,membership_type,password_hash) VALUES
 (u,t,'admin@calendar.example.test','Admin','admin',crypt('fixture-password',gen_salt('bf',4))),
 (c,t,'customer@calendar.example.test','Customer','customer',crypt('fixture-password',gen_salt('bf',4)));
 INSERT INTO agency.listings(id,tenant_id,code,category,title,price_minor) VALUES(l,t,'calendar-test','holiday_home','Calendar test',10000);
 f:=agency.save_external_calendar(t,u,l,'Source one','https://example.com/calendar.ics','Europe/Istanbul');
 BEGIN PERFORM agency.save_external_calendar(x,u,l,'Cross tenant','https://example.com/calendar.ics','Europe/Istanbul'); RAISE EXCEPTION 'scope_failed';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='scope_failed' THEN RAISE; END IF; END;
 BEGIN PERFORM agency.save_external_calendar(t,c,l,'Customer','https://example.com/calendar.ics','Europe/Istanbul'); RAISE EXCEPTION 'scope_failed';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM='scope_failed' THEN RAISE; END IF; END;
 INSERT INTO agency.availability(listing_id,day,units_total,units_available,closed) VALUES(l,current_date+11,1,1,false),(l,current_date+12,1,0,true);
 claim:=gen_random_uuid(); UPDATE agency.external_calendar_feeds SET claim_id=claim,claimed_at=now() WHERE id=f;
 IF agency.complete_external_calendar(x,f,claim,'[]','') THEN RAISE EXCEPTION 'worker scope leak'; END IF;
 PERFORM agency.complete_external_calendar(t,f,claim,jsonb_build_array(jsonb_build_object('key','fixture','start',current_date+10,'end',current_date+12)),'');
 IF NOT EXISTS(SELECT 1 FROM agency.effective_availability WHERE listing_id=l AND day=current_date+10 AND closed) THEN RAISE EXCEPTION 'missing virtual block'; END IF;
 IF NOT EXISTS(SELECT 1 FROM agency.availability WHERE listing_id=l AND day=current_date+11 AND NOT closed AND units_available=1) THEN RAISE EXCEPTION 'local inventory overwritten'; END IF;
 BEGIN INSERT INTO agency.reservations(tenant_id,listing_id,reference_code,check_in,check_out,status) VALUES(t,l,'blocked-'||t,current_date+10,current_date+11,'option'); RAISE EXCEPTION 'reservation_guard_failed';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'external_calendar_unavailable' THEN RAISE; END IF; END;
 INSERT INTO agency.reservations(tenant_id,listing_id,reference_code,check_in,check_out,status) VALUES(t,l,'allowed-'||t,current_date+12,current_date+14,'option') RETURNING id INTO reservation;
 claim:=gen_random_uuid();UPDATE agency.external_calendar_feeds SET claim_id=claim,claimed_at=now() WHERE id=f;
 PERFORM agency.complete_external_calendar(t,f,claim,'[]','Fixture network failure');
 IF NOT EXISTS(SELECT 1 FROM agency.external_calendar_blocks WHERE feed_id=f) THEN RAISE EXCEPTION 'network failure cleared blocks'; END IF;
 PERFORM agency.external_calendar_action(t,u,f,'remove');
 IF EXISTS(SELECT 1 FROM agency.effective_availability WHERE listing_id=l AND day=current_date+11 AND closed) THEN RAISE EXCEPTION 'feed block not removed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM agency.effective_availability WHERE listing_id=l AND day=current_date+12 AND closed) THEN RAISE EXCEPTION 'manual closure lost'; END IF;
 IF NOT agency.rotate_calendar_export(t,u,l,token) THEN RAISE EXCEPTION 'export refused'; END IF;
 d:=agency.calendar_export_data(token);
 IF jsonb_array_length(d->'events')<>1 OR d::text LIKE '%calendar.example.test%' THEN RAISE EXCEPTION 'export privacy failure'; END IF;
 PERFORM agency.rotate_calendar_export(t,u,l,repeat('b',64));
 IF agency.calendar_export_data(token) IS NOT NULL THEN RAISE EXCEPTION 'old token still works'; END IF;
 d:=agency.commerce_operations_data(t,u);
 IF jsonb_array_length(d->'feeds')<>1 OR d::text LIKE '%calendar.ics%' THEN RAISE EXCEPTION 'workspace secret leak'; END IF;
END $$;
ROLLBACK;
