-- The local application role owns the schema and executes SECURITY DEFINER
-- functions itself. Restore the rights those functions need after migration 177.
-- HTTP routes still restrict access by session and tenant; a separate runtime
-- role and database RLS are required before treating SQL privileges as isolation.
GRANT SELECT,INSERT,UPDATE ON agency.sales_channels,agency.channel_product_maps,
  agency.partner_sales_contracts,agency.partner_contract_products TO agency_app;
GRANT SELECT,INSERT,UPDATE ON agency.channel_sync_outbox,
  agency.partner_reservation_allocations TO agency_app;
