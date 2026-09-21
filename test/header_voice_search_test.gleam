import gleam/string
import gleeunit/should
import simplifile

const header_js = "priv/static/chisfis/js/main.js"

const header_css = "priv/static/chisfis-bridge.css"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

pub fn microphone_uses_a_self_contained_svg_icon_test() {
  let js = read_file(header_js)
  js |> string.contains("id=\"nexus-header-mic\"") |> should.be_true
  js |> string.contains("hgi-mic-01") |> should.be_false
  js
  |> string.contains("M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Z")
  |> should.be_true
}

pub fn microphone_exposes_listening_state_test() {
  let js = read_file(header_js)
  js |> string.contains("SpeechRecognition") |> should.be_true
  js
  |> string.contains("headerMic.setAttribute('aria-pressed', 'true')")
  |> should.be_true
  js
  |> string.contains("headerMic.setAttribute('aria-pressed', 'false')")
  |> should.be_true
  read_file(header_css)
  |> string.contains("#nexus-header-mic.is-listening")
  |> should.be_true
}
