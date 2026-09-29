BEGIN;
DO $$
DECLARE
  v_tenant uuid;
  v_foreign_tenant uuid;
  v_listing uuid;
  v_inquiry uuid;
  v_rejected boolean;
BEGIN
  SELECT id INTO STRICT v_tenant FROM agency.tenants WHERE slug='nexus-demo';
  SELECT id INTO STRICT v_foreign_tenant FROM agency.tenants WHERE slug='test-agency';
  SELECT id INTO STRICT v_listing FROM agency.listings
    WHERE tenant_id=v_foreign_tenant AND status='published' LIMIT 1;
  v_rejected:=false;
  BEGIN
    INSERT INTO agency.public_inquiries(tenant_id,listing_id,full_name,email)
    VALUES(v_tenant,v_listing,'Scope Test','scope@example.invalid');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM<>'inquiry_listing_scope' THEN RAISE; END IF;
    v_rejected:=true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'foreign_listing_inquiry_accepted'; END IF;

  INSERT INTO agency.public_inquiries(tenant_id,listing_id,full_name,email)
  VALUES(v_foreign_tenant,v_listing,'Scope Test','scope@example.invalid')
  RETURNING id INTO v_inquiry;
  v_rejected:=false;
  BEGIN
    UPDATE agency.public_inquiries SET tenant_id=v_tenant WHERE id=v_inquiry;
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM<>'inquiry_listing_scope' THEN RAISE; END IF;
    v_rejected:=true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'foreign_tenant_inquiry_update_accepted'; END IF;
  INSERT INTO agency.public_inquiries(tenant_id,full_name,email)
  VALUES(v_tenant,'General Scope Test','general@example.invalid');
  RAISE NOTICE 'public inquiry listing scope passed';
END $$;
ROLLBACK;
