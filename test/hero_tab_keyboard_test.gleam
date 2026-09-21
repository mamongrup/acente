//// Hero sekme listesi — klavye gezinmesi (roving tabindex) regresyonu.
////
//// Şablonun hero sekmeleri `<a role="tab">` öğeleridir ve roving tabindex'i
//// zaten basar (seçili `tabindex="0"`, diğerleri `tabindex="-1"`). Ancak ok
//// tuşları bağlı olmadığı için `-1` sekmelere **klavyeyle hiç
//// odaklanamıyordu** — listeden Tab ile çıkılıyor, diğer sekmeler erişilemez
//// kalıyordu.
////
//// Sabitlenen sözleşmeler:
////
////   A) Bağlama `[role="tablist"]` üzerindedir (yalnız düğümler değil,
////      hero'nun `<a role="tab">` sekmeleri de kapsanır) ve liste başına TEK
////      kez yapılır (`__nxRovingBound`) — dil değişiminde paneller yeniden
////      basıldığında dinleyici çoğalmaz.
////   B) Roving tabindex: odağı alan sekme `tabindex="0"`, kalanlar `-1`;
////      açılışta seçili sekme (yoksa ilk sekme) tabbable bırakılır.
////   C) Ok tuşları: yatay listelerde ←/→, dikey listelerde ↑/↓
////      (`aria-orientation`), RTL belgede ileri yön sol ok; Home/End uçlara
////      atlar. Hepsi `preventDefault()` + `focus()` ile odağı taşır.
////   D) Aktive etme ayrımı: `<button role="tab">` odakla birlikte seçilir
////      (tıklama davranışı tek sahipli — `click()` çağrılır), `<a role="tab">`
////      ok tuşuyla SAYFA DEĞİŞTİRMEZ; seçim Enter/click'e bırakılır.
////   E) Markup: hero tablist'i `aria-orientation="horizontal"`, en az iki
////      sekme ve tam olarak bir `tabindex="0"` taşır (roving invariant'ı
////      markup tarafında da bozulmasın).

import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const main_js_path = "priv/static/chisfis/js/main.js"
const export_home_path = "chisfis-final/index.html"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

fn contains_all(haystack: String, needles: List(String)) -> Bool {
  list.all(needles, fn(needle) { string.contains(haystack, needle) })
}

fn count_of(src: String, needle: String) -> Int {
  src |> string.split(needle) |> list.length |> fn(n) { n - 1 }
}

