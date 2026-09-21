//// i18n completeness tests.
////
//// `i18n.t/2` falls back to echoing the key (`_, other -> other`) for every
//// unknown key, so a missing key in a language block prints raw key text on
//// real pages instead of failing loudly. These tests catch that at CI time:
//// for every key in the Turkish (default) set, every other language must
//// resolve to something that is NOT the raw key echo.

import gleam/io
import gleam/list
import gleam/string
import gleeunit/should
import nexus_agency/i18n

pub const languages = ["tr", "en", "de", "ru", "zh", "fr"]

const keys = [
  // Page/section titles
  "categories_header", "operations_header", "dashboard", "catalog",
  "catalog_inventory", "categories", "reports", "reservations", "offers",
  "abandoned_carts", "customers", "sub_agencies", "team", "campaigns", "popups",
  "cms", "ai", "integrations", "languages", "currencies", "settings", "logout",
  "search_quick", "tcmb_live", "regions", "media", "save", "welcome_eyebrow",
  // Panel headings + menu items (sidebar, mobile tab bar, topbar)
  "inquiries", "notification_center", "search_analytics", "mobile_menu", "menu_open",
  "lang_switch_label", "languages_aria", "section_supplier_campaigns",
  "section_fallback",
  // Dashboard metrics
  "metric_published", "metric_published_desc", "metric_pending",
  "metric_pending_desc", "metric_upcoming", "metric_upcoming_desc",
  "metric_nexus", "metric_nexus_desc",
  // Submenu items
  "sub_overview", "sub_listings", "sub_new", "sub_attributes", "sub_includes",
  "sub_rules", "sub_campaigns", "sub_themes", "sub_rooms", "sub_seo",
  "sub_availability", "sub_recovery", "sub_holiday_home_types",
  "sub_holiday_home_themes", "sub_faq_template",
  // cat_contracts / cat_subcategories
  "cat_contracts", "cat_subcategories",
  // 16 categories
  "cat_hotel", "cat_holiday_home", "cat_yacht", "cat_tour", "cat_flight_bus",
  "cat_activity", "cat_transfer", "cat_ferry", "cat_car", "cat_cruise",
  "cat_hajj", "cat_visa", "cat_sunbed", "cat_cinema", "cat_event",
  "cat_restaurant",
]

pub fn all_six_languages_recognized_test() {
  languages
  |> list.each(fn(lang) { i18n.normalize_lang(lang) |> should.equal(lang) })
}

pub fn unknown_lang_falls_back_to_turkish_test() {
  i18n.normalize_lang("xx") |> should.equal("tr")
}

pub fn every_key_resolves_in_every_language_test() {
  languages
  |> list.each(fn(lang) {
    keys
    |> list.each(fn(key) {
      let value = i18n.t(lang, key)
      string.contains(value, key)
      |> should.be_false
    })
  })
}

pub fn translations_are_not_empty_test() {
  languages
  |> list.each(fn(lang) {
    keys
    |> list.each(fn(key) {
      i18n.t(lang, key)
      |> string.is_empty
      |> should.be_false
    })
  })
}

pub fn translations_are_not_english_copies_in_other_langs_test() {
  // A copy-pasted English value in e.g. the German block is a translation gap;
  // whitelist only keys whose value is legitimately identical in some languages
  // (loanwords, brand-ish terms, acronyms).
  let neutral = [
    "cat_hotel", "cat_transfer", "cat_tour", "cat_yacht", "cat_ferry",
    "cat_visa", "sub_seo", "cms",
  ]
  let failures =
    languages
    |> list.filter(fn(lang) { lang != "en" })
    |> list.flat_map(fn(lang) {
      keys
      |> list.filter(fn(key) { !list.contains(neutral, key) })
      |> list.filter(fn(key) { i18n.t("en", key) == i18n.t(lang, key) })
      |> list.map(fn(key) { lang <> "/" <> key })
    })
  case failures {
    [] -> Nil
    _ -> {
      io.println("EN-identical translations: " <> string.join(failures, ", "))
      should.fail()
    }
  }
}

pub fn arabic_is_rtl_others_are_not_test() {
  i18n.is_rtl("ar") |> should.be_true
  languages
  |> list.filter(fn(lang) { lang != "ar" })
  |> list.each(fn(lang) { i18n.is_rtl(lang) |> should.be_false })
}

pub fn rtl_marker_used_for_arabic_pages_test() {
  // The layout emits dir="rtl" only for Arabic.
  let dir = case i18n.is_rtl("ar") {
    True -> "rtl"
    False -> "ltr"
  }
  dir |> should.equal("rtl")
  i18n.normalize_lang("ar") |> should.equal("ar")
}

pub fn every_language_has_a_flag_and_name_test() {
  languages
  |> list.each(fn(lang) {
    i18n.flag_icon(lang)
    |> string.is_empty
    |> should.be_false
    i18n.lang_name(lang)
    |> string.is_empty
    |> should.be_false
  })
}

pub fn supported_languages_list_matches_language_set_test() {
  let supported =
    i18n.supported_languages()
    |> list.map(fn(triple) {
      let #(code, _flag, _name) = triple
      code
    })
  supported |> should.equal(languages)
}

pub fn campaign_label_varies_by_language_test() {
  let labels =
    languages
    |> list.map(fn(lang) { i18n.campaign_label(lang, "cat_hotel") })
  list.length(list.unique(labels)) |> should.equal(6)
}

pub fn campaign_label_includes_category_name_test() {
  let label = i18n.campaign_label("de", "cat_hotel")
  string.contains(label, i18n.t("de", "cat_hotel")) |> should.be_true
}
