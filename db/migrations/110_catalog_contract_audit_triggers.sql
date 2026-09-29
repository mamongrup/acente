-- DB-level audit coverage for catalog/filter/contract changes that may happen
-- through restored router paths, bulk operations, scripts, or future admin code.

CREATE OR REPLACE FUNCTION agency.audit_catalog_contract_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, agency
AS $$
DECLARE
  v_tenant uuid;
  v_entity uuid;
  v_action text;
  v_meta jsonb := '{}'::jsonb;
BEGIN
  IF TG_TABLE_NAME = 'category_filter_groups' THEN
    v_tenant := COALESCE(NEW.tenant_id, OLD.tenant_id);
    v_entity := COALESCE(NEW.id, OLD.id);
    v_meta := jsonb_build_object(
      'category', COALESCE(NEW.category_code, OLD.category_code),
      'key', COALESCE(NEW.group_key, OLD.group_key),
      'active', COALESCE(NEW.active, OLD.active)
    );
  ELSIF TG_TABLE_NAME = 'category_filter_items' THEN
    SELECT g.tenant_id
      INTO v_tenant
      FROM agency.category_filter_groups g
     WHERE g.id = COALESCE(NEW.group_id, OLD.group_id);
    v_entity := COALESCE(NEW.id, OLD.id);
    v_meta := jsonb_build_object(
      'group_id', COALESCE(NEW.group_id, OLD.group_id),
      'key', COALESCE(NEW.item_key, OLD.item_key),
      'contract_field_key', COALESCE(NEW.contract_field_key, OLD.contract_field_key),
      'contract_value', COALESCE(NEW.contract_value, OLD.contract_value),
      'active', COALESCE(NEW.active, OLD.active)
    );
  ELSIF TG_TABLE_NAME = 'category_fields' THEN
    SELECT c.tenant_id
      INTO v_tenant
      FROM agency.categories c
     WHERE c.id = COALESCE(NEW.category_id, OLD.category_id);
    v_entity := COALESCE(NEW.id, OLD.id);
    v_meta := jsonb_build_object(
      'category_id', COALESCE(NEW.category_id, OLD.category_id),
      'field_key', COALESCE(NEW.field_key, OLD.field_key),
      'field_type', COALESCE(NEW.field_type, OLD.field_type),
      'required', COALESCE(NEW.required, OLD.required)
    );
  ELSIF TG_TABLE_NAME = 'contract_versions' THEN
    v_tenant := NULL;
    v_entity := NULL;
    v_meta := jsonb_build_object(
      'contract_name', COALESCE(NEW.contract_name, OLD.contract_name),
      'version', COALESCE(NEW.version, OLD.version)
    );
  ELSIF TG_TABLE_NAME = 'listings' THEN
    v_tenant := COALESCE(NEW.tenant_id, OLD.tenant_id);
    v_entity := COALESCE(NEW.id, OLD.id);
    v_meta := jsonb_build_object(
      'title', COALESCE(NEW.title, OLD.title),
      'category', COALESCE(NEW.category, OLD.category),
      'status', COALESCE(NEW.status, OLD.status),
      'source', COALESCE(NEW.source, OLD.source)
    );
  END IF;

  v_action := CASE TG_OP
    WHEN 'INSERT' THEN 'catalog.' || TG_TABLE_NAME || '.created'
    WHEN 'UPDATE' THEN 'catalog.' || TG_TABLE_NAME || '.updated'
    WHEN 'DELETE' THEN 'catalog.' || TG_TABLE_NAME || '.deleted'
    ELSE 'catalog.' || TG_TABLE_NAME || '.changed'
  END;

  INSERT INTO agency.audit_logs(tenant_id, user_id, action, entity_type, entity_id, metadata)
  VALUES(v_tenant, NULL, v_action, TG_TABLE_NAME, v_entity, v_meta);

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS agency_audit_category_filter_groups ON agency.category_filter_groups;
CREATE TRIGGER agency_audit_category_filter_groups
AFTER INSERT OR UPDATE OR DELETE ON agency.category_filter_groups
FOR EACH ROW EXECUTE FUNCTION agency.audit_catalog_contract_change();

DROP TRIGGER IF EXISTS agency_audit_category_filter_items ON agency.category_filter_items;
CREATE TRIGGER agency_audit_category_filter_items
AFTER INSERT OR UPDATE OR DELETE ON agency.category_filter_items
FOR EACH ROW EXECUTE FUNCTION agency.audit_catalog_contract_change();

DROP TRIGGER IF EXISTS agency_audit_category_fields ON agency.category_fields;
CREATE TRIGGER agency_audit_category_fields
AFTER INSERT OR UPDATE OR DELETE ON agency.category_fields
FOR EACH ROW EXECUTE FUNCTION agency.audit_catalog_contract_change();

DROP TRIGGER IF EXISTS agency_audit_contract_versions ON agency.contract_versions;
CREATE TRIGGER agency_audit_contract_versions
AFTER INSERT OR UPDATE OR DELETE ON agency.contract_versions
FOR EACH ROW EXECUTE FUNCTION agency.audit_catalog_contract_change();

DROP TRIGGER IF EXISTS agency_audit_listings_catalog ON agency.listings;
DROP TRIGGER IF EXISTS agency_audit_listings_catalog_insert ON agency.listings;
DROP TRIGGER IF EXISTS agency_audit_listings_catalog_update ON agency.listings;
DROP TRIGGER IF EXISTS agency_audit_listings_catalog_delete ON agency.listings;

CREATE TRIGGER agency_audit_listings_catalog_insert
AFTER INSERT ON agency.listings
FOR EACH ROW
EXECUTE FUNCTION agency.audit_catalog_contract_change();

CREATE TRIGGER agency_audit_listings_catalog_update
AFTER UPDATE ON agency.listings
FOR EACH ROW
WHEN (
  OLD.title IS DISTINCT FROM NEW.title
  OR OLD.category IS DISTINCT FROM NEW.category
  OR OLD.status IS DISTINCT FROM NEW.status
  OR OLD.metadata IS DISTINCT FROM NEW.metadata
)
EXECUTE FUNCTION agency.audit_catalog_contract_change();

CREATE TRIGGER agency_audit_listings_catalog_delete
AFTER DELETE ON agency.listings
FOR EACH ROW
EXECUTE FUNCTION agency.audit_catalog_contract_change();

GRANT EXECUTE ON FUNCTION agency.audit_catalog_contract_change() TO agency_app;
