//// Misafir/yolcu sayacı — sahiplik ve davranış kapıları.
////
//// Sayaç header popover'ından ÇIKARILDI (bkz. `header_popover_i18n_test` E) ve
//// arama bölümüne taşındı. Bu dosya yeni sahipliğin sözleşmelerini sabitler:
////
////   1) Hero arama formunda gerçek bir misafir alanı var: üç stepper satırı
////      (`guestAdults` / `guestChildren` / `guestInfants`) ve toplamı taşıyan
////      `name="guests"` gizli alanı.
////   2) Alanın görünen metinleri `data-i18n` ile bağlı ve anahtarların TAMAMI
////      TR/DE/RU sözlüklerinde var — taşınan kontrol İngilizce kalmamalı.
////   3) Bağlayıcı (`main.js` §4) toplamı hem gizli alana hem özet etiketine
////      yazar, aria adlarını sözlükten basar ve dil değişiminde tazeler.
////   4) Arama URL'si: §13 URL kurucusu `guests` parametresini yazar.
////   5) Detay sayfasının rezervasyon paneli de aynı bileşeni kullanır ve
////      `public-guests.js` gerçekten yüklenir (script bağlanmazsa düğmeler
////      dokunulabilir görünüp hiçbir şey yapmazdı).

import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import simplifile

const export_home_path = "chisfis-final/index.html"
const main_js_path = "priv/static/chisfis/js/main.js"
const public_guests_js_path = "priv/static/public-guests.js"
const router_impl_path = "src/nexus_agency/erl/nexus_agency@router_impl.erl"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

