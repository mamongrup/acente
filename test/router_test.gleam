//// Router tests.
////
//// These only exercise paths that never touch the database: public pages,
//// auth-guard redirects (no session cookie is sent), and the 404 fallback.
//// The connection passed to the router is a named pog connection that is
//// never registered and never queried.

import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleeunit/should
import nexus_agency/csrf
import nexus_agency/router
import pog
import support.{
  create_unique_admin, env_set, env_unset, unique_username, with_env2, with_lock,
  with_unique_session,
}
import wisp
import wisp/simulate

const origin = "http://localhost:8082"

/// A placeholder connection. Safe because no request in this file reaches a
/// pog query; if one ever did, pgo would fail loudly instead of hanging.
fn fake_db() -> pog.Connection {
  pog.named_connection(process.new_name("nexus_agency_test_db"))
}

fn get(path: String) -> wisp.Response {
  simulate.browser_request(http.Get, path)
  |> router.handle(fake_db(), origin)
}

fn header(resp: wisp.Response, name: String) -> Result(String, Nil) {
  list.key_find(resp.headers, name)
}

fn get_headers(resp: wisp.Response, name: String) -> List(String) {
  list.filter_map(resp.headers, fn(pair) {
    case pair.0 == name {
      True -> Ok(pair.1)
      False -> Error(Nil)
    }
  })
}

pub fn landing_page_renders_test() {
  // The homepage now reads tenant data during SSR. Exercise it only with a
  // real connection; the critical browser suite covers it in every local run.
  case real_db() {
    Ok(db) -> {
      let _ =
        simulate.browser_request(http.Get, "/")
        |> router.handle(db, origin)
        |> should_status(200)
      Nil
    }
    Error(_) -> panic as database_required()
  }
}

pub fn health_endpoint_returns_json_test() {
  let resp = get("/health")
  resp.status |> should.equal(200)
  header(resp, "cache-control") |> should.equal(Ok("no-store"))
  simulate.read_body(resp)
  |> string.contains("\"database\":\"ready\"")
  |> should.be_true
}

pub fn login_page_renders_test() {
  let resp = get("/login")
  resp.status |> should.equal(200)
  simulate.read_body(resp)
  |> string.contains("action=\"/login\"")
  |> should.be_true
}

pub fn public_contact_form_renders_test() {
  let resp = get("/iletisim?listing=fixture")
  resp.status |> should.equal(200)
  let body = simulate.read_body(resp)
  body |> string.contains("TEKLİF TALEBİ") |> should.be_true
  body |> string.contains("name=\"listing_id\"") |> should.be_true
}

pub fn login_page_arabic_is_rtl_test() {
  let resp = get("/login?lang=ar")
  resp.status |> should.equal(200)
  simulate.read_body(resp)
  |> string.contains("rtl")
  |> should.be_true
}

pub fn admin_requires_session_test() {
  let resp = get("/admin")
  resp.status |> should.equal(303)
  header(resp, "location") |> should.equal(Ok("/login"))
}

pub fn admin_section_requires_session_test() {
  let resp = get("/admin/catalog")
  resp.status |> should.equal(303)
  header(resp, "location") |> should.equal(Ok("/login"))
}

pub fn holiday_home_requires_session_test() {
  let resp = get("/admin/holiday-home/faq")
  resp.status |> should.equal(303)
  header(resp, "location") |> should.equal(Ok("/login"))
}

pub fn logout_without_session_redirects_test() {
  simulate.browser_request(http.Post, "/logout")
  |> router.handle(fake_db(), origin)
  |> should_status(303)
}

pub fn unknown_path_returns_404_test() {
  let resp = get("/definitely/not/a/page")
  resp.status |> should.equal(404)
  simulate.read_body(resp)
  |> string.contains("bulunamadı")
  |> should.be_true
}

pub fn set_lang_redirects_to_referer_test() {
  let resp =
    simulate.browser_request(http.Get, "/set-lang/en")
    |> simulate.header("referer", origin <> "/admin/catalog")
    |> router.handle(fake_db(), origin)

  resp.status |> should.equal(303)
  header(resp, "location") |> should.equal(Ok(origin <> "/admin/catalog"))
}

pub fn set_lang_sets_language_cookie_test() {
  let resp = get("/set-lang/de")
  resp.status |> should.equal(303)
  let cookies = get_headers(resp, "set-cookie")
  cookies
  |> list.any(fn(cookie) { string.contains(cookie, "agency_lang=ZGU") })
  |> should.be_true
  cookies
  |> list.any(fn(cookie) { string.contains(cookie, "nexus_lang=de") })
  |> should.be_true
}

pub fn set_lang_normalizes_unknown_code_test() {
  get("/set-lang/not-a-language")
  |> should_status(303)
}

fn should_status(resp: wisp.Response, expected: Int) -> wisp.Response {
  resp.status |> should.equal(expected)
  resp
}

// ---------------------------------------------------------------------------
// Integration tests — require a live PostgreSQL with the seeded admin user.
// These tests connect to the real database, call auth.login, and exercise the
// authenticated router path.  If the database is unreachable the test is
// silently skipped (no failure) so CI without Postgres stays green.
// ---------------------------------------------------------------------------

import gleam/io
import nexus_agency/auth

import envoy

/// Database backed tests must fail loudly when the database is unreachable.
///
/// Every test below used to read `case real_db() { Error(Nil) -> panic as database_required() ... }`,
/// which is indistinguishable from a passing test: a missing database, wrong
/// credentials or a stopped Postgres all produced a green suite that asserted
/// nothing. The integration suite is exactly where silent green is most
/// dangerous, because these are the only tests that exercise routing,
/// authentication and role boundaries end to end. If the database is not
/// there, that is a failure to fix, not a reason to skip.
fn database_required() -> String {
  "bu test gercek bir veritabani gerektirir: gleam test oncesinde acente veritabanini baslatin (scripts/run-dev.ps1)"
}

@external(erlang, "agency_test_env", "integration_pool_name")
fn integration_pool_name() -> process.Name(pog.Message)

fn real_db() -> Result(pog.Connection, Nil) {
  // Read connection details from environment (set by .env via run-dev.ps1).
  // Falls back to sensible dev defaults.  pog.start is lazy — it starts a
  // pool but defers actual connection.  We attempt a trivial query to
  // confirm the database is reachable before handing the connection to
  // the test.  If the query fails we treat the DB as unavailable.
  let host = envoy.get("PGHOST") |> result.unwrap("127.0.0.1")
  let port =
    envoy.get("PGPORT")
    |> result.try(int.parse)
    |> result.unwrap(5432)
  let db_name = envoy.get("PGDATABASE") |> result.unwrap("nexus_agency")
  let user = envoy.get("PGUSER") |> result.unwrap("agency_app")
  let password = envoy.get("PGPASSWORD") |> result.unwrap("")
  let pool_name = integration_pool_name()
  let config =
    pog.default_config(pool_name)
    |> pog.host(host)
    |> pog.port(port)
    |> pog.database(db_name)
    |> pog.user(user)
    |> pog.password(option.Some(password))
    |> pog.pool_size(2)
  let started = case process.named(pool_name) {
    Ok(_) -> Ok(Nil)
    Error(_) -> pog.start(config) |> result.map(fn(_) { Nil })
  }
  case started {
    Error(_) -> {
      io.println("[SKIP] integration test: pool start failed")
      Error(Nil)
    }
    Ok(_) -> {
      let db = pog.named_connection(pool_name)
      // A trivial query that will only succeed against a live Postgres.
      case
        pog.query("SELECT 1")
        |> pog.execute(db)
      {
        Ok(_) -> {
          // Keep integration tests deterministic without seeding production
          // data. The fixed tenant/email pair is overwritten on every run.
          let tenant_fixture =
            "INSERT INTO agency.tenants(id, legal_name, brand_name, slug) VALUES ('00000000-0000-0000-0000-000000000001', 'NEXUS Test Tenant', 'NEXUS Test', 'nexus-test') ON CONFLICT (id) DO UPDATE SET legal_name = excluded.legal_name;"
          let user_fixture =
            "INSERT INTO agency.users(tenant_id, email, display_name, membership_type, active, password_hash) VALUES ('00000000-0000-0000-0000-000000000001', 'integration-admin@nexus.local', 'Test Admin', 'admin', true, crypt('admin123456', gen_salt('bf'))) ON CONFLICT (tenant_id, email) DO UPDATE SET display_name = excluded.display_name, membership_type = excluded.membership_type, active = true, password_hash = excluded.password_hash, failed_login_attempts = 0, locked_until = NULL;"
          case pog.query(tenant_fixture) |> pog.execute(db) {
            Error(_) -> {
              io.println(
                "[SKIP] integration test: tenant fixture could not be created",
              )
              Error(Nil)
            }
            Ok(_) ->
              case pog.query(user_fixture) |> pog.execute(db) {
                Ok(_) -> Ok(db)
                Error(_) -> {
                  io.println(
                    "[SKIP] integration test: admin fixture could not be created",
                  )
                  Error(Nil)
                }
              }
          }
        }
        Error(_) -> {
          io.println("[SKIP] integration test: database unreachable")
          Error(Nil)
        }
      }
    }
  }
}

