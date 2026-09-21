CREATE TABLE IF NOT EXISTS agency.public_search_events (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), query_text text NOT NULL, detected_category text NOT NULL DEFAULT '', detected_location text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS public_search_events_created_idx ON agency.public_search_events(created_at DESC);
