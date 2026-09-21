-- Canonical category contract v1.0.0 shared with NEXUS.
CREATE TABLE IF NOT EXISTS agency.contract_versions (
  contract_name text PRIMARY KEY,
  version text NOT NULL,
  activated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO agency.contract_versions(contract_name,version)
VALUES ('nexus.catalog.categories','1.0.0')
ON CONFLICT(contract_name) DO UPDATE
SET version=excluded.version,activated_at=now();

-- Refuse an ambiguous merge rather than silently losing category fields.
DO $$
DECLARE conflict_count int;
BEGIN
  SELECT count(*) INTO conflict_count
  FROM agency.categories old_category
  JOIN agency.categories canonical
    ON canonical.tenant_id=old_category.tenant_id
   AND canonical.code=CASE old_category.code
     WHEN 'OTEL' THEN 'hotel' WHEN 'VILLA' THEN 'villa' WHEN 'YAT' THEN 'yacht'
     WHEN 'TUR' THEN 'tour' WHEN 'AKTIVITE' THEN 'activity' WHEN 'UCUS' THEN 'flight'
     WHEN 'ARAC' THEN 'car' WHEN 'KRUVAZIYER' THEN 'cruise'
     WHEN 'HAC_UMRE' THEN 'pilgrimage' WHEN 'VIZE' THEN 'visa'
     WHEN 'FERIBOT' THEN 'ferry' WHEN 'TRANSFER' THEN 'transfer'
     WHEN 'SEZLONG' THEN 'beach' WHEN 'SINEMA' THEN 'cinema'
     WHEN 'ETKINLIK' THEN 'event' WHEN 'RESTORAN' THEN 'restaurant'
     WHEN 'OTOBUS' THEN 'bus' ELSE old_category.code END
  WHERE old_category.code<>canonical.code;
  IF conflict_count>0 THEN
    RAISE EXCEPTION 'canonical category migration found % duplicate legacy/canonical pairs',conflict_count;
  END IF;
END $$;

UPDATE agency.categories SET
 code=CASE code
   WHEN 'OTEL' THEN 'hotel' WHEN 'VILLA' THEN 'villa' WHEN 'YAT' THEN 'yacht'
   WHEN 'TUR' THEN 'tour' WHEN 'AKTIVITE' THEN 'activity' WHEN 'UCUS' THEN 'flight'
   WHEN 'ARAC' THEN 'car' WHEN 'KRUVAZIYER' THEN 'cruise'
   WHEN 'HAC_UMRE' THEN 'pilgrimage' WHEN 'VIZE' THEN 'visa'
   WHEN 'FERIBOT' THEN 'ferry' WHEN 'TRANSFER' THEN 'transfer'
   WHEN 'SEZLONG' THEN 'beach' WHEN 'SINEMA' THEN 'cinema'
   WHEN 'ETKINLIK' THEN 'event' WHEN 'RESTORAN' THEN 'restaurant'
   WHEN 'OTOBUS' THEN 'bus' ELSE lower(code) END,
 name=CASE code
   WHEN 'OTEL' THEN 'Otel' WHEN 'VILLA' THEN 'Villa' WHEN 'YAT' THEN 'Yat'
   WHEN 'TUR' THEN 'Tur' WHEN 'AKTIVITE' THEN 'Aktivite' WHEN 'UCUS' THEN 'Uçuş'
   WHEN 'ARAC' THEN 'Araç' WHEN 'KRUVAZIYER' THEN 'Kruvaziyer'
   WHEN 'HAC_UMRE' THEN 'Hac & Umre' WHEN 'VIZE' THEN 'Vize'
   WHEN 'FERIBOT' THEN 'Feribot' WHEN 'TRANSFER' THEN 'Transfer'
   WHEN 'SEZLONG' THEN 'Şezlong' WHEN 'SINEMA' THEN 'Sinema'
   WHEN 'ETKINLIK' THEN 'Etkinlik' WHEN 'RESTORAN' THEN 'Restoran'
   WHEN 'OTOBUS' THEN 'Otobüs' ELSE name END;

UPDATE agency.listings SET category=CASE category
 WHEN 'OTEL' THEN 'hotel' WHEN 'VILLA' THEN 'villa' WHEN 'YAT' THEN 'yacht'
 WHEN 'TUR' THEN 'tour' WHEN 'AKTIVITE' THEN 'activity' WHEN 'UCUS' THEN 'flight'
 WHEN 'ARAC' THEN 'car' WHEN 'KRUVAZIYER' THEN 'cruise'
 WHEN 'HAC_UMRE' THEN 'pilgrimage' WHEN 'VIZE' THEN 'visa'
 WHEN 'FERIBOT' THEN 'ferry' WHEN 'TRANSFER' THEN 'transfer'
 WHEN 'SEZLONG' THEN 'beach' WHEN 'SINEMA' THEN 'cinema'
 WHEN 'ETKINLIK' THEN 'event' WHEN 'RESTORAN' THEN 'restaurant'
 WHEN 'OTOBUS' THEN 'bus' ELSE lower(category) END;

INSERT INTO agency.categories(tenant_id,code,name,slug,description,active,sort_order)
SELECT id,'bus','Otobüs','otobus','Otobüs hattı, sefer ve koltuk ürünleri',true,17
FROM agency.tenants
ON CONFLICT(tenant_id,code) DO UPDATE SET
 name=excluded.name,slug=excluded.slug,description=excluded.description,
 active=true,sort_order=excluded.sort_order;

