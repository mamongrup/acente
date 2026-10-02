//// Hero sekme etiketleri — hover mikro etkileşimi statik regresyonu.
////
//// Karşılaştırma: şablonun (chisfis-final) kendi kuralı yalnız
//// `transition: color .2s` verir ve alt çizgi göstergesini SEÇİLİ sekmeye
//// saklar (custom.css §5, `tabSlide`); Tailwind tarafı da sadece metin rengini
//// değiştirir (`hover:text-neutral-700` / `dark:hover:text-neutral-400`).
//// Projenin mikro etkileşim dili (`.nc-pop__opt`, `.mm-acc-inner > a`,
//// `.nc-pop__row`) hover'da renk geçişi + yumuşak zemin + 2-3px kayma ve
//// hover'da önizlenen bir gösterge kullanır.
////
//// Sabitlenen sözleşmeler:
////
////   A) Şablonun §5 blokları birebir korunur (markup da öyle): `position:
////      relative`, `transition: color .2s ease`, seçili `::after`, `tabSlide`
////      ve `hero_search_tab`'ın Tailwind sınıf listesi.
////   B) Eksik parçalar bridge CSS'te tamamlanır: zemin katmanı, 2px kayma,
////      hover alt çizgi önizlemesi.
////   C) Zemin/çizgi NEGATİF insetle çizilir — sekme kutusunun padding'i
////      değişmez, yani satır genişliği ve seçili çizginin ölçüsü şablondaki
////      gibi kalır (layout kayması yok).
////   D) Kayma yalnız `@media (hover: hover)` altında uygulanır (dokunmatikte
////      yapışık kalmasın); geniş `[role="tab"]` seçicisi kullanılmaz (şehir
////      sekmeleri ve dil/para sekmeleri etkilenmemeli).
////   E) `prefers-reduced-motion: reduce` altında geçiş ve animasyon kapanır —
////      hem yeni blokta hem şablondan gelen `tabSlide` için.
////   F) Şablonun `focus-visible:outline-hidden` sınıfı odağı görünmez yapıyor;
////      projenin diğer bileşenlerindeki gibi görünür bir odak halkası bırakılır.

import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const bridge_css_path = "priv/static/chisfis-bridge.css"

const custom_css_path = "priv/static/chisfis/css/custom.css"

const router_markup_path = "src/nexus_agency/erl/nexus_agency@router_impl.erl"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    // Windows checkout'ları CRLF yazar; iğneler LF varsayar. Satır sonlarını
    // LF'e indirerek test checkout-bağımsız olur.
    Ok(content) -> string.replace(content, "\r\n", "\n")
    Error(_) -> ""
  }
}

fn contains_all(haystack: String, needles: List(String)) -> Bool {
  list.all(needles, fn(needle) { string.contains(haystack, needle) })
}

fn count_of(src: String, needle: String) -> Int {
  src |> string.split(needle) |> list.length |> fn(n) { n - 1 }
}

pub fn hero_tab_sources_readable_test() {
  read_file(bridge_css_path) |> string.is_empty |> should.be_false
  read_file(custom_css_path) |> string.is_empty |> should.be_false
  read_file(router_markup_path) |> string.is_empty |> should.be_false
}

// ---- A) Şablon paritesi (CSS §5 + markup) ----

pub fn template_tab_rules_kept_verbatim_test() {
  let css = read_file(custom_css_path)
  contains_all(css, [
    "[role=\"tab\"] {\n  position: relative;\n  transition: color .2s ease;\n}",
    "[role=\"tab\"][data-selected]::after {",
    "animation: tabSlide .25s ease;",
    "@keyframes tabSlide {",
  ])
  |> should.be_true
}

pub fn hero_tab_markup_keeps_template_classes_test() {
  let markup = read_file(router_markup_path)
  contains_all(markup, [
    "hero_search_tab(",
    "group/tab flex shrink-0 cursor-pointer items-center",
    "hover:text-neutral-700",
    "dark:hover:text-neutral-400",
    "data-[selected]:text-neutral-950",
    // Seçili noktası: yalnız seçilide görünür (şablon davranışı)
    "group-data-[selected]/tab:block",
  ])
  |> should.be_true
}

