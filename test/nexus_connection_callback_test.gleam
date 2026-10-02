//// NEXUS "connection approved" geri çağrısı — uçtan uca entegrasyon testi.
////
//// Bu dosya adı `*_test` olduğu için gleeunit onu tarıyordu, ama gövdesi
//// `pub fn main()` idi: gleeunit yalnızca `*_test` **fonksiyonlarını** çalıştırır,
//// dolayısıyla buradaki hiçbir doğrulama `gleam test` sırasında koşmuyordu.
//// Adı "test" olan ama çalışmayan bir dosya, kapsamı varmış gibi görünen bir
//// boşluktur; aşağıdaki testler bu yüzden gerçek `*_test` fonksiyonlarına
//// dönüştürüldü.
////
//// Kapsanan sözleşme:
//// 1. Bekleyen bağlantı isteği yokken geri çağrı 409 döner (çift gönderim).
//// 2. İstek `pending` iken geri çağrı 200 döner ve `{"ok":true}` taşır.
//// 3. Aynı geri çağrı ikinci kez 409 döner.
//// 4. Verilen `api_key` düz metin olarak saklanmaz; yalnız `api_key_sealed`
////    (`v1:` önekli şifreli zarf) yazılır.
//// 5. Onay hem `integration.nexus.connection_approved` denetim kaydına düşer
////    hem de yanıt `x-request-id` başlığı ile denetim kaydı eşleşir.
//// 6. Akış rollback içinde koşar: hiçbir tenant, istek veya anahtar kalıcı değildir.
////
//// Gereksinimler: çalışan acente veritabanı **ve** `NEXUS_API_KEY` (`.env`).
//// Eksikse test sessizce yeşil geçmez — gürültülü panic atar. Sessiz atlama,
//// bu dosyada doğrulanmayan bir sözleşme bırakmak demektir.

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
import wisp
import wisp/simulate

/// Besleme havuzu adı test başına benzersiz olmalı: gleeunit testleri
/// paralel çalıştırır ve aynı isim ikinci `pog.start` çağrısını çakıştırır.
fn real_db() -> pog.Connection {
  let pool_name = process.new_name("nexus_callback_test_db")
  let config =
    pog.default_config(pool_name)
    |> pog.host(envoy.get("PGHOST") |> result.unwrap("127.0.0.1"))
    |> pog.port(
      envoy.get("PGPORT") |> result.try(int.parse) |> result.unwrap(5432),
    )
    |> pog.database(envoy.get("PGDATABASE") |> result.unwrap("nexus_agency"))
    |> pog.user(envoy.get("PGUSER") |> result.unwrap("agency_app"))
    |> pog.password(option.Some(envoy.get("PGPASSWORD") |> result.unwrap("")))
    // Havuz boyutu 1: her test tek bir transaction içinde koşar, dolayısıyla
    // tek bağlantı yeter. Varsayılan havuz boyutu (~10) altı test için ~60
    // eşzamanlı bağlantı demek; gleeunit testleri paralel çalıştırdığı için
    // bu, veritabanının bağlantı sınırını doldurup router_test'in sorgularını
    // zaman aşımına uğratıyordu ("Timeout ... PgoProtocol" hatası).
    |> pog.pool_size(1)
    |> pog.pool_size(2)
  case pog.start(config) {
    Error(_) -> panic as database_required()
    Ok(_) -> {
      let db = pog.named_connection(pool_name)
      // pog.start tembeldir: havuz açılır ama bağlantı kurulmaz. `select 1`
      // gerçekten erişilebilir olduğunu kanıtlar.
      case
        pog.query("select 1")
        |> pog.execute(db)
      {
        Ok(_) -> db
        Error(_) -> panic as database_required()
      }
    }
  }
}

fn database_required() -> String {
  "bu test gercek bir veritabani gerektirir: gleam test oncesinde acente veritabanini baslatin (scripts/run-dev.ps1)"
}

fn callback_key() -> String {
  let key = envoy.get("NEXUS_API_KEY") |> result.unwrap("") |> string.trim
  case key == "" {
    True ->
      panic as "NEXUS_API_KEY must be set: run the flow through scripts/check-nexus-callback-flow.ps1 (loads .env) instead of a bare `gleam test`"
    False -> key
  }
}

fn sql(db: pog.Connection, query: String) -> String {
  let assert Ok(rows) =
    pog.query(query)
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(db)
  let assert Ok(value) = list.first(rows.rows)
  value
}

fn post_callback(
  db: pog.Connection,
  agency_id: String,
  callback_key: String,
  issued_key: String,
) -> wisp.Response {
  simulate.browser_request(http.Post, "/v1/nexus/connection-approved")
  |> simulate.header("authorization", "Bearer " <> callback_key)
  |> simulate.json_body(
    json.object([
      #("agency_id", json.string(agency_id)),
      #("api_key", json.string(issued_key)),
    ]),
  )
  |> router.handle(db, "http://localhost:8082")
}

fn status_of(response: wisp.Response, expected: Int) -> wisp.Response {
  response.status |> should.equal(expected)
  response
}

/// Akışı rollback içinde koşturur ve gerçekten geri alındığını doğrular.
///
/// Fixture tenant, istek ve anahtar kalıcı veri tabanına yazılmaz; test
/// sonunda beklenen hata dönerek `pog` transaction'ı geri alır. Dönmezse
/// fixture kalıcı olur ve test "izole" olma iddiasını yerine getirmez.
///
/// Dönüş tipi serbest bırakıldı: test gövdeleri çoğunlukla bir yanıtla
/// bitiyor ve bunu `Nil`'e zorlamak her teste gereksiz bir `let _ =`
/// eklemek anlamına gelirdi.
fn rolled_back(run: fn(pog.Connection) -> a) {
  let db = real_db()
  let outcome =
    pog.transaction(db, fn(tx) {
      let _ = run(tx)
      Error("verified_rollback")
    })
  case outcome {
    Error(pog.TransactionRolledBack("verified_rollback")) -> Nil
    _ -> panic as "Callback transaction did not roll back"
  }
}

