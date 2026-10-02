-- Local operational extension. Does not change the shared listing contract.
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='agency_calendar_listing_scope' AND conrelid='agency.listings'::regclass) THEN ALTER TABLE agency.listings ADD CONSTRAINT agency_calendar_listing_scope UNIQUE(tenant_id,id); END IF; END $$;
CREATE TABLE IF NOT EXISTS agency.external_calendar_feeds (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL,
 listing_id uuid NOT NULL, label text NOT NULL CHECK(length(label) BETWEEN 1 AND 100),
 url text NOT NULL CHECK(url ~ '^https://[^/[:space:]@]+/'),
 active boolean NOT NULL DEFAULT true, timezone text NOT NULL DEFAULT 'Europe/Istanbul',
 next_sync_at timestamptz NOT NULL DEFAULT now(), last_synced_at timestamptz,
 last_error text NOT NULL DEFAULT '', failure_count int NOT NULL DEFAULT 0,
 claimed_at timestamptz, claim_id uuid, event_count int NOT NULL DEFAULT 0,
 FOREIGN KEY(tenant_id,listing_id) REFERENCES agency.listings(tenant_id,id) ON DELETE CASCADE,
 UNIQUE(tenant_id,listing_id,label)
);
CREATE TABLE IF NOT EXISTS agency.external_calendar_blocks (
 feed_id uuid NOT NULL REFERENCES agency.external_calendar_feeds(id) ON DELETE CASCADE,
 event_key text NOT NULL, starts_on date NOT NULL, ends_on date NOT NULL CHECK(ends_on>starts_on),
 PRIMARY KEY(feed_id,event_key)
);
CREATE TABLE IF NOT EXISTS agency.calendar_export_keys (
 tenant_id uuid NOT NULL, listing_id uuid NOT NULL, token_hash text NOT NULL UNIQUE,
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(tenant_id,listing_id),
 FOREIGN KEY(tenant_id,listing_id) REFERENCES agency.listings(tenant_id,id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS external_calendar_due ON agency.external_calendar_feeds(next_sync_at) WHERE active;
CREATE INDEX IF NOT EXISTS external_calendar_dates ON agency.external_calendar_blocks(starts_on,ends_on);

CREATE OR REPLACE VIEW agency.effective_availability AS
WITH blocked AS (
 SELECT DISTINCT f.listing_id,d::date AS day
 FROM agency.external_calendar_feeds f JOIN agency.external_calendar_blocks b ON b.feed_id=f.id
 CROSS JOIN LATERAL generate_series(greatest(b.starts_on,current_date),least(b.ends_on-1,current_date+730),interval '1 day') d
 WHERE f.active
)
SELECT a.id,a.listing_id,a.day,a.units_total,
 CASE WHEN b.listing_id IS NULL THEN a.units_available ELSE 0 END AS units_available,
 a.closed OR b.listing_id IS NOT NULL AS closed
FROM agency.availability a LEFT JOIN blocked b USING(listing_id,day)
UNION ALL
SELECT NULL::uuid,b.listing_id,b.day,1,0,true FROM blocked b
WHERE NOT EXISTS(SELECT 1 FROM agency.availability a WHERE a.listing_id=b.listing_id AND a.day=b.day);

CREATE OR REPLACE FUNCTION agency.save_external_calendar(p_tenant uuid,p_actor uuid,p_listing uuid,p_label text,p_url text,p_timezone text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
 IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'calendar_access_denied'; END IF;
 IF NOT EXISTS(SELECT 1 FROM agency.listings WHERE tenant_id=p_tenant AND id=p_listing
   AND source<>'nexus' AND category IN ('holiday_home','yacht')) THEN RAISE EXCEPTION 'calendar_listing_unavailable'; END IF;
 IF p_url !~ '^https://[^/[:space:]@]+/' OR length(p_url)>2048
  OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_timezone) THEN RAISE EXCEPTION 'calendar_invalid_input'; END IF;
 IF (SELECT count(*) FROM agency.external_calendar_feeds WHERE tenant_id=p_tenant AND listing_id=p_listing AND active)>=8
  AND NOT EXISTS(SELECT 1 FROM agency.external_calendar_feeds WHERE tenant_id=p_tenant AND listing_id=p_listing AND label=p_label) THEN RAISE EXCEPTION 'calendar_feed_limit'; END IF;
 INSERT INTO agency.external_calendar_feeds(tenant_id,listing_id,label,url,timezone)
 VALUES(p_tenant,p_listing,p_label,p_url,p_timezone)
 ON CONFLICT(tenant_id,listing_id,label) DO UPDATE SET url=excluded.url,timezone=excluded.timezone,
 active=true,next_sync_at=now(),claim_id=NULL,claimed_at=NULL,last_error='' RETURNING id INTO v_id;
 RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.external_calendar_action(p_tenant uuid,p_actor uuid,p_feed uuid,p_action text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'calendar_access_denied'; END IF;
 IF p_action='sync' THEN
  UPDATE agency.external_calendar_feeds SET next_sync_at=now() WHERE tenant_id=p_tenant AND id=p_feed AND active;
 ELSIF p_action='remove' THEN
  UPDATE agency.external_calendar_feeds SET active=false,claim_id=NULL,claimed_at=NULL WHERE tenant_id=p_tenant AND id=p_feed;
 ELSE RAISE EXCEPTION 'calendar_invalid_action'; END IF;
 RETURN FOUND;
END $$;

CREATE OR REPLACE FUNCTION agency.claim_external_calendars() RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
 WITH due AS (SELECT id FROM agency.external_calendar_feeds WHERE active AND next_sync_at<=now()
  AND (claimed_at IS NULL OR claimed_at<now()-interval '5 minutes') ORDER BY next_sync_at LIMIT 10 FOR UPDATE SKIP LOCKED),
 claimed AS (UPDATE agency.external_calendar_feeds f SET claimed_at=now(),claim_id=gen_random_uuid()
 FROM due WHERE f.id=due.id RETURNING f.*)
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'tenant_id',tenant_id,'url',url,'timezone',timezone,'claim',claim_id)), '[]'::jsonb) FROM claimed
$$;

