-- Enforce shared listing common requirements before a listing can be submitted
-- for review or published. Draft/paused/archived listings may remain incomplete.

CREATE OR REPLACE FUNCTION agency.validate_listing_common_contract(
  p_listing agency.listings
)
RETURNS TABLE(field_key text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT field_key
  FROM (
    VALUES
      ('code', nullif(trim(coalesce(p_listing.code, '')), '') IS NULL),
      ('category', nullif(trim(coalesce(p_listing.category, '')), '') IS NULL),
      ('title', nullif(trim(coalesce(p_listing.title, '')), '') IS NULL),
      ('description', nullif(trim(coalesce(p_listing.description, '')), '') IS NULL),
      ('locality', nullif(trim(coalesce(p_listing.locality, '')), '') IS NULL),
      ('currency', nullif(trim(coalesce(p_listing.currency::text, '')), '') IS NULL),
      ('price_minor', coalesce(p_listing.price_minor, 0) <= 0),
      ('source', nullif(trim(coalesce(p_listing.source, '')), '') IS NULL),
      ('owner_info', coalesce(jsonb_typeof(p_listing.owner_info), '') <> 'object'),
      ('cancellation_policy', coalesce(jsonb_typeof(p_listing.cancellation_policy), '') <> 'object'),
      ('media', coalesce(jsonb_array_length(coalesce(p_listing.images, '[]'::jsonb)), 0) = 0)
  ) AS required(field_key, missing)
  WHERE missing;
$$;

CREATE OR REPLACE FUNCTION agency.enforce_listing_contract_before_publish()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  missing text;
  missing_common text;
BEGIN
  IF NEW.status IN ('pending_review', 'published') THEN
    SELECT string_agg(field_key, ', ' ORDER BY field_key)
    INTO missing_common
    FROM agency.validate_listing_common_contract(NEW);

    SELECT string_agg(field_key, ', ' ORDER BY field_key)
    INTO missing
    FROM agency.validate_listing_contract(NEW.tenant_id, NEW.category, NEW.metadata);

    IF coalesce(missing_common, '') <> '' THEN
      RAISE EXCEPTION 'Listing common contract required fields missing: %', missing_common
        USING ERRCODE = '23514';
    END IF;

    IF coalesce(missing, '') <> '' THEN
      RAISE EXCEPTION 'Listing category contract required fields missing: %', missing
        USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS agency_listing_contract_publish_guard ON agency.listings;

CREATE TRIGGER agency_listing_contract_publish_guard
BEFORE INSERT OR UPDATE OF status, category, metadata, title, locality, description, price_minor, images, owner_info, cancellation_policy
ON agency.listings
FOR EACH ROW
EXECUTE FUNCTION agency.enforce_listing_contract_before_publish();

GRANT EXECUTE ON FUNCTION agency.validate_listing_common_contract(agency.listings),agency.enforce_listing_contract_before_publish() TO agency_app;
