//// Panel (yönetim) arayüzü i18n katmanı — statik sözleşme bekçisi.
////
//// NEDEN: panel bölüm başlıkları ve menü öğeleri Türkçe sabit metindi; dil
//// seçimi (topbar `/set-lang/<code>` veya `?lang=`) yalnız birkaç etiketi
//// değiştiriyordu. Kök sorun, bölüm başlığının AYNI ZAMANDA yönlendirme
//// anahtarı olmasıydı: `panel.section` form seçimini ve script/CSS seçimini
//// `case title { "Bölgeler" -> ... }` ile yapıyordu. Başlık çevrilebilir
//// olduğunda bu eşleşme kırılacağı için önce dispeç anahtarını görünen
//// metinden ayırmak gerekti.
////
//// Sabitlenen sözleşmeler:
////   1) `panel.section` yönlendirme/asset seçimini `section_key` (slug) ile
////      yapar; görünen başlık `i18n.section_title(lang, key)` üretir.
////   2) `section_scripts` / `section_stylesheets` slug ile anahtarlanır —
////      Türkçe başlıkla değil.
////   3) Menü etiketleri (sidebar, mobil tab bar, topbar dil seçici) i18n
////      üzerinden gelir; panel kaynağında sabit Türkçe menü metni kalmaz.
////   4) Her bölüm slug'ı bir çeviri anahtarına çözülür; tanınmayan slug
////      `section_fallback`'a düşer, sessizce anahtar metni basılmaz.
////   5) Bu anahtarlar tüm dillerde gerçekten çevrilmiştir (i18n_test.gleam
////      kapsam listesi + EN-kopyası denetimi bunu zorlar).

import gleam/list
import gleam/string
import gleeunit/should
import nexus_agency/i18n
import simplifile

const panel_gleam = "src/nexus_agency/panel.gleam"
const router_erl = "src/nexus_agency/erl/nexus_agency@router_impl.erl"

const languages = ["tr", "en", "de", "ru", "zh", "fr"]

/// `panel.section` dispeçinde ve router'da kullanılan bölüm slug'ları.
const section_slugs = [
  "catalog", "listings", "reservations", "customers", "regions", "team",
  "settings", "languages", "currencies", "categories", "cms", "campaigns",
  "supplier-campaigns", "integrations", "ai", "reports", "media",
  "abandoned-carts", "sub-agencies", "popups", "offers", "inquiries",
  "notifications", "search-analytics",
]

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

fn contains_all(haystack: String, needles: List(String)) -> Bool {
  list.all(needles, fn(needle) { string.contains(haystack, needle) })
}

fn contains_none(haystack: String, needles: List(String)) -> Bool {
  list.all(needles, fn(needle) { !string.contains(haystack, needle) })
}

pub fn panel_sources_readable_test() {
  read_file(panel_gleam) |> string.is_empty |> should.be_false
  read_file(router_erl) |> string.is_empty |> should.be_false
}

// ---- 1) Dispeç ve başlık ayrımı ----

pub fn section_dispatches_on_slug_not_title_test() {
  let src = read_file(panel_gleam)

  // Yeni imza: slug parametresi ve i18n'den türetilen başlık
  contains_all(src, [
    "pub fn section(\n  s: Session,\n  section_key: String,",
    "let title = i18n.section_title(lang, section_key)",
    "case section_key {",
    "section_scripts(section_key)",
    "section_stylesheets(section_key)",
  ])
  |> should.be_true

  // Eski Türkçe-başlık dispeçi tamamen gitmiş olmalı
  contains_none(src, [
    "case title {",
    "\"Bölgeler\" -> region_form()",
    "\"CMS içerikleri\" -> cms_form()",
    "section_scripts(title)",
    "section_stylesheets(title)",
  ])
  |> should.be_true
}

pub fn asset_selection_keyed_on_slug_test() {
  let src = read_file(panel_gleam)

  contains_all(src, [
    "fn section_scripts(section_key: String) -> List(String) {",
    "fn section_stylesheets(section_key: String) -> List(String) {",
    "\"catalog\" | \"listings\" ->",
    "\"abandoned-carts\" -> [\"/static/abandoned-carts.js\"]",
    "\"supplier-campaigns\" -> [\"/static/campaign-admin.js\"]",
  ])
  |> should.be_true

  // Türkçe başlıkla anahtarlama kalmamalı
  contains_none(src, [
    "\"Katalog\" | \"İlanlar\"",
    "\"Ayarlar\" | \"Yapay zeka\"",
    "\"Tedarikçi kampanyaları\" ->",
  ])
  |> should.be_true
}

