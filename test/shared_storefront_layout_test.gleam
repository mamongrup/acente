import gleam/string
import gleeunit/should
import simplifile

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

pub fn root_uses_the_same_router_layout_as_public_pages_test() {
  let router = read_file("src/nexus_agency/router.gleam")
  router |> string.contains("demo_home_html") |> should.be_false
  router
  |> string.contains("handle_application_request(req, db, origin)")
  |> should.be_true
}

pub fn storefront_has_one_shared_header_and_footer_source_test() {
  let layout = read_file("src/nexus_agency/chisfis_layout.gleam")
  layout
  |> string.contains("pub fn chisfis_header(origin: String, q: String)")
  |> should.be_true
  layout
  |> string.contains("pub fn chisfis_footer(q: String)")
  |> should.be_true
}

pub fn catalog_and_categories_have_visible_chevrons_test() {
  let css = read_file("priv/static/chisfis-bridge.css")
  css |> string.contains("#popover-button-1::after") |> should.be_true
  css |> string.contains("#popover-button-2::after") |> should.be_true
  css
  |> string.contains("border-block-end: 1.5px solid currentColor")
  |> should.be_true
}

pub fn shared_search_and_microphone_stay_on_one_row_test() {
  let css = read_file("priv/static/chisfis-bridge.css")
  css
  |> string.contains(
    ".chisfis-header-root #nexus-header-search { display: flex; align-items: center; gap: 8px;",
  )
  |> should.be_true
  css
  |> string.contains(
    ".chisfis-header-root #nexus-header-search form { display: flex; align-items: center; flex: 1 1 auto; min-width: 0;",
  )
  |> should.be_true
}

pub fn shared_locale_icons_match_demo_without_icon_font_test() {
  let js = read_file("priv/static/chisfis/js/main.js")
  let demo = read_file("chisfis-final/index.html")
  let globe = "M12 21a9.004 9.004 0 0 0 8.716-6.747"
  let currency = "M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101"
  js |> string.contains("locale.dataset.sharedIconsReady") |> should.be_true
  js |> string.contains(globe) |> should.be_true
  demo |> string.contains(globe) |> should.be_true
  js |> string.contains(currency) |> should.be_true
  demo |> string.contains(currency) |> should.be_true
}
