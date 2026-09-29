BEGIN;
DO $$
DECLARE
  v_tenant uuid;
  v_admin uuid;
  v_supplier uuid;
  v_application uuid;
  v_document uuid;
  v_application_document uuid;
  v_code text;
  v_result text;
  v_data jsonb;
BEGIN
  SELECT tenant_id INTO v_tenant FROM agency.categories
  WHERE code='hotel' AND parent_id IS NULL ORDER BY tenant_id LIMIT 1;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'hotel category fixture missing'; END IF;
  INSERT INTO agency.users(tenant_id,email,display_name,membership_type)
  VALUES(v_tenant,'review-'||gen_random_uuid()||'@example.invalid','Review Admin','admin')
  RETURNING id INTO v_admin;
  INSERT INTO agency.users(tenant_id,email,display_name,membership_type)
  VALUES(v_tenant,'supplier-'||gen_random_uuid()||'@example.invalid','Supplier Test','supplier')
  RETURNING id INTO v_supplier;

  v_data:=jsonb_build_object(
    'supplier_type','company','legal_name','Supplier Test Ltd','display_name','Supplier Test',
    'tax_country','TR','tax_office','Test Office','tax_number','1234567890',
    'authorized_person_name','Test Person','authorized_person_email','person@example.invalid',
    'authorized_person_phone','5550000000','business_category_codes','hotel',
    'service_regions','Istanbul','default_currency','TRY','invoice_address','Test Address',
    'support_email','support@example.invalid','support_phone','5550000001'
  );
  v_application:=agency.submit_supplier_application(v_tenant,v_supplier,'hotel',v_data);
  IF agency.submit_supplier_application(v_tenant,v_supplier,'hotel',v_data)<>v_application THEN
    RAISE EXCEPTION 'application submission not idempotent';
  END IF;
  IF agency.decide_supplier_application(v_tenant,v_application,v_admin,'approved','')<>'requirements_incomplete' THEN
    RAISE EXCEPTION 'approval allowed without identity and documents';
  END IF;
  IF agency.review_supplier_identity(v_tenant,v_application,v_admin,'verified','Manual identity evidence checked')<>'ok' THEN
    RAISE EXCEPTION 'identity review failed';
  END IF;
  IF agency.decide_supplier_application(v_tenant,v_application,v_admin,'approved','')<>'requirements_incomplete' THEN
    RAISE EXCEPTION 'approval allowed without documents';
  END IF;
  INSERT INTO agency.application_documents(application_id,document_type,status)
  SELECT v_application,code,'approved' FROM agency.supplier_onboarding_contract_items
  WHERE kind='required_document';
  IF agency.decide_supplier_application(v_tenant,v_application,v_admin,'approved','')<>'requirements_incomplete' THEN
    RAISE EXCEPTION 'unlinked document rows allowed approval';
  END IF;
  FOR v_code IN SELECT code FROM agency.supplier_onboarding_contract_items WHERE kind='required_document' LOOP
    v_document:=agency.submit_supplier_document(v_tenant,v_supplier,v_code,'https://example.invalid/document/'||v_code,NULL);
    SELECT id INTO v_application_document FROM agency.application_documents
    WHERE application_id=v_application AND supplier_document_id=v_document;
    IF v_application_document IS NULL THEN RAISE EXCEPTION 'document not linked: %',v_code; END IF;
    v_result:=agency.decide_supplier_application_document(v_tenant,v_application_document,v_admin,'approved','reviewed');
    IF v_result<>'ok' OR NOT EXISTS(SELECT 1 FROM agency.supplier_documents WHERE id=v_document AND status='approved') THEN
      RAISE EXCEPTION 'document review not synchronized: %',v_code;
    END IF;
  END LOOP;
  v_document:=agency.submit_supplier_document(v_tenant,v_supplier,'tax_certificate','https://example.invalid/document/tax_certificate-replacement',NULL);
  SELECT id INTO v_application_document FROM agency.application_documents
  WHERE application_id=v_application AND supplier_document_id=v_document;
  IF agency.decide_supplier_application(v_tenant,v_application,v_admin,'approved','')<>'requirements_incomplete' THEN
    RAISE EXCEPTION 'old approved document bypassed newer pending document';
  END IF;
  IF agency.decide_supplier_application_document(v_tenant,v_application_document,v_admin,'approved','reviewed')<>'ok' THEN
    RAISE EXCEPTION 'replacement document review failed';
  END IF;
  IF agency.decide_supplier_application(v_tenant,v_application,v_admin,'approved','')<>'ok' THEN
    RAISE EXCEPTION 'complete application not approved';
  END IF;
  IF agency.review_supplier_identity(v_tenant,v_application,v_admin,'verified','Manual identity evidence checked')<>'invalid_transition' THEN
    RAISE EXCEPTION 'approved identity unexpectedly mutable';
  END IF;
  SELECT id INTO v_application_document FROM agency.application_documents
  WHERE application_id=v_application AND document_type='authorized_signature'
  ORDER BY revision DESC LIMIT 1;
  v_result:=agency.decide_supplier_application_document(v_tenant,v_application_document,v_admin,'rejected','renewal required');
  IF v_result<>'ok' OR (SELECT status FROM agency.applications WHERE id=v_application)<>'suspended' THEN
    RAISE EXCEPTION 'revoked document did not suspend approved application';
  END IF;
  IF agency.decide_supplier_application_document(v_tenant,v_application_document,v_admin,'approved','reviewed again')<>'ok'
    OR agency.decide_supplier_application(v_tenant,v_application,v_admin,'approved','')<>'ok' THEN
    RAISE EXCEPTION 'document restoration did not allow reapproval';
  END IF;
  UPDATE agency.supplier_documents SET expires_on=current_date-1
  WHERE id=(SELECT supplier_document_id FROM agency.application_documents
    WHERE application_id=v_application AND document_type='authorized_signature'
    ORDER BY updated_at DESC,id DESC LIMIT 1);
  v_result:=agency.suspend_expired_supplier_applications(v_tenant,v_admin)::text;
  IF v_result::integer<1
    OR (SELECT status FROM agency.applications WHERE id=v_application)<>'suspended' THEN
    RAISE EXCEPTION 'expired document did not auto-suspend application';
  END IF;
  IF agency.suspend_expired_supplier_applications(v_tenant,v_admin)<>0 THEN
    RAISE EXCEPTION 'expiry suspension was not idempotent';
  END IF;
  IF agency.decide_supplier_application(v_tenant,v_application,v_admin,'approved','')<>'requirements_incomplete' THEN
    RAISE EXCEPTION 'expired document allowed reapproval';
  END IF;
END $$;
ROLLBACK;
