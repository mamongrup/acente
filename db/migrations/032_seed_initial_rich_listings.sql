-- 031_seed_initial_rich_listings.sql
-- Inserts realistic, distinct catalog listings across multiple categories with full metadata, images, and amenities.

INSERT INTO agency.tenants (id, legal_name, brand_name, slug)
VALUES ('ca43626b-4d77-41d8-898c-317576e991b5', 'NEXUS Demo Turizm Ltd.', 'NEXUS Demo', 'nexus-demo')
ON CONFLICT (id) DO NOTHING;

INSERT INTO agency.listings (
  tenant_id,
  code,
  category,
  title,
  locality,
  description,
  currency,
  price_minor,
  status,
  source,
  metadata,
  images,
  amenities,
  owner_info,
  cancellation_policy
) VALUES 
(
  'ca43626b-4d77-41d8-898c-317576e991b5',
  'VIL-2026-001',
  'holiday_home',
  'Bodrum Yalıkavak Panoramik Deniz Manzaralı Lüks Balayı Villası',
  'Yalıkavak, Bodrum, Muğla',
  'Bodrum Yalıkavak koyuna hakim panoramik manzarası, özel sonsuzluk havuzu, jakuzisi ve 4 lüks yatak odasıyla unutulmaz bir tatil deneyimi sunar.',
  'TRY',
  2500000,
  'published',
  'manual',
  '{
    "guests": "8",
    "bedrooms": "4",
    "beds": "5",
    "bathrooms": "4",
    "pool_dimensions": "4x10m Derinlik 1.55m (Sonsuzluk)",
    "sheltered_pool": "true",
    "cleaning_fee": "2500",
    "min_stay_days": "3",
    "commission_percent": "15.00",
    "deposit_percent": "35.00",
    "seo_title": "Bodrum Yalıkavak Lüks Balayı Tatil Villası",
    "seo_description": "Panoramik deniz manzaralı ve özel havuzlu Bodrum Yalıkavak kiralık villa.",
    "slug": "bodrum-yalikavak-luks-balayi-villasi"
  }'::jsonb,
  '[
    "https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1613977257363-707ba9348227?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1200&q=80"
  ]'::jsonb,
  '["pool", "sea_view", "jacuzzi", "sheltered", "ac", "wifi", "bbq", "parking"]'::jsonb,
  '{"name": "Ahmet Yılmaz", "phone": "+90 532 555 1020"}'::jsonb,
  '{"policy": "Giriş tarihinden 14 gün öncesine kadar %100 kesintisiz iade hakkı."}'::jsonb
),
(
  'ca43626b-4d77-41d8-898c-317576e991b5',
  'HTL-2026-002',
  'hotel',
  'Torba Grand Azure Resort & Spa (Ultra Her Şey Dahil)',
  'Torba Koyu, Bodrum, Muğla',
  'Bodrum Torba sahilinde denize sıfır konumda yer alan 5 yıldızlı tesisimiz, aquaparkı, özel mavi bayraklı plajı, spa merkezi ve 3 farklı alakart restoranıyla seçkin misafirlerini ağırlar.',
  'TRY',
  1850000,
  'published',
  'manual',
  '{
    "hotel_stars": "5_star",
    "board_type": "uai",
    "beach_distance": "zero",
    "airport_distance": "32 km",
    "hotel_total_rooms": "140",
    "hotel_total_beds": "350",
    "hotel_pools_count": "3 Açık Havuz, 1 Aquapark",
    "pricing_model": "per_room",
    "check_in_time": "14:00",
    "check_out_time": "12:00",
    "room_types": [
      {
        "id": "1",
        "title": "Standart Kara / Bahçe Manzaralı Oda",
        "size_m2": "30",
        "adults": "2",
        "children": "1",
        "bed": "1 Çift Kişilik",
        "view_type": "Bahçe Manzaralı",
        "count": "60"
      },
      {
        "id": "2",
        "title": "Deluxe Panoramik Deniz Manzaralı Oda",
        "size_m2": "42",
        "adults": "3",
        "children": "1",
        "bed": "1 King Bed + 1 Tek Kişilik",
        "view_type": "Panoramik Deniz",
        "count": "50"
      },
      {
        "id": "3",
        "title": "Aile Süiti (2 Yatak Odalı Aile Odası)",
        "size_m2": "65",
        "adults": "4",
        "children": "2",
        "bed": "1 Çift + 2 Tek Kişilik",
        "view_type": "Deniz & Havuz",
        "count": "30"
      }
    ],
    "seo_title": "Torba Grand Azure Resort & Spa Bodrum",
    "seo_description": "Denize sıfır, 5 yıldızlı ultra her şey dahil Torba Bodrum resort oteli.",
    "slug": "torba-grand-azure-resort-spa"
  }'::jsonb,
  '[
    "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=1200&q=80"
  ]'::jsonb,
  '["private_beach", "open_pool", "aquapark", "heated_indoor_pool", "spa_hamam", "alacarte", "kids_club", "wifi", "fitness", "valet_parking"]'::jsonb,
  '{"name": "Merve Demir", "phone": "+90 252 313 0000"}'::jsonb,
  '{"policy": "Giriş tarihinden 48 saat öncesine kadar %100 kesintisiz iade hakkı."}'::jsonb
),
(
  'ca43626b-4d77-41d8-898c-317576e991b5',
  'YCH-2026-003',
  'yacht',
  'Göcek Koyları 26m Lüks Gulet (Mürettebatlı Mavi Yolculuk)',
  'Göcek Marina, Muğla',
  'Göcek ve Fethiye körfezinin berrak koylarında kaptan, aşçı ve gemici personeli dahil 5 klimalı kabinli ultra lüks ahşap gulet ile mavi tur keyfi.',
  'TRY',
  4200000,
  'published',
  'manual',
  '{
    "guests": "10",
    "bedrooms": "5",
    "beds": "6",
    "bathrooms": "5",
    "cleaning_fee": "0",
    "min_stay_days": "3",
    "commission_percent": "12.00",
    "seo_title": "Göcek 26m Lüks Gulet Kiralama | Mavi Tur",
    "seo_description": "Mürettebatlı 5 kabin lüks gulet ile Göcek koylarında mavi yolculuk.",
    "slug": "gocek-26m-luks-gulet-kiralama"
  }'::jsonb,
  '[
    "https://images.unsplash.com/photo-1569263979104-865ab7cd8d17?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80"
  ]'::jsonb,
  '["wifi", "ac", "sea_view", "skipper", "generator", "sound_system"]'::jsonb,
  '{"name": "Kaptan Serkan", "phone": "+90 533 444 8899"}'::jsonb,
  '{"policy": "Tur tarihinden 30 gün öncesine kadar ücretsiz iptal."}'::jsonb
),
(
  'ca43626b-4d77-41d8-898c-317576e991b5',
  'TUR-2026-004',
  'tour',
  'Kapadokya Balon & Yeraltı Şehri VIP Kültür Turu',
  'Göreme, Nevşehir',
  'Profesyonel rehber eşliğinde Göreme Açık Hava Müzesi, Derinkuyu Yeraltı Şehri, Paşabağ Vadisi ve sıcak hava balonu izleme içeren tam günlük VIP tur.',
  'TRY',
  350000,
  'published',
  'manual',
  '{
    "guests": "16",
    "min_stay_days": "1",
    "seo_title": "Kapadokya VIP Balon & Kültür Turu",
    "seo_description": "Kapadokya tam günlük rehberli yeraltı şehri ve açık hava müzesi turu.",
    "slug": "kapadokya-vip-balon-kultur-turu"
  }'::jsonb,
  '[
    "https://images.unsplash.com/photo-1516483638261-f4dbaf036963?auto=format&fit=crop&w=1200&q=80",
    "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80"
  ]'::jsonb,
  '["guide", "lunch", "transfer", "insurance", "tickets"]'::jsonb,
  '{"name": "Rehber Caner", "phone": "+90 535 777 3322"}'::jsonb,
  '{"policy": "Tur saatinden 24 saat öncesine kadar kesintisiz iade."}'::jsonb
)
ON CONFLICT (tenant_id, code) DO UPDATE SET
  title = EXCLUDED.title,
  locality = EXCLUDED.locality,
  description = EXCLUDED.description,
  currency = EXCLUDED.currency,
  price_minor = EXCLUDED.price_minor,
  status = EXCLUDED.status,
  metadata = EXCLUDED.metadata,
  images = EXCLUDED.images,
  amenities = EXCLUDED.amenities,
  owner_info = EXCLUDED.owner_info,
  cancellation_policy = EXCLUDED.cancellation_policy,
  updated_at = now();

