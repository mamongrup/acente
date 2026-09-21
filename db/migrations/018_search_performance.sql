CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS agency_listings_title_trgm_idx ON agency.listings USING gin(title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS agency_listings_locality_trgm_idx ON agency.listings USING gin(locality gin_trgm_ops);
CREATE INDEX IF NOT EXISTS agency_listings_code_idx ON agency.listings(tenant_id,code);
CREATE INDEX IF NOT EXISTS agency_categories_name_trgm_idx ON agency.categories USING gin(name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS agency_regions_name_trgm_idx ON agency.regions USING gin(name gin_trgm_ops);
