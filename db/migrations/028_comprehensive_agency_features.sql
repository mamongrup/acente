-- 028_comprehensive_agency_features.sql
-- Genişletilmiş seyahat acentesi modülleri: Popuplar, Bannerlar, 301/404, IP Kara Liste, Teklifler, Filtreli Sayfalar ve İlan Detay Alanları

ALTER TABLE agency.listings ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE agency.listings ADD COLUMN IF NOT EXISTS images jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE agency.listings ADD COLUMN IF NOT EXISTS amenities jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE agency.listings ADD COLUMN IF NOT EXISTS owner_info jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE agency.listings ADD COLUMN IF NOT EXISTS cancellation_policy jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Popuplar (Duyuru, Kampanya, Çerez İzni, Lead)
CREATE TABLE IF NOT EXISTS agency.popups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  title text NOT NULL,
  kind text NOT NULL CHECK(kind IN ('announcement','campaign','cookie','lead')),
  content text NOT NULL DEFAULT '',
  image_url text NOT NULL DEFAULT '',
  button_text text NOT NULL DEFAULT '',
  button_link text NOT NULL DEFAULT '',
  delay_seconds int NOT NULL DEFAULT 3,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_popups_active_idx ON agency.popups(tenant_id, active);

-- Reklam & Banner Alanları
CREATE TABLE IF NOT EXISTS agency.banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  title text NOT NULL,
  position text NOT NULL CHECK(position IN ('header_top','listing_top','sidebar','footer','in_feed')),
  image_url text NOT NULL,
  link_url text NOT NULL DEFAULT '#',
  target text NOT NULL DEFAULT '_blank',
  sort_order int NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_banners_pos_idx ON agency.banners(tenant_id, position, active);

-- 301/302 Yönlendirmeleri ve Kırık Link Yönetimi
CREATE TABLE IF NOT EXISTS agency.redirects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  source_path text NOT NULL,
  target_path text NOT NULL,
  status_code int NOT NULL DEFAULT 301 CHECK(status_code IN (301,302)),
  hit_count int NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, source_path)
);
CREATE INDEX IF NOT EXISTS agency_redirects_lookup_idx ON agency.redirects(tenant_id, source_path, active);

-- IP Kara Liste (Spam, Yorum & Güvenlik)
CREATE TABLE IF NOT EXISTS agency.ip_blacklist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  ip_address text NOT NULL,
  reason text NOT NULL DEFAULT '',
  blocked_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, ip_address)
);
CREATE INDEX IF NOT EXISTS agency_ip_blacklist_idx ON agency.ip_blacklist(tenant_id, ip_address);

-- Teklifler & Rezervasyon Öncesi Formlar (PDF & WhatsApp Paylaşımı)
CREATE TABLE IF NOT EXISTS agency.offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  reference_code text NOT NULL UNIQUE,
  customer_id uuid REFERENCES agency.customers(id) ON DELETE SET NULL,
  listing_id uuid REFERENCES agency.listings(id) ON DELETE SET NULL,
  total_minor bigint NOT NULL DEFAULT 0,
  currency char(3) NOT NULL DEFAULT 'TRY',
  dates_text text NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','sent','accepted','rejected','expired')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_offers_tenant_idx ON agency.offers(tenant_id, status, created_at DESC);

-- Filtreli Özel İniş Sayfaları (Örn: Fethiye Lüks Villalar)
CREATE TABLE IF NOT EXISTS agency.custom_landing_pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  title text NOT NULL,
  slug text NOT NULL UNIQUE,
  region_id uuid REFERENCES agency.regions(id) ON DELETE SET NULL,
  category text NOT NULL,
  filter_criteria jsonb NOT NULL DEFAULT '{}'::jsonb,
  seo_title text NOT NULL DEFAULT '',
  seo_description text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_custom_pages_idx ON agency.custom_landing_pages(tenant_id, slug, active);

-- Terk Edilmiş Sepet Bildirim Kayıtları
CREATE TABLE IF NOT EXISTS agency.abandoned_cart_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cart_id uuid NOT NULL REFERENCES agency.carts(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK(channel IN ('sms','email','whatsapp')),
  sent_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'sent'
);
CREATE INDEX IF NOT EXISTS agency_abandoned_cart_notif_idx ON agency.abandoned_cart_notifications(cart_id, sent_at DESC);

GRANT SELECT,INSERT,UPDATE,DELETE ON 
  agency.popups,
  agency.banners,
  agency.redirects,
  agency.ip_blacklist,
  agency.offers,
  agency.custom_landing_pages,
  agency.abandoned_cart_notifications
TO agency_app, nexus_owner;
