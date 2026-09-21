//// Masaüstü header popover'ları — koyu tema hover parite sözleşmesi.
////
//// Gerçek tarayıcıda iki tema × 4 panel × tüm seçenek sınıfları ölçüldü
//// (pasif + hover, WCAG, computed style). Bulunan ihlaller — hepsi karanlık:
////
////   | Hedef                  | ÖNCE             | SONRA            |
////   |------------------------|------------------|------------------|
////   | link ikonu hover       | primary-500:2.31 | token:5.81       |
////   | aktif link metni       | primary-500:2.79 | token:6.25       |
////   | aktif link ikonu       | primary-500:2.76 | token:6.15       |
////   | satır alt etiketi      | neutral-400:4.06 | neutral-300:7.00 |
////
//// KÖK NEDEN: karanlık tema vurgusu `--color-primary-500` (`#fb637e`) idi;
//// kendi karışım zemininde (16% primary-500 üstüne neutral-800) ve hover'daki
//// `neutral-700` üzerinde AA'nın altına düşüyor. Mobil menüde aynı hata
//// `--mm-accent` (primary-300) ile kapatılmıştı; masaüstü tarafı ona bağlandı.
////
//// Sabitlenen sözleşmeler:
////   A) `--nc-accent` kapsamda TANIMLI (fallback'e güvenmez) ve `--mm-accent`
////      ile AYNI primary-300 değerine bağlı (iki dosya arasında drift bekçisi).
////   B) Karanlık hover/aktif renkleri token'dan gelir; dosyada `color:
////      var(--color-primary-500` biçiminde AA-altı metin/ikon rengi kalmaz.
////   C) Satır alt etiketi İKİ temada da hover'a özel renk alır ve geçişi
////      satır zeminiyle aynı ritimdedir; hareket azaltma kapsamına girer.
////   D) `.nc-pop__check` (paylaşılan mobil işaret sınıfı) karanlıkta token'ı
////      kullanır — aydınlık primary-600 koyu zeminde 1.6:1 üretiyordu.

import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const popover_css = "priv/static/chisfis-bridge.css"
const mobile_css = "priv/static/chisfis/css/custom.css"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

fn contains_all(haystack: String, needles: List(String)) -> Bool {
  list.all(needles, fn(needle) { string.contains(haystack, needle) })
}

fn occurrences(src: String, needle: String) -> Int {
  src |> string.split(needle) |> list.length |> fn(n) { n - 1 }
}

pub fn popover_source_readable_test() {
  read_file(popover_css) |> string.is_empty |> should.be_false
}

// ---- A) Token kapsamda tanımlı + iki dosya aynı değere bağlı ----

pub fn dark_accent_token_defined_in_popover_scope_test() {
  let css = read_file(popover_css)
  contains_all(css, [
    "html.dark .nc-pop {\n  --nc-accent: var(--color-primary-300, #a5b4fc);\n  --mm-accent: var(--color-primary-300, #a5b4fc);\n}",
  ])
  |> should.be_true
  // Her token kapsamda bir kez tanımlanır
  occurrences(css, "--nc-accent:") |> should.equal(1)
  occurrences(css, "--mm-accent:") |> should.equal(1)
}

/// İki yüzey (masaüstü popover + mobil menü) AYNI koyu vurguyu paylaşmalı:
/// biri primary-300'den diğeri başka bir basamaktan beslenirse iki taraf
/// sessizce ayrışır.
pub fn dark_accent_same_value_across_surfaces_test() {
  let popover = read_file(popover_css)
  let mobile = read_file(mobile_css)

  popover
  |> string.contains("--nc-accent: var(--color-primary-300, #a5b4fc);")
  |> should.be_true

  mobile
  |> string.contains("--mm-accent: var(--color-primary-300, #a5b4fc);")
  |> should.be_true
}

// ---- B) Karanlık renkleri token'dan gelir; AA-altı primary-500 metni kalmaz ----

pub fn dark_hover_and_active_route_through_token_test() {
  let css = read_file(popover_css)
  contains_all(css, [
    // link hover ikonu
    "  html.dark .nc-pop__link:hover i,\n  html.dark .nc-pop__link:hover svg {\n    color: var(--nc-accent, #a5b4fc);\n  }",
    // aktif link metni + ikonu
    "  color: var(--nc-accent, #a5b4fc);\n}\nhtml.dark .nc-pop__link--active i,\nhtml.dark .nc-pop__link[aria-current='page'] i {\n  color: var(--nc-accent, #a5b4fc);\n}",
    // aktif link hover rengi
    "  color: var(--nc-accent, #a5b4fc);\n}",
  ])
  |> should.be_true
}

/// Karanlıkta AA altına düşen metin/ikon rengi biçimi geri gelmemeli.
///
/// `border-color: var(--color-primary-500)` serbest: `border-color` METİN
/// rengi değildir (3:1 non-text kuralına tabidir ve ölçümlerde geçiyor),
/// ayrıca `color: var(--color-primary-500` alt dizesini de içerir. Bu yüzden
/// düz `contains` yerine sayım farkı kullanılır.
pub fn no_below_aa_primary_text_color_test() {
  let css = read_file(popover_css)
  let all = occurrences(css, "color: var(--color-primary-500")
  let borders = occurrences(css, "border-color: var(--color-primary-500")
  { all - borders } |> should.equal(0)
}

// ---- C) Satır alt etiketi hover rengi (iki tema) ----

pub fn row_sub_hover_colors_test() {
  let css = read_file(popover_css)
  contains_all(css, [
    "  .nc-pop__row:hover .nc-pop__row-sub {\n    color: var(--color-neutral-600);\n  }",
    "  html.dark .nc-pop__row:hover .nc-pop__row-sub {\n    color: var(--color-neutral-300);\n  }",
    // Geçiş satır zeminiyle aynı ritimde
    ".nc-pop__row-sub {\n  font-size: 12px;\n  color: var(--color-neutral-500);\n  margin-top: 2px;",
    "  transition: color 0.15s;\n}",
    // Hareket azaltma kapsamına girdi
    "@media (prefers-reduced-motion: reduce) {\n  .nc-pop__link i,\n  .nc-pop__link svg,\n  .nc-pop__row,\n  .nc-pop__row-sub,",
  ])
  |> should.be_true
}

// ---- D) Paylaşılan işaret sınıfı ----

pub fn shared_check_uses_token_test() {
  let css = read_file(popover_css)
  css
  |> string.contains("html.dark .nc-pop__check { color: var(--nc-accent, #a5b4fc); }")
  |> should.be_true
}
