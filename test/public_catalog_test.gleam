//// Public catalogue landing/detail contract.
////
//// The category list is shared with the control-panel catalogue. These
//// checks keep the public shell from silently losing a category or falling
//// back to the old "geliştirme aşamasında" alias pages.

import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const catalog_js_path = "priv/static/public-catalog.js"
const router_path = "src/nexus_agency/erl/nexus_agency@router_impl.erl"
const bridge_css_path = "priv/static/chisfis-bridge.css"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

fn contains_all(haystack: String, needles: List(String)) -> Bool {
  list.all(needles, fn(needle) { string.contains(haystack, needle) })
}

pub fn all_panel_categories_have_public_surfaces_test() {
  let source = read_file(catalog_js_path)
  contains_all(source, [
    "hotel: {",
    "holiday_home: {",
    "yacht: {",
    "tour: {",
    "activity: {",
    "flight: {",
    "bus: {",
    "transfer: {",
    "ferry: {",
    "car: {",
    "cruise: {",
    "pilgrimage: {",
    "visa: {",
    "beach: {",
    "cinema: {",
    "event: {",
    "restaurant: {",
    "category-directory-grid",
  ])
  |> should.be_true
}

pub fn legacy_category_aliases_use_real_landings_test() {
  let source = read_file(router_path)
  contains_all(source, [
    "{get, [~\"konaklama-kategoriler\"]} ->\n                    public_category_page(Req, Db, Origin, ~\"hotel\")",
    "{get, [~\"deneyimler\"]} ->\n                    public_category_page(Req, Db, Origin, ~\"tour\")",
    "{get, [~\"arac\"]} ->\n                    public_category_page(Req, Db, Origin, ~\"car\")",
    "{get, [~\"ucus\"]} ->\n                    public_category_page(Req, Db, Origin, ~\"flight\")",
    "{get, [~\"otobus\"]} ->\n                    public_category_page(Req, Db, Origin, ~\"bus\")",
  ])
  |> should.be_true
}

pub fn detail_shell_has_category_features_test() {
  let js = read_file(catalog_js_path)
  let css = read_file(bridge_css_path)
  contains_all(js, [".detail-columns", "category-feature-strip", "cfg.booking"]) |> should.be_true
  contains_all(css, [".category-feature-strip", ".category-directory-card.is-active"]) |> should.be_true
}