fn after(src: String, marker: String) -> String {
  case string.split_once(src, marker) {
    Ok(#(_, rest)) -> rest
    Error(_) -> ""
  }
}

fn until(src: String, stop: String) -> String {
  case string.split_once(src, stop) {
    Ok(#(before, _)) -> before
    Error(_) -> ""
  }
}

fn occurrences(src: String, marker: String, stop: String) -> List(String) {
  do_occurrences(src, marker, stop, [])
}

fn do_occurrences(
  src: String,
  marker: String,
  stop: String,
  acc: List(String),
) -> List(String) {
  case string.split_once(src, marker) {
    Error(_) -> list.reverse(acc)
    Ok(#(_, rest)) -> {
      let piece = until(rest, stop)
      case piece {
        "" -> list.reverse(acc)
        _ -> do_occurrences(after(rest, stop), marker, stop, [piece, ..acc])
      }
    }
  }
}

fn dict_block(src: String, name: String, stop_marker: String) -> String {
  src |> after("var " <> name <> " = {") |> until(stop_marker)
}

fn has_key(block: String, key: String) -> Bool {
  string.contains(block, "'" <> key <> "': ")
}

/// Hero arama formunun misafir alanını çevreleyen bölge: toplamı taşıyan
/// gizli alandan geriye doğru en yakın `<form` girişi, ileri doğru ilk
/// `</form>` kapanışı.
fn hero_guest_region(html: String) -> String {
  case string.split_once(html, "name=\"guests\"") {
    Error(_) -> ""
    Ok(#(before, rest)) -> {
      let form_open =
        before |> string.split("<form") |> list.last |> result.unwrap("")
      let rows = until(rest, "</form>")
      form_open <> "name=\"guests\"" <> rows
    }
  }
}

pub fn hero_guest_sources_readable_test() {
  read_file(export_home_path) |> string.is_empty |> should.be_false
  read_file(main_js_path) |> string.is_empty |> should.be_false
  read_file(public_guests_js_path) |> string.is_empty |> should.be_false
  read_file(router_impl_path) |> string.is_empty |> should.be_false
}

// ---- 1) Arama formunda gerçek misafir alanı ----

pub fn hero_form_has_guest_steppers_test() {
  let region = read_file(export_home_path) |> hero_guest_region

  region |> string.is_empty |> should.be_false

  // Toplam alanı: arama URL'sine giden tek sayı.
  region
  |> string.contains("type=\"hidden\" name=\"guests\"")
  |> should.be_true
  region
  |> string.contains("data-guests-total")
  |> should.be_true

  // Üç satır: yetişkin / çocuk / bebek.
  ["guestAdults", "guestChildren", "guestInfants"]
  |> list.each(fn(name) {
    region
    |> string.contains("name=\"" <> name <> "\"")
    |> should.be_true
    region
    |> string.contains(name)
    |> should.be_true
  })

  // Özet etiketi ("4 Guests") ve satır sayaç değerleri markup'ta var.
  region |> string.contains("block font-semibold") |> should.be_true
}

// ---- 2) Taşınan kontrol dört dilde ----

pub fn hero_guest_labels_are_translated_test() {
  let region = read_file(export_home_path) |> hero_guest_region

  let keys = occurrences(region, "data-i18n=\"", "\"")

  // Alanın tamamı bağlı olmalı: özet alt etiketi + 3 satır etiketi +
  // 3 açıklama satırı.
  keys |> list.length |> fn(n) { n >= 7 } |> should.be_true

  ["Guests", "Adults", "Children", "Infants"]
  |> list.each(fn(key) { keys |> list.contains(key) |> should.be_true })

  let dicts = read_file(main_js_path)
  let tr = dict_block(dicts, "TR", "var DE = {")
  let de = dict_block(dicts, "DE", "var RU = {")
  // RU bloğunun bitişi: sözlük seti TR/EN/DE/RU/FR/ZH'ye çıktığında araya
  // giren yorum satırı kalktı; sınır artık FR bloğunun başlangıcı.
  let ru = dict_block(dicts, "RU", "var FR = {")

  [tr, de, ru]
  |> list.each(fn(block) {
    let missing = list.filter(keys, fn(k) { !has_key(block, k) })
    case missing {
      [] -> Nil
      _ -> {
        let msg =
          "hero misafir alanında sözlüğü eksik anahtar: "
          <> string.join(missing, " | ")
        msg |> should.equal("")
      }
    }
  })
}

// ---- 3) Bağlayıcı: toplam + aria + dil tazelemesi ----

pub fn stepper_binding_contract_test() {
  let main = read_file(main_js_path)

  [
    // Satırlar gizli alan adından kimlik kazanır; toplam forma yazılır.
    "$$('.flex.min-w-28').forEach(function (row) {",
    "var totalInput = form && form.querySelector('input[name=\"guests\"]');",
    "if (totalInput) totalInput.value = String(total);",
    // Yetişkin alt sınırı 1 (0 misafirle arama anlamsız).
    "var min = key === 'adults' ? 1 : 0;",
    // Sınırda düğme kapanır (sessiz no-op yok).
    "function bound(btn, atBound) {",
    "btn.disabled = atBound;",
    "bound(minus, count <= min);",
    "bound(plus, count >= GUEST_MAX);",
    // Özet etiketi sözlükten.
    "return t('%s Guests').replace('%s', String(n));",
    // Dil değişiminde özet + aria adları tazelenir.
    "guestRefreshers.push(sync);",
  ]
  |> list.all(fn(needle) { string.contains(main, needle) })
  |> should.be_true

  main
  |> string.contains("guestRefreshers.forEach(function (sync) { sync(); });")
  |> should.be_true

  // Satır etiketi `data-i18n` anahtarı üzerinden çevrilir (İngilizce referans).
  main
  |> string.contains("labelEl.getAttribute('data-i18n')")
  |> should.be_true
}

// ---- 4) Seçim arama URL'sine gider ----

pub fn guests_reach_the_search_url_test() {
  let main = read_file(main_js_path)

  // §13 hero form gönderimi: toplam `guests` parametresi olarak yazılır ve
  // mevcut sorgu (ör. tenant) korunur.
  main
  |> string.contains("var params = new URLSearchParams(window.location.search);")
  |> should.be_true
  main
  |> string.contains("if (totalGuests > 0) params.set('guests', totalGuests);")
  |> should.be_true
  main
  |> string.contains("window.location.href = '/urunler' + (qs ? '?' + qs : '');")
  |> should.be_true

  // Gizli alan yoksa satır sayaçlarından toplanır (tek kaynak kaybolursa
  // `guests` parametresi sessizce düşmesin).
  main
  |> string.contains("['guestAdults', 'guestChildren', 'guestInfants']")
  |> should.be_true
}

// ---- 5) Detay sayfasının rezervasyon paneli de aynı bileşeni kullanır ----

pub fn detail_page_guest_picker_is_wired_test() {
  let router = read_file(router_impl_path)

  // Bileşen sunucuda basılıyor ...
  router
  |> string.contains("chisfis-guest-range")
  |> should.be_true

  // ... ve bağlayıcı script GERÇEKTEN sayfaya ekleniyor: bileşen basılıp
  // script yüklenmezse stepper'lar dokunulabilir görünüp hiçbir şey yapmaz.
  router
  |> string.contains("/static/public-guests.js?v=")
  |> should.be_true
  router
  |> string.contains("public_guests_script()")
  |> should.be_true

  let binder = read_file(public_guests_js_path)
  [
    "document.querySelectorAll(\".chisfis-guest-range\")",
    "container.querySelector(\"input[data-guests-total]\")",
    "hidden.value = String(total());",
    // Yetişkin alt sınırı hero'daki bağlayıcıyla aynı.
    "mins = { adults: 1, children: 0, infants: 0 }",
  ]
  |> list.all(fn(needle) { string.contains(binder, needle) })
  |> should.be_true
}

/// Toplam alanı `type="hidden"` olmalı: görünür bir input olsaydı kullanıcı
/// yazdığı sayı ile stepper'lar arasında iki kaynak doğrardı. Değer de sayısal
/// olmalı (sunucu/JS ayrıştırması bozulmasın).
pub fn guest_total_input_is_hidden_test() {
  let region = read_file(export_home_path) |> hero_guest_region

  region
  |> string.contains("type=\"hidden\" name=\"guests\"")
  |> should.be_true

  let value =
    region |> after("name=\"guests\"") |> after("value=\"") |> until("\"")

  case int.parse(value) {
    Ok(_) -> Nil
    Error(_) -> {
      let msg = "misafir toplam alanı sayısal başlangıç değeri taşımalı: " <> value
      msg |> should.equal("")
    }
  }
}
