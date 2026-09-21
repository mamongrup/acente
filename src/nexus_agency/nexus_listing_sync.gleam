import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import nexus_agency/nexus_api_client
import pog

const sync_interval_ms = 60_000

/// Feed'teki ilan sayısı bu eşiğin altındaysa senkronizasyon şüpheli kabul
/// edilir ve "yayından kalkanları duraklat" sorgusu çalıştırılmaz. Böylece
/// boş ya da yarım dönen bir feed tüm nexus ilanlarını duraklatamaz. UPSERT
/// tarafı etkilenmez: feed'de gelen satırlar her zamanki gibi yazılır.
const min_feed_size = 3

/// REST API tabanlı sürümlü senkronizasyonu başlatır (Rule 9: DB bağlantısı yerine HTTP API).
pub fn start_api_sync(
  agency_db: pog.Connection,
  api_origin: String,
  api_key: String,
  tenant_id: String,
) {
  case tenant_id {
    "" ->
      io.println(
        "NEXUS listing API sync: NEXUS_TENANT_ID not configured, sync disabled",
      )
    _ -> {
      io.println(
        "NEXUS listing sync: running via REST API (" <> api_origin <> ")",
      )
      process.spawn(fn() {
        api_loop(agency_db, api_origin, api_key, tenant_id)
      })
      Nil
    }
  }
}

fn api_loop(
  agency_db: pog.Connection,
  api_origin: String,
  api_key: String,
  tenant_id: String,
) {
  api_sync(agency_db, api_origin, api_key, tenant_id)
  process.sleep(sync_interval_ms)
  api_loop(agency_db, api_origin, api_key, tenant_id)
}

pub fn api_sync(
  agency_db: pog.Connection,
  api_origin: String,
  api_key: String,
  tenant_id: String,
) {
  case api_sync_contract_compatible(agency_db, api_origin, api_key, tenant_id) {
    False -> Nil
    True -> do_api_sync(agency_db, api_origin, api_key, tenant_id)
  }
}

