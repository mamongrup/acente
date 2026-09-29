-- Keep the existing benefit cards in each tenant's editable page-builder block.
-- Only fill blocks that have not been customized yet.
UPDATE agency.page_blocks b
SET content = b.content || jsonb_build_object('items', jsonb_build_array(
  jsonb_build_object('icon','secure','title','Güvenli Rezervasyon','description','SSL şifreleme ve 3D Secure ödeme altyapısıyla güvenle rezervasyon yapın.'),
  jsonb_build_object('icon','price','title','En İyi Fiyat Garantisi','description','Daha ucuz bulursanız farkı iade ediyoruz. Fiyat garantisi ile içiniz rahat olsun.'),
  jsonb_build_object('icon','support','title','Uzman Destek','description','Alanında uzman seyahat danışmanlarımız 7/24 hizmetinizde.'),
  jsonb_build_object('icon','confirm','title','Anında Onay','description','Çoğu rezervasyon anında onaylanır, anında e-posta ile bilgi alırsınız.'),
  jsonb_build_object('icon','cancel','title','Esnek İptal','description','Birçok ürünümüzde ücretsiz iptal ve değişiklik imkânı.'),
  jsonb_build_object('icon','choice','title','Geniş Seçenek','description','Türkiye geneli ve dünyaya açılan kapsamlı ürün portföyümüz.')
))
FROM agency.pages p
WHERE p.id = b.page_id
  AND p.slug LIKE 'category-%'
  AND b.block_type = 'source_section'
  AND b.content->>'sectionKey' = 'benefits'
  AND NOT (b.content ? 'items');
