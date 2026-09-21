CREATE TABLE IF NOT EXISTS agency.conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  subject text NOT NULL DEFAULT '', channel text NOT NULL DEFAULT 'web' CHECK(channel IN ('web','whatsapp','email','phone')), status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','pending','closed')),
  customer_id uuid REFERENCES agency.customers(id) ON DELETE SET NULL, assigned_user_id uuid REFERENCES agency.users(id) ON DELETE SET NULL, created_at timestamptz NOT NULL DEFAULT now(), closed_at timestamptz
);
CREATE TABLE IF NOT EXISTS agency.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), conversation_id uuid NOT NULL REFERENCES agency.conversations(id) ON DELETE CASCADE, sender_user_id uuid REFERENCES agency.users(id) ON DELETE SET NULL,
  sender_name text NOT NULL DEFAULT '', body text NOT NULL, direction text NOT NULL CHECK(direction IN ('inbound','outbound')), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.contact_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE, listing_id uuid REFERENCES agency.listings(id) ON DELETE SET NULL,
  name text NOT NULL, email text NOT NULL DEFAULT '', phone text NOT NULL DEFAULT '', message text NOT NULL DEFAULT '', preferred_channel text NOT NULL DEFAULT 'email', status text NOT NULL DEFAULT 'new' CHECK(status IN ('new','in_progress','answered','closed')), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_conversations_status_idx ON agency.conversations(tenant_id,status,created_at DESC);
CREATE INDEX IF NOT EXISTS agency_messages_conversation_idx ON agency.messages(conversation_id,created_at);
CREATE INDEX IF NOT EXISTS agency_contact_requests_idx ON agency.contact_requests(tenant_id,status,created_at DESC);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.conversations,agency.messages,agency.contact_requests TO agency_app;