/// Login as the seeded admin user, extract the session cookie, then GET
/// /admin and verify the dashboard renders with the user's name.
pub fn login_and_access_admin_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    // skip
    Ok(db) -> {
      // 1. Attempt login --------------------------------------------------------
      let session_token = wisp.random_string(48)
      let login_result =
        auth.login(
          db,
          "integration-admin@nexus.local",
          "admin123456",
          session_token,
        )
      login_result |> should.be_ok

      // 2. Build a browser request carrying the session cookie -------------------
      let resp =
        simulate.browser_request(http.Get, "/admin")
        |> simulate.cookie("agency_session", session_token, wisp.Signed)
        |> router.handle(db, origin)

      // 3. Assert the dashboard renders ------------------------------------------
      resp.status |> should.equal(200)
      let body = simulate.read_body(resp)
      // The dashboard includes the greeting "<name>, Genel bakış"
      body |> string.contains("Genel bakış") |> should.be_true
      // Sidebar brand should appear
      body |> string.contains("NEXUS") |> should.be_true

      // 4. Cleanup: logout so the token row is removed --------------------------
      auth.logout(db, session_token)
    }
  }
}

/// Vitrin dili çerezi panelin seçili dilini değiştiremez.
pub fn storefront_locale_does_not_translate_admin_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let session_token = wisp.random_string(48)
      auth.login(
        db,
        "integration-admin@nexus.local",
        "admin123456",
        session_token,
      )
      |> should.be_ok
      let resp =
        simulate.browser_request(http.Get, "/admin")
        |> simulate.cookie("agency_session", session_token, wisp.Signed)
        |> simulate.cookie("nexus_lang", "ru", wisp.PlainText)
        |> simulate.cookie("agency_lang", "tr", wisp.PlainText)
        |> router.handle_localized(db, origin)
      resp.status |> should.equal(200)
      let body = simulate.read_body(resp)
      body |> string.contains("Otel") |> should.be_true
      body |> string.contains("Отель") |> should.be_false
      auth.logout(db, session_token)
    }
  }
}

pub fn parampos_refund_requires_configured_admin_and_csrf_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let session_token = wisp.random_string(48)
      auth.login(
        db,
        "integration-admin@nexus.local",
        "admin123456",
        session_token,
      )
      |> should.be_ok
      let request =
        simulate.browser_request(
          http.Post,
          "/admin/finance-overview/parampos-refund",
        )
        |> simulate.cookie("agency_session", session_token, wisp.Signed)
      let missing_csrf =
        request
        |> simulate.form_body([
          #("refund_id", "00000000-0000-0000-0000-000000000001"),
        ])
        |> router.handle(db, origin)
      missing_csrf.status |> should.equal(403)
      let unconfigured =
        request
        |> simulate.form_body([
          #("csrf", csrf.token_for(session_token)),
          #("refund_id", "00000000-0000-0000-0000-000000000001"),
        ])
        |> router.handle(db, origin)
      unconfigured.status |> should.equal(422)
      auth.logout(db, session_token)
    }
  }
}

/// Customer accounts are valid credentials but never receive the back-office
/// panel. This guards the role boundary added to the shared session middleware.
pub fn customer_role_cannot_access_admin_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let customer_fixture =
        "INSERT INTO agency.users(tenant_id, email, display_name, membership_type, active, password_hash) VALUES ('00000000-0000-0000-0000-000000000001', 'integration-customer@nexus.local', 'Test Customer', 'customer', true, crypt('customer123456', gen_salt('bf'))) ON CONFLICT (tenant_id, email) DO UPDATE SET membership_type = excluded.membership_type, active = true, password_hash = excluded.password_hash, failed_login_attempts = 0, locked_until = NULL;"
      case pog.query(customer_fixture) |> pog.execute(db) {
        Error(_) -> should.fail()
        Ok(_) -> {
          let session_token = wisp.random_string(48)
          auth.login(
            db,
            "integration-customer@nexus.local",
            "customer123456",
            session_token,
          )
          |> should.be_ok
          let resp =
            simulate.browser_request(http.Get, "/admin")
            |> simulate.cookie("agency_session", session_token, wisp.Signed)
            |> router.handle(db, origin)
          resp.status |> should.equal(403)
          auth.logout(db, session_token)
        }
      }
    }
  }
}

/// Duplicate active e-mails across tenants must fail closed with a dedicated
/// error instead of selecting an arbitrary agency account.
pub fn ambiguous_email_returns_specific_error_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let email = "integration-ambiguous@nexus.local"
      let tenant_fixture =
        "INSERT INTO agency.tenants(id, legal_name, brand_name, slug) VALUES ('00000000-0000-0000-0000-000000000002', 'NEXUS Ambiguous Tenant', 'NEXUS Ambiguous', 'nexus-ambiguous') ON CONFLICT (id) DO UPDATE SET legal_name = excluded.legal_name;"
      let primary_user_fixture =
        "INSERT INTO agency.users(tenant_id, email, display_name, membership_type, active, password_hash) VALUES ('00000000-0000-0000-0000-000000000001', 'integration-ambiguous@nexus.local', 'Primary Ambiguous User', 'staff', true, crypt('ambiguous123', gen_salt('bf'))) ON CONFLICT (tenant_id, email) DO UPDATE SET active = true, password_hash = excluded.password_hash, failed_login_attempts = 0, locked_until = NULL;"
      let user_fixture =
        "INSERT INTO agency.users(tenant_id, email, display_name, membership_type, active, password_hash) VALUES ('00000000-0000-0000-0000-000000000002', 'integration-ambiguous@nexus.local', 'Ambiguous User', 'staff', true, crypt('ambiguous123', gen_salt('bf'))) ON CONFLICT (tenant_id, email) DO UPDATE SET active = true, password_hash = excluded.password_hash, failed_login_attempts = 0, locked_until = NULL;"
      case pog.query(tenant_fixture) |> pog.execute(db) {
        Error(_) -> should.fail()
        Ok(_) ->
          case pog.query(primary_user_fixture) |> pog.execute(db) {
            Error(_) -> should.fail()
            Ok(_) -> {
              case pog.query(user_fixture) |> pog.execute(db) {
                Error(_) -> should.fail()
                Ok(_) -> {
                  let token = wisp.random_string(48)
                  case auth.login(db, email, "ambiguous123", token) {
                    Error(auth.AmbiguousAccount) -> Nil
                    _ -> should.fail()
                  }
                  let scoped_token = wisp.random_string(48)
                  auth.login_with_tenant(
                    db,
                    email,
                    "ambiguous123",
                    scoped_token,
                    "nexus-ambiguous",
                  )
                  |> should.be_ok
                  auth.logout(db, scoped_token)
                  pog.query(
                    "DELETE FROM agency.users WHERE email='integration-ambiguous@nexus.local'",
                  )
                  |> pog.execute(db)
                  |> fn(_) { Nil }
                }
              }
              pog.query(
                "DELETE FROM agency.tenants WHERE id='00000000-0000-0000-0000-000000000002'",
              )
              |> pog.execute(db)
              |> should.be_ok
              |> fn(_) { Nil }
            }
          }
      }
    }
  }
}

