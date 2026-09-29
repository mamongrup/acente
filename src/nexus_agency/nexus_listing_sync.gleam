import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import nexus_agency/net
import nexus_agency/nexus_api_client
import pog

const sync_interval_ms = 60_000

/// REST API tabanlı sürümlü senkronizasyonu başlatır (Rule 9: DB bağlantısı yerine HTTP API).
pub fn start_api_sync(
  agency_db: pog.Connection,
  api_origin: String,
  api_key: String,
  tenant_id: String,
) -> Bool {
  case tenant_id {
    "" -> {
      io.println(
        "NEXUS listing API sync: NEXUS_TENANT_ID not configured, sync disabled",
      )
      False
    }
    _ -> {
      case net.url_reachable(api_origin, 750) {
        False -> standalone_mode()
        True ->
          case nexus_api_client.fetch_contract_state(api_origin, api_key) {
            Error(_) -> standalone_mode()
            Ok(_) -> {
              io.println(
                "NEXUS listing sync: running via REST API ("
                <> api_origin
                <> ")",
              )
              process.spawn(fn() {
                api_loop(agency_db, api_origin, api_key, tenant_id)
              })
              True
            }
          }
      }
    }
  }
}

fn standalone_mode() -> Bool {
  io.println(
    "NEXUS listing sync: remote unavailable; agency continues in standalone mode",
  )
  False
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
      // Vitrin filtreleri tenant yöneticisi tarafından düzenlenir. Sayılarının
      // farklı olması sürümlü ilan sözleşmesinin uyumsuz olduğu anlamına gelmez.
      case required_contract_state(agency_result.rows) == required_contract_state(nexus_rows) {
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

fn required_contract_state(rows: List(#(String, String))) -> List(#(String, String)) {
  rows |> list.filter(fn(row) {
    let #(key, _) = row
    key != "active_filter_item_count"
  })
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
      let upserted =
        rows
        |> list.fold(0, fn(count, row) {
          case upsert(agency_db, row, tenant_id) {
            True -> count + 1
            False -> count
          }
        })

      // Önce bütün satırları doğrula/yaz. Tek bir satır bile yerel sözleşmeden
      // geçemezse mevcut yayındaki veriye dokunma. Tam başarıdan sonra uzak
      // feed'i kaynak gerçekliği olarak uygula ve güncel satırları yeniden aç.
      case upserted == row_count {
        True -> {
          let _ =
            pog.query(
              "update agency.listings set status='paused',updated_at=now() where tenant_id=$1::uuid and source='nexus' and status='published'",
            )
            |> pog.parameter(pog.text(tenant_id))
            |> pog.execute(agency_db)
          rows
          |> list.each(fn(row) {
            let _ = upsert(agency_db, row, tenant_id)
            sync_inventory_for_listing(
              agency_db,
              api_origin,
              api_key,
              tenant_id,
              row,
            )
            Nil
          })
        }
        False -> {
          let message =
            "feed validation failed: received="
            <> int.to_string(row_count)
            <> " upserted="
            <> int.to_string(upserted)
          record_sync_failure(agency_db, tenant_id, message)
          io.println("NEXUS listing API sync: " <> message)
        }
      }
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

fn sync_inventory_for_listing(
  agency_db: pog.Connection,
  api_origin: String,
  api_key: String,
  tenant_id: String,
  row: nexus_api_client.ListingTuple,
) {
  let #(id, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) = row
  case nexus_api_client.fetch_inventory(api_origin, api_key, tenant_id, id) {
    Ok(days) -> {
      case list.length(days) {
        0 -> {
          let _ =
            pog.query(
              "update agency.availability a
               set units_available=0,closed=true
               from agency.listings l
               where l.id=a.listing_id
                 and l.tenant_id=$1::uuid
                 and l.code=upper($2)
                 and l.source='nexus'
                 and a.day>=current_date",
            )
            |> pog.parameter(pog.text(tenant_id))
            |> pog.parameter(pog.text("NEXUS-" <> id))
            |> pog.execute(agency_db)
          io.println(
            "NEXUS inventory sync: "
            <> id
            <> " returned no days; future local days closed",
          )
        }
        _ -> {
          let written =
            days
            |> list.fold(0, fn(count, day) {
              case upsert_inventory_day(agency_db, tenant_id, id, day) {
                True -> count + 1
                False -> count
              }
            })
          case written == list.length(days) {
            True -> {
              let dates_json =
                json.array(days, fn(day) {
                  let #(date, _, _) = day
                  json.string(date)
                })
                |> json.to_string
              let _ =
                pog.query(
                  "delete from agency.availability a
                     using agency.listings l
                     where l.id=a.listing_id
                       and l.tenant_id=$1::uuid
                       and l.code=upper($2)
                       and l.source='nexus'
                       and a.day>=current_date
                       and a.day<=(select max(value::date) from jsonb_array_elements_text($3::jsonb) value)
                       and not exists (
                         select 1
                         from jsonb_array_elements_text($3::jsonb) remote_days
                         where remote_days=a.day::text
                       )",
                )
                |> pog.parameter(pog.text(tenant_id))
                |> pog.parameter(pog.text("NEXUS-" <> id))
                |> pog.parameter(pog.text(dates_json))
                |> pog.execute(agency_db)
              io.println(
                "NEXUS inventory sync: "
                <> id
                <> " "
                <> int.to_string(written)
                <> " day(s), stale days reconciled",
              )
            }
            False -> {
              let message =
                "inventory partial sync for "
                <> id
                <> ": received="
                <> int.to_string(list.length(days))
                <> " written="
                <> int.to_string(written)
              record_sync_failure(agency_db, tenant_id, message)
              io.println("NEXUS inventory sync: " <> message)
            }
          }
        }
      }
    }
    Error(err) -> {
      record_sync_failure(
        agency_db,
        tenant_id,
        "inventory sync failed for " <> id <> ": " <> err,
      )
      io.println("NEXUS inventory sync error: " <> id <> " " <> err)
    }
  }
}

fn upsert_inventory_day(
  agency_db: pog.Connection,
  tenant_id: String,
  nexus_listing_id: String,
  day: nexus_api_client.InventoryDay,
) -> Bool {
  let #(date, status, price_minor) = day
  let available = status == "available"
  let decoder = {
    use value <- decode.field(0, decode.int)
    decode.success(value)
  }
  let inventory_result =
    pog.query(
      "insert into agency.availability(listing_id,day,units_total,units_available,closed,price_minor)
       select l.id,$3::text::date,1,$4::int,$5::boolean,$6::bigint
       from agency.listings l
       where l.tenant_id=$1::uuid
         and l.code=upper($2)
         and l.source='nexus'
       on conflict(listing_id,day) do update set
         units_total=excluded.units_total,
         units_available=excluded.units_available,
         closed=excluded.closed,
         price_minor=excluded.price_minor
       returning 1",
    )
    |> pog.parameter(pog.text(tenant_id))
    |> pog.parameter(pog.text("NEXUS-" <> nexus_listing_id))
    |> pog.parameter(pog.text(date))
    |> pog.parameter(
      pog.int(case available {
        True -> 1
        False -> 0
      }),
    )
    |> pog.parameter(pog.bool(!available))
    |> pog.parameter(pog.int(price_minor))
    |> pog.returning(decoder)
    |> pog.execute(agency_db)
  let _ =
    pog.query(
      "update agency.listings
       set price_minor=$3::bigint,updated_at=now()
       where tenant_id=$1::uuid
         and code=upper($2)
         and source='nexus'
         and price_minor<=0
         and $3::bigint>0",
    )
    |> pog.parameter(pog.text(tenant_id))
    |> pog.parameter(pog.text("NEXUS-" <> nexus_listing_id))
    |> pog.parameter(pog.int(price_minor))
    |> pog.execute(agency_db)
  case inventory_result {
    Ok(result) ->
      case result.rows {
        [] -> False
        _ -> True
      }
    Error(error) -> {
      io.println(
        "NEXUS inventory sync: could not upsert "
        <> nexus_listing_id
        <> " "
        <> date
        <> " ("
        <> query_error_summary(error)
        <> ")",
      )
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
  row: nexus_api_client.ListingTuple,
  tenant_id: String,
) -> Bool {
  let #(
    id,
    title,
    locality,
    region,
    category,
    capacity,
    price,
    currency,
    description,
    short_description,
    images,
    contract_fields_json,
    price_unit,
    availability_mode,
    contact_policy,
    cancellation_policy,
  ) = row
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
           'contract_fields', $12::jsonb,
           'region', $13::text,
           'short_description', $14::text,
           'price_unit', $15::text,
           'availability_mode', $16::text,
           'contact_policy', $17::text
         ),
         case when $11::jsonb = '[]'::jsonb or $11::jsonb is null
           then jsonb_build_array(jsonb_build_object('url', '/static/placeholder.jpg'))
           else $11::jsonb
         end,
         '[]'::jsonb,
         jsonb_build_object('provider', 'NEXUS TravelTech', 'contact_policy', $17::text),
         jsonb_build_object('policy', $18::text)
       )
       on conflict(tenant_id,code) do update set
         category=excluded.category,title=excluded.title,locality=excluded.locality,
         description=excluded.description,currency=excluded.currency,
         price_minor=excluded.price_minor,status='published',source='nexus',
         metadata=agency.listings.metadata||excluded.metadata,
         images=case when excluded.images <> '[]'::jsonb then excluded.images else agency.listings.images end,
         owner_info=case when agency.listings.owner_info = '{}'::jsonb then excluded.owner_info else agency.listings.owner_info end,
         cancellation_policy=case when agency.listings.cancellation_policy = '{}'::jsonb then excluded.cancellation_policy else agency.listings.cancellation_policy end,
         updated_at=now()
       where agency.listings.source='nexus'
         and agency.listings.metadata->>'nexus_listing_id'=$9::text
       returning id::text",
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
    |> pog.parameter(pog.text(region))
    |> pog.parameter(pog.text(short_description))
    |> pog.parameter(pog.text(price_unit))
    |> pog.parameter(pog.text(availability_mode))
    |> pog.parameter(pog.text(contact_policy))
    |> pog.parameter(pog.text(cancellation_policy))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(agency_db)
  {
    Ok(result) ->
      case result.rows {
        [] -> {
          record_sync_collision(agency_db, tenant_id, id)
          record_sync_failure(agency_db, tenant_id, "listing code collision: NEXUS-" <> id)
          False
        }
        _ -> True
      }
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

fn record_sync_collision(
  agency_db: pog.Connection,
  tenant_id: String,
  external_id: String,
) {
  let _ =
    pog.query(
      "select agency.record_listing_sync_conflict($1::uuid,$2,$3)",
    )
    |> pog.parameter(pog.text(tenant_id))
    |> pog.parameter(pog.text(external_id))
    |> pog.parameter(pog.text("NEXUS-" <> external_id))
    |> pog.execute(agency_db)
  Nil
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
