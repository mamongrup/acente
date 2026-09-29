-- A webhook receipt is not a booking when its reference is an old error body.
CREATE OR REPLACE FUNCTION agency.nexus_reservation_ready(p_tenant uuid, p_reservation uuid)
RETURNS boolean LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_source text;
  v_reply jsonb;
  v_reference text;
BEGIN
  SELECT l.source INTO v_source
  FROM agency.reservations r
  JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
  WHERE r.id=p_reservation AND r.tenant_id=p_tenant;
  IF NOT FOUND THEN RETURN false; END IF;
  IF v_source<>'nexus' THEN RETURN true; END IF;

  SELECT d.last_response::jsonb INTO v_reply
  FROM agency.nexus_reservation_deliveries d
  WHERE d.tenant_id=p_tenant AND d.reservation_id=p_reservation
    AND d.event_type='reservation.created' AND d.status='sent';
  IF NOT FOUND OR v_reply->'ok' IS DISTINCT FROM 'true'::jsonb
     OR v_reply->>'status' NOT IN ('processed','duplicate_ignored') THEN
    RETURN false;
  END IF;

  v_reference := btrim(coalesce(v_reply->>'booking_reference',''));
  IF v_reference='' OR lower(left(v_reference,6))='error:'
     OR left(v_reference,1) IN ('{','[') THEN
    RETURN false;
  END IF;
  RETURN true;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN false;
END $$;

REVOKE ALL ON FUNCTION agency.nexus_reservation_ready(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.nexus_reservation_ready(uuid,uuid) TO agency_app;
