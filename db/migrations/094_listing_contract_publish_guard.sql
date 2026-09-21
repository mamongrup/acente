-- Enforce listing contract validation before review/publish states.
-- Draft/paused/archive states can keep incomplete data, but listings cannot be
-- submitted or published with missing required category contract fields.

CREATE OR REPLACE FUNCTION agency.enforce_listing_contract_before_publish()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  missing text;
BEGIN
  IF NEW.status IN ('pending_review', 'published') THEN
    SELECT string_agg(field_key, ', ' ORDER BY field_key)
    INTO missing
    FROM agency.validate_listing_contract(NEW.tenant_id, NEW.category, NEW.metadata);

    IF coalesce(missing, '') <> '' THEN
      RAISE EXCEPTION 'Listing contract required fields missing: %', missing
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS agency_listing_contract_publish_guard ON agency.listings;

CREATE TRIGGER agency_listing_contract_publish_guard
BEFORE INSERT OR UPDATE OF status, category, metadata
ON agency.listings
FOR EACH ROW
EXECUTE FUNCTION agency.enforce_listing_contract_before_publish();

GRANT EXECUTE ON FUNCTION agency.enforce_listing_contract_before_publish() TO agency_app;
