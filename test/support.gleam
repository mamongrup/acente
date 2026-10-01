//// Shared parallel-safe test helpers — Gleam bridge to the
//// `agency_test_env` Erlang module (src/nexus_agency/erl/agency_test_env.erl).
////
//// Env tests (SECRET_KEY_BASE*, CSP_REPORT_ONLY) run under a named lock with
//// panic-safe restore; session tests use unique users. This keeps gleeunit's
//// process-global state (OS env + the shared admin account's login counters)
//// from leaking between parallel tests.
////
//// Contract and decision table: docs/testing-parallel-safe-helpers.md
//// (Previously these bindings lived in test/router_test.gleam.)

import nexus_agency/auth
import pog
import wisp

// --- Paralel yürütme yardımcıları (agency_test_env Erlang modülü) ----------
//
// Env testleri (SECRET_KEY_BASE*, CSP_REPORT_ONLY) adlandırılmış kilit +
// panik-güvenli geri yükleme ile koşar; oturum testleri benzersiz kullanıcı
// kullanır. Böylece gleeunit süreç-genel durumu (OS env + paylaşılan admin
// hesabın giriş sayaçları) paralel testler arasında sızmaz.

@external(erlang, "agency_test_env", "with_lock")
pub fn with_lock(name: a, owner: b, body: fn() -> c) -> c

@external(erlang, "agency_test_env", "with_env")
pub fn with_env2(
  name: a,
  updates: List(#(String, EnvUpdate)),
  body: fn() -> c,
) -> c

pub type EnvUpdate {
  EnvSet(String)
  EnvUnset
}

pub fn env_set(value: String) -> EnvUpdate {
  EnvSet(value)
}

pub fn env_unset() -> EnvUpdate {
  EnvUnset
}

/// Test başına benzersiz admin hesabı e-postası (paralel sayaç yarışlarını
/// önler). Hesap real_db fixture'ının upsert'iyle yaratılır; test bunun
/// üzerinde çalışıp oturumu kapatır.
@external(erlang, "agency_test_env", "unique_username")
pub fn unique_username(tag: String) -> String

/// Benzersiz kullanıcı yaratan + oturum açan ve blok sonunda oturumu kapatan
/// yardımcı. Paralel güvenli oturum testlerinin ortak deseni.
pub fn with_unique_session(
  db: pog.Connection,
  tag: String,
  body: fn(String, String) -> a,
) -> a {
  let email = unique_username(tag)
  "insert into agency.users(tenant_id, email, display_name, membership_type, active, password_hash) values ('00000000-0000-0000-0000-000000000001', $1, 'Parallel Test Admin', 'admin', true, crypt('admin123456', gen_salt('bf'))) on conflict (tenant_id, email) do update set active = true, password_hash = excluded.password_hash, failed_login_attempts = 0, locked_until = null"
  |> pog.query()
  |> pog.parameter(pog.text(email))
  |> pog.execute(db)
  |> fn(_) { Nil }
  let session_token = wisp.random_string(48)
  let assert Ok(_) = auth.login(db, email, "admin123456", session_token)
  let result = body(email, session_token)
  auth.logout(db, session_token)
  result
}

/// Test için benzersiz admin hesabı yaratır (paralel güvenli oturum testlerinin
/// ortak deseni): paylaşılan integration-admin hesabının giriş sayaçları ve
/// tercihleri üzerinde paralel yarış olmadan çalışır. Upsert sayesinde önceki
/// koşulardan kalan aynı ada çarpmaz.
pub fn create_unique_admin(db: pog.Connection, email: String) -> Nil {
  "insert into agency.users(tenant_id, email, display_name, membership_type, active, password_hash) values ('00000000-0000-0000-0000-000000000001', $1, 'Parallel Test Admin', 'admin', true, crypt('admin123456', gen_salt('bf'))) on conflict (tenant_id, email) do update set active = true, password_hash = excluded.password_hash, failed_login_attempts = 0, locked_until = null"
  |> pog.query()
  |> pog.parameter(pog.text(email))
  |> pog.execute(db)
  |> fn(_) { Nil }
}
