-- Enforce supplier-listing contract field keys for every canonical category.
-- For tenant-scoped acente categories, first copy existing canonical fields to
-- every tenant/category row, then remove fields outside the shared contract.

WITH allowed(category_code,field_key) AS (
  VALUES
    ('hotel','property_type'),('hotel','room_types'),('hotel','board_type'),('hotel','check_in_time'),('hotel','check_out_time'),('hotel','amenities'),('hotel','star_rating'),
    ('holiday_home','property_type'),('holiday_home','bedroom_count'),('holiday_home','bathroom_count'),('holiday_home','guest_capacity'),('holiday_home','pool_type'),('holiday_home','kitchen'),('holiday_home','season_rules'),
    ('yacht','yacht_type'),('yacht','capacity'),('yacht','cabin_count'),('yacht','departure_port'),('yacht','route'),('yacht','captain_included'),('yacht','fuel_policy'),
    ('tour','tour_type'),('tour','duration'),('tour','start_point'),('tour','end_point'),('tour','guide_languages'),('tour','group_size_min'),('tour','group_size_max'),
    ('activity','activity_type'),('activity','duration'),('activity','difficulty'),('activity','age_limit'),('activity','equipment_included'),('activity','meeting_point'),
    ('flight','airline_or_provider'),('flight','route_from'),('flight','route_to'),('flight','fare_class'),('flight','baggage_policy'),('flight','ticket_rules'),
    ('car','vehicle_type'),('car','brand_model'),('car','transmission'),('car','fuel_type'),('car','seat_count'),('car','pickup_locations'),('car','deposit_policy'),
    ('cruise','ship_or_provider'),('cruise','route'),('cruise','departure_port'),('cruise','cabin_types'),('cruise','duration'),('cruise','board_type'),
    ('pilgrimage','package_type'),('pilgrimage','departure_city'),('pilgrimage','duration'),('pilgrimage','hotel_class'),('pilgrimage','visa_included'),('pilgrimage','guidance_included'),
    ('visa','destination_country'),('visa','visa_type'),('visa','processing_time'),('visa','required_documents'),('visa','appointment_required'),
    ('ferry','route_from'),('ferry','route_to'),('ferry','operator'),('ferry','schedule'),('ferry','vehicle_allowed'),('ferry','ticket_rules'),
    ('transfer','transfer_type'),('transfer','pickup_location'),('transfer','dropoff_location'),('transfer','vehicle_type'),('transfer','capacity'),('transfer','waiting_policy'),
    ('beach','beach_name'),('beach','access_type'),('beach','seat_type'),('beach','capacity'),('beach','food_beverage_policy'),('beach','time_slot'),
    ('cinema','venue'),('cinema','movie_or_program'),('cinema','session_time'),('cinema','seat_type'),('cinema','ticket_rules'),
    ('event','event_type'),('event','venue'),('event','start_datetime'),('event','end_datetime'),('event','ticket_type'),('event','age_limit'),
    ('restaurant','cuisine_type'),('restaurant','venue'),('restaurant','reservation_type'),('restaurant','capacity'),('restaurant','menu_options'),('restaurant','service_hours'),
    ('bus','operator'),('bus','route_from'),('bus','route_to'),('bus','seat_type'),('bus','baggage_policy'),('bus','ticket_rules')
),
source_fields AS (
  SELECT DISTINCT ON (c.code, f.field_key)
         c.code AS category_code,
         f.field_key,
         f.label,
         f.field_type,
         f.required,
         f.options,
         f.sort_order
  FROM agency.categories c
  JOIN agency.category_fields f ON f.category_id=c.id
  JOIN allowed a ON a.category_code=c.code AND a.field_key=f.field_key
  ORDER BY c.code, f.field_key, f.sort_order, f.id
)
INSERT INTO agency.category_fields(category_id,field_key,label,field_type,required,options,sort_order)
SELECT target.id, sf.field_key, sf.label, sf.field_type, sf.required, sf.options, sf.sort_order
FROM agency.categories target
JOIN source_fields sf ON sf.category_code=target.code
WHERE target.code IN (SELECT DISTINCT category_code FROM allowed)
ON CONFLICT(category_id,field_key) DO UPDATE SET
  label=excluded.label,
  field_type=excluded.field_type,
  required=excluded.required,
  options=excluded.options,
  sort_order=excluded.sort_order;

