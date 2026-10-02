//// Sunucu tarafı (SSR) para birimi dönüşümü — mağaza fiyat gösterimi.
////
//// Kurtarılan Erlang router fiyatları her zaman **ilanın kendi para biriminde**
//// basar (pratikte TRY, `amount_minor_display` biçimi: iki ondalık, binlik
//// ayraç yok). Bu modül, `nexus_currency` çerezindeki seçime göre gövdeyi
//// sunucuda dönüştürür; böylece ilk boyamada doğru para birimi görünür
//// (JS kapalıyken de) ve istemci katmanı devreye girdiğinde değişiklik olmaz.
////
//// Sözleşmeler:
////   • İki gösterim biçimi de dönüştürülür:
////       1) Uygulamanın kanonik biçimi `₺ 25000.00` (simge + boşluk, gruplama
////          yok, iki ondalık) — ilan kartları, detay, rezervasyon.
////       2) Şablonun vitrin/demo kartı biçimi `₺2.800/gece` (simge ile tutar
////          arasında boşluk YOK, Türkçe gruplama, birim soneki bitişik) —
////          ana sayfadaki `featured-card-price` kartları. Şablonun kendi
////          değeri `$2,380` biçimindedir, bu yüzden dönüşüm de aynı sıkı
////          biçimde yazılır: `simge + tutar + sonek`.
////     Sıkı (boşluksuz) biçim önce işlenir; kanonik boşluklu tutarlara
////     dokunmaz, onları ikinci geçiş çevirir.
////   • Kur: `agency.currencies.rate` = 1 birim yabancı para kaç TRY.
////   • Biçim kuralı main.js'teki istemci katmanıyla (FX.format) **birebir**
////     aynıdır: 1000 ve üzeri tam sayıya yuvarlanır (ondalık yok), altında iki
////     ondalık; binlik ayraç `,`, ondalık ayraç `.` (en-US).
////   • İstemci çift dönüşüm yapmaz: fiyat düğümleri kanonik TRY tutarını
////     `data-price-minor` (yalnız rakam) olarak taşır — bu yüzden buradaki
////     metin taraması o özniteliği bozamaz.
////   • Kapsam `/odeme/parampos` dışındadır: orada gerçek TRY tahsilat tutarı
////     gösterilir, gösterim para birimiyle değiştirilmez.

import gleam/float
import gleam/int
import gleam/list
import gleam/string

/// Fiyat metinlerinin basıldığı işaret (simge + boşluk).
const try_price_marker = "₺ "

/// Vitrin/demo kartı biçiminin işareti: simge, arkasından tutar (boşluk yok).
/// Yalnızca arkasından rakam gelen `₺` sıkı tutar sayılır; `₺ 25000.00`
/// parçaları boşlukla başladığı için bu geçişte değişmeden kalır.
const featured_price_marker = "₺"

/// Sıkı biçimde tutar karakterleri: rakamlar ile Türkçe ayraçlar
/// (`.` binlik, `,` ondalık).
const tr_amount_chars = "0123456789.,"

/// Birim soneki karakterleri (`/gece`, `/gün`, `/kişi`): eğik çizgi + harfler.
const unit_chars = "/abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZçğıöşüÇĞİÖŞÜ"

/// JSON-LD offer bloğundaki fiyat alanı (detay sayfası).
const json_ld_offer_marker = "\"priceCurrency\":\"TRY\",\"price\":"

/// Fiyat metinlerinde tutar karakterleri: yalnız rakam ve ondalık ayraç.
const price_amount_chars = "0123456789."

/// JSON sayı token'ı üs gösterimi taşıyabilir: Erlang'ın kısa float biçimi
/// 25000.0 değerini `2.5e4` olarak basar (geçerli JSON). Üs kısmı
/// okunmazsa dönüşüm yanlış hesaplanır (`0.05e4` gibi).
const json_amount_chars = "0123456789.eE+-"

/// Simge tablosu — main.js `FX.symbols` ve `NEXUS_LOCALE.currencies` ile
/// aynı değerleri taşır (testte drift bekçisi vardır). Veritabanı simgesi
/// boş veya yer tutucu geldiğinde bu tabloya düşülür.
pub fn fallback_symbol(code: String) -> String {
  case string.uppercase(string.trim(code)) {
    "TRY" -> "₺"
    "USD" -> "$"
    "EUR" -> "€"
    "GBP" -> "£"
    "SAR" -> "﷼"
    "RUB" -> "₽"
    "CNY" -> "¥"
    _ -> string.uppercase(string.trim(code))
  }
}

