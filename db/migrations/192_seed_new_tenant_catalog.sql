-- A newly created independent agency must receive the same local catalog
-- contract as an existing agency. Keep tenant display choices independent:
-- only missing rows are copied, never updated.
CREATE OR REPLACE FUNCTION agency.seed_tenant_catalog(p_tenant uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_source uuid;
BEGIN
  SELECT c.tenant_id INTO v_source
  FROM agency.categories c
  WHERE c.tenant_id<>p_tenant AND c.parent_id IS NULL AND c.active
    AND c.code IN ('hotel','holiday_home','yacht','tour','activity','flight','car',
      'cruise','pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus')
  GROUP BY c.tenant_id
  HAVING count(DISTINCT c.code)=17
  ORDER BY c.tenant_id
  LIMIT 1;
  IF v_source IS NULL THEN
    RAISE EXCEPTION 'canonical_catalog_source_missing';
  END IF;

  INSERT INTO agency.categories(tenant_id,code,name,slug,description,active,sort_order)
  SELECT p_tenant,code,name,slug,description,true,sort_order
  FROM agency.categories
  WHERE tenant_id=v_source AND parent_id IS NULL AND active
    AND code IN ('hotel','holiday_home','yacht','tour','activity','flight','car',
      'cruise','pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus')
  ON CONFLICT (tenant_id,code) DO NOTHING;

  INSERT INTO agency.category_fields(category_id,field_key,label,field_type,required,options,sort_order)
  SELECT target.id,f.field_key,f.label,f.field_type,f.required,f.options,f.sort_order
  FROM agency.category_fields f
  JOIN agency.categories source ON source.id=f.category_id AND source.tenant_id=v_source
  JOIN agency.categories target ON target.tenant_id=p_tenant AND target.code=source.code
  WHERE source.parent_id IS NULL AND target.parent_id IS NULL
  ON CONFLICT (category_id,field_key) DO NOTHING;

  INSERT INTO agency.modules(tenant_id,code,name,description,active)
  SELECT p_tenant,code,name,description,true FROM agency.modules
  WHERE tenant_id=v_source AND active
  ON CONFLICT (tenant_id,code) DO NOTHING;

  INSERT INTO agency.category_filter_groups
    (tenant_id,category_code,group_key,source_language,title,help_text,display_type,multiple,active,sort_order,metadata)
  SELECT p_tenant,category_code,group_key,source_language,title,help_text,
    display_type,multiple,true,sort_order,metadata
  FROM agency.category_filter_groups WHERE tenant_id=v_source AND active
  ON CONFLICT (tenant_id,category_code,group_key) DO NOTHING;

  INSERT INTO agency.category_filter_items
    (group_id,item_key,source_language,title,help_text,contract_field_key,contract_value,active,sort_order,metadata)
  SELECT target.id,item.item_key,item.source_language,item.title,item.help_text,
    item.contract_field_key,item.contract_value,true,item.sort_order,item.metadata
  FROM agency.category_filter_items item
  JOIN agency.category_filter_groups source ON source.id=item.group_id AND source.tenant_id=v_source
  JOIN agency.category_filter_groups target ON target.tenant_id=p_tenant
    AND target.category_code=source.category_code AND target.group_key=source.group_key
  WHERE item.active AND source.active
  ON CONFLICT (group_id,item_key) DO NOTHING;
END $$;

CREATE OR REPLACE FUNCTION agency.seed_tenant_catalog_after_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  PERFORM agency.seed_tenant_catalog(NEW.id);
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS agency_tenant_catalog_seed ON agency.tenants;
CREATE TRIGGER agency_tenant_catalog_seed
AFTER INSERT ON agency.tenants FOR EACH ROW
EXECUTE FUNCTION agency.seed_tenant_catalog_after_insert();

DO $$ DECLARE v_tenant uuid; BEGIN
  FOR v_tenant IN SELECT id FROM agency.tenants LOOP
    PERFORM agency.seed_tenant_catalog(v_tenant);
  END LOOP;
END $$;
