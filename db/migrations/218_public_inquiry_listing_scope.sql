-- An inquiry for a listing must stay in that listing's tenant. General
-- inquiries without a listing remain valid.
CREATE OR REPLACE FUNCTION agency.guard_public_inquiry_listing_scope()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  IF NEW.tenant_id IS NULL THEN
    RAISE EXCEPTION 'inquiry_tenant_required';
  END IF;
  IF NEW.listing_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM agency.listings l
    WHERE l.id=NEW.listing_id AND l.tenant_id=NEW.tenant_id
  ) THEN
    RAISE EXCEPTION 'inquiry_listing_scope';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS agency_public_inquiry_listing_scope ON agency.public_inquiries;
CREATE TRIGGER agency_public_inquiry_listing_scope
BEFORE INSERT OR UPDATE OF listing_id,tenant_id ON agency.public_inquiries
FOR EACH ROW EXECUTE FUNCTION agency.guard_public_inquiry_listing_scope();

REVOKE ALL ON FUNCTION agency.guard_public_inquiry_listing_scope() FROM PUBLIC;
