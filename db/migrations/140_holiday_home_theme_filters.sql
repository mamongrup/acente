-- Editable holiday-home themes backed by the existing listing amenities codes.
-- Seed every current tenant without overwriting administrator changes.

INSERT INTO agency.category_filter_groups
  (tenant_id, category_code, group_key, title, help_text, display_type, multiple, sort_order, active)
SELECT id, 'holiday_home', 'theme', 'Tema',
  'Tatil evlerini deniz, doğa ve konaklama özelliklerine göre keşfedin.',
  'chips', true, 20, true
FROM agency.tenants
ON CONFLICT (tenant_id, category_code, group_key) DO NOTHING;

WITH seed(item_key, title, amenity_code, sort_order) AS (
  VALUES
    ('beachfront', 'Denize Sıfır', 'beachfront', 10),
    ('sea_view', 'Deniz Manzaralı', 'sea_view', 20),
    ('sheltered', 'Muhafazakar', 'sheltered', 30),
    ('jacuzzi', 'Jakuzili', 'jacuzzi', 40),
    ('forest_view', 'Orman Manzaralı', 'forest_view', 50),
    ('pool', 'Havuzlu', 'pool', 60)
)
INSERT INTO agency.category_filter_items
  (group_id, item_key, title, contract_field_key, contract_value, sort_order, active)
SELECT g.id, s.item_key, s.title, 'amenities', s.amenity_code, s.sort_order, true
FROM agency.category_filter_groups g
CROSS JOIN seed s
WHERE g.category_code = 'holiday_home' AND g.group_key = 'theme'
ON CONFLICT (group_id, item_key) DO NOTHING;

SELECT agency.queue_category_filter_translations('group', id, 'tr')
FROM agency.category_filter_groups
WHERE category_code = 'holiday_home' AND group_key = 'theme';

SELECT agency.queue_category_filter_translations('item', i.id, 'tr')
FROM agency.category_filter_items i
JOIN agency.category_filter_groups g ON g.id = i.group_id
WHERE g.category_code = 'holiday_home' AND g.group_key = 'theme';
