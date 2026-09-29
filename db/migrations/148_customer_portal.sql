-- Customer-owned travel and commerce data. All reads and writes must use
-- both tenant_id and the authenticated user_id.
CREATE TABLE IF NOT EXISTS agency.customer_travelers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  full_name text NOT NULL CHECK (length(trim(full_name)) BETWEEN 2 AND 120),
  birth_date date,
  nationality char(2) NOT NULL DEFAULT 'TR',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS customer_travelers_owner_idx ON agency.customer_travelers(tenant_id,user_id,created_at DESC);

CREATE TABLE IF NOT EXISTS agency.customer_travel_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  reservation_id uuid REFERENCES agency.reservations(id) ON DELETE SET NULL,
  kind text NOT NULL CHECK(kind IN ('ticket','voucher','insurance','other')),
  title text NOT NULL CHECK(length(trim(title)) BETWEEN 2 AND 160),
  document_url text NOT NULL CHECK(length(document_url) BETWEEN 12 AND 2000 AND document_url ~ '^https://'),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS customer_documents_owner_idx ON agency.customer_travel_documents(tenant_id,user_id,created_at DESC);

CREATE TABLE IF NOT EXISTS agency.customer_billing_details (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  label text NOT NULL DEFAULT 'Fatura bilgileri',
  legal_name text NOT NULL CHECK(length(trim(legal_name)) BETWEEN 2 AND 160),
  tax_number text NOT NULL DEFAULT '',
  tax_office text NOT NULL DEFAULT '',
  address text NOT NULL DEFAULT '',
  country_code char(2) NOT NULL DEFAULT 'TR',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS customer_billing_owner_idx ON agency.customer_billing_details(tenant_id,user_id,created_at DESC);

CREATE TABLE IF NOT EXISTS agency.customer_reservation_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL REFERENCES agency.reservations(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK(kind IN ('change','cancel','refund')),
  message text NOT NULL CHECK(length(trim(message)) BETWEEN 10 AND 2000),
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','reviewing','approved','rejected','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS customer_reservation_requests_owner_idx ON agency.customer_reservation_requests(tenant_id,user_id,created_at DESC);

CREATE TABLE IF NOT EXISTS agency.customer_notification_preferences (
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  booking_email boolean NOT NULL DEFAULT true,
  price_email boolean NOT NULL DEFAULT true,
  marketing_email boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(tenant_id,user_id)
);
CREATE TABLE IF NOT EXISTS agency.customer_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  kind text NOT NULL,
  title text NOT NULL,
  message text NOT NULL DEFAULT '',
  target_url text NOT NULL DEFAULT '',
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS customer_notifications_owner_idx ON agency.customer_notifications(tenant_id,user_id,created_at DESC);

CREATE TABLE IF NOT EXISTS agency.customer_price_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  target_price_minor bigint NOT NULL CHECK(target_price_minor > 0),
  currency char(3) NOT NULL DEFAULT 'TRY',
  active boolean NOT NULL DEFAULT true,
  last_notified_price_minor bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,user_id,listing_id)
);
CREATE INDEX IF NOT EXISTS customer_price_alerts_listing_idx ON agency.customer_price_alerts(tenant_id,listing_id,active);

CREATE TABLE IF NOT EXISTS agency.customer_support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  subject text NOT NULL CHECK(length(trim(subject)) BETWEEN 3 AND 160),
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','responded','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS customer_support_owner_idx ON agency.customer_support_tickets(tenant_id,user_id,created_at DESC);
CREATE TABLE IF NOT EXISTS agency.customer_support_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES agency.customer_support_tickets(id) ON DELETE CASCADE,
  author_type text NOT NULL CHECK(author_type IN ('customer','staff')),
  message text NOT NULL CHECK(length(trim(message)) BETWEEN 2 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS customer_support_messages_ticket_idx ON agency.customer_support_messages(ticket_id,created_at);

CREATE OR REPLACE FUNCTION agency.notify_customer_price_drop() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status='published' AND NEW.price_minor > 0 AND NEW.price_minor < OLD.price_minor THEN
    INSERT INTO agency.customer_notifications(tenant_id,user_id,kind,title,message,target_url)
    SELECT a.tenant_id,a.user_id,'price_drop','Fiyat düştü',NEW.title || ' için takip ettiğiniz fiyat seviyesine ulaşıldı.','/urunler/' || NEW.id::text
    FROM agency.customer_price_alerts a
    WHERE a.tenant_id=NEW.tenant_id AND a.listing_id=NEW.id AND a.active
      AND a.currency=NEW.currency AND NEW.price_minor<=a.target_price_minor
      AND (a.last_notified_price_minor IS NULL OR NEW.price_minor<a.last_notified_price_minor);
    UPDATE agency.customer_price_alerts a SET last_notified_price_minor=NEW.price_minor
    WHERE a.tenant_id=NEW.tenant_id AND a.listing_id=NEW.id AND a.active
      AND a.currency=NEW.currency AND NEW.price_minor<=a.target_price_minor
      AND (a.last_notified_price_minor IS NULL OR NEW.price_minor<a.last_notified_price_minor);
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS notify_customer_price_drop ON agency.listings;
CREATE TRIGGER notify_customer_price_drop AFTER UPDATE OF price_minor ON agency.listings
FOR EACH ROW EXECUTE FUNCTION agency.notify_customer_price_drop();

GRANT SELECT,INSERT,UPDATE,DELETE ON agency.customer_travelers,agency.customer_travel_documents,
  agency.customer_billing_details,agency.customer_reservation_requests,agency.customer_notification_preferences,
  agency.customer_notifications,agency.customer_price_alerts,agency.customer_support_tickets,
  agency.customer_support_messages TO agency_app;
