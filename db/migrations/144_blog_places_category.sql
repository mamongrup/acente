-- Blog taxonomy is tenant owned. Blog articles remain CMS pages (template=blog)
-- and carry their category, region and cover in the page SEO metadata.
CREATE TABLE IF NOT EXISTS agency.blog_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  slug text NOT NULL,
  title text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, slug)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON agency.blog_categories TO agency_app;

INSERT INTO agency.blog_categories (tenant_id, slug, title)
SELECT id, 'gezilesi-yerler', 'Gezilesi Yerler' FROM agency.tenants
ON CONFLICT (tenant_id, slug) DO NOTHING;

INSERT INTO agency.pages (tenant_id, slug, template, status, seo, published_at)
SELECT id, 'blog/gezilesi-yerler', 'landing', 'published',
  jsonb_build_object('title', 'Gezilesi Yerler', 'description', 'Bölge rehberleri ve gezilesi yerler.', 'blog_category', 'gezilesi-yerler'), now()
FROM agency.tenants
ON CONFLICT (tenant_id, slug) DO NOTHING;

INSERT INTO agency.page_blocks (page_id, block_type, sort_order, content)
SELECT p.id, 'region_places', 0,
  jsonb_build_object('title', 'Gezilesi Yerler', 'blogCategory', 'gezilesi-yerler', 'limit', 3)
FROM agency.pages p
WHERE p.slug = 'blog/gezilesi-yerler'
  AND NOT EXISTS (SELECT 1 FROM agency.page_blocks b WHERE b.page_id = p.id);

WITH target AS (
  SELECT p.id AS page_id, coalesce((
    SELECT b.sort_order FROM agency.page_blocks b
    WHERE b.page_id = p.id AND b.block_type = 'source_section'
      AND b.content->>'sectionKey' = 'region' LIMIT 1
  ), 4) AS after_order
  FROM agency.pages p
  WHERE p.slug IN ('category-holiday_home', 'category-yacht')
    AND NOT EXISTS (
      SELECT 1 FROM agency.page_blocks b
      WHERE b.page_id = p.id AND b.block_type = 'region_places'
    )
), shifted AS (
  UPDATE agency.page_blocks b SET sort_order = b.sort_order + 1
  FROM target t
  WHERE b.page_id = t.page_id AND b.sort_order > t.after_order
  RETURNING b.id
)
INSERT INTO agency.page_blocks (page_id, block_type, sort_order, content)
SELECT t.page_id, 'region_places', t.after_order + 1,
  jsonb_build_object('title','Gezilesi Yerler','blogCategory','gezilesi-yerler','limit',3)
FROM target t;
