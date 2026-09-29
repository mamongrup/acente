-- Keep legacy connected orders in unsupported categories away from payment.
-- The supported set must move together with a central booking adapter.
CREATE OR REPLACE FUNCTION agency.nexus_reservation_ready(p_tenant uuid, p_reservation uuid)
RETURNS boolean LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_source text;
  v_category text;
  v_reply jsonb;
  v_reference text;
  v_amount text;
  v_currency text;
  v_deadline text;
BEGIN
  SELECT l.source,l.category INTO v_source,v_category
  FROM agency.reservations r
  JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
  WHERE r.id=p_reservation AND r.tenant_id=p_tenant;
  IF NOT FOUND THEN RETURN false; END IF;
  IF v_source<>'nexus' THEN RETURN true; END IF;
  IF v_category NOT IN ('hotel','holiday_home','yacht') THEN RETURN false; END IF;

  SELECT d.last_response::jsonb INTO v_reply
  FROM agency.nexus_reservation_deliveries d
  WHERE d.tenant_id=p_tenant AND d.reservation_id=p_reservation
    AND d.event_type='reservation.created' AND d.status='sent';
  IF NOT FOUND OR v_reply->'ok' IS DISTINCT FROM 'true'::jsonb
     OR v_reply->>'status' NOT IN ('processed','duplicate_ignored') THEN
    RETURN false;
  END IF;
  v_reference := btrim(coalesce(v_reply->>'booking_reference',''));
  v_amount := v_reply->>'total_minor';
  v_currency := v_reply->>'currency';
  v_deadline := v_reply->>'expires_at';
  IF v_reference !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     OR coalesce(v_amount,'') !~ '^[1-9][0-9]{0,14}$'
     OR coalesce(v_currency,'') !~ '^[A-Z]{3}$'
     OR nullif(btrim(coalesce(v_deadline,'')),'') IS NULL
     OR v_deadline::timestamptz<=clock_timestamp() THEN
    RETURN false;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM agency.orders o
    WHERE o.tenant_id=p_tenant AND o.reservation_id=p_reservation
      AND o.total_minor=v_amount::bigint AND o.currency::text=v_currency
  );
EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format
  OR datetime_field_overflow THEN
  RETURN false;
END $$;

REVOKE ALL ON FUNCTION agency.nexus_reservation_ready(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.nexus_reservation_ready(uuid,uuid) TO agency_app;
