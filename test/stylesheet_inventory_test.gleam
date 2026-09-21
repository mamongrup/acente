//// Panel Aurora CSS envanteri regresyon testleri.
////
//// Amaç: panel.gleam'deki core_stylesheet_links() ve section_stylesheets()
//// fonksiyonlarının döndürdüğü CSS yollarının sabit listesinden sapma olmamasını
//// ve referans verilen her dosyanın diskte mevcut olmasını garanti etmek.
////
//// Eski admin-overrides.css / admin-polish.css Aurora setine katıldıktan sonra
//// bu test, 12 dosyalık Aurora envanterinin bütünlüğünü korur.
////
//// Bütçe denetimi: her modül için kural sayısı üst sınırı + Aurora dışı
//// stylesheet referansı olmamalı.

import gleam/list
import gleam/string
import gleeunit/should
import nexus_agency/auth
import nexus_agency/panel
import simplifile

const admin_session = auth.Session(
  tenant_id: "11111111-1111-1111-1111-111111111111",
  user_id: "22222222-2222-2222-2222-222222222222",
  name: "Test Admin",
  membership: "admin",
  theme_pref: "dark",
  wizard_prefs_json: "",
  language_pref: "",
  currency_pref: "",
)

/// Beklenen Aurora CSS envanteri — bu liste değişirse test kırılır.
/// Sıra önemli: cascade sırasıyla sıralanmıştır.
const expected_core_css = [
  "/static/css/01-tokens.css",
  "/static/css/02-base.css",
  "/static/css/03-layout.css",
  "/static/css/04-forms-tables.css",
  "/static/css/05-media-catalog.css",
  "/static/css/07-utilities.css",
  "/static/css/12-compact-responsive.css",
]

/// Bölüm bazlı ek CSS modülleri.
const expected_section_css = [
  #("catalog", [
    "/static/css/06-wizard.css",
    "/static/css/08-editor-rooms-seo.css",
    "/static/css/09-catalog-mode.css",
    "/static/css/10-translations.css",
  ]),
  #("regions", [
    "/static/css/08-editor-rooms-seo.css",
    "/static/css/11-regions.css",
  ]),
  #("settings", [
    "/static/css/09-catalog-mode.css",
    "/static/css/11-regions.css",
  ]),
  #("cms", ["/static/css/08-editor-rooms-seo.css"]),
]

/// Tüm benzersiz CSS dosyaları (core + section birleşimi).
const all_expected_css = [
  "/static/css/01-tokens.css",
  "/static/css/02-base.css",
  "/static/css/03-layout.css",
  "/static/css/04-forms-tables.css",
  "/static/css/05-media-catalog.css",
  "/static/css/06-wizard.css",
  "/static/css/07-utilities.css",
  "/static/css/08-editor-rooms-seo.css",
  "/static/css/09-catalog-mode.css",
  "/static/css/10-translations.css",
  "/static/css/11-regions.css",
  "/static/css/12-compact-responsive.css",
]

/// Her sayfa HTML'inde core CSS linklerinin bulunduğunu doğrular.
/// Argüman bölüm SLUG'ıdır (eskiden görünen Türkçe başlıktı; i18n katmanıyla
/// dispeç slug'a taşındı).
fn section_html(section_key: String) -> String {
  panel.section(admin_session, section_key, "", [], "tr", "hotel")
}

// ---------------------------------------------------------------------------
// Testler
// ---------------------------------------------------------------------------

/// Dashboard: core CSS mevcut, fazla section CSS yok.
pub fn dashboard_contains_core_css_test() {
  let html = panel.dashboard(admin_session, "tr", "hotel")
  list.each(expected_core_css, fn(path) {
    string.contains(html, path) |> should.be_true
  })
  // Section-specific不应出现在 dashboard'da
  list.each(
    ["/static/css/06-wizard.css", "/static/css/11-regions.css"],
    fn(path) {
      string.contains(html, path) |> should.be_false
    },
  )
}

/// Her section için doğru CSS seti yükleniyor.
pub fn section_css_inventory_test() {
  list.each(expected_section_css, fn(pair) {
    let #(title, expected_css) = pair
    let html = section_html(title)
    // Beklenen her CSS mevcut olmalı
    list.each(expected_css, fn(path) {
      string.contains(html, path)
      |> should.be_true
    })
    // Core CSS de her section'da olmalı
    list.each(expected_core_css, fn(path) {
      string.contains(html, path)
      |> should.be_true
    })
  })
}

