CREATE TABLE IF NOT EXISTS agency.currency_update_schedules (
  tenant_id uuid PRIMARY KEY REFERENCES agency.tenants(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'tcmb', endpoint text NOT NULL DEFAULT '',
  first_run_at time NOT NULL DEFAULT '09:00', second_run_at time NOT NULL DEFAULT '16:00', timezone text NOT NULL DEFAULT 'Europe/Istanbul',
  active boolean NOT NULL DEFAULT true, last_run_at timestamptz, last_status text NOT NULL DEFAULT 'never', last_error text NOT NULL DEFAULT ''
);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.currency_update_schedules TO nexus_owner;
