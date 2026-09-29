import gleam/dynamic/decode
import gleam/int
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

pub fn generate_social_post(
  cfg: AIConfig,
  network: String,
  category: String,
  title: String,
  description_snippet: String,
  lang: String,
  tone: String,
) -> Result(String, String) {
  let net = string.lowercase(string.trim(network))
  let platform_rules = case net {
    "instagram" ->
      "Platform: Instagram. İlk 1-2 satırda merak uyandıran güçlü bir kanca (hook), seyahat emojileri, akıcı satır aralıkları, net bir harekete geçirici mesaj (Örn: 'Detaylar ve rezervasyon için profildeki linke tıklayın! 👆') ve en sonda 5-8 adet popüler, keşfete düşüren seyahat etiketi (#villa #tatil #antalya vb.) ekle."
    "threads" ->
      "Platform: Threads. Samimi, sohbet başlatan, soru soran veya deneyim anlatan kısa ve etkileyici bir ton kullan. Fazla hashtag doldurma (en fazla 2-3 adet)."
    "facebook" ->
      "Platform: Facebook. Detaylı, bilgilendirici, ailelere ve tatilcilere güven aşılayan, doğrudan web sitesi linkine davet eden samimi bir anlatım ve 3-4 etiket kullan."
    "pinterest" ->
      "Platform: Pinterest. İlham verici, görsel odaklı, estetik ve dekorasyon/manzara detaylarını öne çıkaran bir açıklama yaz (Örn: 'Hayalinizdeki balayı villası...'). 4-6 anahtar kelime etiketi kullan."
    _ ->
      "Platform: Sosyal Medya. Dikkat çekici, profesyonel, emojili ve rezervasyona yönlendirici bir sosyal medya metni hazırla."
  }

  let tone_rules = case string.lowercase(string.trim(tone)) {
    "luxury" -> "Ton: Ultra lüks, prestijli, ayrıcalıklı ve konfor odaklı."
    "romantic" -> "Ton: Romantik, balayı çiftlerine özel, büyüleyici ve huzur dolu."
    "adventurous" -> "Ton: Heyecan verici, maceracı, dinamik ve enerjik."
    _ -> "Ton: Çekici, samimi, güven veren ve fırsat odaklı."
  }

  let sys =
    "Sen lüks seyahat ve turizm alanında viral içerikler üreten ödüllü bir sosyal medya stratejistisin. "
    <> "Verilen ilanı sosyal medyada en yüksek etkileşim, beğeni ve rezervasyon dönüşümü alacak şekilde uyarla. "
    <> platform_rules
    <> " "
    <> tone_rules
    <> " "
    <> category_rules(category)
    <> " Sadece paylaşılmaya hazır gönderi metnini yaz, markdown backtick (```) bloğu içine alma, doğrudan paylaşım metnini ver."

  let user =
    "İlan Başlığı: "
    <> title
    <> "\nKategori: "
    <> category
    <> "\nDetay Özeti: "
    <> string.slice(description_snippet, 0, 500)
    <> "\nHedef Dil: "
    <> lang

  case call_llm(cfg, sys, user) {
    Ok(text) -> Ok(string.trim(clean_html_fences(text)))
    Error("no_api_key") -> Ok(fallback_social_post(net, title, category))
    Error(e) -> Error(e)
  }
}

pub fn generate_campaign_offer(
  cfg: AIConfig,
  campaign_name: String,
  channel: String,
  benefit: String,
  audience: String,
  lang: String,
) -> Result(String, String) {
  let sys =
    "Sen seyahat pazarlamasında uzman bir kampanya kurgulayıcısısın. "
    <> "Verilen kampanya bilgilerine göre "
    <> channel
    <> " kanalına uygun, tıklama ve dönüşüm sağlayan çekici bir pazarlama mesajı üret. "
    <> "Hedef kitle: "
    <> audience
    <> ". Hedef Dil: "
    <> lang
    <> ". Doğrudan metni ver, ek açıklama ekleme."

  let user =
    "Kampanya Adı: "
    <> campaign_name
    <> "\nKanal: "
    <> channel
    <> "\nAvantaj/İndirim: "
    <> benefit

  case call_llm(cfg, sys, user) {
    Ok(text) -> Ok(string.trim(text))
    Error("no_api_key") ->
      Ok("🎉 " <> campaign_name <> ": " <> benefit <> " fırsatını kaçırmayın! Hemen rezervasyon yapın.")
    Error(e) -> Error(e)
  }
}

