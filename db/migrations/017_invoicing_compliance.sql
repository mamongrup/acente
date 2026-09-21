CREATE TABLE IF NOT EXISTS agency.billing_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  owner_type text NOT NULL, owner_id uuid NOT NULL, legal_name text NOT NULL, tax_number text NOT NULL DEFAULT '', tax_office text NOT NULL DEFAULT '', address text NOT NULL DEFAULT '', country_code char(2) NOT NULL DEFAULT 'TR', UNIQUE(tenant_id,owner_type,owner_id)
);
CREATE TABLE IF NOT EXISTS agency.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE, order_id uuid REFERENCES agency.orders(id) ON DELETE SET NULL,
  billing_profile_id uuid REFERENCES agency.billing_profiles(id) ON DELETE SET NULL, invoice_type text NOT NULL CHECK(invoice_type IN ('e_invoice','e_archive','receipt')), number text NOT NULL, status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','queued','sent','cancelled','failed')),
  currency char(3) NOT NULL DEFAULT 'TRY', subtotal_minor bigint NOT NULL DEFAULT 0, tax_minor bigint NOT NULL DEFAULT 0, total_minor bigint NOT NULL DEFAULT 0, issued_at timestamptz, provider_reference text, UNIQUE(tenant_id,number)
);
CREATE TABLE IF NOT EXISTS agency.invoice_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), invoice_id uuid NOT NULL REFERENCES agency.invoices(id) ON DELETE CASCADE, description text NOT NULL, quantity numeric(12,3) NOT NULL DEFAULT 1, unit_minor bigint NOT NULL DEFAULT 0, tax_rate numeric(6,3) NOT NULL DEFAULT 20
);
CREATE INDEX IF NOT EXISTS agency_invoices_status_idx ON agency.invoices(tenant_id,status,issued_at DESC);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.billing_profiles,agency.invoices,agency.invoice_items TO agency_app;
