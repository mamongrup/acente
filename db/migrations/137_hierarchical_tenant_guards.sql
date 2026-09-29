-- Parent links in regions and menus must never cross the tenant boundary.
CREATE OR REPLACE FUNCTION agency.validate_hierarchy_tenant()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE parent_tenant uuid;
BEGIN
  IF NEW.parent_id IS NULL THEN RETURN NEW; END IF;
  IF NEW.parent_id = NEW.id THEN
    RAISE EXCEPTION 'row cannot be its own parent' USING ERRCODE = '23514';
  END IF;
  IF TG_TABLE_NAME = 'regions' THEN
    SELECT tenant_id INTO parent_tenant FROM agency.regions WHERE id = NEW.parent_id;
  ELSIF TG_TABLE_NAME = 'menus' THEN
    SELECT tenant_id INTO parent_tenant FROM agency.menus WHERE id = NEW.parent_id;
  END IF;
  IF parent_tenant IS DISTINCT FROM NEW.tenant_id THEN
    RAISE EXCEPTION 'parent must belong to the same tenant'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS agency_regions_tenant_tree_guard ON agency.regions;
CREATE TRIGGER agency_regions_tenant_tree_guard
BEFORE INSERT OR UPDATE OF tenant_id,parent_id ON agency.regions
FOR EACH ROW EXECUTE FUNCTION agency.validate_hierarchy_tenant();

DROP TRIGGER IF EXISTS agency_menus_tenant_tree_guard ON agency.menus;
CREATE TRIGGER agency_menus_tenant_tree_guard
BEFORE INSERT OR UPDATE OF tenant_id,parent_id ON agency.menus
FOR EACH ROW EXECUTE FUNCTION agency.validate_hierarchy_tenant();