pub fn parse_concierge_query(
  cfg: AIConfig,
  query: String,
) -> Result(String, String) {
  let sys =
    "Sen NEXUS Seyahat Platformunun akıllı seyahat danışmanısın. "
    <> "Kullanıcının doğal dildeki tatil/seyahat arama sorgusunu analiz et. "
    <> "Kanonik 17 ana kategoriden en uygun olanını seç: [hotel, holiday_home, yacht, tour, activity, flight, car, cruise, pilgrimage, visa, ferry, transfer, beach, cinema, event, restaurant, bus]. "
    <> "Villa/apart arayanlar için 'holiday_home', tekne/gulet arayanlar için 'yacht' seç. "
    <> "JSON formatında yanıt ver: {\"category\": \"...\", \"locality\": \"...\", \"summary\": \"...\", \"keywords\": [\"...\"]}. "
    <> "Sadece JSON objesini döndür, markdown veya ek metin yazma."

  let user = "Arama Sorgusu: " <> query

  case call_llm(cfg, sys, user) {
    Ok(text) -> Ok(clean_json_fences(text))
    Error("no_api_key") -> Ok(fallback_concierge_json(query))
    Error(e) -> Error(e)
  }
}

pub fn extract_listing_specs(
  cfg: AIConfig,
  category: String,
  raw_text: String,
) -> Result(String, String) {
  let cat = string.lowercase(string.trim(category))
  let sys =
    "Sen seyahat ve konaklama ilanları için uzman veri çıkarma yapay zekasısın. "
    <> "Verilen serbest metin veya broşür notlarından, "
    <> cat
    <> " kategorisine ait standart sözleşme alanlarını JSON olarak çıkar. "
    <> "Örnek alanlar: title, locality, property_type, bedroom_count, bathroom_count, guest_capacity, price_estimate, features (dizi). "
    <> "Sadece geçerli bir JSON objesi döndür, markdown bloğu kullanma."

  let user = "İlan Notları:\n" <> raw_text

  case call_llm(cfg, sys, user) {
    Ok(text) -> Ok(clean_json_fences(text))
    Error("no_api_key") -> Ok(fallback_listing_specs(category, raw_text))
    Error(e) -> Error(e)
  }
}

pub fn generate_inquiry_reply(
  cfg: AIConfig,
  customer_name: String,
  message: String,
  listing_title: String,
  category: String,
  policy_rules: String,
) -> Result(String, String) {
  let sys =
    "Sen profesyonel, kibar ve çözüm odaklı bir seyahat acentesi müşteri temsilcisisin. "
    <> "Müşteriden gelen rezervasyon talebine/sorusuna ilanın kurallarını ve özelliklerini göz önünde bulundurarak yanıt yaz. "
    <> "Müşteriye ismiyle hitap et, sorusunu net biçimde cevapla, güven ver ve rezervasyonu tamamlamaya davet et. "
    <> "Sadece gönderilecek mesaj metnini yaz, ek açıklama ekleme."

  let user =
    "Müşteri: "
    <> customer_name
    <> "\nİlan: "
    <> listing_title
    <> " ("
    <> category
    <> ")\nKurallar/Politikalar: "
    <> policy_rules
    <> "\nMüşteri Mesajı: "
    <> message

  case call_llm(cfg, sys, user) {
    Ok(text) -> Ok(string.trim(clean_html_fences(text)))
    Error("no_api_key") -> Ok(fallback_inquiry_reply(customer_name, listing_title))
    Error(e) -> Error(e)
  }
}

pub fn generate_destination_guide(
  cfg: AIConfig,
  destination: String,
  category: String,
  lang: String,
) -> Result(String, String) {
  let sys =
    "Sen ödüllü bir seyahat yazarı ve SEO içerik uzmanısın. "
    <> destination
    <> " bölgesi ve "
    <> category
    <> " tatil türü için arama motorlarında üst sıralara çıkacak, ziyaretçilere ilham veren ve acente rezervasyonuna yönlendiren zengin bir gezi rehberi hazırla. "
    <> "HTML formatında başlıklar (<h2>, <h3>), akıcı paragraflar (<p>) ve maddeleme listeleri (<ul>, <li>) kullan. "
    <> "Dil: "
    <> lang
    <> ". Sadece HTML içeriğini döndür, markdown bloğu kullanma."

  let user = "Destinasyon: " <> destination <> "\nKategori: " <> category

  case call_llm(cfg, sys, user) {
    Ok(text) -> Ok(clean_html_fences(text))
    Error("no_api_key") -> Ok(fallback_destination_guide(destination, category))
    Error(e) -> Error(e)
  }
}

