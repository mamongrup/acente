// Run explicitly: gleam run -m nexus_connection_callback_test
// Verifies the positive NEXUS connection-approved callback path inside a
// rollback transaction. No fixture tenant or credential is left behind.
import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleeunit/should
import nexus_agency/router
import pog
import wisp/simulate

fn sql(db, query) {
  let assert Ok(rows) =
    pog.query(query)
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(db)
  let assert Ok(value) = list.first(rows.rows)
  value
}

fn post_callback(db, agency_id: String, callback_key: String, issued_key: String) {
  simulate.browser_request(http.Post, "/v1/nexus/connection-approved")
  |> simulate.header("authorization", "Bearer " <> callback_key)
  |> simulate.json_body(json.object([
    #("agency_id", json.string(agency_id)),
    #("api_key", json.string(issued_key)),
  ]))
  |> router.handle(db, "http://localhost:8082")
}

pub fn main() {
  let callback_key = envoy.get("NEXUS_API_KEY") |> result.unwrap("") |> string.trim
  case callback_key == "" {
    True -> panic as "NEXUS_API_KEY must be set for callback flow test"
    False -> Nil
  }

  let name = process.new_name("nexus_connection_callback_test")
  let config =
    pog.default_config(name)
    |> pog.host(envoy.get("PGHOST") |> result.unwrap("127.0.0.1"))
    |> pog.port(
      envoy.get("PGPORT") |> result.try(int.parse) |> result.unwrap(5434),
    )
    |> pog.database(envoy.get("PGDATABASE") |> result.unwrap("nexus_agency"))
    |> pog.user(envoy.get("PGUSER") |> result.unwrap("agency_app"))
    |> pog.password(option.Some(envoy.get("PGPASSWORD") |> result.unwrap("")))
  let assert Ok(_) = pog.start(config)

  let outcome =
    pog.transaction(pog.named_connection(name), fn(db) {
      let tenant =
        sql(
          db,
          "insert into agency.tenants(legal_name,brand_name,slug) values('Callback Test','Callback Test','callback-'||gen_random_uuid()) returning id::text",
        )
      let issued_key = "nx_callback_test_" <> string.slice(tenant, 0, 8)
      let response = post_callback(db, tenant, callback_key, issued_key)
      case response.status == 200 {
        True -> Nil
        False -> io.println("callback body: " <> simulate.read_body(response))
      }
      response.status |> should.equal(200)
      simulate.read_body(response)
      |> string.contains("\"ok\":true")
      |> should.be_true
      let assert Ok(request_id) = list.key_find(response.headers, "x-request-id")
      string.trim(request_id) |> should.not_equal("")

      sql(
        db,
        "select count(*)::text from agency.integrations where tenant_id='"
          <> tenant
          <> "' and provider='nexus' and kind='connectivity' and active and coalesce(credentials->>'api_key_sealed','') like 'v1:%' and not (credentials ? 'api_key')",
      )
      |> should.equal("1")

      sql(
        db,
        "select request_id from agency.audit_logs where tenant_id='"
          <> tenant
          <> "' and action='integration.nexus.connection_approved' and request_id<>''",
      )
      |> should.equal(request_id)

      Error("verified_rollback")
    })

  case outcome {
    Error(pog.TransactionRolledBack("verified_rollback")) ->
      io.println("NEXUS connection callback flow passed (rolled back).")
    _ -> panic as "Callback transaction did not roll back"
  }
}
