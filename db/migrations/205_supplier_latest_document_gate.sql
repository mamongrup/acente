-- A replaced or expired document cannot be bypassed by an older approval.
CREATE OR REPLACE FUNCTION agency.supplier_application_documents(p_tenant uuid)
RETURNS TABLE(data text[]) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[
    a.id::text,coalesce(d.id::text,''),r.code,coalesce(d.status,'missing'),
    coalesce(d.note,''),coalesce(d.media_id::text,''),
    coalesce(d.reviewed_at::text,''),coalesce(d.reviewed_by::text,''),
    a.status,coalesce(d.document_url,''),coalesce(s.expires_on::text,'')
  ]
  FROM agency.applications a
  CROSS JOIN agency.supplier_onboarding_contract_items r
  LEFT JOIN LATERAL (
    SELECT * FROM agency.application_documents d
    WHERE d.application_id=a.id AND d.document_type=r.code
    ORDER BY d.updated_at DESC,d.id DESC LIMIT 1
  ) d ON true
  LEFT JOIN agency.supplier_documents s ON s.id=d.supplier_document_id
  WHERE a.tenant_id=p_tenant AND a.type='supplier' AND a.status<>'deleted'
    AND r.kind='required_document'
  ORDER BY a.submitted_at DESC,r.position;
$$;

CREATE OR REPLACE FUNCTION agency.decide_supplier_application(
  p_tenant uuid,p_application uuid,p_reviewer uuid,p_decision text,p_note text DEFAULT ''
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_status text; v_identity text; v_decision text:=lower(btrim(coalesce(p_decision,'')));
BEGIN
  IF NOT agency.supplier_review_actor_allowed(p_tenant,p_reviewer) THEN RETURN 'forbidden'; END IF;
  IF v_decision NOT IN ('in_review','approved','rejected','suspended') THEN RETURN 'invalid_decision'; END IF;
  SELECT status,identity_status INTO v_status,v_identity
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
      LEFT JOIN LATERAL (
        SELECT d.status,s.expires_on
        FROM agency.application_documents d
        LEFT JOIN agency.supplier_documents s ON s.id=d.supplier_document_id
        WHERE d.application_id=p_application AND d.document_type=r.code
        ORDER BY d.updated_at DESC,d.id DESC LIMIT 1
      ) latest ON true
      WHERE r.kind='required_document'
        AND (latest.status IS DISTINCT FROM 'approved'
          OR (latest.expires_on IS NOT NULL AND latest.expires_on<current_date))
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
