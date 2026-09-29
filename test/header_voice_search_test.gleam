import gleam/string
import gleeunit/should
import simplifile

const header_js = "priv/static/chisfis/js/main.js"
const mobile_search_js = "priv/static/mobile-search-form.js"

const header_css = "priv/static/chisfis-bridge.css"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

pub fn microphone_uses_hugeicons_test() {
  read_file(header_js)
  |> string.contains("id=\"nexus-header-mic\"")
  |> should.be_false
  read_file(mobile_search_js)
  |> string.contains("hgi-mic-01")
  |> should.be_true
}

pub fn microphone_exposes_listening_state_test() {
  let js = read_file(mobile_search_js)
  js |> string.contains("SpeechRecognition") |> should.be_true
  js
  |> string.contains("button.setAttribute('aria-pressed', String(listening))")
  |> should.be_true
  read_file(header_css)
  |> string.contains(".nx-search-mic.is-listening")
  |> should.be_true
}
