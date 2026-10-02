-- Secret rotation window gate (platform'daki db/migrations/187
-- sozlesmesinin acente aynalamasi; cift yonlu parite). Her SECRET_KEY_BASE
-- rotasyonu scripts/record-secret-rotation.ps1 ile agency.secret_rotations
-- tablosuna tarihlenir (238). Pencere varsayilani 48 saattir: rotasyondan
-- sonra SECRET_KEY_BASE_PREVIOUS en fazla bu kadar sure devrede kalmali.
-- scripts/check-secret-hygiene.ps1 pencere durumunu bu fonksiyonlardan
-- hesaplar; kayit yoksa durum 'unknown' olur ve kontrol basarisiz sayilir
-- (fail-closed) — kayitsiz sir denetlenemez.
--
-- Ayar tablosu isletim verisidir; agency_app salt-okur (188 muadili),
-- pencere ayari owner/yonetim tarafinda set_rotation_window ile degisir.

CREATE TABLE IF NOT EXISTS agency.secret_rotation_settings (
  secret_name varchar(64) PRIMARY KEY,
  window_hours int NOT NULL CHECK (window_hours BETWEEN 1 AND 24 * 30)
);

INSERT INTO agency.secret_rotation_settings(secret_name, window_hours)
VALUES
  ('SECRET_KEY_BASE', 48),
  ('SECRET_KEY_BASE_PREVIOUS', 48)
ON CONFLICT (secret_name) DO NOTHING;

CREATE OR REPLACE FUNCTION agency.rotation_window_hours(p_secret text)
RETURNS int
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    (SELECT window_hours FROM agency.secret_rotation_settings
      WHERE secret_name = p_secret),
    48
  );
$$;

CREATE OR REPLACE FUNCTION agency.set_rotation_window(p_secret text, p_hours int)
RETURNS void
LANGUAGE plpgsql
VOLATILE
AS $$
BEGIN
  IF p_secret IS NULL OR length(trim(p_secret)) = 0 THEN
    RAISE EXCEPTION 'secret_name is required';
  END IF;
  IF p_hours IS NULL OR p_hours < 1 OR p_hours > 24 * 30 THEN
    RAISE EXCEPTION 'window_hours must be between 1 and 720';
  END IF;
  INSERT INTO agency.secret_rotation_settings(secret_name, window_hours)
  VALUES (left(trim(p_secret), 64), p_hours)
  ON CONFLICT (secret_name) DO UPDATE SET window_hours = EXCLUDED.window_hours;
END;
$$;

CREATE OR REPLACE FUNCTION agency.latest_rotation_age_hours(p_secret text)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
  SELECT round(
    EXTRACT(EPOCH FROM (now() - max(rotated_at))) / 3600.0, 2
  )
  FROM agency.secret_rotations
  WHERE secret_name = p_secret;
$$;

-- Pencere durumu: 'unknown' (kayit yok — fail-closed), 'open' (pencere
-- icinde), 'expired' (pencere kapandi — SECRET_KEY_BASE_PREVIOUS
-- env'den kaldirilmali, hatirlatma burada uretilir).
CREATE OR REPLACE FUNCTION agency.rotation_window_state(p_secret text)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_age numeric;
  v_window int;
BEGIN
  SELECT agency.latest_rotation_age_hours(p_secret) INTO v_age;
  IF v_age IS NULL THEN
    RETURN 'unknown';
  END IF;
  v_window := agency.rotation_window_hours(p_secret);
  IF v_age <= v_window THEN
    RETURN 'open';
  END IF;
  RETURN 'expired';
END;
$$;

COMMENT ON TABLE agency.secret_rotation_settings IS
  'Secret rotation window settings; 48h default for SECRET_KEY_BASE_PREVIOUS.';
COMMENT ON FUNCTION agency.rotation_window_state(text) IS
  'unknown=no record (fail-closed), open=within window, expired=remove previous secret.';

REVOKE ALL ON agency.secret_rotation_settings FROM PUBLIC;
GRANT SELECT ON agency.secret_rotation_settings TO agency_app;
