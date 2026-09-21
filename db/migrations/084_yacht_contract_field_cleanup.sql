-- Keep yacht listing fields aligned with supplier-listing contract v1.1.0.
-- Yat works like holiday_home: subtypes are modeled under yacht.yacht_type.

DELETE FROM agency.category_fields f
USING agency.categories c
WHERE c.id=f.category_id
  AND c.code='yacht'
  AND f.field_key NOT IN (
    'yacht_type',
    'capacity',
    'cabin_count',
    'departure_port',
    'route',
    'captain_included',
    'fuel_policy'
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
    ('yacht_type','Yat / tekne türü','select',true,'["Gulet","Motoryat","Yelkenli","Katamaran","Tekne"]'::jsonb,10),
    ('capacity','Kapasite','number',true,'[]'::jsonb,20),
    ('cabin_count','Kabin sayısı','number',false,'[]'::jsonb,30),
    ('departure_port','Kalkış limanı','text',true,'[]'::jsonb,40),
    ('route','Rota','text',true,'[]'::jsonb,50),
    ('captain_included','Kaptan dahil','boolean',true,'[]'::jsonb,60),
    ('fuel_policy','Yakıt politikası','text',false,'[]'::jsonb,70)
) AS v(field_key,label,field_type,required,options,sort_order)
  ON true
WHERE c.id=f.category_id
  AND c.code='yacht'
  AND v.field_key=f.field_key;

INSERT INTO agency.category_fields(category_id,field_key,label,field_type,required,options,sort_order)
SELECT c.id, v.field_key, v.label, v.field_type, v.required, v.options, v.sort_order
FROM agency.categories c
CROSS JOIN (
  VALUES
    ('yacht_type','Yat / tekne türü','select',true,'["Gulet","Motoryat","Yelkenli","Katamaran","Tekne"]'::jsonb,10),
    ('capacity','Kapasite','number',true,'[]'::jsonb,20),
    ('cabin_count','Kabin sayısı','number',false,'[]'::jsonb,30),
    ('departure_port','Kalkış limanı','text',true,'[]'::jsonb,40),
    ('route','Rota','text',true,'[]'::jsonb,50),
    ('captain_included','Kaptan dahil','boolean',true,'[]'::jsonb,60),
    ('fuel_policy','Yakıt politikası','text',false,'[]'::jsonb,70)
) AS v(field_key,label,field_type,required,options,sort_order)
WHERE c.code='yacht'
ON CONFLICT(category_id,field_key) DO NOTHING;
