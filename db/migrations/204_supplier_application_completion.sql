-- Join the existing supplier document workflow to applications and require
-- verified identity plus accepted contract documents before approval.
ALTER TABLE agency.application_documents
  ADD COLUMN IF NOT EXISTS document_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS supplier_document_id uuid REFERENCES agency.supplier_documents(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS application_supplier_document_unique
  ON agency.application_documents(application_id,supplier_document_id)
  WHERE supplier_document_id IS NOT NULL;

CREATE OR REPLACE FUNCTION agency.submit_supplier_application(
  p_tenant uuid,p_actor uuid,p_category text,p_data jsonb
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid; v_field record;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM agency.users u WHERE u.id=p_actor AND u.tenant_id=p_tenant AND u.active
      AND (u.membership_type='supplier' OR EXISTS (
        SELECT 1 FROM agency.user_roles ur JOIN agency.roles r ON r.id=ur.role_id
        WHERE ur.user_id=u.id AND r.tenant_id=p_tenant AND r.code='supplier'
      ))
  ) OR NOT EXISTS (
    SELECT 1 FROM agency.categories c WHERE c.tenant_id=p_tenant AND c.code=p_category
      AND c.parent_id IS NULL AND c.active
  ) OR jsonb_typeof(p_data)<>'object' THEN
    RAISE EXCEPTION 'invalid_supplier_application';
  END IF;
  FOR v_field IN SELECT code FROM agency.supplier_onboarding_contract_items
    WHERE kind IN ('identity_field','business_field') LOOP
    IF length(btrim(coalesce(p_data->>v_field.code,'')))<2 THEN
      RAISE EXCEPTION 'missing_supplier_field:%',v_field.code;
    END IF;
  END LOOP;
  IF p_data->>'business_category_codes'<>p_category
    OR p_data->>'authorized_person_email' !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    OR p_data->>'support_email' !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  THEN RAISE EXCEPTION 'invalid_supplier_application'; END IF;

  PERFORM pg_advisory_xact_lock(hashtext(p_tenant::text),hashtext(p_actor::text||p_category));
  SELECT id INTO v_id FROM agency.applications
    WHERE tenant_id=p_tenant AND user_id=p_actor AND type='supplier'
      AND category_code=p_category AND status NOT IN ('rejected','deleted')
    ORDER BY submitted_at DESC LIMIT 1;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;

  INSERT INTO agency.applications(tenant_id,user_id,type,status,category_code,contract_data)
  VALUES(p_tenant,p_actor,'supplier','submitted',p_category,p_data)
  RETURNING id INTO v_id;
  INSERT INTO agency.application_category_requests(application_id,category_code)
  VALUES(v_id,p_category) ON CONFLICT DO NOTHING;
  INSERT INTO agency.application_documents(application_id,document_type,document_url,supplier_document_id,status)
  SELECT v_id,d.document_type,d.document_url,d.id,d.status
  FROM agency.supplier_documents d
  WHERE d.tenant_id=p_tenant AND d.supplier_user_id=p_actor
    AND d.document_type IN (SELECT code FROM agency.supplier_onboarding_contract_items WHERE kind='required_document')
  ON CONFLICT(application_id,supplier_document_id) WHERE supplier_document_id IS NOT NULL DO NOTHING;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
  VALUES(p_tenant,p_actor,'supplier_application.submitted','application',v_id,jsonb_build_object('category',p_category));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.link_supplier_document_to_application()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF TG_OP='INSERT' THEN
    INSERT INTO agency.application_documents(application_id,document_type,document_url,supplier_document_id,status)
    SELECT a.id,NEW.document_type,NEW.document_url,NEW.id,NEW.status
    FROM agency.applications a WHERE a.tenant_id=NEW.tenant_id AND a.user_id=NEW.supplier_user_id
      AND a.type='supplier' AND a.status IN ('submitted','in_review','approved','suspended')
    ON CONFLICT(application_id,supplier_document_id) WHERE supplier_document_id IS NOT NULL DO NOTHING;
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    UPDATE agency.application_documents SET status=NEW.status,note=NEW.review_note,
      reviewed_at=NEW.reviewed_at,reviewed_by=NEW.reviewed_by,updated_at=now()
    WHERE supplier_document_id=NEW.id AND status IS DISTINCT FROM NEW.status;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS supplier_document_application_link ON agency.supplier_documents;
CREATE TRIGGER supplier_document_application_link AFTER INSERT OR UPDATE OF status ON agency.supplier_documents
FOR EACH ROW EXECUTE FUNCTION agency.link_supplier_document_to_application();

CREATE OR REPLACE FUNCTION agency.sync_application_document_review()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NEW.supplier_document_id IS NOT NULL AND NEW.status IS DISTINCT FROM OLD.status THEN
    UPDATE agency.supplier_documents SET status=NEW.status,review_note=NEW.note,
      reviewed_at=NEW.reviewed_at,reviewed_by=NEW.reviewed_by
    WHERE id=NEW.supplier_document_id AND status IS DISTINCT FROM NEW.status;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS application_document_supplier_review ON agency.application_documents;
CREATE TRIGGER application_document_supplier_review AFTER UPDATE OF status ON agency.application_documents
FOR EACH ROW EXECUTE FUNCTION agency.sync_application_document_review();

CREATE OR REPLACE FUNCTION agency.review_supplier_identity(
  p_tenant uuid,p_application uuid,p_reviewer uuid,p_result text,p_note text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_status text;
BEGIN
  IF NOT agency.supplier_review_actor_allowed(p_tenant,p_reviewer) THEN RETURN 'forbidden'; END IF;
  IF p_result NOT IN ('verified','manual_review','failed') OR length(btrim(coalesce(p_note,''))) NOT BETWEEN 10 AND 1000 THEN
    RETURN 'invalid_decision';
  END IF;
  SELECT status INTO v_status FROM agency.applications
  WHERE id=p_application AND tenant_id=p_tenant AND type='supplier' FOR UPDATE;
  IF NOT FOUND THEN RETURN 'not_found'; END IF;
  IF v_status NOT IN ('submitted','in_review') THEN RETURN 'invalid_transition'; END IF;
  UPDATE agency.applications SET identity_status=p_result,status='in_review',updated_at=now()
  WHERE id=p_application;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
  VALUES(p_tenant,p_reviewer,'supplier_application.identity_'||p_result,'application',p_application,
    jsonb_build_object('evidence_note',btrim(p_note)));
  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION agency.supplier_application_documents(p_tenant uuid)
RETURNS TABLE(data text[]) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    a.id::text,coalesce(d.id::text,''),r.code,coalesce(d.status,'missing'),
    coalesce(d.note,''),coalesce(d.media_id::text,''),
    coalesce(d.reviewed_at::text,''),coalesce(d.reviewed_by::text,''),
    a.status,coalesce(d.document_url,'')
  ]
  FROM agency.applications a
  CROSS JOIN agency.supplier_onboarding_contract_items r
  LEFT JOIN LATERAL (
    SELECT * FROM agency.application_documents d
    WHERE d.application_id=a.id AND d.document_type=r.code
    ORDER BY d.updated_at DESC,d.id DESC LIMIT 1
  ) d ON true
  WHERE a.tenant_id=p_tenant AND a.type='supplier' AND a.status<>'deleted'
    AND r.kind='required_document'
  ORDER BY a.submitted_at DESC,r.position;
$$;

CREATE OR REPLACE FUNCTION agency.decide_supplier_application(
  p_tenant uuid,p_application uuid,p_reviewer uuid,p_decision text,p_note text DEFAULT ''
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_status text; v_identity text; v_user uuid; v_category text; v_decision text:=lower(btrim(coalesce(p_decision,'')));
BEGIN
  IF NOT agency.supplier_review_actor_allowed(p_tenant,p_reviewer) THEN RETURN 'forbidden'; END IF;
  IF v_decision NOT IN ('in_review','approved','rejected','suspended') THEN RETURN 'invalid_decision'; END IF;
  SELECT status,identity_status,user_id,category_code INTO v_status,v_identity,v_user,v_category
  FROM agency.applications WHERE id=p_application AND tenant_id=p_tenant AND type='supplier'
    AND status<>'deleted' FOR UPDATE;
  IF NOT FOUND THEN RETURN 'not_found'; END IF;
  IF (v_decision='in_review' AND v_status NOT IN ('draft','submitted','rejected'))
    OR (v_decision='approved' AND v_status NOT IN ('submitted','in_review','suspended'))
    OR (v_decision='rejected' AND v_status NOT IN ('submitted','in_review'))
    OR (v_decision='suspended' AND v_status<>'approved') THEN RETURN 'invalid_transition'; END IF;
  IF v_decision='approved' THEN
    IF v_identity<>'verified' OR EXISTS (
      SELECT 1 FROM agency.supplier_onboarding_contract_items r
      WHERE r.kind='required_document' AND NOT EXISTS (
        SELECT 1 FROM agency.application_documents d
        LEFT JOIN agency.supplier_documents s ON s.id=d.supplier_document_id
        WHERE d.application_id=p_application AND d.document_type=r.code AND d.status='approved'
          AND (s.id IS NULL OR s.expires_on IS NULL OR s.expires_on>=current_date)
      )
    ) THEN RETURN 'requirements_incomplete'; END IF;
  END IF;
  UPDATE agency.applications SET status=v_decision,
    reviewed_at=CASE WHEN v_decision IN ('approved','rejected','suspended') THEN now() ELSE reviewed_at END,
    reviewed_by=p_reviewer,note=coalesce(nullif(btrim(p_note),''),note),updated_at=now()
  WHERE id=p_application;
  UPDATE agency.application_category_requests SET
    status=CASE WHEN v_decision IN ('approved','rejected','suspended') THEN v_decision ELSE 'in_review' END,
    reviewed_at=CASE WHEN v_decision IN ('approved','rejected','suspended') THEN now() ELSE reviewed_at END,
    reviewed_by=p_reviewer,note=coalesce(nullif(btrim(p_note),''),note)
  WHERE application_id=p_application;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
  VALUES(p_tenant,p_reviewer,'supplier_application.'||v_decision,'application',p_application,
    jsonb_build_object('previous_status',v_status,'decision',v_decision,'note',coalesce(p_note,'')));
  RETURN 'ok';
END $$;

REVOKE ALL ON FUNCTION agency.submit_supplier_application(uuid,uuid,text,jsonb),agency.review_supplier_identity(uuid,uuid,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.submit_supplier_application(uuid,uuid,text,jsonb),agency.review_supplier_identity(uuid,uuid,uuid,text,text) TO agency_app;
