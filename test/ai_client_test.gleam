//// AI client tests.
////
//// Pure, network-free tests: the JSON response parsers, model defaults, and
//// the graceful no-api-key fallback contract. `post_json` is never reached
//// because these paths either parse already-captured response bodies or
//// short-circuit on the empty API key.

import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string
import gleeunit/should
import nexus_agency/ai_client.{type AIConfig, AIConfig}

fn cfg() -> AIConfig {
  AIConfig(provider: "openai", api_key: "", model: "")
}

// --- Gemini response parsing -------------------------------------------------

pub fn gemini_happy_path_test() {
  let raw =
    json.object([
      #(
        "candidates",
        json.array(
          [
            json.object([
              #(
                "content",
                json.object([
                  #(
                    "parts",
                    json.array(
                      [
                        json.object([
                          #("text", json.string("<h2>Merhaba</h2>")),
                        ]),
                      ],
                      of: fn(x) { x },
                    ),
                  ),
                ]),
              ),
            ]),
          ],
          of: fn(x) { x },
        ),
      ),
    ])
    |> json.to_string

  let assert Ok(text) = ai_client.parse_gemini_response(raw)
  text |> should.equal("<h2>Merhaba</h2>")
}

pub fn gemini_uses_first_part_and_candidate_test() {
  let raw =
    "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"first\"},{\"text\":\"second\"}]}}]}"
  let assert Ok(text) = ai_client.parse_gemini_response(raw)
  text |> should.equal("first")
}

pub fn gemini_empty_candidates_yields_empty_string_test() {
  let assert Ok(text) = ai_client.parse_gemini_response("{\"candidates\":[]}")
  text |> should.equal("")
}

pub fn gemini_error_payload_is_passed_through_test() {
  let raw = "{\"error\":{\"code\":429,\"message\":\"rate limited\"}}"
  let assert Error(message) = ai_client.parse_gemini_response(raw)
  string.contains(message, "rate limited") |> should.be_true
}

pub fn gemini_unparseable_body_gives_turkish_error_test() {
  let assert Error(message) = ai_client.parse_gemini_response("not json at all")
  string.contains(message, "çözümlenemedi") |> should.be_true
}

// --- OpenAI-compatible (DeepSeek/OpenAI) response parsing --------------------

pub fn openai_happy_path_test() {
  let raw =
    "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"OK\"}}]}"
  let assert Ok(text) = ai_client.parse_openai_compatible_response(raw)
  text |> should.equal("OK")
}

pub fn openai_uses_first_choice_test() {
  let raw =
    "{\"choices\":[{\"message\":{\"content\":\"a\"}},{\"message\":{\"content\":\"b\"}}]}"
  let assert Ok(text) = ai_client.parse_openai_compatible_response(raw)
  text |> should.equal("a")
}

pub fn openai_empty_choices_yields_empty_string_test() {
  // Matches the Gemini parser contract: an empty list degrades to "" rather
  // than an error.
  let assert Ok(text) =
    ai_client.parse_openai_compatible_response("{\"choices\":[]}")
  text |> should.equal("")
}

pub fn openai_invalid_json_error_includes_raw_body_test() {
  let assert Error(message) =
    ai_client.parse_openai_compatible_response("gateway timeout html")
  string.contains(message, "gateway timeout html") |> should.be_true
}

// --- Model defaults -----------------------------------------------------------

pub fn default_model_per_provider_test() {
  ai_client.default_model("deepseek") |> should.equal("deepseek-chat")
  ai_client.default_model("openai") |> should.equal("gpt-4o-mini")
  ai_client.default_model("gemini") |> should.equal("gemini-2.5-flash")
  ai_client.default_model("google") |> should.equal("gemini-2.5-flash")
  ai_client.default_model("mystery") |> should.equal("gemini-2.5-flash")
}

pub fn default_model_is_case_and_space_insensitive_test() {
  ai_client.default_model("  DeepSeek ") |> should.equal("deepseek-chat")
  ai_client.default_model("OpenAI") |> should.equal("gpt-4o-mini")
}

// --- Graceful no-api-key fallback contract ------------------------------------
// call_llm short-circuits to Error("no_api_key") before any HTTP call, and the
// high-level operations degrade instead of failing.

pub fn call_llm_without_api_key_errors_test() {
  let assert Error("no_api_key") = ai_client.call_llm(cfg(), "system", "user")
  Nil
}

pub fn description_falls_back_without_api_key_test() {
  let assert Ok(html) =
    ai_client.generate_description(cfg(), "villa", "Villa Deniz", "3 oda", "tr")
  string.contains(html, "Villa Deniz") |> should.be_true
}

pub fn seo_falls_back_without_api_key_test() {
  let assert Ok(#(title, description, keywords)) =
    ai_client.generate_seo(cfg(), "hotel", "Otel Palmiye", "Denize yakın")
  string.contains(title, "Otel Palmiye") |> should.be_true
  string.contains(description, "Otel Palmiye") |> should.be_true
  string.contains(keywords, ",") |> should.be_true
}

pub fn translation_returns_source_without_api_key_test() {
  let assert Ok(text) =
    ai_client.translate_content(cfg(), "<p>Deniz manzarası</p>", "tr", "en")
  text |> should.equal("<p>Deniz manzarası</p>")
}

pub fn listing_translation_fallback_is_valid_json_test() {
  let assert Ok(raw) =
    ai_client.translate_listing_all(cfg(), "Villa Gül", "<p>Havuzlu</p>")
  let decoder = {
    use en <- decode.field("en", lang_decoder())
    use de <- decode.field("de", lang_decoder())
    use ru <- decode.field("ru", lang_decoder())
    use zh <- decode.field("zh", lang_decoder())
    use fr <- decode.field("fr", lang_decoder())
    decode.success([en, de, ru, zh, fr])
  }
  let assert Ok(langs) = json.parse(raw, decoder)
  // Every language object must exist with title and description.
  langs
  |> list.each(fn(obj) {
    dict.get(obj, "title") |> should.be_ok
    dict.get(obj, "description") |> should.be_ok
  })
}

fn lang_decoder() {
  decode.dict(decode.string, decode.string)
}
