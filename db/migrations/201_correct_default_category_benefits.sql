-- Replace only the original stock copy. Tenant-edited benefit cards keep their text.
UPDATE agency.page_blocks AS block
SET content = jsonb_set(
  block.content,
  '{items}',
  (
    SELECT jsonb_agg(
      CASE
        WHEN item->>'title' = 'En İyi Fiyat Garantisi'
         AND item->>'description' = 'Daha ucuz bulursanız farkı iade ediyoruz. Fiyat garantisi ile içiniz rahat olsun.'
          THEN item || jsonb_build_object('title', 'Fiyatları Karşılaştırın', 'description', 'İlanların fiyat ve koşullarını rezervasyon öncesinde inceleyin.')
        WHEN item->>'title' = 'Uzman Destek'
         AND item->>'description' = 'Alanında uzman seyahat danışmanlarımız 7/24 hizmetinizde.'
          THEN item || jsonb_build_object('title', 'Seyahat Desteği', 'description', 'Sorularınız ve talepleriniz için destek kanallarımızı kullanın.')
        WHEN item->>'title' = 'Anında Onay'
         AND item->>'description' = 'Çoğu rezervasyon anında onaylanır, anında e-posta ile bilgi alırsınız.'
          THEN item || jsonb_build_object('title', 'Rezervasyon Takibi', 'description', 'Rezervasyonunuzun durumunu hesabınızdan takip edin.')
        WHEN item->>'title' = 'Esnek İptal'
         AND item->>'description' = 'Birçok ürünümüzde ücretsiz iptal ve değişiklik imkânı.'
          THEN item || jsonb_build_object('title', 'Açık İptal Koşulları', 'description', 'İptal ve değişiklik koşullarını ilan sayfasında inceleyin.')
        ELSE item
      END ORDER BY ordinal
    )
    FROM jsonb_array_elements(block.content->'items') WITH ORDINALITY AS entries(item, ordinal)
  ),
  false
)
FROM agency.pages AS page
WHERE page.id = block.page_id
  AND page.slug LIKE 'category-%'
  AND block.block_type = 'source_section'
  AND block.content->>'sectionKey' = 'benefits'
  AND jsonb_typeof(block.content->'items') = 'array'
  AND EXISTS (
    SELECT 1
    FROM jsonb_array_elements(block.content->'items') AS entry(item)
    WHERE (item->>'title', item->>'description') IN (
      ('En İyi Fiyat Garantisi', 'Daha ucuz bulursanız farkı iade ediyoruz. Fiyat garantisi ile içiniz rahat olsun.'),
      ('Uzman Destek', 'Alanında uzman seyahat danışmanlarımız 7/24 hizmetinizde.'),
      ('Anında Onay', 'Çoğu rezervasyon anında onaylanır, anında e-posta ile bilgi alırsınız.'),
      ('Esnek İptal', 'Birçok ürünümüzde ücretsiz iptal ve değişiklik imkânı.')
    )
  );
