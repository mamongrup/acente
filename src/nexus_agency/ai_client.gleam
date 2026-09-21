import gleam/dynamic/decode
import gleam/json
import gleam/string
import gleam/uri

@external(erlang, "agency_ffi_http", "post_json_with_timeout")
pub fn post_json(
  url: String,
  body: String,
  auth_header: String,
  timeout_ms: Int,
) -> Result(String, String)

pub type AIConfig {
  AIConfig(provider: String, api_key: String, model: String)
}

pub fn default_model(provider: String) -> String {
  case string.lowercase(string.trim(provider)) {
    "deepseek" -> "deepseek-chat"
    "google" | "gemini" -> "gemini-2.5-flash"
    "openai" -> "gpt-4o-mini"
    _ -> "gemini-2.5-flash"
  }
}

fn category_rules(category: String) -> String {
  case string.lowercase(string.trim(category)) {
    "villa" | "holiday_home" ->
      "Kategori: Tatil Evi / Villa. Kapasite, oda sayısı, havuz (açık/ısıtmalı/korunaklı), bahçe, manzara ve konfor özelliklerini öne çıkar. Başlık için sadece villa adını kullan. Metinde kısa paragraflar ve <h2>, <h3>, <ul>, <li> etiketleri kullan."
    "hotel" | "otel" ->
      "Kategori: Otel. Yıldız sınıfı, oda tipleri, pansiyon türü (UAI, AI vb.), plaj/deniz mesafesi, havuz, spa ve gastronomi olanaklarını vurgula. Fiyat ve iptal gibi değişken şartları uydurma."
    "yacht" | "tekne" ->
      "Kategori: Yat & Tekne Kiralama. Tekne tipi (gulet, motoryat vb.), kabin ve misafir kapasitesi, kalkış limanı, rota, mürettebat ve seyir konforunu anlat."
    "tour" | "tur" ->
      "Kategori: Tur & Gezi. Tur süresi, kalkış noktaları, rota durakları, rehberlik hizmeti, dahil ve hariç olan hizmetleri düzenli listelerle belirt."
    "activity" | "aktivite" ->
      "Kategori: Aktivite & Macera. Seans saatleri, süre, yaş/kilo gereksinimleri, ekipman ve güvenlik standartlarını vurgula."
    "car" | "arac" ->
      "Kategori: Araç Kiralama. Araç segmenti, vites ve yakıt tipi, teslimat kolaylığı, kasko ve sürüş konforunu öne çıkar."
    "transfer" ->
      "Kategori: VIP Transfer. Karşılama, havalimanı/otel güzergahı, araç sınıfı (VIP Vito vb.), dakiklik ve sabit fiyat güvencesini anlat."
    _ ->
      "Kategori: Seyahat & Konaklama Ürünü. Konuk deneyimi, konfor, lokasyon ve güvenilirlik unsurlarını profesyonel bir dille açıkla."
  }
}

// ---------------------------------------------------------------------------
// Google Gemini Client
// ---------------------------------------------------------------------------

