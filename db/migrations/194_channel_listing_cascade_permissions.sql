-- The migration/runtime role owns listings. PostgreSQL's cascading delete
-- executes under that role, and listing removal must also remove its channel
-- mappings and pending deliveries. HTTP deletion remains tenant scoped.
DROP TRIGGER IF EXISTS agency_listing_channel_cleanup ON agency.listings;
DROP FUNCTION IF EXISTS agency.cleanup_listing_channel_rows();
GRANT DELETE ON agency.channel_product_maps,agency.channel_sync_outbox TO agency_app;
