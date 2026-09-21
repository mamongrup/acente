//// JS ↔ panel DOM bağlantı (ID wiring) regresyon testleri.
////
//// panel gleeunit'te JS çalıştıramaz, ama en sık kırılan sözleşme statik:
//// `priv/static/*.js` dosyaları `getElementById(...)` ile aradıkları ID'lerin
//// panel HTML'inde var olmasına güvenir. JS'ler eksik elemanı sessizce
//// atladığı için (if (el) ...) bu kırılma testlerle yakalanmalıdır.
////
//// Not: public-*.js ve quick-search.js / public-chat.js gibi kendi DOM'unu
//// kendisi üreten betikler bu sözleşmenin dışındadır; yalnızca panel
//// sayfalarına bağlı admin betikleri test edilir.

import gleam/list
import gleam/string
import gleeunit/should
import nexus_agency/auth
import nexus_agency/panel

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

/// Katalog sihirbazını gerçek render yoluyla üret (router'ın yaptığı gibi).
fn catalog_html() -> String {
  panel.section(admin_session, "catalog", "Katalog intro", [], "tr", "hotel")
}

pub fn wizard_mode_switch_buttons_present_test() {
  let html = catalog_html()
  ["btn-mode-stepper", "btn-mode-full", "form-mode-text"]
  |> list.each(fn(id) {
    string.contains(html, "id=\"" <> id <> "\"")
    |> should.be_true
  })
}

// ---- Erişilebilirlik sözleşmeleri (ARIA) ----
// Not: lustre nitelikleri alfabetik sıralar; eşleşmeler buna göre yazıldı.

pub fn wizard_controls_expose_aria_state_test() {
  let html = catalog_html()
  // Mod düğmeleri aria-pressed ile basılı durum bildirir.
  string.contains(
    html,
    "aria-pressed=\"true\" class=\"btn-mode-tab active\" id=\"btn-mode-stepper\"",
  )
  |> should.be_true
  string.contains(html, "class=\"btn-mode-tab\" id=\"btn-mode-full\"")
  |> should.be_true
  // Adım sekmeleri aria-current="step" taşır (aktif olan).
  string.contains(html, "aria-current=\"step\"")
  |> should.be_true
  // İlerleme çubuğu progressbar rolüyle işaretli.
  string.contains(html, "role=\"progressbar\"")
  |> should.be_true
  string.contains(html, "aria-valuemax=\"7\"")
  |> should.be_true
  // Adım sayacı ekran okuyucuya canlı bölge olarak duyurulur.
  string.contains(html, "aria-live=\"polite\" id=\"wizard-step-text\"")
  |> should.be_true
}

pub fn topbar_controls_expose_aria_state_test() {
  let html = catalog_html()
  // Dil düğmesi menü açar; menü rolü ve aktif dil işaretli.
  string.contains(html, "aria-haspopup=\"menu\"")
  |> should.be_true
  string.contains(html, "role=\"menu\"")
  |> should.be_true
  string.contains(html, "role=\"menuitem\"")
  |> should.be_true
  string.contains(html, "aria-current=\"true\"")
  |> should.be_true
  // Hızlı arama düğmesi diyalog açar.
  string.contains(html, "id=\"topbar-search-trigger\"")
  |> should.be_true
  string.contains(html, "aria-haspopup=\"dialog\"")
  |> should.be_true
}

pub fn room_modal_dialog_semantics_test() {
  let html = catalog_html()
  string.contains(html, "id=\"room-type-modal\" role=\"dialog\"")
  |> should.be_true
  string.contains(html, "aria-modal=\"true\"")
  |> should.be_true
  string.contains(html, "aria-labelledby=\"room-modal-title\"")
  |> should.be_true
}

pub fn amenity_chips_are_pressable_buttons_test() {
  let html = catalog_html()
  string.contains(html, "aria-pressed=\"false\" class=\"amenity-toggle-chip\"")
  |> should.be_true
}

// ---- Sayfa bazlı script yükleme ----
// Her section yalnızca ihtiyaç duyduğu JS'i yükler; alakasız betikler
// sayfaya gönderilmez (paket boyutu ve uygulama tarafı kazanç).

