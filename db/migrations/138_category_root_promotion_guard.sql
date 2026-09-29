CREATE OR REPLACE FUNCTION agency.validate_category_tree_row()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE parent_tenant uuid;
BEGIN
  IF NEW.parent_id IS NULL THEN
    IF (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.parent_id IS NOT NULL))
       AND NEW.code NOT IN (
         'hotel','holiday_home','yacht','tour','activity','flight','car',
         'cruise','pilgrimage','visa','ferry','transfer','beach','cinema',
         'event','restaurant','bus'
       ) THEN
      RAISE EXCEPTION 'new main category code is not in shared contract'
        USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.parent_id = NEW.id THEN
    RAISE EXCEPTION 'category cannot be its own parent' USING ERRCODE = '23514';
  END IF;
  SELECT tenant_id INTO parent_tenant FROM agency.categories WHERE id=NEW.parent_id;
  IF parent_tenant IS DISTINCT FROM NEW.tenant_id THEN
    RAISE EXCEPTION 'category parent must belong to the same tenant'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