fn call_gemini(
  api_key: String,
  model: String,
  system_prompt: String,
  user_prompt: String,
) -> Result(String, String) {
  let m = case string.trim(model) {
    "" -> "gemini-2.5-flash"
    x -> x
  }
  let url =
    "https://generativelanguage.googleapis.com/v1beta/models/"
    <> m
    <> ":generateContent?key="
    <> uri.percent_encode(string.trim(api_key))

  let payload =
    json.object([
      #(
        "systemInstruction",
        json.object([
          #(
            "parts",
            json.array(
              [json.object([#("text", json.string(system_prompt))])],
              of: fn(x) { x },
            ),
          ),
        ]),
      ),
      #(
        "contents",
        json.array(
          [
            json.object([
              #("role", json.string("user")),
              #(
                "parts",
                json.array(
                  [json.object([#("text", json.string(user_prompt))])],
                  of: fn(x) { x },
                ),
              ),
            ]),
          ],
          of: fn(x) { x },
        ),
      ),
      #(
        "generationConfig",
        json.object([
          #("temperature", json.float(0.7)),
          #("maxOutputTokens", json.int(2048)),
        ]),
      ),
    ])
    |> json.to_string

  case post_json(url, payload, "", 35_000) {
    Ok(resp_str) -> parse_gemini_response(resp_str)
    Error(err) -> Error("Gemini API hatası: " <> err)
  }
}

fn text_from_gemini_decoder() -> decode.Decoder(String) {
  decode.field(
    "candidates",
    decode.list(
      decode.field(
        "content",
        decode.field(
          "parts",
          decode.list(
            decode.field("text", decode.string, fn(t) { decode.success(t) }),
          ),
          fn(parts) {
            case parts {
              [first, ..] -> decode.success(first)
              [] -> decode.success("")
            }
          },
        ),
        fn(text) { decode.success(text) },
      ),
    ),
    fn(texts) {
      case texts {
        [first, ..] -> decode.success(first)
        [] -> decode.success("")
      }
    },
  )
}

pub fn parse_gemini_response(raw: String) -> Result(String, String) {
  case json.parse(raw, text_from_gemini_decoder()) {
    Ok(first_part) -> Ok(first_part)
    Error(_) -> {
      case string.contains(raw, "error") {
        True -> Error(raw)
        False -> Error("Gemini yanıtı çözümlenemedi")
      }
    }
  }
}

// ---------------------------------------------------------------------------
// DeepSeek Client
// ---------------------------------------------------------------------------

fn call_deepseek(
  api_key: String,
  model: String,
  system_prompt: String,
  user_prompt: String,
) -> Result(String, String) {
  let m = case string.trim(model) {
    "" -> "deepseek-chat"
    x -> x
  }
  let url = "https://api.deepseek.com/chat/completions"
  let auth = "Bearer " <> string.trim(api_key)

  let payload =
    json.object([
      #("model", json.string(m)),
      #(
        "messages",
        json.array(
          [
            json.object([
              #("role", json.string("system")),
              #("content", json.string(system_prompt)),
            ]),
            json.object([
              #("role", json.string("user")),
              #("content", json.string(user_prompt)),
            ]),
          ],
          of: fn(x) { x },
        ),
      ),
      #("temperature", json.float(0.7)),
      #("max_tokens", json.int(2048)),
    ])
    |> json.to_string

  case post_json(url, payload, auth, 40_000) {
    Ok(resp_str) -> parse_openai_compatible_response(resp_str)
    Error(err) -> Error("DeepSeek API hatası: " <> err)
  }
}

fn text_from_openai_decoder() -> decode.Decoder(String) {
  decode.field(
    "choices",
    decode.list(
      decode.field(
        "message",
        decode.field("content", decode.string, fn(c) { decode.success(c) }),
        fn(m) { decode.success(m) },
      ),
    ),
    fn(choices) {
      case choices {
        [first, ..] -> decode.success(first)
        [] -> decode.success("")
      }
    },
  )
}

pub fn parse_openai_compatible_response(raw: String) -> Result(String, String) {
  case json.parse(raw, text_from_openai_decoder()) {
    Ok(first_choice) -> Ok(first_choice)
    Error(_) -> Error("AI yanıtı okunamadı: " <> raw)
  }
}

// ---------------------------------------------------------------------------
// Universal LLM Dispatcher
// ---------------------------------------------------------------------------

pub fn call_llm(
  cfg: AIConfig,
  system_prompt: String,
  user_prompt: String,
) -> Result(String, String) {
  case string.trim(cfg.api_key) {
    "" -> Error("no_api_key")
    _ -> {
      case string.lowercase(string.trim(cfg.provider)) {
        "deepseek" ->
          call_deepseek(cfg.api_key, cfg.model, system_prompt, user_prompt)
        "openai" ->
          call_deepseek(cfg.api_key, cfg.model, system_prompt, user_prompt)
        _ -> call_gemini(cfg.api_key, cfg.model, system_prompt, user_prompt)
      }
    }
  }
}

// ---------------------------------------------------------------------------
// High-Level AI Operations
// ---------------------------------------------------------------------------

