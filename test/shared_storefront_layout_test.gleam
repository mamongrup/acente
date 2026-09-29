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
  |> string.contains("handle_application_request(correlated_req, db, origin)")
  |> should.be_true
}

pub fn storefront_has_one_shared_header_and_footer_source_test() {
  let layout = read_file("src/nexus_agency/chisfis_layout.gleam")
  layout
  |> string.contains("pub fn chisfis_header(origin: String, q: String)")
  |> should.be_true
  layout
  |> string.contains("pub fn chisfis_footer(_q: String)")
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

pub fn shared_header_search_stays_on_one_row_test() {
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
  read_file("priv/static/chisfis/js/main.js")
  |> string.contains("id=\"nexus-header-mic\"")
  |> should.be_false
}

pub fn shared_locale_icons_use_hugeicons_test() {
  let js = read_file("priv/static/chisfis/js/main.js")
  js |> string.contains("locale.dataset.sharedIconsReady") |> should.be_true
  js |> string.contains("hgi-globe size-5") |> should.be_true
  js |> string.contains("hgi-money-01 size-5") |> should.be_true
}
