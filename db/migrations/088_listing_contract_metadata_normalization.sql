-- Normalize legacy wizard metadata into canonical supplier/listing contract_fields.

UPDATE agency.listings
SET metadata =
  metadata
  || jsonb_build_object(
    'contract_version', '1.1.0',
    'category_code', 'holiday_home',
    'contract_fields',
      coalesce(metadata->'contract_fields', '{}'::jsonb)
      || jsonb_strip_nulls(jsonb_build_object(
        'property_type', coalesce(nullif(metadata->>'property_type',''), nullif(metadata->>'place_type',''), nullif(metadata->>'villa_type',''), 'Villa'),
        'bedroom_count', coalesce(nullif(metadata->>'bedroom_count',''), nullif(metadata->>'bedrooms',''), nullif(metadata->>'bedrooms_count','')),
        'bathroom_count', coalesce(nullif(metadata->>'bathroom_count',''), nullif(metadata->>'bathrooms',''), nullif(metadata->>'bathrooms_count','')),
        'guest_capacity', coalesce(nullif(metadata->>'guest_capacity',''), nullif(metadata->>'guests',''), nullif(metadata->>'capacity','')),
        'pool_type', coalesce(
          nullif(metadata->>'pool_type',''),
          CASE WHEN metadata->>'sheltered_pool'='true' THEN 'Korunaklı Havuz' END,
          CASE WHEN nullif(metadata->>'pool_dimensions','') IS NOT NULL THEN 'Özel Havuz' END
        ),
        'kitchen', nullif(metadata->>'kitchen',''),
        'season_rules', coalesce(nullif(metadata->>'season_rules',''), nullif(metadata->>'season_start',''))
      ))
  )
WHERE category='holiday_home'
   OR category='villa';

UPDATE agency.listings
SET metadata =
  metadata
  || jsonb_build_object(
    'contract_version', '1.1.0',
    'category_code', 'yacht',
    'contract_fields',
      coalesce(metadata->'contract_fields', '{}'::jsonb)
      || jsonb_strip_nulls(jsonb_build_object(
        'yacht_type', coalesce(nullif(metadata->>'yacht_type',''), nullif(metadata->>'boat_type','')),
        'capacity', coalesce(nullif(metadata->>'capacity',''), nullif(metadata->>'guests',''), nullif(metadata->>'berth_count','')),
        'cabin_count', coalesce(nullif(metadata->>'cabin_count',''), nullif(metadata->>'cabins_count','')),
        'departure_port', coalesce(nullif(metadata->>'departure_port',''), nullif(metadata->>'port_name',''), nullif(metadata->>'departure_marina','')),
        'route', coalesce(nullif(metadata->>'route',''), nullif(metadata->>'boat_times','')),
        'captain_included', coalesce(nullif(metadata->>'captain_included',''), CASE WHEN nullif(metadata->>'crew_status','') IS NOT NULL THEN 'true' END),
        'fuel_policy', nullif(metadata->>'fuel_policy','')
      ))
  )
WHERE category='yacht';
