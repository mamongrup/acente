-- Give the yacht landing the same editable section layout as holiday homes.
INSERT INTO agency.pages (tenant_id, slug, template, status, seo, published_at)
SELECT t.id, 'category-yacht', 'standard', 'published', '{}'::jsonb, now()
FROM agency.tenants t
ON CONFLICT (tenant_id, slug) DO NOTHING;

INSERT INTO agency.page_blocks (page_id, block_type, sort_order, content)
SELECT target.id, source_block.block_type, source_block.sort_order, source_block.content
FROM agency.pages target
JOIN agency.pages source_page
  ON source_page.tenant_id = target.tenant_id
 AND source_page.slug = 'category-holiday_home'
JOIN agency.page_blocks source_block ON source_block.page_id = source_page.id
WHERE target.slug = 'category-yacht'
  AND NOT EXISTS (SELECT 1 FROM agency.page_blocks existing WHERE existing.page_id = target.id);

INSERT INTO agency.category_filter_groups
  (tenant_id, category_code, group_key, title, help_text, display_type, multiple, sort_order, active)
SELECT id, 'yacht', 'theme', 'Tema',
  'Yatları ve tekne gezilerini deniz deneyimine göre keşfedin.',
  'chips', true, 20, true
FROM agency.tenants
ON CONFLICT (tenant_id, category_code, group_key) DO NOTHING;

WITH seed(item_key, title, amenity_code, sort_order) AS (
  VALUES
    ('private_cruise', 'Özel Tur', 'private_cruise', 10),
    ('sunset_cruise', 'Gün Batımı', 'sunset_cruise', 20),
    ('swimming', 'Yüzme', 'swimming', 30),
    ('fishing', 'Balık Tutma', 'fishing', 40),
    ('luxury', 'Lüks', 'luxury', 50)
)
INSERT INTO agency.category_filter_items
  (group_id, item_key, title, contract_field_key, contract_value, sort_order, active)
SELECT g.id, s.item_key, s.title, 'amenities', s.amenity_code, s.sort_order, true
FROM agency.category_filter_groups g
CROSS JOIN seed s
WHERE g.category_code = 'yacht' AND g.group_key = 'theme'
ON CONFLICT (group_id, item_key) DO NOTHING;

SELECT agency.queue_category_filter_translations('group', id, 'tr')
FROM agency.category_filter_groups
WHERE category_code = 'yacht' AND group_key = 'theme';

SELECT agency.queue_category_filter_translations('item', i.id, 'tr')
FROM agency.category_filter_items i
JOIN agency.category_filter_groups g ON g.id = i.group_id
WHERE g.category_code = 'yacht' AND g.group_key = 'theme';
