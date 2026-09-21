-- A payment session may be submitted more than once by a browser retry.
-- Keep one active ParamPOS attempt per order while preserving paid history.
CREATE UNIQUE INDEX IF NOT EXISTS agency_payments_active_order_idx
  ON agency.payments(order_id, provider)
  WHERE status IN ('pending', 'authorized');

GRANT SELECT, INSERT, UPDATE ON agency.payments TO agency_app;
