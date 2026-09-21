-- Shared supplier/listing contract v1.0.0 for standalone agency operation.
-- Mirrors Nexustraveltech db/migrations/113_supplier_listing_contract_v1.sql
-- into tenant-scoped agency.category_fields.

INSERT INTO agency.contract_versions(contract_name, version)
VALUES ('nexus.supplier_listing', '1.0.0')
ON CONFLICT (contract_name) DO UPDATE
SET version = EXCLUDED.version,
    activated_at = now();

WITH contract_fields(category_code, field_key, label, field_type, choices, required, sort_order) AS (
  VALUES
  ('hotel','property_type','Tesis türü','select','Otel,Butik Otel,Apart Otel,Pansiyon,Resort,Tatil Köyü',true,10),
  ('hotel','room_types','Oda tipleri','textarea','',true,20),
  ('hotel','board_type','Pansiyon tipi','select','Oda Kahvaltı,Yarım Pansiyon,Tam Pansiyon,Her Şey Dahil,Ultra Her Şey Dahil,Sadece Oda',true,30),
  ('hotel','check_in_time','Giriş saati','text','',true,40),
  ('hotel','check_out_time','Çıkış saati','text','',true,50),
  ('hotel','amenities','Tesis olanakları','textarea','',false,60),
  ('hotel','star_rating','Yıldız / sınıf','select','1,2,3,4,5,Boutique,Special Class',false,70),

  ('villa','property_type','Mülk türü','select','Villa,Apart,Daire,Tatil Evi,Bungalov,Dağ Evi',true,10),
  ('villa','bedroom_count','Yatak odası sayısı','number','',true,20),
  ('villa','bathroom_count','Banyo sayısı','number','',true,30),
  ('villa','guest_capacity','Misafir kapasitesi','number','',true,40),
  ('villa','pool_type','Havuz tipi','select','Yok,Özel Havuz,Ortak Havuz,Isıtmalı Havuz,Korunaklı Havuz',false,50),
  ('villa','kitchen','Mutfak','select','Yok,Mini Mutfak,Tam Donanımlı Mutfak,Açık Mutfak',false,60),
  ('villa','season_rules','Sezon kuralları','textarea','',false,70),

  ('yacht','yacht_type','Yat / tekne türü','select','Gulet,Motoryat,Yelkenli,Katamaran,Tekne',true,10),
  ('yacht','capacity','Kapasite','number','',true,20),
  ('yacht','cabin_count','Kabin sayısı','number','',false,30),
  ('yacht','departure_port','Kalkış limanı','text','',true,40),
  ('yacht','route','Rota','text','',true,50),
  ('yacht','captain_included','Kaptan dahil','boolean','',true,60),
  ('yacht','fuel_policy','Yakıt politikası','text','',false,70),

  ('tour','tour_type','Tur türü','select','Kültür,Doğa,Şehir,Günübirlik,Çok Günlü,Özel Tur',true,10),
  ('tour','duration','Süre','text','',true,20),
  ('tour','start_point','Başlangıç noktası','text','',true,30),
  ('tour','end_point','Bitiş noktası','text','',false,40),
  ('tour','guide_languages','Rehber dilleri','text','',false,50),
  ('tour','group_size_min','Minimum grup','number','',false,60),
  ('tour','group_size_max','Maksimum grup','number','',false,70),

  ('activity','activity_type','Aktivite türü','select','Spor,Doğa,Eğlence,Workshop,Adrenalin,Kültür',true,10),
  ('activity','duration','Süre','text','',true,20),
  ('activity','difficulty','Zorluk','select','Kolay,Orta,Zor,Profesyonel',false,30),
  ('activity','age_limit','Yaş sınırı','text','',false,40),
  ('activity','equipment_included','Ekipman dahil','boolean','',false,50),
  ('activity','meeting_point','Buluşma noktası','text','',true,60),

  ('flight','airline_or_provider','Havayolu / sağlayıcı','text','',true,10),
  ('flight','route_from','Kalkış noktası','text','',true,20),
  ('flight','route_to','Varış noktası','text','',true,30),
  ('flight','fare_class','Bilet sınıfı','select','Ekonomi,Premium Ekonomi,Business,First,Charter',false,40),
  ('flight','baggage_policy','Bagaj politikası','text','',true,50),
  ('flight','ticket_rules','Bilet kuralları','text','',true,60),

  ('car','vehicle_type','Araç tipi','select','Ekonomi,Orta,Üst Segment,SUV,Minivan,Minibüs,Lüks',true,10),
  ('car','brand_model','Marka / model','text','',false,20),
  ('car','transmission','Vites','select','Otomatik,Manuel',true,30),
  ('car','fuel_type','Yakıt tipi','select','Benzin,Dizel,Hibrit,Elektrik,LPG',false,40),
  ('car','seat_count','Koltuk sayısı','number','',true,50),
  ('car','pickup_locations','Teslim alma noktaları','textarea','',true,60),
  ('car','deposit_policy','Depozito politikası','text','',true,70),

  ('cruise','ship_or_provider','Gemi / sağlayıcı','text','',true,10),
  ('cruise','route','Rota','text','',true,20),
  ('cruise','departure_port','Kalkış limanı','text','',true,30),
  ('cruise','cabin_types','Kabin tipleri','textarea','',false,40),
  ('cruise','duration','Süre','text','',true,50),
  ('cruise','board_type','Pansiyon tipi','text','',false,60),

  ('pilgrimage','package_type','Paket türü','select','Hac,Umre,Ramazan Umresi,Kudüs & Umre,Özel Grup',true,10),
  ('pilgrimage','departure_city','Kalkış şehri','text','',true,20),
  ('pilgrimage','duration','Süre','text','',true,30),
  ('pilgrimage','hotel_class','Otel sınıfı','text','',false,40),
  ('pilgrimage','visa_included','Vize dahil','boolean','',false,50),
  ('pilgrimage','guidance_included','Rehberlik dahil','boolean','',true,60),

  ('visa','destination_country','Hedef ülke','text','',true,10),
  ('visa','visa_type','Vize türü','select','Turistik,Ticari,Öğrenci,Aile Ziyareti,Transit,Çalışma',true,20),
  ('visa','processing_time','İşlem süresi','text','',true,30),
  ('visa','required_documents','Gerekli belgeler','textarea','',true,40),
  ('visa','appointment_required','Randevu gerekli','boolean','',false,50),

  ('ferry','route_from','Kalkış noktası','text','',true,10),
  ('ferry','route_to','Varış noktası','text','',true,20),
  ('ferry','operator','Operatör','text','',false,30),
  ('ferry','schedule','Sefer planı','textarea','',true,40),
  ('ferry','vehicle_allowed','Araç kabulü','boolean','',false,50),
  ('ferry','ticket_rules','Bilet kuralları','text','',true,60),

  ('transfer','transfer_type','Transfer türü','select','Havalimanı,Otel,Şehir İçi,Şehirler Arası,Vip,Grup',true,10),
  ('transfer','pickup_location','Alış noktası','text','',true,20),
  ('transfer','dropoff_location','Bırakış noktası','text','',true,30),
  ('transfer','vehicle_type','Araç tipi','text','',true,40),
  ('transfer','capacity','Kapasite','number','',true,50),
  ('transfer','waiting_policy','Bekleme politikası','text','',false,60),

  ('beach','beach_name','Plaj adı','text','',true,10),
  ('beach','access_type','Erişim tipi','select','Günübirlik,Üyelik,Rezervasyonlu,Özel Alan',true,20),
  ('beach','seat_type','Ünite tipi','select','Şezlong,Şemsiye,Loca,Daybed,Kabana',true,30),
  ('beach','capacity','Kapasite','number','',true,40),
  ('beach','food_beverage_policy','Yeme içme politikası','text','',false,50),
  ('beach','time_slot','Zaman dilimi','text','',true,60),

  ('cinema','venue','Mekân','text','',true,10),
  ('cinema','movie_or_program','Film / program','text','',true,20),
  ('cinema','session_time','Seans zamanı','text','',true,30),
  ('cinema','seat_type','Koltuk tipi','text','',false,40),
  ('cinema','ticket_rules','Bilet kuralları','text','',true,50),

  ('event','event_type','Etkinlik türü','select','Konser,Festival,Sergi,Spor,Tiyatro,Workshop,Seminer',true,10),
  ('event','venue','Mekân','text','',true,20),
  ('event','start_datetime','Başlangıç zamanı','text','',true,30),
  ('event','end_datetime','Bitiş zamanı','text','',false,40),
  ('event','ticket_type','Bilet tipi','text','',true,50),
  ('event','age_limit','Yaş sınırı','text','',false,60),

  ('restaurant','cuisine_type','Mutfak türü','text','',true,10),
  ('restaurant','venue','Mekân','text','',true,20),
  ('restaurant','reservation_type','Rezervasyon tipi','select','Masa,Menü,Etkinlik,Grup,Özel Salon',true,30),
  ('restaurant','capacity','Kapasite','number','',false,40),
  ('restaurant','menu_options','Menü seçenekleri','textarea','',false,50),
  ('restaurant','service_hours','Servis saatleri','text','',true,60),

  ('bus','operator','Operatör','text','',true,10),
  ('bus','route_from','Kalkış noktası','text','',true,20),
  ('bus','route_to','Varış noktası','text','',true,30),
  ('bus','seat_type','Koltuk tipi','text','',false,40),
  ('bus','baggage_policy','Bagaj politikası','text','',true,50),
  ('bus','ticket_rules','Bilet kuralları','text','',true,60)
)
INSERT INTO agency.category_fields(category_id, field_key, label, field_type, required, options, sort_order)
SELECT c.id,
       f.field_key,
       f.label,
       f.field_type,
       f.required,
       CASE WHEN f.choices = '' THEN '[]'::jsonb ELSE to_jsonb(string_to_array(f.choices, ',')) END,
       f.sort_order
FROM contract_fields f
JOIN agency.categories c ON c.code = f.category_code
ON CONFLICT(category_id, field_key) DO UPDATE
SET label = EXCLUDED.label,
    field_type = EXCLUDED.field_type,
    required = EXCLUDED.required,
    options = EXCLUDED.options,
    sort_order = EXCLUDED.sort_order;

CREATE OR REPLACE FUNCTION agency.supplier_listing_contract_version()
RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[contract_name, version, activated_at::text]
  FROM agency.contract_versions
  WHERE contract_name IN ('nexus.catalog.categories','nexus.supplier_listing')
  ORDER BY contract_name;
$$;

GRANT EXECUTE ON FUNCTION agency.supplier_listing_contract_version() TO agency_app;
