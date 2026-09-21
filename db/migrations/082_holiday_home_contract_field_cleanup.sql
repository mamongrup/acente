-- Keep holiday_home listing fields aligned with supplier-listing contract v1.1.0.
-- UI-visible fields must be the canonical 7 field keys below. Legacy synonym
-- fields are removed from field definitions; listing metadata can still keep
-- historical values for migration/audit purposes.

DELETE FROM agency.category_fields f
USING agency.categories c
WHERE c.id=f.category_id
  AND c.code='holiday_home'
  AND f.field_key NOT IN (
    'property_type',
    'bedroom_count',
    'bathroom_count',
    'guest_capacity',
    'pool_type',
    'kitchen',
    'season_rules'
  );

UPDATE agency.category_fields f
SET label=v.label,
    field_type=v.field_type,
    required=v.required,
    options=v.options,
    sort_order=v.sort_order
FROM agency.categories c
JOIN LATERAL (
  VALUES
    ('property_type','Tatil evi türü','select',true,'["Villa","Apart","Bungalov","Daire","Residence"]'::jsonb,10),
    ('bedroom_count','Yatak odası sayısı','number',true,'[]'::jsonb,20),
    ('bathroom_count','Banyo sayısı','number',true,'[]'::jsonb,30),
    ('guest_capacity','Misafir kapasitesi','number',true,'[]'::jsonb,40),
    ('pool_type','Havuz tipi','select',false,'["Yok","Özel Havuz","Ortak Havuz","Isıtmalı Havuz","Korunaklı Havuz"]'::jsonb,50),
    ('kitchen','Mutfak','select',false,'["Yok","Mini Mutfak","Tam Donanımlı Mutfak","Açık Mutfak"]'::jsonb,60),
    ('season_rules','Sezon kuralları','textarea',false,'[]'::jsonb,70)
) AS v(field_key,label,field_type,required,options,sort_order)
  ON true
WHERE c.id=f.category_id
  AND c.code='holiday_home'
  AND v.field_key=f.field_key;

INSERT INTO agency.category_fields(category_id,field_key,label,field_type,required,options,sort_order)
SELECT c.id, v.field_key, v.label, v.field_type, v.required, v.options, v.sort_order
FROM agency.categories c
CROSS JOIN (
  VALUES
    ('property_type','Tatil evi türü','select',true,'["Villa","Apart","Bungalov","Daire","Residence"]'::jsonb,10),
    ('bedroom_count','Yatak odası sayısı','number',true,'[]'::jsonb,20),
    ('bathroom_count','Banyo sayısı','number',true,'[]'::jsonb,30),
    ('guest_capacity','Misafir kapasitesi','number',true,'[]'::jsonb,40),
    ('pool_type','Havuz tipi','select',false,'["Yok","Özel Havuz","Ortak Havuz","Isıtmalı Havuz","Korunaklı Havuz"]'::jsonb,50),
    ('kitchen','Mutfak','select',false,'["Yok","Mini Mutfak","Tam Donanımlı Mutfak","Açık Mutfak"]'::jsonb,60),
    ('season_rules','Sezon kuralları','textarea',false,'[]'::jsonb,70)
) AS v(field_key,label,field_type,required,options,sort_order)
WHERE c.code='holiday_home'
ON CONFLICT(category_id,field_key) DO NOTHING;
