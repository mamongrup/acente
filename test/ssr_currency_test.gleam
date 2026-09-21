//// Sunucu tarafı (SSR) para birimi dönüşümü — sözleşme denetimi.
////
//// Seçilen para birimi (`nexus_currency` çerezi) sunucuda uygulanır:
//// kurtarılan Erlang router fiyatları ilanın kendi para biriminde (TRY)
//// basar; Gleam geçişi (`ssr_currency`) HTML gövdesindeki fiyat metinlerini
//// ve JSON-LD offer bloğunu hedef para birimine çevirir. İstemci katmanı
//// (main.js FX) aynı seçimi sayfa yenilemeden uygular.
////
//// Sabitlenen sözleşmeler:
////   A) Biçim kuralı iki katmanda BİREBİR aynı: 1000+ tam sayıya yuvarlanır
////      (ondalık yok), altında iki ondalık; binlik `,`, ondalık `.`.
////   B) Kanonik tutar `data-price-minor` (yalnız rakam) olarak basılır —
////      sunucu metni çevirdiği için istemci metinden okursa çift dönüşüm
////      olurdu; öznitelik bu yüzden metin taramasından etkilenmez.
////   C) `data-price-cur` TRY dışıysa ilan o para biriminde fiyatlanmıştır:
////      ne sunucu ne istemci dönüştürür.
////   D) Kapsam fiyat gösteren mağaza sayfalarıdır; `/odeme/parampos`
////      (gerçek TRY tahsilatı) bilinçli olarak dışarıdadır.
////   E) Simge tablosu Gleam ↔ JS arasında drift etmez; bozuk/boş DB simgesi
////      (`?`) iki tarafta da yedek tabloya düşer.
////
//// Beklenen biçim metinleri gerçek JS motorunda (main.js FX.format) hesaplanıp
//// buraya sabitlendi — test iki katmanın ayrışmasını yakalar.

import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import nexus_agency/ssr_currency
import simplifile

const main_js_path = "priv/static/chisfis/js/main.js"
const router_path = "src/nexus_agency/router.gleam"
const erl_path = "src/nexus_agency/erl/nexus_agency@router_impl.erl"

/// USD kuru (canlı `agency.currencies`): 1 USD = 48.6992 TRY.
const usd_rate = 48.6992

fn read(path: String) -> String {
  simplifile.read(path) |> result.unwrap("")
}

fn occurrences(haystack: String, needle: String) -> Int {
  haystack |> string.split(needle) |> list.length |> int.subtract(1)
}

/// `start` işaretinden sonra, `end` işaretine kadar olan blok.
fn block_between(src: String, start: String, end: String) -> String {
  src
  |> string.split(start)
  |> list.drop(1)
  |> list.first
  |> result.unwrap("")
  |> string.split(end)
  |> list.first
  |> result.unwrap("")
}

// ---------------------------------------------------------------------------
// A) Biçim sözleşmesi (JS ile birebir)
// ---------------------------------------------------------------------------

pub fn format_contract_test() {
  // #(TRY tutar, beklenen USD metni) — beklenenler tarayıcı motorunda
  // `FX.format(tutar / 48.6992, 'USD')` ile üretildi.
  let cases = [
    #(25000.0, "$ 513.36"),
    #(2500.0, "$ 51.34"),
    #(1500.4, "$ 30.81"),
    #(999.99, "$ 20.53"),
    #(12.5, "$ 0.26"),
    #(0.05, "$ 0.00"),
    #(100000.0, "$ 2,053"),
  ]
  cases
  |> list.each(fn(pair) {
    let #(try_amount, expected) = pair
    let converted = ssr_currency.convert_amount(try_amount, usd_rate)
    ssr_currency.format_money(converted, "$") |> should.equal(expected)
  })
}

