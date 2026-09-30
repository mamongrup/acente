-- Keep audit events valid during tenant cascade deletion.
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

  -- Cascaded catalog deletions can run after the tenant row has disappeared.
  -- Preserve the audit event without referencing that deleted tenant.
  IF TG_OP = 'DELETE' AND v_tenant IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM agency.tenants WHERE id = v_tenant) THEN
    v_meta := v_meta || jsonb_build_object('deleted_tenant_id', v_tenant);
    v_tenant := NULL;
  END IF;
  INSERT INTO agency.audit_logs(tenant_id, user_id, action, entity_type, entity_id, metadata)
  VALUES(v_tenant, NULL, v_action, TG_TABLE_NAME, v_entity, v_meta);

  RETURN COALESCE(NEW, OLD);
END;
$$;
