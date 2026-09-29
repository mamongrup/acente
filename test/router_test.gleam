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
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleeunit/should
import nexus_agency/csrf
import nexus_agency/router
import pog
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
      let _ = simulate.browser_request(http.Get, "/")
        |> router.handle(db, origin)
        |> should_status(200)
      Nil
    }
    Error(_) -> Nil
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
  let pool_name = process.new_name("integration_test_db")
  let config =
    pog.default_config(pool_name)
    |> pog.host(host)
    |> pog.port(port)
    |> pog.database(db_name)
    |> pog.user(user)
    |> pog.password(option.Some(password))
    |> pog.pool_size(2)
  case pog.start(config) {
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
    Error(Nil) -> Nil
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
    Error(Nil) -> Nil
    Ok(db) -> {
      let session_token = wisp.random_string(48)
      auth.login(db, "integration-admin@nexus.local", "admin123456", session_token)
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

/// Customer accounts are valid credentials but never receive the back-office
/// panel. This guards the role boundary added to the shared session middleware.
pub fn customer_role_cannot_access_admin_test() {
  case real_db() {
    Error(Nil) -> Nil
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
    Error(Nil) -> Nil
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
    Error(Nil) -> Nil
    Ok(db) -> {
      let resp =
        simulate.browser_request(http.Post, "/login")
        |> simulate.form_body([
          #("email", "integration-admin@nexus.local"),
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
    Error(Nil) -> Nil
    Ok(db) -> {
      let resp =
        simulate.browser_request(http.Post, "/login")
        |> simulate.form_body([
          #("email", "integration-admin@nexus.local"),
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
    Error(Nil) -> Nil
    Ok(db) -> {
      // 1. Reset the account's failed attempts counter -------------------------
      pog.query(
        "UPDATE agency.users SET failed_login_attempts = 0, locked_until = NULL WHERE lower(email) = lower('integration-admin@nexus.local')",
      )
      |> pog.execute(db)
      |> fn(_) { Nil }

      // 2. Make 5 failed login attempts -----------------------------------------
      let failed_attempt = fn(_) {
        let session_token = wisp.random_string(48)
        auth.login(
          db,
          "integration-admin@nexus.local",
          "wrong-password",
          session_token,
        )
        |> fn(_) { Nil }
      }
      failed_attempt(1)
      failed_attempt(2)
      failed_attempt(3)
      failed_attempt(4)
      failed_attempt(5)

      // 3. The 6th attempt should be rejected as account locked -----------------
      let session_token = wisp.random_string(48)
      let result =
        auth.login(
          db,
          "integration-admin@nexus.local",
          "wrong-password",
          session_token,
        )
      case result {
        Ok(_) -> {
          // Should not succeed - account should be locked
          panic as "Expected account to be locked"
        }
        Error(error_type) -> {
          error_type |> should.equal(auth.AccountLocked)
        }
      }

      // 4. Cleanup: reset the account -------------------------------------------
      pog.query(
        "UPDATE agency.users SET failed_login_attempts = 0, locked_until = NULL WHERE lower(email) = lower('integration-admin@nexus.local')",
      )
      |> pog.execute(db)
      |> fn(_) { Nil }
    }
  }
}

// ---------------------------------------------------------------------------
// Para birimi tercihi (sunucu tarafı) — dil tercihi deseninin birebir testi.
// router facade'deki POST /admin/preferences/currency ucunu ve girişte
// nexus_currency çerez damgasını uçtan uca doğrular.
// ---------------------------------------------------------------------------

const pref_email = "integration-admin@nexus.local"

/// Hesapta kayıtlı para birimi tercihini okur (yok → "").
fn account_currency_pref(db: pog.Connection) -> String {
  case
    "select coalesce(u.currency_pref,'') from agency.users u where lower(u.email)=lower($1) limit 1"
    |> pog.query()
    |> pog.parameter(pog.text(pref_email))
    |> pog.returning(
      decode.field(0, decode.string, fn(cur) { decode.success(cur) }),
    )
    |> pog.execute(db)
  {
    Ok(returned) -> list.first(returned.rows) |> result.unwrap("")
    Error(_) -> ""
  }
}

fn reset_currency_pref(db: pog.Connection) -> Nil {
  "update agency.users set currency_pref=null where lower(email)=lower($1)"
  |> pog.query()
  |> pog.parameter(pog.text(pref_email))
  |> pog.execute(db)
  |> fn(_) { Nil }
}

/// Geçerli oturum + CSRF token ile gelen POST tercihi hesaba yazmalı (204).
pub fn currency_preference_persisted_to_account_test() {
  case real_db() {
    Error(Nil) -> Nil
    Ok(db) -> {
      let session_token = wisp.random_string(48)
      auth.login(db, pref_email, "admin123456", session_token) |> should.be_ok
      reset_currency_pref(db)

      let resp =
        simulate.browser_request(
          http.Post,
          "/admin/preferences/currency?currency=EUR",
        )
        |> simulate.cookie("agency_session", session_token, wisp.Signed)
        |> simulate.form_body([#("csrf", csrf.token_for(session_token))])
        |> router.handle(db, origin)

      resp.status |> should.equal(204)
      account_currency_pref(db) |> should.equal("EUR")

      // Temizlik: tercihi ve oturumu sıfırla.
      reset_currency_pref(db)
      auth.logout(db, session_token)
    }
  }
}

/// CSRF token olmadan gelen POST reddedilmeli ve hesap değişmemeli.
pub fn currency_preference_requires_csrf_test() {
  case real_db() {
    Error(Nil) -> Nil
    Ok(db) -> {
      let session_token = wisp.random_string(48)
      auth.login(db, pref_email, "admin123456", session_token) |> should.be_ok
      reset_currency_pref(db)

      let resp =
        simulate.browser_request(
          http.Post,
          "/admin/preferences/currency?currency=USD",
        )
        |> simulate.cookie("agency_session", session_token, wisp.Signed)
        |> simulate.form_body([#("other", "value")])
        |> router.handle(db, origin)

      resp.status |> should.equal(403)
      account_currency_pref(db) |> should.equal("")

      auth.logout(db, session_token)
    }
  }
}

/// Yanlış CSRF token'ı da reddedilmeli (fail-closed).
pub fn currency_preference_rejects_wrong_csrf_test() {
  case real_db() {
    Error(Nil) -> Nil
    Ok(db) -> {
      let session_token = wisp.random_string(48)
      auth.login(db, pref_email, "admin123456", session_token) |> should.be_ok
      reset_currency_pref(db)

      let resp =
        simulate.browser_request(
          http.Post,
          "/admin/preferences/currency?currency=GBP",
        )
        |> simulate.cookie("agency_session", session_token, wisp.Signed)
        |> simulate.form_body([#("csrf", "not-a-valid-token")])
        |> router.handle(db, origin)

      resp.status |> should.equal(403)
      account_currency_pref(db) |> should.equal("")

      auth.logout(db, session_token)
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
    Error(Nil) -> Nil
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
    Error(Nil) -> Nil
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
    Error(Nil) -> Nil
    Ok(db) -> {
      // Hesaba tercihi doğrudan yaz, sonra giriş yap.
      "update agency.users set currency_pref=$1 where lower(email)=lower($2)"
      |> pog.query()
      |> pog.parameter(pog.text("SAR"))
      |> pog.parameter(pog.text(pref_email))
      |> pog.execute(db)
      |> fn(_) { Nil }

      let resp =
        simulate.browser_request(http.Post, "/login")
        |> simulate.form_body([
          #("email", pref_email),
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

      reset_currency_pref(db)
    }
  }
}