fn api_sync_contract_compatible(
  agency_db: pog.Connection,
  api_origin: String,
  api_key: String,
  tenant_id: String,
) -> Bool {
  let decoder = {
    use key <- decode.field(0, decode.string)
    use value <- decode.field(1, decode.string)
    decode.success(#(key, value))
  }

  let agency_state =
    pog.query(
      "select data[1], data[2] from agency.sync_contract_state($1::uuid) order by data[1]",
    )
    |> pog.parameter(pog.text(tenant_id))
    |> pog.returning(decoder)
    |> pog.execute(agency_db)

  let nexus_state = nexus_api_client.fetch_contract_state(api_origin, api_key)

  case agency_state, nexus_state {
    Ok(agency_result), Ok(nexus_rows) -> {
      case agency_result.rows == nexus_rows {
        True -> True
        False -> {
          let message =
            "contract mismatch: agency="
            <> contract_state_summary(agency_result.rows)
            <> " nexus="
            <> contract_state_summary(nexus_rows)
          record_sync_failure(agency_db, tenant_id, message)
          io.println("NEXUS listing API sync: " <> message)
          False
        }
      }
    }
    Error(_), _ -> {
      let message = "agency contract state unavailable"
      record_sync_failure(agency_db, tenant_id, message)
      io.println("NEXUS listing API sync: " <> message)
      False
    }
    _, Error(err) -> {
      let message = "nexus API contract state error: " <> err
      record_sync_failure(agency_db, tenant_id, message)
      io.println("NEXUS listing API sync: " <> message)
      False
    }
  }
}

fn do_api_sync(
  agency_db: pog.Connection,
  api_origin: String,
  api_key: String,
  tenant_id: String,
) {
  case nexus_api_client.fetch_listings_feed(api_origin, api_key, tenant_id) {
    Ok(rows) -> {
      let row_count = list.length(rows)
      case row_count >= min_feed_size {
        True -> {
          let _ =
            pog.query(
              "update agency.listings set status='paused',updated_at=now() where tenant_id=$1::uuid and source='nexus' and status='published'",
            )
            |> pog.parameter(pog.text(tenant_id))
            |> pog.execute(agency_db)
          Nil
        }
        False ->
          io.println(
            "NEXUS listing API sync: feed returned only "
            <> int.to_string(row_count)
            <> " row(s) (minimum "
            <> int.to_string(min_feed_size)
            <> "), skipping pause to protect existing listings",
          )
      }

      let upserted =
        rows
        |> list.fold(0, fn(count, row) {
          case upsert(agency_db, row, tenant_id) {
            True -> count + 1
            False -> count
          }
        })
      io.println(
        "NEXUS listing API sync: "
        <> int.to_string(row_count)
        <> " published listing(s), "
        <> int.to_string(upserted)
        <> " upserted for tenant "
        <> tenant_id,
      )
    }
    Error(err) -> {
      record_sync_failure(agency_db, tenant_id, err)
      io.println("NEXUS listing API sync error: " <> err)
    }
  }
}

/// tenant_id: NEXUS_TENANT_ID ortam değişkeninden gelen, senkronizasyonun
/// yazılacağı tek agency tenant UUID'si. Boş string geçilirse sync devre dışı
/// bırakılır — tüm tenant'lara yanlışlıkla yazılmasını önler.
pub fn start(
  agency_db: pog.Connection,
  nexus_db: pog.Connection,
  tenant_id: String,
) {
  case tenant_id {
    "" ->
      io.println(
        "NEXUS listing sync: NEXUS_TENANT_ID not configured, sync disabled",
      )
    _ -> {
      process.spawn(fn() { loop(agency_db, nexus_db, tenant_id) })
      Nil
    }
  }
}

fn loop(
  agency_db: pog.Connection,
  nexus_db: pog.Connection,
  tenant_id: String,
) {
  sync(agency_db, nexus_db, tenant_id)
  process.sleep(sync_interval_ms)
  loop(agency_db, nexus_db, tenant_id)
}

fn sync(
  agency_db: pog.Connection,
  nexus_db: pog.Connection,
  tenant_id: String,
) {
  case sync_contract_compatible(agency_db, nexus_db, tenant_id) {
    False -> Nil
    True -> do_sync(agency_db, nexus_db, tenant_id)
  }
}

fn do_sync(
  agency_db: pog.Connection,
  nexus_db: pog.Connection,
  tenant_id: String,
) {
  // Sürümlü feed 9 sütun döndürür ve sağlayıcı görsellerini korur.
  let decoder = {
    use id <- decode.field(0, decode.string)
    use title <- decode.field(1, decode.string)
    use locality <- decode.field(2, decode.string)
    use category <- decode.field(3, decode.string)
    use capacity <- decode.field(4, decode.string)
    use price <- decode.field(5, decode.string)
    use currency <- decode.field(6, decode.string)
    use description <- decode.field(7, decode.string)
    use images <- decode.field(8, decode.string)
    decode.success(#(
      id,
      title,
      locality,
      category,
      capacity,
      price,
      currency,
      description,
      images,
    ))
  }
  case
    pog.query(
      "select id,title,locality,category,capacity,price,currency,description,images::text from catalog.marketplace_listings_for_agency($1)",
    )
    |> pog.parameter(pog.text(tenant_id))
    |> pog.returning(decoder)
    |> pog.execute(nexus_db)
  {
    Ok(result) -> {
      let row_count = list.length(result.rows)
      // NEXUS feed'inde artık yer almayan listeleri bu tenant için duraklat.
      // Güvenlik kilidi: feed minimum eşiğin altındaysa (boş ya da yarım)
      // duraklatma atlanır; aksi halde tek bir boş feed tüm nexus ilanlarını
      // yayından kaldırabilirdi.
      case row_count >= min_feed_size {
        True -> {
          let _ =
            pog.query(
              "update agency.listings set status='paused',updated_at=now() where tenant_id=$1::uuid and source='nexus' and status='published'",
            )
            |> pog.parameter(pog.text(tenant_id))
            |> pog.execute(agency_db)
          Nil
        }
        False ->
          io.println(
            "NEXUS listing sync: feed returned only "
            <> int.to_string(row_count)
            <> " row(s) (minimum "
            <> int.to_string(min_feed_size)
            <> "), skipping pause to protect existing listings",
          )
      }

      let upserted =
        result.rows
        |> list.fold(0, fn(count, row) {
          case upsert(agency_db, row, tenant_id) {
            True -> count + 1
            False -> count
          }
        })
      io.println(
        "NEXUS listing sync: "
        <> int.to_string(row_count)
        <> " published listing(s), "
        <> int.to_string(upserted)
        <> " upserted for tenant "
        <> tenant_id,
      )
    }
    Error(_) -> io.println("NEXUS listing sync: source database unavailable")
  }
}