fn after(src: String, marker: String) -> String {
  case string.split_once(src, marker) {
    Ok(#(_, rest)) -> rest
    Error(_) -> ""
  }
}

pub fn hero_tab_keyboard_sources_readable_test() {
  read_file(main_js_path) |> string.is_empty |> should.be_false
  read_file(export_home_path) |> string.is_empty |> should.be_false
}

// ---- A) Bağlama: tablist kapsamı + tek bağlama ----

pub fn tablist_binding_covers_anchors_once_test() {
  let main = read_file(main_js_path)

  contains_all(main, [
    // Sekmeler türüne göre değil role göre toplanır: hero sekmeleri <a>.
    "$$('[role=\"tab\"]', list).filter(function (tab) {",
    "return tab.closest('[role=\"tablist\"]') === list;",
    // Liste düğümünde tek bağlama koruması.
    "$$('[role=\"tablist\"]').forEach(function (list) {",
    "if (list.__nxRovingBound) return;",
    "list.__nxRovingBound = true;",
    "list.addEventListener('keydown', function (e) {",
  ])
  |> should.be_true

  // Eski hâlde gezinme yalnız tıklamayla kuruluyordu; ok tuşu bağlayıcısı
  // dosyada tam olarak BİR kez bulunmalı (ikinci bir kopya çift taşıma yapar).
  count_of(main, "list.addEventListener('keydown'") |> should.equal(1)
}

// ---- B) Roving tabindex invariant'ı ----

pub fn roving_tabindex_invariant_test() {
  let main = read_file(main_js_path)

  contains_all(main, [
    "function setRovingTabindex(tabs, active) {",
    "tabs.forEach(function (tab) { tab.tabIndex = tab === active ? 0 : -1; });",
    // Açılış normalizasyonu: seçili sekme (yoksa ilk sekme) tabbable kalır.
    "return t.getAttribute('aria-selected') === 'true';",
    "setRovingTabindex(tabs, selected || tabs[0]);",
    // Odak zaten listede ise ondan devam edilir.
    "var focused = tabs.indexOf(document.activeElement);",
  ])
  |> should.be_true
}

// ---- C) Ok tuşları + Home/End, yön farkındalığı ----

pub fn arrow_keys_move_focus_test() {
  let main = read_file(main_js_path)

  contains_all(main, [
    "var vertical = list.getAttribute('aria-orientation') === 'vertical';",
    "rtl = getComputedStyle(list).direction === 'rtl';",
    "var forward = vertical ? 'ArrowDown' : (rtl ? 'ArrowLeft' : 'ArrowRight');",
    "var backward = vertical ? 'ArrowUp' : (rtl ? 'ArrowRight' : 'ArrowLeft');",
    "if (e.key === forward) next = tabs[(i + 1) % tabs.length];",
    "else if (e.key === backward) next = tabs[(i - 1 + tabs.length) % tabs.length];",
    "else if (e.key === 'Home') next = tabs[0];",
    "else if (e.key === 'End') next = tabs[tabs.length - 1];",
    // Taşıma: varsayılan kaydırma iptal edilir ve odak gerçekten taşınır.
    "e.preventDefault();",
    "next.focus();",
  ])
  |> should.be_true
}

// ---- D) Bağlantı sekmeleri ok tuşuyla gezinmez ----

pub fn link_tabs_do_not_navigate_on_arrows_test() {
  let main = read_file(main_js_path)

  contains_all(main, [
    "// Düğme sekmeleri odakla birlikte seçilir; bağlantı sekmeleri Enter'ı",
    "if (next.tagName === 'BUTTON') next.click();",
  ])
  |> should.be_true

  // Koşulsuz `next.click()` geri gelirse ok tuşu hero'da sayfa değiştirir.
  count_of(main, "next.click();") |> should.equal(1)
}

// ---- E) Markup: roving invariant + yatay yön ----

pub fn hero_tablist_markup_keeps_roving_invariant_test() {
  let html = read_file(export_home_path)

  html
  |> string.contains("role=\"tablist\" aria-orientation=\"horizontal\"")
  |> should.be_true

  // Hero tablist'i: listeyi takip eden `</a>` parçaları; liste bittiğinde
  // gelen parça artık `role="tab"` taşımaz (take_while burada durur).
  let tabs =
    html
    |> after("role=\"tablist\" aria-orientation=\"horizontal\"")
    |> string.split("</a>")
    |> list.take_while(fn(piece) { string.contains(piece, "role=\"tab\"") })

  tabs |> list.length |> fn(n) { n >= 3 } |> should.be_true

  // Her sekme: rol + gerçek bağlantı + roving tabindex + şablon sınıfı.
  list.each(tabs, fn(tab) {
    tab |> string.contains("role=\"tab\"") |> should.be_true
    tab |> string.contains(" href=") |> should.be_true
    tab |> string.contains("tabindex=\"") |> should.be_true
    tab |> string.contains("class=\"group/tab") |> should.be_true
  })

  // Tam olarak bir tabbable sekme: roving tabindex'in markup tarafı.
  let tabbable =
    list.filter(tabs, fn(t) { string.contains(t, "tabindex=\"0\"") })
  tabbable |> list.length |> should.equal(1)

  // Seçili sekme hem `aria-selected` hem görsel `data-selected` taşır.
  let selected =
    list.filter(tabs, fn(t) {
      string.contains(t, "aria-selected=\"true\"")
    })
  selected |> list.length |> should.equal(1)
  selected
  |> list.map(fn(t) { string.contains(t, "data-selected") })
  |> should.equal([True])
  // Seçili sekme, tabbable olan sekmeyle aynı olmalı.
  selected |> should.equal(tabbable)

  // Kalan sekmeler `-1`: ok tuşu olmadan erişilemezlerdi.
  let rest =
    list.filter(tabs, fn(t) { string.contains(t, "tabindex=\"-1\"") })
  rest |> list.length |> should.equal(list.length(tabs) - 1)
}
