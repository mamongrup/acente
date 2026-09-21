//// CSRF (Cross-Site Request Forgery) koruması — synchronizer token deseni.
////
//// Token oturumdan türetilir: HMAC-SHA256(oturum_jetonu, "nexus:csrf:v1").
//// Oturum jetonu gizlidir ve imzalı çerezle taşınır; jeton oturum
//// kapatıldığında token otomatik geçersizleşir. Doğrulama sabit zamanlı
//// (secure_compare) yapılır. Ayrı rastgele nonce yerine oturumdan türetme
//// tercih edildi: DB'de ekstra sütun/rotasyon gerekmez, token oturum boyunca
//// deterministik kalır (çok sekmeli kullanım güvenli).
////
//// Uygulama modeli: `require_csrf_form` gövdeyi BİR KEZ okur, `csrf` alanını
//// doğrular, alanı ayıklayıp gövdeyi geri tamponlar ve handler'a orijinal
//// `Request` verir — handler'lardaki `wisp.require_form` çağrıları hiçbir
//// değişiklik olmadan çalışmayı sürdürür.
////
//// Kapsam: `application/x-www-form-urlencoded` POST'lar. Panalde multipart
//// admin POST yok; böyle bir route eklenirse Origin/Referer kontrolü
//// (router.handle içinde) tek savunma olarak kalır ve burada genişletilmelidir.

import gleam/bit_array
import gleam/crypto
import gleam/http
import gleam/http/cookie
import gleam/http/request as http_request
import gleam/http/response
import gleam/list
import gleam/option
import gleam/string
import gleam/uri
import wisp
import wisp/internal.{Connection, Chunk, ReadingFinished}

pub const csrf_field = "csrf"

/// Oturum jetonundan CSRF token üretir (base64url, padding'siz).
pub fn token_for(session_token token: String) -> String {
  let mac =
    crypto.hmac(<<token:utf8>>, crypto.Sha256, <<"nexus:csrf:v1":utf8>>)
  bit_array.base64_url_encode(mac, False)
}

/// Sabit zamanlı token doğrulaması.
pub fn verify(token candidate: String, session_token token: String) -> Bool {
  crypto.secure_compare(<<candidate:utf8>>, <<token_for(token):utf8>>)
}

/// Oturum jetonunu imzalı çerezden okur.
///
/// Çerez yoksa/imzası bozuksa None döner; çağıran taraf fail-closed davranır
/// (403), asla doğrulamayı atlamaz.
pub fn session_token_from(req: wisp.Request) -> Result(String, Nil) {
  wisp.get_cookie(req, "agency_session", wisp.Signed)
}

/// Form POST'u için CSRF kapısı: gövdeyi okur, `csrf` alanını doğrular,
/// alanı ayıklayıp gövdeyi yeniden tamponlar ve handler'a orijinal isteği
/// verir. HTML form gönderimleri ve JS tabanlı gönderimler (geçici form,
/// fetch) aynı yoldan korunur.
pub fn require_csrf_form(
  req: wisp.Request,
  session_token: String,
  next: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  case is_urlencoded_form(req) {
    False -> forbidden()
    True ->
      case wisp.read_body_bits(req) {
        Error(_) -> forbidden()
        Ok(bits) ->
          case bit_array.to_string(bits) {
            Error(_) -> forbidden()
            Ok(body_text) ->
              case uri.parse_query(body_text) {
                Error(_) -> forbidden()
                Ok(pairs) ->
                  case list.key_find(pairs, csrf_field) {
                    Error(_) -> forbidden()
                    Ok(candidate) ->
                      case verify(candidate, session_token) {
                        False -> forbidden()
                        True -> {
                          let filtered =
                            list.filter(pairs, fn(pair) {
                              pair.0 != csrf_field
                            })
                          let new_body =
                            filtered
                            |> list.map(pair_to_query)
                            |> string.join("&")
                          let assert Ok(req) =
                            replace_connection_buffer(req, new_body)
                          next(req)
                        }
                      }
                  }
              }
          }
      }
  }
}

fn is_urlencoded_form(req: wisp.Request) -> Bool {
  case list.key_find(req.headers, "content-type") {
    Ok("application/x-www-form-urlencoded")
    | Ok("application/x-www-form-urlencoded;" <> _) -> True
    _ -> False
  }
}

/// Admin GET yanıtlarında JS okuma çerezini tazeler. Cookie.defaults(Http)
/// http_only: True üretir; burada attributes güncellenerek JS erişimi açık
/// tutulur (değer imzasız ve tek başına işlevsizdir).
pub fn set_js_cookie(
  response: wisp.Response,
  session_token: String,
) -> wisp.Response {
  response.set_cookie(
    response,
    js_cookie_name,
    token_for(session_token),
    cookie.Attributes(..cookie.defaults(http.Http), http_only: False, max_age: option.Some(
      28_800,
    )),
  )
}

/// JS'in okuduğu çerezin adı (HttpOnly değil).
pub const js_cookie_name = "nexus_csrf"

fn pair_to_query(pair: #(String, String)) -> String {
  uri.percent_encode(pair.0) <> "=" <> uri.percent_encode(pair.1)
}

/// Okunan gövdeyi tek parça tampon olarak yeni bir Connection'a yerleştirir;
/// `wisp.require_form` bu tampondan normal akışla okur.
fn replace_connection_buffer(
  req: wisp.Request,
  body_text: String,
) -> Result(wisp.Request, Nil) {
  let Connection(reader, max_body, max_files, chunk_size, secret, tmp_dir) =
    req.body
  let _ = reader
  let _ = chunk_size
  let buffered = <<body_text:utf8>>
  // Tek seferlik okuyucu: ilk çağrı tamponu döner, zincirin devamı biter.
  let buffered_reader = fn(_size) {
    Ok(Chunk(buffered, fn(_size) { Ok(ReadingFinished) }))
  }
  let new_connection =
    Connection(
      reader: buffered_reader,
      max_body_size: max_body,
      max_files_size: max_files,
      read_chunk_size: chunk_size,
      secret_key_base: secret,
      temporary_directory: tmp_dir,
    )
  Ok(http_request.Request(..req, body: new_connection))
}

fn forbidden() -> wisp.Response {
  wisp.response(403)
  |> wisp.string_body("CSRF doğrulaması başarısız. Sayfayı yenileyip tekrar deneyin.")
}