pub fn test_connection(cfg: AIConfig) -> Result(String, String) {
  let sys = "Sen seyahat platformu AI denetleyicisisin."
  let user = "Bağlantı testi. Sadece 'OK' yanıtını ver."
  case call_llm(cfg, sys, user) {
    Ok(resp) -> Ok(string.trim(resp))
    Error(e) -> Error(e)
  }
}

fn fallback_social_post(network: String, title: String, category: String) -> String {
  case network {
    "instagram" ->
      "✨ Hayalinizdeki tatil burada başlıyor: "
      <> title
      <> " 🌊\n\nKonfor, huzur ve unutulmaz anılar için yerinizi hemen ayırtın! Özel fırsatlar ve erken rezervasyon avantajları sizi bekliyor.\n\n👉 Detaylar ve online rezervasyon için profilimizdeki linke göz atın!\n\n#tatil #seyahat #rezervasyon #"
      <> string.lowercase(string.trim(category))
      <> " #turizm #gezilecekyerler"
    "threads" ->
      "Bavulları hazırlama vakti geldi mi? "
      <> title
      <> " için sezonun en özel tarihleri açıldı. Bu manzarada kiminle olmak isterdiniz? 🌴 #tatil"
    "pinterest" ->
      title
      <> " · Tatil Rotası & Konaklama Fikirleri. Eşsiz bir seyahat deneyimi için keşfedin ve panonuza kaydedin! 📌 #tatilfikirleri #seyahat"
    _ ->
      "🎉 "
      <> title
      <> " ile unutulmaz bir deneyime hazır olun! Erken rezervasyon fırsatlarıyla hemen yerinizi ayırtın. Detaylar sitemizde!"
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

pub fn fallback_concierge_json(query: String) -> String {
  let q = string.lowercase(query)
  let category = case
    string.contains(q, "villa")
    || string.contains(q, "tatil evi")
    || string.contains(q, "apart")
  {
    True -> "holiday_home"
    False ->
      case
        string.contains(q, "otel")
        || string.contains(q, "hotel")
        || string.contains(q, "pansiyon")
      {
        True -> "hotel"
        False ->
          case
            string.contains(q, "yat")
            || string.contains(q, "tekne")
            || string.contains(q, "gulet")
          {
            True -> "yacht"
            False ->
              case string.contains(q, "tur") || string.contains(q, "gezi") {
                True -> "tour"
                False ->
                  case
                    string.contains(q, "aktivite")
                    || string.contains(q, "dalış")
                    || string.contains(q, "parasailing")
                  {
                    True -> "activity"
                    False ->
                      case
                        string.contains(q, "araç")
                        || string.contains(q, "araba")
                        || string.contains(q, "rent")
                      {
                        True -> "car"
                        False ->
                          case
                            string.contains(q, "transfer")
                            || string.contains(q, "vip")
                          {
                            True -> "transfer"
                            False -> "holiday_home"
                          }
                      }
                  }
              }
          }
      }
  }
  let locality = case string.contains(q, "fethiye") {
    True -> "Fethiye"
    False ->
      case string.contains(q, "kaş") || string.contains(q, "kas") {
        True -> "Kaş"
        False ->
          case string.contains(q, "bodrum") {
            True -> "Bodrum"
            False ->
              case string.contains(q, "marmaris") {
                True -> "Marmaris"
                False ->
                  case string.contains(q, "antalya") {
                    True -> "Antalya"
                    False ->
                      case string.contains(q, "kalkan") {
                        True -> "Kalkan"
                        False -> ""
                      }
                  }
              }
          }
      }
  }
  "{\"category\":\""
  <> category
  <> "\",\"locality\":\""
  <> locality
  <> "\",\"summary\":\""
  <> string.replace(query, "\"", "'")
  <> "\",\"keywords\":[\"tatil\",\"rezervasyon\"]}"
}

pub fn fallback_listing_specs(category: String, raw_text: String) -> String {
  let first_line = case string.split(raw_text, "\n") {
    [h, ..] -> string.trim(h)
    [] -> "Yeni İlan"
  }
  let safe_title = string.replace(first_line, "\"", "'")
  "{\"title\":\""
  <> safe_title
  <> "\",\"locality\":\"Antalya\",\"category\":\""
  <> string.lowercase(string.trim(category))
  <> "\",\"property_type\":\"Standart\",\"bedroom_count\":2,\"bathroom_count\":1,\"guest_capacity\":4,\"price_estimate\":10000}"
}

pub fn fallback_inquiry_reply(customer_name: String, listing_title: String) -> String {
  let name = case string.trim(customer_name) {
    "" -> "Değerli Misafirimiz"
    n -> "Sayın " <> n
  }
  name
  <> ",\n\n"
  <> listing_title
  <> " hakkındaki rezervasyon talebiniz için çok teşekkür ederiz. İlgilendiğiniz tarihler ve özel şartlarınız kayıt altına alınmıştır. Ekibimiz en kısa sürede sizinle iletişime geçerek detayları paylaşacaktır.\n\nKeyifli bir tatil dileriz!"
}

pub fn fallback_destination_guide(destination: String, category: String) -> String {
  "<h2>"
  <> destination
  <> " Seyahat ve Tatil Rehberi</h2>\n"
  <> "<p>"
  <> destination
  <> ", eşsiz doğası, berrak denizi ve seçkin konaklama seçenekleriyle unutulmaz bir seyahat deneyimi sunuyor.</p>\n"
  <> "<h3>Öne Çıkan Deneyimler</h3>\n"
  <> "<ul>\n"
  <> "  <li>Bölgenin en popüler koyları ve doğal güzellikleri</li>\n"
  <> "  <li>Konforlu ve güvenilir "
  <> category
  <> " seçenekleri</li>\n"
  <> "  <li>Yöresel gastronomi ve seçkin lezzet durakları</li>\n"
  <> "</ul>\n"
  <> "<p>Erken rezervasyon avantajlarından yararlanmak ve en uygun seçenekleri keşfetmek için sitemizdeki ilanları inceleyebilirsiniz.</p>"
}

// ---------------------------------------------------------------------------
// 1. Dynamic Pricing Optimizer
// ---------------------------------------------------------------------------

pub fn optimize_pricing(
  cfg: AIConfig,
  category: String,
  locality: String,
  current_price: Int,
  currency: String,
  season: String,
  occupancy_rate: Int,
) -> Result(String, String) {
  let cat = string.lowercase(string.trim(category))
  let sys =
    "Sen lüks ve butik turizmde gelir yönetimi (Revenue Management) ve dinamik fiyatlandırma uzmanısın. "
    <> "Verilen kategori ("
    <> cat
    <> "), lokasyon, mevcut fiyat, sezon ve doluluk verilerine göre acentenin kârını maksimize edecek dinamik fiyatlandırma stratejisi öner. "
    <> "JSON formatında yanıt ver: {"
    <> "\"base_price_suggested\": 0, "
    <> "\"weekend_price_suggested\": 0, "
    <> "\"high_season_price\": 0, "
    <> "\"low_season_price\": 0, "
    <> "\"min_stay_days\": 1, "
    <> "\"occupancy_boost_action\": \"...\", "
    <> "\"strategy_summary\": \"...\", "
    <> "\"insights\": [\"...\", \"...\"]"
    <> "}. Sadece geçerli JSON döndür, markdown veya ek metin ekleme."

  let user =
    "Kategori: "
    <> category
    <> "\nLokasyon: "
    <> locality
    <> "\nMevcut Fiyat: "
    <> int.to_string(current_price)
    <> " "
    <> currency
    <> "\nSezon: "
    <> season
    <> "\nDoluluk Oranı: %"
    <> int.to_string(occupancy_rate)

  case call_llm(cfg, sys, user) {
    Ok(text) -> Ok(clean_json_fences(text))
    Error("no_api_key") ->
      Ok(fallback_pricing_optimization(
        category,
        locality,
        current_price,
        currency,
        season,
        occupancy_rate,
      ))
    Error(e) -> Error(e)
  }
}

pub fn fallback_pricing_optimization(
  category: String,
  locality: String,
  current_price: Int,
  currency: String,
  season: String,
  occupancy_rate: Int,
) -> String {
  let base = case current_price <= 0 {
    True -> 5000
    False -> current_price
  }
  let s = string.lowercase(season)
  let #(season_mult, season_label) = case s {
    "high" | "yuksek" -> #(135, "Yüksek Sezon / Yoğun Talep")
    "low" | "dusuk" -> #(85, "Düşük Sezon / Fırsat Dönemi")
    _ -> #(105, "Orta Sezon / Dengeli Talep")
  }

  let occ_mult = case occupancy_rate {
    r if r >= 80 -> 115
    r if r < 40 -> 90
    _ -> 100
  }

  let total_mult = { season_mult * occ_mult } / 100
  let base_suggested = { base * total_mult } / 100
  let weekend_suggested = { base_suggested * 120 } / 100
  let high_price = { base * 140 } / 100
  let low_price = { base * 80 } / 100
  let min_stay = case s {
    "high" | "yuksek" -> 4
    "low" | "dusuk" -> 2
    _ -> 3
  }

  let action = case occupancy_rate {
    r if r >= 80 -> "Doluluk %80 üzeri; son boş tarihler için minimum gece sayısını artırın ve kâr marjını yükseltin."
    r if r < 40 -> "Doluluk %40 altında; erken rezervasyon promosyonu ve hafta içi özel indirimler uygulayın."
    _ -> "Doluluk dengeli seviyede; hafta sonu çarpanını koruyarak istikrarlı satışları sürdürün."
  }

  "{\"base_price_suggested\":"
  <> int.to_string(base_suggested)
  <> ",\"weekend_price_suggested\":"
  <> int.to_string(weekend_suggested)
  <> ",\"high_season_price\":"
  <> int.to_string(high_price)
  <> ",\"low_season_price\":"
  <> int.to_string(low_price)
  <> ",\"min_stay_days\":"
  <> int.to_string(min_stay)
  <> ",\"occupancy_boost_action\":\""
  <> action
  <> "\",\"strategy_summary\":\""
  <> locality
  <> " bölgesindeki "
  <> category
  <> " ilanları için "
  <> season_label
  <> " koşullarında taban fiyat "
  <> int.to_string(base_suggested)
  <> " "
  <> currency
  <> " olarak optimize edildi.\",\"insights\":[\"Hafta sonu talebine %20 dinamik prim uygulandı.\",\"Sezon ve doluluk çarpanları kâr marjını koruyacak şekilde hesaplandı.\"]}"
}

// ---------------------------------------------------------------------------
// 2. Review Sentiment & Auto-Responder
// ---------------------------------------------------------------------------

pub fn analyze_review_sentiment(
  cfg: AIConfig,
  rating: Int,
  review_text: String,
  listing_title: String,
) -> Result(String, String) {
  let sys =
    "Sen seyahat ve otelcilikte itibar yönetimi (Online Reputation Management) ve misafir ilişkileri uzmanısın. "
    <> "Misafirin bıraktığı puan (1-5) ve yorum metnine göre duygu analizini yap (positive/neutral/negative, skor 1-100), "
    <> "öne çıkan memnuniyetleri ve şikayetleri çıkar, ardından acente adına yayınlanmaya hazır 2 alternatif yanıt taslağı hazırla. "
    <> "JSON formatında yanıt ver: {"
    <> "\"sentiment\": \"positive|neutral|negative\", "
    <> "\"score\": 85, "
    <> "\"key_positives\": [\"...\"], "
    <> "\"key_concerns\": [\"...\"], "
    <> "\"suggested_reply_standard\": \"...\", "
    <> "\"suggested_reply_action_oriented\": \"...\""
    <> "}. Sadece geçerli JSON döndür, markdown veya ek metin ekleme."

  let user =
    "İlan: "
    <> listing_title
    <> "\nPuan: "
    <> int.to_string(rating)
    <> "/5\nYorum:\n"
    <> review_text

  case call_llm(cfg, sys, user) {
    Ok(text) -> Ok(clean_json_fences(text))
    Error("no_api_key") ->
      Ok(fallback_review_sentiment(rating, review_text, listing_title))
    Error(e) -> Error(e)
  }
}

pub fn fallback_review_sentiment(
  rating: Int,
  _review_text: String,
  listing_title: String,
) -> String {
  let #(sentiment, score) = case rating {
    5 -> #("positive", 98)
    4 -> #("positive", 82)
    3 -> #("neutral", 60)
    2 -> #("negative", 35)
    _ -> #("negative", 15)
  }
  let safe_title = string.replace(listing_title, "\"", "'")
  let reply_standard = case rating >= 4 {
    True ->
      "Değerli misafirimiz, "
      <> safe_title
      <> " tesisimizdeki konaklamanız ve nazik değerlendirmeniz için içtenlikle teşekkür ederiz. Sizi ve sevdiklerinizi yeniden ağırlamaktan büyük mutluluk duyacağız!"
    False ->
      "Değerli misafirimiz, "
      <> safe_title
      <> " deneyiminizle ilgili geri bildiriminiz için teşekkür ederiz. Belirttiğiniz hususlar ekibimiz tarafından hassasiyetle incelenmekte olup, gelecekteki ziyaretinizde kusursuz bir deneyim sunmak için gerekli aksiyonlar alınmıştır."
  }
  let reply_action = case rating >= 4 {
    True ->
      "Harika geri bildiriminiz için çok teşekkürler! Bir sonraki tatil planınızda özel acente indirim kodunuzu kullanmayı unutmayın. Yeniden görüşmek dileğiyle!"
    False ->
      "Yaşadığınız aksaklıkları telafi edebilmek adına sizinle özel olarak görüşmek isteriz. Rezervasyon yetkilimiz en kısa sürede doğrudan iletişime geçecektir."
  }
  "{\"sentiment\":\""
  <> sentiment
  <> "\",\"score\":"
  <> int.to_string(score)
  <> ",\"key_positives\":[\"Genel misafir memnuniyeti\",\"Tesis konforu\"]"
  <> ",\"key_concerns\":["
  <> case rating <= 3 {
    True -> "\"Hizmet ve süreç iyileştirme ihtiyacı\""
    False -> "\"Belirgin bir olumsuzluk bildirilmedi\""
  }
  <> "],\"suggested_reply_standard\":\""
  <> string.replace(reply_standard, "\"", "'")
  <> "\",\"suggested_reply_action_oriented\":\""
  <> string.replace(reply_action, "\"", "'")
  <> "\"}"
}

