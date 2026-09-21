-- Contract hardening: holiday_home must expose property_type as the canonical subtype field.
-- Villa, Apart, Bungalov, Daire and Residence are subtypes, not main categories.

INSERT INTO agency.category_fields(category_id,field_key,label,field_type,required,options,sort_order)
SELECT c.id,
       'property_type',
       'Tatil evi türü',
       'select',
       true,
       '["Villa","Apart","Bungalov","Daire","Residence"]'::jsonb,
       10
FROM agency.categories c
WHERE c.code='holiday_home'
ON CONFLICT(category_id,field_key) DO UPDATE SET
  label=excluded.label,
  field_type=excluded.field_type,
  required=excluded.required,
  options=excluded.options,
  sort_order=least(agency.category_fields.sort_order, excluded.sort_order);

UPDATE agency.category_fields f
SET required=false,
    label='Eski alan: Tatil evi türü',
    sort_order=0
FROM agency.categories c
WHERE c.id=f.category_id
  AND c.code='holiday_home'
  AND f.field_key IN ('place_type','villa_type')
  AND f.field_key <> 'property_type';

UPDATE agency.contract_versions
SET version='1.1.0', activated_at=now()
WHERE contract_name IN ('nexus.catalog.categories','nexus.supplier_listing');