fn sync_contract_compatible(
  agency_db: pog.Connection,
  nexus_db: pog.Connection,
  tenant_id: String,
) -> Bool {
  let decoder = {
    use key <- decode.field(0, decode.string)
    use value <- decode.field(1, decode.string)
    decode.success(#(key, value))
  }

  let agency_state =
    pog.query(
      "select data[1], data[2] from agency.sync_contract_state($1::uuid) order by data[1]",
    )
    |> pog.parameter(pog.text(tenant_id))
    |> pog.returning(decoder)
    |> pog.execute(agency_db)

  let nexus_state =
    pog.query(
      "select data[1], data[2] from onboarding.sync_contract_state() order by data[1]",
    )
    |> pog.returning(decoder)
    |> pog.execute(nexus_db)

  case agency_state, nexus_state {
    Ok(agency_result), Ok(nexus_result) -> {
      case agency_result.rows == nexus_result.rows {
        True -> True
        False -> {
          let message =
            "contract mismatch: agency="
            <> contract_state_summary(agency_result.rows)
            <> " nexus="
            <> contract_state_summary(nexus_result.rows)
          record_sync_failure(agency_db, tenant_id, message)
          io.println("NEXUS listing sync: " <> message)
          False
        }
      }
    }
    Error(_), _ -> {
      let message = "agency contract state unavailable"
      record_sync_failure(agency_db, tenant_id, message)
      io.println("NEXUS listing sync: " <> message)
      False
    }
    _, Error(_) -> {
      let message = "nexus contract state unavailable"
      record_sync_failure(agency_db, tenant_id, message)
      io.println("NEXUS listing sync: " <> message)
      False
    }
  }
}

fn contract_state_summary(rows: List(#(String, String))) -> String {
  rows
  |> list.map(fn(row) {
    let #(key, value) = row
    key <> "=" <> value
  })
  |> string.join(",")
}

fn record_sync_failure(
  agency_db: pog.Connection,
  tenant_id: String,
  message: String,
) {
  let _ =
    pog.query(
      "insert into agency.sync_jobs(tenant_id,job_type,status,started_at,finished_at,error)
       values($1::uuid,'import','failed',now(),now(),$2)",
    )
    |> pog.parameter(pog.text(tenant_id))
    |> pog.parameter(pog.text(message))
    |> pog.execute(agency_db)
  Nil
}

fn upsert(
  agency_db: pog.Connection,
  row: #(String, String, String, String, String, String, String, String, String),
  tenant_id: String,
) -> Bool {
  let #(
    id,
    title,
    locality,
    category,
    capacity,
    price,
    currency,
    description,
    images,
  ) = row
  let contract_fields_json = category_contract_fields_json(category, capacity, locality)
  case
    pog.query(
      "insert into agency.listings(
         tenant_id, code, category, title, locality, description, currency, price_minor,
         status, source, metadata, images, amenities, owner_info, cancellation_policy
       )
       values(
         $1::uuid, upper($2), $3, $4, $5, $6, upper($7), $8::bigint,
         'published', 'nexus',
         jsonb_build_object(
           'nexus_listing_id', $9::text,
           'guests', $10::text,
           'contract_fields', $12::jsonb
         ),
         case when $11::jsonb = '[]'::jsonb or $11::jsonb is null
           then jsonb_build_array(jsonb_build_object('url', '/static/placeholder.jpg'))
           else $11::jsonb
         end,
         '[]'::jsonb,
         jsonb_build_object('provider', 'NEXUS TravelTech'),
         jsonb_build_object('policy', 'Standart')
       )
       on conflict(tenant_id,code) do update set
         category=excluded.category,title=excluded.title,locality=excluded.locality,
         description=excluded.description,currency=excluded.currency,
         price_minor=excluded.price_minor,status='published',source='nexus',
         metadata=agency.listings.metadata||excluded.metadata,
         images=case when excluded.images <> '[]'::jsonb then excluded.images else agency.listings.images end,
         owner_info=case when agency.listings.owner_info = '{}'::jsonb then excluded.owner_info else agency.listings.owner_info end,
         cancellation_policy=case when agency.listings.cancellation_policy = '{}'::jsonb then excluded.cancellation_policy else agency.listings.cancellation_policy end,
         updated_at=now()",
    )
    |> pog.parameter(pog.text(tenant_id))
    |> pog.parameter(pog.text("NEXUS-" <> id))
    |> pog.parameter(pog.text(category))
    |> pog.parameter(pog.text(title))
    |> pog.parameter(pog.text(locality))
    |> pog.parameter(pog.text(description))
    |> pog.parameter(pog.text(currency))
    |> pog.parameter(pog.int(int.parse(price) |> result.unwrap(0)))
    |> pog.parameter(pog.text(id))
    |> pog.parameter(pog.text(capacity))
    |> pog.parameter(pog.text(images))
    |> pog.parameter(pog.text(contract_fields_json))
    |> pog.execute(agency_db)
  {
    Ok(_) -> True
    Error(error) -> {
      io.println(
        "NEXUS listing sync: could not upsert listing "
        <> id
        <> " for tenant "
        <> tenant_id
        <> " ("
        <> query_error_summary(error)
        <> ")",
      )
      False
    }
  }
}

