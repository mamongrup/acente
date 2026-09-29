-- A scheduled run is not a delivery. Evaluate a narrow, explicit email
-- audience before any future channel executor is allowed to enqueue mail.
CREATE OR REPLACE FUNCTION agency.ai_campaign_preflight(p_tenant uuid, p_run uuid)
RETURNS TABLE(ready boolean, reason text, eligible_count integer)
LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $$
DECLARE
  v_run agency.ai_campaign_runs%ROWTYPE;
  v_count integer;
  v_requested integer;
BEGIN
  SELECT * INTO v_run FROM agency.ai_campaign_runs
    WHERE id=p_run AND tenant_id=p_tenant;
  IF NOT FOUND THEN RETURN QUERY SELECT false,'run_not_found',0; RETURN; END IF;
  IF v_run.status <> 'scheduled' OR v_run.scheduled_at IS NULL
     OR v_run.scheduled_at > now() THEN
    RETURN QUERY SELECT false,'not_due',0; RETURN;
  END IF;
  IF v_run.channel <> 'email' THEN
    RETURN QUERY SELECT false,'channel_executor_unavailable',0; RETURN;
  END IF;
  IF v_run.campaign_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM agency.campaigns c WHERE c.id=v_run.campaign_id
      AND c.tenant_id=p_tenant AND c.active
      AND (c.starts_at IS NULL OR c.starts_at<=now())
      AND (c.ends_at IS NULL OR c.ends_at>=now())
  ) THEN
    RETURN QUERY SELECT false,'campaign_inactive',0; RETURN;
  END IF;
  IF jsonb_typeof(v_run.audience->'user_ids') IS DISTINCT FROM 'array'
     OR jsonb_array_length(v_run.audience->'user_ids')=0
     OR jsonb_typeof(v_run.offer->'message') IS DISTINCT FROM 'string'
     OR length(btrim(v_run.offer->>'message'))=0 THEN
    RETURN QUERY SELECT false,'audience_or_offer_missing',0; RETURN;
  END IF;
  SELECT count(*) INTO v_requested FROM jsonb_array_elements_text(v_run.audience->'user_ids');
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements_text(v_run.audience->'user_ids') ids(value)
    WHERE ids.value !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ) THEN
    RETURN QUERY SELECT false,'invalid_audience_id',0; RETURN;
  END IF;
  SELECT count(DISTINCT u.id) INTO v_count
  FROM jsonb_array_elements_text(v_run.audience->'user_ids') ids(value)
  JOIN agency.users u ON u.id::text=ids.value AND u.tenant_id=p_tenant AND u.active
  JOIN agency.customer_notification_preferences pref
    ON pref.user_id=u.id AND pref.tenant_id=p_tenant AND pref.marketing_email=true
  WHERE nullif(btrim(u.email),'') IS NOT NULL;
  IF v_count<>v_requested THEN
    RETURN QUERY SELECT false,'audience_consent_missing',v_count; RETURN;
  END IF;
  RETURN QUERY SELECT true,'ready',v_count;
END $$;

REVOKE ALL ON FUNCTION agency.ai_campaign_preflight(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.ai_campaign_preflight(uuid,uuid) TO agency_app;
