-- Supplier panel module contract v1.1.0.
-- These module codes come from contracts/supplier-listing-contract.v1.json
-- and must remain aligned with the central Nexus project.

WITH tenants AS (
  SELECT id AS tenant_id FROM agency.tenants
), modules(code, name, description, sort_order) AS (
  VALUES
    ('dashboard','Genel Bakış','Tedarikçinin günlük operasyon, uyarı ve performans özeti.',10),
    ('company_profile','Şirket Profili','Kuruluş, vergi, iletişim ve ticari profil yönetimi.',20),
    ('documents','Belgeler','Zorunlu belge, onay ve yenileme süreçleri.',30),
    ('catalog','Katalog','İlan, ürün ve hizmet içerik yönetimi.',40),
    ('availability','Müsaitlik','Takvim, stok, kontenjan ve uygunluk yönetimi.',50),
    ('pricing','Fiyatlandırma','Fiyat, sezon, komisyon ve promosyon yönetimi.',60),
    ('reservations','Rezervasyonlar','Talep, opsiyon, onay, iptal ve konaklama akışı.',70),
    ('offers','Teklifler','Kurumsal teklif, özel fiyat ve paket akışı.',80),
    ('customers','Müşteriler','Misafir, müşteri ve ilişki kayıtları.',90),
    ('messages','Mesajlar','Acente, müşteri ve operasyon mesajlaşması.',100),
    ('tasks','İş Takibi','Görev, kontrol listesi ve operasyon takipleri.',110),
    ('staff','Personel','Kullanıcı, rol, vardiya ve ekip yönetimi.',120),
    ('accounting','Muhasebe','Cari, tahsilat, fatura ve finans görünürlüğü.',130),
    ('payments','Ödemeler','Ödeme, iade, teminat ve mutabakat işlemleri.',140),
    ('reports','Raporlar','Operasyon, satış ve finans raporları.',150),
    ('integrations','Entegrasyonlar','Harici servis, kanal ve sağlayıcı bağlantıları.',160),
    ('settings','Ayarlar','Tedarikçi panel ayarları ve çalışma kuralları.',170)
)
INSERT INTO agency.modules(tenant_id, code, name, description, active)
SELECT t.tenant_id, m.code, m.name, m.description, true
FROM tenants t
CROSS JOIN modules m
ON CONFLICT (tenant_id, code) DO UPDATE
  SET name = excluded.name,
      description = excluded.description,
      active = true;
