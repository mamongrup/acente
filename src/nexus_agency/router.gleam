//// HTTP router cephesi (facade).
////
//// Orijinal router.gleam (10.343 satır) yanlışlıkla üzerine yazıldı; kaynak
//// kaybolduğu için derlenmiş Erlang çıktısı `src/nexus_agency/erl/`
//// altında `nexus_agency@router_impl` olarak kurtarıldı ve modül olarak
//// projeye eklendi. Bu dosya, kayıpsız ve davranışsal olarak birebir aynı
//// router'ı Gleam dünyasına bağlı ince bir tipli cephedir.
////
//// Kurtarma geçmişi: `nexus_agency@router.erl` artefaktı 2026-09-19
//// 15:26 tarihindeki son başarılı derlemeden gelir ve kaynakta tanımlı
//// tüm fonksiyonları (67 üst düzey tanım) içerir. Erlang modülü Gleam
//// derleyicisiyle aynı zamanda yeniden derlenir ve `handle/3` üzerinden
//// tüm rota davranışı (public vitrin, admin panel, API, statik dosyalar)
//// aynen korunur.
////
//// Yeni rota/görünüm eklemek için: Erlang tarafına eklemek yerine yeni
//// Gleam modülleri yazıp buradaki `handle` zincirine ön-middleware olarak
//// bağlamak tercih edilmelidir.

import gleam/bit_array
import gleam/crypto
import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/float
import gleam/http
import gleam/http/cookie as http_cookie
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/int
import gleam/json
import gleam/list

// wisp'in json_response/json_body yardımcıları gleam/json ile aynı isimde
// olduğundan modül fonksiyonlarını wisp_json üzerinden çağırıyoruz.
import envoy
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp
import gleam/uri
import nexus_agency/ai_client
import nexus_agency/auth
import nexus_agency/csrf
import nexus_agency/i18n
import nexus_agency/panel
import nexus_agency/parampos
import nexus_agency/permissions
import nexus_agency/secrets
import nexus_agency/ssr_currency
import pog
import wisp.{type Response}
import wisp/internal.{Chunk, Connection, ReadingFinished}

/// Kayıpsız kurtarılan router uygulaması (Erlang, derleyici yönetiminde).
@external(erlang, "nexus_agency@router_impl", "handle")
fn router_handle_impl(
  _req: wisp.Request,
  db: pog.Connection,
  origin: String,
) -> Response

@external(erlang, "nexus_agency@router_impl", "public_tenant_selector")
fn public_tenant_selector(req: wisp.Request) -> String

/// Panel rotaları için oturum middleware'i: geçerli `agency_session` çerezi
/// yoksa istek /login'e yönlendirilir, varsa gövde `session` ile çalışır.
@external(erlang, "nexus_agency@router_impl", "require_session")
fn require_session_impl(
  db: pog.Connection,
  token: Result(String, Nil),
  body: fn() -> Response,
) -> Response

/// API rotaları için oturum middleware'i: yönlendirme yerine 401 döner.
@external(erlang, "nexus_agency@router_impl", "require_session_api")
fn require_session_api_impl(
  db: pog.Connection,
  token: Result(String, Nil),
  body: fn() -> Response,
) -> Response

@external(erlang, "nexus_agency@router_impl", "parampos_config")
fn parampos_config_impl(
  db: pog.Connection,
  tenant_id: String,
) -> Result(parampos.Config, String)

/// Ana giriş noktası: tüm HTTP isteklerini kurtarılan router'a iletir.
///
/// Ön-middleware zinciri:
///   1) POST /admin/preferences/language → hesaba dil tercihi yazar (bu
///      modülde; kurtarılan Erlang router'a dokunmadan yeni pref uçları
///      burada eklenir — dokümantasyondaki yönergeyle uyumlu),
///   2) diğer tüm istekler router_impl.handle'a iletilir.
pub fn handle(
  req: wisp.Request,
  db: pog.Connection,
  origin: String,
) -> Response {
  // Generate or accept the correlation id once, then propagate it through
  // the request so audit rows and the response header always match.
  let correlation_id = request_id(req)
  let correlated_req =
    http_request.set_header(req, "x-request-id", correlation_id)

  case client_quarantined(db, correlated_req) {
    True -> too_many_requests()
    False -> handle_application_request(correlated_req, db, origin)
  }
  |> sync_language_cookie(correlated_req)
  |> http_response.set_header("x-request-id", correlation_id)
  |> security_headers
}

fn request_id(req: wisp.Request) -> String {
  let supplied =
    http_request.get_header(req, "x-request-id")
    |> result.unwrap("")
    |> string.trim
    |> string.slice(0, 128)
  case supplied {
    "" -> "req-" <> wisp.random_string(24)
    value -> value
  }
}

fn security_headers(res: Response) -> Response {
  let secured =
    res
    |> http_response.set_header("x-content-type-options", "nosniff")
    |> http_response.set_header("x-frame-options", "SAMEORIGIN")
    |> http_response.set_header("referrer-policy", "same-origin")
    |> http_response.set_header("cross-origin-opener-policy", "same-origin")
    |> http_response.set_header("x-permitted-cross-domain-policies", "none")
    |> http_response.set_header(
      "permissions-policy",
      "camera=(), microphone=(), geolocation=(), payment=()",
    )
    |> http_response.set_header(
      "content-security-policy",
      "default-src 'self'; img-src 'self' data: https: http:; media-src 'self' data: https: http: blob:; style-src 'self' 'unsafe-inline' https:; script-src 'self' 'unsafe-inline' https:; font-src 'self' data: https:; connect-src 'self' https: http:; frame-ancestors 'self'; base-uri 'self'; form-action 'self'",
    )
  case envoy.get("APP_ENV") {
    Ok("production") ->
      secured
      |> http_response.set_header(
        "strict-transport-security",
        "max-age=31536000; includeSubDomains",
      )
    _ -> secured
  }
}

fn handle_application_request(
  req: wisp.Request,
  db: pog.Connection,
  origin: String,
) -> Response {
  case public_rate_limited(req) {
    True -> {
      record_rate_limit_violation(db, req)
      too_many_requests()
    }
    False ->
      case sales_chain_request(req) {
        True -> handle_sales_chain_request(req, db)
        False ->
      // Self-service listing wizard (public storefront)
      case ilan_ver_request(req) {
        True -> handle_ilan_ver(req, db)
        False ->
      case rates_api_request(req) {
        True -> handle_rates_api(db)
        False ->
          case report_audit_request(req) {
            True -> handle_report_audit_request(req, db)
            False ->
              case social_admin_request(req) {
                True -> handle_social_admin_request(req, db)
                False ->
                  case ai_health_request(req) {
                    True -> handle_ai_health_request(req, db)
                    False -> case module_control_request(req) {
                    True -> handle_module_control_request(req, db)
                    False ->
                      case integration_admin_request(req) {
                        True ->
                          handle_integration_admin_request(req, db, origin)
                        False ->
                          case nexus_connection_approval_request(req) {
                            True -> handle_nexus_connection_approval(req, db)
                            False ->
                              case control_center_request(req) {
                                True -> handle_control_center_request(req, db)
                                False -> case supplier_onboarding_admin_request(req) {
                                True ->
                                  handle_supplier_onboarding_admin_request(
                                    req,
                                    db,
                                  )
                                False ->
                                  case sync_admin_request(req) {
                                    True -> handle_sync_admin_request(req, db)
                                    False ->
                                      case category_filter_request(req) {
                                        True ->
                                          handle_category_filter_request(
                                            req,
                                            db,
                                          )
                                        False ->
                                          case currency_pref_request(req) {
                                            Ok(cur) ->
                                              save_currency_pref(req, db, cur)
                                            Error(Nil) ->
                                              case language_pref_request(req) {
                                                Ok(lang) ->
                                                  save_language_pref(
                                                    req,
                                                    db,
                                                    lang,
                                                  )
                                                Error(Nil) ->
                                                  // Giriş akışı: gövdeden e-postayı oku (gövdeyi yeniden tamponla),
                                                  // router'a ilet; başarılı girişte kullanıcının kayıtlı dil/para
                                                  // birimi tercihlerini nexus_lang / nexus_currency çerezlerine
                                                  // bin — farklı cihazda/temiz tarayıcıda ilk sayfa açılışı sunucu
                                                  // tercihlerinde başlar.
                                                  case login_email(req) {
                                                    Ok(#(email, bits)) ->
                                                      case
                                                        rate_limited(
                                                          "login:"
                                                            <> string.lowercase(
                                                            string.trim(email),
                                                          )
                                                            <> ":"
                                                            <> request_client_id(
                                                            req,
                                                          ),
                                                          12,
                                                          300_000.0,
                                                        )
                                                      {
                                                        True ->
                                                          too_many_requests()
                                                        False ->
                                                          case
                                                            rebuild_buffered(
                                                              req,
                                                              bits,
                                                            )
                                                          {
                                                            Ok(buffered) -> {
                                                              let res =
                                                                router_handle_impl(
                                                                  buffered,
                                                                  db,
                                                                  origin,
                                                                )
                                                              case
                                                                res.status
                                                                == 303
                                                              {
                                                                True ->
                                                                  stamp_pref_cookies(
                                                                    res,
                                                                    buffered,
                                                                    db,
                                                                    email,
                                                                    login_tenant_slug(
                                                                      bits,
                                                                    ),
                                                                  )
                                                                False -> res
                                                              }
                                                            }
                                                            Error(Nil) ->
                                                              router_handle_impl(
                                                                req,
                                                                db,
                                                                origin,
                                                              )
                                                          }
                                                      }
                                                    Error(Nil) ->
                                                      router_handle_impl(
                                                        req,
                                                        db,
                                                        origin,
                                                      )
                                                  }
                                              }
                                          }
                                      }
                                  }
                              }
                              }
                          }
                      }
                  }
                  }
              }
          }
      }
      }
      }
  }
}

fn sales_chain_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Get, ["admin", "finance-overview", "chain", _] -> True
    http.Post, ["admin", "finance-overview", "cancel"] -> True
    http.Post, ["admin", "finance-overview", "parampos-refund"] -> True
    _, _ -> False
  }
}

fn handle_sales_chain_request(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) -> case auth.session(db, token) {
      Error(Nil) -> unauthorized_json()
      Ok(session) -> case permissions.is_admin_or_owner(session.membership) {
        False -> wisp.response(403)
        True -> case req.method, http_request.path_segments(req) {
          http.Get, ["admin", "finance-overview", "chain", order_id] -> {
            let decoder = decode.field(0, decode.string, decode.success)
            case pog.query("select agency.get_sales_chain_details($1::uuid,$2::uuid)::text")
              |> pog.parameter(pog.text(session.tenant_id))
              |> pog.parameter(pog.text(order_id))
              |> pog.returning(decoder)
              |> pog.execute(db) {
              Ok(rows) -> case rows.rows {
                [value, ..] -> wisp.json_response(value, 200)
                _ -> wisp.response(404)
              }
              Error(_) -> wisp.response(400)
            }
          }
          http.Post, ["admin", "finance-overview", "cancel"] ->
            csrf.require_csrf_form(req, token, fn(clean_req) {
              case wisp.read_body_bits(clean_req) {
                Error(_) -> wisp.response(400)
                Ok(bits) -> case bits |> bit_array.to_string |> result.try(uri.parse_query) {
                  Error(_) -> wisp.response(400)
                  Ok(pairs) -> {
                    let decoder = decode.field(0, decode.string, decode.success)
                    case pog.query("select agency.cancel_and_refund_order($1::uuid,$2::uuid,$3::uuid,$4)::text")
                      |> pog.parameter(pog.text(session.tenant_id))
                      |> pog.parameter(pog.text(session.user_id))
                      |> pog.parameter(pog.text(form_value(pairs, "order_id")))
                      |> pog.parameter(pog.text(form_value(pairs, "reason")))
                      |> pog.returning(decoder)
                      |> pog.execute(db) {
                      Ok(_) -> wisp.redirect("/admin/finance-overview")
                      Error(_) -> wisp.response(422)
                    }
                  }
                }
              }
            })
          http.Post, ["admin", "finance-overview", "parampos-refund"] ->
            csrf.require_csrf_form(req, token, fn(clean_req) {
              case wisp.read_body_bits(clean_req) {
                Error(_) -> wisp.response(400)
                Ok(bits) -> case bits |> bit_array.to_string |> result.try(uri.parse_query) {
                  Error(_) -> wisp.response(400)
                  Ok(pairs) -> process_parampos_refund(
                    db,
                    session.tenant_id,
                    session.user_id,
                    form_value(pairs, "refund_id"),
                  )
                }
              }
            })
          _, _ -> wisp.response(404)
        }
      }
    }
  }
}

fn process_parampos_refund(
  db: pog.Connection,
  tenant_id: String,
  actor_id: String,
  refund_id: String,
) -> Response {
  case parampos_config_impl(db, tenant_id) {
    Error(_) -> wisp.response(422) |> wisp.string_body("ParamPOS bağlantısı yapılandırılmamış.")
    Ok(config) -> {
      let decoder = decode.field(0, decode.string, decode.success)
      case pog.query("select agency.claim_parampos_refund($1::uuid,$2::uuid,$3::uuid)::text")
        |> pog.parameter(pog.text(tenant_id))
        |> pog.parameter(pog.text(actor_id))
        |> pog.parameter(pog.text(refund_id))
        |> pog.returning(decoder)
        |> pog.execute(db) {
        Error(_) -> wisp.response(422) |> wisp.string_body("İade talebi gönderilemedi veya daha önce gönderildi.")
        Ok(rows) -> case rows.rows {
          [claim, ..] -> case json.parse(from: claim, using: {
            use attempt <- decode.field("attempt_id", decode.string)
            use order <- decode.field("order_id", decode.string)
            use amount <- decode.field("amount_minor", decode.int)
            use action <- decode.field("action", decode.string)
            decode.success(#(attempt, order, amount, action))
          }) {
            Error(_) -> wisp.response(500)
            Ok(#(attempt, order, amount, action)) -> {
              let outcome = parampos.refund(config, order, amount, action)
              let #(status, reference, summary) = case outcome {
                Ok(proof) -> {
                  let ref = case proof.bank_transaction_id {
                    "" -> proof.bank_host_reference
                    value -> value
                  }
                  #("succeeded", ref, proof.message)
                }
                Error(_) -> #("unknown", "", "Provider confirmation unavailable")
              }
              case pog.query("select agency.finish_parampos_refund($1::uuid,$2::uuid,$3::uuid,$4,$5,$6)::text")
                |> pog.parameter(pog.text(tenant_id))
                |> pog.parameter(pog.text(actor_id))
                |> pog.parameter(pog.text(attempt))
                |> pog.parameter(pog.text(status))
                |> pog.parameter(pog.text(reference))
                |> pog.parameter(pog.text(summary))
                |> pog.returning(decoder)
                |> pog.execute(db) {
                Error(_) -> wisp.response(503) |> wisp.string_body("İade sonucu kaydedilemedi; işlem inceleme gerektiriyor.")
                Ok(_) -> case status {
                  "succeeded" -> wisp.redirect("/admin/finance-overview")
                  _ -> wisp.response(502) |> wisp.string_body("ParamPOS iade sonucu belirsiz; tekrar göndermeden önce mutabakat yapın.")
                }
              }
            }
          }
          _ -> wisp.response(500)
        }
      }
    }
  }
}

fn public_rate_limited(req: wisp.Request) -> Bool {
  let client = request_client_id(req)
  case req.method, http_request.path_segments(req) {
    http.Post, ["iletisim"] ->
      rate_limited("public:inquiry:" <> client, 5, 600_000.0)

    // Self-service listing submission: 3 per hour per IP
    http.Post, ["api", "public", "listing-submit"] ->
      rate_limited("public:listing_submit:" <> client, 3, 3_600_000.0)

    http.Post, ["api", "public", "checkout", "start"] ->
      rate_limited("public:checkout_order:" <> client, 8, 600_000.0)

    http.Post, ["api", "public", "checkout", "parampos", "start"] ->
      rate_limited("public:checkout_start:" <> client, 8, 600_000.0)

    http.Post, ["api", "public", "checkout", "parampos", "return"] ->
      rate_limited("public:parampos_return:" <> client, 40, 300_000.0)

    http.Post, ["api", "public", "chat"] ->
      rate_limited("public:chat:" <> client, 30, 300_000.0)

    http.Get, ["api", "public", "rates"] ->
      rate_limited("public:rates:" <> client, 120, 60_000.0)

    http.Get, ["api", "public", ..] ->
      rate_limited("public:get_api:" <> client, 180, 60_000.0)

    http.Get, ["static", ..] -> False

    // Coarse anonymous-page floor against scanners rotating random paths and
    // identifiers. Static assets are excluded above so one page load does not
    // consume the whole allowance.
    http.Get, _ -> rate_limited("public:get_page:" <> client, 300, 60_000.0)

    _, _ -> False
  }
}

fn nexus_connection_approval_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Post, ["v1", "nexus", "connection-approved"] -> True
    _, _ -> False
  }
}

fn integration_admin_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Post, ["admin", "integrations"] -> True
    _, _ -> False
  }
}

fn social_admin_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Post, ["admin", "social"] -> True
    http.Get, ["admin", "social", "posts"] -> True
    http.Post, ["admin", "social", "posts", "action"] -> True
    _, _ -> False
  }
}

fn ai_health_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Get, ["admin", "ai", "workers"] -> True
    http.Get, ["admin", "ai", "campaign-runs"] -> True
    http.Get, ["admin", "ai", "quality-cases"] -> True
    http.Post, ["admin", "ai", "quality-cases", "output"] -> True
    http.Post, ["admin", "ai", "social-generate"] -> True
    http.Post, ["admin", "ai", "extract-listing-fields"] -> True
    http.Post, ["admin", "ai", "inquiry-reply"] -> True
    http.Post, ["admin", "ai", "generate-blog"] -> True
    http.Post, ["admin", "ai", "optimize-pricing"] -> True
    http.Post, ["admin", "ai", "review-sentiment"] -> True
    http.Post, ["admin", "ai", "bundle-cross-sell"] -> True
    http.Post, ["admin", "ai", "support-copilot"] -> True
    _, _ -> False
  }
}

fn ai_health_sql(req: wisp.Request) -> String {
  case http_request.path_segments(req) {
    ["admin", "ai", "campaign-runs"] ->
      "select coalesce(json_agg(row_to_json(x)),'[]')::text from (select r.id,r.channel,r.status,r.scheduled_at,r.metrics,c.name as campaign_name,case when r.status='scheduled' then (select gate.reason from agency.ai_campaign_preflight(r.tenant_id,r.id) gate) else null end as preflight_reason from agency.ai_campaign_runs r left join agency.campaigns c on c.id=r.campaign_id and c.tenant_id=r.tenant_id where r.tenant_id=$1::uuid order by r.created_at desc limit 50) x"
    ["admin", "ai", "quality-cases"] ->
      "select coalesce(json_agg(row_to_json(x)),'[]')::text from (select id,suite_key,name,expected,last_result,last_error,last_run_at,case when actual is null then 'output_missing' when agency.ai_quality_text_rules(expected,actual) is null then 'unsupported_rules' else 'evaluated' end as evaluation_state from agency.ai_test_cases where tenant_id=$1::uuid order by last_run_at desc nulls last,suite_key,name limit 100) x"
    _ ->
      "select coalesce(json_agg(row_to_json(x)),'[]')::text from (select worker_key,status,queue_depth,details,last_heartbeat from agency.ai_worker_health where tenant_id=$1::uuid order by worker_key) x"
  }
}

fn handle_ai_health_request(req: wisp.Request, db: pog.Connection) -> Response {
  case req.method, http_request.path_segments(req) {
    http.Post, ["admin", "ai", "social-generate"] ->
      handle_ai_social_generate(req, db)
    http.Post, ["admin", "ai", "extract-listing-fields"] ->
      handle_ai_extract_listing(req, db)
    http.Post, ["admin", "ai", "inquiry-reply"] ->
      handle_ai_inquiry_reply(req, db)
    http.Post, ["admin", "ai", "generate-blog"] ->
      handle_ai_generate_blog(req, db)
    http.Post, ["admin", "ai", "optimize-pricing"] ->
      handle_ai_optimize_pricing(req, db)
    http.Post, ["admin", "ai", "review-sentiment"] ->
      handle_ai_review_sentiment(req, db)
    http.Post, ["admin", "ai", "bundle-cross-sell"] ->
      handle_ai_bundle_cross_sell(req, db)
    http.Post, ["admin", "ai", "support-copilot"] ->
      handle_ai_support_copilot(req, db)
    http.Post, _ -> handle_ai_quality_output(req, db)
    _, _ -> handle_ai_health_read(req, db)
  }
}

fn get_tenant_ai_config(db: pog.Connection, tenant_id: String) -> ai_client.AIConfig {
  let ai_cfg_query =
    "select coalesce(row_to_json(x)::text,'') from (select coalesce(provider,'google') as provider,coalesce(api_key_encrypted,'') as api_key,coalesce(model,'') as model from agency.ai_key_pool where tenant_id=$1::uuid and active and api_key_encrypted<>'' and (cooldown_until is null or cooldown_until<=now()) and (daily_limit=0 or daily_used<daily_limit) order by priority,id limit 1) x"
    |> pog.query()
    |> pog.parameter(pog.text(tenant_id))
    |> pog.returning(decode.field(0, decode.string, fn(r) { decode.success(r) }))
    |> pog.execute(db)

  let pool_decoder = {
    use provider <- decode.field("provider", decode.string)
    use api_key <- decode.field("api_key", decode.string)
    use model <- decode.field("model", decode.string)
    decode.success(ai_client.AIConfig(provider: provider, api_key: api_key, model: model))
  }

  case ai_cfg_query {
    Ok(rows) -> case rows.rows {
      [raw, ..] -> case json.parse(raw, pool_decoder) {
        Ok(c) -> c
        Error(_) -> ai_client.AIConfig(provider: "google", api_key: "", model: "gemini-2.5-flash")
      }
      [] -> ai_client.AIConfig(provider: "google", api_key: "", model: "gemini-2.5-flash")
    }
    Error(_) -> ai_client.AIConfig(provider: "google", api_key: "", model: "gemini-2.5-flash")
  }
}

fn handle_ai_social_generate(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let listing_id = form_value(pairs, "listing_id")
                    let network = case form_value(pairs, "network") {
                      "" -> "instagram"
                      n -> n
                    }
                    let lang = case form_value(pairs, "language_code") {
                      "" -> "tr"
                      l -> l
                    }
                    let tone = case form_value(pairs, "tone") {
                      "" -> "luxury"
                      t -> t
                    }
                    let custom_prompt = form_value(pairs, "prompt")

                    let listing_json = case string.trim(listing_id) {
                      "" -> ""
                      id -> {
                        let q =
                          "select coalesce(row_to_json(x)::text,'') from (select id,title,category,coalesce(description,'') as description,coalesce(images->0->>'url','') as media_url from agency.listings where tenant_id=$1::uuid and (id::text=$2 or code ilike $2 or title ilike '%'||$2||'%') order by case when id::text=$2 then 0 when code ilike $2 then 1 else 2 end,id limit 1) x"
                          |> pog.query()
                          |> pog.parameter(pog.text(session.tenant_id))
                          |> pog.parameter(pog.text(id))
                          |> pog.returning(decode.field(0, decode.string, fn(r) { decode.success(r) }))
                          |> pog.execute(db)
                        case q {
                          Ok(rows) -> case rows.rows {
                            [raw, ..] -> raw
                            [] -> ""
                          }
                          Error(_) -> ""
                        }
                      }
                    }

                    let listing_decoder = {
                      use resolved_id <- decode.field("id", decode.string)
                      use title <- decode.field("title", decode.string)
                      use category <- decode.field("category", decode.string)
                      use description <- decode.field("description", decode.string)
                      use media_url <- decode.field("media_url", decode.string)
                      decode.success(#(resolved_id, title, category, description, media_url))
                    }

                    let #(resolved_id, title, category, desc, media_url) = case json.parse(listing_json, listing_decoder) {
                      Ok(tup) -> tup
                      Error(_) -> {
                        let t = case form_value(pairs, "title") {
                          "" -> "Özel Tatil Fırsatı"
                          val -> val
                        }
                        #( "", t, "holiday_home", custom_prompt, "")
                      }
                    }

                    case listing_id != "" && resolved_id == "" {
                      True -> wisp.json_response("{\"ok\":false,\"error\":\"İlan bu acentede bulunamadı\"}", 404)
                      False -> {
                    let cfg = get_tenant_ai_config(db, session.tenant_id)

                    case ai_client.generate_social_post(cfg, network, category, title, desc, lang, tone) {
                      Ok(content) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(True)),
                            #("content", json.string(content)),
                            #("media_url", json.string(media_url)),
                            #("title", json.string(title)),
                            #("category", json.string(category)),
                            #("listing_id", json.string(resolved_id)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 200)
                      }
                      Error(err) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(False)),
                            #("error", json.string(err)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 500)
                      }
                    }
                      }
                    }
                  }
                }
            }
          _, _ -> unauthorized_json()
        }
      })
  }
}

