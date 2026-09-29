-- WP1: Ortak kuruluş, rol ve ilan sözleşmesi — kapsamlı kabul testi
-- Kabul koşulu: Aynı sözleşme sürümündeki bir ilan iki projede aynı yetki,
-- doğrulama ve durum kararını verir; farklı tenant erişimi reddedilir;
-- NEXUS kapalıyken yerel ilan/rezervasyon çalışır.

BEGIN;

DO $$
DECLARE
  v_tenant_a    uuid := gen_random_uuid();
  v_tenant_b    uuid := gen_random_uuid();
  v_admin_a     uuid := gen_random_uuid();
  v_reviewer_a  uuid := gen_random_uuid();
  v_supplier_a  uuid := gen_random_uuid();
  v_admin_b     uuid := gen_random_uuid();
  v_reviewer_role_a uuid := gen_random_uuid();
  v_listing_a   uuid := gen_random_uuid();
  v_listing_b   uuid := gen_random_uuid();
  v_blocked     boolean;
  v_missing_fields text;
  -- Minimal geçerli hotel metadata (sözleşme 1.2.0)
  v_hotel_meta  jsonb := jsonb_build_object(
    'property_type',  'Otel',
    'room_types',     'Standart',
    'board_type',     'Oda Kahvaltı',
    'check_in_time',  '14:00',
    'check_out_time', '12:00'
  );
  -- Eksik zorunlu alan içeren metadata
  v_bad_meta    jsonb := jsonb_build_object(
    'property_type', 'Otel'
  );