/// Verify that a bad password returns 401 on the login POST.
pub fn login_wrong_password_returns_401_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      // Benzersiz hesap: başarısız denemeler paylaşılan admin'in sayaçlarını
      // taşımasın (paralel lockout testiyle yarışmasın).
      let email = unique_username("wrongpw")
      create_unique_admin(db, email)
      let resp =
        simulate.browser_request(http.Post, "/login")
        |> simulate.form_body([
          #("email", email),
          #("password", "wrong-password"),
        ])
        |> router.handle(db, origin)

      resp.status |> should.equal(401)
      let body = simulate.read_body(resp)
      body
      |> string.contains("E-posta veya parola hatalı.")
      |> should.be_true
    }
  }
}

/// A valid login POST redirects to /admin and sets the session cookie.
pub fn login_success_redirects_to_admin_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      // Benzersiz hesap: test login akışının kendisini doğruladığı için
      // with_unique_session kullanılamaz (o oturumu önceden açar); bunun
      // yerine paylaşılan integration-admin'in giriş sayaçlarına paralel
      // dokunmayan tek kullanımlık hesap yaratılır (lockout testi deseni).
      let email = unique_username("loginsuccess")
      create_unique_admin(db, email)
      let resp =
        simulate.browser_request(http.Post, "/login")
        |> simulate.form_body([
          #("email", email),
          #("password", "admin123456"),
        ])
        |> router.handle(db, origin)

      resp.status |> should.equal(303)
      resp |> header("location") |> should.equal(Ok("/admin"))
      // The response sets TWO cookies now: the signed session cookie and the
      // (unsigned, JS-readable) CSRF token cookie. Find the session one.
      let session_cookie =
        list.filter_map(get_headers(resp, "set-cookie"), fn(value) {
          case string.contains(value, "agency_session") {
            True -> Ok(value)
            False -> Error(Nil)
          }
        })
      let assert Ok(session_value) = list.first(session_cookie)
      session_value |> string.contains("agency_session") |> should.be_true
    }
  }
}

/// Verify that the account locks after 5 failed attempts.
pub fn account_locks_after_failed_attempts_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      // Lockout kesinliği hesap sayaçlarına dayanır; paralel koşan başka bir
      // oturum testiyle yarışmasın diye kilit altında ve kendi benzersiz
      // hesabında koşar.
      with_lock("account_lockout", "account_lockout_owner", fn() {
        // 1. Test için benzersiz hesap (sayaç paylaşılmaz).
        let email = unique_username("lockout")
        create_unique_admin(db, email)

        // 2. Make 5 failed login attempts.
        let failed_attempt = fn(_) {
          let session_token = wisp.random_string(48)
          auth.login(db, email, "wrong-password", session_token)
          |> fn(_) { Nil }
        }
        failed_attempt(1)
        failed_attempt(2)
        failed_attempt(3)
        failed_attempt(4)
        failed_attempt(5)

        // 3. The 6th attempt should be rejected as account locked.
        let session_token = wisp.random_string(48)
        let result = auth.login(db, email, "wrong-password", session_token)
        case result {
          Ok(_) -> {
            // Should not succeed - account should be locked
            panic as "Expected account to be locked"
          }
          Error(error_type) -> {
            error_type |> should.equal(auth.AccountLocked)
          }
        }

        // 4. Cleanup: unlock the dedicated account (paylaşılan hesaba dokunmaz).
        "UPDATE agency.users SET failed_login_attempts = 0, locked_until = NULL WHERE lower(email) = $1"
        |> pog.query()
        |> pog.parameter(pog.text(email))
        |> pog.execute(db)
        |> fn(_) { Nil }
      })
    }
  }
}

// ---------------------------------------------------------------------------
// Para birimi tercihi (sunucu tarafı) — dil tercihi deseninin birebir testi.
// router facade'deki POST /admin/preferences/currency ucunu ve girişte
// nexus_currency çerez damgasını uçtan uca doğrular.
// ---------------------------------------------------------------------------

const pref_email = "integration-admin@nexus.local"

// Paralel yürütme yardımcıları (agency_test_env köprüsü) test/support.gleam
// modülüne taşındı; bu dosya yukarıdaki dot-import ile bağlanır:
// import support.{create_unique_admin, env_set, env_unset, unique_username,
//   with_env2, with_lock, with_unique_session}

/// Hesapta kayıtlı para birimi tercihini okur (yok → "").
fn account_currency_pref(db: pog.Connection, email: String) -> String {
  case
    "select coalesce(u.currency_pref,'') from agency.users u where lower(u.email)=lower($1) limit 1"
    |> pog.query()
    |> pog.parameter(pog.text(email))
    |> pog.returning(
      decode.field(0, decode.string, fn(cur) { decode.success(cur) }),
    )
    |> pog.execute(db)
  {
    Ok(returned) -> list.first(returned.rows) |> result.unwrap("")
    Error(_) -> ""
  }
}

fn reset_currency_pref(db: pog.Connection, email: String) -> Nil {
  "update agency.users set currency_pref=null where lower(email)=lower($1)"
  |> pog.query()
  |> pog.parameter(pog.text(email))
  |> pog.execute(db)
  |> fn(_) { Nil }
}

/// Geçerli oturum + CSRF token ile gelen POST tercihi hesaba yazmalı (204).
pub fn currency_preference_persisted_to_account_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      with_unique_session(db, "currencypref", fn(email, session_token) {
        reset_currency_pref(db, email)

        let resp =
          simulate.browser_request(
            http.Post,
            "/admin/preferences/currency?currency=EUR",
          )
          |> simulate.cookie("agency_session", session_token, wisp.Signed)
          |> simulate.form_body([#("csrf", csrf.token_for(session_token))])
          |> router.handle(db, origin)

        resp.status |> should.equal(204)
        account_currency_pref(db, email) |> should.equal("EUR")
      })
    }
  }
}

// ---------------------------------------------------------------------------
// Public form CSRF akışı — e2e regresyon.
//
// Sözleşme (router_impl `csrf_token_for` + `public_csrf_valid`):
//   1) Public GET formları `csrf_token` gizli alanı ve eşleşen `agency_csrf`
//      çerezini damgalar (double-submit); oturumlu tarayıcıda token imzalı
//      `agency_session` çerezinden HMAC ile türetilir.
//   2) POST'ta: oturum varsa token `csrf.verify` ile oturumdan doğrulanır;
//      oturum yoksa çerez/form eşitliği sabit zamanlı karşılaştırılır.
//   3) CSRF reddi (403) diğer doğrulamalardan ÖNCE gelir — eksik/yanlış
//      token, geçersiz alanların ürettiği 400'ü asla gölgeleyemez.

