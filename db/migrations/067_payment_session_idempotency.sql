-- Repeating the checkout request must reuse the active payment session.
CREATE UNIQUE INDEX IF NOT EXISTS agency_payment_sessions_active_order_idx
  ON agency.payment_sessions(order_id)
  WHERE status IN ('created', 'initiated');
