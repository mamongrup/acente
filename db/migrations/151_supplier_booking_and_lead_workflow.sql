-- Supplier decisions are requests for agency review. They do not silently
-- confirm or cancel a customer booking or trigger a payment.
CREATE TABLE IF NOT EXISTS agency.supplier_booking_decisions (
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  reservation_id uuid PRIMARY KEY REFERENCES agency.reservations(id) ON DELETE CASCADE,
  supplier_user_id uuid NOT NULL REFERENCES agency.users(id),
  decision text NOT NULL CHECK(decision IN ('accepted','rejected')),
  note text NOT NULL DEFAULT '',
  decided_at timestamptz NOT NULL DEFAULT now(),
  applied_at timestamptz,
  applied_by uuid REFERENCES agency.users(id),
  UNIQUE(tenant_id,reservation_id)
);
CREATE INDEX IF NOT EXISTS agency_supplier_decisions_review_idx ON agency.supplier_booking_decisions(tenant_id,applied_at,decided_at DESC);

CREATE TABLE IF NOT EXISTS agency.supplier_lead_replies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  contact_request_id uuid NOT NULL REFERENCES agency.contact_requests(id) ON DELETE CASCADE,
  supplier_user_id uuid NOT NULL REFERENCES agency.users(id),
  message text NOT NULL CHECK(length(trim(message)) BETWEEN 2 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_supplier_lead_replies_idx ON agency.supplier_lead_replies(tenant_id,contact_request_id,created_at DESC);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.supplier_booking_decisions,agency.supplier_lead_replies TO agency_app;