// ---------------------------------------------------------------------------
// 3. Cross-Sell & Itinerary Bundle Assistant
// ---------------------------------------------------------------------------

pub fn generate_bundle_cross_sell(
  cfg: AIConfig,
  locality: String,
  primary_category: String,
  travel_style: String,
  guest_count: Int,
) -> Result(String, String) {
  let sys =
    "Sen seyahat paketleme ve çapraz satış (Dynamic Packaging & Cross-Sell) uzmanısın. "
    <> "Misafirin ana konaklamasına ("
    <> primary_category
    <> ", "
    <> locality
    <> ") ek olarak seyahat stiline uygun 3 tamamlayıcı kategori teklifi oluştur (transfer, tur, yat, aktivite). "
    <> "JSON formatında yanıt ver: {"
    <> "\"bundle_title\": \"...\", "
    <> "\"target_audience\": \"...\", "
    <> "\"bundle_discount_percent\": 10, "
    <> "\"pitch_copy\": \"...\", "
    <> "\"items\": ["
    <> "{\"category\": \"...\", \"title\": \"...\", \"reason\": \"...\", \"estimated_price\": 0}"
    <> "]"
    <> "}. Sadece geçerli JSON döndür, markdown veya ek metin ekleme."

  let user =
    "Lokasyon: "
    <> locality
    <> "\nAna Kategori: "
    <> primary_category
    <> "\nSeyahat Tarzı: "
    <> travel_style
    <> "\nMisafir Sayısı: "
    <> int.to_string(guest_count)

  case call_llm(cfg, sys, user) {
    Ok(text) -> Ok(clean_json_fences(text))
    Error("no_api_key") ->
      Ok(fallback_bundle_cross_sell(
        locality,
        primary_category,
        travel_style,
        guest_count,
      ))
    Error(e) -> Error(e)
  }
}

