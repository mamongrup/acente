-- Admin-managed category filters and sub-type presentation.
-- These are intentionally NOT hard-coded: contract fields validate listings,
-- while this layer controls storefront/admin filter grouping and labels.

CREATE TABLE IF NOT EXISTS agency.category_filter_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  category_code text NOT NULL,
  group_key text NOT NULL CHECK (group_key ~ '^[a-z][a-z0-9_]{1,60}$'),
  source_language varchar(10) NOT NULL DEFAULT 'tr' REFERENCES agency.languages(code),
  title text NOT NULL,
  help_text text NOT NULL DEFAULT '',
  display_type text NOT NULL DEFAULT 'checkbox'
    CHECK (display_type IN ('checkbox','radio','select','chips','range','boolean')),
  multiple boolean NOT NULL DEFAULT true,
  active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 10,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, category_code, group_key)
);

CREATE TABLE IF NOT EXISTS agency.category_filter_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES agency.category_filter_groups(id) ON DELETE CASCADE,
  item_key text NOT NULL CHECK (item_key ~ '^[a-z][a-z0-9_]{1,80}$'),
  source_language varchar(10) NOT NULL DEFAULT 'tr' REFERENCES agency.languages(code),
  title text NOT NULL,
  help_text text NOT NULL DEFAULT '',
  contract_field_key text NOT NULL DEFAULT '',
  contract_value text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 10,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(group_id, item_key)
);

CREATE TABLE IF NOT EXISTS agency.category_filter_translations (
  entity_type text NOT NULL CHECK (entity_type IN ('group','item')),
  entity_id uuid NOT NULL,
  language_code varchar(10) NOT NULL REFERENCES agency.languages(code),
  title text NOT NULL DEFAULT '',
  help_text text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued','translated','approved','published','failed')),
  provider text NOT NULL DEFAULT 'ai_pending',
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(entity_type, entity_id, language_code)
);

CREATE INDEX IF NOT EXISTS agency_category_filter_groups_lookup_idx
  ON agency.category_filter_groups(tenant_id, category_code, active, sort_order);
CREATE INDEX IF NOT EXISTS agency_category_filter_items_lookup_idx
  ON agency.category_filter_items(group_id, active, sort_order);

CREATE OR REPLACE FUNCTION agency.queue_category_filter_translations(p_entity_type text, p_entity_id uuid, p_source_language varchar DEFAULT 'tr')
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE lang record;
BEGIN
  IF p_entity_type NOT IN ('group','item') THEN
    RETURN 'invalid_entity_type';
  END IF;

  FOR lang IN
    SELECT code FROM agency.languages WHERE active AND code <> coalesce(p_source_language,'tr')
  LOOP
    INSERT INTO agency.category_filter_translations(entity_type, entity_id, language_code, status)
    VALUES(p_entity_type, p_entity_id, lang.code, 'queued')
    ON CONFLICT(entity_type, entity_id, language_code)
    DO UPDATE SET status='queued', provider='ai_pending', updated_at=now()
    WHERE agency.category_filter_translations.status IN ('failed','queued');
  END LOOP;

  RETURN 'queued';
END $$;

CREATE OR REPLACE FUNCTION agency.category_filter_groups_for(p_tenant uuid, p_category text, p_language varchar DEFAULT 'tr')
RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    g.id::text,
    g.category_code,
    g.group_key,
    coalesce(nullif(t.title,''), g.title),
    coalesce(nullif(t.help_text,''), g.help_text),
    g.display_type,
    g.multiple::text,
    g.active::text,
    g.sort_order::text
  ]
  FROM agency.category_filter_groups g
  LEFT JOIN agency.category_filter_translations t
    ON t.entity_type='group' AND t.entity_id=g.id AND t.language_code=coalesce(p_language,'tr')
       AND t.status IN ('translated','approved','published')
  WHERE g.tenant_id=p_tenant AND g.category_code=p_category AND g.active
  ORDER BY g.sort_order, g.title;
$$;

