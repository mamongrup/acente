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
  -- Self-seeding: 'test-agency' kiraci taze kurulumda yoksa tohumlanir;
  -- yayinlanmis ilani da baska bir tenant'in gecerli ilanindan kopyalanir.
  SELECT id INTO v_foreign_tenant FROM agency.tenants WHERE slug='test-agency';
  IF NOT FOUND THEN
    INSERT INTO agency.tenants(legal_name,brand_name,slug)
      VALUES('Test Agency','Test Agency','test-agency')
      RETURNING id INTO v_foreign_tenant;
  END IF;
  BEGIN
    SELECT id INTO STRICT v_listing FROM agency.listings
      WHERE tenant_id=v_foreign_tenant AND status='published' LIMIT 1;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    INSERT INTO agency.listings(tenant_id,code,category,title,locality,description,currency,price_minor,status,source,images,owner_info,cancellation_policy,metadata)
    SELECT v_foreign_tenant,'seed-scope-'||gen_random_uuid()::text,category,title,locality,description,currency,price_minor,'published','manual',images,owner_info,cancellation_policy,metadata
    FROM agency.listings l WHERE l.status='published'
      AND NOT EXISTS(SELECT 1 FROM agency.validate_listing_common_contract(l))
      AND NOT EXISTS(SELECT 1 FROM agency.validate_listing_contract(l.tenant_id,l.category,l.metadata))
    ORDER BY l.created_at LIMIT 1
    RETURNING id INTO v_listing;
  END;
  IF v_listing IS NULL THEN RAISE EXCEPTION 'valid published listing fixture missing'; END IF;
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