CREATE OR REPLACE FUNCTION agency.complete_external_calendar(p_tenant uuid,p_feed uuid,p_claim uuid,p_events jsonb,p_error text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE f agency.external_calendar_feeds%ROWTYPE;
BEGIN
 SELECT * INTO f FROM agency.external_calendar_feeds WHERE id=p_feed AND tenant_id=p_tenant
  AND active AND claim_id=p_claim FOR UPDATE;
 IF NOT FOUND THEN RETURN false; END IF;
 IF coalesce(p_error,'')<>'' THEN
  UPDATE agency.external_calendar_feeds SET last_error=left(p_error,300),failure_count=least(failure_count+1,10),
   next_sync_at=now()+least(interval '6 hours',interval '5 minutes'*power(2,least(failure_count,6))),
   claim_id=NULL,claimed_at=NULL WHERE id=f.id;
  RETURN true; -- Keep the last valid blocks on network/parser failure.
 END IF;
 IF jsonb_typeof(p_events)<>'array' OR jsonb_array_length(p_events)>5000 THEN RAISE EXCEPTION 'calendar_invalid_events'; END IF;
 PERFORM 1 FROM agency.listings WHERE id=f.listing_id AND tenant_id=p_tenant FOR UPDATE;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_events) e WHERE length(e->>'key') NOT BETWEEN 1 AND 300
  OR (e->>'start')::date IS NULL OR (e->>'end')::date IS NULL
  OR (e->>'end')::date<=(e->>'start')::date OR (e->>'end')::date-(e->>'start')::date>730) THEN RAISE EXCEPTION 'calendar_invalid_events'; END IF;
 DELETE FROM agency.external_calendar_blocks WHERE feed_id=f.id;
 INSERT INTO agency.external_calendar_blocks SELECT f.id,e->>'key',(e->>'start')::date,(e->>'end')::date
 FROM jsonb_array_elements(p_events) e;
 UPDATE agency.external_calendar_feeds SET last_synced_at=now(),next_sync_at=now()+interval '15 minutes',
  last_error='',failure_count=0,event_count=jsonb_array_length(p_events),claim_id=NULL,claimed_at=NULL WHERE id=f.id;
 RETURN true;
END $$;