pub fn format_edge_cases_test() {
  // Binlik ayraç üçlü gruplar hâlinde
  ssr_currency.format_money(2053.4, "$") |> should.equal("$ 2,053")
  ssr_currency.format_money(1000000.0, "$") |> should.equal("$ 1,000,000")
  // 1000 eşiğinin hemen altı: iki ondalık korunur
  ssr_currency.format_money(999.995, "$") |> should.equal("$ 1,000.00")
  // Simge ayrımı: boşluk + simge önde
  ssr_currency.format_money(12.5, "€") |> should.equal("€ 12.50")
}

pub fn rate_guard_test() {
  // Kur yok/geçersizse tutar değişmez (sessizce büyütüp küçültmez)
  ssr_currency.convert_amount(1000.0, 0.0) |> should.equal(1000.0)
  ssr_currency.convert_amount(1000.0, -1.0) |> should.equal(1000.0)
  ssr_currency.convert_amount(1000.0, 1.0) |> should.equal(1000.0)
}

// ---------------------------------------------------------------------------
// B/C/D) Gövde dönüşümü
// ---------------------------------------------------------------------------

/// Kart + detay + vitrin metni + JSON-LD içeren gerçekçi gövde parçası.
/// Vitrin kartı **gerçek maket** biçimindedir: birim kendi spanında ve
/// kanonik tutar öznitelikte taşınır (ana sayfa demo kartları böyle basılır).
fn fixture() -> String {
  "<div class=\"card-price\"><strong data-price-minor=\"2500000\" data-price-cur=\"TRY\">₺ 25000.00</strong><span class=\"card-price-unit\">/gece</span></div>"
  <> "<div class=\"flex items-end text-2xl font-semibold sm:text-3xl\" data-price-minor=\"2500000\" data-price-cur=\"TRY\">₺ 25000.00<span> / gece</span></div>"
  <> "<span class=\"featured-card-price\" data-price-minor=\"280000\" data-price-cur=\"TRY\">₺2.800<span class=\"featured-card-price-unit\">/gece</span></span>"
  // JSON-LD'de tutar Erlang'ın kısa float biçimiyle gelir: 25000.0 → `2.5e4`
  <> "<script type=\"application/ld+json\">{\"priceCurrency\":\"TRY\",\"price\":2.5e4}</script>"
}

pub fn body_conversion_test() {
  let converted = ssr_currency.convert_prices(fixture(), usd_rate, "USD", "$")

  // Fiyat metinleri hedef para biriminde
  occurrences(converted, "$ 513.36") |> should.equal(2)
  // TRY gösterimi kalmadı
  string.contains(converted, "₺ ") |> should.equal(False)
  // Kanonik tutar öznitelikleri bozulmadı (metin taraması bunlara dokunmaz)
  occurrences(converted, "data-price-minor=\"2500000\"") |> should.equal(2)
  occurrences(converted, "data-price-minor=\"280000\"") |> should.equal(1)
  occurrences(converted, "data-price-cur=\"TRY\"") |> should.equal(3)
  // Boşluksuz şablon metni (vitrin kartı) da dönüşür: `₺2.800` → `$57.50`
  string.contains(converted, "₺2.800") |> should.equal(False)
  string.contains(converted, ">$57.50<span class=\"featured-card-price-unit\">") 
  |> should.equal(True)
  // JSON-LD offer bloğu görünür fiyatla tutarlı
  string.contains(converted, "{\"priceCurrency\":\"USD\",\"price\":513.36}") |> should.equal(True)
  // Birim etiketi korunur
  string.contains(converted, "/gece") |> should.equal(True)
}

/// Vitrin/demo kartı geçişi (ana sayfa `featured-card-price`).
/// Bu biçim Türkçe binlik grubu taşır ve **kesirli kısmı yoktur**
/// (`₺2.800`). `float.parse` nokta içermeyen dizeyi reddettiği için
/// normalizasyon `.0` eklemek zorundadır — eklenmezse tutar okunamaz ve
/// kart sessizce TRY'de kalır (regresyon).
pub fn featured_conversion_test() {
  // Binlik gruplu, kesirsiz (regresyonun tam kalbi)
  ssr_currency.convert_featured_prices("₺2.800/gece", usd_rate, "$")
  |> should.equal("$57.50/gece")
  // Gruplama eşiğinin altı: nokta hiç yok (`₺850`)
  ssr_currency.convert_featured_prices("₺850/gece", usd_rate, "$")
  |> should.equal("$17.45/gece")
  // Hem binlik hem ondalık ayraç (`₺25.000,50`)
  ssr_currency.convert_featured_prices("₺25.000,50/gece", usd_rate, "$")
  |> should.equal("$513.37/gece")
  // Birim soneki sıkı biçimde tutara bitişik kalır (araya boşluk girmez)
  ssr_currency.convert_featured_prices("₺850/gece", usd_rate, "$")
  |> string.contains("$17.45/gece")
  |> should.equal(True)
}