/// Public iletisim formundaki csrf_token gizli alanını ayıklar.
/// Lustre çıktı sırası derleyiciye bağlıdır (value/name sırası değişebilir),
/// bu yüzden "csrf_token" ile sınırlı pencere içinde value= yakalanır.
fn public_form_csrf(body: String) -> Result(String, Nil) {
  case string.split_once(body, "name=\"csrf_token\"") {
    Ok(#(_, rest)) ->
      case string.split_once(rest, "value=\"") {
        Ok(#(_, value)) ->
          case string.split_once(value, "\"") {
            Ok(#(token, _)) if token != "" -> Ok(token)
            _ -> Error(Nil)
          }
        Error(_) -> Error(Nil)
      }
    Error(_) -> Error(Nil)
  }
}

fn inquiry_form() -> List(#(String, String)) {
  [
    #("listing_id", ""),
    #("tenant", "nexus-test"),
    #("name", "CSRF Test"),
    #("email", "csrf-e2e-" <> wisp.random_string(8) <> "@nexus.local"),
    #("phone", "+90 555 000 00 00"),
    #("message", "csrf e2e"),
    #("guest_count", "2"),
    #("idempotency_key", "csrf-e2e-" <> wisp.random_string(12)),
  ]
}

/// GET /iletisim sayfası token'ı damgalar ve eşleşen agency_csrf çerezini
/// kurar. Dönen değer formdaki ham token'dır; çerez kablo üzerinde base64
/// kodlu taşınır (wisp PlainText), testte simulate.cookie bu kodlamayı yapar.
fn public_inquiry_csrf_token() -> String {
  let resp = get("/iletisim?tenant=nexus-test")
  resp.status |> should.equal(200)
  // Çerez de damgalanmalı (double-submit'in diğer yarısı).
  list.filter_map(get_headers(resp, "set-cookie"), fn(value) {
    case string.contains(value, "agency_csrf=") {
      True -> Ok(value)
      False -> Error(Nil)
    }
  })
  |> should.not_equal([])
  let assert Ok(token) = public_form_csrf(simulate.read_body(resp))
  token
}

pub fn public_inquiry_csrf_happy_path_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let token = public_inquiry_csrf_token()
      let resp =
        simulate.browser_request(http.Post, "/iletisim")
        |> simulate.header("x-forwarded-for", "192.0.2.11")
        |> simulate.cookie("agency_csrf", token, wisp.PlainText)
        |> simulate.form_body(
          list.append(inquiry_form(), [
            #("csrf_token", token),
          ]),
        )
        |> router.handle(db, origin)

      resp.status |> should.equal(303)
      resp |> header("location") |> should.equal(Ok("/iletisim?sent=1"))
    }
  }
}

/// Çerez var ama form token'ı eksik → 403 (double-submit kırık).
pub fn public_inquiry_csrf_missing_form_token_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let token = public_inquiry_csrf_token()
      let resp =
        simulate.browser_request(http.Post, "/iletisim")
        |> simulate.header("x-forwarded-for", "192.0.2.12")
        |> simulate.cookie("agency_csrf", token, wisp.PlainText)
        |> simulate.form_body(inquiry_form())
        |> router.handle(db, origin)

      resp.status |> should.equal(403)
      simulate.read_body(resp)
      |> string.contains("Güvenlik doğrulaması başarısız")
      |> should.be_true
    }
  }
}

/// Çerez ile form token'ı farklı → 403 (fail-closed).
pub fn public_inquiry_csrf_mismatched_token_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let token = public_inquiry_csrf_token()
      let resp =
        simulate.browser_request(http.Post, "/iletisim")
        |> simulate.header("x-forwarded-for", "192.0.2.13")
        |> simulate.cookie("agency_csrf", token, wisp.PlainText)
        |> simulate.form_body(
          list.append(inquiry_form(), [
            #("csrf_token", token <> "tampered"),
          ]),
        )
        |> router.handle(db, origin)

      resp.status |> should.equal(403)
    }
  }
}

/// Hiç çerez yok → 403; ve 403, geçersiz alan 400'ünden ÖNCE gelir.
pub fn public_inquiry_csrf_absent_cookie_is_403_before_400_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      // Aynı gövde alan-geçersiz (boş name) ve çerezsiz: CSRF kapısı kazanan
      // kontrol olmalı (403), form doğrulaması değil (400).
      let no_cookie =
        simulate.browser_request(http.Post, "/iletisim")
        |> simulate.header("x-forwarded-for", "192.0.2.14")
        |> simulate.form_body(inquiry_form())
        |> router.handle(db, origin)
      no_cookie.status |> should.equal(403)

      // Kontrol: alan-geçersiz (boş name) AMA CSRF geçerli istek 400 döner —
      // yani 403 gerçekten CSRF kapısından geliyor, başka bir sebepten değil.
      let token = public_inquiry_csrf_token()
      let invalid_fields_valid_csrf =
        simulate.browser_request(http.Post, "/iletisim")
        |> simulate.header("x-forwarded-for", "192.0.2.15")
        |> simulate.cookie("agency_csrf", token, wisp.PlainText)
        |> simulate.form_body(
          list.append(inquiry_form(), [#("csrf_token", token)])
          |> list.map(fn(pair) {
            case pair.0 {
              "name" -> #("name", "")
              _ -> pair
            }
          }),
        )
        |> router.handle(db, origin)
      invalid_fields_valid_csrf.status |> should.equal(400)
    }
  }
}

/// Oturumlu tarayıcıda token oturumdan HMAC türetilir: çerez double-submit
/// değeriyle uyuşmasa bile doğru oturum token'ı KABUL edilir; yanlış oturum
/// türevi REDDedilir. (Imzalı agency_session + injected agency_csrf ile
/// double-submit bypass'ının kapatıldığı sözleşmenin regresyonu.)
pub fn public_inquiry_csrf_session_bound_token_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      // Benzersiz oturum: paylaşılan admin yerine tek kullanımlık hesap;
      // giriş/çıkış yardımcıda (paralel sayaç yarışı yok).
      with_unique_session(db, "publiccsrf", fn(_email, session_token) {
        // Kötü niyetli sayfanın enjekte edebileceği double-submit çerezi.
        let attacker_cookie = "attacker-controlled-value"
        let session_bound = csrf.token_for(session_token)

        let valid_session_post =
          simulate.browser_request(http.Post, "/iletisim")
          |> simulate.header("x-forwarded-for", "192.0.2.16")
          |> simulate.cookie("agency_session", session_token, wisp.Signed)
          |> simulate.cookie("agency_csrf", attacker_cookie, wisp.PlainText)
          |> simulate.form_body(
            list.append(inquiry_form(), [
              #("csrf_token", session_bound),
            ]),
          )
          |> router.handle(db, origin)
        valid_session_post.status |> should.equal(303)

        let wrong_session_post =
          simulate.browser_request(http.Post, "/iletisim")
          |> simulate.header("x-forwarded-for", "192.0.2.17")
          |> simulate.cookie("agency_session", session_token, wisp.Signed)
          |> simulate.cookie("agency_csrf", attacker_cookie, wisp.PlainText)
          |> simulate.form_body(
            list.append(inquiry_form(), [
              #("csrf_token", csrf.token_for("other-session")),
            ]),
          )
          |> router.handle(db, origin)
        wrong_session_post.status |> should.equal(403)
      })
    }
  }
}

// ---------------------------------------------------------------------------
// SECRET_KEY_BASE rotasyonu — imzalı oturum çerezi ve CSRF token etkisi.
//
// wisp imzalı çerezi Connection.secret_key_base ile imzalar/doğrular;
// production'da bu sır önyüklemede SECRET_KEY_BASE'den alınır. Rotasyon =
// süreç yeni sırla yeniden başlatılır. Test bunu aynı istek üzerinde sırrı
// değiştirerek birebir model eder: çerez eski sır ile imzalanır, doğrulama
// öncesi connection sırrı yeni sıra çevrilir — sunucunun rotasyon sonrası
// durumunun karşılığıdır. Sözleşme:
//   1) Rotasyon, eski oturumun imzasını geçersiz kılar → tarayıcı anonim
//      kalır; oturumdan türetilen CSRF token'ı (csrf.token_for) da reddedilir.
//   2) Anonim double-submit akışı (agency_csrf çerezi + form alanı) sırdan
//      bağımsız olduğundan rotasyondan etkilenmez — public ziyaretçi kaybolmaz.
//   3) Rotasyon sonrası yeni oturum yeni sır altında imzalanır ve yeni
//      token türetir; saldırgan çerezi ile double-submit bypass hâlâ kapalı.

const rotation_old_secret = "rotation-old-secret-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const rotation_new_secret = "rotation-new-secret-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

/// Rotasyon öncesi oturum-türevli token kabul edilir (303); aynı istek
/// rotasyon sonrası (yeni sır) eski imzalı çerezi kaybeder ve 403 alır.
pub fn secret_rotation_invalidates_signed_session_and_csrf_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      // Pencereyi deterministik kapalıya zorla; env değişikliği kilit altında
      // ve panik-güvenli geri yüklemeyle yapılır (paralel env sızmaz).
      with_env2(
        "secret_rotation_window",
        [#("SECRET_KEY_BASE_PREVIOUS", env_unset())],
        fn() { rotate_invalidates_body(db) },
      )
    }
  }
}

