//// ParamPOS TP_WMD_UCD / TP_WMD_Pay SOAP istemcisi.

import gleam/bit_array
import gleam/crypto
import gleam/int
import gleam/result
import gleam/string

@external(erlang, "agency_ffi_http", "post_xml")
fn post_xml(
  url: String,
  body: String,
  soap_action: String,
) -> Result(String, String)

pub type Config {
  Config(
    client_code: String,
    username: String,
    password: String,
    guid: String,
    service_url: String,
  )
}

pub type StartInput {
  StartInput(
    order_id: String,
    owner: String,
    pan: String,
    month: String,
    year: String,
    cvc: String,
    gsm: String,
    amount: String,
    success_url: String,
    error_url: String,
    ip: String,
  )
}

pub type StartResult {
  StartResult(
    result: Int,
    message: String,
    html: String,
    md: String,
    transaction_guid: String,
  )
}

pub type PayResult {
  PayResult(result: Int, message: String, receipt_id: String, bank_code: Int)
}

pub fn md_success(status: String) -> Bool {
  status == "1" || status == "2" || status == "3" || status == "4"
}

pub fn pay_success(payment: PayResult) -> Bool {
  payment.result > 0
  && payment.bank_code == 0
  && { int.parse(payment.receipt_id) |> result.unwrap(0) } > 0
}

fn esc(v: String) -> String {
  v
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&apos;")
}

fn tag(name: String, value: String) -> String {
  "<" <> name <> ">" <> esc(value) <> "</" <> name <> ">"
}

fn security(c: Config) -> String {
  "<G>"
  <> tag("CLIENT_CODE", c.client_code)
  <> tag("CLIENT_USERNAME", c.username)
  <> tag("CLIENT_PASSWORD", c.password)
  <> "</G>"
}

fn envelope(body: String) -> String {
  "<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body>"
  <> body
  <> "</soap:Body></soap:Envelope>"
}

@external(erlang, "agency_parampos_xml", "value")
fn xml_value(xml: String, name: String) -> String

fn int_value(xml: String, name: String) -> Int {
  case int.parse(string.trim(xml_value(xml, name))) {
    Ok(n) -> n
    Error(_) -> 0
  }
}

fn sha2b64(c: Config, value: String) -> Result(String, String) {
  use raw <- result.try(post_xml(
    c.service_url,
    envelope(
      "<SHA2B64 xmlns=\"https://turkpos.com.tr/\">"
      <> tag("Data", value)
      <> "</SHA2B64>",
    ),
    "https://turkpos.com.tr/SHA2B64",
  ))
  case xml_value(raw, "SHA2B64Result") {
    "" -> Error("missing_hash")
    hash -> Ok(hash)
  }
}

pub fn callback_hash(
  guid: String,
  transaction_guid: String,
  md: String,
  md_status: String,
  order_id: String,
) -> String {
  let data =
    transaction_guid <> md <> md_status <> order_id <> string.lowercase(guid)
  crypto.hash(crypto.Sha1, <<data:utf8>>) |> bit_array.base64_encode(True)
}

pub fn verify_hash(received: String, expected: String) -> Bool {
  received != "" && crypto.secure_compare(<<received:utf8>>, <<expected:utf8>>)
}

pub fn start(c: Config, i: StartInput) -> Result(StartResult, String) {
  use hash <- result.try(sha2b64(
    c,
    c.client_code <> c.guid <> "1" <> i.amount <> i.amount <> i.order_id,
  ))
  let body =
    "<TP_WMD_UCD xmlns=\"https://turkpos.com.tr/\">"
    <> security(c)
    <> tag("GUID", c.guid)
    <> tag("KK_Sahibi", i.owner)
    <> tag("KK_No", i.pan)
    <> tag("KK_SK_Ay", i.month)
    <> tag("KK_SK_Yil", i.year)
    <> tag("KK_CVC", i.cvc)
    <> tag("KK_Sahibi_GSM", i.gsm)
    <> tag("Hata_URL", i.error_url)
    <> tag("Basarili_URL", i.success_url)
    <> tag("Siparis_ID", i.order_id)
    <> tag("Siparis_Aciklama", "Rezervasyon")
    <> tag("Taksit", "1")
    <> tag("Islem_Tutar", i.amount)
    <> tag("Toplam_Tutar", i.amount)
    <> tag("Islem_Hash", hash)
    <> tag("Islem_Guvenlik_Tip", "3D")
    <> tag("Islem_ID", "0")
    <> tag("IPAdr", i.ip)
    <> tag("Ref_URL", i.success_url)
    <> tag("Data1", "")
    <> tag("Data2", "")
    <> tag("Data3", "")
    <> tag("Data4", "")
    <> tag("Data5", "")
    <> "</TP_WMD_UCD>"
  use raw <- result.try(post_xml(
    c.service_url,
    envelope(body),
    "https://turkpos.com.tr/TP_WMD_UCD",
  ))
  Ok(StartResult(
    int_value(raw, "Sonuc"),
    xml_value(raw, "Sonuc_Str"),
    xml_value(raw, "UCD_HTML"),
    xml_value(raw, "UCD_MD"),
    xml_value(raw, "Islem_GUID"),
  ))
}

pub fn pay(
  c: Config,
  md: String,
  transaction_guid: String,
  order_id: String,
) -> Result(PayResult, String) {
  let body =
    "<TP_WMD_Pay xmlns=\"https://turkpos.com.tr/\">"
    <> security(c)
    <> tag("GUID", c.guid)
    <> tag("UCD_MD", md)
    <> tag("Islem_GUID", transaction_guid)
    <> tag("Siparis_ID", order_id)
    <> "</TP_WMD_Pay>"
  use raw <- result.try(post_xml(
    c.service_url,
    envelope(body),
    "https://turkpos.com.tr/TP_WMD_Pay",
  ))
  let payment = parse_pay(raw)
  case int.parse(string.trim(xml_value(raw, "Sonuc"))) {
    Error(_) -> Error("invalid_payment_response")
    Ok(_) ->
      case payment.result > 0 && !pay_success(payment) {
        True -> Error("ambiguous_payment_response")
        False -> Ok(payment)
      }
  }
}

pub fn parse_pay(raw: String) -> PayResult {
  PayResult(
    int_value(raw, "Sonuc"),
    xml_value(raw, "Sonuc_Ack"),
    xml_value(raw, "Dekont_ID"),
    case int.parse(string.trim(xml_value(raw, "Bank_Sonuc_Kod"))) {
      Ok(code) -> code
      Error(_) ->
        int.parse(string.trim(xml_value(raw, "Banka_Sonuc_Kod")))
        |> result.unwrap(-1)
    },
  )
}
