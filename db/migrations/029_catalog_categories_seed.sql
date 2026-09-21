-- 029_catalog_categories_seed.sql
-- Seed 16 comprehensive travel agency catalog categories inspired by rezervasyonyap.com.tr

INSERT INTO agency.categories (tenant_id, code, name, slug, description, active, sort_order)
SELECT 
  t.id,
  cat.code,
  cat.name,
  cat.slug,
  cat.description,
  true,
  cat.sort_order
FROM agency.tenants t
CROSS JOIN (
  VALUES
    ('OTEL', 'Otel', 'otel', 'Lüks oteller, butik oteller, tatil köyleri ve pansiyonlar', 1),
    ('VILLA', 'Villa', 'villa', 'Özel havuzlu, korunaklı, lüks kiralık tatil villaları ve yazlıklar', 2),
    ('YAT', 'Yat', 'yat', 'Haftalık gulet, motor yat, katamaran ve yelkenli kiralama', 3),
    ('TUR', 'Tur', 'tur', 'Günübirlik turlar, sabit tarihli paket turlar ve rehberli geziler', 4),
    ('AKTIVITE', 'Aktivite', 'aktivite', 'Yamaç paraşütü, dalış, safari, rafting ve doğa sporları', 5),
    ('UCUS', 'Uçuş', 'ucus', 'Yurtiçi ve yurtdışı uçak bileti arama ve rezervasyonu', 6),
    ('ARAC', 'Araç', 'arac', 'Binek araç, SUV, VIP minibüs, helikopter ve tekne kiralama', 7),
    ('KRUVAZIYER', 'Kruvaziyer', 'kruvaziyer', 'Lüks gemi turları, Akdeniz, Ege ve dünya cruise seferleri', 8),
    ('HAC_UMRE', 'Hac & Umre', 'hac-umre', 'Kutsal topraklar hac ve umre tur organizasyonları', 9),
    ('VIZE', 'Vize', 'vize', 'Schengen, ABD, İngiltere ve dünya vize danışmanlık hizmetleri', 10),
    ('FERIBOT', 'Feribot', 'feribot', 'Yunan adaları, adalara feribot ve deniz otobüsü biletleri', 11),
    ('TRANSFER', 'Transfer', 'transfer', 'Havalimanı VIP transfer, otel karşılama ve şehirlerarası transfer', 12),
    ('SEZLONG', 'Şezlong', 'sezlong', 'Beach club şezlong, loca, VIP plaj rezervasyonları', 13),
    ('SINEMA', 'Sinema', 'sinema', 'Sinema vizyon filmleri, salon ve seans biletleme', 14),
    ('ETKINLIK', 'Etkinlik', 'etkinlik', 'Konser, tiyatro, festival, fuar ve özel gösteri biletleri', 15),
    ('RESTORAN', 'Restoran', 'restoran', 'Gurme restoranlar, akşam yemeği rezervasyonları ve masa ayırtma', 16)
) AS cat(code, name, slug, description, sort_order)
ON CONFLICT (tenant_id, code) DO UPDATE SET
  name = EXCLUDED.name,
  slug = EXCLUDED.slug,
  description = EXCLUDED.description,
  sort_order = EXCLUDED.sort_order,
  active = true;
