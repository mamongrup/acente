-- Bootstrap managed storefront/listing filters for every canonical category.
-- These are editable defaults; admins can rename, reorder, add or deactivate
-- groups/items without changing code.

WITH tenants AS (
  SELECT id AS tenant_id FROM agency.tenants
), seed_groups(category_code, group_key, title, help_text, contract_field_key, sort_order) AS (
  VALUES
    ('hotel','property_type','Konaklama tipi','Otel ve konaklama tiplerini yönetin.','property_type',10),
    ('tour','tour_type','Tur tipi','Kültür, doğa, günübirlik ve paket tur tiplerini yönetin.','tour_type',10),
    ('activity','activity_type','Aktivite tipi','Macera, deneyim ve eğlence aktivitelerini yönetin.','activity_type',10),
    ('flight','fare_class','Bilet sınıfı','Uçuş bilet sınıflarını yönetin.','fare_class',10),
    ('car','vehicle_type','Araç tipi','Kiralık araç ve filo tiplerini yönetin.','vehicle_type',10),
    ('cruise','cabin_types','Kabin tipi','Kruvaziyer kabin seçeneklerini yönetin.','cabin_types',10),
    ('pilgrimage','package_type','Paket tipi','Hac ve umre paket tiplerini yönetin.','package_type',10),
    ('visa','visa_type','Vize tipi','Vize başvuru türlerini yönetin.','visa_type',10),
    ('ferry','ticket_rules','Bilet tipi','Feribot bilet tiplerini yönetin.','ticket_rules',10),
    ('transfer','transfer_type','Transfer tipi','Transfer hizmet tiplerini yönetin.','transfer_type',10),
    ('beach','seat_type','Oturma tipi','Şezlong, loca ve plaj kullanım tiplerini yönetin.','seat_type',10),
    ('cinema','seat_type','Koltuk tipi','Sinema koltuk ve salon seçeneklerini yönetin.','seat_type',10),
    ('event','event_type','Etkinlik tipi','Konser, festival, tiyatro ve organizasyon tiplerini yönetin.','event_type',10),
    ('restaurant','cuisine_type','Mutfak tipi','Restoran mutfak ve servis tiplerini yönetin.','cuisine_type',10),
    ('bus','seat_type','Koltuk tipi','Otobüs koltuk ve bilet seçeneklerini yönetin.','seat_type',10)
), inserted_groups AS (
  INSERT INTO agency.category_filter_groups(
    tenant_id, category_code, group_key, title, help_text, display_type, multiple, sort_order, active
  )
  SELECT t.tenant_id, s.category_code, s.group_key, s.title, s.help_text, 'chips', true, s.sort_order, true
  FROM tenants t
  CROSS JOIN seed_groups s
  ON CONFLICT (tenant_id, category_code, group_key) DO UPDATE
    SET title = excluded.title,
        help_text = excluded.help_text,
        display_type = excluded.display_type,
        multiple = excluded.multiple,
        sort_order = excluded.sort_order,
        active = true,
        updated_at = now()
  RETURNING id, tenant_id, category_code, group_key
), seed_items(category_code, group_key, item_key, title, contract_value, sort_order) AS (
  VALUES
    ('hotel','property_type','hotel','Otel','Hotel',10),
    ('hotel','property_type','resort','Resort','Resort',20),
    ('hotel','property_type','boutique','Butik otel','Boutique',30),
    ('hotel','property_type','apart_hotel','Apart otel','Apart Hotel',40),
    ('tour','tour_type','culture','Kültür turu','Culture',10),
    ('tour','tour_type','nature','Doğa turu','Nature',20),
    ('tour','tour_type','daily','Günübirlik tur','Daily',30),
    ('tour','tour_type','package','Paket tur','Package',40),
    ('activity','activity_type','adventure','Macera','Adventure',10),
    ('activity','activity_type','water_sport','Su sporu','Water Sport',20),
    ('activity','activity_type','workshop','Atölye','Workshop',30),
    ('activity','activity_type','show','Gösteri','Show',40),
    ('flight','fare_class','economy','Ekonomi','Economy',10),
    ('flight','fare_class','business','Business','Business',20),
    ('flight','fare_class','first','First class','First',30),
    ('car','vehicle_type','economy','Ekonomi','Economy',10),
    ('car','vehicle_type','suv','SUV','SUV',20),
    ('car','vehicle_type','luxury','Lüks','Luxury',30),
    ('car','vehicle_type','van','Van / Minibüs','Van',40),
    ('cruise','cabin_types','inside','İç kabin','Inside',10),
    ('cruise','cabin_types','oceanview','Deniz manzaralı','Oceanview',20),
    ('cruise','cabin_types','balcony','Balkonlu','Balcony',30),
    ('cruise','cabin_types','suite','Suit','Suite',40),
    ('pilgrimage','package_type','umrah','Umre','Umrah',10),
    ('pilgrimage','package_type','hajj','Hac','Hajj',20),
    ('pilgrimage','package_type','vip','VIP paket','VIP',30),
    ('visa','visa_type','tourist','Turistik','Tourist',10),
    ('visa','visa_type','business','Ticari','Business',20),
    ('visa','visa_type','student','Öğrenci','Student',30),
    ('ferry','ticket_rules','passenger','Yolcu','Passenger',10),
    ('ferry','ticket_rules','vehicle','Araçlı','Vehicle',20),
    ('ferry','ticket_rules','cabin','Kabinli','Cabin',30),
    ('transfer','transfer_type','private','Özel transfer','Private',10),
    ('transfer','transfer_type','shared','Paylaşımlı transfer','Shared',20),
    ('transfer','transfer_type','vip','VIP transfer','VIP',30),
    ('beach','seat_type','sunbed','Şezlong','Sunbed',10),
    ('beach','seat_type','cabana','Loca','Cabana',20),
    ('beach','seat_type','pavilion','Pavilyon','Pavilion',30),
    ('cinema','seat_type','standard','Standart','Standard',10),
    ('cinema','seat_type','vip','VIP','VIP',20),
    ('cinema','seat_type','imax','IMAX','IMAX',30),
    ('event','event_type','concert','Konser','Concert',10),
    ('event','event_type','festival','Festival','Festival',20),
    ('event','event_type','theatre','Tiyatro','Theatre',30),
    ('event','event_type','workshop','Atölye','Workshop',40),
    ('restaurant','cuisine_type','turkish','Türk mutfağı','Turkish',10),
    ('restaurant','cuisine_type','seafood','Deniz ürünleri','Seafood',20),
    ('restaurant','cuisine_type','world','Dünya mutfağı','World',30),
    ('restaurant','cuisine_type','fine_dining','Fine dining','Fine Dining',40),
    ('bus','seat_type','standard','Standart','Standard',10),
    ('bus','seat_type','comfort','Comfort','Comfort',20),
    ('bus','seat_type','vip','VIP','VIP',30)
), active_groups AS (
  SELECT id, tenant_id, category_code, group_key
  FROM inserted_groups
  UNION
  SELECT g.id, g.tenant_id, g.category_code, g.group_key
  FROM agency.category_filter_groups g
  JOIN tenants t ON t.tenant_id = g.tenant_id
  JOIN seed_groups s ON s.category_code = g.category_code AND s.group_key = g.group_key
)
INSERT INTO agency.category_filter_items(
  group_id, item_key, title, contract_field_key, contract_value, sort_order, active
)
SELECT g.id, i.item_key, i.title, g.group_key, i.contract_value, i.sort_order, true
FROM active_groups g
JOIN seed_items i ON i.category_code = g.category_code AND i.group_key = g.group_key
ON CONFLICT (group_id, item_key) DO UPDATE
  SET title = excluded.title,
      contract_field_key = excluded.contract_field_key,
      contract_value = excluded.contract_value,
      sort_order = excluded.sort_order,
      active = true,
      updated_at = now();

SELECT agency.queue_category_filter_translations('group', id, 'tr')
FROM agency.category_filter_groups
WHERE category_code IN (
  'hotel','tour','activity','flight','car','cruise','pilgrimage','visa',
  'ferry','transfer','beach','cinema','event','restaurant','bus'
);

SELECT agency.queue_category_filter_translations('item', i.id, 'tr')
FROM agency.category_filter_items i
JOIN agency.category_filter_groups g ON g.id = i.group_id
WHERE g.category_code IN (
  'hotel','tour','activity','flight','car','cruise','pilgrimage','visa',
  'ferry','transfer','beach','cinema','event','restaurant','bus'
);
