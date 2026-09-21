-- Listing contract validation helper.
-- Returns missing required category field keys for a listing metadata payload.

CREATE OR REPLACE FUNCTION agency.validate_listing_contract(
  p_tenant uuid,
  p_category text,
  p_metadata jsonb
)
RETURNS TABLE(field_key text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  SELECT f.field_key
  FROM agency.categories c
  JOIN agency.category_fields f ON f.category_id = c.id
  WHERE c.tenant_id = p_tenant
    AND c.code = p_category
    AND c.active
    AND f.required
    AND nullif(trim(coalesce(p_metadata->'contract_fields'->>f.field_key, p_metadata->>f.field_key, '')), '') IS NULL
  ORDER BY f.sort_order, f.field_key
$$;

GRANT EXECUTE ON FUNCTION agency.validate_listing_contract(uuid,text,jsonb) TO agency_app;
