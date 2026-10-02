-- Secret rotation baseline: her SECRET_KEY_BASE rotasyonu burada tarihlenir
-- (scripts/record-secret-rotation.ps1). check-secret-hygiene.ps1 rotasyon
-- yaşını bu tablodan hesaplar; kayıt yoksa kontrol "bilinmiyor" der ve
-- başarısız sayar (fail-closed) — kayıtsız sır denetlenemez.
CREATE TABLE IF NOT EXISTS agency.secret_rotations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  secret_name varchar(64) NOT NULL,
  rotated_at timestamptz NOT NULL DEFAULT now(),
  source varchar(64) NOT NULL DEFAULT 'manual'
);

CREATE INDEX IF NOT EXISTS agency_secret_rotations_name_time_idx
  ON agency.secret_rotations(secret_name, rotated_at DESC);

REVOKE ALL ON agency.secret_rotations FROM PUBLIC;
GRANT SELECT, INSERT ON agency.secret_rotations TO agency_app;