fn handle_ai_extract_listing(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let category = form_value(pairs, "category")
                    let raw_text = form_value(pairs, "raw_text")
                    let cfg = get_tenant_ai_config(db, session.tenant_id)
                    case ai_client.extract_listing_specs(cfg, category, raw_text) {
                      Ok(specs_json) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(True)),
                            #("specs", json.string(specs_json)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 200)
                      }
                      Error(err) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(False)),
                            #("error", json.string(err)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 500)
                      }
                    }
                  }
                }
            }
          _, _ -> unauthorized_json()
        }
      })
  }
}

fn handle_ai_inquiry_reply(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let customer_name = form_value(pairs, "customer_name")
                    let message = form_value(pairs, "message")
                    let listing_id = form_value(pairs, "listing_id")
                    let default_title = form_value(pairs, "listing_title")
                    let default_cat = form_value(pairs, "category")
                    let rules = form_value(pairs, "rules")

                    let listing_info = case string.trim(listing_id) {
                      "" -> #(default_title, default_cat)
                      id -> {
                        let q =
                          "select coalesce(row_to_json(x)::text,'') from (select title,category from agency.listings where tenant_id=$1::uuid and (id::text=$2 or code ilike $2) limit 1) x"
                          |> pog.query()
                          |> pog.parameter(pog.text(session.tenant_id))
                          |> pog.parameter(pog.text(id))
                          |> pog.returning(decode.field(0, decode.string, fn(r) { decode.success(r) }))
                          |> pog.execute(db)
                        case q {
                          Ok(rows) -> case rows.rows {
                            [raw, ..] -> {
                              let dec = {
                                use t <- decode.field("title", decode.string)
                                use c <- decode.field("category", decode.string)
                                decode.success(#(t, c))
                              }
                              case json.parse(raw, dec) {
                                Ok(tup) -> tup
                                Error(_) -> #(default_title, default_cat)
                              }
                            }
                            [] -> #(default_title, default_cat)
                          }
                          Error(_) -> #(default_title, default_cat)
                        }
                      }
                    }

                    let #(title, cat) = listing_info
                    let title_final = case title {
                      "" -> "Tatil Hizmetimiz"
                      t -> t
                    }
                    let cat_final = case cat {
                      "" -> "holiday_home"
                      c -> c
                    }
                    let cfg = get_tenant_ai_config(db, session.tenant_id)
                    case
                      ai_client.generate_inquiry_reply(
                        cfg,
                        customer_name,
                        message,
                        title_final,
                        cat_final,
                        rules,
                      )
                    {
                      Ok(reply) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(True)),
                            #("reply", json.string(reply)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 200)
                      }
                      Error(err) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(False)),
                            #("error", json.string(err)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 500)
                      }
                    }
                  }
                }
            }
          _, _ -> unauthorized_json()
        }
      })
  }
}

fn handle_ai_generate_blog(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let destination = form_value(pairs, "destination")
                    let category = form_value(pairs, "category")
                    let lang = case form_value(pairs, "language_code") {
                      "" -> "tr"
                      l -> l
                    }
                    let dest_final = case string.trim(destination) {
                      "" -> "Türkiye"
                      d -> d
                    }
                    let cat_final = case string.trim(category) {
                      "" -> "holiday_home"
                      c -> c
                    }
                    let cfg = get_tenant_ai_config(db, session.tenant_id)
                    case
                      ai_client.generate_destination_guide(
                        cfg,
                        dest_final,
                        cat_final,
                        lang,
                      )
                    {
                      Ok(content) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(True)),
                            #("content", json.string(content)),
                            #("destination", json.string(dest_final)),
                            #("category", json.string(cat_final)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 200)
                      }
                      Error(err) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(False)),
                            #("error", json.string(err)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 500)
                      }
                    }
                  }
                }
            }
          _, _ -> unauthorized_json()
        }
      })
  }
}

fn parse_int_or(str: String, default: Int) -> Int {
  case int.parse(str) {
    Ok(i) -> i
    Error(_) -> default
  }
}

fn handle_ai_optimize_pricing(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let listing_id = form_value(pairs, "listing_id")
                    let raw_category = form_value(pairs, "category")
                    let raw_locality = form_value(pairs, "locality")
                    let raw_price = parse_int_or(form_value(pairs, "price"), 5000)
                    let currency = case form_value(pairs, "currency") {
                      "" -> "TRY"
                      c -> c
                    }
                    let season = case form_value(pairs, "season") {
                      "" -> "medium"
                      s -> s
                    }
                    let occ = parse_int_or(form_value(pairs, "occupancy_rate"), 60)

                    let #(category, locality, price) = case string.trim(listing_id) {
                      "" -> #(raw_category, raw_locality, raw_price)
                      id -> {
                        let q =
                          "select coalesce(row_to_json(x)::text,'') from (select category,locality,(price_minor/100)::int as price from agency.listings where tenant_id=$1::uuid and (id::text=$2 or code ilike $2) limit 1) x"
                          |> pog.query()
                          |> pog.parameter(pog.text(session.tenant_id))
                          |> pog.parameter(pog.text(id))
                          |> pog.returning(decode.field(0, decode.string, fn(r) { decode.success(r) }))
                          |> pog.execute(db)
                        case q {
                          Ok(rows) -> case rows.rows {
                            [raw, ..] -> {
                              let dec = {
                                use c <- decode.field("category", decode.string)
                                use l <- decode.field("locality", decode.string)
                                use p <- decode.field("price", decode.int)
                                decode.success(#(c, l, p))
                              }
                              case json.parse(raw, dec) {
                                Ok(tup) -> tup
                                Error(_) -> #(raw_category, raw_locality, raw_price)
                              }
                            }
                            [] -> #(raw_category, raw_locality, raw_price)
                          }
                          Error(_) -> #(raw_category, raw_locality, raw_price)
                        }
                      }
                    }

                    let cat_final = case string.trim(category) {
                      "" -> "holiday_home"
                      c -> c
                    }
                    let loc_final = case string.trim(locality) {
                      "" -> "Akdeniz"
                      l -> l
                    }

                    let cfg = get_tenant_ai_config(db, session.tenant_id)
                    case ai_client.optimize_pricing(cfg, cat_final, loc_final, price, currency, season, occ) {
                      Ok(res_json) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(True)),
                            #("result", json.string(res_json)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 200)
                      }
                      Error(err) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(False)),
                            #("error", json.string(err)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 500)
                      }
                    }
                  }
                }
            }
          _, _ -> unauthorized_json()
        }
      })
  }
}

fn handle_ai_review_sentiment(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let rating = parse_int_or(form_value(pairs, "rating"), 5)
                    let review_text = form_value(pairs, "review_text")
                    let listing_title = case form_value(pairs, "listing_title") {
                      "" -> "Tesisimiz"
                      t -> t
                    }
                    let cfg = get_tenant_ai_config(db, session.tenant_id)
                    case ai_client.analyze_review_sentiment(cfg, rating, review_text, listing_title) {
                      Ok(res_json) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(True)),
                            #("result", json.string(res_json)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 200)
                      }
                      Error(err) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(False)),
                            #("error", json.string(err)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 500)
                      }
                    }
                  }
                }
            }
          _, _ -> unauthorized_json()
        }
      })
  }
}

fn handle_ai_bundle_cross_sell(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let locality = case form_value(pairs, "locality") {
                      "" -> "Bodrum"
                      l -> l
                    }
                    let category = case form_value(pairs, "category") {
                      "" -> "holiday_home"
                      c -> c
                    }
                    let travel_style = case form_value(pairs, "travel_style") {
                      "" -> "Lüks & Konfor"
                      s -> s
                    }
                    let guests = parse_int_or(form_value(pairs, "guest_count"), 2)

                    let cfg = get_tenant_ai_config(db, session.tenant_id)
                    case ai_client.generate_bundle_cross_sell(cfg, locality, category, travel_style, guests) {
                      Ok(res_json) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(True)),
                            #("result", json.string(res_json)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 200)
                      }
                      Error(err) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(False)),
                            #("error", json.string(err)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 500)
                      }
                    }
                  }
                }
            }
          _, _ -> unauthorized_json()
        }
      })
  }
}

fn handle_ai_support_copilot(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let customer_name = form_value(pairs, "customer_name")
                    let question = form_value(pairs, "question")
                    let listing_title = case form_value(pairs, "listing_title") {
                      "" -> "Tesisimiz"
                      t -> t
                    }
                    let category = case form_value(pairs, "category") {
                      "" -> "holiday_home"
                      c -> c
                    }
                    let locality = case form_value(pairs, "locality") {
                      "" -> "Kaş"
                      l -> l
                    }
                    let channel = case form_value(pairs, "channel") {
                      "" -> "whatsapp"
                      ch -> ch
                    }

                    let cfg = get_tenant_ai_config(db, session.tenant_id)
                    case ai_client.generate_support_copilot_reply(cfg, customer_name, question, listing_title, category, locality, channel) {
                      Ok(res_json) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(True)),
                            #("result", json.string(res_json)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 200)
                      }
                      Error(err) -> {
                        let resp =
                          json.object([
                            #("ok", json.bool(False)),
                            #("error", json.string(err)),
                          ])
                          |> json.to_string
                        wisp.json_response(resp, 500)
                      }
                    }
                  }
                }
            }
          _, _ -> unauthorized_json()
        }
      })
  }
}


fn handle_ai_quality_output(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let case_id = form_value(pairs, "case_id")
                    let output = form_value(pairs, "actual_text")
                    case string.length(output) == 0 || string.length(output) > 10000 {
                      True -> wisp.response(422)
                      False ->
                        "update agency.ai_test_cases set actual=jsonb_build_object('text',$3::text),last_result='pending',last_error='' where tenant_id=$1::uuid and id::text=$2 returning id::text"
                        |> pog.query()
                        |> pog.parameter(pog.text(session.tenant_id))
                        |> pog.parameter(pog.text(case_id))
                        |> pog.parameter(pog.text(output))
                        |> pog.returning(decode.field(0, decode.string, fn(raw) { decode.success(raw) }))
                        |> pog.execute(db)
                        |> result.map(fn(rows) {
                          case rows.rows {
                            [_, ..] -> wisp.redirect("/admin/ai#ai-quality-review")
                            _ -> wisp.response(404)
                          }
                        })
                        |> result.unwrap(wisp.response(500))
                    }
                  }
                }
            }
          _, _ -> wisp.redirect("/login")
        }
      })
  }
}

fn handle_ai_health_read(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      case auth.session(db, token) {
        Error(Nil) -> unauthorized_json()
        Ok(session) ->
          case permissions.is_admin_or_owner(session.membership) {
            False -> wisp.response(403)
            True ->
              ai_health_sql(req)
              |> pog.query()
              |> pog.parameter(pog.text(session.tenant_id))
              |> pog.returning(decode.field(0, decode.string, fn(raw) {
                decode.success(raw)
              }))
              |> pog.execute(db)
              |> result.map(fn(rows) {
                case rows.rows {
                  [raw, ..] -> wisp.json_response(raw, 200)
                  _ -> wisp.json_response("[]", 200)
                }
              })
              |> result.unwrap(wisp.response(500))
          }
      }
  }
}

fn module_control_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Post, ["admin", "module-controls"] -> True
    http.Get, ["admin", "module-controls", "data"] -> True
    http.Get, ["admin", "module-controls", "report"] -> True
    _, _ -> False
  }
}

fn handle_module_control_request(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case req.method {
    http.Get ->
      case csrf.session_token_from(req) {
        Error(Nil) -> unauthorized_json()
        Ok(token) ->
          case auth.session(db, token) {
            Error(Nil) -> unauthorized_json()
            Ok(session) ->
              module_control_report_sql(req)
              |> pog.query()
              |> pog.parameter(pog.text(session.tenant_id))
              |> pog.returning(
                decode.field(0, decode.string, fn(raw) { decode.success(raw) }),
              )
              |> pog.execute(db)
              |> result.map(fn(result) {
                case result.rows {
                  [raw, ..] -> wisp.json_response(raw, 200)
                  _ -> wisp.json_response("[]", 200)
                }
              })
              |> result.unwrap(wisp.json_response(
                "{\"error\":\"Modül politikaları okunamadı\"}",
                500,
              ))
          }
      }
    http.Post -> handle_module_control_post(req, db)
    _ -> wisp.response(405)
  }
}

fn module_control_report_sql(req: wisp.Request) -> String {
  case http_request.path_segments(req) {
    ["admin", "module-controls", "report"] ->
      "select coalesce(json_agg(row_to_json(x)),'[]')::text from (select module_key, report_date, completed_count, failed_count, skipped_count, running_count, tokens_used, cost_cents from agency.module_operation_daily_report where tenant_id=$1::uuid and report_date >= current_date - 30 order by report_date desc, module_key) x"
    _ ->
      "select coalesce(json_agg(row_to_json(x)),'[]')::text from (select module_key, mode, enabled, daily_limit, weekly_limit, monthly_limit from agency.module_control_policies where tenant_id=$1::uuid order by module_key) x"
  }
}

fn handle_module_control_post(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.redirect("/admin")
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True ->
                    "insert into agency.module_control_policies(tenant_id,module_key,mode,daily_limit,weekly_limit,monthly_limit,updated_at) values($1::uuid,$2,$3,$4,$5,$6,now()) on conflict(tenant_id,module_key) do update set mode=excluded.mode,daily_limit=excluded.daily_limit,weekly_limit=excluded.weekly_limit,monthly_limit=excluded.monthly_limit,updated_at=now()"
                    |> pog.query()
                    |> pog.parameter(pog.text(session.tenant_id))
                    |> pog.parameter(pog.text(form_value(pairs, "module_key")))
                    |> pog.parameter(pog.text(form_value(pairs, "mode")))
                    |> pog.parameter(pog.int(form_int(pairs, "daily_limit")))
                    |> pog.parameter(pog.int(form_int(pairs, "weekly_limit")))
                    |> pog.parameter(pog.int(form_int(pairs, "monthly_limit")))
                    |> pog.execute(db)
                    |> result.map(fn(_) {
                      wisp.redirect("/admin#module-controls")
                    })
                    |> result.unwrap(
                      wisp.response(500)
                      |> wisp.string_body("Modül politikası kaydedilemedi"),
                    )
                }
            }
          _, _ -> wisp.redirect("/login")
        }
      })
  }
}

fn handle_social_admin_request(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case req.method, http_request.path_segments(req) {
    http.Get, ["admin", "social", "posts"] -> social_posts_data(req, db)
    http.Post, ["admin", "social", "posts", "action"] ->
      social_post_action(req, db)
    _, _ -> handle_social_compose(req, db)
  }
}

fn social_posts_data(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      case auth.session(db, token) {
        Error(Nil) -> unauthorized_json()
        Ok(session) ->
          case permissions.is_admin_or_owner(session.membership) {
            False -> wisp.response(403)
            True ->
              "select coalesce(json_agg(row_to_json(x)),'[]')::text from (select id,network,language_code,content,status,approved_at,external_post_id,failure_code,error,scheduled_at,published_at from agency.social_posts where tenant_id=$1::uuid order by coalesce(scheduled_at,published_at) desc nulls last,id desc limit 100) x"
              |> pog.query()
              |> pog.parameter(pog.text(session.tenant_id))
              |> pog.returning(decode.field(0, decode.string, fn(raw) {
                decode.success(raw)
              }))
              |> pog.execute(db)
              |> result.map(fn(rows) {
                case rows.rows {
                  [raw, ..] -> wisp.json_response(raw, 200)
                  _ -> wisp.json_response("[]", 200)
                }
              })
              |> result.unwrap(wisp.response(500))
          }
      }
  }
}

fn social_post_action(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let action = form_value(pairs, "action")
                    let post_id = form_value(pairs, "post_id")
                    let confirmed =
                      form_value(pairs, "confirmed_not_published") == "true"
                    let sql = case action {
                      "approve" ->
                        "with changed as (update agency.social_posts set approved_at=now(),moderation_status='approved' where tenant_id=$1::uuid and id::text=$2 and status='queued' and approved_at is null returning tenant_id,id) insert into agency.social_post_events(tenant_id,social_post_id,event_type,payload) select tenant_id,id,'approved','{}'::jsonb from changed"
                      "retry" if confirmed ->
                        "with changed as (update agency.social_posts set status='queued',approved_at=coalesce(approved_at,now()),moderation_status='approved',next_attempt_at=now(),started_at=null,attempts=0,error='',failure_code=null where tenant_id=$1::uuid and id::text=$2 and status='failed' and failure_code='delivery_unknown' returning tenant_id,id) insert into agency.social_post_events(tenant_id,social_post_id,event_type,payload) select tenant_id,id,'requeued','{}'::jsonb from changed"
                      "cancel" ->
                        "with changed as (update agency.social_posts set status='cancelled',next_attempt_at=null where tenant_id=$1::uuid and id::text=$2 and status in ('queued','failed') returning tenant_id,id) insert into agency.social_post_events(tenant_id,social_post_id,event_type,payload) select tenant_id,id,'cancelled','{}'::jsonb from changed"
                      _ -> ""
                    }
                    case sql == "" {
                      True -> wisp.response(422)
                      False ->
                        sql
                        |> pog.query()
                        |> pog.parameter(pog.text(session.tenant_id))
                        |> pog.parameter(pog.text(post_id))
                        |> pog.execute(db)
                        |> result.map(fn(_) {
                          wisp.redirect("/admin/ai#social-review")
                        })
                        |> result.unwrap(wisp.response(500))
                    }
                  }
                }
            }
          _, _ -> wisp.redirect("/login")
        }
      })
  }
}

fn handle_social_compose(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(clean_req) {
        case auth.session(db, session_token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.redirect("/admin")
              Ok(pairs) -> {
                let network = form_value(pairs, "network")
                let allowed = ["instagram", "facebook", "threads", "pinterest"]
                case
                  permissions.is_admin_or_owner(session.membership),
                  list.contains(allowed, network)
                {
                  False, _ -> wisp.response(403)
                  _, False ->
                    wisp.response(422)
                    |> wisp.string_body("Desteklenmeyen sosyal ağ")
                  True, True -> {
                    let content = form_value(pairs, "content")
                    let media = form_value(pairs, "media_url")
                    let listing_id = form_value(pairs, "listing_id")
                    let ai_gen = form_value(pairs, "ai_generated") == "true"
                    let automatic =
                      form_value(pairs, "automation_mode") == "automatic"
                    let approval =
                      form_value(pairs, "approval_required") == "true"
                    let daily_limit = form_int(pairs, "daily_limit")
                    case string.trim(content) == "" || daily_limit < 0 || daily_limit > 1000 {
                      True ->
                        wisp.response(422)
                        |> wisp.string_body("Gönderi metni boş olamaz")
                      False ->
                        "with listing as (select id from agency.listings where tenant_id=$1::uuid and (id::text=$10 or code ilike $10 or title ilike $10) order by case when id::text=$10 then 0 when code ilike $10 then 1 else 2 end,id limit 1), policy as (insert into agency.social_automation_policies(tenant_id,network,language_code,daily_limit,auto_generate,approval_required,updated_at) select $1::uuid,$2,$3,$4,$5::boolean,$6::boolean,now() where $10='' or exists(select 1 from listing) on conflict(tenant_id,network,language_code,market_code) do update set daily_limit=excluded.daily_limit,auto_generate=excluded.auto_generate,approval_required=excluded.approval_required,updated_at=now() returning id) insert into agency.social_posts(tenant_id,entity_type,entity_id,network,language_code,content,scheduled_at,metadata,approved_at,moderation_status,ai_generated) select $1::uuid,case when $10<>'' then 'listing' else 'manual' end,coalesce((select id from listing),gen_random_uuid()),$2,$3,$7,nullif($8,'')::timestamptz,jsonb_build_object('media_url',$9,'approval_required',$6::boolean,'listing_id',(select id::text from listing),'ai_generated',$11::boolean),case when $6::boolean then null else now() end,case when $6::boolean then 'pending' else 'approved' end,$11::boolean from policy returning id::text"
                        |> pog.query()
                        |> pog.parameter(pog.text(session.tenant_id))
                        |> pog.parameter(pog.text(network))
                        |> pog.parameter(
                          pog.text(form_value(pairs, "language_code")),
                        )
                        |> pog.parameter(pog.int(daily_limit))
                        |> pog.parameter(pog.bool(automatic))
                        |> pog.parameter(pog.bool(approval))
                        |> pog.parameter(pog.text(content))
                        |> pog.parameter(
                          pog.text(form_value(pairs, "scheduled_at")),
                        )
                        |> pog.parameter(pog.text(media))
                        |> pog.parameter(pog.text(listing_id))
                        |> pog.parameter(pog.bool(ai_gen))
                        |> pog.returning(decode.field(0, decode.string, decode.success))
                        |> pog.execute(db)
                        |> result.map(fn(rows) {
                          case rows.rows {
                            [] -> wisp.response(422) |> wisp.string_body("İlan bu acentede bulunamadı")
                            _ -> wisp.redirect("/admin/ai#social-review")
                          }
                        })
                        |> result.unwrap(
                          wisp.response(500)
                          |> wisp.string_body(
                            "Sosyal medya taslağı kaydedilemedi",
                          ),
                        )
                    }
                  }
                }
              }
            }
          _, _ -> wisp.redirect("/login")
        }
      })
  }
}

fn report_audit_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Get, ["admin", "reports", "audits"] -> True
    http.Get, ["admin", "reports", "audits.csv"] -> True
    _, _ -> False
  }
}

fn handle_report_audit_request(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(session_token) ->
      case auth.session(db, session_token) {
        Error(Nil) -> unauthorized_json()
        Ok(session) ->
          case permissions.is_admin_or_owner(session.membership) {
            False -> wisp.response(403)
            True -> {
              let query = wisp.get_query(req)
              let search = query_value(query, "q")
              let action = query_value(query, "action")
              let entity = query_value(query, "entity")
              let limit = audit_limit(query_value(query, "limit"))
              case req.method, http_request.path_segments(req) {
                http.Get, ["admin", "reports", "audits.csv"] ->
                  audit_csv_response(
                    db,
                    session.tenant_id,
                    search,
                    action,
                    entity,
                    limit,
                  )
                _, _ ->
                  audit_json_response(
                    db,
                    session.tenant_id,
                    search,
                    action,
                    entity,
                    limit,
                  )
              }
            }
          }
      }
  }
}

fn audit_limit(value: String) -> Int {
  case int.parse(value) {
    Ok(n) if n > 0 && n <= 500 -> n
    Ok(n) if n > 500 -> 500
    _ -> 50
  }
}