WITH allowed(category_code,field_key) AS (
  VALUES
    ('hotel','property_type'),('hotel','room_types'),('hotel','board_type'),('hotel','check_in_time'),('hotel','check_out_time'),('hotel','amenities'),('hotel','star_rating'),
    ('holiday_home','property_type'),('holiday_home','bedroom_count'),('holiday_home','bathroom_count'),('holiday_home','guest_capacity'),('holiday_home','pool_type'),('holiday_home','kitchen'),('holiday_home','season_rules'),
    ('yacht','yacht_type'),('yacht','capacity'),('yacht','cabin_count'),('yacht','departure_port'),('yacht','route'),('yacht','captain_included'),('yacht','fuel_policy'),
    ('tour','tour_type'),('tour','duration'),('tour','start_point'),('tour','end_point'),('tour','guide_languages'),('tour','group_size_min'),('tour','group_size_max'),
    ('activity','activity_type'),('activity','duration'),('activity','difficulty'),('activity','age_limit'),('activity','equipment_included'),('activity','meeting_point'),
    ('flight','airline_or_provider'),('flight','route_from'),('flight','route_to'),('flight','fare_class'),('flight','baggage_policy'),('flight','ticket_rules'),
    ('car','vehicle_type'),('car','brand_model'),('car','transmission'),('car','fuel_type'),('car','seat_count'),('car','pickup_locations'),('car','deposit_policy'),
    ('cruise','ship_or_provider'),('cruise','route'),('cruise','departure_port'),('cruise','cabin_types'),('cruise','duration'),('cruise','board_type'),
    ('pilgrimage','package_type'),('pilgrimage','departure_city'),('pilgrimage','duration'),('pilgrimage','hotel_class'),('pilgrimage','visa_included'),('pilgrimage','guidance_included'),
    ('visa','destination_country'),('visa','visa_type'),('visa','processing_time'),('visa','required_documents'),('visa','appointment_required'),
    ('ferry','route_from'),('ferry','route_to'),('ferry','operator'),('ferry','schedule'),('ferry','vehicle_allowed'),('ferry','ticket_rules'),
    ('transfer','transfer_type'),('transfer','pickup_location'),('transfer','dropoff_location'),('transfer','vehicle_type'),('transfer','capacity'),('transfer','waiting_policy'),
    ('beach','beach_name'),('beach','access_type'),('beach','seat_type'),('beach','capacity'),('beach','food_beverage_policy'),('beach','time_slot'),
    ('cinema','venue'),('cinema','movie_or_program'),('cinema','session_time'),('cinema','seat_type'),('cinema','ticket_rules'),
    ('event','event_type'),('event','venue'),('event','start_datetime'),('event','end_datetime'),('event','ticket_type'),('event','age_limit'),
    ('restaurant','cuisine_type'),('restaurant','venue'),('restaurant','reservation_type'),('restaurant','capacity'),('restaurant','menu_options'),('restaurant','service_hours'),
    ('bus','operator'),('bus','route_from'),('bus','route_to'),('bus','seat_type'),('bus','baggage_policy'),('bus','ticket_rules')
)
DELETE FROM agency.category_fields f
USING agency.categories c
WHERE c.id=f.category_id
  AND c.code IN (SELECT DISTINCT category_code FROM allowed)
  AND NOT EXISTS (
    SELECT 1 FROM allowed a WHERE a.category_code=c.code AND a.field_key=f.field_key
  );