fn rotate_invalidates_body(db: pog.Connection) -> Nil {
  let session_token = wisp.random_string(48)
  auth.login(db, pref_email, "admin123456", session_token)
  |> should.be_ok

  let attacker_cookie = "attacker-controlled-value"
  let form_with = fn(form_token: String) {
    list.append(inquiry_form(), [#("csrf_token", form_token)])
  }
  // Eski sır altında imzalanmış oturum çerezi taşıyan tarayıcı.
  let old_era =
    simulate.browser_request(http.Post, "/iletisim")
    |> simulate.header("x-forwarded-for", "192.0.2.31")
    |> wisp.set_secret_key_base(rotation_old_secret)
    |> simulate.cookie("agency_session", session_token, wisp.Signed)
    |> simulate.cookie("agency_csrf", attacker_cookie, wisp.PlainText)

  // Rotasyon öncesi: oturum-türevli token kabul → 303. (simulate.form_body
  // bağlantıyı varsayılan sırla yeniden kurar; dönem sırrı gönderimden
  // hemen önce ayarlanır — imza doğrulaması bu sır ile yapılır.)
  old_era
  |> simulate.form_body(form_with(csrf.token_for(session_token)))
  |> wisp.set_secret_key_base(rotation_old_secret)
  |> router.handle(db, origin)
  |> should_status(303)

  // Rotasyon: sunucu yeni sıra geçti (connection sırrı değişir).
  // Eski imza artık doğrulanamaz: oturum yok sayılır, oturum-türevli
  // CSRF token'ı anonim kapıdan reddedilir (çerez/form uyuşmaz → 403).
  old_era
  |> simulate.form_body(form_with(csrf.token_for(session_token)))
  |> wisp.set_secret_key_base(rotation_new_secret)
  |> router.handle(db, origin)
  |> should_status(403)

  // Aynı eski-imzalı çerez /admin'de de oturumu kaybeder: panele giriş
  // yerine girişe yönlendirme gelir (fail-closed, çökme değil).
  let admin =
    simulate.browser_request(http.Get, "/admin")
    |> wisp.set_secret_key_base(rotation_old_secret)
    |> simulate.cookie("agency_session", session_token, wisp.Signed)
    |> wisp.set_secret_key_base(rotation_new_secret)
    |> router.handle(db, origin)
  admin.status |> should.equal(303)
  header(admin, "location") |> should.equal(Ok("/login"))

  auth.logout(db, session_token)
}

/// Rotasyon anonim ziyaretçiyi etkilemez: agency_csrf double-submit çerezi
/// imzasız olduğundan rotasyon sonrası sunucuda da iletisim formu çalışır.
pub fn secret_rotation_anonymous_double_submit_unaffected_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let token = public_inquiry_csrf_token()
      simulate.browser_request(http.Post, "/iletisim")
      |> simulate.header("x-forwarded-for", "192.0.2.32")
      |> wisp.set_secret_key_base(rotation_new_secret)
      |> simulate.cookie("agency_csrf", token, wisp.PlainText)
      |> simulate.form_body(
        list.append(inquiry_form(), [
          #("csrf_token", token),
        ]),
      )
      |> router.handle(db, origin)
      |> should_status(303)
    }
  }
}

/// Rotasyon sonrası yeni oturum yeni sır altında imzalanır ve token türetir:
/// oturum-türevli token kabul edilir; enjekte edilmiş double-submit çerezi
/// (attacker_cookie) yine de bypass edemez — oturum-türev sözleşme rotasyon
/// sonrasında da bozulmaz.
pub fn secret_rotation_new_session_rebinds_csrf_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let session_token = wisp.random_string(48)
      auth.login(db, pref_email, "admin123456", session_token)
      |> should.be_ok

      let attacker_cookie = "attacker-controlled-value"
      simulate.browser_request(http.Post, "/iletisim")
      |> simulate.header("x-forwarded-for", "192.0.2.33")
      |> wisp.set_secret_key_base(rotation_new_secret)
      |> simulate.cookie("agency_session", session_token, wisp.Signed)
      |> simulate.cookie("agency_csrf", attacker_cookie, wisp.PlainText)
      |> simulate.form_body(
        list.append(inquiry_form(), [
          #("csrf_token", csrf.token_for(session_token)),
        ]),
      )
      |> wisp.set_secret_key_base(rotation_new_secret)
      |> router.handle(db, origin)
      |> should_status(303)

      auth.logout(db, session_token)
    }
  }
}

// ---------------------------------------------------------------------------
// Public form CSRF akışı — chat / checkout/start / parampos/start genişletmesi.
//
// Sohbet, satın alma başlangıcı ve ödeme başlatma uçları iletisim formuyla aynı
// kapıdan (public_csrf_valid) geçer; bu grup o sözleşmeyi bu üç uç için de
// sabitler: 403 gövdesi uç türüne göre JSON ya da düz metindir, 403 diğer
// doğrulamalardan önce gelir ve başarı durumu (200/303) CSRF token'ı ile
// birlikte gelmelidir.
//
// Tüm grup tek pog.transaction içinde koşar ve Error ile geri sarılır; bu
// desen parampos_integration.gleam ile aynıdır. Sohbet testleri herhangi bir
// tenant'a yazabilir (tenant kapsamlı AI sohbeti), checkout/parampos
// testleri 00000000-0000-0000-0000-000000000001 ID'li test tenant'ını
// (real_db fixture'ının kullandığı) kullanır.

/// Public sayfadaki <meta name="csrf-token"> değerini ayıklar. Lustre
/// sürümüne göre meta öznitelik sırası değişebilir (content name'den önce
/// ya da sonra gelir); her iki sırayı da aynı etiket sınırı içinde çözer.
fn public_meta_csrf(body: String) -> Result(String, Nil) {
  case string.split_once(body, "name=\"csrf-token\"") {
    Ok(#(before, after)) ->
      // Aynı etiket içinde ileri bak (name ... content sırası);
      // ilk > etiketin sonu olduğundan sonraki etikete taşamaz.
      case string.split_once(after, ">") {
        Ok(#(same_tag, _)) ->
          case string.split_once(same_tag, "content=\"") {
            Ok(#(_, value)) -> meta_token(value)
            // Ters sıra (content ... name): name'den hemen önceki
            // content= aynı etiketin değeridir.
            Error(_) ->
              case list.last(string.split(before, "content=\"")) {
                Ok(value) -> meta_token(value)
                Error(_) -> Error(Nil)
              }
          }
        Error(_) -> Error(Nil)
      }
    Error(_) -> Error(Nil)
  }
}

fn meta_token(value: String) -> Result(String, Nil) {
  case string.split_once(value, "\"") {
    Ok(#(token, _)) if token != "" -> Ok(token)
    _ -> Error(Nil)
  }
}

/// Bir public sayfanın damgaladığı CSRF token'ını döndürür: sayfanın meta
/// etiketindeki ham değer. Testte simulate.cookie ile çerez yarısına
/// dönüştürülür (iletisim testlerinin deseniyle aynı).
fn public_page_csrf_token(db: pog.Connection, path: String) -> String {
  let resp =
    simulate.browser_request(http.Get, path)
    |> router.handle(db, origin)
  resp.status |> should.equal(200)
  get_headers(resp, "set-cookie")
  |> list.filter(fn(value) { string.contains(value, "agency_csrf=") })
  |> list.length
  |> fn(count) { count >= 1 }
  |> should.be_true
  let assert Ok(token) = public_meta_csrf(simulate.read_body(resp))
  token
}

/// Sohbet ucu CSRF'siz POST'u JSON 403 ile reddeder. Token kaynağı `/`
/// sayfasının damgaladığı meta etiketidir (concierge widget'ın üretimdeki
/// kaynağıyla aynı); meta ile çerez değeri eşit damgalanır (double-submit
/// iki yarısı).
pub fn chat_csrf_missing_form_token_is_403_json_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let _ = public_page_csrf_token(db, "/")

      let resp =
        simulate.browser_request(http.Post, "/api/public/chat")
        |> simulate.header("x-forwarded-for", "192.0.2.41")
        |> simulate.form_body([
          #("name", "CSRF Chat Test"),
          #("message", "csrf e2e"),
          #("email", "csrf-chat-" <> wisp.random_string(8) <> "@nexus.local"),
          #("phone", ""),
          #("tenant", "nexus-test"),
          #("lang", "tr"),
        ])
        |> router.handle(db, origin)

      resp.status |> should.equal(403)
      let body = simulate.read_body(resp)
      string.contains(body, "Güvenlik doğrulaması başarısız")
      |> should.be_true
      // JSON gövde, uç türüne uyar; alan doğrulamasının 400 gövdesi değildir.
      json.parse(body, decode.field("ok", decode.bool, decode.success))
      |> should.equal(Ok(False))
    }
  }
}

/// Geçerli çerez + form token'ı sohbet ucunun CSRF kapısından geçer. Kapı
/// sonrası sohbet akışı AI havuzu ve conversation yazımları yaptığı için
/// geçişi yazım yapmayan deterministik sinyalle sabitliyoruz: geçerli CSRF +
/// bilinçli olarak boş name → kapıyı geçen istek alan doğrulamasının 400
/// gövdesini döndürür (403 değil).
pub fn chat_csrf_valid_token_reaches_validation_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let token = public_page_csrf_token(db, "/")
      let resp =
        simulate.browser_request(http.Post, "/api/public/chat")
        |> simulate.header("x-forwarded-for", "192.0.2.42")
        |> simulate.cookie("agency_csrf", token, wisp.PlainText)
        |> simulate.form_body([
          #("name", ""),
          #("message", "csrf e2e"),
          #("email", "csrf-chat-" <> wisp.random_string(8) <> "@nexus.local"),
          #("phone", ""),
          #("tenant", "nexus-test"),
          #("lang", "tr"),
          #("csrf_token", token),
        ])
        |> router.handle(db, origin)

      resp.status |> should.equal(400)
      simulate.read_body(resp)
      |> string.contains("Ad ve mesaj alanlarını kontrol edin")
      |> should.be_true
    }
  }
}