/// Router, bölüm sayfasına slug geçer — çevrilmiş başlığı değil.
pub fn router_passes_slug_to_section_test() {
  let src = read_file(router_erl)
  src
  |> string.contains("section_title(")
  |> should.be_false
  contains_all(src, [
    "nexus_agency@panel:section(Session, Section, ",
    "nexus_agency@panel:section(Session, ~\"reservations\",",
    "nexus_agency@panel:section(Session, ~\"cms\",",
  ])
  |> should.be_true
}

// ---- 2) Menü öğeleri i18n üzerinden ----

pub fn sidebar_menu_labels_use_i18n_test() {
  let src = read_file(panel_gleam)
  contains_all(src, [
    "#(\"/admin/inquiries\", i18n.t(lang, \"inquiries\"))",
    "#(\"/admin/notifications\", i18n.t(lang, \"notification_center\"))",
    "#(\"/admin/search-analytics\", i18n.t(lang, \"search_analytics\"))",
  ])
  |> should.be_true

  // Eski sabit Türkçe menü etiketleri kalmamalı
  contains_none(src, [
    "#(\"/admin/inquiries\", \"Teklif Talepleri\")",
    "#(\"/admin/notifications\", \"Bildirim Merkezi\")",
    "#(\"/admin/search-analytics\", \"Arama Analitiği\")",
    "a.attribute(\"aria-label\", \"Mobil menü\")",
    "a.attribute(\"aria-label\", \"Menüyü aç\")",
  ])
  |> should.be_true
}

pub fn topbar_and_tabbar_labels_use_i18n_test() {
  let src = read_file(panel_gleam)
  contains_all(src, [
    "a.attribute(\"aria-label\", i18n.t(lang, \"mobile_menu\"))",
    "a.attribute(\"aria-label\", i18n.t(lang, \"menu_open\"))",
    "i18n.t(lang, \"lang_switch_label\") <> \" — \" <> i18n.lang_name(lang)",
    "a.attribute(\"aria-label\", i18n.t(lang, \"languages_aria\"))",
  ])
  |> should.be_true
}

// ---- 3) Slug → çeviri anahtarı eşlemesi ve kapsam ----

pub fn every_section_slug_resolves_to_a_translation_test() {
  let fallback_key = i18n.section_heading_key("__bilinmeyen__")
  fallback_key |> should.equal("section_fallback")

  // Bilinen her slug kendi anahtarına çözülür (sessizce fallback'e düşmez)
  section_slugs
  |> list.each(fn(slug) {
    i18n.section_heading_key(slug)
    |> should.not_equal(fallback_key)
  })
}pub fn section_titles_are_localized_in_all_languages_test() {
  section_slugs
    |> list.each(fn(slug) {
      let key = i18n.section_heading_key(slug)
      let values =
        languages
        |> list.map(fn(lang) { i18n.section_title(lang, slug) })
      // Hiçbir dil boş değer ya da ham anahtar yankısı döndürmez.
      // (Alt-dize kontrolü kasten yok: "notifications" slug'ına karşılık
      // gelen Fransızca değer "Centre de notifications" doğal olarak
      // slug'ı içerir; yankı denetimi i18n_test.gleam'de tam-eşitlikle
      // yapılır.)
      list.all(values, fn(v) { !string.is_empty(v) && v != key })
      |> should.be_true
    })
}

/// Başlık gerçekten dile göre değişir — aynı slug için TR ile EN farklı olmalı.
pub fn section_titles_differ_across_languages_test() {
  let headlines =
    section_slugs
    |> list.filter(fn(slug) {
      let slug_neutral = ["cms", "ai", "media"]
      !list.contains(slug_neutral, slug)
    })
  headlines
  |> list.each(fn(slug) {
    i18n.section_title("tr", slug)
    |> should.not_equal(i18n.section_title("en", slug))
  })
}

/// Bölüm başlığı anahtarları i18n_test kapsam listesine de girmiş olmalı
/// (aksi halde "her anahtar çözülür" denetimi onları atlar).
pub fn new_keys_are_registered_in_i18n_test_test() {
  let registry = read_file("test/i18n_test.gleam")
  contains_all(registry, [
    "\"inquiries\", \"notification_center\", \"search_analytics\", \"mobile_menu\"",
    "\"lang_switch_label\", \"languages_aria\", \"section_supplier_campaigns\"",
    "\"section_fallback\"",
  ])
  |> should.be_true
}