// ---- B) Tamamlanan parçalar ----

pub fn hero_tab_hover_pieces_present_test() {
  let css = read_file(bridge_css_path)
  contains_all(css, [
    // Zemin katmanı (pill)
    ".chisfis-home .hero-search-form [role=\"tablist\"] [role=\"tab\"]::before {",
    "background: var(--color-neutral-50);",
    "html.dark .chisfis-home .hero-search-form [role=\"tablist\"] [role=\"tab\"]::before {",
    "background: var(--color-neutral-700);",
    // Hover alt çizgi önizlemesi + kayma
    "@keyframes tabHoverIn {",
    "animation: tabHoverIn .18s ease forwards;",
    "transform: translateX(2px);",
  ])
  |> should.be_true
}

pub fn hero_tab_hover_is_scoped_and_gated_test() {
  let css = read_file(bridge_css_path)
  // Geniş `[role="tab"]` seçicisi eklenmemiş olmalı: şehir sekmeleri ve
  // mm-pop (dil/para) sekmeleri bu dilin dışında kalır.
  css |> string.contains("\n[role=\"tab\"] {") |> should.be_false
  css |> string.contains("\n[role=\"tab\"]:hover") |> should.be_false

  // Kayma yalnız hover yeteneği olan cihazlarda
  let hover_blocks =
    css
    |> string.split("@media (hover: hover) {")
    |> list.length
    |> fn(n) { n - 1 }
  { hover_blocks > 0 } |> should.be_true

  // Zemin + çizgi: NEGATİF inset (kutunun padding'i değişmemeli — aksi halde
  // sekme satırının genişliği ve seçili alt çizginin ölçüsü şablondan sapar).
  // Kural gövdesi birebir sabitlenir: padding eklenirse test kırmızı olur.
  css |> string.contains("inset: -4px -8px;") |> should.be_true
  css
  |> string.contains(
    ".chisfis-home .hero-search-form [role=\"tablist\"] [role=\"tab\"] {\n  transition: color .2s ease, transform .15s ease;\n}",
  )
  |> should.be_true
}

// ---- E) Hareket azaltma ----

pub fn hero_tab_reduced_motion_guards_test() {
  let bridge = read_file(bridge_css_path)
  contains_all(bridge, [
    "@media (prefers-reduced-motion: reduce) {",
    ".chisfis-home .hero-search-form [role=\"tablist\"] [role=\"tab\"]:hover {\n    transform: none;\n  }",
    ".chisfis-home .hero-search-form [role=\"tablist\"] [role=\"tab\"]:hover:not([data-selected])::after {\n    animation: none;\n    opacity: .45;\n  }",
  ])
  |> should.be_true

  // Şablondan gelen `tabSlide` de kapatılır
  let custom = read_file(custom_css_path)
  contains_all(custom, [
    "/* Proje eki (şablonda yok): hareket azaltma tercihinde gösterge animasyonsuz",
    "[role=\"tab\"] { transition: none; }",
    "[role=\"tab\"][data-selected]::after { animation: none; }",
  ])
  |> should.be_true
}

// ---- F) Odak göstergesi ----

pub fn hero_tab_focus_ring_present_test() {
  let css = read_file(bridge_css_path)
  contains_all(css, [
    ".chisfis-home .hero-search-form [role=\"tablist\"] [role=\"tab\"]:focus-visible {",
    "outline: 2px solid var(--color-primary-500);",
    "outline-offset: 3px;",
  ])
  |> should.be_true

  // Odak halkası hero sekmelerinde tam olarak bir kez tanımlı (kopya blok yok)
  // (baştaki satır sonu: `html.dark` varyantını saymaz)
  count_of(
    css,
    "\n.chisfis-home .hero-search-form [role=\"tablist\"] [role=\"tab\"]:focus-visible {",
  )
  |> should.equal(1)
}
