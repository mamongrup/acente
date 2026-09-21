CREATE TABLE IF NOT EXISTS agency.favorites (
  customer_id uuid NOT NULL REFERENCES agency.customers(id) ON DELETE CASCADE, listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(customer_id,listing_id)
);
CREATE TABLE IF NOT EXISTS agency.comparisons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), customer_id uuid REFERENCES agency.customers(id) ON DELETE CASCADE, session_key text,
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(customer_id,session_key)
);
CREATE TABLE IF NOT EXISTS agency.comparison_items (
  comparison_id uuid NOT NULL REFERENCES agency.comparisons(id) ON DELETE CASCADE, listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  added_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(comparison_id,listing_id)
);
CREATE TABLE IF NOT EXISTS agency.recent_views (
  customer_id uuid REFERENCES agency.customers(id) ON DELETE CASCADE, session_key text, listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(), UNIQUE(customer_id,session_key,listing_id)
);
CREATE TABLE IF NOT EXISTS agency.user_preferences (
  user_id uuid PRIMARY KEY REFERENCES agency.users(id) ON DELETE CASCADE, language_code varchar(10) NOT NULL DEFAULT 'tr', currency char(3) NOT NULL DEFAULT 'TRY', data jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE IF NOT EXISTS agency.devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE, platform text NOT NULL, push_token text NOT NULL, active boolean NOT NULL DEFAULT true, last_seen_at timestamptz, UNIQUE(user_id,push_token)
);
CREATE INDEX IF NOT EXISTS agency_favorites_listing_idx ON agency.favorites(listing_id,created_at DESC);
CREATE INDEX IF NOT EXISTS agency_recent_views_idx ON agency.recent_views(customer_id,session_key,viewed_at DESC);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.favorites,agency.comparisons,agency.comparison_items,agency.recent_views,agency.user_preferences,agency.devices TO agency_app;
