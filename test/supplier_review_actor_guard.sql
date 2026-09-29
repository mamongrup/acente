BEGIN;

DO $$
BEGIN
  IF to_regprocedure('agency.decide_supplier_application_unchecked(uuid,uuid,uuid,text,text)') IS NOT NULL
    OR to_regprocedure('agency.decide_supplier_application_document_unchecked(uuid,uuid,uuid,text,text)') IS NOT NULL
  THEN RAISE EXCEPTION 'unchecked supplier review bypass remains'; END IF;
END $$;

DO $$
DECLARE
  tenant_one uuid := gen_random_uuid();
  tenant_two uuid := gen_random_uuid();
  admin_one uuid := gen_random_uuid();
  supplier_one uuid := gen_random_uuid();
  staff_one uuid := gen_random_uuid();
  admin_two uuid := gen_random_uuid();
  admin_role uuid := gen_random_uuid();
  application_one uuid := gen_random_uuid();
  document_one uuid := gen_random_uuid();
BEGIN
  INSERT INTO agency.tenants(id,legal_name,brand_name,slug)
  VALUES (tenant_one,'Review test','Review test','review-test-' || replace(tenant_one::text,'-','')),
         (tenant_two,'Other review test','Other review test','review-test-' || replace(tenant_two::text,'-',''));
  INSERT INTO agency.users(id,tenant_id,email,display_name,membership_type)
  VALUES (admin_one,tenant_one,'admin@example.invalid','Admin','admin'),
         (supplier_one,tenant_one,'supplier@example.invalid','Supplier','supplier'),
         (staff_one,tenant_one,'staff@example.invalid','Staff','staff'),
         (admin_two,tenant_two,'other-admin@example.invalid','Other Admin','admin');
  INSERT INTO agency.roles(id,tenant_id,code,name)
  VALUES (admin_role,tenant_one,'admin','Admin');
  INSERT INTO agency.user_roles(user_id,role_id) VALUES (staff_one,admin_role);
  INSERT INTO agency.applications(id,tenant_id,user_id,type,status)
  VALUES (application_one,tenant_one,supplier_one,'supplier','submitted');
  INSERT INTO agency.application_documents(id,application_id,document_type)
  VALUES (document_one,application_one,'tax_certificate');

  IF agency.decide_supplier_application(tenant_one,application_one,supplier_one,'approved','') <> 'forbidden'
    OR agency.decide_supplier_application_document(tenant_one,document_one,supplier_one,'approved','') <> 'forbidden'
    OR agency.decide_supplier_application(tenant_one,application_one,admin_two,'approved','') <> 'forbidden'
    OR agency.decide_supplier_application_document(tenant_one,document_one,admin_two,'approved','') <> 'forbidden'
  THEN RAISE EXCEPTION 'supplier or cross-tenant reviewer was accepted'; END IF;

  IF agency.decide_supplier_application(tenant_one,application_one,admin_one,'in_review','') <> 'ok'
  THEN RAISE EXCEPTION 'authorized application review start failed'; END IF;
  IF agency.decide_supplier_application_document(tenant_one,document_one,staff_one,'approved','') <> 'document_invalid'
  THEN RAISE EXCEPTION 'document without supplier upload was approved'; END IF;
  IF agency.decide_supplier_application(tenant_one,application_one,admin_one,'approved','') <> 'requirements_incomplete'
  THEN RAISE EXCEPTION 'incomplete application was approved'; END IF;

  IF (SELECT status FROM agency.applications WHERE id=application_one) <> 'in_review'
    OR (SELECT status FROM agency.application_documents WHERE id=document_one) <> 'pending'
  THEN RAISE EXCEPTION 'supplier review state was not applied'; END IF;
END $$;

ROLLBACK;
