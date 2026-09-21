-- Add supplier panel module detail signature to sync contract state.

CREATE OR REPLACE FUNCTION agency.sync_contract_state(p_tenant uuid)
RETURNS TABLE(data text[])
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
  WITH tenant_scope AS (
    SELECT p_tenant AS tenant_id
  ),
  contract_modules(code) AS (
    VALUES
      ('dashboard'),('company_profile'),('documents'),('catalog'),
      ('availability'),('pricing'),('reservations'),('offers'),
      ('customers'),('messages'),('tasks'),('staff'),('accounting'),
      ('payments'),('reports'),('integrations'),('settings')
  ),
  contract AS (
    SELECT
      coalesce(max(version) FILTER (WHERE contract_name = 'nexus.catalog.categories'), '') AS catalog_version,
      coalesce(max(version) FILTER (WHERE contract_name = 'nexus.supplier_listing'), '') AS supplier_listing_version
    FROM agency.contract_versions
  ),
  category_stats AS (
    SELECT count(DISTINCT c.code)::text AS active_category_count
    FROM agency.categories c
    JOIN tenant_scope t ON t.tenant_id = c.tenant_id
    WHERE c.active
      AND c.code IN (
        'hotel','holiday_home','yacht','tour','activity','flight','car',
        'cruise','pilgrimage','visa','ferry','transfer','beach','cinema',
        'event','restaurant','bus'
      )
  ),
  filter_stats AS (
    SELECT count(DISTINCT i.item_key)::text AS active_filter_item_count
    FROM agency.category_filter_groups g
    JOIN agency.category_filter_items i ON i.group_id = g.id
    JOIN tenant_scope t ON t.tenant_id = g.tenant_id
    WHERE g.active
      AND i.active
      AND g.category_code IN (
        'hotel','holiday_home','yacht','tour','activity','flight','car',
        'cruise','pilgrimage','visa','ferry','transfer','beach','cinema',
        'event','restaurant','bus'
      )
  ),
  module_stats AS (
    SELECT count(DISTINCT m.code)::text AS active_supplier_module_count
    FROM agency.modules m
    JOIN contract_modules cm ON cm.code = m.code
    JOIN tenant_scope t ON t.tenant_id = m.tenant_id
    WHERE m.active
  ),
  module_detail_stats AS (
    SELECT md5(string_agg(
      concat_ws('|', code, family, array_to_string(scope, ','), array_to_string(permissions, ',')),
      ';;' ORDER BY code
    )) AS supplier_module_detail_signature
    FROM agency.supplier_panel_module_contract_details()
  )
  SELECT ARRAY['catalog_contract_version', catalog_version] FROM contract
  UNION ALL
  SELECT ARRAY['supplier_listing_contract_version', supplier_listing_version] FROM contract
  UNION ALL
  SELECT ARRAY['active_category_count', active_category_count] FROM category_stats
  UNION ALL
  SELECT ARRAY['active_filter_item_count', active_filter_item_count] FROM filter_stats
  UNION ALL
  SELECT ARRAY['active_supplier_module_count', active_supplier_module_count] FROM module_stats
  UNION ALL
  SELECT ARRAY['supplier_module_detail_signature', supplier_module_detail_signature] FROM module_detail_stats
  ORDER BY 1;
$$;

GRANT EXECUTE ON FUNCTION agency.sync_contract_state(uuid) TO agency_app;

