-- Make existing contract field selections available to public facet filtering.
-- Preserve all existing metadata and never infer a tour subtype from its title.
UPDATE agency.listings
SET metadata = jsonb_set(
  metadata,
  '{contract_fields}',
  metadata->'extra_metadata'->'contract_fields',
  true
)
WHERE metadata->'contract_fields' IS NULL
  AND jsonb_typeof(metadata->'extra_metadata'->'contract_fields') = 'object';
