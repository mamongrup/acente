-- Category contract v1.1.0: holiday_home is the main category.
-- Villa, apart, bungalow, daire and residence are property_type subtypes.

UPDATE agency.contract_versions
SET version='1.1.0', activated_at=now()
WHERE contract_name IN ('nexus.catalog.categories','nexus.supplier_listing');

INSERT INTO agency.contract_versions(contract_name,version)
VALUES ('nexus.catalog.categories','1.1.0'),('nexus.supplier_listing','1.1.0')
ON CONFLICT(contract_name) DO UPDATE SET version=excluded.version,activated_at=now();

-- Ensure every tenant has a holiday_home category before moving references.
INSERT INTO agency.categories(tenant_id,code,name,slug,description,active,sort_order)
SELECT t.id,'holiday_home','Tatil Evi','tatil-evi','Tatil evi; villa, apart, bungalov, daire ve residence alt türlerini kapsar',true,2
FROM agency.tenants t
ON CONFLICT(tenant_id,code) DO UPDATE SET
 name=excluded.name,
 slug=excluded.slug,
 description=excluded.description,
 active=true,
 sort_order=excluded.sort_order;

-- Copy villa category fields onto holiday_home without losing custom tenant definitions.
INSERT INTO agency.category_fields(category_id,field_key,label,field_type,required,options,sort_order)
SELECT target.id, f.field_key, f.label, f.field_type, f.required, f.options, f.sort_order
FROM agency.category_fields f
JOIN agency.categories source ON source.id=f.category_id AND source.code='villa'
JOIN agency.categories target ON target.tenant_id=source.tenant_id AND target.code='holiday_home'
ON CONFLICT(category_id,field_key) DO UPDATE SET
 label=excluded.label,
 field_type=excluded.field_type,
 required=excluded.required,
 options=excluded.options,
 sort_order=excluded.sort_order;

UPDATE agency.category_fields f
SET options='["Villa","Apart","Bungalov","Daire","Residence"]'::jsonb,
    label='Tatil evi türü',
    required=true
FROM agency.categories c
WHERE c.id=f.category_id
  AND c.code='holiday_home'
  AND f.field_key='property_type';

DELETE FROM agency.category_fields f
USING agency.categories c
WHERE c.id=f.category_id AND c.code='villa';

UPDATE agency.listings
SET category='holiday_home',
    metadata=jsonb_set(
      coalesce(metadata,'{}'::jsonb),
      '{extra_metadata,category_code}',
      '"holiday_home"'::jsonb,
      true
    )
WHERE lower(category) IN ('villa','holiday_home','vılla');

UPDATE agency.categories
SET active=false, name='Villa (Tatil Evi alt türü)', slug='villa', description='Ana kategori değildir; holiday_home.property_type alt türüdür', sort_order=0
WHERE code='villa';

UPDATE agency.categories
SET name='Tatil Evi',
    slug='tatil-evi',
    description='Tatil evi; villa, apart, bungalov, daire ve residence alt türlerini kapsar',
    active=true,
    sort_order=2
WHERE code='holiday_home';