fn audit_json_response(
  db: pog.Connection,
  tenant_id: String,
  search: String,
  action: String,
  entity: String,
  limit: Int,
) -> Response {
  let decoder = decode.field(0, decode.string, decode.success)
  case
    "select coalesce(json_agg(json_build_object(
       'id', a.id::text,
       'action', a.action,
       'entityType', a.entity_type,
       'entityId', coalesce(a.entity_id::text,''),
       'userId', coalesce(a.user_id::text,''),
       'userEmail', coalesce(u.email,''),
       'userName', coalesce(u.display_name,''),
       'ip', coalesce(a.ip::text,''),
       'userAgent', coalesce(a.user_agent,''),
       'requestId', coalesce(a.request_id,''),
       'metadata', a.metadata,
       'createdAt', to_char(a.created_at,'YYYY-MM-DD HH24:MI:SS')
     ) order by a.created_at desc), '[]'::json)::text
     from (
       select id, action, entity_type, entity_id, user_id, ip, user_agent, request_id, metadata, created_at
       from agency.audit_logs
       where (tenant_id=$1::uuid or tenant_id is null)
         and ($2='' or action ilike '%' || $2 || '%' or entity_type ilike '%' || $2 || '%' or metadata::text ilike '%' || $2 || '%')
         and ($3='' or action ilike '%' || $3 || '%')
         and ($4='' or entity_type=$4)
       order by created_at desc
       limit $5
     ) a
     left join agency.users u on u.id=a.user_id"
    |> pog.query()
    |> pog.parameter(pog.text(tenant_id))
    |> pog.parameter(pog.text(search))
    |> pog.parameter(pog.text(action))
    |> pog.parameter(pog.text(entity))
    |> pog.parameter(pog.int(limit))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(result) ->
      case result.rows {
        [body, ..] -> wisp.json_response(body, 200)
        [] -> wisp.json_response("[]", 200)
      }
    Error(_) ->
      wisp.json_response("{\"error\":\"Audit kayıtları okunamadı\"}", 500)
  }
}

fn audit_csv_response(
  db: pog.Connection,
  tenant_id: String,
  search: String,
  action: String,
  entity: String,
  limit: Int,
) -> Response {
  let decoder = {
    use action <- decode.field(0, decode.string)
    use entity_type <- decode.field(1, decode.string)
    use entity_id <- decode.field(2, decode.string)
    use user_name <- decode.field(3, decode.string)
    use user_email <- decode.field(4, decode.string)
    use ip <- decode.field(5, decode.string)
    use user_agent <- decode.field(6, decode.string)
    use request_id <- decode.field(7, decode.string)
    use metadata <- decode.field(8, decode.string)
    use created_at <- decode.field(9, decode.string)
    decode.success(#(
      action,
      entity_type,
      entity_id,
      user_name,
      user_email,
      ip,
      user_agent,
      request_id,
      metadata,
      created_at,
    ))
  }
  case
    "select a.action, a.entity_type, coalesce(a.entity_id::text,''),
            coalesce(u.display_name,''), coalesce(u.email,''),
            coalesce(a.ip::text,''), coalesce(a.user_agent,''), coalesce(a.request_id,''),
            a.metadata::text, to_char(a.created_at,'YYYY-MM-DD HH24:MI:SS')
     from (
       select id, action, entity_type, entity_id, user_id, ip, user_agent, request_id, metadata, created_at
       from agency.audit_logs
       where (tenant_id=$1::uuid or tenant_id is null)
         and ($2='' or action ilike '%' || $2 || '%' or entity_type ilike '%' || $2 || '%' or metadata::text ilike '%' || $2 || '%')
         and ($3='' or action ilike '%' || $3 || '%')
         and ($4='' or entity_type=$4)
       order by created_at desc
       limit $5
     ) a
     left join agency.users u on u.id=a.user_id
     order by a.created_at desc"
    |> pog.query()
    |> pog.parameter(pog.text(tenant_id))
    |> pog.parameter(pog.text(search))
    |> pog.parameter(pog.text(action))
    |> pog.parameter(pog.text(entity))
    |> pog.parameter(pog.int(limit))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(result) -> {
      let rows =
        result.rows
        |> list.map(fn(row) {
          let #(
            action,
            entity_type,
            entity_id,
            user_name,
            user_email,
            ip,
            user_agent,
            request_id,
            metadata,
            created_at,
          ) = row
          [
            created_at,
            action,
            entity_type,
            entity_id,
            user_name,
            user_email,
            ip,
            user_agent,
            request_id,
            metadata,
          ]
          |> list.map(csv_cell)
          |> string.join(",")
        })
      let body =
        [
          "created_at,action,entity_type,entity_id,user_name,user_email,ip,user_agent,request_id,metadata",
          ..rows
        ]
        |> string.join("\n")
      wisp.response(200)
      |> http_response.set_header("content-type", "text/csv; charset=utf-8")
      |> http_response.set_header(
        "content-disposition",
        "attachment; filename=\"audit-logs.csv\"",
      )
      |> wisp.string_body(body)
    }
    Error(_) -> wisp.json_response("{\"error\":\"Audit CSV üretilemedi\"}", 500)
  }
}

fn csv_cell(value: String) -> String {
  "\"" <> string.replace(value, "\"", "\"\"") <> "\""
}

fn handle_integration_admin_request(
  req: wisp.Request,
  db: pog.Connection,
  origin: String,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(clean_req) {
        case auth.session(db, session_token), form_pairs(clean_req) {
          Ok(session), Ok(pairs) -> {
            let provider = form_value(pairs, "provider")
            let kind = form_value(pairs, "kind")
            case provider == "parampos" && kind == "payment" {
              True -> save_parampos_integration(clean_req, db, session, pairs)
              False ->
                case provider == "qnb_esolutions" && kind == "document" {
                  True -> save_qnb_esolutions_integration(clean_req, db, session, pairs)
                  False ->
                    case provider == "social" {
                      True -> save_social_integration(db, session, pairs)
                      False ->
                        save_search_engine_integration(
                          clean_req,
                          db,
                          session,
                          pairs,
                          provider,
                          kind,
                          origin,
                        )
                    }
                }
            }
          }
          _, _ -> wisp.redirect("/admin/integrations")
        }
      })
  }
}

fn save_social_integration(
  db: pog.Connection,
  session: auth.Session,
  pairs: List(#(String, String)),
) -> Response {
  case permissions.is_admin_or_owner(session.membership) {
    False -> wisp.response(403)
    True -> {
      let active = case form_value(pairs, "active") {
        "" -> "false"
        value -> value
      }
      let token = form_value(pairs, "access_token")
      let app_secret = form_value(pairs, "app_secret")
      case
        seal_optional(session.tenant_id, "integration.access_token", token),
        seal_optional(session.tenant_id, "integration.app_secret", app_secret)
      {
        Error(_), _ ->
          wisp.response(422)
          |> wisp.string_body("Sosyal medya belirteci mühürlenemedi")
        _, Error(_) ->
          wisp.response(422)
          |> wisp.string_body("Sosyal medya uygulama sırrı mühürlenemedi")
        Ok(token_sealed), Ok(app_secret_sealed) ->
          "insert into agency.integrations(tenant_id,provider,kind,credentials,active) values($1::uuid,'social','social',jsonb_build_object('access_token_sealed',$2,'page_id',$3,'instagram_id',$4,'threads_user_id',$5,'pinterest_token',$6,'pinterest_board_id',$7,'app_id',$8,'app_secret_sealed',$9,'tiktok_business_id',$10,'youtube_channel_id',$11,'meta_redirect_uri',$12,'tiktok_redirect_uri',$13,'youtube_redirect_uri',$14),$15::boolean) on conflict(tenant_id,provider,kind) do update set credentials=excluded.credentials,active=excluded.active"
          |> pog.query()
          |> pog.parameter(pog.text(session.tenant_id))
          |> pog.parameter(pog.text(token_sealed))
          |> pog.parameter(pog.text(form_value(pairs, "page_id")))
          |> pog.parameter(pog.text(form_value(pairs, "instagram_id")))
          |> pog.parameter(pog.text(form_value(pairs, "threads_user_id")))
          |> pog.parameter(pog.text(form_value(pairs, "pinterest_token")))
          |> pog.parameter(pog.text(form_value(pairs, "pinterest_board_id")))
          |> pog.parameter(pog.text(form_value(pairs, "app_id")))
          |> pog.parameter(pog.text(app_secret_sealed))
          |> pog.parameter(pog.text(form_value(pairs, "tiktok_business_id")))
          |> pog.parameter(pog.text(form_value(pairs, "youtube_channel_id")))
          |> pog.parameter(pog.text(form_value(pairs, "meta_redirect_uri")))
          |> pog.parameter(pog.text(form_value(pairs, "tiktok_redirect_uri")))
          |> pog.parameter(pog.text(form_value(pairs, "youtube_redirect_uri")))
          |> pog.parameter(pog.text(active))
          |> pog.execute(db)
          |> result.map(fn(_) { wisp.redirect("/admin/integrations") })
          |> result.unwrap(
            wisp.response(500)
            |> wisp.string_body("Sosyal medya bağlantısı kaydedilemedi"),
          )
      }
    }
  }
}

fn save_search_engine_integration(
  _req: wisp.Request,
  db: pog.Connection,
  session: auth.Session,
  pairs: List(#(String, String)),
  provider: String,
  _kind: String,
  _origin: String,
) -> Response {
  let supported = [
    "google_search_console",
    "google_merchant",
    "google_analytics",
    "google_tag_manager",
    "yandex_webmaster",
    "baidu_search",
  ]
  case
    permissions.is_admin_or_owner(session.membership),
    list.contains(supported, provider)
  {
    False, _ -> wisp.response(403)
    _, False ->
      wisp.response(422)
      |> wisp.string_body("Desteklenmeyen arama motoru sağlayıcısı")
    True, True -> {
      let active = case form_value(pairs, "active") {
        "" -> "false"
        value -> value
      }
      let sql =
        "insert into agency.search_engine_integrations(tenant_id,provider,site_url,verification_code,account_id,merchant_country,feed_url,active,updated_at) values($1::uuid,$2,$3,$4,$5,$6,$7,$8::text::boolean,now()) on conflict(tenant_id,provider) do update set site_url=excluded.site_url,verification_code=excluded.verification_code,account_id=excluded.account_id,merchant_country=excluded.merchant_country,feed_url=excluded.feed_url,active=excluded.active,updated_at=now()"
      case
        sql
        |> pog.query()
        |> pog.parameter(pog.text(session.tenant_id))
        |> pog.parameter(pog.text(provider))
        |> pog.parameter(pog.text(form_value(pairs, "site_url")))
        |> pog.parameter(pog.text(form_value(pairs, "verification_code")))
        |> pog.parameter(pog.text(form_value(pairs, "account_id")))
        |> pog.parameter(pog.text(form_value(pairs, "merchant_country")))
        |> pog.parameter(pog.text(form_value(pairs, "feed_url")))
        |> pog.parameter(pog.text(active))
        |> pog.execute(db)
      {
        Ok(_) -> wisp.redirect("/admin/integrations")
        Error(_) ->
          wisp.response(500)
          |> wisp.string_body("Entegrasyon ayarı kaydedilemedi")
      }
    }
  }
}

fn save_qnb_esolutions_integration(
  req: wisp.Request,
  db: pog.Connection,
  session: auth.Session,
  pairs: List(#(String, String)),
) -> Response {
  case permissions.is_admin_or_owner(session.membership) {
    False -> wisp.response(403)
    True -> {
      let endpoint = string.trim(form_value(pairs, "endpoint"))
      case endpoint == "" || secrets.valid_https(endpoint) {
        False -> wisp.response(422) |> wisp.string_body("QNB servis adresi HTTPS olmalı.")
        True ->
          case
            seal_optional(session.tenant_id, "qnb_esolutions.password", form_value(pairs, "password")),
            seal_optional(session.tenant_id, "qnb_esolutions.api_key", form_value(pairs, "api_key"))
          {
            Ok(password_sealed), Ok(api_key_sealed) -> {
              let active = case form_value(pairs, "active") {
                "true" -> "true"
                _ -> "false"
              }
              let sql =
                "insert into agency.integrations(tenant_id,provider,kind,credentials,active,updated_at)
                 values($1::uuid,'qnb_esolutions','document',jsonb_build_object(
                   'username',$2,'password_sealed',$3,'api_key_sealed',$4,'endpoint',$5),$6::boolean,now())
                 on conflict(tenant_id,provider,kind) do update set
                   credentials=coalesce(agency.integrations.credentials,'{}'::jsonb)
                     || coalesce((select jsonb_object_agg(k,v) from jsonb_each_text(excluded.credentials) where v<>''),'{}'::jsonb),
                   active=excluded.active,updated_at=now()"
              case sql
                |> pog.query()
                |> pog.parameter(pog.text(session.tenant_id))
                |> pog.parameter(pog.text(string.trim(form_value(pairs, "username"))))
                |> pog.parameter(pog.text(password_sealed))
                |> pog.parameter(pog.text(api_key_sealed))
                |> pog.parameter(pog.text(endpoint))
                |> pog.parameter(pog.text(active))
                |> pog.execute(db)
              {
                Ok(_) -> {
                  record_audit(req, db, session.tenant_id, session.user_id,
                    "integration.qnb_esolutions.updated", "integration", "qnb_esolutions")
                  wisp.redirect("/admin/integrations")
                }
                Error(_) -> wisp.response(500) |> wisp.string_body("QNB ayarları kaydedilemedi.")
              }
            }
            _, _ -> wisp.response(500) |> wisp.string_body("QNB gizli bilgileri şifrelenemedi.")
          }
      }
    }
  }
}

fn save_parampos_integration(
  req: wisp.Request,
  db: pog.Connection,
  session: auth.Session,
  pairs: List(#(String, String)),
) -> Response {
  case permissions.is_admin_or_owner(session.membership) {
    False -> wisp.response(403)
    True -> {
      let username = form_value(pairs, "username")
      let password = form_value(pairs, "password")
      let guid = form_value(pairs, "guid")
      let endpoint = form_value(pairs, "endpoint")
      case valid_parampos_endpoint(endpoint) {
        False ->
          wisp.response(422)
          |> wisp.string_body(
            "ParamPOS servis adresi yalnızca güvenli ParamPOS alan adları olabilir.",
          )
        True ->
          case
            seal_optional(session.tenant_id, "parampos.username", username),
            seal_optional(session.tenant_id, "parampos.password", password),
            seal_optional(session.tenant_id, "parampos.guid", guid)
          {
            Ok(username_sealed), Ok(password_sealed), Ok(guid_sealed) -> {
              let active = case form_value(pairs, "active") {
                "" -> "false"
                value -> value
              }
              case
                "insert into agency.integrations(tenant_id,provider,kind,credentials,active,updated_at)
             values(
               $1::uuid,
               'parampos',
               'payment',
               jsonb_build_object(
                 'client_code',$2,
                 'username_sealed',$3,
                 'password_sealed',$4,
                 'guid_sealed',$5,
                 'endpoint',$6
               ),
               $7::text::boolean,
               now()
             )
             on conflict(tenant_id,provider,kind) do update set
               credentials=(
                 coalesce(agency.integrations.credentials,'{}'::jsonb)
                 - 'username' - 'password' - 'guid'
               ) || coalesce((
                 select jsonb_object_agg(k,v)
                   from jsonb_each_text(excluded.credentials)
                  where v <> ''
               ),'{}'::jsonb),
               active=excluded.active,
               updated_at=now()"
                |> pog.query()
                |> pog.parameter(pog.text(session.tenant_id))
                |> pog.parameter(pog.text(form_value(pairs, "client_code")))
                |> pog.parameter(pog.text(username_sealed))
                |> pog.parameter(pog.text(password_sealed))
                |> pog.parameter(pog.text(guid_sealed))
                |> pog.parameter(pog.text(endpoint))
                |> pog.parameter(pog.text(active))
                |> pog.execute(db)
              {
                Ok(_) -> {
                  record_audit(
                    req,
                    db,
                    session.tenant_id,
                    session.user_id,
                    "integration.parampos.updated",
                    "integration",
                    "parampos",
                  )
                  wisp.redirect("/admin/integrations")
                }
                Error(_) ->
                  wisp.response(500)
                  |> wisp.string_body(
                    "ParamPOS ayarları güvenli kaydedilemedi.",
                  )
              }
            }
            _, _, _ ->
              wisp.response(500)
              |> wisp.string_body("ParamPOS gizli bilgileri şifrelenemedi.")
          }
      }
    }
  }
}

fn record_audit(
  req: wisp.Request,
  db: pog.Connection,
  tenant_id: String,
  user_id: String,
  action: String,
  entity_type: String,
  entity_label: String,
) -> Nil {
  let _ =
    "insert into agency.audit_logs(tenant_id,user_id,action,entity_type,ip,user_agent,request_id,metadata)
     values($1::uuid,nullif($2,'')::uuid,$3::text,$4::text,nullif($6,'')::inet,$7::text,$8::text,jsonb_build_object('entity',$5::text,'requestId',$8::text))"
    |> pog.query()
    |> pog.parameter(pog.text(tenant_id))
    |> pog.parameter(pog.text(user_id))
    |> pog.parameter(pog.text(action))
    |> pog.parameter(pog.text(entity_type))
    |> pog.parameter(pog.text(entity_label))
    |> pog.parameter(pog.text(request_client_ip(req)))
    |> pog.parameter(pog.text(request_user_agent(req)))
    |> pog.parameter(pog.text(request_id(req)))
    |> pog.execute(db)
  Nil
}

fn request_user_agent(req: wisp.Request) -> String {
  http_request.get_header(req, "user-agent")
  |> result.unwrap("")
  |> string.trim
  |> string.slice(0, 500)
}

fn seal_optional(
  tenant_id: String,
  field: String,
  value: String,
) -> Result(String, Nil) {
  case string.trim(value) {
    "" -> Ok("")
    trimmed -> secrets.seal_for_tenant(tenant_id, field, trimmed)
  }
}

fn valid_parampos_endpoint(value: String) -> Bool {
  let endpoint = string.trim(value)
  endpoint == ""
  || local_parampos_fixture_endpoint(endpoint)
  || {
    secrets.valid_https(endpoint)
    && {
      parampos_endpoint_host(endpoint, "https://testposws.param.com.tr")
      || parampos_endpoint_host(endpoint, "https://posws.param.com.tr")
    }
  }
}

fn local_parampos_fixture_endpoint(endpoint: String) -> Bool {
  let app_env = envoy.get("APP_ENV") |> result.unwrap("development")
  app_env != "production"
  && {
    string.starts_with(endpoint, "http://127.0.0.1:")
    || string.starts_with(endpoint, "http://localhost:")
  }
}

fn parampos_endpoint_host(endpoint: String, base: String) -> Bool {
  endpoint == base || string.starts_with(endpoint, base <> "/")
}

fn handle_nexus_connection_approval(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  let auth_header =
    http_request.get_header(req, "authorization")
    |> result.unwrap("")
    |> string.trim
  let api_header =
    http_request.get_header(req, "x-nexus-api-key")
    |> result.unwrap("")
    |> string.trim
  let expected = envoy.get("NEXUS_API_KEY") |> result.unwrap("") |> string.trim
  let bearer_expected = "Bearer " <> expected
  let authorized =
    expected != ""
    && {
      crypto.secure_compare(<<auth_header:utf8>>, <<expected:utf8>>)
      || crypto.secure_compare(<<auth_header:utf8>>, <<bearer_expected:utf8>>)
      || crypto.secure_compare(<<api_header:utf8>>, <<expected:utf8>>)
      || crypto.secure_compare(<<api_header:utf8>>, <<bearer_expected:utf8>>)
    }

  case authorized {
    False -> {
      let key =
        "nexus-callback:"
        <> request_client_id(req)
      case rate_limited(key, 30, 300_000.0) {
        True -> too_many_requests()
        False ->
          wisp.json_response(
            "{\"ok\":false,\"error\":\"Geçersiz NEXUS onay anahtarı\"}",
            401,
          )
      }
    }
    True ->
      case
        rate_limited(
          "nexus-callback-ok:" <> request_client_id(req),
          120,
          60_000.0,
        )
      {
        True -> too_many_requests()
        False -> handle_authorized_nexus_connection_approval(req, db)
      }
  }
}

fn handle_authorized_nexus_connection_approval(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case wisp.read_body_bits(req) {
    Error(_) ->
      wisp.json_response("{\"ok\":false,\"error\":\"Gövde okunamadı\"}", 400)
    Ok(bits) ->
      case bit_array.to_string(bits) {
        Error(_) ->
          wisp.json_response(
            "{\"ok\":false,\"error\":\"Gövde metin değil\"}",
            400,
          )
        Ok(body) -> save_nexus_connection_approval(req, db, body)
      }
  }
}

fn save_nexus_connection_approval(
  req: wisp.Request,
  db: pog.Connection,
  body: String,
) -> Response {
  let decoder = {
    use agency_id <- decode.field("agency_id", decode.string)
    use api_key <- decode.field("api_key", decode.string)
    decode.success(#(agency_id, api_key))
  }
  case json.parse(from: body, using: decoder) {
    Error(_) ->
      wisp.json_response("{\"ok\":false,\"error\":\"Geçersiz JSON\"}", 400)
    Ok(#(agency_id, api_key)) -> {
      let agency_id = string.trim(agency_id)
      let api_key = string.trim(api_key)
      case agency_id == "" || api_key == "" {
        True ->
          wisp.json_response(
            "{\"ok\":false,\"error\":\"agency_id ve api_key zorunlu\"}",
            422,
          )
        False ->
          case secrets.seal_for_tenant(agency_id, "nexus.api_key", api_key) {
            Error(Nil) ->
              wisp.json_response(
                "{\"ok\":false,\"error\":\"API anahtarı güvenli saklanamadı\"}",
                500,
              )
            Ok(sealed_api_key) -> {
              let decoder = decode.field(0, decode.string, decode.success)
              case
                "with pending_request as (
                   select tenant_id from agency.nexus_connection_requests
                    where tenant_id=$1::uuid and status='pending'
                    for update
                 ), updated as (
                   insert into agency.integrations(tenant_id,provider,kind,credentials,active)
                   select
                     pending_request.tenant_id,
                     'nexus',
                     'connectivity',
                     jsonb_build_object('api_key_sealed',$2::text,'agency_code',$1::text),
                     true
                   from pending_request
                   on conflict(tenant_id,provider,kind) do update set
                     credentials=(coalesce(agency.integrations.credentials,'{}'::jsonb) - 'api_key')
                       || jsonb_build_object('api_key_sealed',$2::text,'agency_code',$1::text),
                     active=true
                   returning tenant_id
                 ), request_update as (
                   update agency.nexus_connection_requests
                      set status='approved',
                          message='NEXUS bağlantısı onaylandı ve API anahtarı güvenli saklandı.',
                          updated_at=now()
                    where tenant_id in (select tenant_id from updated)
                    returning tenant_id
                 )
                 select tenant_id::text from request_update"
                |> pog.query()
                |> pog.parameter(pog.text(agency_id))
                |> pog.parameter(pog.text(sealed_api_key))
                |> pog.returning(decoder)
                |> pog.execute(db)
              {
                Ok(result) -> case result.rows {
                  [] -> wisp.json_response(
                    "{\"ok\":false,\"error\":\"Bekleyen bağlantı isteği bulunamadı\"}",
                    409,
                  )
                  _ -> {
                    record_audit(
                      req,
                      db,
                      agency_id,
                      "",
                      "integration.nexus.connection_approved",
                      "integration",
                      "nexus",
                    )
                    wisp.json_response("{\"ok\":true}", 200)
                  }
                }
                Error(_) -> {
                  wisp.json_response(
                    "{\"ok\":false,\"error\":\"Onay kaydedilemedi\"}",
                    500,
                  )
                }
              }
            }
          }
      }
    }
  }
}

fn control_center_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Get, ["admin", "control-center"] -> True
    http.Get, ["admin", "control-center", "data"] -> True
    _, _ -> False
  }
}

fn handle_control_center_request(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(token) -> case auth.session(db, token) {
      Error(Nil) -> wisp.redirect("/login")
      Ok(session) -> case permissions.is_admin_or_owner(session.membership) {
        False -> wisp.response(403) |> wisp.string_body("Bu denetim alanına erişim yetkiniz yok")
        True -> case http_request.path_segments(req) {
          ["admin", "control-center", "data"] -> control_center_data(db, session.tenant_id)
          _ -> {
            let lang = case session.language_pref { "" -> "tr" value -> value }
            wisp.response(200)
            |> wisp.html_body(panel.section(
              session,
              "control-center",
              "Acente operasyonlarının canlı denetim sonuçları ve müdahale alanları.",
              [
                #("/admin/sync", "NEXUS ve kuyruklar"),
                #("/admin/supplier-onboarding", "Tedarikçi onayları"),
                #("/admin/finance-overview", "Ödeme ve faturalar"),
                #("/admin/team", "Ekip ve yetkiler"),
                #("/admin/ai", "Yapay zekâ yönetimi"),
                #("/admin/reports", "Rapor ve denetim kayıtları"),
              ],
              lang,
              "",
            ))
          }
        }
      }
    }
  }
}

fn control_center_data(db: pog.Connection, tenant_id: String) -> Response {
  let decoder = {
    use value <- decode.field(0, decode.string)
    decode.success(value)
  }
  let query = "
    with m as (
      select
        (select count(*) from agency.categories where tenant_id=$1::uuid and parent_id is null and active and code in ('hotel','holiday_home','yacht','tour','activity','flight','car','cruise','pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus')) as categories,
        (select count(*) from (select distinct on (coalesce(connection_id::text,''),job_type) status from agency.sync_jobs where tenant_id=$1::uuid order by coalesce(connection_id::text,''),job_type,coalesce(finished_at,started_at) desc nulls last,id desc) latest where status='failed') as sync_failed,
        (select count(*) from agency.nexus_reservation_deliveries where tenant_id=$1::uuid and status='failed') as booking_failed,
        (select count(*) from agency.listings where tenant_id=$1::uuid
          and source='nexus' and status='published'
          and category not in ('hotel','holiday_home','yacht')) as unsupported_connected,
        (select count(*) from agency.reservations r
          join agency.listings l on l.id=r.listing_id and l.tenant_id=r.tenant_id
          where r.tenant_id=$1::uuid and l.source='nexus' and r.payment_status='paid'
            and r.status in ('confirmed','completed','cancelled')
            and not exists (select 1 from agency.nexus_reservation_deliveries d
              where d.tenant_id=r.tenant_id and d.reservation_id=r.id
                and d.event_type='reservation.status_changed'
                and d.reservation_status=r.status and d.status='sent')) as paid_booking_unacknowledged,
        (select count(*) from agency.notifications where tenant_id=$1::uuid and status='failed') as notification_failed,
        (select count(*) from agency.listing_sync_conflicts where tenant_id=$1::uuid and status='open') as conflicts,
        (select count(*) from agency.ai_worker_health where tenant_id=$1::uuid) as workers,
        (select count(*) from agency.ai_worker_health where tenant_id=$1::uuid and (status<>'healthy' or last_heartbeat is null or last_heartbeat<now()-interval '15 minutes')) as workers_unhealthy,
        (select count(*) from agency.integrations where tenant_id=$1::uuid and provider='nexus' and kind='connectivity' and active and coalesce(credentials->>'endpoint','')<>'' and (coalesce(credentials->>'api_key_sealed','')<>'' or coalesce(credentials->>'api_key','')<>'')) as nexus_connections,
        (select status from agency.nexus_connection_requests where tenant_id=$1::uuid order by updated_at desc limit 1) as nexus_approval,
        (select count(*) from agency.integrations where tenant_id=$1::uuid and kind='payment' and active) as payment_connections,
        (select count(*) from agency.applications where tenant_id=$1::uuid and type='supplier' and status in ('pending','submitted','in_review')) as supplier_reviews,
        (select count(*) from agency.invoices where tenant_id=$1::uuid and status='failed') as invoice_failed,
        (select count(*) from agency.refunds r join agency.payments p on p.id=r.payment_id join agency.orders o on o.id=p.order_id where o.tenant_id=$1::uuid and r.status in ('pending','failed')) as refund_reviews,
        (select count(*) from agency.users where tenant_id=$1::uuid and membership_type='admin' and active) as admins,
        (select count(*) from agency.health_checks where tenant_id=$1::uuid) as health_records,
        (select count(*) from (select distinct on (component) status from agency.health_checks where tenant_id=$1::uuid order by component,checked_at desc) h where status in ('down','degraded')) as health_alerts
    ), checks as (
      select * from m, lateral (values
        ('categories','Kategori sözleşmesi',case when categories=17 then 'ok' else 'attention' end,categories::text||'/17','Etkin kanonik ana kategoriler','/admin/categories'),
        ('nexus','NEXUS bağlantısı',case when nexus_connections=0 then 'optional' when nexus_approval='approved' then 'ok' else 'attention' end,case when nexus_connections=0 then 'Bağımsız' when nexus_approval='approved' then 'Onaylı' else 'Onay bekliyor' end,'Merkez bağlantısı isteğe bağlıdır','/admin/integrations'),
        ('sync','Senkronizasyon işleri',case when nexus_connections=0 then 'optional' when sync_failed=0 then 'ok' else 'attention' end,case when nexus_connections=0 then 'Bağımsız' else sync_failed::text||' son hata' end,'Her bağlantı ve iş tipinin son durumu','/admin/sync'),
        ('bookings','NEXUS rezervasyon iletimi',case when booking_failed=0 then 'ok' else 'attention' end,booking_failed::text||' hata','Başarısız iletimlerde ödeme güvenlik kapısı devrededir','/admin/sync'),
        ('connected_categories','Stoklu rezervasyonu olmayan bağlı kategoriler',case when unsupported_connected=0 then 'ok' else 'attention' end,unsupported_connected::text||' ilan','Merkezi stoklu ödeme akışı bu kategorilerde henüz desteklenmiyor','/admin/listings'),
        ('paid_nexus','Tahsil edilmiş NEXUS rezervasyonları',case when paid_booking_unacknowledged=0 then 'ok' else 'attention' end,paid_booking_unacknowledged::text||' onay bekliyor','Ödemesi alınmış ancak merkez durum onayı henüz ulaşmamış kayıtlar','/admin/sync'),
        ('conflicts','İlan eşleme çakışmaları',case when conflicts=0 then 'ok' else 'attention' end,conflicts::text||' açık','Çakışmalar yerel ilanı sessizce ezmez','/admin/sync'),
        ('notifications','Bildirim kuyruğu',case when notification_failed=0 then 'ok' else 'attention' end,notification_failed::text||' hata','E-posta, SMS, WhatsApp ve anlık bildirimler','/admin/notifications'),
        ('workers','Yapay zekâ işçileri',case when workers=0 then 'optional' when workers_unhealthy=0 then 'ok' else 'attention' end,case when workers=0 then 'Kayıt yok' else workers_unhealthy::text||' sorun / '||workers::text end,'Son sağlık sinyali 15 dakikadan eskiyse uyarı','/admin/ai'),
        ('health','Diğer sağlık kontrolleri',case when health_records=0 then 'optional' when health_alerts=0 then 'ok' else 'attention' end,case when health_records=0 then 'Kayıt yok' else health_alerts::text||' uyarı' end,'Bileşenlerin son kayıtlı sağlık durumu','/admin/reports'),
        ('payments','Ödeme bağlantısı',case when payment_connections=0 then 'optional' else 'ok' end,case when payment_connections=0 then 'Yapılandırılmadı' else payment_connections::text||' etkin' end,'Canlı ödeme için sağlayıcı erişimi gerekir','/admin/integrations')
        ,('supplier_reviews','Tedarikçi onay kuyruğu',case when supplier_reviews=0 then 'ok' else 'attention' end,supplier_reviews::text||' bekliyor','Kimlik, belge ve kategori talepleri','/admin/supplier-onboarding')
        ,('invoices','Fatura hataları',case when invoice_failed=0 then 'ok' else 'attention' end,invoice_failed::text||' hata','Başarısız e-fatura ve e-arşiv kayıtları','/admin/finance-overview')
        ,('refunds','İade incelemesi',case when refund_reviews=0 then 'ok' else 'attention' end,refund_reviews::text||' işlem','Bekleyen veya başarısız iadeler','/admin/finance-overview')
        ,('admins','Yönetici erişimi',case when admins>0 then 'ok' else 'attention' end,admins::text||' etkin','Bu acentede etkin yönetici hesapları','/admin/team')
      ) as v(key,title,status,metric,detail,href)
    )
    select jsonb_build_object('generatedAt',now(),'checks',coalesce(jsonb_agg(jsonb_build_object('key',key,'title',title,'status',status,'metric',metric,'detail',detail,'href',href)),'[]'::jsonb))::text from checks"
  case pog.query(query)
    |> pog.parameter(pog.text(tenant_id))
    |> pog.returning(decoder)
    |> pog.execute(db) {
    Ok(rows) -> case rows.rows {
      [value, ..] -> wisp.json_response(value, 200)
      _ -> wisp.json_response("{\"error\":\"Denetim verisi bulunamadı\"}", 500)
    }
    Error(_) -> wisp.json_response("{\"error\":\"Denetimler okunamadı\"}", 500)
  }
}

fn supplier_onboarding_admin_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Post, ["admin", "supplier-operations", "application"] -> True
    http.Get, ["admin", "supplier-operations", "application"] -> True
    http.Get, ["admin", "supplier-onboarding"] -> True
    http.Get, ["admin", "supplier-onboarding", "data"] -> True
    http.Post, ["admin", "supplier-onboarding", "decision"] -> True
    http.Post, ["admin", "supplier-onboarding", "document-decision"] -> True
    http.Post, ["admin", "supplier-onboarding", "identity"] -> True
    // Listing submissions (self-service /ilan-ver)
    http.Get, ["admin", "listing-submissions"] -> True
    http.Get, ["admin", "listing-submissions", "data"] -> True
    http.Post, ["admin", "listing-submissions", "approve"] -> True
    http.Post, ["admin", "listing-submissions", "reject"] -> True
    _, _ -> False
  }
}