/// Test başına yeni tenant + anahtar; hepsi rollback ile gider.
fn fresh_tenant(db: pog.Connection) -> #(String, String) {
  let tenant =
    sql(
      db,
      "insert into agency.tenants(legal_name,brand_name,slug) values('Callback Test','Callback Test','callback-'||gen_random_uuid()) returning id::text",
    )
  #(tenant, "nx_callback_test_" <> string.slice(tenant, 0, 8))
}

fn open_request(db: pog.Connection, tenant: String) {
  sql(
    db,
    "insert into agency.nexus_connection_requests(tenant_id,status) values('"
      <> tenant
      <> "','pending') returning id::text",
  )
}

// ---------------------------------------------------------------------------
// 1) Çift gönderim: istek yokken ve onaydan sonra 409
// ---------------------------------------------------------------------------

pub fn duplicate_submission_is_rejected_test() {
  rolled_back(fn(db) {
    let key = callback_key()
    let #(tenant, issued) = fresh_tenant(db)
    // Bekleyen istek yok: onaylayacak bir şey bulunmuyor.
    status_of(post_callback(db, tenant, key, issued), 409)
  })
}

pub fn approval_is_accepted_once_then_rejected_test() {
  rolled_back(fn(db) {
    let key = callback_key()
    let #(tenant, issued) = fresh_tenant(db)
    open_request(db, tenant)
    status_of(post_callback(db, tenant, key, issued), 200)
    // Aynı onay ikinci kez gönderilemez.
    status_of(post_callback(db, tenant, key, issued), 409)
  })
}

pub fn approval_body_reports_ok_test() {
  rolled_back(fn(db) {
    let key = callback_key()
    let #(tenant, issued) = fresh_tenant(db)
    open_request(db, tenant)
    let response = status_of(post_callback(db, tenant, key, issued), 200)
    let body = simulate.read_body(response)
    string.contains(body, "\"ok\":true") |> should.be_true()
  })
}

// ---------------------------------------------------------------------------
// 2) Anahtar yalnızca şifreli saklanır
// ---------------------------------------------------------------------------

/// Kullanıcıya verilen anahtar düz metin olarak `credentials` içine
/// yazılmamalı. Şifreleme zarfı `v1:` önekli `api_key_sealed` alanında ve
/// düz `api_key` anahtarı hiç bulunmamalı.
pub fn issued_key_is_sealed_not_plaintext_test() {
  rolled_back(fn(db) {
    let key = callback_key()
    let #(tenant, issued) = fresh_tenant(db)
    open_request(db, tenant)
    status_of(post_callback(db, tenant, key, issued), 200)
    sql(
      db,
      "select count(*)::text from agency.integrations where tenant_id='"
        <> tenant
        <> "' and provider='nexus' and kind='connectivity' and active"
        <> " and coalesce(credentials->>'api_key_sealed','') like 'v1:%'"
        <> " and not (credentials ? 'api_key')",
    )
    |> should.equal("1")
  })
}

// ---------------------------------------------------------------------------
// 3) Denetim kaydı yanıt başlığıyla eşleşir
// ---------------------------------------------------------------------------

/// Onayın iz bırakmaması, yani `integration.nexus.connection_approved`
/// denetim kaydının `x-request-id` ile birebir eşleşmemesi, ihlali
/// sonradan araştırılamaz hale getirir.
pub fn approval_is_audited_with_matching_request_id_test() {
  rolled_back(fn(db) {
    let key = callback_key()
    let #(tenant, issued) = fresh_tenant(db)
    open_request(db, tenant)
    let response = status_of(post_callback(db, tenant, key, issued), 200)
    let assert Ok(request_id) = list.key_find(response.headers, "x-request-id")
    let trimmed = string.trim(request_id)
    // `|>` `>`'den öncelikli: parantez olmadan `length > (0 |> be_true)`
    // olarak ayrışır ve Int, Bool bekleyen fonksiyona gider.
    should.be_true(string.length(trimmed) > 0)
    sql(
      db,
      "select request_id from agency.audit_logs where tenant_id='"
        <> tenant
        <> "' and action='integration.nexus.connection_approved' and request_id='"
        <> trimmed
        <> "'",
    )
    |> should.equal(trimmed)
  })
}

// ---------------------------------------------------------------------------
// Manuel koşu
// ---------------------------------------------------------------------------

/// `scripts/check-nexus-callback-flow.ps1` bu modülü `gleam run -m` ile
/// çağırır ve `.env`'i yükler; düz `gleam test` `.env`'i yüklemediği için
/// `NEXUS_API_KEY` boş kalır ve testler gürültülü panic atar (sessiz atlama
/// değil — sözleşme doğrulanmadan yeşil saymak daha kötü).
///
/// `main` yalnızca *aynı* test gövdelerini çağırır; mantık tek yerde durur,
/// iki giriş noktası birbirinden ayrışamaz. gleeunit yalnızca `*_test`
/// fonksiyonlarını çalıştırdığı için `main` onun için zararsızdır.
pub fn main() {
  duplicate_submission_is_rejected_test()
  approval_is_accepted_once_then_rejected_test()
  approval_body_reports_ok_test()
  issued_key_is_sealed_not_plaintext_test()
  approval_is_audited_with_matching_request_id_test()
  io.println(
    "NEXUS connection callback flow passed (her test rollback ile geri alindi).",
  )
}
