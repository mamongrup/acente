CREATE TABLE IF NOT EXISTS agency.languages (
  code varchar(10) PRIMARY KEY,
  name text NOT NULL,
  native_name text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  is_default boolean NOT NULL DEFAULT false
);
INSERT INTO agency.languages(code,name,native_name,is_default) VALUES
  ('tr','Turkish','Türkçe',true),('en','English','English',false),('de','German','Deutsch',false),
  ('ru','Russian','Русский',false),('ar','Arabic','العربية',false),('fr','French','Français',false)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS agency.currencies (
  code char(3) PRIMARY KEY,
  name text NOT NULL,
  symbol text NOT NULL,
  rate numeric(18,8) NOT NULL DEFAULT 1,
  adjustment_percent numeric(8,4) NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO agency.currencies(code,name,symbol) VALUES
 ('TRY','Türk Lirası','₺'),('EUR','Euro','€'),('USD','US Dollar','$'),
 ('GBP','Pound Sterling','£'),('RUB','Russian Ruble','₽'),('AED','UAE Dirham','د.إ')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS agency.translations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  language_code varchar(10) NOT NULL REFERENCES agency.languages(code),
  field_name text NOT NULL,
  value text NOT NULL DEFAULT '',
  UNIQUE(tenant_id,entity_type,entity_id,language_code,field_name)
);
CREATE INDEX IF NOT EXISTS agency_translations_lookup_idx ON agency.translations(tenant_id,entity_type,entity_id,language_code);

CREATE TABLE IF NOT EXISTS agency.regions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES agency.regions(id) ON DELETE SET NULL,
  country_code char(2) NOT NULL DEFAULT 'TR',
  name text NOT NULL,
  slug text NOT NULL,
  description text NOT NULL DEFAULT '',
  latitude numeric(9,6), longitude numeric(9,6),
  seo_title text NOT NULL DEFAULT '', seo_description text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,slug)
);
CREATE INDEX IF NOT EXISTS agency_regions_tree_idx ON agency.regions(tenant_id,parent_id,active);
CREATE INDEX IF NOT EXISTS agency_regions_search_idx ON agency.regions USING gin(to_tsvector('simple',name||' '||description));
ALTER TABLE agency.listings ADD COLUMN IF NOT EXISTS region_id uuid REFERENCES agency.regions(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS agency_listings_region_idx ON agency.listings(tenant_id,region_id,status);
GRANT USAGE ON SCHEMA agency TO agency_app;
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.languages,agency.currencies,agency.translations,agency.regions TO agency_app;