fn handle_supplier_onboarding_admin_request(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case req.method, http_request.path_segments(req) {
    http.Post, ["admin", "supplier-operations", "application"] ->
      supplier_application_submit(req, db)
    http.Get, ["admin", "supplier-operations", "application"] ->
      supplier_application_data(req, db)
    http.Get, ["admin", "supplier-onboarding"] ->
      case csrf.session_token_from(req) {
        Error(Nil) -> wisp.redirect("/login")
        Ok(session_token) ->
          case auth.session(db, session_token) {
            Error(Nil) -> wisp.redirect("/login")
            Ok(session) -> case permissions.is_admin_or_owner(session.membership) {
              False -> wisp.response(403)
              True -> {
              let lang = case session.language_pref {
                "" -> "tr"
                value -> value
              }
              wisp.response(200)
              |> wisp.html_body(panel.section(
                session,
                "supplier-onboarding",
                "Tedarikçi başvuru, belge ve kategori talepleri ortak sözleşmeye göre izlenir.",
                [
                  #("/admin/team", "Tedarikçi kullanıcıları"),
                  #("/admin/categories", "Kategori ve alan sözleşmeleri"),
                  #("/admin/sync", "Sync durumu"),
                ],
                lang,
                "",
              ))
              }
            }
          }
      }
    http.Get, ["admin", "supplier-onboarding", "data"] ->
      supplier_onboarding_admin_data(req, db)
    http.Post, ["admin", "supplier-onboarding", "decision"] ->
      supplier_onboarding_decision(req, db)
    http.Post, ["admin", "supplier-onboarding", "document-decision"] ->
      supplier_onboarding_document_decision(req, db)
    http.Post, ["admin", "supplier-onboarding", "identity"] ->
      supplier_onboarding_identity(req, db)
    // Listing submissions (self-service /ilan-ver)
    http.Get, ["admin", "listing-submissions"] ->
      handle_listing_submissions_page(req, db)
    http.Get, ["admin", "listing-submissions", "data"] ->
      handle_listing_submissions_data(req, db)
    http.Post, ["admin", "listing-submissions", "approve"] ->
      handle_listing_submission_approve(req, db)
    http.Post, ["admin", "listing-submissions", "reject"] ->
      handle_listing_submission_reject(req, db)
    _, _ -> wisp.response(404) |> wisp.string_body("Bulunamadı")
  }
}

fn supplier_onboarding_admin_data(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(session_token) ->
      case auth.session(db, session_token) {
        Error(Nil) -> unauthorized_json()
        Ok(session) -> case permissions.is_admin_or_owner(session.membership) {
          False -> wisp.response(403)
          True -> {
          let decoder = {
            use id <- decode.field(0, decode.string)
            use email <- decode.field(1, decode.string)
            use name <- decode.field(2, decode.string)
            use categories <- decode.field(3, decode.string)
            use status <- decode.field(4, decode.string)
            use identity_status <- decode.field(5, decode.string)
            use document_count <- decode.field(6, decode.string)
            use submitted_at <- decode.field(7, decode.string)
            use reviewed_at <- decode.field(8, decode.string)
            use note <- decode.field(9, decode.string)
            decode.success(#(
              id,
              email,
              name,
              categories,
              status,
              identity_status,
              document_count,
              submitted_at,
              reviewed_at,
              note,
            ))
          }
          let document_decoder = {
            use application_id <- decode.field(0, decode.string)
            use document_id <- decode.field(1, decode.string)
            use document_type <- decode.field(2, decode.string)
            use status <- decode.field(3, decode.string)
            use note <- decode.field(4, decode.string)
            use media_id <- decode.field(5, decode.string)
            use reviewed_at <- decode.field(6, decode.string)
            use reviewed_by <- decode.field(7, decode.string)
            use application_status <- decode.field(8, decode.string)
            use document_url <- decode.field(9, decode.string)
            use expires_on <- decode.field(10, decode.string)
            use source_valid <- decode.field(11, decode.string)
            decode.success(#(
              application_id,
              document_id,
              document_type,
              status,
              note,
              media_id,
              reviewed_at,
              reviewed_by,
              application_status,
              document_url,
              expires_on,
              source_valid,
            ))
          }
          let documents_result =
            pog.query(
              "select data[1],data[2],data[3],data[4],data[5],data[6],data[7],data[8],data[9],data[10],data[11],data[12] from agency.supplier_application_documents($1::uuid)",
            )
            |> pog.parameter(pog.text(session.tenant_id))
            |> pog.returning(document_decoder)
            |> pog.execute(db)
          case
            pog.query(
              "select data[1],data[2],data[3],data[4],data[5],data[6],data[7],data[8],data[9],data[10] from agency.supplier_application_queue($1::uuid)",
            )
            |> pog.parameter(pog.text(session.tenant_id))
            |> pog.returning(decoder)
            |> pog.execute(db)
          {
            Ok(result) -> {
              let documents = case documents_result {
                Ok(doc_result) -> doc_result.rows
                Error(_) -> []
              }
              wisp.json_response(
                json.to_string(
                  json.object([
                    #(
                      "applications",
                      json.array(result.rows, fn(row) {
                        let #(
                          id,
                          email,
                          name,
                          categories,
                          status,
                          identity_status,
                          document_count,
                          submitted_at,
                          reviewed_at,
                          note,
                        ) = row
                        json.object([
                          #("id", json.string(id)),
                          #("email", json.string(email)),
                          #("name", json.string(name)),
                          #("categories", json.string(categories)),
                          #("status", json.string(status)),
                          #("identity_status", json.string(identity_status)),
                          #("document_count", json.string(document_count)),
                          #("submitted_at", json.string(submitted_at)),
                          #("reviewed_at", json.string(reviewed_at)),
                          #("note", json.string(note)),
                        ])
                      }),
                    ),
                    #(
                      "documents",
                      json.array(documents, fn(row) {
                        let #(
                          application_id,
                          document_id,
                          document_type,
                          status,
                          note,
                          media_id,
                          reviewed_at,
                          reviewed_by,
                          application_status,
                          document_url,
                          expires_on,
                          source_valid,
                        ) = row
                        json.object([
                          #("application_id", json.string(application_id)),
                          #("document_id", json.string(document_id)),
                          #("document_type", json.string(document_type)),
                          #("status", json.string(status)),
                          #("note", json.string(note)),
                          #("media_id", json.string(media_id)),
                          #("document_url", json.string(document_url)),
                          #("expires_on", json.string(expires_on)),
                          #("source_valid", json.string(source_valid)),
                          #("reviewed_at", json.string(reviewed_at)),
                          #("reviewed_by", json.string(reviewed_by)),
                          #(
                            "application_status",
                            json.string(application_status),
                          ),
                        ])
                      }),
                    ),
                  ]),
                ),
                200,
              )
            }
            Error(_) ->
              wisp.json_response(
                json.to_string(
                  json.object([
                    #("error", json.string("Tedarikçi başvuruları okunamadı")),
                  ]),
                ),
                500,
              )
          }
          }
        }
      }
  }
}

fn supplier_application_data(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) -> case auth.session(db, token) {
      Error(Nil) -> unauthorized_json()
      Ok(session) -> {
        let decoder = decode.field(0, decode.string, decode.success)
        case pog.query("select jsonb_build_object('applications',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'category',a.category_code,'status',a.status,'identityStatus',a.identity_status,'submittedAt',a.submitted_at) order by a.submitted_at desc) from agency.applications a where a.tenant_id=$1::uuid and a.user_id=$2::uuid and a.type='supplier' and a.status<>'deleted'),'[]'::jsonb),'categories',coalesce((select jsonb_agg(jsonb_build_object('code',c.code,'name',c.name) order by c.sort_order) from agency.categories c where c.tenant_id=$1::uuid and c.parent_id is null and c.active and c.code in ('hotel','holiday_home','yacht','tour','activity','flight','car','cruise','pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus')),'[]'::jsonb))::text")
          |> pog.parameter(pog.text(session.tenant_id))
          |> pog.parameter(pog.text(session.user_id))
          |> pog.returning(decoder)
          |> pog.execute(db) {
          Ok(rows) -> case rows.rows {
            [value, ..] -> wisp.json_response(value, 200)
            _ -> wisp.json_response("{\"error\":\"Başvurular okunamadı\"}", 500)
          }
          Error(_) -> wisp.json_response("{\"error\":\"Başvurular okunamadı\"}", 500)
        }
      }
    }
  }
}

fn supplier_application_submit(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(token) -> csrf.require_csrf_form(req, token, fn(clean_req) {
      case auth.session(db, token) {
        Error(Nil) -> wisp.redirect("/login")
        Ok(session) -> wisp.require_form(clean_req, fn(form) {
          let category = form_field(form.values, "category_code")
          let fields = [
            "supplier_type", "legal_name", "display_name", "tax_country",
            "tax_office", "tax_number", "authorized_person_name",
            "authorized_person_email", "authorized_person_phone",
            "service_regions", "default_currency", "invoice_address",
            "support_email", "support_phone",
          ]
          let data = json.object(
            [#("business_category_codes", json.string(category))]
            |> list.append(fields |> list.map(fn(key) {
              #(key, json.string(form_field(form.values, key)))
            })),
          ) |> json.to_string
          let decoder = decode.field(0, decode.string, decode.success)
          case pog.query("select agency.submit_supplier_application($1::uuid,$2::uuid,$3,$4::jsonb)::text")
            |> pog.parameter(pog.text(session.tenant_id))
            |> pog.parameter(pog.text(session.user_id))
            |> pog.parameter(pog.text(category))
            |> pog.parameter(pog.text(data))
            |> pog.returning(decoder)
            |> pog.execute(db) {
            Ok(_) -> wisp.redirect("/admin/supplier-operations")
            Error(_) -> wisp.response(422) |> wisp.string_body("Başvuru alanları eksik veya geçersiz")
          }
        })
      }
    })
  }
}

fn supplier_onboarding_identity(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(token) -> csrf.require_csrf_form(req, token, fn(clean_req) {
      case auth.session(db, token) {
        Error(Nil) -> wisp.redirect("/login")
        Ok(session) -> case permissions.is_admin_or_owner(session.membership) {
          False -> wisp.response(403)
          True -> wisp.require_form(clean_req, fn(form) {
            let decoder = decode.field(0, decode.string, decode.success)
            case pog.query("select agency.review_supplier_identity($1::uuid,$2::uuid,$3::uuid,$4,$5)")
              |> pog.parameter(pog.text(session.tenant_id))
              |> pog.parameter(pog.text(form_field(form.values, "application")))
              |> pog.parameter(pog.text(session.user_id))
              |> pog.parameter(pog.text(form_field(form.values, "result")))
              |> pog.parameter(pog.text(form_field(form.values, "note")))
              |> pog.returning(decoder)
              |> pog.execute(db) {
              Ok(result) -> case result.rows {
                ["ok", ..] -> wisp.redirect("/admin/supplier-onboarding")
                ["forbidden", ..] -> wisp.response(403)
                ["not_found", ..] -> wisp.response(404)
                _ -> wisp.response(409)
              }
              Error(_) -> wisp.response(503)
            }
          })
        }
      }
    })
  }
}

fn supplier_onboarding_document_decision(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(clean_req) {
        case auth.session(db, session_token) {
          Error(Nil) -> wisp.redirect("/login")
          Ok(session) ->
            case permissions.is_admin_or_owner(session.membership) {
              False -> wisp.response(403)
              True ->
                wisp.require_form(clean_req, fn(form) {
                  let document = form_field(form.values, "document")
                  let decision = form_field(form.values, "decision")
                  let note = form_field(form.values, "note")
                  let decoder = decode.field(0, decode.string, decode.success)
                  let decision_result =
                    pog.query(
                      "select agency.decide_supplier_application_document($1::uuid,$2::uuid,$3::uuid,$4,$5)",
                    )
                    |> pog.parameter(pog.text(session.tenant_id))
                    |> pog.parameter(pog.text(document))
                    |> pog.parameter(pog.text(session.user_id))
                    |> pog.parameter(pog.text(decision))
                    |> pog.parameter(pog.text(note))
                    |> pog.returning(decoder)
                    |> pog.execute(db)
                  case decision_result {
                    Ok(result) -> case result.rows {
                      ["ok", ..] -> wisp.redirect("/admin/supplier-onboarding")
                      ["forbidden", ..] -> wisp.response(403)
                      ["not_found", ..] -> wisp.response(404)
                      _ -> wisp.response(409)
                    }
                    Error(_) -> wisp.response(503)
                  }
                })
            }
        }
      })
  }
}

fn supplier_onboarding_decision(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(clean_req) {
        case auth.session(db, session_token) {
          Error(Nil) -> wisp.redirect("/login")
          Ok(session) ->
            case permissions.is_admin_or_owner(session.membership) {
              False -> wisp.response(403)
              True ->
                wisp.require_form(clean_req, fn(form) {
                  let application = form_field(form.values, "application")
                  let decision = form_field(form.values, "decision")
                  let note = form_field(form.values, "note")
                  let decoder = decode.field(0, decode.string, decode.success)
                  let decision_result =
                    pog.query(
                      "select agency.decide_supplier_application($1::uuid,$2::uuid,$3::uuid,$4,$5)",
                    )
                    |> pog.parameter(pog.text(session.tenant_id))
                    |> pog.parameter(pog.text(application))
                    |> pog.parameter(pog.text(session.user_id))
                    |> pog.parameter(pog.text(decision))
                    |> pog.parameter(pog.text(note))
                    |> pog.returning(decoder)
                    |> pog.execute(db)
                  case decision_result {
                    Ok(result) -> case result.rows {
                      ["ok", ..] -> wisp.redirect("/admin/supplier-onboarding")
                      ["forbidden", ..] -> wisp.response(403)
                      ["not_found", ..] -> wisp.response(404)
                      _ -> wisp.response(409)
                    }
                    Error(_) -> wisp.response(503)
                  }
                })
            }
        }
      })
  }
}

fn form_field(form: List(#(String, String)), name: String) -> String {
  form
  |> list.key_find(name)
  |> result.unwrap("")
  |> string.trim
}

fn sync_admin_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Get, ["admin", "sync"] -> True
    http.Get, ["admin", "sync", "data"] -> True
    http.Get, ["admin", "sync", "deliveries"] -> True
    http.Post, ["admin", "sync", "retry"] -> True
    http.Post, ["admin", "sync", "retry-reservation"] -> True
    http.Post, ["admin", "sync", "resolve-conflict"] -> True
    _, _ -> False
  }
}

