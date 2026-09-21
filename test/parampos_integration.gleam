// Run explicitly: gleam run -m parampos_integration (PG* environment required).
// Every DDL/data change is rolled back. Only the local SOAP fixture is called.
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
import gleeunit/should
import nexus_agency/parampos
import nexus_agency/router
import pog
import simplifile
import wisp/simulate

@external(erlang, "parampos_test_helpers", "statements")
fn statements(sql: String) -> List(String)

fn sql(db, query) {
  let assert Ok(rows) =
    pog.query(query)
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(db)
  let assert Ok(value) = list.first(rows.rows)
  value
}

fn execute(db, query) {
  let assert Ok(_) = pog.query(query) |> pog.execute(db)
  Nil
}

fn post(db, path, values) {
  simulate.browser_request(http.Post, path)
  |> simulate.form_body(values)
  |> simulate.header("cookie", "agency_csrf=dGVzdA")
  |> router.handle(db, "http://localhost:8082")
}

fn callback(db, order, guid, status, hash) {
  post(db, "/api/public/checkout/parampos/return", [
    #("orderId", order),
    #("islemGUID", guid),
    #("md", "md"),
    #("mdStatus", status),
    #("islemHash", hash),
  ])
}

pub fn main() {
  let name = process.new_name("parampos_integration")
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
      let assert Ok(migration) =
        simplifile.read("db/migrations/073_parampos_lifecycle.sql")
      statements(migration) |> list.each(fn(q) { execute(db, q) })
      let tenant =
        sql(
          db,
          "insert into agency.tenants(legal_name,brand_name,slug) values('Test','Test','parampos-'||gen_random_uuid()) returning id::text",
        )
      let listing =
        sql(
          db,
          "insert into agency.listings(tenant_id,code,category,title,price_minor,status) values('"
            <> tenant
            <> "','test','hotel','Test',12345,'published') returning id::text",
        )
      execute(
        db,
        "insert into agency.integrations(tenant_id,provider,kind,active,credentials) values('"
          <> tenant
          <> "','parampos','payment',true,'{\"client_code\":\"test\",\"username\":\"test\",\"password\":\"test\",\"guid\":\"ABC\",\"endpoint\":\"http://127.0.0.1:18089\"}')",
      )
      let arrival = sql(db, "select (current_date+1)::text")
      let departure = sql(db, "select (current_date+4)::text")
      let form = [
        #("listing_id", listing),
        #("tenant", tenant),
        #("name", "Test"),
        #("email", "test@example.invalid"),
        #("phone", ""),
        #("check_in", arrival),
        #("check_out", departure),
        #("guest_count", "2"),
        #("idempotency_key", "test-key"),
        #("csrf_token", "test"),
      ]
      let response = post(db, "/api/public/checkout/start", form)
      response.status |> should.equal(200)
      let assert Ok(session) =
        json.parse(
          simulate.read_body(response),
          decode.field("sessionId", decode.string, decode.success),
        )
      let repeat = post(db, "/api/public/checkout/start", form)
      repeat.status |> should.equal(200)
      json.parse(
        simulate.read_body(repeat),
        decode.field("sessionId", decode.string, decode.success),
      )
      |> should.equal(Ok(session))
      let order =
        sql(
          db,
          "select order_id::text from agency.payment_sessions where id='"
            <> session
            <> "'",
        )
      let card = [
        #("session_id", session),
        #("csrf_token", "test"),
        #("cardOwner", "Test"),
        #("pan", "4444444444444444"),
        #("cvv", "123"),
        #("expiryMonth", "12"),
        #("expiryYear", "2030"),
      ]
      post(db, "/api/public/checkout/parampos/start", card).status
      |> should.equal(200)
      post(db, "/api/public/checkout/parampos/start", card).status
      |> should.equal(409)
      callback(
        db,
        order,
        sql(
          db,
          "select transaction_guid from agency.payment_sessions where id='"
            <> session
            <> "'",
        ),
        "1",
        "tampered",
      ).headers
      |> list.key_find("location")
      |> should.equal(Ok(
        "http://localhost:8082/iletisim?payment=verification_failed",
      ))
      let guid =
        sql(
          db,
          "select transaction_guid from agency.payment_sessions where id='"
            <> session
            <> "'",
        )
      let failed_hash = parampos.callback_hash("ABC", guid, "md", "0", order)
      callback(db, order, guid, "0", failed_hash).headers
      |> list.key_find("location")
      |> should.equal(Ok("http://localhost:8082/iletisim?payment=failed"))
      sql(
        db,
        "select status from agency.payment_sessions where id='"
          <> session
          <> "'",
      )
      |> should.equal("failed")
      let session =
        sql(
          db,
          "select agency.checkout_session('"
            <> tenant
            <> "','"
            <> order
            <> "')::text",
        )
      let card =
        list.map(card, fn(pair) {
          case pair.0 {
            "session_id" -> #("session_id", session)
            _ -> pair
          }
        })
      post(db, "/api/public/checkout/parampos/start", card).status
      |> should.equal(200)
      let guid =
        sql(
          db,
          "select transaction_guid from agency.payment_sessions where id='"
            <> session
            <> "'",
        )
      execute(
        db,
        "update agency.payment_sessions set expires_at=now()-interval '1 second' where id='"
          <> session
          <> "'",
      )
      let expired_hash = parampos.callback_hash("ABC", guid, "md", "1", order)
      callback(db, order, guid, "1", expired_hash).headers
      |> list.key_find("location")
      |> should.equal(Ok(
        "http://localhost:8082/iletisim?payment=expired_or_processing",
      ))
      post(db, "/api/public/checkout/parampos/start", card).status
      |> should.equal(404)
      let session =
        sql(
          db,
          "select agency.checkout_session('"
            <> tenant
            <> "','"
            <> order
            <> "')::text",
        )
      let card =
        list.map(card, fn(pair) {
          case pair.0 {
            "session_id" -> #("session_id", session)
            _ -> pair
          }
        })
      post(db, "/api/public/checkout/parampos/start", card).status
      |> should.equal(200)
      let guid =
        sql(
          db,
          "select transaction_guid from agency.payment_sessions where id='"
            <> session
            <> "'",
        )
      let hash = parampos.callback_hash("ABC", guid, "md", "1", order)
      callback(db, order, guid, "1", hash).headers
      |> list.key_find("location")
      |> should.equal(Ok("http://localhost:8082/iletisim?payment=paid"))
      callback(db, order, guid, "1", hash).headers
      |> list.key_find("location")
      |> should.equal(Ok("http://localhost:8082/iletisim?payment=paid"))
      sql(db, "select status from agency.orders where id='" <> order <> "'")
      |> should.equal("confirmed")
      sql(
        db,
        "select r.payment_status from agency.reservations r join agency.orders o on o.reservation_id=r.id where o.id='"
          <> order
          <> "'",
      )
      |> should.equal("paid")
      // Returning Error intentionally rolls back migration and fixtures.
      Error("verified_rollback")
    })
  case outcome {
    Error(pog.TransactionRolledBack("verified_rollback")) ->
      io.println(
        "ParamPOS HTTP + SOAP + PostgreSQL integration passed (rolled back).",
      )
    _ -> panic as "Integration transaction did not finish"
  }
}