/// Checkout başlangıcı CSRF'siz POST'u JSON 403 ile reddeder; 403, alan
/// doğrulamasının (boş listing_id → 400) ÖNCE gelir.
pub fn checkout_start_csrf_missing_is_403_before_400_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let resp =
        simulate.browser_request(http.Post, "/api/public/checkout/start")
        |> simulate.header("x-forwarded-for", "192.0.2.43")
        |> simulate.form_body([
          #("listing_id", ""),
          #("tenant", "nexus-test"),
          #("name", "CSRF Checkout Test"),
          #(
            "email",
            "csrf-checkout-" <> wisp.random_string(8) <> "@nexus.local",
          ),
          #("phone", ""),
          #("check_in", "2027-01-10"),
          #("check_out", "2027-01-12"),
          #("guest_count", "2"),
          #("idempotency_key", "csrf-e2e-" <> wisp.random_string(12)),
        ])
        |> router.handle(db, origin)

      resp.status |> should.equal(403)
      let body = simulate.read_body(resp)
      string.contains(body, "Güvenlik doğrulaması başarısız")
      |> should.be_true
      json.parse(body, decode.field("ok", decode.bool, decode.success))
      |> should.equal(Ok(False))
    }
  }
}

/// Geçerli double-submit ile kapı geçilir: kapı sonrası ilan araması koşar.
/// Var olmayan ilan ID'si → 404 (400 değil); yani CSRF kapısı aşıldı.
pub fn checkout_start_csrf_valid_reaches_listing_lookup_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let token = public_page_csrf_token(db, "/")
      let resp =
        simulate.browser_request(http.Post, "/api/public/checkout/start")
        |> simulate.header("x-forwarded-for", "192.0.2.44")
        |> simulate.cookie("agency_csrf", token, wisp.PlainText)
        |> simulate.form_body([
          #("listing_id", "00000000-0000-0000-0000-000000000000"),
          #("tenant", "nexus-test"),
          #("name", "CSRF Checkout Test"),
          #(
            "email",
            "csrf-checkout-" <> wisp.random_string(8) <> "@nexus.local",
          ),
          #("phone", ""),
          #("check_in", "2027-01-10"),
          #("check_out", "2027-01-12"),
          #("guest_count", "2"),
          #("idempotency_key", "csrf-e2e-" <> wisp.random_string(12)),
          #("csrf_token", token),
        ])
        |> router.handle(db, origin)

      resp.status |> should.equal(404)
    }
  }
}

/// ParamPOS başlatma CSRF'siz POST'u düz metin 403 ile reddeder; 403, ödeme
/// oturumu aramasının (404) ÖNCE gelir.
pub fn parampos_start_csrf_missing_is_403_before_404_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let resp =
        simulate.browser_request(
          http.Post,
          "/api/public/checkout/parampos/start",
        )
        |> simulate.header("x-forwarded-for", "192.0.2.45")
        |> simulate.form_body([
          #("session_id", "00000000-0000-0000-0000-000000000000"),
        ])
        |> router.handle(db, origin)

      resp.status |> should.equal(403)
      simulate.read_body(resp)
      |> string.contains("Güvenlik doğrulaması başarısız")
      |> should.be_true
    }
  }
}

/// Geçerli double-submit ile kapı geçilir: kapı sonrası ödeme oturumu
/// araması koşar; bilinmeyen session_id → 404.
pub fn parampos_start_csrf_valid_reaches_session_lookup_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let token = public_page_csrf_token(db, "/")
      let resp =
        simulate.browser_request(
          http.Post,
          "/api/public/checkout/parampos/start",
        )
        |> simulate.header("x-forwarded-for", "192.0.2.46")
        |> simulate.cookie("agency_csrf", token, wisp.PlainText)
        |> simulate.form_body([
          #("session_id", "00000000-0000-0000-0000-000000000000"),
          #("csrf_token", token),
        ])
        |> router.handle(db, origin)

      resp.status |> should.equal(404)
    }
  }
}

/// Oturumlu tarayıcıda parampos/start da oturum-türevli token'ı doğrular:
/// doğru oturum türevi kapıyı geçer (→ 404), yanlış oturum türevi 403'tür.
pub fn parampos_start_csrf_session_bound_token_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      // Benzersiz oturum: paylaşılan pref_email hesabına paralel dokunma yok.
      with_unique_session(db, "paramposcsrf", fn(_email, session_token) {
        let attacker_cookie = "attacker-controlled-value"
        let start_with = fn(form_token: String) {
          simulate.browser_request(
            http.Post,
            "/api/public/checkout/parampos/start",
          )
          |> simulate.header("x-forwarded-for", "192.0.2.47")
          |> simulate.cookie("agency_session", session_token, wisp.Signed)
          |> simulate.cookie("agency_csrf", attacker_cookie, wisp.PlainText)
          |> simulate.form_body([
            #("session_id", "00000000-0000-0000-0000-000000000000"),
            #("csrf_token", form_token),
          ])
          |> router.handle(db, origin)
        }

        start_with(csrf.token_for(session_token)).status |> should.equal(404)
        start_with(csrf.token_for("other-session")).status |> should.equal(403)
      })
    }
  }
}

/// Çift sırlı rotasyon penceresi: SECRET_KEY_BASE_PREVIOUS set iken eski sır
/// altında imzalanmış oturum çerezi kabul edilir, istek current-era
/// bağlantıyla işlenir ve yanıt agency_session çerezini yeni sır ile yeniden
/// damgalar — kullanıcı zorunlu çıkışa düşmez. Pencere kapalıyken eski imza
/// yine reddedilir: pencere kalıcı bir gevşeme değildir.
pub fn secret_rotation_window_migrates_and_restamps_session_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      // Pencereyi env kapsamı içinde aç (kilitli, panik-güvenli geri yükleme;
      // test VM'inde SECRET_KEY_BASE env'i yoktur, simulate sırrıyla hizalanır).
      // 1-3: pencere açıkken göç + yeniden damgalama + dönüş yolculuğu.
      let session_token =
        with_env2(
          "secret_rotation_window",
          [
            #("SECRET_KEY_BASE_PREVIOUS", env_set(rotation_old_secret)),
            #("SECRET_KEY_BASE", env_set(simulate.default_secret_key_base)),
          ],
          fn() { rotation_window_body(db) },
        )

      // 4) Pencere kapalıyken eski imza yeniden reddedilir: pencere kalıcı
      //    bir gevşeme değildir. with_env2 döndüğünde iki env de eski değerine
      //    döner; bu adım ancak o zaman anlamlıdır, bu yüzden kapanışın
      //    DIŞINDA koşar.
      old_browser_for(session_token)
      |> simulate.form_body(
        list.append(inquiry_form(), [
          #("csrf_token", csrf.token_for(session_token)),
        ]),
      )
      |> router.handle(db, origin)
      |> should_status(403)

      auth.logout(db, session_token)
    }
  }
}

