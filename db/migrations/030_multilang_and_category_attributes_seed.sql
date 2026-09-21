-- 030_multilang_and_category_attributes_seed.sql
-- 1. Activate all 6 languages: TR, EN, DE, RU, AR, FR
-- 2. Seed comprehensive category fields / attributes for all 16 categories
-- 3. Seed category name translations in 6 languages

-- 1. Ensure all 6 languages exist and are active
INSERT INTO agency.languages (code, name, native_name, active, is_default) VALUES
  ('tr', 'Turkish', 'Türkçe', true, true),
  ('en', 'English', 'English', true, false),
  ('de', 'German', 'Deutsch', true, false),
  ('ru', 'Russian', 'Русский', true, false),
  ('ar', 'Arabic', 'العربية', true, false),
  ('fr', 'French', 'Français', true, false)
ON CONFLICT (code) DO UPDATE SET active = true, native_name = EXCLUDED.native_name;

-- 2. Seed Category Attributes (agency.category_fields)
-- Helper: Insert category fields for all tenants matching category code
DO $$
DECLARE
  t RECORD;
  cat_id uuid;
BEGIN
  FOR t IN SELECT id FROM agency.tenants LOOP
    
    -- OTEL (Hotel)
    SELECT id INTO cat_id FROM agency.categories WHERE tenant_id = t.id AND code = 'OTEL';
    IF cat_id IS NOT NULL THEN
      INSERT INTO agency.category_fields (category_id, field_key, label, field_type, required, options, sort_order) VALUES
        (cat_id, 'star_rating', 'Yıldız Sayısı (1-5 Yıldız / Butik)', 'select', true, '["1 Yıldız","2 Yıldız","3 Yıldız","4 Yıldız","5 Yıldız","Butik Otel","Tatil Köyü"]'::jsonb, 1),
        (cat_id, 'board_type', 'Pansiyon Türü', 'select', true, '["Ultra Her Şey Dahil","Her Şey Dahil","Tam Pansiyon","Yarım Pansiyon","Oda Kahvaltı","Sadece Yatak"]'::jsonb, 2),
        (cat_id, 'beach_distance', 'Denize Mesafe (metre/km)', 'text', false, '[]'::jsonb, 3),
        (cat_id, 'room_types', 'Oda Tipleri', 'multiselect', false, '["Standart Oda","Deluxe Oda","Aile Odası","Suit Oda","Deniz Manzaralı","Jakuzili Balayı Odası"]'::jsonb, 4),
        (cat_id, 'aquapark', 'Aquapark / Su Kaydırağı', 'boolean', false, '[]'::jsonb, 5)
      ON CONFLICT (category_id, field_key) DO UPDATE SET label = EXCLUDED.label, options = EXCLUDED.options, sort_order = EXCLUDED.sort_order;
    END IF;

    -- VILLA (Villa)
    SELECT id INTO cat_id FROM agency.categories WHERE tenant_id = t.id AND code = 'VILLA';
    IF cat_id IS NOT NULL THEN
      INSERT INTO agency.category_fields (category_id, field_key, label, field_type, required, options, sort_order) VALUES
        (cat_id, 'pool_type', 'Havuz Türü', 'select', true, '["Özel Müstakil Havuz","Ortak Havuz","Sonsuzluk (Infinity) Havuzu","Havuzsuz"]'::jsonb, 1),
        (cat_id, 'sheltered', 'Korunaklı / Dışarıdan Görünmez', 'boolean', true, '[]'::jsonb, 2),
        (cat_id, 'pool_dimensions', 'Havuz Ölçüleri (En x Boy x Derinlik)', 'text', false, '[]'::jsonb, 3),
        (cat_id, 'pool_heating', 'Isıtmalı Havuz', 'boolean', false, '[]'::jsonb, 4),
        (cat_id, 'bedrooms_count', 'Yatak Odası Sayısı', 'number', true, '[]'::jsonb, 5),
        (cat_id, 'bathrooms_count', 'Banyo Sayısı', 'number', true, '[]'::jsonb, 6),
        (cat_id, 'capacity_pax', 'Maksimum Konaklama Kapasitesi (Kişi)', 'number', true, '[]'::jsonb, 7),
        (cat_id, 'jacuzzi', 'Jakuzi', 'boolean', false, '[]'::jsonb, 8),
        (cat_id, 'damage_deposit', 'Hasar Depozitosu (TL)', 'money', false, '[]'::jsonb, 9),
        (cat_id, 'ministry_license_no', 'Kültür ve Turizm Bakanlığı Belge No', 'text', true, '[]'::jsonb, 10)
      ON CONFLICT (category_id, field_key) DO UPDATE SET label = EXCLUDED.label, options = EXCLUDED.options, sort_order = EXCLUDED.sort_order;
    END IF;

    -- YAT (Yacht)
    SELECT id INTO cat_id FROM agency.categories WHERE tenant_id = t.id AND code = 'YAT';
    IF cat_id IS NOT NULL THEN
      INSERT INTO agency.category_fields (category_id, field_key, label, field_type, required, options, sort_order) VALUES
        (cat_id, 'yacht_type', 'Tekne / Yat Türü', 'select', true, '["Gulet","Motoryat","Katamaran","Yelkenli","Sürat Teknesi"]'::jsonb, 1),
        (cat_id, 'cabins_count', 'Kabin Sayısı', 'number', true, '[]'::jsonb, 2),
        (cat_id, 'berth_capacity', 'Yatak Kapasitesi', 'number', true, '[]'::jsonb, 3),
        (cat_id, 'skipper_status', 'Kaptan / Mürettebat Hizmeti', 'select', true, '["Kaptanlı (Mürettebat Dahil)","Kaptansız (Bareboat)","Opsiyonel Kaptan"]'::jsonb, 4),
        (cat_id, 'fuel_included', 'Yakıt Durumu', 'select', false, '["Yakıt Fiyata Dahil","Yakıt Kullanıma Göre Ekstra"]'::jsonb, 5),
        (cat_id, 'home_port', 'Kalkış / Bağlama Limanı', 'text', true, '[]'::jsonb, 6),
        (cat_id, 'air_condition', 'Klima Hizmeti', 'select', false, '["24 Saat Kesintisiz","Günde 4-6 Saat","Klimasız"]'::jsonb, 7)
      ON CONFLICT (category_id, field_key) DO UPDATE SET label = EXCLUDED.label, options = EXCLUDED.options, sort_order = EXCLUDED.sort_order;
    END IF;

    -- TUR (Tour)
    SELECT id INTO cat_id FROM agency.categories WHERE tenant_id = t.id AND code = 'TUR';
    IF cat_id IS NOT NULL THEN
      INSERT INTO agency.category_fields (category_id, field_key, label, field_type, required, options, sort_order) VALUES
        (cat_id, 'tour_type', 'Tur Türü', 'select', true, '["Günübirlik Tur","Konaklamalı Paket Tur","Özel VIP Tur","Yurtdışı Tur"]'::jsonb, 1),
        (cat_id, 'duration_days_hours', 'Tur Süresi', 'text', true, '[]'::jsonb, 2),
        (cat_id, 'departure_point', 'Kalkış / Buluşma Noktası', 'text', true, '[]'::jsonb, 3),
        (cat_id, 'included_items', 'Dahil Olan Hizmetler', 'textarea', false, '[]'::jsonb, 4),
        (cat_id, 'guide_languages', 'Rehberlik Dilleri', 'multiselect', false, '["Türkçe","English","Deutsch","Русский","العربية"]'::jsonb, 5)
      ON CONFLICT (category_id, field_key) DO UPDATE SET label = EXCLUDED.label, options = EXCLUDED.options, sort_order = EXCLUDED.sort_order;
    END IF;

    -- AKTIVITE (Activity)
    SELECT id INTO cat_id FROM agency.categories WHERE tenant_id = t.id AND code = 'AKTIVITE';
    IF cat_id IS NOT NULL THEN
      INSERT INTO agency.category_fields (category_id, field_key, label, field_type, required, options, sort_order) VALUES
        (cat_id, 'activity_type', 'Aktivite Türü', 'select', true, '["Yamaç Paraşütü","Scuba Diving (Dalış)","Jeep & ATV Safari","Rafting","Tekne Turu","Balon Turu"]'::jsonb, 1),
        (cat_id, 'min_age', 'Minimum Yaş Sınırı', 'number', false, '[]'::jsonb, 2),
        (cat_id, 'equipment_provided', 'Ekipman Sağlanıyor mu?', 'boolean', true, '[]'::jsonb, 3),
        (cat_id, 'insurance_included', 'Sigorta Dahil mi?', 'boolean', true, '[]'::jsonb, 4)
      ON CONFLICT (category_id, field_key) DO UPDATE SET label = EXCLUDED.label, options = EXCLUDED.options, sort_order = EXCLUDED.sort_order;
    END IF;

    -- ARAC (Car Rental)
    SELECT id INTO cat_id FROM agency.categories WHERE tenant_id = t.id AND code = 'ARAC';
    IF cat_id IS NOT NULL THEN
      INSERT INTO agency.category_fields (category_id, field_key, label, field_type, required, options, sort_order) VALUES
        (cat_id, 'transmission', 'Vites Tipi', 'select', true, '["Otomatik","Manuel"]'::jsonb, 1),
        (cat_id, 'fuel_type', 'Yakıt Tipi', 'select', true, '["Benzin","Dizel","Hibrit","Elektrik"]'::jsonb, 2),
        (cat_id, 'vehicle_segment', 'Araç Segmenti', 'select', true, '["Ekonomik","Kompakt","SUV","Lüks & VIP","Minibüs"]'::jsonb, 3),
        (cat_id, 'min_license_age', 'Min. Ehliyet Yaşı (Yıl)', 'number', false, '[]'::jsonb, 4),
        (cat_id, 'deposit_amount', 'Provizyon / Depozito Tutarı (TL)', 'money', false, '[]'::jsonb, 5)
      ON CONFLICT (category_id, field_key) DO UPDATE SET label = EXCLUDED.label, options = EXCLUDED.options, sort_order = EXCLUDED.sort_order;
    END IF;

    -- TRANSFER (Transfer)
    SELECT id INTO cat_id FROM agency.categories WHERE tenant_id = t.id AND code = 'TRANSFER';
    IF cat_id IS NOT NULL THEN
      INSERT INTO agency.category_fields (category_id, field_key, label, field_type, required, options, sort_order) VALUES
        (cat_id, 'vehicle_type', 'Araç Sınıfı', 'select', true, '["Mercedes Vito VIP (6 Kişi)","Mercedes Sprinter VIP (16 Kişi)","Sedan Lüks (3 Kişi)"]'::jsonb, 1),
        (cat_id, 'route_name', 'Güzergah (Havalimanı - Bölge)', 'text', true, '[]'::jsonb, 2),
        (cat_id, 'meet_and_greet', 'Havalimanı İsimli Karşılama', 'boolean', true, '[]'::jsonb, 3)
      ON CONFLICT (category_id, field_key) DO UPDATE SET label = EXCLUDED.label, options = EXCLUDED.options, sort_order = EXCLUDED.sort_order;
    END IF;

    -- RESTORAN (Restaurant)
    SELECT id INTO cat_id FROM agency.categories WHERE tenant_id = t.id AND code = 'RESTORAN';
    IF cat_id IS NOT NULL THEN
      INSERT INTO agency.category_fields (category_id, field_key, label, field_type, required, options, sort_order) VALUES
        (cat_id, 'table_location', 'Masa Tercihi', 'select', true, '["Deniz Kenarı","Teras","Bahçe / Açık Alan","VIP Salon"]'::jsonb, 1),
        (cat_id, 'cuisine', 'Mutfak Türü', 'select', true, '["Ege & Deniz Ürünleri","Steakhouse","Geleneksel Türk","İtalyan & Akdeniz","Uzakdoğu"]'::jsonb, 2),
        (cat_id, 'min_spend', 'Kişi Başı Ortalama / Min. Harcama (TL)', 'money', false, '[]'::jsonb, 3)
      ON CONFLICT (category_id, field_key) DO UPDATE SET label = EXCLUDED.label, options = EXCLUDED.options, sort_order = EXCLUDED.sort_order;
    END IF;

    -- SEZLONG (Sunbed)
    SELECT id INTO cat_id FROM agency.categories WHERE tenant_id = t.id AND code = 'SEZLONG';
    IF cat_id IS NOT NULL THEN
      INSERT INTO agency.category_fields (category_id, field_key, label, field_type, required, options, sort_order) VALUES
        (cat_id, 'row_position', 'Konum & Sıra', 'select', true, '["1. Sıra (Deniz Kenarı)","2. & 3. Sıra","VIP Loca","Çim Alan"]'::jsonb, 1),
        (cat_id, 'includes_towel', 'Plaj Havlusu & Su Dahil', 'boolean', true, '[]'::jsonb, 2),
        (cat_id, 'min_spend_limit', 'Harcama Limiti (TL)', 'money', false, '[]'::jsonb, 3)
      ON CONFLICT (category_id, field_key) DO UPDATE SET label = EXCLUDED.label, options = EXCLUDED.options, sort_order = EXCLUDED.sort_order;
    END IF;

  END LOOP;
END $$;
