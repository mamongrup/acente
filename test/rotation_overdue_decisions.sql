-- notify-rotation-overdue.ps1 karar senaryolari (gürültülü kabul testi).
--
-- Acente notifier'inin UÇ karar senaryosunu uçtan uca doğrular:
--   open                      -> exit 0, uyari yok
--   expired + PREVIOUS var    -> exit 1, PREVIOUS kaldırılmalı
--   unknown (kayıt yok)       -> exit 1, fail-closed
--
-- Kapsam bilinçli olarak üç senaryoyla sınırlıdır: istenen kabul testi
-- bunları kapsar. Platform muadili (Nexustraveltech
-- test/rotation_overdue_decisions.sql) ayrıca overdue yaş kapısını ve
-- 179/180/181 gün eşik taramasını da kapsar; karar tablosunun GÖVDESİ
-- iki projede birebir aynıdır ve scripts/check-rotation-notify-parity.mjs
-- bunu denetler. Buradaki amaç acente notifier'ının kendi kararlarını
-- uçtan uca kanıtlamaktır.
--
-- Karar tablosu migration 271'de agency.rotation_check_decision() olarak
-- YASAR ve notify-rotation-overdue.ps1 BU FONKSİYONU ÇAĞIRIR. Buradaki
-- test kararın kopyası değil, betiğin kullandığı tek kaynağı doğrular;
-- iki taraf ayrılırsa test kırmızı olur.
--
-- "Gürültülü" kasıtlıdır: her senaryo için beklenen karar, girdiler ve
-- gerekçe RAISE NOTICE ile basılır; test/*.sql zinciri CI loglarında
-- karar tablosunu satır satır okunabilir hâlde gösterir.
--
-- Zincirde alfabetik sırayla koşulur; BEGIN/ROLLBACK ile izole eder ve
-- canlı SECRET_KEY_BASE / NEXUS_CONFIG_KEY kayıtlarına DOKUNMAZ.

BEGIN;

-- Beklenen kararı doğrular ve gerekçesiyle birlikte gürültü üretir.
CREATE OR REPLACE FUNCTION pg_temp.assert_rotation_decision(
  p_label text,
  p_state text,
  p_age_hours numeric,
  p_max_days int,
  p_previous_present boolean,
  p_expected_exit int,
  p_expected_kind text,
  p_why text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_exit int;
  v_severity text;
  v_kind text;
BEGIN
  SELECT d.exit_code, d.severity, d.alert_kind
    INTO v_exit, v_severity, v_kind
  FROM agency.rotation_check_decision(
         p_state, p_age_hours, p_max_days, p_previous_present) AS d;

  IF v_exit IS DISTINCT FROM p_expected_exit OR v_kind IS DISTINCT FROM p_expected_kind THEN
    RAISE EXCEPTION '% senaryosu başarısız: beklenen exit=% kind=% ama exit=% kind=%',
      p_label, p_expected_exit, p_expected_kind, v_exit, v_kind;
  END IF;

  RAISE NOTICE '  [%] exit=% severity=% kind=%  <- %',
    p_label, v_exit, v_severity, v_kind, p_why;
END;
$$;

-- SENARYO 1'in state'i YAPAY OLARAK YAZILMAZ: test sırına taze kayıt
-- eklenir, böylece agency.rotation_window_state gerçekten 'open' döner ve
-- 247 ile karar tablosu arasındaki bağlantı da doğrulanır. Kayıt yalnızca
-- bu transaction içinde yaşar (ROLLBACK).
INSERT INTO agency.secret_rotations(secret_name, source)
VALUES ('DECISION_TEST_SECRET', 'test');

-- Senaryolar ve gürültü bir DO bloğunda: RAISE NOTICE yalnızca plpgsql
-- içinde geçerlidir.
DO $$
DECLARE
  v_state text;
  v_age numeric;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '== acente notify-rotation-overdue karar tablosu ==';

  -- ---------------------------------------------------------------------
  -- SENARYO 1: open -> sağlıklı, çıkış 0
  -- Rotasyon taze; PREVIOUS .env'de olsa bile uyari üretilmez çünkü
  -- pencere içindeyken PREVIOUS kalabilir.
  -- ---------------------------------------------------------------------
  v_state := agency.rotation_window_state('DECISION_TEST_SECRET');
  IF v_state IS DISTINCT FROM 'open' THEN
    RAISE EXCEPTION 'taze kayıt ''open'' vermeliydi ama %', v_state;
  END IF;

  PERFORM pg_temp.assert_rotation_decision(
    'open', v_state, 0.5, 180, true,
    0, 'none',
    'pencere açık; PREVIOUS kalabilir, uyarı üretilmez');

  -- ---------------------------------------------------------------------
  -- SENARYO 2: expired + PREVIOUS var -> çıkış 1, PREVIOUS kaldırılmalı
  -- Yaş 72 saat > 48 saat pencere. state ve yaş yine de migration 247'den
  -- GELİR: taze kayıt yaşlandırılır, durum yeniden okunur.
  -- ---------------------------------------------------------------------
  UPDATE agency.secret_rotations
     SET rotated_at = now() - interval '72 hours'
   WHERE secret_name = 'DECISION_TEST_SECRET';

  v_state := agency.rotation_window_state('DECISION_TEST_SECRET');
  IF v_state IS DISTINCT FROM 'expired' THEN
    RAISE EXCEPTION '72 saatlik kayıt ''expired'' vermeliydi ama %', v_state;
  END IF;

  SELECT agency.latest_rotation_age_hours('DECISION_TEST_SECRET') INTO v_age;

  PERFORM pg_temp.assert_rotation_decision(
    'expired+previous', v_state, v_age, 180, true,
    1, 'window_expired_previous_present',
    'pencere doldu ve PREVIOUS hâlâ .env''de; kaldırılmalı');

  -- ---------------------------------------------------------------------
  -- SENARYO 2b: expired + PREVIOUS YOK -> sağlıklı, çıkış 0
  -- Pencere doldu ama eski değer kaldırıldı; artık kullanılmıyor. Sıcak
  -- durum DEĞİL: çıkış 0, uyari yok. Bu ayrım notifier'ın çıkış
  -- sözleşmesinin kritik parçasıdır (sessizce "sıcak" saymamak).
  -- ---------------------------------------------------------------------
  PERFORM pg_temp.assert_rotation_decision(
    'expired-no-previous', v_state, v_age, 180, false,
    0, 'none',
    'pencere doldu ama PREVIOUS kaldırılmış; sağlıklı durum');

  -- ---------------------------------------------------------------------
  -- SENARYO 3: unknown -> fail-closed, çıkış 1
  -- Hiç kayıt olmayan sır: yaş NULL. Kayıtsız sır denetlenemez.
  -- ---------------------------------------------------------------------
  PERFORM pg_temp.assert_rotation_decision(
    'unknown', agency.rotation_window_state('DECISION_TEST_YOK'), NULL, 180, false,
    1, 'no_record',
    'kayıt yok; fail-closed, denetlenemeyen sır uyarılır');

  -- unknown + PREVIOUS olsa da karar değişmez (fail-closed).
  PERFORM pg_temp.assert_rotation_decision(
    'unknown+previous', agency.rotation_window_state('DECISION_TEST_YOK'), NULL, 180, true,
    1, 'no_record',
    'PREVIOUS varlığı fail-closed kararını değiştirmez');

  -- ---------------------------------------------------------------------
  -- Sınır durumu: beklenmeyen durum sessizce geçmez, çıkış 2 üretir.
  -- ---------------------------------------------------------------------
  PERFORM pg_temp.assert_rotation_decision(
    'unexpected-state', 'weird_state', 1, 180, false,
    2, 'unexpected_state',
    'beklenmeyen pencere durumu: denetim yapılamadı, uyarı yok');

  RAISE NOTICE '';
  RAISE NOTICE 'PASS: acente notify-rotation-overdue karar tablosu (open / expired+previous / unknown + expired-no-previous + 2 sınır durumu)';
END;
$$;

DROP FUNCTION pg_temp.assert_rotation_decision(text, text, numeric, int, boolean, int, text, text);

ROLLBACK;