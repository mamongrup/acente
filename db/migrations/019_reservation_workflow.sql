CREATE TABLE IF NOT EXISTS agency.reservation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), reservation_id uuid NOT NULL REFERENCES agency.reservations(id) ON DELETE CASCADE,
  from_status text, to_status text NOT NULL, actor_user_id uuid REFERENCES agency.users(id) ON DELETE SET NULL, note text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.reservation_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), reservation_id uuid NOT NULL REFERENCES agency.reservations(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL, deposit_minor bigint NOT NULL DEFAULT 0, status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','converted','expired','cancelled'))
);
CREATE TABLE IF NOT EXISTS agency.refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), payment_id uuid NOT NULL REFERENCES agency.payments(id) ON DELETE CASCADE,
  amount_minor bigint NOT NULL CHECK(amount_minor>0), reason text NOT NULL DEFAULT '', status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','processed','failed')), provider_reference text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_reservation_events_idx ON agency.reservation_events(reservation_id,created_at);
CREATE INDEX IF NOT EXISTS agency_reservation_options_expiry_idx ON agency.reservation_options(status,expires_at);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.reservation_events,agency.reservation_options,agency.refunds TO agency_app;
