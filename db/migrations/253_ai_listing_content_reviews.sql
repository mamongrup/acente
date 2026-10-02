CREATE TABLE IF NOT EXISTS agency.ai_listing_content_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id uuid NOT NULL,
 listing_id uuid NOT NULL,actor_id uuid NOT NULL REFERENCES agency.users(id),
 source_text text NOT NULL,review jsonb NOT NULL CHECK(jsonb_typeof(review)='object'),
 provider text NOT NULL,model text NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,listing_id) REFERENCES agency.listings(tenant_id,id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS ai_listing_review_recent ON agency.ai_listing_content_reviews(tenant_id,actor_id,created_at DESC);
REVOKE ALL ON agency.ai_listing_content_reviews FROM PUBLIC;
GRANT SELECT,INSERT ON agency.ai_listing_content_reviews TO agency_app;