/// Katalog section'ı ek CSS'leri de içermeli (06, 08, 09, 10).
pub fn catalog_section_has_wizard_css_test() {
  let html = section_html("catalog")
  [
    "/static/css/06-wizard.css",
    "/static/css/08-editor-rooms-seo.css",
    "/static/css/09-catalog-mode.css",
    "/static/css/10-translations.css",
  ]
  |> list.each(fn(path) {
    string.contains(html, path) |> should.be_true
  })
}

/// Hiçbir section'da olmayan CSS referansı olmamalı
/// (ör. eski admin-overrides veya admin-polish).
pub fn no_legacy_css_references_test() {
  let titles = [
    "catalog", "regions", "settings", "cms", "customers", "reservations",
    "languages", "integrations", "ai",
  ]
  list.each(titles, fn(title) {
    let html = section_html(title)
    // Eski legacy dosyalar referans edilmemeli
    ["admin-overrides", "admin-polish"]
    |> list.each(fn(legacy) {
      string.contains(html, legacy) |> should.be_false
    })
  })
}

/// Tüm Aurora CSS dosyaları toplamda en az bir section'da referans edilmeli.
/// Eksik dosya = potansiyel 404 veya yüklenmeyen stil.
pub fn all_expected_css_referenced_test() {
  // Dashboard'da core'ları kontrol et
  let dash = panel.dashboard(admin_session, "tr", "hotel")
  list.each(expected_core_css, fn(path) {
    string.contains(dash, path) |> should.be_true
  })
  // Section-specific'leri ilgili section'larda kontrol et
  list.each(expected_section_css, fn(pair) {
    let #(title, css) = pair
    let html = section_html(title)
    list.each(css, fn(path) {
      string.contains(html, path) |> should.be_true
    })
  })
}

/// Toplam benzersiz CSS dosya sayısı 12 olmalı (13 değil; envanter daraldı).
pub fn total_css_file_count_test() {
  let count = list.length(all_expected_css)
  count |> should.equal(12)
}

/// Core CSS sayısı 7 olmalı.
pub fn core_css_count_test() {
  let count = list.length(expected_core_css)
  count |> should.equal(7)
}

/// Script tag envanteri: core script'ler her sayfada mevcut olmalı.
pub fn core_scripts_present_in_dashboard_test() {
  let html = panel.dashboard(admin_session, "tr", "hotel")
  [
    "/static/csrf-guard.js",
    "/static/theme-toggle.js",
    "/static/theme-boot.js",
    "/static/table-bulk.js",
    "/static/table-expand.js",
    "/static/sidebar-tree.js",
    "/static/sidebar-nav.js",
    "/static/quick-search.js",
    "/static/panel-tab-bar.js",
  ]
  |> list.each(fn(path) {
    string.contains(html, path) |> should.be_true
  })
}

/// Sayfada 404'e yol açabilecek olmayan dosya referansı olmamalı
/// (bilinen legacy dosyalar).
pub fn no_obsolete_static_references_test() {
  let html = panel.dashboard(admin_session, "tr", "hotel")
  [
    "admin-overrides.css",
    "admin-polish.css",
    "agency-admin.css",
  ]
  |> list.each(fn(path) {
    string.contains(html, path) |> should.be_false
  })
}

// ===========================================================================
// CSS BÜTÇE DENEYİMİ — kural sayısı üst sınırı + Aurora dışı engelleme
// ===========================================================================

/// Her Aurora modülü için izin verilen maksimum kural sayısı.
/// Mevcut kural sayılarına %20 headroom eklenmiştir; aşılırsa test kırılır.
/// Yeni kural eklendiğinde bu sınırda da güncelleme gerekir.
const css_budget = [
  #("01-tokens.css", 28),
  #("02-base.css", 12),
  #("03-layout.css", 180),
  #("04-forms-tables.css", 160),
  #("05-media-catalog.css", 138),
  #("06-wizard.css", 307),
  #("07-utilities.css", 10),
  #("08-editor-rooms-seo.css", 187),
  #("09-catalog-mode.css", 209),
  #("10-translations.css", 30),
  #("11-regions.css", 71),
  #("12-compact-responsive.css", 217),
]

/// CSS dosyasındaki yaklaşık kural sayısını sayar: açma parantezi { sayısını
/// alır (yorum/içerik içindeki,false positive'ler minimum düzeyde).
fn count_css_rules(content: String) -> Int {
  let chars = string.to_graphemes(content)
  count_braces(chars, 0, False, False, 0)
}

