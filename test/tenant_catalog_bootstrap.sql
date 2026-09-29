BEGIN;
DO $$
DECLARE v_tenant uuid; v_categories int; v_fields int; v_modules int;
  v_groups int; v_items int; v_pages int;
BEGIN
  INSERT INTO agency.tenants(legal_name,brand_name,slug,nexus_connected)
  VALUES('Standalone Contract Test','Standalone Contract Test',
    'standalone-contract-'||substr(gen_random_uuid()::text,1,8),false)
  RETURNING id INTO v_tenant;
  SELECT count(*) INTO v_categories FROM agency.categories
    WHERE tenant_id=v_tenant AND active AND parent_id IS NULL;
  SELECT count(*) INTO v_fields FROM agency.category_fields f
    JOIN agency.categories c ON c.id=f.category_id WHERE c.tenant_id=v_tenant;
  SELECT count(*) INTO v_modules FROM agency.modules
    WHERE tenant_id=v_tenant AND active;
  SELECT count(*) INTO v_groups FROM agency.category_filter_groups
    WHERE tenant_id=v_tenant AND active;
  SELECT count(*) INTO v_items FROM agency.category_filter_items i
    JOIN agency.category_filter_groups g ON g.id=i.group_id
    WHERE g.tenant_id=v_tenant AND i.active;
  SELECT count(*) INTO v_pages FROM agency.pages
    WHERE tenant_id=v_tenant AND slug LIKE 'category-%';
  IF v_categories<>17 OR v_fields<>106 OR v_modules<>17
     OR v_groups<>20 OR v_items<>78 OR v_pages<>17 THEN
    RAISE EXCEPTION 'standalone_catalog_incomplete: % % % % % %',
      v_categories,v_fields,v_modules,v_groups,v_items,v_pages;
  END IF;
  RAISE NOTICE 'standalone tenant catalog bootstrap passed';
END $$;
ROLLBACK;