pub fn generate_description(
  cfg: AIConfig,
  category: String,
  title: String,
  attributes_summary: String,
  lang: String,
) -> Result(String, String) {
  let sys =
    "Sen lüks turizm ve seyahat sektöründe uzmanlaşmış, dönüşüm oranı (conversion rate) odaklı profesyonel bir içerik editörüsün. "
    <> "Verilen ürün bilgilerini akıcı, davetkar, kolay taranabilir semantik HTML (<h2>, <h3>, <p>, <ul>, <li>) formatında yaz. "
    <> "Asla uydurma iptal/iade şartı veya kesin olmayan fiyat yazma. Yalnızca belirtilen özellikleri zenginleştir. "
    <> category_rules(category)
    <> " Çıktıyı doğrudan HTML olarak ver, markdown backtick (```html) bloğu içine alma."

  let user =
    "Başlık: "
    <> title
    <> "\nKategori: "
    <> category
    <> "\nÖzellikler:\n"
    <> attributes_summary
    <> "\nHedef Dil: "
    <> lang

  case call_llm(cfg, sys, user) {
    Ok(text) -> Ok(clean_html_fences(text))
    Error("no_api_key") -> Ok(fallback_description(title))
    Error(e) -> Error(e)
  }
}

pub fn generate_seo(
  cfg: AIConfig,
  category: String,
  title: String,
  description: String,
) -> Result(#(String, String, String), String) {
  let sys =
    "Sen seyahat ve turizm alanında Google SEO uzmanısın. Verilen ilanı analiz ederek yüksek arama hacimli, tıklama çeken meta verileri üret. "
    <> "Yanıtını YALNIZCA geçerli bir JSON olarak ver. Format: {\"title\": \"Max 60 Karakter Başlık\", \"description\": \"Max 155 Karakter Çekici Açıklama\", \"keywords\": \"virgülle, ayrılmış, 6-8, anahtar, kelime\"}. Başka hiçbir metin yazma."

  let user =
    "Başlık: "
    <> title
    <> "\nKategori: "
    <> category
    <> "\nAçıklama: "
    <> string.slice(description, 0, 500)

  case call_llm(cfg, sys, user) {
    Ok(raw_json) -> {
      let decoder = {
        use t <- decode.field("title", decode.string)
        use d <- decode.field("description", decode.string)
        use k <- decode.field("keywords", decode.string)
        decode.success(#(t, d, k))
      }
      let cleaned = clean_json_fences(raw_json)
      case json.parse(cleaned, decoder) {
        Ok(tup) -> Ok(tup)
        Error(_) -> Ok(fallback_seo(title))
      }
    }
    Error("no_api_key") -> Ok(fallback_seo(title))
    Error(e) -> Error(e)
  }
}

pub fn translate_content(
  cfg: AIConfig,
  source_text: String,
  source_lang: String,
  target_lang: String,
) -> Result(String, String) {
  let sys =
    "Sen profesyonel bir turizm ve seyahat çevirmenisin. Metni "
    <> source_lang
    <> " dilinden "
    <> target_lang
    <> " diline ana dili seviyesinde akıcı, doğal ve bağlama uygun olarak çevir. HTML etiketlerini (<h2>, <p>, <ul>, <li>, <strong> vb.) olduğu gibi koru, yalnızca metinleri çevir. Markdown bloğu kullanma."
  let user = "Metin:\n" <> source_text

  case call_llm(cfg, sys, user) {
    Ok(res) -> Ok(clean_html_fences(res))
    Error("no_api_key") -> Ok(source_text)
    Error(e) -> Error(e)
  }
}

pub fn translate_listing_all(
  cfg: AIConfig,
  title: String,
  description: String,
) -> Result(String, String) {
  let sys =
    "Sen seyahat ve turizm platformları için uzman çok dilli yerelleştirme yapay zekasısın. "
    <> "Verilen Türkçe ilan başlığını ve HTML açıklamasını [en, de, ru, zh, fr] dillerine profesyonelce çevir. "
    <> "Yanıtını YALNIZCA geçerli bir JSON objesi olarak ver. "
    <> "Format: {\"en\": {\"title\": \"...\", \"description\": \"...\"}, \"de\": {\"title\": \"...\", \"description\": \"...\"}, \"ru\": {\"title\": \"...\", \"description\": \"...\"}, \"zh\": {\"title\": \"...\", \"description\": \"...\"}, \"fr\": {\"title\": \"...\", \"description\": \"...\"}}. "
    <> "HTML etiketlerini koru, yalnızca metinleri çevir. Markdown bloğu veya açıklama yazma."

  let user =
    "Başlık:\n"
    <> title
    <> "\n\nAçıklama:\n"
    <> string.slice(description, 0, 1500)

  case call_llm(cfg, sys, user) {
    Ok(res) -> Ok(clean_json_fences(res))
    Error("no_api_key") -> Ok(fallback_translations_json(title, description))
    Error(e) -> Error(e)
  }
}

fn fallback_translations_json(title: String, description: String) -> String {
  let safe_title = string.replace(title, "\"", "\\\"")
  let safe_desc =
    string.replace(string.slice(description, 0, 300), "\"", "\\\"")
  "{\"en\":{\"title\":\""
  <> safe_title
  <> "\",\"description\":\""
  <> safe_desc
  <> "\"},\"de\":{\"title\":\""
  <> safe_title
  <> "\",\"description\":\""
  <> safe_desc
  <> "\"},\"ru\":{\"title\":\""
  <> safe_title
  <> "\",\"description\":\""
  <> safe_desc
  <> "\"},\"zh\":{\"title\":\""
  <> safe_title
  <> "\",\"description\":\""
  <> safe_desc
  <> "\"},\"fr\":{\"title\":\""
  <> safe_title
  <> "\",\"description\":\""
  <> safe_desc
  <> "\"}}"
}

pub fn test_connection(cfg: AIConfig) -> Result(String, String) {
  let sys = "Sen seyahat platformu AI denetleyicisisin."
  let user = "Bağlantı testi. Sadece 'OK' yanıtını ver."
  case call_llm(cfg, sys, user) {
    Ok(resp) -> Ok(string.trim(resp))
    Error(e) -> Error(e)
  }
}

// ---------------------------------------------------------------------------
// Helpers & Graceful Fallbacks
// ---------------------------------------------------------------------------

fn clean_html_fences(s: String) -> String {
  let t = string.trim(s)
  case string.starts_with(t, "```html") {
    True ->
      string.replace(t, "```html", "")
      |> string.replace("```", "")
      |> string.trim
    False ->
      case string.starts_with(t, "```") {
        True -> string.replace(t, "```", "") |> string.trim
        False -> t
      }
  }
}

fn clean_json_fences(s: String) -> String {
  let t = string.trim(s)
  case string.starts_with(t, "```json") {
    True ->
      string.replace(t, "```json", "")
      |> string.replace("```", "")
      |> string.trim
    False ->
      case string.starts_with(t, "```") {
        True -> string.replace(t, "```", "") |> string.trim
        False -> t
      }
  }
}

fn fallback_description(title: String) -> String {
  "<h2>"
  <> title
  <> " ile Unutulmaz Bir Tatil Deneyimi</h2>\n"
  <> "<p>Bölgenin en seçkin lokasyonlarından birinde yer alan tesisimiz, konfor ve huzuru bir arada sunmak için özenle tasarlanmıştır.</p>\n"
  <> "<h3>Öne Çıkan Özellikler</h3>\n"
  <> "<ul>\n"
  <> "  <li>Konforlu ve modern yaşam alanları</li>\n"
  <> "  <li>Merkezi ve ulaşımı kolay seçkin lokasyon</li>\n"
  <> "  <li>NEXUS Acente güvencesi ile doğrudan rezervasyon</li>\n"
  <> "  <li>Hızlı ve güvenilir rezervasyon onayı</li>\n"
  <> "</ul>\n"
  <> "<p>Detaylı bilgi, müsaitlik takvimi ve anında rezervasyon için tarih seçerek işlemlerinizi tamamlayabilirsiniz.</p>"
}

fn fallback_seo(title: String) -> #(String, String, String) {
  #(
    title <> " | En Uygun Fiyat Garantisi - NEXUS",
    title
      <> " için hemen rezervasyon yapın. Erken rezervasyon fırsatları, güvenli ödeme ve acente güvencesiyle unutulmaz tatil sizi bekliyor.",
    "rezervasyon, tatil, otel, villa kiralama, en uygun fiyat, acente",
  )
}
