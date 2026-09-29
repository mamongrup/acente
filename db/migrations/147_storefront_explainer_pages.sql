-- Public role guides are tenant-owned CMS pages and remain editable in page builder.
WITH definitions(slug, title, description) AS (
  VALUES
    ('nasil-calisir', 'Nasıl çalışır?', 'Seyahat seçeneklerini keşfetme, karşılaştırma ve rezervasyon adımlarını öğrenin.'),
    ('tedarikciler-icin', 'Tedarikçiler için', 'Kendi ilanlarınızı, fiyatlarınızı ve müsaitliğinizi acente panelinde yönetin.'),
    ('acenteler-icin', 'Acenteler için', 'Kendi markanız ve ilanlarınızla bağımsız çalışın; isterseniz tedarikçi ağına bağlanın.'),
    ('musteriler-icin', 'Müşteriler için', 'Size uygun seyahat seçeneklerini bulun, bilgileri karşılaştırın ve rezervasyonunuzu takip edin.')
)
INSERT INTO agency.pages (tenant_id, slug, template, status, seo, published_at)
SELECT t.id, d.slug, 'standard', 'published',
       jsonb_build_object('title', d.title, 'description', d.description), now()
FROM agency.tenants t CROSS JOIN definitions d
ON CONFLICT (tenant_id, slug) DO NOTHING;

WITH blocks(slug, sort_order, title, body, button_text, button_url) AS (
  VALUES
    ('nasil-calisir', 0, 'Arayın ve keşfedin', 'Konaklama, tur, yat ve diğer seyahat seçeneklerini kategoriye veya konuma göre inceleyin.', '', ''),
    ('nasil-calisir', 1, 'Bilgileri karşılaştırın', 'İlan açıklamalarını, fiyatları ve mevcut seçenekleri bir arada değerlendirerek size uygun olanı seçin.', '', ''),
    ('nasil-calisir', 2, 'Rezervasyon adımına geçin', 'Seçtiğiniz ilandan talep oluşturun veya sunulan rezervasyon adımlarını izleyin; hesabınızdan süreci takip edin.', 'Tüm ilanları keşfet', '/urunler'),
    ('tedarikciler-icin', 0, 'İlanlarınız sizin kontrolünüzde', 'Otel, tatil evi, yat, tur ve diğer kategorilerdeki kendi ürünlerinizi doğrudan acente panelinden oluşturup düzenleyebilirsiniz.', '', ''),
    ('tedarikciler-icin', 1, 'Fiyat ve müsaitliği yönetin', 'Yayın durumunu, fiyat bilgilerini ve müsaitliği kendi operasyonunuza göre güncel tutun.', '', ''),
    ('tedarikciler-icin', 2, 'İş birliğini seçin', 'Acenteyle yerel olarak çalışabilir veya uygun olduğunda merkezi tedarikçi bağlantısından yararlanabilirsiniz.', 'İletişime geçin', '/iletisim'),
    ('acenteler-icin', 0, 'Kendi markanızla yayın yapın', 'Acente sitenizi ve vitrininizi kendi markanızla yönetin; temel işlevler merkezi bağlantı olmadan da çalışır.', '', ''),
    ('acenteler-icin', 1, 'Yerel ilanlarınızı yönetin', 'Kendi otel, tatil evi, tur, araç ve diğer ilanlarınızı panelden oluşturun, düzenleyin ve yayınlayın.', '', ''),
    ('acenteler-icin', 2, 'Tedarikçi ağına isteğe bağlı bağlanın', 'Dilerseniz harici tedarikçi ilanlarını sitenizde yayınlamak için merkezi ağla bağlantı kurun.', 'İş birliği hakkında bilgi alın', '/iletisim'),
    ('musteriler-icin', 0, 'Size uygun seyahati bulun', 'Farklı kategorilerdeki ilanları ve konumları keşfederek seyahatinize uygun seçenekleri bulun.', '', ''),
    ('musteriler-icin', 1, 'Kararınızı bilgiyle verin', 'İlanın açıklamasını, fiyatını, kapasitesini ve sunulan koşulları birlikte inceleyin.', '', ''),
    ('musteriler-icin', 2, 'Süreci takip edin', 'Rezervasyon ve talepleriniz için hesabınızı kullanın; yardıma ihtiyaç duyduğunuzda bizimle iletişime geçin.', 'Seyahat seçenekleri', '/urunler')
)
INSERT INTO agency.page_blocks (page_id, block_type, sort_order, content)
SELECT p.id, 'info', b.sort_order,
       jsonb_build_object('title', b.title, 'body', b.body, 'button_text', b.button_text, 'button_url', b.button_url)
FROM blocks b JOIN agency.pages p ON p.slug = b.slug
WHERE NOT EXISTS (
  SELECT 1 FROM agency.page_blocks existing
  WHERE existing.page_id = p.id AND existing.sort_order = b.sort_order
);