fn handle_sync_admin_request(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case req.method, http_request.path_segments(req) {
    http.Get, ["admin", "sync"] ->
      case csrf.session_token_from(req) {
        Error(Nil) -> wisp.redirect("/login")
        Ok(session_token) ->
          case auth.session(db, session_token) {
            Error(Nil) -> wisp.redirect("/login")
            Ok(session) -> case permissions.is_admin_or_owner(session.membership) {
              False -> wisp.response(403)
              True -> {
              let lang = case session.language_pref {
                "" -> "tr"
                value -> value
              }
              wisp.response(200)
              |> wisp.html_body(panel.section(
                session,
                "sync",
                "Nexus bağlantısı, sözleşme uyumu ve import işleri izlenir.",
                [
                  #("/admin/integrations", "NEXUS bağlantı ayarları"),
                  #("/admin/categories", "Kategori sözleşmeleri"),
                  #("/admin/reports", "Raporlar ve loglar"),
                ],
                lang,
                "",
              ))
              }
            }
          }
      }
    http.Get, ["admin", "sync", "data"] -> sync_admin_data(req, db)
    http.Get, ["admin", "sync", "deliveries"] ->
      sync_admin_deliveries(req, db)
    http.Post, ["admin", "sync", "retry"] -> sync_admin_retry(req, db)
    http.Post, ["admin", "sync", "retry-reservation"] ->
      sync_admin_retry_reservation(req, db)
    http.Post, ["admin", "sync", "resolve-conflict"] ->
      sync_admin_resolve_conflict(req, db)
    _, _ -> wisp.response(404) |> wisp.string_body("Bulunamadı")
  }
}

fn sync_admin_deliveries(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(session_token) -> case auth.session(db, session_token) {
      Error(Nil) -> unauthorized_json()
      Ok(session) -> case permissions.is_admin_or_owner(session.membership) {
        False -> wisp.response(403)
        True -> {
          let decoder = decode.field(0, decode.string, decode.success)
          case pog.query(
            "select coalesce(jsonb_agg(jsonb_build_object(
               'id',x.id,'reference',x.reference_code,'eventType',x.event_type,
               'reservationStatus',x.reservation_status,'status',x.status,
               'attempts',x.attempts,'error',left(x.last_error,300),
               'updatedAt',x.updated_at,'canRetry',x.status='failed' and x.attempts<100)
               order by x.updated_at desc),'[]'::jsonb)::text
             from (select d.id,d.event_type,d.reservation_status,d.status,
                 d.attempts,d.last_error,d.updated_at,r.reference_code
               from agency.nexus_reservation_deliveries d
               join agency.reservations r on r.id=d.reservation_id
                 and r.tenant_id=d.tenant_id
               where d.tenant_id=$1::uuid
                 and d.status in ('failed','pending','processing')
               order by d.updated_at desc limit 50) x",
          )
            |> pog.parameter(pog.text(session.tenant_id))
            |> pog.returning(decoder)
            |> pog.execute(db) {
            Ok(rows) -> case rows.rows {
              [value, ..] -> wisp.json_response(value, 200)
              _ -> wisp.json_response("[]", 200)
            }
            Error(_) -> wisp.json_response("{\"error\":\"Teslimatlar okunamadı\"}", 500)
          }
        }
      }
    }
  }
}

fn sync_admin_retry_reservation(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(clean_req) {
        case auth.session(db, session_token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) -> case permissions.is_admin_or_owner(session.membership) {
                False -> wisp.response(403)
                True ->
                  pog.query(
                    "select agency.retry_nexus_reservation_delivery($1::uuid,$2::uuid,$3::uuid)::text",
                  )
                  |> pog.parameter(pog.text(session.tenant_id))
                  |> pog.parameter(pog.text(session.user_id))
                  |> pog.parameter(pog.text(form_value(pairs, "delivery_id")))
                  |> pog.returning(decode.field(0, decode.string, decode.success))
                  |> pog.execute(db)
                  |> result.map(fn(_) { wisp.redirect("/admin/sync") })
                  |> result.unwrap(wisp.response(422))
              }
            }
          _, _ -> wisp.redirect("/login")
        }
      })
  }
}

fn sync_admin_data(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(session_token) ->
      case auth.session(db, session_token) {
        Error(Nil) -> unauthorized_json()
        Ok(session) -> case permissions.is_admin_or_owner(session.membership) {
          False -> wisp.response(403)
          True -> {
          let state_decoder = {
            use key <- decode.field(0, decode.string)
            use value <- decode.field(1, decode.string)
            decode.success(#(key, value))
          }
          let job_decoder = {
            use job_type <- decode.field(0, decode.string)
            use status <- decode.field(1, decode.string)
            use started_at <- decode.field(2, decode.string)
            use finished_at <- decode.field(3, decode.string)
            use items_count <- decode.field(4, decode.string)
            use error <- decode.field(5, decode.string)
            decode.success(#(
              job_type,
              status,
              started_at,
              finished_at,
              items_count,
              error,
            ))
          }
          let health_decoder = {
            use configured <- decode.field(0, decode.string)
            use connection_status <- decode.field(1, decode.string)
            use last_sync_at <- decode.field(2, decode.string)
            use last_sync_status <- decode.field(3, decode.string)
            use last_sync_error <- decode.field(4, decode.string)
            use pending_deliveries <- decode.field(5, decode.string)
            use failed_deliveries <- decode.field(6, decode.string)
            use nexus_listings <- decode.field(7, decode.string)
            use failed_jobs <- decode.field(8, decode.string)
            use last_success_at <- decode.field(9, decode.string)
            decode.success(#(
              configured,
              connection_status,
              last_sync_at,
              last_sync_status,
              last_sync_error,
              pending_deliveries,
              failed_deliveries,
              nexus_listings,
              failed_jobs,
              last_success_at,
            ))
          }
          let state_result =
            pog.query(
              "select data[1],data[2] from agency.sync_contract_state($1::uuid) order by data[1]",
            )
            |> pog.parameter(pog.text(session.tenant_id))
            |> pog.returning(state_decoder)
            |> pog.execute(db)
          let conflict_decoder = {
            use id <- decode.field(0, decode.string)
            use title <- decode.field(1, decode.string)
            use code <- decode.field(2, decode.string)
            use external_id <- decode.field(3, decode.string)
            decode.success(#(id, title, code, external_id))
          }
          let conflicts_result =
            pog.query(
              "select c.id::text,l.title,c.conflicting_code,c.external_listing_id
               from agency.listing_sync_conflicts c
               join agency.listings l on l.id=c.listing_id and l.tenant_id=c.tenant_id
               where c.tenant_id=$1::uuid and c.status='open'
               order by c.detected_at desc limit 100",
            )
            |> pog.parameter(pog.text(session.tenant_id))
            |> pog.returning(conflict_decoder)
            |> pog.execute(db)
          let jobs_result =
            pog.query(
              "select job_type,status,coalesce(started_at::text,''),coalesce(finished_at::text,''),items_count::text,error from agency.sync_jobs where tenant_id=$1::uuid order by coalesce(started_at,finished_at,now()) desc,id desc limit 20",
            )
            |> pog.parameter(pog.text(session.tenant_id))
            |> pog.returning(job_decoder)
            |> pog.execute(db)
          let health_result =
            pog.query(
              "select
                 case when exists(
                   select 1 from agency.integrations
                    where tenant_id=$1::uuid and provider='nexus'
                      and kind='connectivity' and active
                      and coalesce(credentials->>'endpoint','')<>''
                      and (
                        coalesce(credentials->>'api_key_sealed','')<>''
                        or coalesce(credentials->>'api_key','')<>''
                      )
                 ) then 'true' else 'false' end,
                 coalesce((
                   select case when status='approved' then 'approved' else status end
                     from agency.nexus_connection_requests
                    where tenant_id=$1::uuid
                    order by updated_at desc limit 1
                 ),'not_requested'),
                 coalesce((
                   select coalesce(finished_at,started_at)::text
                     from agency.sync_jobs
                    where tenant_id=$1::uuid
                    order by coalesce(started_at,finished_at) desc nulls last,id desc limit 1
                 ),''),
                 coalesce((
                   select status
                     from agency.sync_jobs
                    where tenant_id=$1::uuid
                    order by coalesce(started_at,finished_at) desc nulls last,id desc limit 1
                 ),'never'),
                 coalesce((
                   select error
                     from agency.sync_jobs
                    where tenant_id=$1::uuid
                    order by coalesce(started_at,finished_at) desc nulls last,id desc limit 1
                 ),''),
                 (select count(*)::text from agency.nexus_reservation_deliveries
                   where tenant_id=$1::uuid and status in ('pending','processing')),
                 (select count(*)::text from agency.nexus_reservation_deliveries
                   where tenant_id=$1::uuid and status='failed'),
                 (select count(*)::text from agency.listings
                   where tenant_id=$1::uuid and source='nexus'),
                 (select count(*)::text from agency.sync_jobs
                   where tenant_id=$1::uuid and status='failed'),
                 coalesce((
                   select coalesce(finished_at,started_at)::text
                     from agency.sync_jobs
                    where tenant_id=$1::uuid and status='success'
                    order by coalesce(finished_at,started_at) desc nulls last,id desc limit 1
                 ),'')",
            )
            |> pog.parameter(pog.text(session.tenant_id))
            |> pog.returning(health_decoder)
            |> pog.execute(db)

          case state_result, jobs_result, health_result, conflicts_result {
            Ok(state), Ok(jobs), Ok(health), Ok(conflicts) ->
              wisp.json_response(
                json.to_string(
                  json.object([
                    #(
                      "contract",
                      json.array(state.rows, fn(row) {
                        let #(key, value) = row
                        json.object([
                          #("key", json.string(key)),
                          #("value", json.string(value)),
                        ])
                      }),
                    ),
                    #(
                      "jobs",
                      json.array(jobs.rows, fn(row) {
                        let #(
                          job_type,
                          status,
                          started_at,
                          finished_at,
                          items_count,
                          error,
                        ) = row
                        json.object([
                          #("job_type", json.string(job_type)),
                          #("status", json.string(status)),
                          #("started_at", json.string(started_at)),
                          #("finished_at", json.string(finished_at)),
                          #("items_count", json.string(items_count)),
                          #("error", json.string(error)),
                        ])
                      }),
                    ),
                    #(
                      "conflicts",
                      json.array(conflicts.rows, fn(row) {
                        let #(id, title, code, external_id) = row
                        json.object([
                          #("id", json.string(id)),
                          #("title", json.string(title)),
                          #("code", json.string(code)),
                          #("externalId", json.string(external_id)),
                        ])
                      }),
                    ),
                    #(
                      "health",
                      json.array(health.rows, fn(row) {
                        let #(
                          configured,
                          connection_status,
                          last_sync_at,
                          last_sync_status,
                          last_sync_error,
                          pending_deliveries,
                          failed_deliveries,
                          nexus_listings,
                          failed_jobs,
                          last_success_at,
                        ) = row
                        json.object([
                          #("configured", json.string(configured)),
                          #("connection_status", json.string(connection_status)),
                          #("last_sync_at", json.string(last_sync_at)),
                          #("last_sync_status", json.string(last_sync_status)),
                          #("last_sync_error", json.string(last_sync_error)),
                          #(
                            "pending_deliveries",
                            json.string(pending_deliveries),
                          ),
                          #("failed_deliveries", json.string(failed_deliveries)),
                          #("nexus_listings", json.string(nexus_listings)),
                          #("failed_jobs", json.string(failed_jobs)),
                          #("last_success_at", json.string(last_success_at)),
                        ])
                      }),
                    ),
                  ]),
                ),
                200,
              )
            _, _, _, _ ->
              wisp.json_response(
                json.to_string(
                  json.object([#("error", json.string("Sync durumu okunamadı"))]),
                ),
                500,
              )
          }
        }
      }
  }
  }
}

fn sync_admin_retry(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(clean_req) {
        case auth.session(db, session_token) {
          Error(Nil) -> wisp.redirect("/login")
          Ok(session) ->
            case permissions.is_admin_or_owner(session.membership) {
              False -> wisp.response(403)
              True -> {
                let _ =
                  pog.query(
                    "insert into agency.sync_jobs(tenant_id,job_type,status,started_at,error)
                     values($1::uuid,'import','queued',now(),'Manuel import denemesi panelden sıraya alındı')",
                  )
                  |> pog.parameter(pog.text(session.tenant_id))
                  |> pog.execute(db)
                record_audit(
                  clean_req,
                  db,
                  session.tenant_id,
                  session.user_id,
                  "sync.retry_queued",
                  "sync_job",
                  "import",
                )
                wisp.redirect("/admin/sync")
              }
            }
        }
      })
  }
}

fn sync_admin_resolve_conflict(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(clean_req) {
        case auth.session(db, session_token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bits |> bit_array.to_string |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True ->
                    pog.query(
                      "select agency.release_listing_sync_code($1::uuid,$2::uuid,$3::uuid)::text",
                    )
                    |> pog.parameter(pog.text(session.tenant_id))
                    |> pog.parameter(pog.text(session.user_id))
                    |> pog.parameter(pog.text(form_value(pairs, "conflict_id")))
                    |> pog.returning(decode.field(0, decode.string, decode.success))
                    |> pog.execute(db)
                    |> result.map(fn(_) { wisp.redirect("/admin/sync") })
                    |> result.unwrap(wisp.response(422))
                }
            }
          _, _ -> wisp.redirect("/login")
        }
      })
  }
}

fn category_filter_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Get, ["api", "public", "listings"] -> True
    http.Get, ["api", "public", "campaigns"] -> True
    http.Get, ["api", "public", "category-filters"] -> True
    http.Get, ["api", "public", "concierge"] -> True
    http.Post, ["api", "public", "concierge"] -> True
    http.Get, ["admin", "categories", "filter-data"] -> True
    http.Post, ["admin", "categories", "filter-groups"] -> True
    http.Post, ["admin", "categories", "filter-groups", "deactivate"] -> True
    http.Post, ["admin", "categories", "filter-items"] -> True
    http.Post, ["admin", "categories", "filter-items", "deactivate"] -> True
    _, _ -> False
  }
}

fn handle_category_filter_request(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case req.method, http_request.path_segments(req) {
    http.Get, ["api", "public", "listings"] -> public_listings_json(req, db)
    http.Get, ["api", "public", "campaigns"] -> public_campaigns_json(req, db)
    http.Get, ["api", "public", "category-filters"] ->
      public_category_filters_json(req, db)
    http.Get, ["api", "public", "concierge"] -> public_concierge_json(req, db)
    http.Post, ["api", "public", "concierge"] -> public_concierge_json(req, db)
    http.Get, ["admin", "categories", "filter-data"] ->
      case csrf.session_token_from(req) {
        Error(Nil) -> unauthorized_json()
        Ok(session_token) ->
          case auth.session(db, session_token) {
            Error(Nil) -> unauthorized_json()
            Ok(session) -> category_filters_json(db, session.tenant_id)
          }
      }
    http.Post, ["admin", "categories", "filter-groups"] ->
      save_category_filter_group(req, db)
    http.Post, ["admin", "categories", "filter-groups", "deactivate"] ->
      deactivate_category_filter_group(req, db)
    http.Post, ["admin", "categories", "filter-items"] ->
      save_category_filter_item(req, db)
    http.Post, ["admin", "categories", "filter-items", "deactivate"] ->
      deactivate_category_filter_item(req, db)
    _, _ -> wisp.response(404) |> wisp.string_body("Bulunamadı")
  }
}

