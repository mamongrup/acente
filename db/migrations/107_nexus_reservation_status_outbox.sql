-- Queue NEXUS reservation lifecycle events separately. A reservation create
-- event and later status changes must not block each other with one unique row.
ALTER TABLE agency.nexus_reservation_deliveries
  ADD COLUMN IF NOT EXISTS event_type text NOT NULL DEFAULT 'reservation.created',
  ADD COLUMN IF NOT EXISTS reservation_status text NOT NULL DEFAULT '';

ALTER TABLE agency.nexus_reservation_deliveries
  DROP CONSTRAINT IF EXISTS nexus_reservation_deliveries_reservation_id_key;

ALTER TABLE agency.nexus_reservation_deliveries
  DROP CONSTRAINT IF EXISTS agency_nexus_reservation_deliveries_event_type_check;

ALTER TABLE agency.nexus_reservation_deliveries
  ADD CONSTRAINT agency_nexus_reservation_deliveries_event_type_check
  CHECK (event_type IN ('reservation.created','reservation.status_changed'));

CREATE UNIQUE INDEX IF NOT EXISTS agency_nexus_reservation_delivery_event_uidx
  ON agency.nexus_reservation_deliveries(reservation_id,event_type);

CREATE OR REPLACE FUNCTION agency.enqueue_nexus_reservation_delivery()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,agency AS $$
DECLARE
  target_event text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    target_event := 'reservation.created';
  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    target_event := 'reservation.status_changed';
  ELSE
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM agency.listings l
    WHERE l.id=NEW.listing_id
      AND l.tenant_id=NEW.tenant_id
      AND l.source='nexus'
      AND nullif(l.metadata->>'nexus_listing_id','') IS NOT NULL
  ) THEN
    INSERT INTO agency.nexus_reservation_deliveries(
      tenant_id,reservation_id,event_type,reservation_status,status,
      attempts,next_attempt_at,last_error,last_response,started_at,sent_at,updated_at
    )
    VALUES(
      NEW.tenant_id,NEW.id,target_event,NEW.status,'pending',
      0,now(),'','',NULL,NULL,now()
    )
    ON CONFLICT(reservation_id,event_type) DO UPDATE SET
      reservation_status=excluded.reservation_status,
      status='pending',
      attempts=0,
      next_attempt_at=now(),
      last_error='',
      last_response='',
      started_at=NULL,
      sent_at=NULL,
      updated_at=now();
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS agency_reservation_nexus_outbox_trg ON agency.reservations;
CREATE TRIGGER agency_reservation_nexus_outbox_trg
AFTER INSERT OR UPDATE OF status ON agency.reservations
FOR EACH ROW EXECUTE FUNCTION agency.enqueue_nexus_reservation_delivery();

GRANT SELECT, INSERT, UPDATE ON agency.nexus_reservation_deliveries TO agency_app;
