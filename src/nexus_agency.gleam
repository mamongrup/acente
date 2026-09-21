import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option
import gleam/result
import mist
import nexus_agency/currency_worker
import nexus_agency/email_worker
import nexus_agency/nexus_listing_sync
import nexus_agency/router
import nexus_agency/weekly_digest_scheduler
import pog
import wisp
import wisp/wisp_mist

pub fn main() {
  let assert Ok("development") = envoy.get("APP_ENV")
    as "Local development only. Read docs/production-gates.md."
  let assert Ok(secret) = envoy.get("SECRET_KEY_BASE")
  let assert Ok(password) = envoy.get("PGPASSWORD")
  let assert Ok(origin) = envoy.get("APP_ORIGIN")
  let name = process.new_name("nexus_agency_database")
  let config =
    pog.default_config(name)
    |> pog.host(envoy.get("PGHOST") |> result.unwrap("127.0.0.1"))
    |> pog.port(env_int("PGPORT", 5434))
    |> pog.database(envoy.get("PGDATABASE") |> result.unwrap("nexus_agency"))
    |> pog.user(envoy.get("PGUSER") |> result.unwrap("agency_app"))
    |> pog.password(option.Some(password))
    |> pog.pool_size(5)
  let assert Ok(_) = pog.start(config)
  let db = pog.named_connection(name)
  currency_worker.start(db)
  start_nexus_listing_sync(db)
  weekly_digest_scheduler.start(db)
  email_worker.start(db)
  wisp.configure_logger()
  // SSR yerelleştirme: nexus_lang çerezine göre mağaza sayfaları sunucuda
  // hedef dilde render edilir (handle_localized → handle zinciri).
  let handler = fn(req) { router.handle_localized(req, db, origin) }
  let assert Ok(_) =
    handler
    |> wisp_mist.handler(secret)
    |> mist.new
    |> mist.bind("127.0.0.1")
    |> mist.port(env_int("APP_PORT", 8082))
    |> mist.start
  io.println("NEXUS Agency: " <> origin)
  process.sleep_forever()
}

fn env_int(key: String, fallback: Int) -> Int {
  envoy.get(key) |> result.try(int.parse) |> result.unwrap(fallback)
}

fn start_nexus_listing_sync(agency_db: pog.Connection) {
  let tenant_id = envoy.get("NEXUS_TENANT_ID") |> result.unwrap("")
  case envoy.get("NEXUS_API_ORIGIN") {
    Ok(api_origin) -> {
      let api_key =
        envoy.get("NEXUS_API_KEY")
        |> result.lazy_or(fn() { envoy.get("NEXUS_CONFIG_KEY") })
        |> result.unwrap("")
      nexus_listing_sync.start_api_sync(
        agency_db,
        api_origin,
        api_key,
        tenant_id,
      )
    }
    Error(_) -> {
      case envoy.get("NEXUS_PGPASSWORD") {
        Ok(nexus_password) -> {
          let nexus_name = process.new_name("nexus_listing_source_database")
          let nexus_config =
            pog.default_config(nexus_name)
            |> pog.host(envoy.get("NEXUS_PGHOST") |> result.unwrap("127.0.0.1"))
            |> pog.port(env_int("NEXUS_PGPORT", 5433))
            |> pog.database(
              envoy.get("NEXUS_PGDATABASE")
              |> result.unwrap("nexustraveltech"),
            )
            |> pog.user(envoy.get("NEXUS_PGUSER") |> result.unwrap("nexus_app"))
            |> pog.password(option.Some(nexus_password))
            |> pog.pool_size(2)
          case pog.start(nexus_config) {
            Ok(_) ->
              nexus_listing_sync.start(
                agency_db,
                pog.named_connection(nexus_name),
                tenant_id,
              )
            Error(_) ->
              io.println("NEXUS listing sync: connection could not start")
          }
        }
        Error(_) ->
          io.println(
            "NEXUS listing sync: NEXUS_API_ORIGIN or NEXUS_PGPASSWORD is not configured",
          )
      }
    }
  }
}