pub fn featured_idempotence_test() {
  // Geçiş kanonik boşluklu biçime dokunmaz ("₺ " boşlukla başlar)
  ssr_currency.convert_featured_prices("₺ 25000.00", usd_rate, "$")
  |> should.equal("₺ 25000.00")
  // Simge var ama tutar yok: metin bozulmaz
  ssr_currency.convert_featured_prices("₺ simge", usd_rate, "$")
  |> should.equal("₺ simge")
  // İkinci geçiş sonucu tekrar dönüştürmez (çift dönüşüm yok): çıktı
  // artık `₺` içermez.
  let once = ssr_currency.convert_featured_prices("₺2.800/gece", usd_rate, "$")
  ssr_currency.convert_featured_prices(once, usd_rate, "$")
  |> should.equal(once)
}

pub fn json_ld_exponent_test() {
  // Üs gösterimi okunmazsa tutar yanlış hesaplanır (0.05e4 gibi): sunucu
  // gerçekte `2.5e4` basıyor, dönüşüm tam sayıyı görmeli.
  ssr_currency.convert_prices(
    "{\"priceCurrency\":\"TRY\",\"price\":2.5e4}",
    usd_rate,
    "USD",
    "$",
  )
  |> should.equal("{\"priceCurrency\":\"USD\",\"price\":513.36}")
  // Üs kısmı ayrıştırılamayan biçimdeyse metin bozulmaz
  ssr_currency.convert_prices(
    "{\"priceCurrency\":\"TRY\",\"price\":e4}",
    usd_rate,
    "USD",
    "$",
  )
  |> should.equal("{\"priceCurrency\":\"TRY\",\"price\":e4}")
}

pub fn body_no_match_test() {
  // Tutar okunamıyorsa metin aynen kalır (sessiz bozulma yok)
  ssr_currency.convert_prices("₺ simge burada", usd_rate, "USD", "$")
  |> should.equal("₺ simge burada")
  // Fiyat içermeyen gövde değişmez
  ssr_currency.convert_prices("<p>Merhaba</p>", usd_rate, "USD", "$")
  |> should.equal("<p>Merhaba</p>")
}

pub fn symbol_fallback_test() {
  // Veritabanı boş/yer tutucu simge verirse (canlı veride SAR '?' idi)
  ssr_currency.display_symbol("SAR", "?" ) |> should.equal("﷼")
  ssr_currency.display_symbol("SAR", "") |> should.equal("﷼")
  ssr_currency.display_symbol("USD", " ") |> should.equal("$")
  // Geçerli simge aynen kullanılır
  ssr_currency.display_symbol("EUR", "€") |> should.equal("€")
}

// ---------------------------------------------------------------------------
// Statik kapılar
// ---------------------------------------------------------------------------

pub fn erl_emits_canonical_amount_test() {
  let src = read(erl_path)
  // Dört fiyat noktası: ürün kartı, detay büyük fiyat, rezervasyon kartı,
  // ana sayfa vitrin/demo kartı (`featured-card-price`).
  occurrences(src, "data-price-minor") |> should.equal(4)
  occurrences(src, "data-price-cur") |> should.equal(4)
  // Kanonik tutar Price / Price_minor'dan gelir (metinden ayrıştırılmaz)
  string.contains(src, "lustre@attribute:attribute(~\"data-price-minor\", erlang:integer_to_binary(Price))")
  |> should.equal(True)
  string.contains(src, "lustre@attribute:attribute(~\"data-price-minor\", Price_minor)")
  |> should.equal(True)
  // Vitrin kartı: birim kendi spanında, fiyat metni ayrı düğümde — istemci
  // yalnız metin düğümünü değiştirip `/gece` spanını koruyabilir.
  string.contains(src, "lustre@element:element(~\"span\", [lustre@attribute:class(~\"featured-card-price-unit\")")
  |> should.equal(True)
}

