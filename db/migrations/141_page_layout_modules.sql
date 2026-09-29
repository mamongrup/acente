-- Each visible section between the header and footer is an independently
-- ordered page-builder block. Existing site sections stay in place until the
-- published layout applies, so a missing CMS connection is a safe fallback.
INSERT INTO agency.pages (tenant_id, slug, template, status, seo, published_at)
SELECT t.id, scope.slug, 'standard', 'published', '{}'::jsonb, now()
FROM agency.tenants t
CROSS JOIN (VALUES ('home'), ('category-holiday_home')) AS scope(slug)
ON CONFLICT (tenant_id, slug) DO NOTHING;

WITH definitions(slug, sort_order, section_key) AS (
  VALUES
    ('home',0,'hero'),
    ('home',1,'adventure'),
    ('home',2,'why_host'),
    ('home',3,'featured'),
    ('home',4,'divider_one'),
    ('home',5,'how_it_works'),
    ('home',6,'become_host'),
    ('home',7,'newsletter'),
    ('home',8,'divider_two'),
    ('home',9,'explore_nearby'),
    ('home',10,'host_cta'),
    ('home',11,'stay_types'),
    ('home',12,'videos'),
    ('home',13,'news'),
    ('category-holiday_home',0,'hero'),
    ('category-holiday_home',1,'results_heading'),
    ('category-holiday_home',2,'filters'),
    ('category-holiday_home',3,'listings'),
    ('category-holiday_home',4,'region'),
    ('category-holiday_home',5,'theme'),
    ('category-holiday_home',6,'benefits')
)
INSERT INTO agency.page_blocks (page_id, block_type, sort_order, content)
SELECT p.id, 'source_section', d.sort_order,
       jsonb_build_object('sectionKey', d.section_key, 'enabled', true)
FROM definitions d
JOIN agency.pages p ON p.slug = d.slug
WHERE NOT EXISTS (
  SELECT 1 FROM agency.page_blocks existing WHERE existing.page_id = p.id
);
