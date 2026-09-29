-- Verification script for marketplace multi-domain self-service listing flow
DO $$
DECLARE
  v_tenant uuid;
  v_user uuid;
  v_sub_id uuid;
  v_listing_id uuid;
BEGIN
  SELECT id INTO v_tenant FROM agency.tenants ORDER BY created_at LIMIT 1;
  SELECT id INTO v_user FROM agency.users WHERE tenant_id = v_tenant AND membership_type IN ('owner','admin') LIMIT 1;

  -- 1. Insert test submission
  INSERT INTO agency.supplier_onboarding_submissions (
    tenant_id, company_name, contact_name, email, phone, tax_id, tax_office,
    category_code, listing_title, locality, description, currency, price_minor,
    guest_capacity, domain_target, status
  ) VALUES (
    v_tenant, 'Test Turizm A.S.', 'Ali Veli', 'ali@testturizm.com', '+905321112233', '1234567890', 'Kadikoy',
    'hotel', 'Ege Butik Otel Test', 'Mugla, Bodrum', 'Test aciklama', 'TRY', 350000,
    2, 'both', 'submitted'
  ) RETURNING id INTO v_sub_id;

  RAISE NOTICE 'Submission created: %', v_sub_id;

  -- 2. Verify in view
  IF NOT EXISTS (SELECT 1 FROM agency.v_listing_submissions WHERE id = v_sub_id) THEN
    RAISE EXCEPTION 'View agency.v_listing_submissions does not contain submission';
  END IF;

  -- 3. Approve submission
  v_listing_id := agency.approve_supplier_submission(v_tenant, v_user, v_sub_id, 'published');
  RAISE NOTICE 'Approved and listing created: %', v_listing_id;

  -- 4. Verify listing domain_visibility
  IF NOT EXISTS (SELECT 1 FROM agency.listings WHERE id = v_listing_id AND domain_visibility = 'all') THEN
    RAISE EXCEPTION 'domain_visibility check failed';
  END IF;

  -- 5. Clean up test records
  DELETE FROM agency.listings WHERE id = v_listing_id;
  DELETE FROM agency.supplier_onboarding_submissions WHERE id = v_sub_id;

  -- 6. Test rejection flow
  INSERT INTO agency.supplier_onboarding_submissions (
    tenant_id, company_name, contact_name, email, phone, tax_id, tax_office,
    category_code, listing_title, locality, description, currency, price_minor,
    guest_capacity, domain_target, status
  ) VALUES (
    v_tenant, 'Ret Test Turizm', 'Mehmet Oz', 'mehmet@rettest.com', '+905329998877', '9876543210', 'Besiktas',
    'tour', 'Kapadokya Balon Turu', 'Nevsehir, Goreme', 'Test aciklama', 'EUR', 18000,
    1, 'reservationinturkey', 'submitted'
  ) RETURNING id INTO v_sub_id;

  PERFORM agency.reject_supplier_submission(v_tenant, v_user, v_sub_id, 'Eksik belge nedeniyle reddedildi.');

  IF NOT EXISTS (SELECT 1 FROM agency.supplier_onboarding_submissions WHERE id = v_sub_id AND status = 'rejected' AND admin_notes = 'Eksik belge nedeniyle reddedildi.') THEN
    RAISE EXCEPTION 'rejection check failed';
  END IF;

  DELETE FROM agency.supplier_onboarding_submissions WHERE id = v_sub_id;

  RAISE NOTICE 'SUCCESS: End-to-end listing submission, approval AND rejection lifecycles verified!';
END $$;