fn category_contract_fields_json(category: String, capacity: String, locality: String) -> String {
  let cap = case string.trim(capacity) {
    "" -> "4"
    c -> c
  }
  let loc = case string.trim(locality) {
    "" -> "Merkez"
    l -> l
  }
  case category {
    "holiday_home" ->
      "{\"property_type\":\"Villa\",\"bedroom_count\":\"3\",\"bathroom_count\":\"2\",\"guest_capacity\":\"" <> cap <> "\"}"
    "hotel" ->
      "{\"property_type\":\"Otel\",\"board_type\":\"Oda Kahvaltı\",\"check_in_time\":\"14:00\",\"check_out_time\":\"12:00\",\"room_types\":\"Standart\"}"
    "yacht" ->
      "{\"yacht_type\":\"Gulet\",\"capacity\":\"" <> cap <> "\",\"captain_included\":\"Evet\",\"departure_port\":\"" <> loc <> "\",\"route\":\"Standart Seyir\"}"
    "tour" ->
      "{\"tour_type\":\"Kültür Tipi\",\"duration\":\"Günübirlik\",\"start_point\":\"" <> loc <> "\"}"
    "activity" ->
      "{\"activity_type\":\"Açık Hava\",\"duration\":\"2 Saat\",\"meeting_point\":\"" <> loc <> "\"}"
    "car" ->
      "{\"vehicle_type\":\"Sedan\",\"transmission\":\"Otomatik\",\"seat_count\":\"" <> cap <> "\",\"deposit_policy\":\"Kredi Kartı\",\"pickup_locations\":\"" <> loc <> "\"}"
    "transfer" ->
      "{\"transfer_type\":\"VIP\",\"vehicle_type\":\"Minivan\",\"capacity\":\"" <> cap <> "\",\"pickup_location\":\"Havalimanı\",\"dropoff_location\":\"" <> loc <> "\"}"
    "flight" ->
      "{\"airline_or_provider\":\"NEXUS Air\",\"route_from\":\"IST\",\"route_to\":\"" <> loc <> "\",\"baggage_policy\":\"20kg\",\"ticket_rules\":\"Standart\"}"
    "ferry" ->
      "{\"route_from\":\"Merkez\",\"route_to\":\"" <> loc <> "\",\"schedule\":\"Günlük\",\"ticket_rules\":\"Standart\"}"
    "bus" ->
      "{\"operator\":\"NEXUS Express\",\"route_from\":\"Merkez\",\"route_to\":\"" <> loc <> "\",\"baggage_policy\":\"30kg\",\"ticket_rules\":\"Standart\"}"
    "cruise" ->
      "{\"ship_or_provider\":\"NEXUS Cruise\",\"departure_port\":\"" <> loc <> "\",\"route\":\"Akdeniz\",\"duration\":\"7 Gece\"}"
    "pilgrimage" ->
      "{\"package_type\":\"Ekonomik\",\"departure_city\":\"İstanbul\",\"duration\":\"14 Gün\",\"guidance_included\":\"Evet\"}"
    "visa" ->
      "{\"visa_type\":\"Turistik\",\"destination_country\":\"Schengen\",\"processing_time\":\"15 Gün\",\"required_documents\":\"Standart Evrak Listesi\"}"
    "beach" ->
      "{\"beach_name\":\"Plaj\",\"seat_type\":\"Şezlong\",\"time_slot\":\"Tam Gün\",\"access_type\":\"Standart\",\"capacity\":\"" <> cap <> "\"}"
    "cinema" ->
      "{\"movie_or_program\":\"Vizyon\",\"venue\":\"" <> loc <> "\",\"session_time\":\"21:00\",\"ticket_rules\":\"Numaralı\"}"
    "event" ->
      "{\"event_type\":\"Konser\",\"venue\":\"" <> loc <> "\",\"start_datetime\":\"2026-10-01 20:00\",\"ticket_type\":\"Genel Giriş\"}"
    "restaurant" ->
      "{\"venue\":\"" <> loc <> "\",\"cuisine_type\":\"Akdeniz\",\"reservation_type\":\"Akşam Yemeği\",\"service_hours\":\"18:00 - 23:00\"}"
    _ ->
      "{}"
  }
}

fn query_error_summary(error: pog.QueryError) -> String {
  case error {
    pog.ConstraintViolated(message, constraint, detail) ->
      message <> " " <> constraint <> " " <> detail
    pog.PostgresqlError(code, name, message) ->
      code <> " " <> name <> " " <> message
    pog.UnexpectedArgumentCount(expected, got) ->
      "argument count " <> int.to_string(expected) <> "/" <> int.to_string(got)
    pog.UnexpectedArgumentType(expected, got) ->
      "argument type " <> expected <> "/" <> got
    pog.UnexpectedResultType(_) -> "unexpected result type"
    pog.QueryTimeout -> "query timeout"
    pog.ConnectionUnavailable -> "connection unavailable"
  }
}
