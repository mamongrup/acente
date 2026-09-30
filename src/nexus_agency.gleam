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
  // Remote discovery can wait for an HTTP timeout; it must not delay the site.
  process.spawn(fn() { start_nexus_listing_sync(db) })
  process.sleep_forever()
}

type SyncConfig {
  SyncConfig(local_id: String, remote_id: String, origin: String, key: String)
}

type ActiveSync {
  ActiveSync(config: SyncConfig, listing_pid: process.Pid, reservation_pid: process.Pid)
}

fn env_int(key: String, fallback: Int) -> Int {
  envoy.get(key) |> result.try(int.parse) |> result.unwrap(fallback)
}

fn start_nexus_listing_sync(agency_db: pog.Connection) {
  sync_supervisor(agency_db, [])
}

fn sync_supervisor(agency_db: pog.Connection, running: List(ActiveSync)) {
  let next = case discover_sync_configs(agency_db) {
    Error(_) -> running
    Ok(configs) -> {
      running |> list.each(fn(worker) {
        case list.any(configs, fn(config) { config == worker.config })
          && process.is_alive(worker.listing_pid)
          && process.is_alive(worker.reservation_pid) {
          True -> Nil
          False -> stop_sync(agency_db, worker)
        }
      })
      configs |> list.map(fn(config) {
        case list.find(running, fn(worker) {
          worker.config == config
          && process.is_alive(worker.listing_pid)
          && process.is_alive(worker.reservation_pid)
        }) {
          Ok(worker) -> worker
          Error(_) -> start_sync(agency_db, config)
        }
      })
    }
  }
  let discovery_ms = env_int("NEXUS_SYNC_DISCOVERY_MS", 60_000)
  process.sleep(case discovery_ms < 1_000 { True -> 1_000 False -> discovery_ms })
  sync_supervisor(agency_db, next)
}

fn stop_sync(agency_db: pog.Connection, worker: ActiveSync) {
  process.kill(worker.listing_pid)
  process.kill(worker.reservation_pid)
  nexus_listing_sync.suspend_nexus_catalog(agency_db, worker.config.local_id)
  io.println("NEXUS sync stopped for tenant " <> worker.config.local_id)
}

fn start_sync(agency_db: pog.Connection, config: SyncConfig) -> ActiveSync {
  io.println("NEXUS sync started for tenant " <> config.local_id)
  let reservation_pid = nexus_reservation_worker.start(
    agency_db, config.origin, config.key, config.local_id, config.remote_id,
  )
  let listing_pid = nexus_listing_sync.start_api_sync(
    agency_db, config.origin, config.key, config.local_id, config.remote_id,
  )
  ActiveSync(config, listing_pid, reservation_pid)
}

fn discover_sync_configs(agency_db: pog.Connection) -> Result(List(SyncConfig), Nil) {
  let active_tenants =
    pog.query(
      "select tenant_id::text from agency.integrations where provider='nexus' and kind='connectivity' and active order by tenant_id",
    )
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(agency_db)
  case active_tenants {
    Ok(result) -> {
      let configured = result.rows |> list.filter_map(fn(tenant_id) {
        tenant_sync_config(agency_db, tenant_id, False)
      })
      case env_sync_config(agency_db) {
        Ok(env_config) ->
          case list.any(result.rows, fn(id) { id == env_config.local_id }) {
            True -> Ok(configured)
            False -> Ok([env_config, ..configured])
          }
        Error(_) -> Ok(configured)
      }
    }
    Error(_) -> {
      io.println("NEXUS listing sync: integration discovery unavailable; agency remains online")
      Error(Nil)
    }
  }
}

fn env_sync_config(agency_db: pog.Connection) -> Result(SyncConfig, Nil) {
  let env_tenant_id = envoy.get("NEXUS_TENANT_ID") |> result.unwrap("")
  case string.trim(env_tenant_id) {
    "" -> Error(Nil)
    tenant_id -> {
      let existing =
        pog.query(
          "select '1' from agency.integrations where tenant_id=$1::uuid and provider='nexus' and kind='connectivity' limit 1",
        )
        |> pog.parameter(pog.text(tenant_id))
        |> pog.returning(decode.field(0, decode.string, decode.success))
        |> pog.execute(agency_db)
      case existing {
        Ok(result) ->
          case result.rows {
            [] -> tenant_sync_config(agency_db, tenant_id, True)
            _ -> Error(Nil)
          }
        Error(_) -> Error(Nil)
      }
    }
  }
}

fn tenant_sync_config(agency_db: pog.Connection, local_tenant_id: String, allow_env: Bool) -> Result(SyncConfig, Nil) {
  let remote_tenant_id =
    integration_value(agency_db, local_tenant_id, "agency_code")
    |> result.try(fn(value) {
      case string.trim(value) {
        "" -> Error(Nil)
        selected -> Ok(selected)
      }
    })
    |> result.unwrap(local_tenant_id)
  let env_origin = envoy.get("NEXUS_API_ORIGIN") |> result.unwrap("")
  // NEXUS_API_KEY is the only credential that authenticates a call to NEXUS.
  // NEXUS_CONFIG_KEY is this application's master key for sealing stored
  // secrets; it was previously used as a fallback here, which sent the master
  // key to the other project as a bearer token on every feed request. NEXUS
  // rejects that value outright, so the integration failed with 401 while
  // looking configured.
  let env_key = envoy.get("NEXUS_API_KEY") |> result.unwrap("")
  let origin_fallback = case allow_env { True -> env_origin False -> "" }
  let key_fallback = case allow_env { True -> env_key False -> "" }
  let api_origin =
    integration_value(agency_db, local_tenant_id, "endpoint")
    |> result.unwrap(origin_fallback)
  let api_key =
    integration_value(agency_db, local_tenant_id, "api_key") |> result.unwrap(key_fallback)
  case string.trim(api_origin), string.trim(api_key), string.trim(remote_tenant_id) {
    "", _, _ -> Error(Nil)
    _, "", _ -> Error(Nil)
    _, _, "" -> Error(Nil)
    origin, key, remote_id -> Ok(SyncConfig(local_tenant_id, remote_id, origin, key))
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
      "select coalesce(credentials->>$2,''), coalesce(credentials->>'api_key_sealed','') from agency.integrations where tenant_id=$1::uuid and provider='nexus' and kind='connectivity' and active limit 1",
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
