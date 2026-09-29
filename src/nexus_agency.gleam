import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import mist
import nexus_agency/currency_worker
import nexus_agency/email_worker
import nexus_agency/nexus_listing_sync
import nexus_agency/nexus_reservation_worker
import nexus_agency/router
import nexus_agency/secrets
import nexus_agency/weekly_digest_scheduler
import pog
import wisp
import wisp/wisp_mist

pub fn main() {
  let assert Ok(app_env) = envoy.get("APP_ENV")
  let assert True = app_env == "development" || app_env == "production"
    as "APP_ENV must be development or production."
  let assert Ok(secret) = envoy.get("SECRET_KEY_BASE")
  let assert Ok(password) = envoy.get("PGPASSWORD")
  let assert Ok(origin) = envoy.get("APP_ORIGIN")
  let _ = case app_env {
    "production" -> {
      let assert True = string.starts_with(origin, "https://")
        as "Production APP_ORIGIN must use HTTPS."
      let assert True = string.length(secret) >= 64
        as "Production SECRET_KEY_BASE must contain at least 64 characters."
      let assert Ok(config_key) = envoy.get("NEXUS_CONFIG_KEY")
      let assert True = string.length(config_key) >= 64
        as "Production NEXUS_CONFIG_KEY must contain at least 64 characters."
      let assert Ok("true") = envoy.get("TRUSTED_PROXY_SECURE_COOKIES")
      let assert Ok("true") = envoy.get("TRUST_PROXY_HEADERS")
      let assert Ok("true") = envoy.get("EDGE_RATE_LIMIT_ENABLED")
      Nil
    }
    _ -> Nil
  }
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
  wisp.set_logger_level(wisp.WarningLevel)
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
  let env_tenant_id = envoy.get("NEXUS_TENANT_ID") |> result.unwrap("")
  let tenant_id =
    integration_value(agency_db, env_tenant_id, "agency_code")
    |> result.try(fn(value) {
      case string.trim(value) {
        "" -> Error(Nil)
        selected -> Ok(selected)
      }
    })
    |> result.unwrap(env_tenant_id)
  let env_origin = envoy.get("NEXUS_API_ORIGIN") |> result.unwrap("")
  let env_key =
    envoy.get("NEXUS_API_KEY")
    |> result.lazy_or(fn() { envoy.get("NEXUS_CONFIG_KEY") })
    |> result.unwrap("")
  let api_origin =
    integration_value(agency_db, tenant_id, "endpoint")
    |> result.unwrap(env_origin)
  let api_key =
    integration_value(agency_db, tenant_id, "api_key") |> result.unwrap(env_key)
  case string.trim(api_origin) {
    "" -> {
      io.println(
        "NEXUS listing sync: NEXUS_API_ORIGIN is not configured; agency remains in standalone mode",
      )
    }
    _ -> {
      case string.trim(tenant_id), string.trim(api_key) {
        "", _ ->
          io.println(
            "NEXUS listing sync: NEXUS_TENANT_ID is not configured; agency remains in standalone mode",
          )
        _, "" ->
          io.println(
            "NEXUS listing sync: API key is not configured; agency remains in standalone mode",
          )
        _, _ -> {
          let sync_started =
            nexus_listing_sync.start_api_sync(
              agency_db,
              api_origin,
              api_key,
              tenant_id,
            )
          case sync_started {
            True ->
              nexus_reservation_worker.start(agency_db, api_origin, api_key)
            False -> Nil
          }
        }
      }
    }
  }
}

fn integration_value(
  db: pog.Connection,
  tenant_id: String,
  key: String,
) -> Result(String, Nil) {
  let decoder = {
    use plain <- decode.field(0, decode.string)
    use sealed <- decode.field(1, decode.string)
    decode.success(#(plain, sealed))
  }
  case
    pog.query(
      "select coalesce(credentials->>$2,''), coalesce(credentials->>'api_key_sealed','') from agency.integrations where tenant_id=$1::uuid and provider='nexus' and kind='connectivity' limit 1",
    )
    |> pog.parameter(pog.text(tenant_id))
    |> pog.parameter(pog.text(key))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(result) ->
      list.first(result.rows)
      |> result.try(fn(row) {
        let #(plain, sealed) = row
        case key == "api_key" && string.trim(sealed) != "" {
          True -> secrets.open_for_tenant(tenant_id, "nexus.api_key", sealed)
          False ->
            case key == "api_key" && string.trim(plain) != "" {
              True -> {
                let _ = migrate_plain_nexus_api_key(db, tenant_id, plain)
                Ok(plain)
              }
              False -> Ok(plain)
            }
        }
      })
    Error(_) -> Error(Nil)
  }
}

fn migrate_plain_nexus_api_key(
  db: pog.Connection,
  tenant_id: String,
  api_key: String,
) -> Nil {
  case secrets.seal_for_tenant(tenant_id, "nexus.api_key", api_key) {
    Error(Nil) -> Nil
    Ok(sealed) -> {
      let _ =
        pog.query(
          "update agency.integrations
              set credentials=(coalesce(credentials,'{}'::jsonb) - 'api_key')
                    || jsonb_build_object('api_key_sealed',$2),
                  updated_at=now()
            where tenant_id=$1::uuid
              and provider='nexus'
              and kind='connectivity'
              and coalesce(credentials->>'api_key','')<>''",
        )
        |> pog.parameter(pog.text(tenant_id))
        |> pog.parameter(pog.text(sealed))
        |> pog.execute(db)
      Nil
    }
  }
}
