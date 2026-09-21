-- Ensure every agency tenant has the full canonical category dictionary.
-- Categories are tenant-scoped in acente, so seeding only one tenant causes
-- independent agencies to miss categories even though the shared contract exists.

WITH canonical(code,name,slug,description,sort_order) AS (
  VALUES
    ('hotel','Otel','otel','Otel, resort, butik otel ve konaklama tesisleri',1),
    ('holiday_home','Tatil Evi','tatil-evi','Tatil evi; villa, apart, bungalov, daire ve residence alt türlerini kapsar',2),
    ('yacht','Yat','yat','Yat, tekne ve deniz deneyimleri',3),
    ('tour','Tur','tur','Tur, gezi ve rehberli deneyimler',4),
    ('activity','Aktivite','aktivite','Aktivite, atölye ve deneyim ürünleri',5),
    ('flight','Uçuş','ucus','Uçuş ve havayolu ürünleri',6),
    ('car','Araç','arac','Araç kiralama ve ulaşım ürünleri',7),
    ('cruise','Kruvaziyer','kruvaziyer','Kruvaziyer ve gemi seyahatleri',8),
    ('pilgrimage','Hac & Umre','hac-umre','Hac, umre ve dini seyahat programları',9),
    ('visa','Vize','vize','Vize danışmanlığı ve başvuru hizmetleri',10),
    ('ferry','Feribot','feribot','Feribot ve deniz ulaşımı biletleri',11),
    ('transfer','Transfer','transfer','Havalimanı, şehir içi ve özel transfer hizmetleri',12),
    ('beach','Şezlong','sezlong','Şezlong, plaj ve beach club hizmetleri',13),
    ('cinema','Sinema','sinema','Sinema, seans ve koltuk biletleri',14),
    ('event','Etkinlik','etkinlik','Etkinlik, konser ve organizasyon biletleri',15),
    ('restaurant','Restoran','restoran','Restoran rezervasyonu ve yeme içme hizmetleri',16),
    ('bus','Otobüs','otobus','Otobüs hattı, sefer ve koltuk ürünleri',17)
)
INSERT INTO agency.categories(tenant_id,code,name,slug,description,active,sort_order)
SELECT t.id,c.code,c.name,c.slug,c.description,true,c.sort_order
FROM agency.tenants t
CROSS JOIN canonical c
ON CONFLICT(tenant_id,code) DO UPDATE SET
  name=excluded.name,
  slug=excluded.slug,
  description=excluded.description,
  active=true,
  sort_order=excluded.sort_order;

UPDATE agency.categories
SET active=false,
    name='Villa (Tatil Evi alt türü)',
    slug='villa',
    description='Ana kategori değildir; holiday_home.property_type alt türüdür',
    sort_order=0
WHERE code='villa';

UPDATE agency.contract_versions
SET version='1.1.0', activated_at=now()
WHERE contract_name IN ('nexus.catalog.categories','nexus.supplier_listing');