fn script_srcs(html: String) -> List(String) {
  html
  |> string.split("src=\"")
  |> list.filter_map(fn(part) {
    case string.split_once(part, "\"") {
      Ok(#(src, _)) -> Ok(src)
      Error(_) -> Error(Nil)
    }
  })
}

pub fn catalog_page_loads_only_wizard_scripts_test() {
  let srcs = script_srcs(catalog_html())
  // Yüklenmeli:
  ["listing-admin.js", "listing-wizard.js", "rich-editor.js", "ai-seo-suite.js"]
  |> list.each(fn(name) {
    srcs
    |> list.any(fn(src) { string.contains(src, name) })
    |> should.be_true
  })
  // Yüklenmemeli (başka section'ların betikleri):
  [
    "dashboard-admin.js", "settings-admin.js", "region-admin.js",
    "customer-admin.js", "reservation-admin.js", "cms-admin.js", "team-admin.js",
    "report-admin.js", "photo-editor.js", "popups-admin.js", "campaign-admin.js",
    "integration-admin.js", "currency-admin.js", "abandoned-carts.js",
    "offer-whatsapp.js", "ai-admin.js",
  ]
  |> list.each(fn(name) {
    srcs
    |> list.any(fn(src) { string.contains(src, name) })
    |> should.be_false
  })
}

pub fn every_page_keeps_base_scripts_test() {
  let srcs = script_srcs(catalog_html())
  ["sidebar-tree.js", "sidebar-nav.js", "quick-search.js"]
  |> list.each(fn(name) {
    srcs
    |> list.any(fn(src) { string.contains(src, name) })
    |> should.be_true
  })
}

pub fn login_page_loads_only_base_scripts_test() {
  let html = panel.login_page("", "tr")
  let srcs = script_srcs(html)
  // Giriş sayfası yalnızca temel seti yükler (bölüm betiklerinden hiçbiri yok):
  ["sidebar-tree.js", "sidebar-nav.js", "quick-search.js"]
  |> list.each(fn(name) {
    srcs
    |> list.any(fn(src) { string.contains(src, name) })
    |> should.be_true
  })
  srcs
  |> list.any(fn(src) {
    string.contains(src, "admin.js") && !string.contains(src, "sidebar")
  })
  |> should.be_false
}

pub fn dashboard_loads_metrics_script_test() {
  let html = panel.section(admin_session, "Genel bakış", "intro", [], "tr", "")
  let srcs = script_srcs(html)
  // Dashboard metrikleri ayrı bir rota üzerinden dashboard section'ında yüklenir;
  // genel section sayfası yüklememeli.
  srcs
  |> list.any(fn(src) { string.contains(src, "dashboard-admin.js") })
  |> should.be_false
}

pub fn full_form_quick_nav_present_and_hidden_test() {
  let html = catalog_html()
  string.contains(html, "id=\"full-form-quick-nav\"")
  |> should.be_true
  // Varsayılan olarak gizli başlamalı (JS setMode('full') ile açılır).
  string.contains(html, "full-form-quick-nav hidden")
  |> should.be_true
  // Hedef paneller sec-1..sec-7 mevcut olmalı.
  ["sec-1", "sec-2", "sec-3", "sec-4", "sec-5", "sec-6", "sec-7"]
  |> list.each(fn(id) {
    string.contains(html, "id=\"" <> id <> "\"")
    |> should.be_true
  })
}

pub fn hotel_metadata_fields_match_js_expectations_test() {
  // listing-wizard.js meta doldurma alanları — panel ID'leri JS ile birebir
  // olmalı (input-airport-dist / input-checkin gibi kısaltmalar tarih oldu).
  let html = catalog_html()
  [
    "input-hotel-stars", "input-board-type", "input-beach-distance",
    "input-airport-distance", "input-pricing-model", "input-check-in",
    "input-check-out",
  ]
  |> list.each(fn(id) {
    string.contains(html, "id=\"" <> id <> "\"")
    |> should.be_true
  })
  // Eski yanlış ID'ler bir daha geri dönmemeli.
  ["input-airport-dist", "input-checkin", "input-checkout"]
  |> list.each(fn(stale) {
    string.contains(html, "id=\"" <> stale <> "\"")
    |> should.be_false
  })
}

pub fn topbar_and_search_trigger_present_test() {
  let html = catalog_html()
  ["topbar-search-trigger", "topbar-lang-btn", "topbar-lang-menu"]
  |> list.each(fn(id) {
    string.contains(html, "id=\"" <> id <> "\"")
    |> should.be_true
  })
}

pub fn wizard_action_buttons_present_test() {
  let html = catalog_html()
  [
    "btn-quick-draft", "btn-quick-publish", "btn-wizard-prev", "btn-wizard-next",
    "btn-wizard-submit", "wizard-progress-fill", "wizard-step-text",
    "wizard-stepper-wrap", "wizard-edit-mode-banner", "banner-listing-code",
    "banner-listing-title", "btn-cancel-edit-mode",
  ]
  |> list.each(fn(id) {
    string.contains(html, "id=\"" <> id <> "\"")
    |> should.be_true
  })
}

// ---- Tema (karanlık / aydınlık) sözleşmeleri ----
// tokens katmanı çift palet; düğme + boot script + stylesheet'ler yerinde kalmalı.

pub fn theme_toggle_button_present_test() {
  let html = catalog_html()
  // Tek toggle düğmesi: header'da karanlık/aydınlık işareti görünür.
  let has_toggle =
    string.contains(html, "id=\"theme-toggle\"")
    || string.contains(html, "id=\"theme-toggle-btn\"")
  has_toggle |> should.be_true
  // İki yönlü ikonlar yerinde (moon/sun) — auto varsayılan JS'te çözülür.
  string.contains(html, "theme-icon-dark") |> should.be_true
  string.contains(html, "theme-icon-light") |> should.be_true
}

pub fn theme_modules_served_in_core_css_test() {
  // Çift palet bu üç modülde yaşar; çekirdek settten çıkarılmamalı.
  let html = catalog_html()
  ["01-tokens.css", "02-base.css", "12-compact-responsive.css"]
  |> list.each(fn(name) {
    string.contains(html, "/static/css/" <> name)
    |> should.be_true
  })
}

pub fn theme_boot_script_applies_saved_preference_test() {
  // FOUC önleme: boot script kayıtlı tercihi ilk boyamadan önce uygular.
  // (Inline script kullanılamaz — lustre metin kaçışı JS'i bozar; dış dosya.)
  let html = catalog_html()
  string.contains(html, "/static/theme-boot.js")
  |> should.be_true
  // Boot script, tema stylesheet'lerinden ÖNCE gelmeli (parse aşamasında çalışır).
  let assert Ok(#(before_boot, _)) =
    string.split_once(html, "/static/theme-boot.js")
  string.contains(before_boot, "01-tokens.css")
  |> should.be_false
}
