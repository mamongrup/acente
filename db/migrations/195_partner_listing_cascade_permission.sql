-- PostgreSQL requires DELETE on the dependent table when a listing with
-- partner contract products is removed through its ON DELETE CASCADE FK.
GRANT DELETE ON agency.partner_contract_products TO agency_app;
