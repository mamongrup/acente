CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS agency;
CREATE TABLE IF NOT EXISTS agency.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  legal_name text NOT NULL,
  brand_name text NOT NULL,
  slug text NOT NULL UNIQUE,
  nexus_connected boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  email text NOT NULL,
  display_name text NOT NULL,
  membership_type text NOT NULL CHECK (membership_type IN ('admin','sub_agency','supplier','staff','customer')),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,email)
);
CREATE INDEX IF NOT EXISTS agency_users_tenant_role_idx ON agency.users(tenant_id,membership_type,active);
