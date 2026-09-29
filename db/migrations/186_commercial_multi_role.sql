-- Respect tenant-scoped secondary roles in every new commercial operation.
CREATE OR REPLACE FUNCTION agency.has_panel_role(p_tenant uuid,p_actor uuid,p_role text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT EXISTS(
    SELECT 1 FROM agency.users u
    WHERE u.tenant_id=p_tenant AND u.id=p_actor AND u.active
      AND (u.membership_type=p_role OR EXISTS(
        SELECT 1 FROM agency.user_roles ur
        JOIN agency.roles r ON r.id=ur.role_id AND r.tenant_id=p_tenant
        WHERE ur.user_id=u.id AND r.code=p_role))
  )
$$;

CREATE OR REPLACE FUNCTION agency.commercial_admin(p_tenant uuid,p_actor uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT agency.has_panel_role(p_tenant,p_actor,'admin')
$$;

CREATE OR REPLACE FUNCTION agency.start_reservation_service(p_tenant uuid,p_actor uuid,p_reservation uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_listing agency.listings%ROWTYPE; v_status text; v_count integer;
BEGIN
  SELECT r.status INTO v_status FROM agency.reservations r
   WHERE r.tenant_id=p_tenant AND r.id=p_reservation FOR UPDATE;
  IF NOT FOUND OR v_status NOT IN ('confirmed','completed') THEN
    RAISE EXCEPTION 'reservation_not_serviceable';
  END IF;
  SELECT l.* INTO v_listing FROM agency.reservations r
    JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
   WHERE r.tenant_id=p_tenant AND r.id=p_reservation;
  IF NOT FOUND THEN RAISE EXCEPTION 'reservation_listing_missing'; END IF;
  IF NOT (agency.commercial_admin(p_tenant,p_actor) OR
    (agency.has_panel_role(p_tenant,p_actor,'supplier') AND v_listing.owner_user_id=p_actor)) THEN
    RAISE EXCEPTION 'service_access_denied';
  END IF;
  INSERT INTO agency.reservation_service_tasks
    (tenant_id,reservation_id,listing_id,category_code,step_key,stage,title_tr,owner_role,position)
  SELECT p_tenant,p_reservation,v_listing.id,v_listing.category,s.step_key,s.stage,
    s.title_tr,s.owner_role,s.position
  FROM agency.category_service_steps s WHERE s.category_code=v_listing.category
  ON CONFLICT(tenant_id,reservation_id,step_key) DO NOTHING;
  GET DIAGNOSTICS v_count=ROW_COUNT;
  RETURN v_count;
END $$;

CREATE OR REPLACE FUNCTION agency.finish_reservation_service_task(
  p_tenant uuid,p_actor uuid,p_task uuid,p_status text,p_note text DEFAULT ''
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_task agency.reservation_service_tasks%ROWTYPE;
BEGIN
  SELECT * INTO v_task FROM agency.reservation_service_tasks
   WHERE tenant_id=p_tenant AND id=p_task FOR UPDATE;
  IF NOT FOUND OR v_task.status<>'open' OR p_status NOT IN ('done','waived')
     OR length(coalesce(p_note,''))>2000 THEN RAISE EXCEPTION 'invalid_service_task'; END IF;
  IF NOT (agency.commercial_admin(p_tenant,p_actor) OR
    (p_status='done' AND v_task.owner_role='supplier'
     AND agency.has_panel_role(p_tenant,p_actor,'supplier')
     AND EXISTS(SELECT 1 FROM agency.listings l WHERE l.id=v_task.listing_id
       AND l.tenant_id=p_tenant AND l.owner_user_id=p_actor))) THEN RAISE EXCEPTION 'service_access_denied'; END IF;
  UPDATE agency.reservation_service_tasks SET status=p_status,completed_by=p_actor,
    completed_at=now(),note=coalesce(p_note,'') WHERE id=p_task;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'reservation.service_task_'||p_status,'reservation',v_task.reservation_id,
      jsonb_build_object('task',p_task,'step',v_task.step_key));
  RETURN p_task;
END $$;

CREATE OR REPLACE FUNCTION agency.queue_channel_update(
  p_tenant uuid,p_actor uuid,p_channel uuid,p_listing uuid,
  p_event_key text,p_event_type text,p_payload jsonb
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'channel_access_denied'; END IF;
  IF p_event_type NOT IN ('availability','price','restriction','reservation_status')
    OR length(coalesce(p_event_key,'')) NOT BETWEEN 8 AND 180
    OR jsonb_typeof(p_payload)<>'object'
    OR NOT EXISTS(SELECT 1 FROM agency.channel_product_maps m
       JOIN agency.sales_channels c ON c.id=m.channel_id AND c.tenant_id=m.tenant_id
       JOIN agency.listings l ON l.id=m.listing_id AND l.tenant_id=m.tenant_id
       WHERE m.tenant_id=p_tenant AND m.channel_id=p_channel AND m.listing_id=p_listing
         AND m.enabled AND c.mode<>'disabled' AND l.source<>'nexus') THEN
    RAISE EXCEPTION 'channel_mapping_inactive';
  END IF;
  INSERT INTO agency.channel_sync_outbox
    (tenant_id,channel_id,listing_id,event_key,event_type,payload)
  VALUES(p_tenant,p_channel,p_listing,p_event_key,p_event_type,p_payload)
  ON CONFLICT(tenant_id,channel_id,event_key) DO UPDATE
    SET event_key=excluded.event_key
    WHERE agency.channel_sync_outbox.listing_id=excluded.listing_id
      AND agency.channel_sync_outbox.event_type=excluded.event_type
      AND agency.channel_sync_outbox.payload=excluded.payload
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'channel_event_key_conflict'; END IF;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.activate_partner_sales_contract(
  p_tenant uuid,p_actor uuid,p_contract uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_contract agency.partner_sales_contracts%ROWTYPE;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'contract_access_denied'; END IF;
  SELECT * INTO v_contract FROM agency.partner_sales_contracts
    WHERE tenant_id=p_tenant AND id=p_contract FOR UPDATE;
  IF NOT FOUND OR v_contract.status<>'draft' OR v_contract.valid_until<current_date
    OR NOT EXISTS(SELECT 1 FROM agency.partner_contract_products p
       JOIN agency.listings l ON l.id=p.listing_id AND l.tenant_id=p.tenant_id
       WHERE p.tenant_id=p_tenant AND p.contract_id=p_contract AND l.status='published') THEN
    RAISE EXCEPTION 'contract_not_ready';
  END IF;
  UPDATE agency.partner_sales_contracts SET status='active',approved_by=p_actor,
    approved_at=now() WHERE id=p_contract;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'partner.contract_activated','partner_contract',p_contract,
      jsonb_build_object('organization',v_contract.organization_id));
  RETURN p_contract;
END $$;

CREATE OR REPLACE FUNCTION agency.propose_listing_price(
  p_tenant uuid,p_actor uuid,p_listing uuid,p_price bigint,p_reason text,p_evidence jsonb DEFAULT '{}'::jsonb
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_listing agency.listings%ROWTYPE; v_id uuid;
BEGIN
  SELECT * INTO v_listing FROM agency.listings
    WHERE tenant_id=p_tenant AND id=p_listing FOR UPDATE;
  IF NOT FOUND OR v_listing.source='nexus' OR p_price IS NULL OR p_price<0
    OR p_price=v_listing.price_minor OR length(trim(coalesce(p_reason,''))) NOT BETWEEN 10 AND 2000
    OR jsonb_typeof(p_evidence)<>'object' THEN RAISE EXCEPTION 'invalid_price_proposal'; END IF;
  IF NOT (agency.commercial_admin(p_tenant,p_actor) OR
    (agency.has_panel_role(p_tenant,p_actor,'supplier') AND v_listing.owner_user_id=p_actor)) THEN
    RAISE EXCEPTION 'price_access_denied'; END IF;
  INSERT INTO agency.listing_price_proposals
    (tenant_id,listing_id,baseline_minor,proposed_minor,currency,reason,evidence,proposed_by)
  VALUES(p_tenant,p_listing,v_listing.price_minor,p_price,v_listing.currency,
    p_reason,p_evidence,p_actor) RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.review_listing_price(
  p_tenant uuid,p_actor uuid,p_proposal uuid,p_decision text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_proposal agency.listing_price_proposals%ROWTYPE; v_listing agency.listings%ROWTYPE;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'price_review_denied'; END IF;
  SELECT * INTO v_proposal FROM agency.listing_price_proposals
    WHERE tenant_id=p_tenant AND id=p_proposal FOR UPDATE;
  IF NOT FOUND OR v_proposal.status<>'pending' OR p_decision NOT IN ('approved','rejected')
    THEN RAISE EXCEPTION 'invalid_price_review'; END IF;
  SELECT * INTO v_listing FROM agency.listings
    WHERE tenant_id=p_tenant AND id=v_proposal.listing_id FOR UPDATE;
  IF NOT FOUND OR v_listing.source='nexus' OR v_listing.currency<>v_proposal.currency
    OR v_listing.price_minor<>v_proposal.baseline_minor THEN
    UPDATE agency.listing_price_proposals SET status='stale',reviewed_by=p_actor,
      reviewed_at=now() WHERE id=p_proposal;
    RETURN p_proposal;
  END IF;
  IF p_decision='approved' THEN
    UPDATE agency.listings SET price_minor=v_proposal.proposed_minor,updated_at=now()
      WHERE id=v_listing.id AND tenant_id=p_tenant;
  END IF;
  UPDATE agency.listing_price_proposals SET status=p_decision,reviewed_by=p_actor,
    reviewed_at=now() WHERE id=p_proposal;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'pricing.proposal_'||p_decision,'listing',v_listing.id,
      jsonb_build_object('proposal',p_proposal,'old',v_proposal.baseline_minor,
        'new',v_proposal.proposed_minor));
  RETURN p_proposal;
END $$;

CREATE OR REPLACE FUNCTION agency.activate_partner_bonus_campaign(
  p_tenant uuid,p_actor uuid,p_campaign uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'bonus_access_denied'; END IF;
  UPDATE agency.partner_bonus_campaigns SET status='active',approved_by=p_actor
    WHERE tenant_id=p_tenant AND id=p_campaign AND status='draft' AND ends_on>=current_date;
  IF NOT FOUND THEN RAISE EXCEPTION 'bonus_campaign_not_ready'; END IF;
  RETURN p_campaign;
END $$;

REVOKE ALL ON FUNCTION agency.has_panel_role(uuid,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.has_panel_role(uuid,uuid,text) TO agency_app;
