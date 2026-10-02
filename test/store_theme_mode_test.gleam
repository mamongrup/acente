//// Mağaza tema çözümlemesi — `applyTheme` mod string sözleşmesi.
////
//// Bulunan hata: `applyTheme(document.documentElement.classList.contains('dark'))`
//// çağrısı bir BOOLEAN geçiyordu. `applyTheme` içinde `dark = mode !== 'light'`
//// olduğu için boolean her zaman `true` oluyor ve mağaza her sayfa yüklemesinde
//// zorla karanlığa dönüyordu — yani aydınlık palet hiç ulaşılamıyordu
//// (`data-theme="light"` ama `class="dark"`).
////
//// Sabitlenen sözleşmeler:
////   A) `applyTheme`'e asla boolean geçilmez; modu sınıflardan okuyan tek bir
////      `currentMode()` yardımcısı vardır ve hem swatch işareti hem mm-foot
////      etiketi senkronu onu kullanır.
////   B) `currentMode()` üç modu da doğru çözer (sahra > dark > light).
////   C) Tema anahtarı tek yerden okunur (`chisfis-theme`) ve auto çözümlemesi
////      saat dilimine bağlı kalır.

import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const main_js_path = "priv/static/chisfis/js/main.js"

/// Kaynak dosyayı LF'e normalize ederek okur.
///
/// Testler `main.js` içinde çok satırlı **tam** alt-dizeler arıyor
/// (`function currentMode() {\n ... }`). Depodaki `.gitattributes` bu dosyayı
/// LF olarak tanımlar, ama Windows'ta `core.autocrlf=true` olan bir çalışma
/// kopyası satırları CRLF ile açar; o zaman `\n` bekleyen eşleme kırılır ve
/// hata koddan değil, kontrolcünün ayarından gelir. Eşleştirme kaynak
/// kodlamadan bağımsız olmalı.
fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content |> string.replace("\r\n", "\n")
    Error(_) -> ""
  }
}

fn contains_all(haystack: String, needles: List(String)) -> Bool {
  list.all(needles, fn(needle) { string.contains(haystack, needle) })
}

fn occurrences(src: String, needle: String) -> Int {
  src |> string.split(needle) |> list.length |> fn(n) { n - 1 }
}

pub fn theme_source_readable_test() {
  read_file(main_js_path) |> string.is_empty |> should.be_false
}

// ---- A) Boolean argümanı yasak, tek mod çözücü ----

pub fn apply_theme_never_receives_boolean_test() {
  let src = read_file(main_js_path)

  // Hatalı desen: sınıftan boolean okuyup doğrudan applyTheme'e geçmek
  src
  |> string.contains("applyTheme(document.documentElement.classList.contains")
  |> should.be_false

  contains_all(src, [
    "function currentMode() {",
    "if (document.documentElement.classList.contains('sahra')) return 'sahra';",
    "return document.documentElement.classList.contains('dark') ? 'dark' : 'light';",
  ])
  |> should.be_true

  // İki senkron noktası da mod çözücüyü kullanmalı
  occurrences(src, "applyTheme(currentMode());") |> should.equal(2)
}

// ---- B) Mod çözümü ----

/// `currentMode()` gövdesi birebir sabitlenir: üç modu da kapsar, sahra
/// kontrolü dark kontrolünden ÖNCE gelir (sahra'da `dark` sınıfı da olabilir)
/// ve her zaman string döner — asla boolean.
pub fn current_mode_resolves_all_palettes_test() {
  let src = read_file(main_js_path)
  let expected =
    "function currentMode() {\n    if (document.documentElement.classList.contains('sahra')) return 'sahra';\n    return document.documentElement.classList.contains('dark') ? 'dark' : 'light';\n  }"

  contains_all(src, [expected]) |> should.be_true
  // Çözücü sınıflardan başka bir kaynağa bağlanmamalı
  src |> string.contains("currentMode = ") |> should.be_false
}

// ---- C) Anahtar + auto çözümlemesi ----

pub fn theme_key_and_auto_resolution_intact_test() {
  let src = read_file(main_js_path)
  contains_all(src, [
    "var THEME_KEY = 'chisfis-theme';",
    "var AUTO_SLOTS = [",
    "function autoStoreTheme(hour) {",
    "[6, 17, 'light'],",
    "[17, 21, 'sahra'],",
    "[21, 24, 'dark'],",
    "[0, 6, 'dark'],",
  ])
  |> should.be_true
}