pub fn fallback_bundle_cross_sell(
  locality: String,
  _primary_category: String,
  travel_style: String,
  guest_count: Int,
) -> String {
  let loc = case string.trim(locality) {
    "" -> "Akdeniz"
    l -> l
  }
  let style = case string.trim(travel_style) {
    "" -> "Konfor & Macera"
    s -> s
  }
  "{\"bundle_title\":\""
  <> loc
  <> " "
  <> style
  <> " Özel Seyahat Paketi\""
  <> ",\"target_audience\":\""
  <> int.to_string(guest_count)
  <> " Kişilik "
  <> style
  <> " Misafirleri\""
  <> ",\"bundle_discount_percent\":12"
  <> ",\"pitch_copy\":\""
  <> loc
  <> " tatilinizi tamamlayacak VIP transfer, tekne turu ve yerel aktivite deneyimlerini tek tıkla %12 avantajlı paket olarak ekleyin.\""
  <> ",\"items\":["
  <> "{\"category\":\"transfer\",\"title\":\"Havalimanı VIP Karşılama & Özel Transfer\",\"reason\":\"Konforlu, beklemesiz ve güvenli ulaşım garantisi\",\"estimated_price\":3200},"
  <> "{\"category\":\"yacht\",\"title\":\"Özel Koylar Günübirlik Tekne Gezisi\",\"reason\":\"Bölgenin saklı plajlarını keşfetme fırsatı\",\"estimated_price\":7500},"
  <> "{\"category\":\"activity\",\"title\":\"Rehberli Doğa & Macera Deneyimi\",\"reason\":\"Unutulmaz tatil anıları ve profesyonel rehberlik\",\"estimated_price\":2400}"
  <> "]}"
}

