-- Rotasyon denetimi karar tablosu (notify-rotation-overdue.ps1 muadili).
--
-- Platform ayni tabloyu events.rotation_check_decision adiyla 192'de
-- yazdi. Bu migration acente aynasidir: sema adi agency'dir, govde
-- birebir ayni sozlesmeyi ifade eder. Iki projenin rotasyon uyarisi
-- ayni girdide ayni karari vermelidir (AGENTS.md: sozlesme degisikligi
-- tek taraflı olamaz).
--
-- Betik daha once karari kendi switch'iyle veriyordu ve karar test
-- edilemiyordu. Artik betik BU FONKSIYONU CAGIRIR; test/
-- rotation_overdue_decisions.sql (acente) karar tablosunu dogrular.
--
-- Girdi/cikti sozlesmesi:
--   p_state            agency.rotation_window_state() ciktisi
--   p_age_hours        agency.latest_rotation_age_hours() ciktisi
--                      (kayit yoksa NULL)
--   p_max_days         -SecretKeyRotationMaxDays (varsayilan 180)
--   p_previous_present SECRET_KEY_BASE_PREVIOUS .env'de tanimli mi
--
--   exit_code    cikis kodu (0 saglikli, 1 uyari, 2 denetim yapilamadi)
--   severity     'ok' | 'warn' | 'error'
--   alert_kind   'none' | 'overdue' | 'window_expired_previous_present'
--                | 'no_record' | 'unexpected_state'
--
-- SIRA ONEMLI: yas kapisi (overdue) pencere durumundan ONCE gelir; bu
-- sira platform muadiliyle ve eski betikle aynidir.

CREATE OR REPLACE FUNCTION agency.rotation_check_decision(
  p_state text,
  p_age_hours numeric,
  p_max_days int,
  p_previous_present boolean
)
RETURNS TABLE(exit_code int, severity text, alert_kind text)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_age_days numeric;
BEGIN
  -- 1) Yas kapisi: pencere durumundan bagimsiz, en ust oncelikli. Kayit
  --    yoksa yas NULL'dir ve bu adim atlanir (fail-closed degeri asagida
  --    'no_record' olarak uretilir).
  IF p_age_hours IS NOT NULL THEN
    v_age_days := round((p_age_hours / 24.0)::numeric, 2);
    IF p_max_days IS NOT NULL AND v_age_days > p_max_days THEN
      RETURN QUERY SELECT 1, 'warn', 'overdue'::text;
      RETURN;
    END IF;
  END IF;

  -- 2) Pencere durumu.
  CASE p_state
    WHEN 'open' THEN
      -- Rotasyon yeni ve PREVIOUS kalabilir: saglikli durum, uyari yok.
      RETURN QUERY SELECT 0, 'ok', 'none'::text;
    WHEN 'expired' THEN
      -- Pencere doldu. PREVIOUS hala .env'de ise uyari; kaldirilmissa
      -- saglikli durum (eski deger artik kullanilmiyor).
      IF COALESCE(p_previous_present, false) THEN
        RETURN QUERY SELECT 1, 'warn', 'window_expired_previous_present'::text;
      ELSE
        RETURN QUERY SELECT 0, 'ok', 'none'::text;
      END IF;
    WHEN 'unknown' THEN
      -- Kayitsiz sir denetlenemez: fail-closed, uyari uretilir.
      RETURN QUERY SELECT 1, 'warn', 'no_record'::text;
    ELSE
      -- Beklenmeyen durum: denetim yapilamadi (cikis 2).
      RETURN QUERY SELECT 2, 'error', 'unexpected_state'::text;
  END CASE;
END;
$$;

COMMENT ON FUNCTION agency.rotation_check_decision(text, numeric, int, boolean) IS
  'notify-rotation-overdue.ps1 karar tablosu: (exit_code, severity, alert_kind). Yas kapisi pencere durumundan onceliklidir.';

-- Uygulama rolu karar tablosunu OKUMAZ (betik owner kimligiyle baglanir);
-- salt-okur yetki verilmez, operasyonel yuzey genislemez.
REVOKE ALL ON FUNCTION agency.rotation_check_decision(text, numeric, int, boolean) FROM PUBLIC;