/// Eski dönem tarayıcısı: çerez eski sır ile imzalanır, sonra bağlantı
/// sunucunun current sırrına (simulate varsayılanı) döner — rotasyon
/// sonrası sunucu durumunun karşılığı. Saf kurulum: her çağrıda aynı
/// isteği üretir (4. adım kapsam dışında yeniden kurar).
fn old_browser_for(session_token: String) {
  simulate.browser_request(http.Post, "/iletisim")
  |> simulate.header("x-forwarded-for", "192.0.2.34")
  |> wisp.set_secret_key_base(rotation_old_secret)
  |> simulate.cookie("agency_session", session_token, wisp.Signed)
  |> wisp.set_secret_key_base(simulate.default_secret_key_base)
  |> simulate.cookie("agency_csrf", "attacker-controlled-value", wisp.PlainText)
}

/// Pencere açıkken 1-3. adımları koşar ve oturum jetonunu döndürür. 4. adım
/// (pencere kapalıyken reddi) kapsam kapandıktan sonra test gövdesinde koşar.
fn rotation_window_body(db: pog.Connection) -> String {
  let session_token = wisp.random_string(48)
  auth.login(db, pref_email, "admin123456", session_token)
  |> should.be_ok

  let old_browser = old_browser_for(session_token)

  // 1) Pencere açıkken eski imza kabul edilir → 303.
  let migrated_response =
    old_browser
    |> simulate.form_body(
      list.append(inquiry_form(), [
        #("csrf_token", csrf.token_for(session_token)),
      ]),
    )
    |> router.handle(db, origin)
  migrated_response |> should_status(303)

  // 2) Yanıt, current sır ile yeniden damgalanmış agency_session taşımalı.
  //    Damga, current-era sırrı (simulate.default_secret_key_base) ile
  //    doğrulanabilmeli — eski sır ile değil.
  let stamped =
    get_headers(migrated_response, "set-cookie")
    |> list.find(fn(value) {
      string.contains(value, "agency_session=")
      && !string.contains(value, "Max-Age=0")
    })
  let assert Ok(stamp_line) = stamped
  let assert Ok(#(_, stamp_value)) =
    string.split_once(stamp_line, "agency_session=")
  let assert Ok(#(wire_value, _attrs)) = string.split_once(stamp_value, ";")
  let current_verify =
    wisp.get_cookie(
      simulate.browser_request(http.Get, "/")
        |> wisp.set_secret_key_base(simulate.default_secret_key_base)
        |> simulate.header("cookie", "agency_session=" <> wire_value),
      "agency_session",
      wisp.Signed,
    )
  current_verify |> should.equal(Ok(session_token))

  // 3) Dönüş yolculuğu: tarayıcı yeni damgayı alır, bir sonraki istek
  //    current sır altında imzalanmış çerez taşır → pencere olmadan da 303.
  old_browser
  |> simulate.header("cookie", "agency_session=" <> wire_value)
  |> simulate.form_body(
    list.append(inquiry_form(), [
      #("csrf_token", csrf.token_for(session_token)),
    ]),
  )
  |> router.handle(db, origin)
  |> should_status(303)

  session_token
}

const csp_test_report = "{\"csp-report\":{\"document-uri\":\"http://localhost:8082/\",\"violated-directive\":\"script-src-elem\",\"blocked-uri\":\"https://evil.example/x.js\"}}"

/// application/csp-report gövdesi kabul edilir ve security_events tablosuna
/// info/observed olayı olarak düşer.
pub fn csp_report_endpoint_stores_violation_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let request_marker = "req-csp-test-" <> wisp.random_string(16)
      let resp =
        simulate.browser_request(http.Post, "/api/csp-report")
        |> simulate.header("x-request-id", request_marker)
        |> simulate.header("x-forwarded-for", "192.0.2.21")
        |> simulate.string_body(csp_test_report)
        |> simulate.header("content-type", "application/csp-report")
        |> router.handle(db, origin)

      resp.status |> should.equal(204)

      // Olay gerçekten kaydedildi mi?
      let count =
        "select count(*)::int from agency.security_events where request_id = $1 and event_type = 'csp_violation' and route = 'csp-report' and severity = 'info' and decision = 'observed'"
        |> pog.query()
        |> pog.parameter(pog.text(request_marker))
        |> pog.returning(decode.field(0, decode.int, decode.success))
        |> pog.execute(db)
      let assert Ok(rows) = count
      let assert Ok(1) = list.first(rows.rows)

      // Temizlik.
      "delete from agency.security_events where request_id = $1"
      |> pog.query()
      |> pog.parameter(pog.text(request_marker))
      |> pog.execute(db)
      |> fn(_) { Nil }
    }
  }
}

/// Yanlış içerik tipi 415 — boş ham gövdeyi JSON sanan suistimallere kapı yok.
pub fn csp_report_endpoint_rejects_wrong_content_type_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let resp =
        simulate.browser_request(http.Post, "/api/csp-report")
        |> simulate.header("x-forwarded-for", "192.0.2.22")
        |> simulate.form_body([#("csp-report", "junk")])
        |> router.handle(db, origin)

      resp.status |> should.equal(415)
    }
  }
}

/// 16 KB üstü gövde 413 — kayıt öncesi kesilir.
pub fn csp_report_endpoint_rejects_oversized_body_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let big = string.repeat("x", 17_000)
      let resp =
        simulate.browser_request(http.Post, "/api/csp-report")
        |> simulate.header("x-forwarded-for", "192.0.2.23")
        |> simulate.string_body(big)
        |> simulate.header("content-type", "application/csp-report")
        |> router.handle(db, origin)

      resp.status |> should.equal(413)
    }
  }
}

/// CSP_REPORT_ONLY=true iken sıkılaştırılmış politika report-only başlığıyla
/// gider, enforcing başlık hiç gelmez; kip kapalıyken tersi geçerlidir.
pub fn csp_report_only_header_switch_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      with_env2(
        "csp_report_only",
        [#("CSP_REPORT_ONLY", env_set("true"))],
        fn() { csp_report_only_body(db) },
      )
    }
  }
}

fn csp_report_only_body(db: pog.Connection) -> Nil {
  let ro =
    simulate.browser_request(http.Get, "/health")
    |> simulate.header("x-forwarded-for", "192.0.2.24")
    |> router.handle(db, origin)
  header(ro, "content-security-policy-report-only")
  |> should.equal(Ok(
    "default-src 'self'; img-src 'self' data: https:; media-src 'self' data: https: blob:; style-src 'self' 'unsafe-inline' https://use.hugeicons.com https://embed.tawk.to; script-src 'self' 'unsafe-inline' https://embed.tawk.to; font-src 'self' data: https://use.hugeicons.com; connect-src 'self' https:; frame-src https://www.openstreetmap.org https://embed.tawk.to; frame-ancestors 'self'; base-uri 'self'; form-action 'self' https://www.param.com.tr https://testposws.param.com.tr; object-src 'none'",
  ))
  header(ro, "content-security-policy") |> should.equal(Error(Nil))

  // with_env2 kapsamı biterken CSP_REPORT_ONLY eski değerine döner; enforcing
  // dalı kapsam DIŞINDA ölçülür (env herkese görünür durumda olmalı).
  Nil
}