CREATE OR REPLACE FUNCTION agency.category_filter_items_for(p_group uuid, p_language varchar DEFAULT 'tr')
RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    i.id::text,
    i.item_key,
    coalesce(nullif(t.title,''), i.title),
    coalesce(nullif(t.help_text,''), i.help_text),
    i.contract_field_key,
    i.contract_value,
    i.active::text,
    i.sort_order::text
  ]
  FROM agency.category_filter_items i
  LEFT JOIN agency.category_filter_translations t
    ON t.entity_type='item' AND t.entity_id=i.id AND t.language_code=coalesce(p_language,'tr')
       AND t.status IN ('translated','approved','published')
  WHERE i.group_id=p_group AND i.active
  ORDER BY i.sort_order, i.title;
$$;

GRANT SELECT,INSERT,UPDATE,DELETE ON agency.category_filter_groups,agency.category_filter_items,agency.category_filter_translations TO agency_app;
GRANT EXECUTE ON FUNCTION agency.queue_category_filter_translations(text,uuid,varchar),agency.category_filter_groups_for(uuid,text,varchar),agency.category_filter_items_for(uuid,varchar) TO agency_app;

WITH tenant_rows AS (
  SELECT id AS tenant_id FROM agency.tenants
), groups AS (
  INSERT INTO agency.category_filter_groups(tenant_id, category_code, group_key, title, help_text, display_type, multiple, sort_order)
  SELECT tenant_id, 'holiday_home', 'property_type', 'Tatil evi tipi', 'Villa, apart, bungalov, daire ve residence tiplerini yönetin.', 'chips', true, 10
  FROM tenant_rows
  ON CONFLICT(tenant_id, category_code, group_key) DO UPDATE
  SET title=excluded.title, help_text=excluded.help_text, display_type=excluded.display_type, multiple=excluded.multiple, updated_at=now()
  RETURNING id
), yacht_groups AS (
  INSERT INTO agency.category_filter_groups(tenant_id, category_code, group_key, title, help_text, display_type, multiple, sort_order)
  SELECT tenant_id, 'yacht', 'yacht_type', 'Yat / tekne tipi', 'Gulet, motoryat, yelkenli, katamaran ve tekne tiplerini yönetin.', 'chips', true, 10
  FROM tenant_rows
  ON CONFLICT(tenant_id, category_code, group_key) DO UPDATE
  SET title=excluded.title, help_text=excluded.help_text, display_type=excluded.display_type, multiple=excluded.multiple, updated_at=now()
  RETURNING id
)
SELECT agency.queue_category_filter_translations('group', id, 'tr') FROM groups
UNION ALL
SELECT agency.queue_category_filter_translations('group', id, 'tr') FROM yacht_groups;

WITH target_groups AS (
  SELECT id, category_code, group_key
  FROM agency.category_filter_groups
  WHERE (category_code='holiday_home' AND group_key='property_type')
     OR (category_code='yacht' AND group_key='yacht_type')
), seed_items(group_id, item_key, title, contract_field_key, contract_value, sort_order) AS (
  SELECT g.id, v.item_key, v.title, 'property_type', v.title, v.sort_order
  FROM target_groups g
  CROSS JOIN (VALUES
    ('villa','Villa',10),
    ('apart','Apart',20),
    ('bungalov','Bungalov',30),
    ('daire','Daire',40),
    ('residence','Residence',50)
  ) v(item_key,title,sort_order)
  WHERE g.category_code='holiday_home'
  UNION ALL
  SELECT g.id, v.item_key, v.title, 'yacht_type', v.title, v.sort_order
  FROM target_groups g
  CROSS JOIN (VALUES
    ('gulet','Gulet',10),
    ('motoryat','Motoryat',20),
    ('yelkenli','Yelkenli',30),
    ('katamaran','Katamaran',40),
    ('tekne','Tekne',50)
  ) v(item_key,title,sort_order)
  WHERE g.category_code='yacht'
), inserted AS (
  INSERT INTO agency.category_filter_items(group_id, item_key, title, contract_field_key, contract_value, sort_order)
  SELECT group_id, item_key, title, contract_field_key, contract_value, sort_order
  FROM seed_items
  ON CONFLICT(group_id, item_key) DO UPDATE
  SET title=excluded.title,
      contract_field_key=excluded.contract_field_key,
      contract_value=excluded.contract_value,
      sort_order=excluded.sort_order,
      updated_at=now()
  RETURNING id
)
SELECT agency.queue_category_filter_translations('item', id, 'tr') FROM inserted;
