ALTER TABLE agency.supplier_documents DROP CONSTRAINT IF EXISTS supplier_documents_document_url_check;
ALTER TABLE agency.supplier_documents ADD CONSTRAINT supplier_documents_document_url_check
  CHECK (document_url ~ '^https://[^[:space:]]+$' AND length(document_url) BETWEEN 14 AND 1008);

CREATE OR REPLACE FUNCTION agency.submit_supplier_document(p_tenant uuid,p_actor uuid,p_type text,p_url text,p_expires date)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM agency.users u WHERE u.id=p_actor AND u.tenant_id=p_tenant AND u.active
    AND (u.membership_type='supplier' OR EXISTS(SELECT 1 FROM agency.user_roles ur JOIN agency.roles r ON r.id=ur.role_id WHERE ur.user_id=u.id AND r.tenant_id=p_tenant AND r.code='supplier')))
     OR NOT EXISTS (SELECT 1 FROM agency.supplier_onboarding_contract_items WHERE kind='required_document' AND code=p_type)
     OR p_url !~ '^https://[^[:space:]]+$' OR length(p_url) NOT BETWEEN 14 AND 1008
     OR (p_expires IS NOT NULL AND p_expires<current_date)
  THEN RAISE EXCEPTION 'invalid_supplier_document'; END IF;
  INSERT INTO agency.supplier_documents(tenant_id,supplier_user_id,document_type,document_url,expires_on)
    VALUES(p_tenant,p_actor,p_type,p_url,p_expires) RETURNING id INTO v_id;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'supplier.document_submitted','supplier_document',v_id,jsonb_build_object('type',p_type,'expiresOn',p_expires));
  RETURN v_id;
END $$;
