-- Keep the channel ledger private while allowing a tenant-scoped listing
-- deletion to clean its dependent rows through a definer trigger.
CREATE OR REPLACE FUNCTION agency.cleanup_listing_channel_rows()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  DELETE FROM agency.channel_sync_outbox
  WHERE tenant_id=OLD.tenant_id AND listing_id=OLD.id;
  DELETE FROM agency.channel_product_maps
  WHERE tenant_id=OLD.tenant_id AND listing_id=OLD.id;
  RETURN OLD;
END $$;

DROP TRIGGER IF EXISTS agency_listing_channel_cleanup ON agency.listings;
CREATE TRIGGER agency_listing_channel_cleanup
BEFORE DELETE ON agency.listings FOR EACH ROW
EXECUTE FUNCTION agency.cleanup_listing_channel_rows();

REVOKE ALL ON FUNCTION agency.cleanup_listing_channel_rows() FROM PUBLIC;
