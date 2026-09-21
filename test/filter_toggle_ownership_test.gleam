//// İlan listesi filtre paneli — tek sahiplik ve `aria-expanded` doğruluğu.
////
//// Sabitlenen davranışlar:
////
////   1) Düğmeyi YALNIZ `public-listings.js` yönetir. `main.js` §2'deki genel
////      `button[aria-expanded][aria-controls]` bağlayıcısı da bağlanırsa sıra
////      şu ölü sonucu verir: genel bağlayıcı `aria-expanded`'ı 'true' yapar,
////      hemen ardından filtre denetleyicisi düğmeyi "açık" okuyup kapatır ve
////      düğme HİÇBİR ŞEY yapmaz (mobilde filtre paneli açılamıyordu).
////   2) Açık/kapalı durumunun tek kaynağı gövdenin `is-open` sınıfıdır.
////      `aria-expanded` türetilmiş etikettir; girdi olarak okunursa belge
////      genelindeki dış-tıklama süpürmesi (main.js §12 ve
////      `header-popovers.js`) etiketi sıfırladığı için panel açıkken düğme
////      "kapalı" davranır.
////   3) Bu süpürmeler sahipliği `window.NEXUS_STATE_OWNED` ile sorar; ortak
////      predicate tek yerde tanımlanır ve iki tüketici de onu çağırır.

import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const main_js_path = "priv/static/chisfis/js/main.js"
const list_js_path = "priv/static/public-listings.js"
const header_js_path = "priv/static/header-popovers.js"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

fn count_occurrences(src: String, needle: String) -> Int {
  src |> string.split(needle) |> list.length |> fn(n) { n - 1 }
}

pub fn filter_toggle_files_readable_test() {
  read_file(main_js_path) |> string.is_empty |> should.be_false
  read_file(list_js_path) |> string.is_empty |> should.be_false
  read_file(header_js_path) |> string.is_empty |> should.be_false
}

/// Sahiplik predicate'i TEK yerde tanımlı ve üç tüketici de onu kullanır:
/// genel bağlayıcı (§2), dış-tıklama süpürmesi (§12) ve header süpürmesi.
pub fn state_owned_single_source_test() {
  let main = read_file(main_js_path)
  main |> count_occurrences("window.NEXUS_STATE_OWNED = ") |> should.equal(1)
  main |> count_occurrences("if (window.NEXUS_STATE_OWNED(btn)) return;") |> should.equal(1)
  main |> count_occurrences("if (window.NEXUS_STATE_OWNED(b)) return;") |> should.equal(1)
  main |> string.contains("[data-filter-panel]") |> should.be_true

  let header = read_file(header_js_path)
  header |> string.contains("window.NEXUS_STATE_OWNED(b)") |> should.be_true
}

/// `public-listings.js` durumu `is-open` sınıfından türetir; `aria-expanded`
/// okumak (girdi almak) geri gelirse kapı kırılır.
pub fn filter_state_source_is_class_test() {
  let src = read_file(list_js_path)
  src |> string.contains("function isExpanded() {") |> should.be_true
  src |> string.contains("return body.classList.contains(\"is-open\");") |> should.be_true
  // Türetilmiş etiket yazılır...
  src |> string.contains("function syncAria() {") |> should.be_true
  // ...ama girdi olarak OKUNMAZ (tek okuma yeri yok; eski kopya geri gelirse
  // aşağıdaki sayaç kırılır).
  src |> count_occurrences("getAttribute(\"aria-expanded\")") |> should.equal(0)
  src |> count_occurrences("getAttribute('aria-expanded')") |> should.equal(0)
}

/// Mobilde varsayılan kapalı, masaüstünde açık: `sync()` her iki dalda da
/// etiketi gerçek duruma yazar (kapalıyken `false`, masaüstünde `true`).
pub fn aria_synced_in_both_breakpoints_test() {
  let src = read_file(list_js_path)
  src |> count_occurrences("syncAria();") |> should.equal(2)
  src |> string.contains("if (window.innerWidth >= BREAKPOINT)") |> should.be_true
}