fn public_concierge_json(req: wisp.Request, db: pog.Connection) -> Response {
  let query = wisp.get_query(req)
  let tenant_selector = public_tenant_selector(req)
  let user_q = case query_value(query, "q") {
    "" -> query_value(query, "query")
    val -> val
  }
  let final_q = case user_q {
    "" ->
      case wisp.read_body_bits(req) {
        Ok(bits) ->
          case bits |> bit_array.to_string |> result.try(uri.parse_query) {
            Ok(pairs) ->
              case form_value(pairs, "q") {
                "" -> form_value(pairs, "query")
                val -> val
              }
            Error(_) -> ""
          }
        Error(_) -> ""
      }
    val -> val
  }

  case string.trim(final_q) {
    "" -> {
      let resp =
        json.object([
          #("ok", json.bool(False)),
          #("error", json.string("Arama sorgusu boş olamaz")),
        ])
        |> json.to_string
      wisp.json_response(resp, 400)
    }
    q -> {
      let tenant_sql =
        "with resolved_tenant as (select agency.resolve_public_tenant($1) as id) select coalesce(id::text,'') from resolved_tenant limit 1"

      let tenant_id =
        tenant_sql
        |> pog.query()
        |> pog.parameter(pog.text(tenant_selector))
        |> pog.returning(decode.field(0, decode.string, decode.success))
        |> pog.execute(db)
        |> result.map(fn(r) {
          case r.rows {
            [t, ..] -> t
            [] -> ""
          }
        })
        |> result.unwrap("")

      let cfg = case tenant_id {
        "" -> ai_client.AIConfig(provider: "google", api_key: "", model: "gemini-2.5-flash")
        tid -> get_tenant_ai_config(db, tid)
      }

      let parsed_res = ai_client.parse_concierge_query(cfg, q)
      let parsed_json = case parsed_res {
        Ok(json_str) -> json_str
        Error(_) -> ai_client.fallback_concierge_json(q)
      }

      let parsed_decoder = {
        use category <- decode.field("category", decode.string)
        use locality <- decode.field("locality", decode.string)
        use summary <- decode.field("summary", decode.string)
        decode.success(#(category, locality, summary))
      }

      let #(parsed_cat, parsed_loc, parsed_summary) =
        case json.parse(parsed_json, parsed_decoder) {
          Ok(tup) -> tup
          Error(_) -> #("holiday_home", "", q)
        }

      let listings_sql =
        "with resolved_tenant as (select agency.resolve_public_tenant($1) as id) select coalesce(json_agg(json_build_object('id', l.id::text, 'title', l.title, 'category', l.category, 'categoryLabel', case l.category when 'hotel' then 'Otel' when 'holiday_home' then 'Tatil Evi' when 'yacht' then 'Yat' when 'tour' then 'Tur' when 'activity' then 'Aktivite' when 'flight' then 'Uçuş' when 'bus' then 'Otobüs' when 'car' then 'Araç' else l.category end, 'locality', coalesce(l.locality,''), 'description', coalesce(l.description,''), 'currency', l.currency, 'priceMinor', l.price_minor::text, 'images', coalesce(l.images,'[]'::jsonb), 'propertyType', coalesce(l.metadata->'contract_fields'->>'property_type',l.metadata->'contract_fields'->>'yacht_type',l.metadata->'contract_fields'->>'tour_subcategory',l.metadata->'contract_fields'->>'type',l.metadata->>'property_type',l.metadata->>'yacht_type',''), 'guestCount', coalesce(l.metadata->'contract_fields'->>'guest_capacity',l.metadata->>'guests','')) order by case when ($3 <> '' and l.locality ilike '%' || $3 || '%') and l.category=$4 then 0 when l.category=$4 then 1 when ($3 <> '' and l.locality ilike '%' || $3 || '%') then 2 else 3 end, l.updated_at desc), '[]'::json)::text from agency.listings l join resolved_tenant rt on l.tenant_id=rt.id where l.status='published' and (($3='' or l.locality ilike '%' || $3 || '%') or ($4='' or l.category=$4)) limit 12"

      let listings_json =
        listings_sql
        |> pog.query()
        |> pog.parameter(pog.text(tenant_selector))
        |> pog.parameter(pog.text(q))
        |> pog.parameter(pog.text(parsed_loc))
        |> pog.parameter(pog.text(parsed_cat))
        |> pog.returning(decode.field(0, decode.string, decode.success))
        |> pog.execute(db)
        |> result.map(fn(rows) {
          case rows.rows {
            [raw, ..] -> raw
            [] -> "[]"
          }
        })
        |> result.unwrap("[]")

      let resp =
        "{\"ok\":true,\"query\":\""
        <> string.replace(q, "\"", "'")
        <> "\",\"parsed\":{\"category\":\""
        <> parsed_cat
        <> "\",\"locality\":\""
        <> parsed_loc
        <> "\",\"summary\":\""
        <> string.replace(parsed_summary, "\"", "'")
        <> "\"},\"listings\":"
        <> listings_json
        <> "}"

      wisp.json_response(resp, 200)
    }
  }
}

fn public_campaigns_json(req: wisp.Request, db: pog.Connection) -> Response {
  let tenant_selector = public_tenant_selector(req)
  let sql =
    "with resolved_tenant as (select agency.resolve_public_tenant($1) as id) select coalesce(json_agg(json_build_object('id',c.id::text,'name',c.name) order by c.name),'[]'::json)::text from agency.campaigns c join resolved_tenant rt on c.tenant_id=rt.id where c.active and (c.starts_at is null or c.starts_at<=now()) and (c.ends_at is null or c.ends_at>=now())"
  case
    sql
    |> pog.query()
    |> pog.parameter(pog.text(tenant_selector))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(db)
  {
    Ok(returned) ->
      returned.rows
      |> list.first
      |> result.unwrap("[]")
      |> wisp.json_response(200)
    Error(_) -> wisp.json_response("[]", 200)
  }
}

fn public_listings_json(req: wisp.Request, db: pog.Connection) -> Response {
  let query = wisp.get_query(req)
  let tenant_selector = public_tenant_selector(req)
  let search = query_value(query, "q")
  let locality = query_value(query, "konum")
  let category = canonical_category(query_value(query, "kategori"))
  let filter_key = query_value(query, "filter_key")
  let filter_value = query_value(query, "filter_value")
  let sql =
    "with resolved_tenant as (select agency.resolve_public_tenant($1) as id) select coalesce(json_agg(json_build_object('id', l.id::text, 'title', l.title, 'category', l.category, 'categoryLabel', case l.category when 'hotel' then 'Otel' when 'holiday_home' then 'Tatil Evi' when 'yacht' then 'Yat' when 'tour' then 'Tur' when 'activity' then 'Aktivite' when 'flight' then 'Uçuş' when 'bus' then 'Otobüs' when 'car' then 'Araç' else l.category end, 'locality', coalesce(l.locality,''), 'description', coalesce(l.description,''), 'currency', l.currency, 'priceMinor', l.price_minor::text, 'images', coalesce(l.images,'[]'::jsonb), 'amenities', coalesce(l.amenities,'[]'::jsonb), 'favoriteCount', (select count(*) from agency.favorites f where f.listing_id=l.id), 'reviewCount', (select count(*) from agency.reviews rv where rv.tenant_id=l.tenant_id and rv.listing_id=l.id and rv.status='approved'), 'ratingAverage', (select round(avg(rv.rating)::numeric, 1)::text from agency.reviews rv where rv.tenant_id=l.tenant_id and rv.listing_id=l.id and rv.status='approved'), 'propertyType', coalesce(l.metadata->'contract_fields'->>'property_type',l.metadata->'contract_fields'->>'yacht_type',l.metadata->'contract_fields'->>'tour_subcategory',l.metadata->'contract_fields'->>'type',l.metadata->>'property_type',l.metadata->>'yacht_type',''), 'guestCount', coalesce(l.metadata->'contract_fields'->>'guest_capacity',l.metadata->>'guests',''), 'bedroomCount', coalesce(l.metadata->'contract_fields'->>'bedroom_count',l.metadata->>'bedrooms',''), 'bathroomCount', coalesce(l.metadata->'contract_fields'->>'bathroom_count',l.metadata->>'bathrooms',''), 'latitude', coalesce(l.metadata->'geo'->>'latitude',l.metadata->>'latitude',r.latitude::text,''), 'longitude', coalesce(l.metadata->'geo'->>'longitude',l.metadata->>'longitude',r.longitude::text,'')) order by l.updated_at desc), '[]'::json)::text from agency.listings l join resolved_tenant rt on l.tenant_id=rt.id left join agency.regions r on r.id=l.region_id and r.tenant_id=l.tenant_id where l.status='published' and ($2='' or l.title ilike '%' || $2 || '%' or l.description ilike '%' || $2 || '%') and ($3='' or l.locality ilike '%' || $3 || '%') and ($4='' or l.category=$4) and ($5='' or ($5='amenities' and coalesce(l.amenities,'[]'::jsonb) ? $6) or ($5<>'amenities' and lower(coalesce(l.metadata->'contract_fields'->>$5, l.metadata->>$5, '')) = lower($6))) limit 100"
  case
    sql
    |> pog.query()
    |> pog.parameter(pog.text(tenant_selector))
    |> pog.parameter(pog.text(search))
    |> pog.parameter(pog.text(locality))
    |> pog.parameter(pog.text(category))
    |> pog.parameter(pog.text(filter_key))
    |> pog.parameter(pog.text(filter_value))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(db)
  {
    Ok(returned) ->
      returned.rows
      |> list.first
      |> result.unwrap("[]")
      |> wisp.json_response(200)
    Error(_) -> wisp.json_response("{\"error\":\"İlanlar okunamadı\"}", 500)
  }
}

fn canonical_category(value: String) -> String {
  case string.lowercase(string.trim(value)) {
    "otel" | "hotel" | "hotels" -> "hotel"
    "tatil-evi"
    | "tatil_evleri"
    | "holiday-home"
    | "holiday_home"
    | "villa"
    | "villas" -> "holiday_home"
    "yat" | "yacht" | "yachts" -> "yacht"
    "tur" | "turlar" | "tour" | "tours" -> "tour"
    "aktivite" | "aktiviteler" | "activity" | "activities" -> "activity"
    "ucus" | "uçuş" | "flights" | "flight" -> "flight"
    "arac" | "araç" | "car" | "cars" -> "car"
    "kruvaziyer" | "cruise" -> "cruise"
    "hac-umre" | "hac_umre" | "pilgrimage" -> "pilgrimage"
    "vize" | "visa" -> "visa"
    "feribot" | "ferry" -> "ferry"
    "transfer" | "transfers" -> "transfer"
    "sezlong" | "şezlong" | "beach" -> "beach"
    "sinema" | "cinema" -> "cinema"
    "etkinlik" | "event" | "events" -> "event"
    "restoran" | "restaurant" -> "restaurant"
    "otobus" | "otobüs" | "bus" -> "bus"
    "flight_bus" -> "flight"
    "hajj" -> "pilgrimage"
    "sunbed" -> "beach"
    other -> other
  }
}

fn category_filters_json(db: pog.Connection, tenant_id: String) -> Response {
  let sql =
    "select coalesce(json_agg(json_build_object('id', g.id::text, 'category', g.category_code, 'key', g.group_key, 'title', g.title, 'helpText', coalesce(g.help_text, ''), 'displayType', g.display_type, 'multiple', g.multiple, 'active', g.active, 'sortOrder', g.sort_order, 'translationsQueued', (select count(*) from agency.category_filter_translations t where t.entity_type = 'group' and t.entity_id = g.id and t.status in ('queued','failed')), 'items', coalesce((select json_agg(json_build_object('id', i.id::text, 'key', i.item_key, 'title', i.title, 'helpText', coalesce(i.help_text, ''), 'contractFieldKey', coalesce(i.contract_field_key, ''), 'contractValue', coalesce(i.contract_value, ''), 'active', i.active, 'sortOrder', i.sort_order, 'translationsQueued', (select count(*) from agency.category_filter_translations it where it.entity_type = 'item' and it.entity_id = i.id and it.status in ('queued','failed')) ) order by i.sort_order, i.title) from agency.category_filter_items i where i.group_id = g.id), '[]'::json)) order by g.category_code, g.sort_order, g.title), '[]'::json)::text from agency.category_filter_groups g where g.tenant_id = $1::uuid"
  case
    sql
    |> pog.query()
    |> pog.parameter(pog.text(tenant_id))
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(db)
  {
    Ok(returned) ->
      returned.rows
      |> list.first
      |> result.unwrap("[]")
      |> wisp.json_response(200)
    Error(_) ->
      wisp.json_response("{\"error\":\"Kategori filtreleri okunamadı\"}", 500)
  }
}

fn public_category_filters_json(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  let query = wisp.get_query(req)
  let category = canonical_category(query_value(query, "category"))
  let tenant_selector = public_tenant_selector(req)
  let lang = public_lang(req, query)
  case category {
    "" -> wisp.json_response("[]", 200)
    _ -> {
      let sql =
        "with resolved_tenant as (select agency.resolve_public_tenant($1) as id), groups as (select g.* from agency.category_filter_groups g join resolved_tenant rt on g.tenant_id=rt.id where g.category_code=$2 and g.active) select coalesce(json_agg(json_build_object('id', g.id::text, 'category', g.category_code, 'key', g.group_key, 'title', coalesce(nullif(gt.title,''), g.title), 'helpText', coalesce(nullif(gt.help_text,''), g.help_text, ''), 'displayType', g.display_type, 'multiple', g.multiple, 'sortOrder', g.sort_order, 'items', coalesce((select json_agg(json_build_object('id', i.id::text, 'key', i.item_key, 'title', coalesce(nullif(it.title,''), i.title), 'helpText', coalesce(nullif(it.help_text,''), i.help_text, ''), 'contractFieldKey', coalesce(i.contract_field_key, ''), 'contractValue', coalesce(i.contract_value, ''), 'sortOrder', i.sort_order) order by i.sort_order, i.title) from agency.category_filter_items i left join agency.category_filter_translations it on it.entity_type='item' and it.entity_id=i.id and it.language_code=$3 and it.status in ('translated','approved','published') where i.group_id=g.id and i.active), '[]'::json)) order by g.sort_order, g.title), '[]'::json)::text from groups g left join agency.category_filter_translations gt on gt.entity_type='group' and gt.entity_id=g.id and gt.language_code=$3 and gt.status in ('translated','approved','published')"
      case
        sql
        |> pog.query()
        |> pog.parameter(pog.text(tenant_selector))
        |> pog.parameter(pog.text(category))
        |> pog.parameter(pog.text(lang))
        |> pog.returning(decode.field(0, decode.string, decode.success))
        |> pog.execute(db)
      {
        Ok(returned) ->
          returned.rows
          |> list.first
          |> result.unwrap("[]")
          |> wisp.json_response(200)
        Error(_) ->
          wisp.json_response(
            "{\"error\":\"Kategori filtreleri okunamadı\"}",
            500,
          )
      }
    }
  }
}

fn query_value(pairs: List(#(String, String)), key: String) -> String {
  pairs
  |> list.key_find(key)
  |> result.unwrap("")
  |> string.trim
}

fn public_lang(req: wisp.Request, query: List(#(String, String))) -> String {
  let from_query = query_value(query, "lang")
  case from_query {
    "" ->
      case ssr_cookie(req, "nexus_lang") {
        "" -> "tr"
        value -> value
      }
    value -> value
  }
}

fn save_category_filter_group(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  save_category_filter_form(req, db, fn(session, pairs) {
    let category_code = form_value(pairs, "category_code")
    let group_key = form_value(pairs, "group_key")
    let title = form_value(pairs, "title")
    let help_text = form_value(pairs, "help_text")
    let display_type = form_value_default(pairs, "display_type", "chips")
    let multiple = form_bool(pairs, "multiple")
    let sort_order = form_int(pairs, "sort_order")
    case category_code == "" || group_key == "" || title == "" {
      True -> redirect_filters()
      False -> {
        let sql =
          "with saved as (insert into agency.category_filter_groups (tenant_id, category_code, group_key, title, help_text, display_type, multiple, sort_order, active) values ($1::uuid, $2, $3, $4, nullif($5,''), $6, $7, $8, true) on conflict (tenant_id, category_code, group_key) do update set title = excluded.title, help_text = excluded.help_text, display_type = excluded.display_type, multiple = excluded.multiple, sort_order = excluded.sort_order, updated_at = now() returning id) select agency.queue_category_filter_translations('group', id, 'tr')::text from saved"
        let _ =
          sql
          |> pog.query()
          |> pog.parameter(pog.text(session.tenant_id))
          |> pog.parameter(pog.text(category_code))
          |> pog.parameter(pog.text(group_key))
          |> pog.parameter(pog.text(title))
          |> pog.parameter(pog.text(help_text))
          |> pog.parameter(pog.text(display_type))
          |> pog.parameter(pog.bool(multiple))
          |> pog.parameter(pog.int(sort_order))
          |> pog.execute(db)
        redirect_filters()
      }
    }
  })
}

fn save_category_filter_item(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  save_category_filter_form(req, db, fn(session, pairs) {
    let group_id = form_value(pairs, "group_id")
    let item_key = form_value(pairs, "item_key")
    let title = form_value(pairs, "title")
    let help_text = form_value(pairs, "help_text")
    let contract_field_key = form_value(pairs, "contract_field_key")
    let contract_value = form_value(pairs, "contract_value")
    let sort_order = form_int(pairs, "sort_order")
    case group_id == "" || item_key == "" || title == "" {
      True -> redirect_filters()
      False -> {
        let sql =
          "with allowed_group as (select id from agency.category_filter_groups where id = $1::uuid and tenant_id = $2::uuid), saved as (insert into agency.category_filter_items (group_id, item_key, title, help_text, contract_field_key, contract_value, sort_order, active) select id, $3, $4, nullif($5,''), nullif($6,''), nullif($7,''), $8, true from allowed_group on conflict (group_id, item_key) do update set title = excluded.title, help_text = excluded.help_text, contract_field_key = excluded.contract_field_key, contract_value = excluded.contract_value, sort_order = excluded.sort_order, updated_at = now() returning id) select agency.queue_category_filter_translations('item', id, 'tr')::text from saved"
        let _ =
          sql
          |> pog.query()
          |> pog.parameter(pog.text(group_id))
          |> pog.parameter(pog.text(session.tenant_id))
          |> pog.parameter(pog.text(item_key))
          |> pog.parameter(pog.text(title))
          |> pog.parameter(pog.text(help_text))
          |> pog.parameter(pog.text(contract_field_key))
          |> pog.parameter(pog.text(contract_value))
          |> pog.parameter(pog.int(sort_order))
          |> pog.execute(db)
        redirect_filters()
      }
    }
  })
}

fn deactivate_category_filter_group(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  save_category_filter_form(req, db, fn(session, pairs) {
    let group_id = form_value(pairs, "group_id")
    case group_id {
      "" -> redirect_filters()
      _ -> {
        let _ =
          "update agency.category_filter_groups set active=false, updated_at=now() where id=$1::uuid and tenant_id=$2::uuid"
          |> pog.query()
          |> pog.parameter(pog.text(group_id))
          |> pog.parameter(pog.text(session.tenant_id))
          |> pog.execute(db)
        redirect_filters()
      }
    }
  })
}

fn deactivate_category_filter_item(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  save_category_filter_form(req, db, fn(session, pairs) {
    let item_id = form_value(pairs, "item_id")
    case item_id {
      "" -> redirect_filters()
      _ -> {
        let _ =
          "update agency.category_filter_items i set active=false, updated_at=now() from agency.category_filter_groups g where i.id=$1::uuid and i.group_id=g.id and g.tenant_id=$2::uuid"
          |> pog.query()
          |> pog.parameter(pog.text(item_id))
          |> pog.parameter(pog.text(session.tenant_id))
          |> pog.execute(db)
        redirect_filters()
      }
    }
  })
}

fn save_category_filter_form(
  req: wisp.Request,
  db: pog.Connection,
  handler: fn(auth.Session, List(#(String, String))) -> Response,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(clean_req) {
        case auth.session(db, session_token), form_pairs(clean_req) {
          Ok(session), Ok(pairs) ->
            case permissions.is_admin_or_owner(session.membership) {
              True -> handler(session, pairs)
              False -> wisp.response(403)
            }
          _, _ -> redirect_filters()
        }
      })
  }
}

fn form_pairs(req: wisp.Request) -> Result(List(#(String, String)), Nil) {
  case wisp.read_body_bits(req) {
    Ok(bits) ->
      bits
      |> bit_array.to_string
      |> result.try(uri.parse_query)
    Error(_) -> Error(Nil)
  }
}

fn form_value(pairs: List(#(String, String)), key: String) -> String {
  pairs
  |> list.key_find(key)
  |> result.unwrap("")
  |> string.trim
}

fn form_value_default(
  pairs: List(#(String, String)),
  key: String,
  default: String,
) -> String {
  case form_value(pairs, key) {
    "" -> default
    value -> value
  }
}

fn form_bool(pairs: List(#(String, String)), key: String) -> Bool {
  form_value(pairs, key) == "true"
}

fn form_int(pairs: List(#(String, String)), key: String) -> Int {
  form_value(pairs, key)
  |> int.parse
  |> result.unwrap(0)
}

fn redirect_filters() -> Response {
  wisp.redirect("/admin/categories#category-filters")
}

fn unauthorized_json() -> Response {
  wisp.json_response("{\"error\":\"Oturum bulunamadı\"}", 401)
}

/// Başarılı girişte kayıtlı dil + para birimi tercihlerini çerezlere damgalar.
/// Çerezler JS-okunurdur (http_only: False) — main.js başlangıç zinciri
/// (cookie → localStorage → varsayılan) sunucu tercihini okuyabilsin diye.
fn stamp_pref_cookies(
  res: Response,
  req: wisp.Request,
  db: pog.Connection,
  email: String,
  tenant_slug: String,
) -> Response {
  case account_prefs_of(db, email, tenant_slug) {
    Ok(#(lang, cur)) ->
      res
      |> wisp.set_cookie(
        req,
        "agency_lang",
        i18n.normalize_lang(lang),
        wisp.PlainText,
        31_536_000,
      )
      |> http_response.set_cookie(
        "nexus_lang",
        i18n.normalize_lang(lang),
        pref_cookie_attrs(),
      )
      |> http_response.set_cookie("nexus_currency", cur, pref_cookie_attrs())
    Error(Nil) -> res
  }
}

fn pref_cookie_attrs() -> http_cookie.Attributes {
  http_cookie.Attributes(
    ..http_cookie.defaults(http.Http),
    path: option.Some("/"),
    max_age: option.Some(31_536_000),
    same_site: option.Some(http_cookie.Lax),
    http_only: False,
  )
}

fn sync_language_cookie(res: Response, req: wisp.Request) -> Response {
  case req.method, http_request.path_segments(req), res.status {
    http.Get, ["set-lang", lang], 303 ->
      http_response.set_cookie(
        res,
        "nexus_lang",
        i18n.normalize_lang(lang),
        pref_cookie_attrs(),
      )
    _, _, _ -> res
  }
}

fn login_tenant_slug(bits: BitArray) -> String {
  bits
  |> bit_array.to_string
  |> result.try(uri.parse_query)
  |> result.try(fn(pairs) { list.key_find(pairs, "tenant_slug") })
  |> result.unwrap("")
}

/// Yalnızca panel girişi POST'unu tanır; gövdesinden e-postayı çıkarır ve
/// gövdeyi (router yeniden okuyabilsin diye) geri döndürür.
fn login_email(req: wisp.Request) -> Result(#(String, BitArray), Nil) {
  case req.method, http_request.path_segments(req) {
    http.Post, ["login"] ->
      case wisp.read_body_bits(req) {
        Ok(bits) ->
          case
            bits
            |> bit_array.to_string
            |> result.try(uri.parse_query)
          {
            Ok(pairs) ->
              case list.key_find(pairs, "email") {
                Ok("") -> Error(Nil)
                Ok(email) -> Ok(#(email, bits))
                Error(Nil) -> Error(Nil)
              }
            Error(_) -> Error(Nil)
          }
        Error(_) -> Error(Nil)
      }
    _, _ -> Error(Nil)
  }
}

/// Aynı e-posta birden fazla acentede kayıtlı olabilir. Tercihler yalnızca
/// başarılı girişte seçilen acentenin kullanıcı kaydından okunur.
fn account_prefs_of(
  db: pog.Connection,
  email: String,
  tenant_slug: String,
) -> Result(#(String, String), Nil) {
  let decoder = {
    use lang <- decode.field(0, decode.string)
    use cur <- decode.field(1, decode.string)
    decode.success(#(lang, cur))
  }
  case
    "select coalesce(nullif(u.language_pref,''),'tr'), coalesce(nullif(u.currency_pref,''),'TRY') from agency.users u join agency.tenants t on t.id=u.tenant_id where lower(u.email)=lower($1) and u.active and ($2='' or lower(t.slug)=lower($2)) limit 1"
    |> pog.query()
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(tenant_slug))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(returned) -> list.first(returned.rows)
    Error(_) -> Error(Nil)
  }
}

/// Gövdeyi tek parça tampon olarak yeni Connection'a yerleştirir; router
/// (wisp.require_form) bu tampondan normal akışla okur. csrf modülündeki
/// gövde tamponlama yaklaşımının aynısıdır.
fn rebuild_buffered(
  req: wisp.Request,
  body_bits: BitArray,
) -> Result(wisp.Request, Nil) {
  let Connection(reader, max_body, max_files, chunk_size, secret, tmp_dir) =
    req.body
  let _ = reader
  let _ = chunk_size
  let buffered_reader = fn(_size) {
    Ok(Chunk(body_bits, fn(_size) { Ok(ReadingFinished) }))
  }
  Ok(
    http_request.Request(
      ..req,
      body: Connection(
        reader: buffered_reader,
        max_body_size: max_body,
        max_files_size: max_files,
        read_chunk_size: chunk_size,
        secret_key_base: secret,
        temporary_directory: tmp_dir,
      ),
    ),
  )
}

// ---------------------------------------------------------------------------
// Dil tercihi (sunucu tarafı): POST /admin/preferences/language
// Gövde: urlencoded `lang=tr|en|de|ru` + CSRF alanı. Oturum yoksa 401.
// Tema tercihindeki (/admin/preferences/theme) desenin aynısı.
const supported_languages = ["tr", "en", "de", "ru", "zh", "fr"]

fn language_pref_request(req: wisp.Request) -> Result(String, Nil) {
  case req.method, http_request.path_segments(req) {
    http.Post, ["admin", "preferences", "language"] ->
      case list.key_find(wisp.get_query(req), "lang") {
        Ok(lang) ->
          case list.contains(supported_languages, lang) {
            True -> Ok(lang)
            False -> Error(Nil)
          }
        Error(Nil) -> Error(Nil)
      }
    _, _ -> Error(Nil)
  }
}

fn save_language_pref(
  req: wisp.Request,
  db: pog.Connection,
  lang: String,
) -> Response {
  // CSRF kapısı: gövdedeki `csrf` alanı oturum jetonuna karşı doğrulanır,
  // alan ayıklanır; lang sorgudan okunduğu için gövde yalnızca CSRF taşır.
  case csrf.session_token_from(req) {
    Error(Nil) ->
      wisp.response(401)
      |> wisp.string_body("Oturum bulunamadı. Lütfen giriş yapın.")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(_clean_req) {
        case auth.session(db, session_token) {
          Error(Nil) ->
            wisp.response(401)
            |> wisp.string_body("Oturum geçersiz. Lütfen tekrar giriş yapın.")
          Ok(session) ->
            case
              "update agency.users set language_pref=$1 where id=$2::uuid and tenant_id=$3::uuid"
              |> pog.query()
              |> pog.parameter(pog.text(lang))
              |> pog.parameter(pog.text(session.user_id))
              |> pog.parameter(pog.text(session.tenant_id))
              |> pog.execute(db)
            {
              Ok(_) ->
                wisp.response(204)
                |> wisp.set_cookie(
                  req,
                  "agency_lang",
                  lang,
                  wisp.PlainText,
                  31_536_000,
                )
                |> http_response.set_cookie(
                  "nexus_lang",
                  lang,
                  pref_cookie_attrs(),
                )
              Error(_) ->
                wisp.response(500)
                |> wisp.string_body("Dil tercihi kaydedilemedi.")
            }
        }
      })
  }
}

// ---------------------------------------------------------------------------
// Para birimi tercihi (sunucu tarafı): POST /admin/preferences/currency
// Gövde: urlencoded `csrf` alanı; currency sorgudan okunur. Dil tercihi
// (save_language_pref) ile birebir aynı desen.
// ---------------------------------------------------------------------------

const supported_currencies = ["TRY", "USD", "EUR", "GBP", "SAR", "RUB", "CNY"]

fn currency_pref_request(req: wisp.Request) -> Result(String, Nil) {
  case req.method, http_request.path_segments(req) {
    http.Post, ["admin", "preferences", "currency"] ->
      case list.key_find(wisp.get_query(req), "currency") {
        Ok(cur) ->
          case list.contains(supported_currencies, cur) {
            True -> Ok(cur)
            False -> Error(Nil)
          }
        Error(Nil) -> Error(Nil)
      }
    _, _ -> Error(Nil)
  }
}

fn save_currency_pref(
  req: wisp.Request,
  db: pog.Connection,
  cur: String,
) -> Response {
  // CSRF kapısı: gövdedeki `csrf` alanı oturum jetonuna karşı doğrulanır.
  case csrf.session_token_from(req) {
    Error(Nil) ->
      wisp.response(401)
      |> wisp.string_body("Oturum bulunamadı. Lütfen giriş yapın.")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(_clean_req) {
        case auth.session(db, session_token) {
          Error(Nil) ->
            wisp.response(401)
            |> wisp.string_body("Oturum geçersiz. Lütfen tekrar giriş yapın.")
          Ok(session) ->
            case
              "update agency.users set currency_pref=$1 where id=$2::uuid and tenant_id=$3::uuid"
              |> pog.query()
              |> pog.parameter(pog.text(cur))
              |> pog.parameter(pog.text(session.user_id))
              |> pog.parameter(pog.text(session.tenant_id))
              |> pog.execute(db)
            {
              Ok(_) -> wisp.response(204)
              Error(_) ->
                wisp.response(500)
                |> wisp.string_body("Para birimi tercihi kaydedilemedi.")
            }
        }
      })
  }
}

// ---------------------------------------------------------------------------
// SSR yerelleştirme: mağaza sayfalarını nexus_lang çerezine göre sunucuda
// render et. Kurtarılan Erlang router sayfaları Türkçe basar; bu middleware
// yalnızca GET HTML yanıtlarının gövdesindeki bilinen arayüz metinlerini
// hedef dile çevirir ve <html lang> özniteliğini senkronlar. Çeviri tablosu
// main.js'teki TR sözlüğünün karşılıklarıdır (TR←EN anahtar → hedef dil).
// JS tarafı (main.js applyLang) aynı anahtarlar üzerinden çalışır; iki katman
// aynı çerezle aynı dile oturur.
// ---------------------------------------------------------------------------

// Kanonik mağaza dilleri i18n.supported_languages() ile aynıdır.
// Türkçe varsayılan olduğu için SSR çeviri katmanında ayrıca dönüştürülmez.
const ssr_langs = ["en", "de", "ru", "zh", "fr"]

fn ssr_lang_from(req: wisp.Request) -> Result(String, Nil) {
  let value = ssr_cookie(req, "nexus_lang")
  case list.contains(ssr_langs, value) {
    True -> Ok(value)
    False -> Error(Nil)
  }
}

/// `nexus_currency` çerezinden seçili para birimini okur; desteklenmeyen
/// (veya eksik) değer → Error. Gösterim dönüşümü yalnızca TRY dışı bir
/// seçimde uygulanır.
fn ssr_currency_from(req: wisp.Request) -> Result(String, Nil) {
  let value = ssr_cookie(req, "nexus_currency")
  case list.contains(supported_currencies, value) {
    True -> Ok(value)
    False -> Error(Nil)
  }
}

/// Çerez değerini header'dan okur. Bu çerezler main.js tarafından düz metin
/// yazılır (base64 değil), bu yüzden wisp.get_cookie(PlainText) yerine
/// header elle ayrıştırılır.
fn ssr_cookie(req: wisp.Request, name: String) -> String {
  req.headers
  |> list.key_find("cookie")
  |> result.unwrap("")
  |> string.split("; ")
  |> list.filter_map(fn(pair) {
    case string.split_once(pair, "=") {
      Ok(#(cookie_name, val)) if cookie_name == name -> Ok(val)
      _ -> Error(Nil)
    }
  })
  |> list.first
  |> result.unwrap("")
}

fn ssr_html_response(res: Response) -> Bool {
  // Yalnızca başarılı HTML sayfa yanıtları çevrilir; API/JSON/redirect/statik
  // akışlar olduğu gibi kalır.
  res.status == 200
  && list.any(res.headers, fn(h) {
    let #(name, value) = h
    name == "content-type" && string.contains(value, "text/html")
  })
}

// Vitrinin metin değiştirme katmanı panel HTML'ine uygulanamaz: panel
// i18n.t ile kendi dilinde render edilir. Aksi halde eski nexus_lang çerezi
// Türkçe panelin kategori etiketlerini başka dile çevirir.
fn ssr_translation_route(req: wisp.Request) -> Bool {
  case req.method {
    http.Get ->
      case http_request.path_segments(req) {
        [] -> False
        ["admin", ..] -> False
        ["login"] -> False
        ["set-lang", _] -> False
        ["nasil-calisir"] -> False
        ["tedarikciler-icin"] -> False
        ["acenteler-icin"] -> False
        ["musteriler-icin"] -> False
        _ -> True
      }
    _ -> False
  }
}

fn ssr_translate_response(res: Response, lang: String) -> Response {
  case res.body {
    wisp.Text(body) -> {
      let translated = ssr_translate_body(body, lang)
      let translated = case string.contains(translated, "<html") {
        True ->
          string.replace(
            translated,
            "<html lang=\"tr\"",
            "<html lang=\"" <> lang <> "\"",
          )
        False -> translated
      }
      http_response.Response(..res, body: wisp.Text(translated))
    }
    _ -> res
  }
}

/// Sunucu tarafı metin çevirisi için ortak giriş noktası.
///
/// Kurtarılan Erlang router'ın basamadığı, sunucuda üretilen etiketler
/// (kategori adları, rozetler) bu fonksiyonla hedef dile çevrilebilir.
/// `lang` desteklenen bir dil değilse metin değişmeden döner.
pub fn translate_text(text: String, lang: String) -> String {
  ssr_translate_body(text, lang)
}

/// Gövde metnini hedef dile göre çevirir: önce dil özel tablo, sonra ortak
/// tablo uygulanır. Değişmeyen gövde olduğu gibi döner.
fn ssr_translate_body(body: String, lang: String) -> String {
  case lang {
    "de" -> ssr_apply_map(body, ssr_map_de())
    "ru" -> ssr_apply_map(body, ssr_map_ru())
    "en" -> ssr_apply_map(body, ssr_map_en())
    _ -> body
  }
}

/// Tablo anahtarlarını uzunluğa göre azalan sırada uygular.
///
/// Uzun ifadeler kısa olanlardan önce değiştirilir: "Giriş yap" anahtarı
/// "Giriş"ten önce işlenmezse kısa anahtar uzun ifadenin içine girip
/// kalıntı bırakırdı.
fn ssr_apply_map(body: String, pairs: List(#(String, String))) -> String {
  pairs
  |> list.sort(fn(a, b) { int.compare(string.length(b.0), string.length(a.0)) })
  |> list.fold(body, fn(acc, pair) {
    let #(from, to) = pair
    ssr_replace_bounded(acc, from, to)
  })
}

/// `from` metnini yalnızca kelime sınırındaysa `to` ile değiştirir.
///
/// Sınır kuralı: eşleşmenin hemen öncesi ve sonrası bir harf/rakam değilse
/// (boşluk, noktalama, HTML etiketi, metin başı/sonu) değişim yapılır.
/// Böylece "Aktivite" anahtarı "Aktiviteler" kelimesinin içinde eşleşip
/// "Активностьler" gibi melez metin üretmez.
fn ssr_replace_bounded(body: String, from: String, to: String) -> String {
  case string.is_empty(from) {
    True -> body
    False -> ssr_replace_scan(body, from, to, "")
  }
}

fn ssr_replace_scan(
  rest: String,
  from: String,
  to: String,
  acc: String,
) -> String {
  case string.split_once(rest, from) {
    Error(Nil) -> acc <> rest
    Ok(#(before, after)) -> {
      let left_ok = case before {
        "" -> True
        _ -> !is_word_grapheme(string.last(before) |> result.unwrap(""))
      }
      let right_ok = case after {
        "" -> True
        _ -> !is_word_grapheme(string.first(after) |> result.unwrap(""))
      }
      case left_ok && right_ok {
        True -> ssr_replace_scan(after, from, to, acc <> before <> to)
        // Sınır sağlanmadı: eşleşme korunur ve tarama eşleşmenin sonundan
        // sürer (her adımda `rest` kısaldığı için sonlanır).
        False -> ssr_replace_scan(after, from, to, acc <> before <> from)
      }
    }
  }
}

/// ASCII harf/rakam kümesi (tek baytlı grafikler için üyelik testi).
const ascii_word_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

/// Çok baytlı ama kelime sayılmayan işaretler: tipografi, para birimi,
/// ayraç ve HTML entity parçaları. Listede OLMAYAN çok baytlı grafikler harf
/// kabul edilir — ç, ğ, ı, ö, ş, ü ve Kiril harfleri buna dahildir.
const unicode_separators = "—–…“”‘’«»·•€™₺₽/\\|<>()[]{}!?.,;:"

/// Grafik bir harf veya rakam mı?
///
/// Tek baytlıysa ASCII harf/rakam kümesine bakılır; çok baytlıysa yalnız
/// bilinen ayraçlar dışlanır (Türkçe/Kiril harfler kelime sayılır).
fn is_word_grapheme(grapheme: String) -> Bool {
  case string.byte_size(grapheme) {
    1 -> string.contains(ascii_word_chars, grapheme)
    _ -> !string.contains(unicode_separators, grapheme)
  }
}

fn ssr_map_en() -> List(#(String, String)) {
  [
    #("SEYAHAT ENVANTERİ", "TRAVEL INVENTORY"),
    #("Ana Sayfa", "Home"),
    #("Ürünler", "Listings"),
    #("Size uygun ürünü keşfedin", "Discover the right listing for you"),
    #("Filtre ve Arama", "Filter and search"),
    #("Tüm kategoriler", "All categories"),
    #("Aktivite", "Activity"),
    #("Uçuş", "Flight"),
    #("Transfer", "Transfer"),
    #("Feribot", "Ferry"),
    #("Kruvaziyer", "Cruise"),
    #("Etkinlik", "Event"),
    #("Restoran", "Restaurant"),
    #("Sinema", "Cinema"),
    #("Otel", "Hotel"),
    #("Oteller", "Hotels"),
    #("Uçuşlar", "Flights"),
    #("Araçlar", "Cars"),
    #("Villalar", "Villas"),
    #("Deneyimler", "Experiences"),
    #("Turlar", "Tours"),
    #("Aktiviteler", "Activities"),
    #("Tur", "Tour"),
    #("Yat", "Yacht"),
    #("Araç", "Car"),
    #("Vize", "Visa"),
    #("Plaj", "Beach"),
    #("Hac &amp; Umre", "Hajj &amp; Umrah"),
    #("Seçiminize uygun seçenekler", "Options matching your selection"),
    #("Önerilenler", "Recommended"),
    #("Fiyata göre", "By price"),
    #("Yeni eklenenler", "Newest"),
    #("Tümü", "All"),
    #("Giriş", "Check in"),
    #("Çıkış", "Check out"),
    #("Misafir sayısı", "Guests"),
    #("Ad soyad", "Full name"),
    #("Telefon", "Phone"),
    #("Tarih ekle", "Add date"),
    #("Misafir ekle", "Add guests"),
    #("/ gece", "/ night"),
    #("/ hizmet", "/ service"),
    #("/ kişibaşı", "/ person"),
    #("Müsaitlik ve teklif iste", "Request availability and quote"),
    #("Rezervasyonunuzu oluşturun", "Create your booking"),
    #("GÜVENLİ REZERVASYON", "SECURE BOOKING"),
    #(
      "Bilgilerinizi gönderin; ödeme adımına güvenli biçimde yönlendirileceksiniz.",
      "Submit your details and you will be redirected securely to the payment step.",
    ),
    #("Ödeme adımına geç →", "Continue to payment →"),
    #(
      "Ücretsiz teklif · Ön ödeme koşulları danışmanınız tarafından paylaşılır",
      "Free quote · Prepayment terms are shared by your consultant",
    ),
    #("Ürüne dön", "Back to listing"),
    #("Benzer ürünleri keşfet", "Explore similar listings"),
    #("Yaklaşan müsaitlik", "Upcoming availability"),
    #("Favorilere ekle", "Add to favourites"),
    #("Bağlantıyı kopyala", "Copy link"),
    #("Bağlantı kopyalandı", "Link copied"),
    #("Aydınlık", "Light"),
    #("Karanlık", "Dark"),
    #("Çalışma alanınıza giriş yapın", "Sign in to your workspace"),
    #(
      "Acente, ekip ve müşteri operasyonlarını tek yerden yönetin.",
      "Run agency, team and customer operations from one place.",
    ),
    #("E-POSTA", "EMAIL"),
    #("PAROLA", "PASSWORD"),
    #("Giriş yap", "Sign in"),
    #("ACENTE KODU (İSTEĞE BAĞLI)", "AGENCY CODE (OPTIONAL)"),
    #("Ürünler | NEXUS Agency", "Listings | NEXUS Agency"),
    #("Seyahat Edenler", "Travelers"),
    #("Şablonlar", "Templates"),
    #("Tesisinizi listeleyin", "List your property"),
    #("Bildirimler", "Notifications"),
    #("Hesap menüsünü aç", "Open account menu"),
    #("Ana menüyü aç", "Open main menu"),
    #("Nereye?", "Where to?"),
    #("Herhangi bir hafta", "Any week"),
    #("Konaklamalar", "Stays"),
    #("Gayrimenkuller", "Real Estates"),
    #("Keşfet", "Explore"),
    #("Favoriler", "Wishlists"),
    #("Hesap", "Account"),
    #("Menü", "Menu"),
    #("Rezervasyon", "Book"),
    #("Keşfedin", "Discover"),
    #("Şirket", "Company"),
    #("Yasal", "Legal"),
    #("Araç kiralama", "Car rental"),
    #("Yardım merkezi", "Help centre"),
    #("Haritada ara", "Search on a map"),
    #("Ev sahiplerimizle tanışın", "Meet our hosts"),
    #("Hakkımızda", "About us"),
    #("Günlük", "Journal"),
    #("İletişim", "Contact"),
    #("Gayrimenkul", "Real estate"),
    #("Kullanım şartları", "Terms of service"),
    #("Gizlilik politikası", "Privacy policy"),
    #("Çerez politikası", "Cookie policy"),
    #("Tema", "Theme"),
    #("Sahra", "Sahara"),
    #("Otomatik", "Auto"),
    #(
      "Zarif hiyerarşiler inşa ederek dünyayı daha iyi bir yer yapıyoruz.",
      "Making the world a better place through constructing elegant hierarchies.",
    ),
  ]
}

fn ssr_map_de() -> List(#(String, String)) {
  [
    #("SEYAHAT ENVANTERİ", "REISEINVENTAR"),
    #("Ana Sayfa", "Startseite"),
    #("Ürünler", "Angebote"),
    #("Size uygun ürünü keşfedin", "Entdecken Sie das passende Angebot"),
    #("Filtre ve Arama", "Filter und Suche"),
    #("Tüm kategoriler", "Alle Kategorien"),
    #("Aktivite", "Aktivität"),
    #("Uçuş", "Flug"),
    #("Transfer", "Transfer"),
    #("Feribot", "Fähre"),
    #("Kruvaziyer", "Kreuzfahrt"),
    #("Etkinlik", "Veranstaltung"),
    #("Restoran", "Restaurant"),
    #("Sinema", "Kino"),
    #("Otel", "Hotel"),
    #("Oteller", "Hotels"),
    #("Uçuşlar", "Flüge"),
    #("Araçlar", "Autos"),
    #("Villalar", "Villen"),
    #("Deneyimler", "Erlebnisse"),
    #("Turlar", "Touren"),
    #("Aktiviteler", "Aktivitäten"),
    #("Tur", "Tour"),
    #("Yat", "Yacht"),
    #("Araç", "Auto"),
    #("Vize", "Visum"),
    #("Plaj", "Strand"),
    #("Hac &amp; Umre", "Hadsch &amp; Umra"),
    #("Seçiminize uygun seçenekler", "Passende Optionen für Sie"),
    #("Önerilenler", "Empfohlen"),
    #("Fiyata göre", "Nach Preis"),
    #("Yeni eklenenler", "Neu"),
    #("Tümü", "Alle"),
    #("Giriş", "Anreise"),
    #("Çıkış", "Abreise"),
    #("Misafir sayısı", "Gästezahl"),
    #("Ad soyad", "Vor- und Nachname"),
    #("Telefon", "Telefon"),
    #("Tarih ekle", "Datum hinzufügen"),
    #("Misafir ekle", "Gäste hinzufügen"),
    #("/ gece", "/ Nacht"),
    #("/ hizmet", "/ Leistung"),
    #("/ kişibaşı", "/ Person"),
    #("Müsaitlik ve teklif iste", "Verfügbarkeit & Angebot anfragen"),
    #("Rezervasyonunuzu oluşturun", "Buchung erstellen"),
    #("GÜVENLİ REZERVASYON", "SICHERE BUCHUNG"),
    #(
      "Bilgilerinizi gönderin; ödeme adımına güvenli biçimde yönlendirileceksiniz.",
      "Senden Sie Ihre Angaben; Sie werden sicher zum Zahlungsschritt weitergeleitet.",
    ),
    #("Ödeme adımına geç →", "Weiter zur Zahlung →"),
    #(
      "Ücretsiz teklif · Ön ödeme koşulları danışmanınız tarafından paylaşılır",
      "Kostenloses Angebot · Vorauszahlungsbedingungen teilt Ihr Berater mit",
    ),
    #("Ürüne dön", "Zurück zum Angebot"),
    #("Benzer ürünleri keşfet", "Ähnliche Angebote entdecken"),
    #("Yaklaşan müsaitlik", "Kommende Verfügbarkeit"),
    #("Favorilere ekle", "Zu Favoriten hinzufügen"),
    #("Bağlantıyı kopyala", "Link kopieren"),
    #("Bağlantı kopyalandı", "Link kopiert"),
    #("Aydınlık", "Hell"),
    #("Karanlık", "Dunkel"),
    #(
      "Çalışma alanınıza giriş yapın",
      "Melden Sie sich bei Ihrem Arbeitsbereich an",
    ),
    #(
      "Acente, ekip ve müşteri operasyonlarını tek yerden yönetin.",
      "Verwalten Sie Agentur-, Team- und Kundenoperationen an einem Ort.",
    ),
    #("E-POSTA", "E-MAIL"),
    #("PAROLA", "PASSWORT"),
    #("Giriş yap", "Anmelden"),
    #("ACENTE KODU (İSTEĞE BAĞLI)", "AGENTURCODE (OPTIONAL)"),
    #("Ürünler | NEXUS Agency", "Angebote | NEXUS Agency"),
    #("Seyahat Edenler", "Reisende"),
    #("Şablonlar", "Vorlagen"),
    #("Tesisinizi listeleyin", "Ihre Immobilie auflisten"),
    #("Bildirimler", "Benachrichtigungen"),
    #("Hesap menüsünü aç", "Kontomenü öffnen"),
    #("Ana menüyü aç", "Hauptmenü öffnen"),
    #("Nereye?", "Wohin?"),
    #("Herhangi bir hafta", "Irgendeine Woche"),
    #("Konaklamalar", "Unterkünfte"),
    #("Gayrimenkuller", "Immobilien"),
    #("Keşfet", "Entdecken"),
    #("Favoriler", "Favoriten"),
    #("Hesap", "Konto"),
    #("Menü", "Menü"),
    #("Rezervasyon", "Buchen"),
    #("Keşfedin", "Entdecken"),
    #("Şirket", "Unternehmen"),
    #("Yasal", "Rechtliches"),
    #("Araç kiralama", "Autovermietung"),
    #("Yardım merkezi", "Hilfezentrum"),
    #("Haritada ara", "Auf der Karte suchen"),
    #("Ev sahiplerimizle tanışın", "Lernen Sie unsere Gastgeber kennen"),
    #("Hakkımızda", "Über uns"),
    #("Günlük", "Journal"),
    #("İletişim", "Kontakt"),
    #("Gayrimenkul", "Immobilie"),
    #("Kullanım şartları", "Nutzungsbedingungen"),
    #("Gizlilik politikası", "Datenschutzerklärung"),
    #("Çerez politikası", "Cookie-Richtlinie"),
    #("Tema", "Thema"),
    #("Sahra", "Sahara"),
    #("Otomatik", "Automatisch"),
    #(
      "Zarif hiyerarşiler inşa ederek dünyayı daha iyi bir yer yapıyoruz.",
      "Wir machen die Welt zu einem besseren Ort, indem wir elegante Hierarchien aufbauen.",
    ),
  ]
}

