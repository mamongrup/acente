-- WP2: Tek tam satış zinciri — Acente tarafı kapsamlı kabul testi
-- Kapsam: Sipariş ve rezervasyon tekil kimlik zinciri, çift istek koruması,
-- ödeme seansı ve callback yaşam döngüsü, iptal ve iade iş akışı,
-- bağımsız çalışma modu ve yetkisiz aktör koruması.

BEGIN;
DO $$
DECLARE
  v_tenant uuid;
  v_admin uuid;
  v_customer uuid;
  v_listing_local uuid;
  v_listing_remote uuid;
  v_order_local record;
  v_order_remote record;
  v_session uuid;
  v_chain jsonb;
  v_cancel_res jsonb;
  v_refund_claim jsonb;
  v_refund_finish jsonb;
  v_blocked boolean;
  v_req_key text := 'wp2-order-' || gen_random_uuid()::text;
BEGIN
  -- =========================================================================
  -- 0. Fixture hazırlığı: Tenant, kullanıcılar ve ilanlar
  -- =========================================================================
  SELECT id INTO STRICT v_tenant FROM agency.tenants WHERE slug='nexus-demo';

  INSERT INTO agency.users(tenant_id, email, display_name, membership_type, active)
  VALUES (v_tenant, 'wp2-admin@example.invalid', 'WP2 Admin', 'admin', true)
  RETURNING id INTO v_admin;

  INSERT INTO agency.users(tenant_id, email, display_name, membership_type, active)
  VALUES (v_tenant, 'wp2-cust@example.invalid', 'WP2 Customer', 'customer', true)
  RETURNING id INTO v_customer;

  -- Yerel ilan (Manual / Standalone)
  INSERT INTO agency.listings(
    tenant_id, code, category, title, locality, description, currency, price_minor,
    status, source, metadata, images, owner_info, cancellation_policy, owner_user_id
  ) VALUES (
    v_tenant, 'wp2-local-' || gen_random_uuid(), 'hotel', 'WP2 Local Hotel', 'Antalya',
    'WP2 Local test listing', 'TRY', 25000, 'published', 'manual',
    jsonb_build_object('property_type','Otel','room_types','Standart Oda',
                       'board_type','Oda Kahvaltı','check_in_time','14:00','check_out_time','12:00'),
    jsonb_build_array(jsonb_build_object('url','/static/placeholder.jpg')),
    jsonb_build_object('provider','Local Provider'),
    jsonb_build_object('policy','Standard'),
    v_admin
  ) RETURNING id INTO v_listing_local;

  -- Bağlantılı ilan (NEXUS Connected)
  INSERT INTO agency.listings(
    tenant_id, code, category, title, locality, description, currency, price_minor,
    status, source, metadata, images, owner_info, cancellation_policy
  ) VALUES (
    v_tenant, 'wp2-remote-' || gen_random_uuid(), 'hotel', 'WP2 Connected Hotel', 'Antalya',
    'WP2 Connected test listing', 'TRY', 30000, 'published', 'nexus',
    jsonb_build_object('property_type','Otel','room_types','Suit Oda',
                       'board_type','Oda Kahvaltı','check_in_time','14:00','check_out_time','12:00',
                       'nexus_listing_id', gen_random_uuid()::text),
    jsonb_build_array(jsonb_build_object('url','/static/placeholder.jpg')),
    jsonb_build_object('provider','Remote Partner'),
    jsonb_build_object('policy','Flexible')
  ) RETURNING id INTO v_listing_remote;

  -- =========================================================================
  -- 1. Sipariş oluşturma ve Tekil Kimlik Zinciri (Single Identity Chain)
  -- =========================================================================
  SELECT * INTO STRICT v_order_local
  FROM agency.checkout_order(
    v_tenant, 'WP2 Müşteri', 'wp2-cust@example.invalid', '+905551112233',
    v_listing_local, 'WP2-REF-' || gen_random_uuid(),
    CURRENT_DATE + 2, CURRENT_DATE + 4, 2, v_req_key
  );

  -- 2 gece * 25000 = 50000 minor
  IF v_order_local.total_minor <> 50000 THEN
    RAISE EXCEPTION 'WP2.1 FAILED: Sipariş toplamı hatalı: %', v_order_local.total_minor;
  END IF;

  -- Tek kimlikle satış zincirini sorgula (Migration 226: get_sales_chain_details)
  v_chain := agency.get_sales_chain_details(v_tenant, v_order_local.id);
  IF v_chain->>'ok' <> 'true'
     OR v_chain->'chain'->'order'->>'id' <> v_order_local.id::text
     OR v_chain->'chain'->'reservation'->>'id' <> v_order_local.reservation_id::text THEN
    RAISE EXCEPTION 'WP2.1 FAILED: Satış zinciri tek kimlikle sorgulanamadı: %', v_chain;
  END IF;

  -- =========================================================================
  -- 2. Çift İstek Koruması (Idempotent Checkout)
  -- =========================================================================
  DECLARE
    v_order_retry record;
  BEGIN
    SELECT * INTO STRICT v_order_retry
    FROM agency.checkout_order(
      v_tenant, 'WP2 Müşteri', 'wp2-cust@example.invalid', '+905551112233',
      v_listing_local, 'IGNORED-REF',
      CURRENT_DATE + 2, CURRENT_DATE + 4, 2, v_req_key
    );

    IF v_order_retry.id <> v_order_local.id THEN
      RAISE EXCEPTION 'WP2.2 FAILED: Aynı anahtar ile yeni sipariş oluşturuldu: % vs %',
        v_order_retry.id, v_order_local.id;
    END IF;
  END;

  -- Farklı parametrelerle aynı key kullanıldığında hata vermelidir
  v_blocked := false;
  BEGIN
    PERFORM agency.checkout_order(
      v_tenant, 'Farklı İsim', 'wp2-cust@example.invalid', '+905551112233',
      v_listing_local, 'DIFF-REF',
      CURRENT_DATE + 2, CURRENT_DATE + 4, 2, v_req_key
    );
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%mismatch%' THEN v_blocked := true; END IF;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'WP2.2 FAILED: Değişen payload ile idempotency key kabul edildi';
  END IF;

  -- =========================================================================
  -- 3. Ödeme Seansı ve Callback Yaşam Döngüsü (Payment Transition & Safety)
  -- =========================================================================
  v_session := agency.checkout_session(v_tenant, v_order_local.id);
  IF v_session IS NULL THEN
    RAISE EXCEPTION 'WP2.3 FAILED: Ödeme seansı oluşturulamadı';
  END IF;

  -- Çift başlatma engeli
  IF NOT agency.parampos_transition(v_session, 'claim_start') THEN
    RAISE EXCEPTION 'WP2.3 FAILED: İlk claim_start başarısız';
  END IF;
  IF agency.parampos_transition(v_session, 'claim_start') THEN
    RAISE EXCEPTION 'WP2.3 FAILED: Çift claim_start kabul edildi';
  END IF;

  -- Provizyon kaydı
  IF NOT agency.parampos_transition(v_session, 'initiated', 'wp2-guid-123') THEN
    RAISE EXCEPTION 'WP2.3 FAILED: initiated adımı başarısız';
  END IF;

  v_blocked := false;
  BEGIN
    PERFORM agency.cancel_and_refund_order(v_tenant, v_admin, v_order_local.id);
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%payment_in_progress%' THEN v_blocked := true; END IF;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'WP2.3 FAILED: Devam eden ödeme sırasında iptal kabul edildi';
  END IF;

  -- Ödeme onayı
  IF NOT agency.parampos_transition(v_session, 'claim_pay') THEN
    RAISE EXCEPTION 'WP2.3 FAILED: claim_pay adımı başarısız';
  END IF;
  IF NOT agency.parampos_transition(v_session, 'paid', '', '999888') THEN
    RAISE EXCEPTION 'WP2.3 FAILED: paid adımı başarısız';
  END IF;

  -- Paid sonrası sipariş ve rezervasyon durumu kontrolü
  IF (SELECT status FROM agency.orders WHERE id=v_order_local.id) <> 'confirmed' THEN
    RAISE EXCEPTION 'WP2.3 FAILED: Ödenen sipariş confirmed olmadı';
  END IF;
  IF (SELECT status FROM agency.reservations WHERE id=v_order_local.reservation_id) <> 'confirmed'
     OR (SELECT payment_status FROM agency.reservations WHERE id=v_order_local.reservation_id) <> 'paid' THEN
    RAISE EXCEPTION 'WP2.3 FAILED: Rezervasyon paid ve confirmed durumuna geçmedi';
  END IF;

  -- Ödenmiş sipariş için yeni ödeme seansı alınamaz
  v_blocked := false;
  BEGIN
    PERFORM agency.checkout_session(v_tenant, v_order_local.id);
  EXCEPTION WHEN OTHERS THEN
    v_blocked := true;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'WP2.3 FAILED: Ödenmiş sipariş için yeni seans oluşturulabildi';
  END IF;

  -- =========================================================================
  -- 4. İptal ve İade İş Akışı (Migration 226: cancel_and_refund_order)
  -- =========================================================================
  INSERT INTO agency.supplier_settlements(
    tenant_id,reservation_id,supplier_user_id,gross_minor,commission_minor,
    net_minor,currency,due_on,created_by,status,paid_at
  ) VALUES (
    v_tenant,v_order_local.reservation_id,v_admin,50000,0,
    50000,'TRY',current_date,v_admin,'paid',now()
  );
  v_blocked := false;
  BEGIN
    PERFORM agency.cancel_and_refund_order(v_tenant, v_admin, v_order_local.id);
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%paid_settlement_requires_manual_reversal%' THEN v_blocked := true; END IF;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'WP2.4 FAILED: Ödenmiş hakedişe rağmen iptal kabul edildi';
  END IF;
  DELETE FROM agency.supplier_settlements
  WHERE reservation_id=v_order_local.reservation_id AND tenant_id=v_tenant;

  INSERT INTO agency.supplier_settlements(
    tenant_id,reservation_id,supplier_user_id,gross_minor,commission_minor,
    net_minor,currency,due_on,created_by,status
  ) VALUES (
    v_tenant,v_order_local.reservation_id,v_admin,50000,0,
    50000,'TRY',current_date,v_admin,'pending'
  );

  -- Ödenmiş siparişi iptal edip iade sürecini başlatalım
  v_cancel_res := agency.cancel_and_refund_order(
    v_tenant, v_admin, v_order_local.id, 'Müşteri seyahat planı değişti'
  );

  IF v_cancel_res->>'ok' <> 'true' OR v_cancel_res->>'refund_id' IS NULL THEN
    RAISE EXCEPTION 'WP2.4 FAILED: İptal ve iade başarısız: %', v_cancel_res;
  END IF;
  IF v_cancel_res->>'settlement_annulled' <> 'true' OR NOT EXISTS (
    SELECT 1 FROM agency.supplier_settlements
    WHERE reservation_id=v_order_local.reservation_id AND status='cancelled'
  ) THEN
    RAISE EXCEPTION 'WP2.4 FAILED: Bekleyen hakediş iptal edilmedi';
  END IF;

  -- İade sağlayıcı tarafından işlenene dek sipariş cancelled kalır.
  IF (SELECT status FROM agency.reservations WHERE id=v_order_local.reservation_id) <> 'cancelled' THEN
    RAISE EXCEPTION 'WP2.4 FAILED: Rezervasyon cancelled durumuna geçmedi';
  END IF;
  IF (SELECT status FROM agency.orders WHERE id=v_order_local.id) <> 'cancelled' THEN
    RAISE EXCEPTION 'WP2.4 FAILED: Bekleyen iade erken tamamlandı sayıldı';
  END IF;

  -- agency.refunds tablosunda iade talebi oluştu mu?
  IF NOT EXISTS (
    SELECT 1 FROM agency.refunds
    WHERE id=(v_cancel_res->>'refund_id')::uuid AND amount_minor=50000 AND status='pending'
  ) THEN
    RAISE EXCEPTION 'WP2.4 FAILED: İade kaydı agency.refunds tablosunda doğrulanamadı';
  END IF;

  PERFORM agency.cancel_and_refund_order(v_tenant, v_admin, v_order_local.id);
  IF (SELECT count(*) FROM agency.refunds f JOIN agency.payments p ON p.id=f.payment_id
      WHERE p.order_id=v_order_local.id) <> 1 THEN
    RAISE EXCEPTION 'WP2.4 FAILED: Tekrarlanan iptal ikinci iade oluşturdu';
  END IF;

  -- Sağlayıcıdan geciken/tekrarlanan başarı callback'i iptali geri alamaz.
  PERFORM agency.parampos_transition(v_session, 'paid', '', '999888');
  IF (SELECT status FROM agency.orders WHERE id=v_order_local.id) <> 'cancelled'
     OR (SELECT status FROM agency.reservations WHERE id=v_order_local.reservation_id) <> 'cancelled' THEN
    RAISE EXCEPTION 'WP2.4 FAILED: Gecikmiş callback iptali geri aldı';
  END IF;

  -- =========================================================================
  -- 5. Yetkisiz Aktör Koruması (Role / Actor Isolation)
  -- =========================================================================
  v_blocked := false;
  BEGIN
    -- Müşteri kullanıcısı sipariş iptal/iade yönetici fonksiyonunu çağıramaz
    PERFORM agency.cancel_and_refund_order(v_tenant, v_customer, v_order_local.id);
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%unauthorized%' THEN v_blocked := true; END IF;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'WP2.5 FAILED: Müşteri rolü admin iptal/iade fonksiyonunu çalıştırabildi';
  END IF;

  -- Sağlayıcı yanıtı burada yalnızca rollback içindeki durum makinesine verilir.
  -- Gerçek SOAP sonucu test/parampos_integration.gleam fikstüründe doğrulanır.
  v_refund_claim := agency.claim_parampos_refund(
    v_tenant,v_admin,(v_cancel_res->>'refund_id')::uuid
  );
  IF v_refund_claim->>'order_id' <> v_order_local.id::text
     OR v_refund_claim->>'amount_minor' <> '50000' THEN
    RAISE EXCEPTION 'WP2.5 FAILED: İade claim verisi hatalı: %',v_refund_claim;
  END IF;
  v_blocked := false;
  BEGIN
    PERFORM agency.claim_parampos_refund(
      v_tenant,v_admin,(v_cancel_res->>'refund_id')::uuid
    );
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%refund_dispatch_already_claimed%' THEN v_blocked := true; END IF;
  END;
  IF NOT v_blocked THEN
    RAISE EXCEPTION 'WP2.5 FAILED: Aynı iade ikinci kez sağlayıcıya gönderilebilir';
  END IF;
  v_refund_finish := agency.finish_parampos_refund(
    v_tenant,v_admin,(v_refund_claim->>'attempt_id')::uuid,
    'succeeded','fixture-bank-reference','rollback-fixture'
  );
  IF v_refund_finish->>'status'<>'succeeded'
     OR (SELECT status FROM agency.orders WHERE id=v_order_local.id)<>'refunded'
     OR (SELECT status FROM agency.refunds WHERE id=(v_cancel_res->>'refund_id')::uuid)<>'processed'
     OR (SELECT payment_status FROM agency.reservations WHERE id=v_order_local.reservation_id)<>'refunded' THEN
    RAISE EXCEPTION 'WP2.5 FAILED: Kanıtlı iade durum zinciri tamamlanmadı';
  END IF;

  -- =========================================================================
  -- 6. Bağlantılı İlanda Outbox Tetikleyicisi (Connected Outbox Verification)
  -- =========================================================================
  SELECT * INTO STRICT v_order_remote
  FROM agency.checkout_order(
    v_tenant, 'Remote Müşteri', 'remote-cust@example.invalid', '+905559998877',
    v_listing_remote, 'REMOTE-REF-' || gen_random_uuid(),
    CURRENT_DATE + 3, CURRENT_DATE + 5, 2, 'remote-req-' || gen_random_uuid()
  );

  -- Outbox tablosunda reservation.created kuyruklandı mı?
  IF NOT EXISTS (
    SELECT 1 FROM agency.nexus_reservation_deliveries
    WHERE reservation_id=v_order_remote.reservation_id
      AND event_type='reservation.created' AND status='pending'
  ) THEN
    RAISE EXCEPTION 'WP2.6 FAILED: Bağlantılı rezervasyon outbox kuyruğuna eklenmedi';
  END IF;

  -- Rezervasyonu iptal ettiğimizde outbox'a status_changed (cancelled) eklenir mi?
  PERFORM agency.cancel_and_refund_order(v_tenant, v_admin, v_order_remote.id);

  IF NOT EXISTS (
    SELECT 1 FROM agency.nexus_reservation_deliveries
    WHERE reservation_id=v_order_remote.reservation_id
      AND event_type='reservation.status_changed'
      AND reservation_status='cancelled'
  ) THEN
    RAISE EXCEPTION 'WP2.6 FAILED: İptal edilen bağlantılı rezervasyon outbox status_changed kuyruğuna girmedi';
  END IF;

  RAISE NOTICE '=======================================================';
  RAISE NOTICE 'WP2 Acente Satış Zinciri ve Yaşam Döngüsü Kabul Testi: BAŞARILI';
  RAISE NOTICE '=======================================================';
END $$;
ROLLBACK;
