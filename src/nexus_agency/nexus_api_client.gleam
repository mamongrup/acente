import gleam/dynamic/decode
import gleam/json
import gleam/string

@external(erlang, "agency_ffi_http", "get_url_with_auth")
pub fn get_url_with_auth(
  url: String,
  auth_header: String,
) -> Result(String, String)

@external(erlang, "agency_ffi_http", "post_json_with_timeout")
pub fn post_json_with_timeout(
  url: String,
  body: String,
  auth_header: String,
  timeout_ms: Int,
) -> Result(String, String)

pub type ListingTuple =
  #(String, String, String, String, String, String, String, String, String)

fn auth_header(api_key: String) -> String {
  case string.trim(api_key) {
    "" -> ""
    key -> "Bearer " <> key
  }
}

fn clean_origin(origin: String) -> String {
  let trimmed = string.trim(origin)
  case string.ends_with(trimmed, "/") {
    True -> string.drop_end(trimmed, 1)
    False -> trimmed
  }
}

/// NEXUS sunucusundan sürümlü sözleşme durumunu REST API üzerinden çeker.
pub fn fetch_contract_state(
  api_origin: String,
  api_key: String,
) -> Result(List(#(String, String)), String) {
  let url = clean_origin(api_origin) <> "/api/v1/contract/state"
  let auth = auth_header(api_key)

  case get_url_with_auth(url, auth) {
    Ok(body) -> parse_contract_state(body)
    Error(err) -> Error("NEXUS sözleşme API çağrısı başarısız: " <> err)
  }
}

fn contract_item_decoder() -> decode.Decoder(#(String, String)) {
  use key <- decode.field("key", decode.string)
  use value <- decode.field("value", decode.string)
  decode.success(#(key, value))
}

fn contract_state_decoder() -> decode.Decoder(List(#(String, String))) {
  use state <- decode.field("contract_state", decode.list(contract_item_decoder()))
  decode.success(state)
}

fn parse_contract_state(
  raw_json: String,
) -> Result(List(#(String, String)), String) {
  case json.parse(from: raw_json, using: contract_state_decoder()) {
    Ok(state) -> Ok(state)
    Error(_) -> Error("NEXUS sözleşme yanıtı JSON formatına uymuyor")
  }
}

/// NEXUS sunucusundan acenteye özel ya da genel yayınlanmış ilan feed'ini çeker.
pub fn fetch_listings_feed(
  api_origin: String,
  api_key: String,
  agency_id: String,
) -> Result(List(ListingTuple), String) {
  let query = case string.trim(agency_id) {
    "" -> ""
    id -> "?agency_id=" <> id
  }
  let url = clean_origin(api_origin) <> "/api/v1/feed/listings" <> query
  let auth = auth_header(api_key)

  case get_url_with_auth(url, auth) {
    Ok(body) -> parse_listings_feed(body)
    Error(err) -> Error("NEXUS ilan feed API çağrısı başarısız: " <> err)
  }
}

fn listing_item_decoder() -> decode.Decoder(ListingTuple) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use locality <- decode.field("locality", decode.string)
  use category <- decode.field("category", decode.string)
  use capacity <- decode.field("capacity", decode.string)
  use price <- decode.field("price", decode.string)
  use currency <- decode.field("currency", decode.string)
  use description <- decode.field("description", decode.string)
  use images_json <- decode.field("images_json", decode.string)
  decode.success(#(
    id,
    title,
    locality,
    category,
    capacity,
    price,
    currency,
    description,
    images_json,
  ))
}

fn listings_feed_decoder() -> decode.Decoder(List(ListingTuple)) {
  use listings <- decode.field("listings", decode.list(listing_item_decoder()))
  decode.success(listings)
}

fn parse_listings_feed(raw_json: String) -> Result(List(ListingTuple), String) {
  case json.parse(from: raw_json, using: listings_feed_decoder()) {
    Ok(listings) -> Ok(listings)
    Error(_) -> Error("NEXUS ilan feed yanıtı JSON formatına uymuyor")
  }
}

/// NEXUS sunucusuna acenteden rezervasyon webhook'u iletir (idempotency destekli).
pub fn send_reservation_webhook(
  api_origin: String,
  api_key: String,
  payload_json: String,
) -> Result(String, String) {
  let url = clean_origin(api_origin) <> "/api/v1/webhooks/reservations"
  let auth = auth_header(api_key)

  case post_json_with_timeout(url, payload_json, auth, 15_000) {
    Ok(reply) -> Ok(reply)
    Error(err) -> Error("NEXUS rezervasyon webhook hatası: " <> err)
  }
}

/// NEXUS sunucusundan bir ilan için müsaitlik ve fiyat takvimini çeker.
pub fn fetch_inventory(
  api_origin: String,
  api_key: String,
  listing_id: String,
) -> Result(String, String) {
  let url = clean_origin(api_origin) <> "/api/v1/feed/inventory?listing_id=" <> listing_id
  let auth = auth_header(api_key)

  case get_url_with_auth(url, auth) {
    Ok(body) -> Ok(body)
    Error(err) -> Error("NEXUS envanter çağrısı başarısız: " <> err)
  }
}

/// NEXUS sunucusundan 17 kanonik kategori için sözleşme filtre gruplarını çeker.
pub fn fetch_contract_filters(
  api_origin: String,
  api_key: String,
) -> Result(String, String) {
  let url = clean_origin(api_origin) <> "/api/v1/contract/filters"
  let auth = auth_header(api_key)

  case get_url_with_auth(url, auth) {
    Ok(body) -> Ok(body)
    Error(err) -> Error("NEXUS sözleşme filtreleri çağrısı başarısız: " <> err)
  }
}