/// Kip kapalıyken (env unset) enforcing başlığı gelir, report-only gelmez.
pub fn csp_enforcing_header_when_mode_disabled_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      with_env2("csp_report_only", [#("CSP_REPORT_ONLY", env_unset())], fn() {
        csp_enforcing_body(db)
      })
    }
  }
}

fn csp_enforcing_body(db: pog.Connection) -> Nil {
  let enforcing =
    simulate.browser_request(http.Get, "/health")
    |> simulate.header("x-forwarded-for", "192.0.2.25")
    |> router.handle(db, origin)
  header(enforcing, "content-security-policy")
  |> result.is_ok
  |> should.be_true
  header(enforcing, "content-security-policy-report-only")
  |> should.equal(Error(Nil))
}

/// CSRF token olmadan gelen POST reddedilmeli ve hesap değişmemeli.
pub fn currency_preference_requires_csrf_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      with_unique_session(db, "currencyneeds", fn(email, session_token) {
        reset_currency_pref(db, email)

        let resp =
          simulate.browser_request(
            http.Post,
            "/admin/preferences/currency?currency=USD",
          )
          |> simulate.cookie("agency_session", session_token, wisp.Signed)
          |> simulate.form_body([#("other", "value")])
          |> router.handle(db, origin)

        resp.status |> should.equal(403)
        account_currency_pref(db, email) |> should.equal("")
      })
    }
  }
}

/// Yanlış CSRF token'ı da reddedilmeli (fail-closed).
pub fn currency_preference_rejects_wrong_csrf_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      with_unique_session(db, "currencywrong", fn(email, session_token) {
        reset_currency_pref(db, email)

        let resp =
          simulate.browser_request(
            http.Post,
            "/admin/preferences/currency?currency=GBP",
          )
          |> simulate.cookie("agency_session", session_token, wisp.Signed)
          |> simulate.form_body([#("csrf", "not-a-valid-token")])
          |> router.handle(db, origin)

        resp.status |> should.equal(403)
        account_currency_pref(db, email) |> should.equal("")
      })
    }
  }
}

// ---------------------------------------------------------------------------
// SSR yerelleştirme (nexus_lang çerezi) — mağaza sayfaları sunucuda çevrilir.
// ---------------------------------------------------------------------------

/// Kelime sınırı kuralı: tablo anahtarı ancak bağımsız kelime olarak
/// eşleştiğinde çevrilir, uzun bir kelimenin İÇİNDE eşleşmez.
///
/// Bu test kasıtlı olarak tabloda OLMAYAN bir türev kullanır ("Otelcilik"):
/// sınır kuralı olmadan düz `string.replace` "Отельcilik" gibi melez metin
/// üretir. Uzunluk sıralaması bu durumu kurtaramaz — tek savunma sınır
/// kuralıdır, dolayısıyla test doğrudan o mekanizmayı ölçer.
pub fn translate_text_respects_word_boundaries_test() {
  // Tam kelime çevrilir
  router.translate_text("Aktivite", "ru") |> should.equal("Активность")
  router.translate_text("Otel", "de") |> should.equal("Hotel")
  // Uzun anahtar kısa olandan önce uygulanır
  router.translate_text("Aktiviteler", "ru") |> should.equal("Активности")
  router.translate_text("Turlar", "ru") |> should.equal("Туры")
  // Tabloda olmayan türev DEĞİŞMEDEN kalır (melez metin yok)
  router.translate_text("Otelcilik", "ru") |> should.equal("Otelcilik")
  router.translate_text("Uçuşlarımla", "de") |> should.equal("Uçuşlarımla")
  // Ayraçla biten/başlayan anahtarlar hâlâ çevrilir
  router.translate_text("₺ 2500 / gece", "ru")
  |> should.equal("₺ 2500 / ночь")
  // Desteklenmeyen dil metni değiştirmez
  router.translate_text("Aktivite", "tr") |> should.equal("Aktivite")
}

/// nexus_lang=ru ile liste sayfası Rusça render edilmeli ve çeviri kelime
/// sınırına saygılı olmalı: "Aktivite" anahtarı "Aktiviteler" kelimesinin
/// içinde eşleşip "Активностьler" gibi melez metin üretmemeli.
pub fn ssr_localized_listing_page_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      // SSR yerelleştirme uygulamanın handle_localized sarmalayıcısında;
      // router.handle doğrudan çağrılırsa çeviri uygulanmaz.
      let ru =
        simulate.browser_request(http.Get, "/urunler?kategori=tour")
        |> simulate.header("cookie", "nexus_lang=ru")
        |> router.handle_localized(db, origin)
      ru.status |> should.equal(200)
      let ru_body = simulate.read_body(ru)
      // Kategori etiketleri tam çevrilmeli
      ru_body |> string.contains("Активности") |> should.be_true
      ru_body |> string.contains("Туры") |> should.be_true
      // Kısmi kelime eşleşmesinden doğan melez metin OLMAMALI
      ru_body |> string.contains("Активностьler") |> should.be_false
      // html lang hedef dile yükseltilmeli
      ru_body |> string.contains("<html lang=\"ru\">") |> should.be_true

      // Çerezsiz kontrol: Türkçe gövde değişmemeli.
      let tr =
        simulate.browser_request(http.Get, "/urunler?kategori=tour")
        |> router.handle_localized(db, origin)
      let tr_body = simulate.read_body(tr)
      tr_body |> string.contains("Aktiviteler") |> should.be_true
      tr_body |> string.contains("Активности") |> should.be_false
    }
  }
}

/// Sınır kuralı: kısa anahtar uzun kelimenin içinde eşleşmemeli, ama
/// bağımsız kelime olarak eşleşmeye devam etmeli.
///
/// Kanıt: filtre panelindeki `<option value="tour">Tur</option>` tam
/// çevrilmeli (Тур), buna karşın "Turlar" kelimesinden melez metin
/// (Турlar / Турlar) doğmamalı.
pub fn ssr_translation_respects_word_boundaries_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let de =
        simulate.browser_request(http.Get, "/urunler?kategori=tour")
        |> simulate.header("cookie", "nexus_lang=de")
        |> router.handle_localized(db, origin)
      let de_body = simulate.read_body(de)
      de_body |> string.contains("Aktivitäten") |> should.be_true
      de_body |> string.contains("Aktivitätler") |> should.be_false

      let ru =
        simulate.browser_request(http.Get, "/urunler?kategori=tour")
        |> simulate.header("cookie", "nexus_lang=ru")
        |> router.handle_localized(db, origin)
      let ru_body = simulate.read_body(ru)
      // Bağımsız "Tur" anahtarı tam çevrilir...
      ru_body
      |> string.contains("<option value=\"tour\">Тур</option>")
      |> should.be_true
      // ...ama "Turlar" kelimesinin içinde eşleşip melez metin üretmez.
      ru_body |> string.contains("Турlar") |> should.be_false
    }
  }
}

/// Başarılı giriş, kayıtlı tercihi JS-okunur nexus_currency çerezine damgalar.
pub fn login_stamps_currency_cookie_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      with_unique_session(db, "currencystamp", fn(email, _session_token) {
        // Hesaba tercihi doğrudan yaz, sonra giriş yap.
        "update agency.users set currency_pref=$1 where lower(email)=lower($2)"
        |> pog.query()
        |> pog.parameter(pog.text("SAR"))
        |> pog.parameter(pog.text(email))
        |> pog.execute(db)
        |> fn(_) { Nil }

        let resp =
          simulate.browser_request(http.Post, "/login")
          |> simulate.form_body([
            #("email", email),
            #("password", "admin123456"),
          ])
          |> router.handle(db, origin)

        resp.status |> should.equal(303)
        let currency_cookie =
          list.filter_map(get_headers(resp, "set-cookie"), fn(value) {
            case string.contains(value, "nexus_currency=SAR") {
              True -> Ok(value)
              False -> Error(Nil)
            }
          })
        currency_cookie |> should.not_equal([])
        // Çerez JS tarafından okunabilmeli (HttpOnly OLMAMALI).
        let assert Ok(value) = list.first(currency_cookie)
        value |> string.contains("HttpOnly") |> should.be_false
      })
    }
  }
}