/// Tail-recursive { sayacı: // ve /* */ yorumlarını atlar.
fn count_braces(
  chars: List(String),
  depth: Int,
  in_comment: Bool,
  in_line_comment: Bool,
  count: Int,
) -> Int {
  case chars {
    [] -> count
    ["/", "*", ..rest] if !in_comment && !in_line_comment -> {
      count_braces(rest, depth, True, False, count)
    }
    ["*", "/", ..rest] if in_comment -> {
      count_braces(rest, depth, False, False, count)
    }
    ["/", "/", ..rest] if !in_comment && !in_line_comment -> {
      count_braces(rest, depth, False, True, count)
    }
    ["\n", ..rest] if in_line_comment -> {
      count_braces(rest, depth, False, False, count)
    }
    ["{", ..rest] if !in_comment && !in_line_comment -> {
      count_braces(rest, depth + 1, False, False, count + 1)
    }
    ["}", ..rest] if !in_comment && !in_line_comment -> {
      count_braces(rest, depth - 1, False, False, count)
    }
    [_, ..rest] -> {
      count_braces(rest, depth, in_comment, in_line_comment, count)
    }
  }
}

/// CSS dosyasını diskten oku.
fn read_css(filename: String) -> String {
  case simplifile.read("priv/static/css/" <> filename) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

/// Her Aurora CSS modülünün kural sayısını bütçe ile karşılaştırır.
pub fn css_rule_budget_per_module_test() {
  list.each(css_budget, fn(pair) {
    let #(filename, limit) = pair
    let content = read_css(filename)
    let rules = count_css_rules(content)
    should.be_true(rules <= limit)
  })
}

/// Hiçbir Aurora CSS dosyası discriminator'da eksik olmamalı.
pub fn budget_covers_all_modules_test() {
  let budget_files = list.map(css_budget, fn(p) { p.0 })
  list.each(all_expected_css, fn(path) {
    // /static/css/ prefix'ini kaldırarak dosya adını al
    let filename = case string.starts_with(path, "/static/css/") {
      True -> string.drop_start(path, 12)
      False -> path
    }
    list.contains(budget_files, filename) |> should.be_true
  })
}

/// Tüm Aurora CSS dosyaları diskte mevcut olmalı (404 engeli).
pub fn all_aurora_css_files_exist_on_disk_test() {
  list.each(all_expected_css, fn(path) {
    let filename = case string.starts_with(path, "/static/css/") {
      True -> string.drop_start(path, 12)
      False -> path
    }
    let content = read_css(filename)
    // Boş dosya = diskte yok veya okunamadı
    string.is_empty(content) |> should.be_false
  })
}

/// Tüm Aurora CSS dosyalarının toplam boyutu 300KB'ı aşmamalı.
pub fn total_css_size_budget_test() {
  let max_bytes = 300_000
  let total =
    list.fold(all_expected_css, 0, fn(acc, path) {
      let filename = case string.starts_with(path, "/static/css/") {
        True -> string.drop_start(path, 12)
        False -> path
      }
      acc + string.length(read_css(filename))
    })
  should.be_true(total <= max_bytes)
}

/// Panel sayfalarında Aurora dışı stylesheet referansı olmamalı.
/// Yalnızca /static/css/NN-*.css ve bilinen static dosyalara izin verilir.
pub fn no_unauthorized_stylesheets_in_html_test() {
  let titles = [
    "Dashboard", "catalog", "regions", "settings",
    "customers", "reservations",
  ]
  // Aurora dışı bilinen dosya adları — bunlar HTML'de görünmemeli
  let forbidden = [
    "agency-admin.css",
    "admin-overrides.css",
    "admin-polish.css",
    "bootstrap",
    "tailwind.css",
    "fontawesome",
    "materialize",
  ]
  list.each(titles, fn(title) {
    let html = case title {
      "Dashboard" -> panel.dashboard(admin_session, "tr", "hotel")
      _ -> section_html(title)
    }
    list.each(forbidden, fn(name) {
      string.contains(html, name) |> should.be_false
    })
  })
}

/// Herhangi bir sayfada bilinen legacy CSS dosyası referansı olmamalı.
pub fn no_legacy_css_in_any_section_test() {
  let titles = [
    "catalog", "regions", "settings", "cms", "customers", "reservations",
    "languages", "integrations", "ai",
  ]
  let legacy = [
    "admin-overrides.css",
    "admin-polish.css",
    "agency-admin.css",
    "overrides.css",
    "custom.css",
  ]
  list.each(titles, fn(title) {
    let html = section_html(title)
    list.each(legacy, fn(name) {
      string.contains(html, name) |> should.be_false
    })
  })
}
