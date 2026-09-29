-- NEXUS kaynaklı ilan rezervasyonlarını güvenli ve tekrar denenebilir biçimde
-- merkezi platforma iletmek için yerel outbox.
CREATE TABLE IF NOT EXISTS agency.nexus_reservation_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL REFERENCES agency.reservations(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','processing','sent','failed')),
  attempts int NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  last_error text NOT NULL DEFAULT '',
  last_response text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  UNIQUE (reservation_id)
);

CREATE INDEX IF NOT EXISTS agency_nexus_reservation_delivery_due_idx
  ON agency.nexus_reservation_deliveries(status,next_attempt_at,created_at)
  WHERE status IN ('pending','failed');

CREATE OR REPLACE FUNCTION agency.enqueue_nexus_reservation_delivery()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,agency AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM agency.listings l
    WHERE l.id=NEW.listing_id
      AND l.tenant_id=NEW.tenant_id
      AND l.source='nexus'
      AND nullif(l.metadata->>'nexus_listing_id','') IS NOT NULL
  ) THEN
    INSERT INTO agency.nexus_reservation_deliveries(tenant_id,reservation_id)
    VALUES(NEW.tenant_id,NEW.id)
    ON CONFLICT(reservation_id) DO NOTHING;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS agency_reservation_nexus_outbox_trg ON agency.reservations;
CREATE TRIGGER agency_reservation_nexus_outbox_trg
AFTER INSERT ON agency.reservations
FOR EACH ROW EXECUTE FUNCTION agency.enqueue_nexus_reservation_delivery();

REVOKE ALL ON agency.nexus_reservation_deliveries FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE ON agency.nexus_reservation_deliveries TO agency_app;