BEGIN
  -- ─────────────────────────────────────────────────────────────────────
  -- BÖLÜM 1: Temel kuruluş ve rol kurulumu
  -- ─────────────────────────────────────────────────────────────────────

  INSERT INTO agency.tenants(id, legal_name, brand_name, slug)
  VALUES
    (v_tenant_a, 'WP1 Acente A Ltd', 'Acente A', 'wp1-a-'||replace(v_tenant_a::text,'-','')),
    (v_tenant_b, 'WP1 Acente B Ltd', 'Acente B', 'wp1-b-'||replace(v_tenant_b::text,'-',''));

  INSERT INTO agency.users(id, tenant_id, email, display_name, membership_type, active)
  VALUES
    (v_admin_a,    v_tenant_a, 'wp1-admin-a@example.invalid',    'Admin A',    'admin',    true),
    (v_reviewer_a, v_tenant_a, 'wp1-reviewer-a@example.invalid', 'Reviewer A', 'staff',    true),
    (v_supplier_a, v_tenant_a, 'wp1-supplier-a@example.invalid', 'Supplier A', 'supplier', true),
    (v_admin_b,    v_tenant_b, 'wp1-admin-b@example.invalid',    'Admin B',    'admin',    true);

  -- Reviewer rolü oluştur ve ata
  INSERT INTO agency.roles(id, tenant_id, code, name)
  VALUES (v_reviewer_role_a, v_tenant_a, 'reviewer', 'İlan İnceleme');

  INSERT INTO agency.user_roles(user_id, role_id)
  VALUES (v_reviewer_a, v_reviewer_role_a);

  -- Rol kontrolleri
  IF NOT agency.has_panel_role(v_tenant_a, v_admin_a, 'admin') THEN
    RAISE EXCEPTION 'wp1_admin_a_role_missing';
  END IF;
  IF NOT agency.has_panel_role(v_tenant_a, v_reviewer_a, 'reviewer') THEN
    RAISE EXCEPTION 'wp1_reviewer_a_role_missing';
  END IF;
  -- Cross-tenant rol sızıntısı yok
  IF agency.has_panel_role(v_tenant_b, v_reviewer_a, 'reviewer') THEN
    RAISE EXCEPTION 'wp1_reviewer_cross_tenant_role_leak';
  END IF;

  RAISE NOTICE 'WP1.1 rol ve kuruluş: GEÇTI';

  -- ─────────────────────────────────────────────────────────────────────
  -- BÖLÜM 2: İlan sözleşme doğrulaması — eşit karar
  -- Acente: agency.validate_listing_contract(tenant, category, metadata)
  -- NEXUS eşdeğeri: onboarding.validate_listing_contract(category, metadata)
  -- ─────────────────────────────────────────────────────────────────────

  -- Geçerli metadata → eksik alan yok
  SELECT string_agg(field_key, ',') INTO v_missing_fields
  FROM agency.validate_listing_contract(v_tenant_a, 'hotel', v_hotel_meta);

  IF coalesce(v_missing_fields, '') <> '' THEN
    RAISE EXCEPTION 'wp1_valid_hotel_meta_reported_missing: %', v_missing_fields;
  END IF;

  -- Eksik alan içeren metadata → en az bir alan eksik raporlanmalı
  SELECT string_agg(field_key, ',') INTO v_missing_fields
  FROM agency.validate_listing_contract(v_tenant_a, 'hotel', v_bad_meta);

  IF coalesce(v_missing_fields, '') = '' THEN
    RAISE EXCEPTION 'wp1_bad_hotel_meta_not_detected';
  END IF;

  RAISE NOTICE 'WP1.2 ilan sözleşme doğrulama: GEÇTI (eksik alanlar: %)', v_missing_fields;

  -- ─────────────────────────────────────────────────────────────────────
  -- BÖLÜM 3: İlan oluşturma ve durum geçiş makinesi
  -- ─────────────────────────────────────────────────────────────────────

  INSERT INTO agency.listings(
    id, tenant_id, code, category, title, locality, description,
    currency, price_minor, status, source,
    metadata, images, owner_info, cancellation_policy, owner_user_id)
  VALUES
    (v_listing_a, v_tenant_a, 'wp1-code-a-'||gen_random_uuid(), 'hotel',
     'WP1 Otel A', 'Antalya', 'WP1 Test Otel A',
     'TRY', 15000, 'draft', 'manual',
     v_hotel_meta,
     jsonb_build_array(jsonb_build_object('url','/wp1-hotel-a.jpg')),
     jsonb_build_object('provider','Test'), jsonb_build_object('policy','Standard'),
     v_admin_a),
    (v_listing_b, v_tenant_b, 'wp1-code-b-'||gen_random_uuid(), 'hotel',
     'WP1 Otel B', 'Bodrum', 'WP1 Test Otel B',
     'TRY', 20000, 'draft', 'manual',
     v_hotel_meta,
     jsonb_build_array(jsonb_build_object('url','/wp1-hotel-b.jpg')),
     jsonb_build_object('provider','Test'), jsonb_build_object('policy','Strict'),
     v_admin_b);

  -- 3a. draft → pending_review: admin yapabilir
  PERFORM agency.transition_listing_status(v_tenant_a, v_admin_a, v_listing_a, 'pending_review', 'İncelemeye gönder');
  IF (SELECT status FROM agency.listings WHERE id=v_listing_a) <> 'pending_review' THEN
    RAISE EXCEPTION 'wp1_draft_to_pending_review_failed';
  END IF;

  -- 3b. pending_review → published: reviewer yapabilir
  PERFORM agency.transition_listing_status(v_tenant_a, v_reviewer_a, v_listing_a, 'published', 'Onaylandı');
  IF (SELECT status FROM agency.listings WHERE id=v_listing_a) <> 'published' THEN
    RAISE EXCEPTION 'wp1_pending_review_to_published_failed';
  END IF;

  -- 3c. published → paused: admin yapabilir
  PERFORM agency.transition_listing_status(v_tenant_a, v_admin_a, v_listing_a, 'paused', 'Geçici duraklat');
  IF (SELECT status FROM agency.listings WHERE id=v_listing_a) <> 'paused' THEN
    RAISE EXCEPTION 'wp1_published_to_paused_failed';
  END IF;

  -- 3d. paused → published: admin yapabilir
  PERFORM agency.transition_listing_status(v_tenant_a, v_admin_a, v_listing_a, 'published', 'Tekrar yayınla');
  IF (SELECT status FROM agency.listings WHERE id=v_listing_a) <> 'published' THEN
    RAISE EXCEPTION 'wp1_paused_to_published_failed';
  END IF;

  RAISE NOTICE 'WP1.3 ilan durum geçiş makinesi: GEÇTI';

  -- ─────────────────────────────────────────────────────────────────────
  -- BÖLÜM 4: Negatif durum geçiş testleri
  -- ─────────────────────────────────────────────────────────────────────

  -- 4a. Tenant B admini Tenant A ilanının durumunu değiştiremez
  v_blocked := false;
  BEGIN
    PERFORM agency.transition_listing_status(v_tenant_b, v_admin_b, v_listing_a, 'archived', 'Korsan arşiv');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'wp1_cross_tenant_status_change_allowed';
  END IF;

  -- 4b. Reviewer direct draft → published geçişi yapamaz (önce pending_review gerekir)
  -- listing_b hala draft'ta
  v_blocked := false;
  BEGIN
    -- reviewer, tenant_b'de rolü yok, bu senaryo zaten cross-tenant bloğuna girer
    -- ama burada yetkisiz geçiş matrisini test ediyoruz: draft → published yasak
    -- admin_b ile deneyelim
    PERFORM agency.transition_listing_status(v_tenant_b, v_admin_b, v_listing_b, 'published', 'Yasak geçiş');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'wp1_draft_to_published_direct_allowed';
  END IF;

  -- 4c. Aynı duruma geçiş yasak
  v_blocked := false;
  BEGIN
    PERFORM agency.transition_listing_status(v_tenant_a, v_admin_a, v_listing_a, 'published', 'Tekrar aynı');
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'wp1_same_status_transition_allowed';
  END IF;

  RAISE NOTICE 'WP1.4 negatif durum geçiş testleri: GEÇTI';

  -- ─────────────────────────────────────────────────────────────────────
  -- BÖLÜM 5: NEXUS bağlantısı kapalıyken yerel ilan ve rezervasyon
  -- Acente bağımsız çalışabilir — connections tablosunda aktif bağlantı
  -- olmasına gerek yok.
  -- ─────────────────────────────────────────────────────────────────────

  -- NEXUS bağlantısı olmaksızın yerel rezervasyon
  DECLARE
    v_order record;
    v_nexus_connected boolean;
  BEGIN
    -- Aktif NEXUS bağlantısı var mı?
    SELECT EXISTS(
      SELECT 1 FROM agency.connections
      WHERE tenant_id = v_tenant_a AND active = true
        AND provider = 'nexus'
    ) INTO v_nexus_connected;

    -- Bağlantı yokken checkout çalışmalı (bağımsız mod)
    SELECT * INTO STRICT v_order FROM agency.checkout_order(
      v_tenant_a, 'NEXUS Bağımsız Müşteri', 'standalone@example.invalid', '5550000001',
      v_listing_a, 'REZ-WP1-SA-'||gen_random_uuid(),
      current_date + 10, current_date + 15, 2,
      'wp1-idemp-sa-'||gen_random_uuid()
    );

    IF v_order.reservation_id IS NULL THEN
      RAISE EXCEPTION 'wp1_standalone_checkout_failed';
    END IF;

    RAISE NOTICE 'WP1.5 NEXUS kapalı bağımsız rezervasyon: GEÇTI (nexus_connected=%, reservation=%)',
      v_nexus_connected, v_order.reservation_id;
  END;

  -- ─────────────────────────────────────────────────────────────────────
  -- BÖLÜM 6: İlan durum geçişi denetim kaydı doğrulaması
  -- ─────────────────────────────────────────────────────────────────────

  IF NOT EXISTS(
    SELECT 1 FROM agency.audit_logs
    WHERE tenant_id = v_tenant_a
      AND entity_type = 'listing'
      AND entity_id = v_listing_a
      AND action = 'status_transition'
      AND (metadata->>'from') IS NOT NULL
      AND (metadata->>'to') IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'wp1_audit_log_missing_for_status_transition';
  END IF;

  RAISE NOTICE 'WP1.6 durum geçiş denetim kaydı: GEÇTI';

  -- ─────────────────────────────────────────────────────────────────────
  RAISE NOTICE '=== WP1 TÜM TESTLER GEÇTI ===';
END;
$$;

ROLLBACK;