// ---------------------------------------------------------------------------
// 4. Support & WhatsApp Co-Pilot
// ---------------------------------------------------------------------------

pub fn generate_support_copilot_reply(
  cfg: AIConfig,
  customer_name: String,
  customer_question: String,
  listing_title: String,
  category: String,
  locality: String,
  channel: String,
) -> Result(String, String) {
  let sys =
    "Sen bir seyahat acentesi için yapay zeka müşteri asistanısın (Support Co-Pilot). "
    <> "Misafirin sorusuna ("
    <> channel
    <> " kanalı üzerinden) kurum kültürüne uygun, samimi, kibar ve çözüm sunan bir yanıt hazırla. "
    <> "JSON formatında yanıt ver: {"
    <> "\"reply_text\": \"...\", "
    <> "\"action_items\": [\"...\"], "
    <> "\"quick_tags\": [\"...\"]"
    <> "}. Sadece geçerli JSON döndür, markdown veya ek metin ekleme."

  let user =
    "Müşteri: "
    <> customer_name
    <> "\nKanal: "
    <> channel
    <> "\nİlan: "
    <> listing_title
    <> " ("
    <> category
    <> ", "
    <> locality
    <> ")\nMüşteri Sorusu: "
    <> customer_question

  case call_llm(cfg, sys, user) {
    Ok(text) -> Ok(clean_json_fences(text))
    Error("no_api_key") ->
      Ok(fallback_support_copilot(
        customer_name,
        customer_question,
        listing_title,
        category,
        locality,
        channel,
      ))
    Error(e) -> Error(e)
  }
}