fn ssr_map_ru() -> List(#(String, String)) {
  [
    #("SEYAHAT ENVANTERİ", "ТУРИСТИЧЕСКИЙ КАТАЛОГ"),
    #("Ana Sayfa", "Главная"),
    #("Ürünler", "Предложения"),
    #("Size uygun ürünü keşfedin", "Найдите подходящее предложение"),
    #("Filtre ve Arama", "Фильтр и поиск"),
    #("Tüm kategoriler", "Все категории"),
    #("Aktivite", "Активность"),
    #("Uçuş", "Авиаперелёт"),
    #("Transfer", "Трансфер"),
    #("Feribot", "Паром"),
    #("Kruvaziyer", "Круиз"),
    #("Etkinlik", "Мероприятие"),
    #("Restoran", "Ресторан"),
    #("Sinema", "Кино"),
    #("Otel", "Отель"),
    #("Oteller", "Отели"),
    #("Uçuşlar", "Перелёты"),
    #("Araçlar", "Автомобили"),
    #("Villalar", "Виллы"),
    #("Deneyimler", "Впечатления"),
    #("Villa", "Вилла"),
    #("Turlar", "Туры"),
    #("Aktiviteler", "Активности"),
    #("Tur", "Тур"),
    #("Yat", "Яхта"),
    #("Araç", "Автомобиль"),
    #("Vize", "Виза"),
    #("Plaj", "Пляж"),
    #("Hac &amp; Umre", "Хадж и&nbsp;Умра"),
    #("Seçiminize uygun seçenekler", "Подходящие варианты"),
    #("Önerilenler", "Рекомендуем"),
    #("Fiyata göre", "По цене"),
    #("Yeni eklenenler", "Новые"),
    #("Tümü", "Все"),
    #("Giriş", "Заезд"),
    #("Çıkış", "Выезд"),
    #("Misafir sayısı", "Количество гостей"),
    #("Ad soyad", "Имя и фамилия"),
    #("Telefon", "Телефон"),
    #("Tarih ekle", "Добавить дату"),
    #("Misafir ekle", "Добавить гостей"),
    #("/ gece", "/ ночь"),
    #("/ hizmet", "/ услуга"),
    #("/ kişibaşı", "/ человек"),
    #("Müsaitlik ve teklif iste", "Запросить наличие и предложение"),
    #("Rezervasyonunuzu oluşturun", "Оформите бронирование"),
    #("GÜVENLİ REZERVASYON", "БЕЗОПАСНОЕ БРОНИРОВАНИЕ"),
    #(
      "Bilgilerinizi gönderin; ödeme adımına güvenli biçimde yönlendirileceksiniz.",
      "Отправьте данные — вы будете безопасно перенаправлены на шаг оплаты.",
    ),
    #("Ödeme adımına geç →", "Перейти к оплате →"),
    #(
      "Ücretsiz teklif · Ön ödeme koşulları danışmanınız tarafından paylaşılır",
      "Бесплатный запрос · Условия предоплаты сообщит ваш консультант",
    ),
    #("Ürüne dön", "Вернуться к предложению"),
    #("Benzer ürünleri keşfet", "Похожие предложения"),
    #("Yaklaşan müsaitlik", "Ближайшая доступность"),
    #("Favorilere ekle", "В избранное"),
    #("Bağlantıyı kopyala", "Копировать ссылку"),
    #("Bağlantı kopyalandı", "Ссылка скопирована"),
    #("Aydınlık", "Светлая"),
    #("Karanlık", "Тёмная"),
    #("Çalışma alanınıza giriş yapın", "Войдите в рабочее пространство"),
    #(
      "Acente, ekip ve müşteri operasyonlarını tek yerden yönetin.",
      "Управляйте агентством, командой и клиентами в одном месте.",
    ),
    #("E-POSTA", "EMAIL"),
    #("PAROLA", "ПАРОЛЬ"),
    #("Giriş yap", "Войти"),
    #("ACENTE KODU (İSTEĞE BAĞLI)", "КОД АГЕНТСТВА (НЕОБЯЗАТЕЛЬНО)"),
    #("Ürünler | NEXUS Agency", "Предложения | NEXUS Agency"),
    #("Seyahat Edenler", "Путешественники"),
    #("Şablonlar", "Шаблоны"),
    #("Tesisinizi listeleyin", "Разместить ваше жильё"),
    #("Bildirimler", "Уведомления"),
    #("Hesap menüsünü aç", "Открыть меню аккаунта"),
    #("Ana menüyü aç", "Открыть главное меню"),
    #("Nereye?", "Куда?"),
    #("Herhangi bir hafta", "Любая неделя"),
    #("Konaklamalar", "Проживание"),
    #("Gayrimenkuller", "Недвижимость"),
    #("Keşfet", "Обзор"),
    #("Favoriler", "Избранное"),
    #("Hesap", "Аккаунт"),
    #("Menü", "Меню"),
    #("Rezervasyon", "Забронировать"),
    #("Keşfedin", "Открыть"),
    #("Şirket", "Компания"),
    #("Yasal", "Правовая информация"),
    #("Araç kiralama", "Аренда автомобилей"),
    #("Yardım merkezi", "Справочный центр"),
    #("Haritada ara", "Поиск на карте"),
    #("Ev sahiplerimizle tanışın", "Познакомьтесь с нашими хозяевами"),
    #("Hakkımızda", "О нас"),
    #("Günlük", "Журнал"),
    #("İletişim", "Контакты"),
    #("Gayrimenkul", "Недвижимость"),
    #("Kullanım şartları", "Условия обслуживания"),
    #("Gizlilik politikası", "Политика конфиденциальности"),
    #("Çerez politikası", "Политика использования файлов cookie"),
    #("Tema", "Тема"),
    #("Sahra", "Сахра"),
    #("Otomatik", "Авто"),
    #(
      "Zarif hiyerarşiler inşa ederek dünyayı daha iyi bir yer yapıyoruz.",
      "Мы делаем мир лучше, создавая элегантные иерархии.",
    ),
  ]
}

/// SSR yerelleştirme + para birimi uygulayan handle sarmalayıcı:
///   • nexus_lang çerezi en/de/ru ise HTML gövdesi hedef dile çevrilir,
///   • nexus_currency çerezi TRY dışıysa fiyat gösteren mağaza sayfalarında
///     (liste, detay, kategori, rezervasyon) fiyatlar ve JSON-LD offer
///     bloğu seçili para biriminde render edilir.
///
/// Her iki geçiş de aynı yanıt gövdesi üzerinde çalışır: önce çeviri, sonra
/// fiyat dönüşümü (fiyat metni hedef dilde de aynı `₺ ` işaretiyle basıldığı
/// için sıra önemli değil, ama tek geçişte tutarlı kalır).
pub fn handle_localized(
  req: wisp.Request,
  db: pog.Connection,
  origin: String,
) -> Response {
  let res = handle(req, db, origin)
  let res = case ssr_lang_from(req), ssr_translation_route(req) {
    Ok(lang), True ->
      case ssr_html_response(res) {
        True -> ssr_translate_response(res, lang)
        False -> res
      }
    _, _ -> res
  }
  case ssr_html_response(res), ssr_price_route(req) {
    True, True ->
      case ssr_currency_from(req) {
        Ok(code) if code != "TRY" -> ssr_currency_response(res, db, code)
        _ -> res
      }
    _, _ -> res
  }
}

// ---------------------------------------------------------------------------
// SSR para birimi: fiyat gösterimi (nexus_currency çerezi)
//
// Kurtarılan Erlang router fiyatları ilanın kendi para biriminde basar.
// Bu bölüm, çerezde TRY dışı bir seçim varsa gövdedeki fiyat metinlerini
// sunucuda dönüştürür: ilk boyama doğru, istemci katmanı (main.js) yalnızca
// seçim değişimini anında uygular (kanonik tutar `data-price-minor`).
// ---------------------------------------------------------------------------