pub fn router_scope_test() {
  let src = read(router_path)
  let route = block_between(src, "fn ssr_price_route", "\nfn ")
  // Ana sayfa (kök yol) kapsamda: vitrin/demo kartları fiyat basar
  route |> string.contains("[] -> True") |> should.equal(True)
  // Fiyat gösteren mağaza sayfaları kapsamda
  route |> string.contains("[\"urunler\"]") |> should.equal(True)
  route |> string.contains("[\"urunler\", _]") |> should.equal(True)
  route |> string.contains("[\"kategori\", _]") |> should.equal(True)
  route |> string.contains("[\"rezervasyon\"]") |> should.equal(True)
  // Gerçek TRY tahsilatı gösteren ödeme sayfası kapsam DIŞI
  route |> string.contains("parampos") |> should.equal(False)
  // Yalnız GET yanıtları
  route |> string.contains("http.Get") |> should.equal(True)
}

pub fn router_wiring_test() {
  let src = read(router_path)
  // Çerez adı ve TRY dışı kapısı
  src |> string.contains("ssr_cookie(req, \"nexus_currency\")") |> should.equal(True)
  src |> string.contains("Ok(code) if code != \"TRY\"") |> should.equal(True)
  // Kur kaynağı: aktif para birimleri tablosu
  src |> string.contains("from agency.currencies where active") |> should.equal(True)
  // Önbellek: TTL sabiti + kalıcı terim
  src |> string.contains("ssr_rate_cache_ttl_ms") |> should.equal(True)
  src |> string.contains("persistent_term") |> should.equal(True)
  // Önbellek anahtarı para birimine göre ayrışır (TRY sorgusu yapılmaz)
  src |> string.contains("dict.insert(cache, code,") |> should.equal(True)

  // handle_localized: tek handle çağrısı, önce çeviri sonra fiyat geçişi
  let wrapper = block_between(src, "pub fn handle_localized", "\n// ---")
  occurrences(wrapper, "handle(req, db, origin)") |> should.equal(1)
  let translate_at = string.split(wrapper, "ssr_translate_response") |> list.length
  let currency_at = string.split(wrapper, "ssr_currency_response") |> list.length
  // İkisi de çağrılıyor ve fiyat geçişi çeviri geçişinden SONRA kuruluyor
  translate_at |> should.equal(2)
  currency_at |> should.equal(2)
  // Çeviri çağrısından SONRAKİ gövde parçası fiyat geçişini içermeli
  wrapper
  |> string.split("ssr_translate_response")
  |> list.drop(1)
  |> list.first
  |> result.unwrap("")
  |> string.contains("ssr_currency_response")
  |> should.equal(True)
}

pub fn client_consumes_canonical_amount_test() {
  let src = read(main_js_path)
  src |> string.contains("el.getAttribute('data-price-minor')") |> should.equal(True)
  src |> string.contains("el.getAttribute('data-price-cur')") |> should.equal(True)
  // Kanonik tutar varsa metinden okunmaz (çift dönüşüm koruması)
  src |> string.contains("return { amount: m / 100, minor: true }") |> should.equal(True)
  // TRY'ye dönüşte sunucunun biçimi geri yazılır
  src |> string.contains("formatTry: function") |> should.equal(True)
  src |> string.contains("'₺ ' + value.toFixed(2)") |> should.equal(True)
  // Bozuk DB simgesi yedeğe düşer
  src |> string.contains("dbSym !== '?'") |> should.equal(True)
}