pub fn fallback_support_copilot(
  customer_name: String,
  _customer_question: String,
  listing_title: String,
  category: String,
  locality: String,
  channel: String,
) -> String {
  let name = case string.trim(customer_name) {
    "" -> "Değerli Misafirimiz"
    n -> "Sayın " <> n
  }
  let safe_title = string.replace(listing_title, "\"", "'")
  let reply = case string.lowercase(channel) {
    "whatsapp" ->
      "Merhaba "
      <> name
      <> "! 🌴 "
      <> safe_title
      <> " ("
      <> locality
      <> ") hakkındaki sorunuz için teşekkürler.\\n\\n"
      <> "Talebinizi inceledik. Detaylı müsaitlik ve giriş şartlarımız günceldir. Size özel avantajlı teklifimizi iletmekten memnuniyet duyarız.\\n\\n"
      <> "Sorularınız için buradayız, keyifli tatiller dileriz! ✨"
    _ ->
      "Sayın "
      <> name
      <> ",\\n\\n"
      <> safe_title
      <> " için ilettiğiniz talebiniz alınmıştır. İlgili tesisimizin şartları ve güncel rezervasyon detayları doğrulanmıştır.\\n\\n"
      <> "Rezervasyonunuzu güvenle tamamlamak için acentemizle dilediğiniz zaman iletişime geçebilirsiniz.\\n\\nİyi günler dileriz."
  }
  "{\"reply_text\":\""
  <> string.replace(reply, "\"", "'")
  <> "\",\"action_items\":[\"İlan müsaitlik takvimini teyit et\",\"Misafire ödeme linki veya teklif ilet\"],\"quick_tags\":[\""
  <> category
  <> "\",\"bilgi-talebi\",\""
  <> channel
  <> "\"]}"
}