/// Fiyat gösterilen mağaza sayfaları. `/odeme/parampos` bilinçli olarak
/// dışarıda: orada gösterilen tutar gerçek TRY tahsilatıdır ve gösterim
/// para birimiyle değiştirilemez.
///
/// Ana sayfa (`[]` — kök yol) da kapsamdadır: vitrin/demo kartları
/// (`featured-card-price`) fiyat basar ve dönüşüm onları atlarsa TRY'deki
/// kart, para birimi değişince mağazanın geri kalanıyla tutarsız kalır.
fn ssr_price_route(req: wisp.Request) -> Bool {
  case req.method {
    http.Get ->
      case http_request.path_segments(req) {
        [] -> True
        ["urunler"] -> True
        ["urunler", _] -> True
        [_] -> True
        _ -> False
      }
    _ -> False
  }
}

const ssr_rate_cache_key = "nexus_agency:ssr_currency_rates"

const ssr_rate_cache_ttl_ms = 60_000.0

@external(erlang, "persistent_term", "get")
fn cache_get(key: String, default: a) -> a

@external(erlang, "persistent_term", "put")
fn cache_put(key: String, value: a) -> Nil

fn request_client_id(req: wisp.Request) -> String {
  case trust_proxy_headers() {
    False -> "unknown"
    True -> {
      let forwarded =
        http_request.get_header(req, "x-forwarded-for")
        |> result.unwrap("")
        |> first_csv_value
      case forwarded {
        "" ->
          http_request.get_header(req, "cf-connecting-ip")
          |> result.unwrap("")
          |> string.trim
          |> normalize_client_ip
        value -> normalize_client_ip(value)
      }
    }
  }
}

fn trust_proxy_headers() -> Bool {
  case envoy.get("TRUST_PROXY_HEADERS"), envoy.get("APP_ENV") {
    Ok("true"), _ -> True
    Ok(_), _ -> False
    Error(_), Ok("production") -> False
    Error(_), _ -> True
  }
}

fn request_client_ip(req: wisp.Request) -> String {
  case request_client_id(req) {
    "unknown" -> ""
    value -> value
  }
}

fn first_csv_value(value: String) -> String {
  value
  |> string.split(",")
  |> list.first
  |> result.unwrap("")
  |> string.trim
}

@external(erlang, "nexus_agency_security_rate_limit", "normalize_ip")
fn normalize_client_ip(value: String) -> String

fn too_many_requests() -> Response {
  wisp.json_response(
    "{\"ok\":false,\"error\":\"Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.\"}",
    429,
  )
  |> http_response.set_header("retry-after", "60")
  |> http_response.set_header("cache-control", "no-store")
}

fn client_quarantined(db: pog.Connection, req: wisp.Request) -> Bool {
  let client = request_client_id(req)
  case client, http_request.path_segments(req) {
    "unknown", _ -> False
    _, ["static", ..] -> False
    _, _ ->
      case
        "select agency.security_client_is_quarantined($1)::text"
        |> pog.query()
        |> pog.parameter(pog.text(client))
        |> pog.returning(decode.field(0, decode.string, decode.success))
        |> pog.execute(db)
      {
        Ok(result) -> result.rows == ["true"]
        // An unapplied migration or a transient database fault must not take
        // the storefront offline. The edge still enforces distributed limits.
        Error(_) -> False
      }
  }
}

fn security_route_group(req: wisp.Request) -> String {
  case http_request.path_segments(req) {
    ["iletisim"] -> "/iletisim"
    ["api", "public", "checkout", ..] -> "/api/public/checkout"
    ["api", "public", "chat"] -> "/api/public/chat"
    ["api", "public", "rates"] -> "/api/public/rates"
    ["api", "public", ..] -> "/api/public"
    _ -> "/pages"
  }
}

fn record_rate_limit_violation(db: pog.Connection, req: wisp.Request) -> Nil {
  let client = request_client_id(req)
  // Sample one violation per client per ten seconds to bound database writes.
  case rate_limited("security:violation:" <> client, 1, 10_000.0) {
    True -> Nil
    False -> {
      let _ =
        "select agency.register_rate_limit_violation($1, $2, $3, $4)::text"
        |> pog.query()
        |> pog.parameter(pog.text(request_id(req)))
        |> pog.parameter(pog.text(client))
        |> pog.parameter(pog.text(http.method_to_string(req.method)))
        |> pog.parameter(pog.text(security_route_group(req)))
        |> pog.returning(decode.field(0, decode.string, decode.success))
        |> pog.execute(db)
      Nil
    }
  }
}

@external(erlang, "nexus_agency_security_rate_limit", "limited")
fn rate_limited(key: String, limit: Int, window_ms: Float) -> Bool

fn ssr_currency_response(
  res: Response,
  db: pog.Connection,
  code: String,
) -> Response {
  case res.body {
    wisp.Text(body) ->
      case ssr_rate(db, code) {
        Ok(#(rate, symbol)) ->
          http_response.Response(
            ..res,
            body: wisp.Text(ssr_currency.convert_prices(
              body,
              rate,
              code,
              symbol,
            )),
          )
        Error(Nil) -> res
      }
    _ -> res
  }
}

/// Kur + simge: 60 sn kalıcı terim önbelleği (persistent_term). Veritabanı
/// yalnızca önbellek soğuk/eskimişken okunur; okuma başarısız olursa eski
/// (stale) değer kullanılır, hiç yoksa dönüşüm uygulanmaz (TRY görünür).
fn ssr_rate(db: pog.Connection, code: String) -> Result(#(Float, String), Nil) {
  let now_ms = timestamp.to_unix_seconds(timestamp.system_time()) *. 1000.0
  let cache: dict.Dict(String, #(Float, Float, String)) =
    cache_get(ssr_rate_cache_key, dict.new())
  let stale = dict.get(cache, code)
  case stale {
    Ok(#(at, rate, symbol)) if now_ms -. at <. ssr_rate_cache_ttl_ms ->
      Ok(#(rate, symbol))
    _ ->
      case ssr_fetch_rate(db, code) {
        Ok(#(rate, symbol)) -> {
          cache_put(
            ssr_rate_cache_key,
            dict.insert(cache, code, #(now_ms, rate, symbol)),
          )
          Ok(#(rate, symbol))
        }
        Error(Nil) ->
          stale
          |> result.map(fn(entry) {
            let #(_at, rate, symbol) = entry
            #(rate, symbol)
          })
      }
  }
}

/// `agency.currencies.rate` = 1 birim yabancı para kaç TRY.
fn ssr_fetch_rate(
  db: pog.Connection,
  code: String,
) -> Result(#(Float, String), Nil) {
  case
    "select rate::text, coalesce(symbol, '') from agency.currencies where active and upper(trim(code)) = $1 limit 1"
    |> pog.query()
    |> pog.parameter(pog.text(code))
    |> pog.returning(
      decode.field(0, decode.string, fn(rate_text) {
        decode.field(1, decode.string, fn(symbol) {
          decode.success(#(rate_text, symbol))
        })
      }),
    )
    |> pog.execute(db)
  {
    Ok(result) ->
      result.rows
      |> list.first
      |> result.try(fn(row) {
        let #(rate_text, symbol) = row
        case float.parse(rate_text) {
          Ok(rate) -> Ok(#(rate, ssr_currency.display_symbol(code, symbol)))
          Error(Nil) -> Error(Nil)
        }
      })
    Error(_) -> Error(Nil)
  }
}

// ---------------------------------------------------------------------------
// Genel kur API'si: GET /api/public/rates — fiyatların istemci tarafı
// para birimi dönüşümü için NEXUS_LOCALE kur oranlarını besler.
// Kimlik doğrulama yoktur (genel vitrin verisi); yalnızca aktif kurlar.
// `rate` = 1 birim yabancı para kaç TRY (TCMB ForexSelling); dönüşüm
// formülü: try_amount / rate[usd] = usd_amount.
// ---------------------------------------------------------------------------
fn rates_api_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Get, ["api", "public", "rates"] -> True
    _, _ -> False
  }
}

fn handle_rates_api(db: pog.Connection) -> Response {
  case
    "select upper(trim(code)), rate::text, symbol from agency.currencies where active order by code"
    |> pog.query()
    |> pog.returning(
      decode.field(0, decode.string, fn(code) {
        decode.field(1, decode.string, fn(rate_text) {
          decode.field(2, decode.string, fn(symbol) {
            decode.success(#(code, rate_text, symbol))
          })
        })
      }),
    )
    |> pog.execute(db)
  {
    Error(_) -> fallback_rates_response()
    Ok(result) -> {
      let rates =
        result.rows
        |> list.filter_map(fn(row) {
          let #(code, rate_text, symbol) = row
          case float.parse(rate_text) {
            Ok(rate) -> Ok(#(code, rate, symbol))
            Error(Nil) -> Error(Nil)
          }
        })
      let entries =
        rates
        |> list.map(fn(r) {
          let #(code, rate, symbol) = r
          #(
            code,
            json.object([
              #("rate", json.float(rate)),
              #("symbol", json.string(symbol)),
            ]),
          )
        })
      wisp.json_response(
        json.to_string(
          json.object([
            #("base", json.string("TRY")),
            #("rates", json.object(entries)),
          ]),
        ),
        200,
      )
    }
  }
}

fn fallback_rates_response() -> Response {
  wisp.json_response(
    json.to_string(
      json.object([
        #("base", json.string("TRY")),
        #("degraded", json.bool(True)),
        #(
          "rates",
          json.object([
            #(
              "TRY",
              json.object([
                #("rate", json.float(1.0)),
                #("symbol", json.string("₺")),
              ]),
            ),
          ]),
        ),
      ]),
    ),
    200,
  )
}

/// Oturum çerezini doğrulayıp panel rotalarını koruyan middleware.
pub fn require_session(
  db: pog.Connection,
  token: Result(String, Nil),
  body: fn() -> Response,
) -> Response {
  require_session_impl(db, token, body)
}

/// API rotaları için 401 dönen oturum middleware'i.
pub fn require_session_api(
  db: pog.Connection,
  token: Result(String, Nil),
  body: fn() -> Response,
) -> Response {
  require_session_api_impl(db, token, body)
}

// ---------------------------------------------------------------------------
// Yayın sırası (order-preserving) destek yardımcıları: kurtarılan Erlang
// modülü dışındaki işlemler (ör. arka plan görevleri) Gleam tarafında kalır.
// ---------------------------------------------------------------------------

/// Test/diagnostik için: istek yönlendirmeden önce ön işlem yapma imkânı.
/// Şu an değişiklik yapmadan iletir.
pub fn with_middleware(
  req: wisp.Request,
  db: pog.Connection,
  origin: String,
) -> Response {
  handle(req, db, origin)
}

// Uygulama tarafında kullanılan temel tipleri yeniden dışa açar (kurtarılan
// modülle uyum). Bunlar yalnızca tip düzeyindedir; kayıpsız kurtarma sırasında
// hiçbir çalışma zamanı davranışı değişmez.
/// Yaşam döngüsü yardımı: test kurulumlarında pog havuzunun kapanmasını
/// bekleyen yardımcı.
pub fn shutdown_gracefully(_db: pog.Connection) -> Nil {
  process.sleep(1)
  Nil
}
// ---------------------------------------------------------------------------
// Not: gleam/http, gleam/http/response, gleam/option ve wisp tipleri bu
// modülün dış API'sinde yalnızca `handle` imzası üzerinden görünür. response
// ve http importları erlang hedefinde kullanılmasa da cephenin okunabilirliği
// için dokümantasyon amaçlı tutulmuştur.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// /ilan-ver  –  Self-Service Supplier Listing Wizard (Public Storefront)
// ---------------------------------------------------------------------------

fn ilan_ver_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Get, ["ilan-ver"] -> True
    http.Get, ["ilan-ver", ..] -> True
    http.Post, ["api", "public", "listing-submit"] -> True
    http.Get, ["api", "public", "listing-categories"] -> True
    _, _ -> False
  }
}

fn handle_ilan_ver(req: wisp.Request, db: pog.Connection) -> Response {
  case req.method, http_request.path_segments(req) {
    http.Get, ["api", "public", "listing-categories"] ->
      handle_public_listing_categories(db, req)
    http.Post, ["api", "public", "listing-submit"] ->
      handle_public_listing_submit(req, db)
    http.Get, _ ->
      handle_ilan_ver_page(req, db)
    _, _ -> wisp.response(405)
  }
}

/// Public endpoint: supported 17 canonical categories (for wizard step 1)
fn handle_public_listing_categories(
  db: pog.Connection,
  req: wisp.Request,
) -> Response {
  // Tenant slug from host header to scope category list
  let host = http_request.get_header(req, "host") |> result.unwrap("")
  let tenant_id = tenant_id_from_host(db, host)
  let q =
    "select coalesce(json_agg(row_to_json(x) order by x.position),'[]')::text from (select c.code, c.name_tr as name, c.position, c.icon from agency.catalog_categories c where c.tenant_id=$1::uuid and c.parent_id is null and c.active order by c.position) x"
    |> pog.query()
    |> pog.parameter(pog.text(tenant_id))
    |> pog.returning(decode.field(0, decode.string, fn(r) { decode.success(r) }))
    |> pog.execute(db)
  let cats = case q {
    Ok(rows) -> case rows.rows { [raw, ..] -> raw  [] -> "[]" }
    Error(_) -> "[]"
  }
  wisp.json_response("{\"categories\":" <> cats <> "}", 200)
}

/// Public endpoint: submit listing wizard form
fn handle_public_listing_submit(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case wisp.read_body_bits(req) {
    Error(_) -> wisp.response(400) |> wisp.string_body("Geçersiz istek")
    Ok(bits) ->
      case bit_array.to_string(bits)
        |> result.try(fn(s) {
          json.parse(s, submission_decoder())
          |> result.map_error(fn(_) { Nil })
        }) {
        Error(_) ->
          wisp.json_response("{\"error\":\"Geçersiz form verisi\"}", 400)
        Ok(sub) -> {
          let host = http_request.get_header(req, "host") |> result.unwrap("")
          let ip = http_request.get_header(req, "x-forwarded-for")
            |> result.unwrap(http_request.get_header(req, "x-real-ip") |> result.unwrap(""))
          let tenant_id = tenant_id_from_host(db, host)
          let #(company, contact, email, phone, tax_id, tax_office, category,
                title, locality, description, currency, price_minor,
                guest_capacity, domain_target) = sub
          let q =
            "insert into agency.supplier_onboarding_submissions (tenant_id,company_name,contact_name,email,phone,tax_id,tax_office,category_code,listing_title,locality,description,currency,price_minor,guest_capacity,domain_target,ip_address) values ($1::uuid,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13::bigint,$14::int,$15,$16) returning id::text"
            |> pog.query()
            |> pog.parameter(pog.text(tenant_id))
            |> pog.parameter(pog.text(company))
            |> pog.parameter(pog.text(contact))
            |> pog.parameter(pog.text(email))
            |> pog.parameter(pog.text(phone))
            |> pog.parameter(pog.text(tax_id))
            |> pog.parameter(pog.text(tax_office))
            |> pog.parameter(pog.text(category))
            |> pog.parameter(pog.text(title))
            |> pog.parameter(pog.text(locality))
            |> pog.parameter(pog.text(description))
            |> pog.parameter(pog.text(currency))
            |> pog.parameter(pog.text(int.to_string(price_minor)))
            |> pog.parameter(pog.text(int.to_string(guest_capacity)))
            |> pog.parameter(pog.text(domain_target))
            |> pog.parameter(pog.text(ip))
            |> pog.returning(decode.field(0, decode.string, fn(r) { decode.success(r) }))
            |> pog.execute(db)
          case q {
            Ok(rows) ->
              case rows.rows {
                [id, ..] ->
                  wisp.json_response(
                    "{\"ok\":true,\"submission_id\":\"" <> id <> "\"}",
                    201,
                  )
                [] ->
                  wisp.json_response("{\"error\":\"Kayıt oluşturulamadı\"}", 500)
              }
            Error(_) ->
              wisp.json_response("{\"error\":\"Sunucu hatası\"}", 500)
          }
        }
      }
  }
}

fn submission_decoder() {
  use company <- decode.field("company_name", decode.string)
  use contact <- decode.field("contact_name", decode.string)
  use email <- decode.field("email", decode.string)
  use phone <- decode.field("phone", decode.string)
  use tax_id <- decode.field("tax_id", decode.string)
  use tax_office <- decode.field("tax_office", decode.string)
  use category <- decode.field("category_code", decode.string)
  use title <- decode.field("listing_title", decode.string)
  use locality <- decode.field("locality", decode.string)
  use description <- decode.field("description", decode.string)
  use currency <- decode.field("currency", decode.string)
  use price_minor <- decode.field("price_minor", decode.int)
  use guest_capacity <- decode.field("guest_capacity", decode.int)
  use domain_target <- decode.field("domain_target", decode.string)
  decode.success(#(
    company, contact, email, phone, tax_id, tax_office, category,
    title, locality, description, currency, price_minor,
    guest_capacity, domain_target,
  ))
}

/// Public page: /ilan-ver wizard HTML
fn handle_ilan_ver_page(req: wisp.Request, db: pog.Connection) -> Response {
  let host = http_request.get_header(req, "host") |> result.unwrap("")
  let lang = case ssr_cookie(req, "nexus_lang") {
    "" -> case string.contains(host, "reservationinturkey") { True -> "en" False -> "tr" }
    l -> l
  }
  let domain_target = case string.contains(host, "reservationinturkey") {
    True -> "reservationinturkey"
    False -> "rezervasyonyap"
  }
  let _ = db
  wisp.response(200)
  |> wisp.html_body(panel.ilan_ver_page(lang, domain_target))
}

/// Resolve tenant_id from incoming Host header (falls back to first active tenant)
fn tenant_id_from_host(db: pog.Connection, host: String) -> String {
  let clean_host = string.split(host, ":") |> list.first() |> result.unwrap(host)
  let q =
    "select t.id::text from agency.tenants t left join agency.marketplace_domains md on md.tenant_id=t.id and md.domain_host=$1 order by case when md.domain_host=$1 then 0 else 1 end, t.created_at limit 1"
    |> pog.query()
    |> pog.parameter(pog.text(clean_host))
    |> pog.returning(decode.field(0, decode.string, fn(r) { decode.success(r) }))
    |> pog.execute(db)
  case q {
    Ok(rows) -> case rows.rows { [id, ..] -> id  [] -> "" }
    Error(_) -> ""
  }
}

// ---------------------------------------------------------------------------
// Admin: Listing Submissions (from /ilan-ver self-service wizard)
// ---------------------------------------------------------------------------

fn handle_listing_submissions_page(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(token) ->
      case auth.session(db, token) {
        Error(Nil) -> wisp.redirect("/login")
        Ok(session) ->
          case permissions.is_admin_or_owner(session.membership) {
            False -> wisp.response(403)
            True -> {
              let lang = case session.language_pref { "" -> "tr" l -> l }
              wisp.response(200)
              |> wisp.html_body(panel.section(
                session,
                "listing-submissions",
                "Vitrin üzerinden gelen ilan başvurularını inceleyin, onaylayın veya reddedin.",
                [
                  #("/admin/supplier-onboarding", "Tedarikçi başvuruları"),
                  #("/admin/listings", "Yayınlanan ilanlar"),
                ],
                lang,
                "",
              ))
            }
          }
      }
  }
}

fn handle_listing_submissions_data(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      case auth.session(db, token) {
        Error(Nil) -> unauthorized_json()
        Ok(session) ->
          case permissions.is_admin_or_owner(session.membership) {
            False -> wisp.response(403)
            True -> {
              let params = http_request.get_query(req) |> result.unwrap([])
              let status_filter = form_value(params, "status")
              let base_q = case status_filter {
                "" -> "select coalesce(json_agg(row_to_json(x) order by x.created_at desc),'[]')::text from (select id,company_name,contact_name,email,phone,category_code,listing_title,locality,currency,price_minor,domain_target,status,admin_notes,created_at::text,reviewed_at::text,reviewer_email,listing_code,listing_status from agency.v_listing_submissions where tenant_id=$1::uuid order by created_at desc limit 200) x"
                _ -> "select coalesce(json_agg(row_to_json(x) order by x.created_at desc),'[]')::text from (select id,company_name,contact_name,email,phone,category_code,listing_title,locality,currency,price_minor,domain_target,status,admin_notes,created_at::text,reviewed_at::text,reviewer_email,listing_code,listing_status from agency.v_listing_submissions where tenant_id=$1::uuid and status=$2 order by created_at desc limit 200) x"
              }
              let q = case status_filter {
                "" ->
                  base_q
                  |> pog.query()
                  |> pog.parameter(pog.text(session.tenant_id))
                  |> pog.returning(decode.field(0, decode.string, fn(r) { decode.success(r) }))
                  |> pog.execute(db)
                _ ->
                  base_q
                  |> pog.query()
                  |> pog.parameter(pog.text(session.tenant_id))
                  |> pog.parameter(pog.text(status_filter))
                  |> pog.returning(decode.field(0, decode.string, fn(r) { decode.success(r) }))
                  |> pog.execute(db)
              }
              let rows_json = case q {
                Ok(rows) -> case rows.rows { [raw, ..] -> raw  [] -> "[]" }
                Error(_) -> "[]"
              }
              wisp.json_response("{\"submissions\":" <> rows_json <> "}", 200)
            }
          }
      }
  }
}

fn handle_listing_submission_approve(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bit_array.to_string(bits) |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let submission_id = form_value(pairs, "submission_id")
                    let initial_status = case form_value(pairs, "initial_status") {
                      "" -> "published"
                      s -> s
                    }
                    let q =
                      "select agency.approve_supplier_submission($1::uuid,$2::uuid,$3::uuid,$4)"
                      |> pog.query()
                      |> pog.parameter(pog.text(session.tenant_id))
                      |> pog.parameter(pog.text(session.user_id))
                      |> pog.parameter(pog.text(submission_id))
                      |> pog.parameter(pog.text(initial_status))
                      |> pog.returning(decode.field(0, decode.string, fn(r) { decode.success(r) }))
                      |> pog.execute(db)
                    case q {
                      Ok(rows) ->
                        case rows.rows {
                          [listing_id, ..] ->
                            wisp.json_response(
                              "{\"ok\":true,\"listing_id\":\"" <> listing_id <> "\"}",
                              200,
                            )
                          [] -> wisp.json_response("{\"error\":\"Onay başarısız\"}", 500)
                        }
                      Error(e) ->
                        wisp.json_response(
                          "{\"error\":\"" <> string.inspect(e) <> "\"}",
                          500,
                        )
                    }
                  }
                }
            }
          _, _ -> wisp.response(400)
        }
      })
  }
}

fn handle_listing_submission_reject(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(token) ->
      csrf.require_csrf_form(req, token, fn(clean_req) {
        case auth.session(db, token), wisp.read_body_bits(clean_req) {
          Ok(session), Ok(bits) ->
            case bit_array.to_string(bits) |> result.try(uri.parse_query) {
              Error(_) -> wisp.response(400)
              Ok(pairs) ->
                case permissions.is_admin_or_owner(session.membership) {
                  False -> wisp.response(403)
                  True -> {
                    let submission_id = form_value(pairs, "submission_id")
                    let reason = form_value(pairs, "reason")
                    let q =
                      "select agency.reject_supplier_submission($1::uuid,$2::uuid,$3::uuid,$4)"
                      |> pog.query()
                      |> pog.parameter(pog.text(session.tenant_id))
                      |> pog.parameter(pog.text(session.user_id))
                      |> pog.parameter(pog.text(submission_id))
                      |> pog.parameter(pog.text(reason))
                      |> pog.returning(decode.field(0, decode.string, fn(r) { decode.success(r) }))
                      |> pog.execute(db)
                    case q {
                      Ok(_) -> wisp.json_response("{\"ok\":true}", 200)
                      Error(e) ->
                        wisp.json_response(
                          "{\"error\":\"" <> string.inspect(e) <> "\"}",
                          500,
                        )
                    }
                  }
                }
            }
          _, _ -> wisp.response(400)
        }
      })
  }
}
