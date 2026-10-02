-- NEXUS_CONFIG_KEY rotasyon penceresi sozlesmesi (platform 193'un acente
-- muadili; 247'nin genisletilmis hali).
--
-- 247 yalniz iki satir seed'lerdi:
--   SECRET_KEY_BASE, SECRET_KEY_BASE_PREVIOUS
-- NEXUS_CONFIG_KEY ise satirsiz kaldi ve agency.rotation_window_hours()
-- varsayilan degeri (48 saat) geri dusuyordu. Ayarli degistirilemese de
-- (asagida) pencere DEGERI artik acikca yazilidir ve iki sifrinin
-- pencereleri ayri ayri olusturulabilir.
--
-- KAPSAM: bu sır ENFORMATIFtir. Acente'de NEXUS_CONFIG_KEY, saklanan
-- ayar degerlerini sifreleyen ust anahtardir ve kayipsiz degistirilemez
-- (scripts/seal-legacy-secrets.ps1 ve src/nexus_agency/secrets.gleam).
-- Dolayisiyla:
--   * PREVIOUS karsiligi YOKTUR; 'expired' durumunda kaldirilacak bir
--     deger bulunmaz.
--   * YAS kapisi (overdue) Gecerlidir ve uyari uretir: anahtarin ne kadar
--     suredir degistirilmedigi izlenir.
--   * 'expired' yalnizca RAPRORLANIR, zorlama uygulanmaz.
--
-- Bu migration 247'yi DEGISTIRMEZ (checksum korunur); yalnizca yeni bir
-- ayar satiri ekler. Platformdaki 193 ile birebir ayni sozlesmedir ve
-- scripts/check-rotation-notify-parity.mjs bunu dogrular.
--
-- Idempotent: ON CONFLICT DO NOTHING ile mevcut operator ayari
-- (varsa set_rotation_window ile degistirilmis) ASLA ezilmez.

INSERT INTO agency.secret_rotation_settings(secret_name, window_hours)
VALUES
  ('NEXUS_CONFIG_KEY', 48)
ON CONFLICT (secret_name) DO NOTHING;

COMMENT ON FUNCTION agency.rotation_window_state(text) IS
  'unknown=no record (fail-closed), open=within window, expired=remove previous secret. NEXUS_CONFIG_KEY icin PREVIOUS karsiligi yoktur: expired yalnizca raporlanir, overdue gecerlidir.';
