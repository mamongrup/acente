-- Tenant deletion and test-fixture rollback must cascade through commercial
-- records under the application-owned schema. Admin HTTP tenant operations
-- remain separately authorized and scoped.
GRANT DELETE ON agency.sales_channels,agency.partner_sales_contracts,
  agency.partner_reservation_allocations TO agency_app;