// ---------------------------------------------------------------------------
// Ana sayfa vitrin (demo) kartları — kanonik tutar ↔ basılan TRY metni
// ---------------------------------------------------------------------------
//
// Demo kartların fiyatı iki yerde duruyor: görünen metin (`~"₺2.800"`) ve
// kanonik kuruş tutarı (`~"280000"`). İstemci dönüşümü kanonik tutarı
// kullandığı için ikisi ayrı düşerse kart TRY'de bir sayı, USD'de başka bir
// sayı gösterir — sessiz bir tutarsızlık. Bu kapı ikisini eşit tutar.

/// `~"..."` literal'lerini kaynak sırasıyla toplar.
fn literals(chunk: String) -> List(String) {
  chunk
  |> string.split("~\"")
  |> list.drop(1)
  |> list.map(fn(part) {
    part |> string.split("\"") |> list.first |> result.unwrap("")
  })
}

/// Vitrin kartı maketindeki fiyat çiftini (`Price`, `Minor`) verir.
/// Yalnız çağrı yerleri sayılır; tanım ve `-spec` başlığında literal yok.
fn featured_demo_prices(src: String) -> List(List(String)) {
  src
  |> string.split("public_featured_card(")
  |> list.drop(1)
  |> list.map(fn(chunk) {
    chunk |> string.split(")") |> list.first |> result.unwrap("") |> literals
  })
  |> list.filter(fn(items) { list.length(items) >= 7 })
}

/// Binlik ayraç `.` (TR vitrin biçimi).
fn group_tr(digits: String) -> String {
  let size = string.length(digits)
  case size <= 3 {
    True -> digits
    False ->
      group_tr(string.slice(digits, 0, size - 3))
      <> "."
      <> string.slice(digits, size - 3, 3)
  }
}

/// Kuruş tutarının TRY vitrin gösterimi (`280000` → `₺2.800`).
/// `ssr_currency.format_featured` ile aynı kural: simge bitişik.
fn try_compact(minor: Int) -> String {
  let lira = int.divide(minor, 100) |> result.unwrap(0)
  let cents = int.modulo(minor, 100) |> result.unwrap(0)
  "₺"
  <> group_tr(int.to_string(lira))
  <> case cents {
    0 -> ""
    value if value < 10 -> ",0" <> int.to_string(value)
    value -> "," <> int.to_string(value)
  }
}

pub fn featured_demo_price_parity_test() {
  let cards = featured_demo_prices(read(erl_path))
  // Ana sayfadaki dört demo vitrin kartı da kanonik tutar taşımalı
  list.length(cards) |> should.equal(4)
  cards
  |> list.each(fn(items) {
    let price = items |> list.drop(5) |> list.first |> result.unwrap("")
    let minor = items |> list.drop(6) |> list.first |> result.unwrap("")
    minor
    |> int.parse
    |> result.map(try_compact)
    |> should.equal(Ok(price))
  })
}

pub fn symbol_table_parity_test() {
  // Gleam yedek tablosu, main.js FX.symbols ile aynı olmalı (drift bekçisi)
  let pairs = [
    #("TRY", "₺"),
    #("USD", "$"),
    #("EUR", "€"),
    #("GBP", "£"),
    #("SAR", "﷼"),
  ]
  let src = read(main_js_path)
  let symbols_line =
    src
    |> string.split("symbols: {")
    |> list.drop(1)
    |> list.first
    |> result.unwrap("")
    |> string.split("},")
    |> list.first
    |> result.unwrap("")
  pairs
  |> list.each(fn(pair) {
    let #(code, symbol) = pair
    ssr_currency.fallback_symbol(code) |> should.equal(symbol)
    symbols_line
    |> string.contains(code <> ": '" <> symbol <> "'")
    |> should.equal(True)
  })
  // NEXUS_LOCALE.currencies listesi de aynı simgeleri taşır
  pairs
  |> list.each(fn(pair) {
    let #(code, symbol) = pair
    read(main_js_path)
    |> string.contains("{ code: '" <> code <> "', symbol: '" <> symbol <> "' }")
    |> should.equal(True)
  })
}
