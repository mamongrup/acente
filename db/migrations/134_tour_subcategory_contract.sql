-- Shared optional tour facet v1.2.0; main category and existing tour_type stay unchanged.
INSERT INTO agency.category_fields(category_id, field_key, label, field_type, required, options, sort_order)
SELECT c.id, 'tour_subcategory', 'Tur alt kategorisi', 'select', false,
       '["tour_abroad","tour_culture","tour_cruise","tour_daily","tour_religious"]'::jsonb, 11
FROM agency.categories c
WHERE c.code = 'tour' AND c.parent_id IS NULL
ON CONFLICT(category_id, field_key) DO UPDATE SET
  label=excluded.label, field_type=excluded.field_type,
  required=excluded.required, options=excluded.options, sort_order=excluded.sort_order;

WITH groups AS (
  INSERT INTO agency.category_filter_groups(
    tenant_id, category_code, group_key, title, help_text,
    display_type, multiple, sort_order, active
  )
  SELECT t.id, 'tour', 'tour_subcategory', 'Tur alt kategorisi',
         'Tur ilanlarını alt kategoriye göre görüntüleyin.',
         'chips', false, 5, true
  FROM agency.tenants t
  ON CONFLICT(tenant_id, category_code, group_key) DO UPDATE SET
    active=true, updated_at=now()
  RETURNING id
), items(item_key,title,sort_order) AS (
  VALUES
    ('tour_abroad','Yurtdışı Turlar',10),
    ('tour_culture','Kültür Turları',20),
    ('tour_cruise','Gemi Turları',30),
    ('tour_daily','Günlük Turlar',40),
    ('tour_religious','Dini Turlar',50)
)
INSERT INTO agency.category_filter_items(
  group_id,item_key,title,contract_field_key,contract_value,sort_order,active
)
SELECT g.id,i.item_key,i.title,'tour_subcategory',i.item_key,i.sort_order,true
FROM groups g CROSS JOIN items i
ON CONFLICT(group_id,item_key) DO UPDATE SET
  active=true,contract_field_key=excluded.contract_field_key,
  contract_value=excluded.contract_value,updated_at=now();

SELECT agency.queue_category_filter_translations('group',id,'tr')
FROM agency.category_filter_groups WHERE category_code='tour' AND group_key='tour_subcategory';
SELECT agency.queue_category_filter_translations('item',i.id,'tr')
FROM agency.category_filter_items i
JOIN agency.category_filter_groups g ON g.id=i.group_id
WHERE g.category_code='tour' AND g.group_key='tour_subcategory';

UPDATE agency.contract_versions SET version='1.2.0',activated_at=now()
WHERE contract_name='nexus.supplier_listing';
