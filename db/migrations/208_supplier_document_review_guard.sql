-- Only real supplier uploads can be accepted. Revoking an accepted document
-- suspends an already approved supplier application immediately.
CREATE OR REPLACE FUNCTION agency.decide_supplier_application_document(
  p_tenant uuid,p_document uuid,p_reviewer uuid,p_decision text,p_note text DEFAULT ''
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
  v_decision text:=lower(btrim(coalesce(p_decision,'')));
  v_application uuid; v_old_status text; v_app_status text;
  v_supplier uuid; v_type text; v_source uuid; v_valid boolean;
BEGIN
  IF NOT agency.supplier_review_actor_allowed(p_tenant,p_reviewer) THEN RETURN 'forbidden'; END IF;
  IF v_decision NOT IN ('approved','rejected','pending') THEN RETURN 'invalid_decision'; END IF;
  SELECT d.application_id,d.status,a.status,a.user_id,d.document_type,d.supplier_document_id,
    s.id IS NOT NULL AND s.tenant_id=p_tenant AND s.supplier_user_id=a.user_id
      AND s.document_type=d.document_type AND s.document_url ~ '^https://[^[:space:]]+$'
      AND (s.expires_on IS NULL OR s.expires_on>=current_date)
  INTO v_application,v_old_status,v_app_status,v_supplier,v_type,v_source,v_valid
  FROM agency.application_documents d
  JOIN agency.applications a ON a.id=d.application_id
  LEFT JOIN agency.supplier_documents s ON s.id=d.supplier_document_id
  WHERE d.id=p_document AND a.tenant_id=p_tenant AND a.type='supplier' AND a.status<>'deleted'
  FOR UPDATE OF d;
  IF v_application IS NULL THEN RETURN 'not_found'; END IF;
  IF v_decision='approved' AND v_valid IS DISTINCT FROM true THEN RETURN 'document_invalid'; END IF;
  UPDATE agency.application_documents SET status=v_decision,
    note=coalesce(nullif(btrim(p_note),''),note),
    reviewed_at=CASE WHEN v_decision IN ('approved','rejected') THEN now() ELSE NULL END,
    reviewed_by=CASE WHEN v_decision IN ('approved','rejected') THEN p_reviewer ELSE NULL END,
    updated_at=clock_timestamp()
  WHERE id=p_document;
  UPDATE agency.applications SET
    status=CASE WHEN status='submitted' THEN 'in_review'
      WHEN status='approved' AND v_decision<>'approved' THEN 'suspended' ELSE status END,
    reviewed_by=p_reviewer,updated_at=now()
  WHERE id=v_application AND tenant_id=p_tenant;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
  VALUES(p_tenant,p_reviewer,'supplier_application_document.'||v_decision,'application_document',p_document,
    jsonb_build_object('application_id',v_application,'previous_status',v_old_status,
      'decision',v_decision,'note',coalesce(p_note,'')));
  RETURN 'ok';
END $$;

CREATE OR REPLACE FUNCTION agency.suspend_supplier_application_on_document_loss()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NEW.status<>'approved' AND OLD.status='approved'
    AND EXISTS(SELECT 1 FROM agency.supplier_onboarding_contract_items
      WHERE kind='required_document' AND code=NEW.document_type)
  THEN
    UPDATE agency.applications SET status='suspended',updated_at=now()
    WHERE id=NEW.application_id AND type='supplier' AND status='approved';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS supplier_application_document_loss ON agency.application_documents;
CREATE TRIGGER supplier_application_document_loss AFTER UPDATE OF status ON agency.application_documents
FOR EACH ROW WHEN (NEW.status IS DISTINCT FROM OLD.status)
EXECUTE FUNCTION agency.suspend_supplier_application_on_document_loss();

REVOKE ALL ON FUNCTION agency.decide_supplier_application_document(uuid,uuid,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.decide_supplier_application_document(uuid,uuid,uuid,text,text) TO agency_app;
