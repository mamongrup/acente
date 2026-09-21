CREATE TABLE IF NOT EXISTS agency.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES agency.categories(id) ON DELETE CASCADE, code text NOT NULL, name text NOT NULL, slug text NOT NULL,
  description text NOT NULL DEFAULT '', active boolean NOT NULL DEFAULT true, sort_order int NOT NULL DEFAULT 0,
  UNIQUE(tenant_id,slug), UNIQUE(tenant_id,code)
);
CREATE TABLE IF NOT EXISTS agency.category_fields (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), category_id uuid NOT NULL REFERENCES agency.categories(id) ON DELETE CASCADE,
  field_key text NOT NULL, label text NOT NULL, field_type text NOT NULL CHECK(field_type IN ('text','textarea','number','money','date','boolean','select','multiselect','media','location')),
  required boolean NOT NULL DEFAULT false, options jsonb NOT NULL DEFAULT '[]'::jsonb, sort_order int NOT NULL DEFAULT 0,
  UNIQUE(category_id,field_key)
);
CREATE TABLE IF NOT EXISTS agency.listing_field_values (
  listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  field_id uuid NOT NULL REFERENCES agency.category_fields(id) ON DELETE CASCADE,
  value jsonb NOT NULL DEFAULT 'null'::jsonb, PRIMARY KEY(listing_id,field_id)
);
CREATE TABLE IF NOT EXISTS agency.modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid REFERENCES agency.tenants(id) ON DELETE CASCADE,
  code text NOT NULL, name text NOT NULL, description text NOT NULL DEFAULT '', active boolean NOT NULL DEFAULT true,
  UNIQUE(tenant_id,code)
);
CREATE TABLE IF NOT EXISTS agency.supplier_modules (
  supplier_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  module_id uuid NOT NULL REFERENCES agency.modules(id) ON DELETE CASCADE,
  enabled boolean NOT NULL DEFAULT true, assigned_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(supplier_id,module_id)
);
CREATE TABLE IF NOT EXISTS agency.supplier_categories (
  supplier_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES agency.categories(id) ON DELETE CASCADE,
  approved boolean NOT NULL DEFAULT false, approved_at timestamptz, PRIMARY KEY(supplier_id,category_id)
);
CREATE INDEX IF NOT EXISTS agency_categories_tree_idx ON agency.categories(tenant_id,parent_id,active,sort_order);
CREATE INDEX IF NOT EXISTS agency_category_fields_order_idx ON agency.category_fields(category_id,sort_order);
CREATE INDEX IF NOT EXISTS agency_supplier_modules_idx ON agency.supplier_modules(supplier_id,enabled);
CREATE INDEX IF NOT EXISTS agency_supplier_categories_idx ON agency.supplier_categories(supplier_id,approved);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.categories,agency.category_fields,agency.listing_field_values,agency.modules,agency.supplier_modules,agency.supplier_categories TO agency_app;
