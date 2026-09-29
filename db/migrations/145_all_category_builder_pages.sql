-- Every canonical category has an independent editable landing-page layout.
-- The existing holiday-home and yacht layouts and tenant customizations remain intact.
WITH categories(code) AS (
  VALUES ('hotel'),('holiday_home'),('yacht'),('tour'),('activity'),('flight'),
         ('car'),('cruise'),('pilgrimage'),('visa'),('ferry'),('transfer'),
         ('beach'),('cinema'),('event'),('restaurant'),('bus')
)
INSERT INTO agency.pages (tenant_id, slug, template, status, seo, published_at)
SELECT t.id, 'category-' || c.code, 'standard', 'published',
       jsonb_build_object('category_scope', c.code), now()
FROM agency.tenants t CROSS JOIN categories c
ON CONFLICT (tenant_id, slug) DO NOTHING;

WITH definitions(sort_order, section_key) AS (
  VALUES (0,'hero'),(1,'results_heading'),(2,'filters'),(3,'listings'),
         (4,'region'),(5,'theme'),(7,'benefits')
), target AS (
  SELECT p.id
  FROM agency.pages p
  WHERE p.slug LIKE 'category-%'
    AND p.slug NOT IN ('category-holiday_home','category-yacht')
    AND NOT EXISTS (SELECT 1 FROM agency.page_blocks b WHERE b.page_id = p.id)
)
INSERT INTO agency.page_blocks (page_id, block_type, sort_order, content)
SELECT t.id, 'source_section', d.sort_order,
       jsonb_build_object('sectionKey',d.section_key,'enabled',true)
FROM target t CROSS JOIN definitions d;

INSERT INTO agency.page_blocks (page_id, block_type, sort_order, content)
SELECT p.id, 'region_places', 6,
       jsonb_build_object('title','Gezilesi Yerler','blogCategory','gezilesi-yerler','limit',3)
FROM agency.pages p
WHERE p.slug LIKE 'category-%'
  AND NOT EXISTS (
    SELECT 1 FROM agency.page_blocks b
    WHERE b.page_id = p.id AND b.block_type = 'region_places'
  );
