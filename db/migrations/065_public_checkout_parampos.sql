-- Public checkout and ParamPOS 3D Secure lifecycle.
ALTER TABLE agency.orders
  ADD COLUMN IF NOT EXISTS reservation_id uuid REFERENCES agency.reservations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS agency_orders_idempotency_idx
  ON agency.orders(tenant_id,idempotency_key)
  WHERE idempotency_key IS NOT NULL AND idempotency_key <> '';

CREATE TABLE IF NOT EXISTS agency.payment_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES agency.orders(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'parampos' CHECK(provider='parampos'),
  transaction_guid text NOT NULL DEFAULT '',
  md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'created' CHECK(status IN ('created','initiated','authorized','paid','failed','cancelled','expired')),
  amount_minor bigint NOT NULL CHECK(amount_minor >= 0),
  currency char(3) NOT NULL DEFAULT 'TRY',
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 minutes'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_payment_sessions_order_idx ON agency.payment_sessions(tenant_id,order_id,created_at DESC);
CREATE INDEX IF NOT EXISTS agency_payment_sessions_guid_idx ON agency.payment_sessions(transaction_guid) WHERE transaction_guid <> '';
GRANT SELECT,INSERT,UPDATE ON agency.payment_sessions TO agency_app;
