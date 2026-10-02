-- Fresh-install seed contract test (migration 017/052/058/143 contracts).
-- Verifies the standalone-agency baseline a fresh installation must provide:
--   1) 017: invoicing schema exists and is application-writable
--      (billing_profiles + invoices + invoice_items; invoice_type and status
--      enums reject unknown values).
--   2) 052: customers.email is optional - phone-only leads are valid
--      customers (052 made email nullable and normalized blank values).
--   3) 058/236: the original three-argument auth.login contract survives as
--      a delegating wrapper: EXECUTE granted to agency_app and a real login
--      returns the scoped four-argument result.
--   4) 143+201: category benefit cards exist on category pages with the
--      201-corrected stock copy. The 143 stock copy is the 201-obsolete one,
--      so seeing it means the 201 correction was skipped (the two backfills
--      contradict each other and must fail loudly).
-- Self-seeding and rollback-only: creates its own rows inside the
-- transaction; never mutates live rows.
\set ON_ERROR_STOP on
BEGIN;
DO $$
DECLARE
  v_tenant uuid;
  v_profile uuid;
  v_invoice uuid;
  v_email text;
  v_login record;
  v_stock_143 int;
  v_pages_total int;
  v_pages_with_cards int;
  v_corrected int;
BEGIN
  -- ---------------------------------------------------------------
  -- 017: invoicing schema + enum contracts
  -- ---------------------------------------------------------------
  IF to_regclass('agency.billing_profiles') IS NULL
     OR to_regclass('agency.invoices') IS NULL
     OR to_regclass('agency.invoice_items') IS NULL THEN
    RAISE EXCEPTION 'invoicing_schema_missing';
  END IF;
  SELECT id INTO v_tenant FROM agency.tenants ORDER BY created_at LIMIT 1;
  IF v_tenant IS NULL THEN RAISE EXCEPTION 'tenant fixture missing'; END IF;
  INSERT INTO agency.billing_profiles(tenant_id, owner_type, owner_id, legal_name)
    VALUES (v_tenant, 'tenant', v_tenant, 'Seed Sozlesme Testi')
    RETURNING id INTO v_profile;
  INSERT INTO agency.invoices(tenant_id, number, invoice_type, subtotal_minor, tax_minor, total_minor)
    VALUES (v_tenant, 'SEEDTEST-' || gen_random_uuid()::text, 'e_invoice', 10000, 2000, 12000)
    RETURNING id INTO v_invoice;
  INSERT INTO agency.invoice_items(invoice_id, description, quantity, unit_minor, tax_rate)
    VALUES (v_invoice, 'Seed test kalem', 2, 5000, 20);
  BEGIN
    INSERT INTO agency.invoices(tenant_id, number, invoice_type, subtotal_minor, tax_minor, total_minor)
      VALUES (v_tenant, 'SEEDTEST-' || gen_random_uuid()::text, 'paper_invoice', 1, 0, 1);
    RAISE EXCEPTION 'invalid_invoice_type_accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'invalid_invoice_type_accepted' THEN RAISE; END IF;
  END;

  -- ---------------------------------------------------------------
  -- 052: phone-only customers are valid (email optional)
  -- ---------------------------------------------------------------
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'agency' AND table_name = 'customers'
      AND column_name = 'email' AND is_nullable = 'NO'
  ) THEN
    RAISE EXCEPTION 'customers_email_still_required';
  END IF;
  INSERT INTO agency.customers(tenant_id, full_name, email, phone)
    VALUES (v_tenant, 'Seed Test Musterisi', '', '+90 555 000 00 01');

  -- ---------------------------------------------------------------
  -- 058/236: three-argument auth.login wrapper contract
  -- ---------------------------------------------------------------
  IF NOT has_function_privilege('agency_app', 'auth.login(text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'login3_agency_app_grant_missing';
  END IF;
  v_email := 'seed-contract-' || gen_random_uuid()::text || '@example.test';
  INSERT INTO agency.users(tenant_id, email, display_name, membership_type)
    VALUES (v_tenant, v_email, 'Seed Contract Admin', 'admin');
  UPDATE agency.users
    SET password_hash = crypt('seed-contract-password', gen_salt('bf', 4))
    WHERE tenant_id = v_tenant AND email = v_email;
  -- 4-arg login contract requires a non-null session token (the row is
  -- registered in auth.sessions with its sha256 digest).
  SELECT * INTO v_login FROM auth.login(v_email, 'seed-contract-password',
    'seed-token-' || gen_random_uuid()::text);
  IF v_login.error_code IS NOT NULL THEN
    RAISE EXCEPTION 'login3_failed: %', v_login.error_code;
  END IF;
  IF v_login.user_id IS NULL OR v_login.membership_type IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'login3_unexpected_result';
  END IF;

  -- ---------------------------------------------------------------
  -- 143+201: category benefit cards (corrected stock copy)
  -- ---------------------------------------------------------------
  SELECT count(*) INTO v_stock_143
  FROM agency.page_blocks b
  WHERE b.block_type = 'source_section'
    AND b.content->>'sectionKey' = 'benefits'
    AND jsonb_typeof(b.content->'items') = 'array'
    AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(b.content->'items') entry(item)
      WHERE item->>'title' = 'En İyi Fiyat Garantisi'
        AND item->>'description' = 'Daha ucuz bulursanız farkı iade ediyoruz. Fiyat garantisi ile içiniz rahat olsun.'
    );
  IF v_stock_143 <> 0 THEN
    RAISE EXCEPTION 'benefit_cards_stale_143_copy: %', v_stock_143;
  END IF;

  SELECT count(*) INTO v_pages_total
  FROM agency.pages p
  WHERE p.slug LIKE 'category-%';
  SELECT count(DISTINCT p.id) INTO v_pages_with_cards
  FROM agency.pages p
  JOIN agency.page_blocks b ON b.page_id = p.id
  WHERE p.slug LIKE 'category-%'
    AND b.block_type = 'source_section'
    AND b.content->>'sectionKey' = 'benefits'
    AND jsonb_typeof(b.content->'items') = 'array'
    AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(b.content->'items') entry(item)
      WHERE item->>'icon' = 'secure'
        AND item->>'title' = 'Güvenli Rezervasyon'
    );
  IF v_pages_total = 0 OR v_pages_with_cards = 0 THEN
    RAISE EXCEPTION 'benefit_cards_missing (pages=%, with_cards=%)', v_pages_total, v_pages_with_cards;
  END IF;

  SELECT count(*) INTO v_corrected
  FROM agency.page_blocks b
  WHERE b.block_type = 'source_section'
    AND b.content->>'sectionKey' = 'benefits'
    AND jsonb_typeof(b.content->'items') = 'array'
    AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(b.content->'items') entry(item)
      WHERE item->>'title' = 'Fiyatları Karşılaştırın'
        AND item->>'description' = 'İlanların fiyat ve koşullarını rezervasyon öncesinde inceleyin.'
    );
  IF v_corrected = 0 THEN
    RAISE EXCEPTION 'benefit_cards_201_correction_missing';
  END IF;
END $$;
ROLLBACK;
\echo 'PASS: fresh-install seed contracts (017 invoicing, 052 phone-only customers, 058/236 login wrapper, 143+201 benefit cards)'