CREATE OR REPLACE FUNCTION agency.guard_external_calendar_reservation() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NEW.status NOT IN ('option','confirmed') OR NEW.listing_id IS NULL THEN RETURN NEW; END IF;
 -- Never invalidate an already accepted booking because a late external feed conflicts.
 IF TG_OP='UPDATE' AND OLD.status IN ('option','confirmed') AND NEW.listing_id=OLD.listing_id
  AND NEW.check_in=OLD.check_in AND NEW.check_out=OLD.check_out THEN RETURN NEW; END IF;
 PERFORM 1 FROM agency.listings WHERE id=NEW.listing_id AND tenant_id=NEW.tenant_id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM agency.external_calendar_feeds f JOIN agency.external_calendar_blocks b ON b.feed_id=f.id
  WHERE f.tenant_id=NEW.tenant_id AND f.listing_id=NEW.listing_id AND f.active
  AND b.starts_on<NEW.check_out AND b.ends_on>NEW.check_in) THEN RAISE EXCEPTION 'external_calendar_unavailable'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS external_calendar_reservation_guard ON agency.reservations;
CREATE TRIGGER external_calendar_reservation_guard BEFORE INSERT OR UPDATE OF listing_id,check_in,check_out,status
ON agency.reservations FOR EACH ROW EXECUTE FUNCTION agency.guard_external_calendar_reservation();

CREATE OR REPLACE FUNCTION agency.rotate_calendar_export(p_tenant uuid,p_actor uuid,p_listing uuid,p_token text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'calendar_access_denied'; END IF;
 IF p_token !~ '^[a-f0-9]{64}$' OR NOT EXISTS(SELECT 1 FROM agency.listings WHERE tenant_id=p_tenant
  AND id=p_listing AND source<>'nexus' AND category IN ('holiday_home','yacht')) THEN RETURN false; END IF;
 INSERT INTO agency.calendar_export_keys(tenant_id,listing_id,token_hash)
 VALUES(p_tenant,p_listing,encode(public.digest(p_token,'sha256'),'hex'))
 ON CONFLICT(tenant_id,listing_id) DO UPDATE SET token_hash=excluded.token_hash,created_at=now();
 RETURN true;
END $$;

CREATE OR REPLACE FUNCTION agency.calendar_export_data(p_token text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object('listing',k.listing_id,'events',coalesce((SELECT jsonb_agg(jsonb_build_object(
  'key',r.id,'start',r.check_in,'end',r.check_out)) FROM agency.reservations r WHERE r.tenant_id=k.tenant_id
  AND r.listing_id=k.listing_id AND r.status IN ('option','confirmed','completed') AND r.check_out>=current_date
  AND r.check_in IS NOT NULL AND r.check_out>r.check_in),'[]'::jsonb))
 FROM agency.calendar_export_keys k JOIN agency.listings l ON l.id=k.listing_id AND l.tenant_id=k.tenant_id
 WHERE k.token_hash=encode(public.digest(p_token,'sha256'),'hex') AND p_token ~ '^[a-f0-9]{64}$' AND l.source<>'nexus'
$$;

REVOKE ALL ON agency.external_calendar_feeds,agency.external_calendar_blocks,agency.calendar_export_keys FROM PUBLIC;
GRANT SELECT ON agency.external_calendar_feeds,agency.external_calendar_blocks,agency.calendar_export_keys,agency.effective_availability TO agency_app;
REVOKE ALL ON FUNCTION agency.save_external_calendar(uuid,uuid,uuid,text,text,text),agency.external_calendar_action(uuid,uuid,uuid,text),agency.claim_external_calendars(),agency.complete_external_calendar(uuid,uuid,uuid,jsonb,text),agency.rotate_calendar_export(uuid,uuid,uuid,text),agency.calendar_export_data(text),agency.guard_external_calendar_reservation() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.save_external_calendar(uuid,uuid,uuid,text,text,text),agency.external_calendar_action(uuid,uuid,uuid,text),agency.claim_external_calendars(),agency.complete_external_calendar(uuid,uuid,uuid,jsonb,text),agency.rotate_calendar_export(uuid,uuid,uuid,text),agency.calendar_export_data(text),agency.guard_external_calendar_reservation() TO agency_app;