/// Veritabanı simgesi boş veya yer tutucu (`?`) ise yedek simgeye düşer.
/// (SAR kaydı canlı veride `?` ile gelmişti: kullanıcı "? 1,234" görüyordu.)
pub fn display_symbol(code: String, db_symbol: String) -> String {
  case string.trim(db_symbol) {
    "" -> fallback_symbol(code)
    "?" -> fallback_symbol(code)
    symbol -> symbol
  }
}

/// Kur üzerinden TRY tutarını hedef para birimine çevirir.
/// Kur yok/geçersizse (0 veya negatif) tutar değişmeden döner.
pub fn convert_amount(try_amount: Float, rate: Float) -> Float {
  case rate >. 0.0 {
    True -> try_amount /. rate
    False -> try_amount
  }
}

/// Fiyat metni: `simge + " " + tutar` (main.js FX.format ile birebir).
pub fn format_money(value: Float, symbol: String) -> String {
  symbol <> " " <> money_text(value)
}

/// Gövdedeki TRY fiyatlarını ve JSON-LD offer fiyatını hedef para birimine
/// çevirir.
pub fn convert_prices(
  body: String,
  rate: Float,
  code: String,
  symbol: String,
) -> String {
  body
  |> convert_featured_prices(rate, symbol)
  |> rewrite_amounts_after(try_price_marker, price_amount_chars, fn(amount) {
    Ok(format_money(convert_amount(amount, rate), symbol))
  })
  |> rewrite_amounts_after(json_ld_offer_marker, json_amount_chars, fn(amount) {
    Ok(
      "\"priceCurrency\":\""
      <> code
      <> "\",\"price\":"
      <> json_number(convert_amount(amount, rate)),
    )
  })
}

// ---------------------------------------------------------------------------
// Şablon vitrin kartı biçimi (boşluksuz, Türkçe gruplu)
// ---------------------------------------------------------------------------

/// `₺2.800/gece` biçimindeki vitrin kartı fiyatlarını çevirir.
/// Sıkı biçim korunur: `simge + tutar + sonek` arasına boşluk girmez.
/// Tutar okunamayan `₺` işaretleri aynen bırakılır (boşluklu kanonik biçim
/// ikinci geçişte çevrilir).
pub fn convert_featured_prices(
  body: String,
  rate: Float,
  symbol: String,
) -> String {
  case string.split(body, featured_price_marker) {
    [] -> body
    [only] -> only
    [head, ..tail] -> {
      let rewritten =
        tail
        |> list.map(fn(chunk) {
          case leading_tr_amount(chunk) {
            Ok(#(amount, rest)) -> {
              let #(unit, after) = split_leading_unit(rest)
              format_featured(convert_amount(amount, rate), symbol)
              <> unit
              <> after
            }
            Error(Nil) -> featured_price_marker <> chunk
          }
        })
      string.concat([head, ..rewritten])
    }
  }
}

/// Sıkı biçim çıktısı: simge tutara bitişik (`$59.20`, `€54.30`).
/// Sayı biçimi kanonik biçimle aynı kuraldır (`money_text`), yalnızca aradaki
/// boşluk yoktur.
pub fn format_featured(value: Float, symbol: String) -> String {
  symbol <> money_text(value)
}

