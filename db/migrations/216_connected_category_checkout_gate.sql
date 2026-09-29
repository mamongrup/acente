-- Connected categories without a central booking adapter may be displayed,
-- but they must not create a payable order before fulfillment is implemented.
CREATE OR REPLACE FUNCTION agency.guard_connected_category_order()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE v_source text; v_category text;
BEGIN
  IF NEW.status NOT IN ('pending','confirmed') THEN RETURN NEW; END IF;
  SELECT l.source,l.category INTO v_source,v_category
  FROM agency.reservations r
  JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
  WHERE r.id=NEW.reservation_id AND r.tenant_id=NEW.tenant_id;
  IF v_source='nexus' AND v_category NOT IN ('hotel','holiday_home','yacht') THEN
    RAISE EXCEPTION 'nexus_booking_unavailable';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS agency_connected_category_order_guard ON agency.orders;
CREATE TRIGGER agency_connected_category_order_guard
BEFORE INSERT OR UPDATE OF status,reservation_id,tenant_id ON agency.orders
FOR EACH ROW EXECUTE FUNCTION agency.guard_connected_category_order();

REVOKE ALL ON FUNCTION agency.guard_connected_category_order() FROM PUBLIC;
