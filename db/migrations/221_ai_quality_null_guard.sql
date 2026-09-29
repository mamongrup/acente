-- SQL three-valued logic must not turn a missing model output into a pass.
CREATE OR REPLACE FUNCTION agency.ai_quality_text_rules(p_expected jsonb, p_actual jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
DECLARE
  v_text text;
  v_key text;
  v_rule jsonb;
  v_item jsonb;
BEGIN
  IF p_expected IS NULL OR p_actual IS NULL
     OR jsonb_typeof(p_expected) <> 'object'
     OR p_expected = '{}'::jsonb
     OR jsonb_typeof(p_actual) <> 'object'
     OR jsonb_typeof(p_actual->'text') <> 'string' THEN
    RETURN NULL;
  END IF;
  v_text := p_actual->>'text';
  FOR v_key IN SELECT jsonb_object_keys(p_expected) LOOP
    IF v_key NOT IN ('contains','not_contains','max_length') THEN RETURN NULL; END IF;
    v_rule := p_expected->v_key;
    IF v_key IN ('contains','not_contains') THEN
      IF jsonb_typeof(v_rule) <> 'array' THEN RETURN NULL; END IF;
      FOR v_item IN SELECT value FROM jsonb_array_elements(v_rule) LOOP
        IF jsonb_typeof(v_item) <> 'string' THEN RETURN NULL; END IF;
      END LOOP;
    ELSIF jsonb_typeof(v_rule) <> 'number'
       OR (v_rule #>> '{}') !~ '^[0-9]{1,8}$' THEN
      RETURN NULL;
    END IF;
  END LOOP;
  IF p_expected ? 'contains' THEN
    FOR v_item IN SELECT value FROM jsonb_array_elements(p_expected->'contains') LOOP
      IF position(v_item #>> '{}' IN v_text) = 0 THEN RETURN false; END IF;
    END LOOP;
  END IF;
  IF p_expected ? 'not_contains' THEN
    FOR v_item IN SELECT value FROM jsonb_array_elements(p_expected->'not_contains') LOOP
      IF position(v_item #>> '{}' IN v_text) > 0 THEN RETURN false; END IF;
    END LOOP;
  END IF;
  IF p_expected ? 'max_length'
     AND char_length(v_text) > (p_expected->>'max_length')::integer THEN
    RETURN false;
  END IF;
  RETURN true;
END $$;