/// Parçanın başındaki Türkçe gruplu tutarı okur; kalanı döndürür.
/// `.` binlik, `,` ondalık ayraçtır (`2.800` = 2800, `25.000,50` = 25000.5).
fn leading_tr_amount(text: String) -> Result(#(Float, String), Nil) {
  let raw =
    text
    |> string.to_graphemes
    |> list.take_while(fn(char) { string.contains(tr_amount_chars, char) })
    |> string.concat
  case raw {
    "" -> Error(Nil)
    _ -> {
      let rest = string.drop_start(text, up_to: string.length(raw))
      // Ondalık kısım yoksa `.0` eklenir: `float.parse`/`binary_to_float`
      // nokta içermeyen dizeyi reddeder, bu yüzden `2.800` (Türkçe binlik
      // gruplu, kesirli kısmı olmayan vitrin fiyatı) normalizasyondan sonra
      // `2800.0` olmalı — aksi hâlde tutar okunamaz ve vitrin kartı
      // sessizce dönüşmeden kalır.
      let normalized = case string.split(raw, ",") {
        [whole, fraction, ..] ->
          string.replace(whole, ".", "") <> "." <> fraction
        _ -> string.replace(raw, ".", "") <> ".0"
      }
      case float.parse(normalized) {
        Ok(value) -> Ok(#(value, rest))
        Error(Nil) -> Error(Nil)
      }
    }
  }
}

/// Tutara bitişik birim sonekini (`/gece`) ayırır.
fn split_leading_unit(text: String) -> #(String, String) {
  let unit =
    text
    |> string.to_graphemes
    |> list.take_while(fn(char) { string.contains(unit_chars, char) })
    |> string.concat
  #(unit, string.drop_start(text, up_to: string.length(unit)))
}

// ---------------------------------------------------------------------------
// Biçimlendirme
// ---------------------------------------------------------------------------

fn money_text(value: Float) -> String {
  case value >=. 1000.0 {
    True -> group_digits(int.to_string(float.round(value)))
    False -> {
      // Kuruş cinsinden tam sayıya yuvarlanır; ondalık kısım basamak
      // düzeyinde yazılır (kayan nokta gösterimine güvenilmez).
      let cents = float.round(value *. 100.0)
      let digits = int.to_string(cents)
      let digits = case string.length(digits) {
        size if size < 3 -> string.repeat("0", times: 3 - size) <> digits
        _ -> digits
      }
      let size = string.length(digits)
      group_digits(string.slice(digits, 0, size - 2))
      <> "."
      <> string.slice(digits, size - 2, 2)
    }
  }
}

/// Binlik ayraç: en-US kuralı (virgül, üçlü gruplar).
fn group_digits(digits: String) -> String {
  let size = string.length(digits)
  case size <= 3 {
    True -> digits
    False ->
      group_digits(string.slice(digits, 0, size - 3))
      <> ","
      <> string.slice(digits, size - 3, 3)
  }
}

/// JSON-LD fiyatı: iki ondalığa yuvarlanmış geçerli JSON sayısı.
fn json_number(value: Float) -> String {
  float.to_string(int.to_float(float.round(value *. 100.0)) /. 100.0)
}

// ---------------------------------------------------------------------------
// Gövde taraması
// ---------------------------------------------------------------------------

/// `marker`dan sonra gelen sayısal tutarı `replace` ile yeniden yazar.
/// Tutar okunamazsa (ör. metin) işaret ve gövde aynen korunur; bu yüzden
/// fonksiyon yalnızca gerçekten tutar basılan yerleri değiştirir.
fn rewrite_amounts_after(
  body: String,
  marker: String,
  amount_chars: String,
  replace: fn(Float) -> Result(String, Nil),
) -> String {
  case string.split(body, marker) {
    [] -> body
    [only] -> only
    [head, ..tail] -> {
      let rewritten =
        tail
        |> list.map(fn(chunk) {
          case leading_amount(chunk, amount_chars) {
            Ok(#(amount, rest)) ->
              case replace(amount) {
                Ok(replacement) -> replacement <> rest
                Error(Nil) -> marker <> chunk
              }
            Error(Nil) -> marker <> chunk
          }
        })
      string.concat([head, ..rewritten])
    }
  }
}

/// Parçanın başındaki tutar dizisini (`amount_chars`) sayı olarak okur;
/// kalanı döndürür. Ayraç `float.parse`ın kabul ettiği biçimdir
/// (`25000.00`, `2.5e4`).
fn leading_amount(
  text: String,
  amount_chars: String,
) -> Result(#(Float, String), Nil) {
  let amount =
    text
    |> string.to_graphemes
    |> list.take_while(is_amount_char(amount_chars))
    |> string.concat
  case amount {
    "" -> Error(Nil)
    _ ->
      case float.parse(amount) {
        Ok(value) ->
          Ok(#(value, string.drop_start(text, up_to: string.length(amount))))
        Error(Nil) -> Error(Nil)
      }
  }
}

fn is_amount_char(amount_chars: String) -> fn(String) -> Bool {
  fn(char) { string.contains(amount_chars, char) }
}
