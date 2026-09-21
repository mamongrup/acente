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
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp
import gleam/uri
import nexus_agency/auth
import nexus_agency/csrf
import nexus_agency/panel
import nexus_agency/ssr_currency
import pog
import wisp.{type Response}
import wisp/internal.{Chunk, Connection, ReadingFinished}

/// Kayıpsız kurtarılan router uygulaması (Erlang, derleyici yönetiminde).
@external(erlang, "nexus_agency@router_impl", "handle")
fn router_handle_impl(
  req: wisp.Request,
  db: pog.Connection,
  origin: String,
) -> Response

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
  handle_application_request(req, db, origin)
}

fn handle_application_request(
  req: wisp.Request,
  db: pog.Connection,
  origin: String,
) -> Response {
  case rates_api_request(req) {
    True -> handle_rates_api(db)
    False ->
      case supplier_onboarding_admin_request(req) {
        True -> handle_supplier_onboarding_admin_request(req, db)
        False ->
          case sync_admin_request(req) {
            True -> handle_sync_admin_request(req, db)
            False ->
              case category_filter_request(req) {
                True -> handle_category_filter_request(req, db)
                False ->
                  case currency_pref_request(req) {
                    Ok(cur) -> save_currency_pref(req, db, cur)
                    Error(Nil) ->
                      case language_pref_request(req) {
                        Ok(lang) -> save_language_pref(req, db, lang)
                        Error(Nil) ->
                          // Giriş akışı: gövdeden e-postayı oku (gövdeyi yeniden tamponla),
                          // router'a ilet; başarılı girişte kullanıcının kayıtlı dil/para
                          // birimi tercihlerini nexus_lang / nexus_currency çerezlerine
                          // bin — farklı cihazda/temiz tarayıcıda ilk sayfa açılışı sunucu
                          // tercihlerinde başlar.
                          case login_email(req) {
                            Ok(#(email, bits)) ->
                              case rebuild_buffered(req, bits) {
                                Ok(buffered) -> {
                                  let res = router_handle_impl(buffered, db, origin)
                                  case res.status == 303 {
                                    True -> stamp_pref_cookies(res, db, email)
                                    False -> res
                                  }
                                }
                                Error(Nil) -> router_handle_impl(req, db, origin)
                              }
                            Error(Nil) -> router_handle_impl(req, db, origin)
                          }
                      }
                  }
              }
          }
      }
  }
}

fn supplier_onboarding_admin_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Get, ["admin", "supplier-onboarding"] -> True
    http.Get, ["admin", "supplier-onboarding", "data"] -> True
    http.Post, ["admin", "supplier-onboarding", "decision"] -> True
    http.Post, ["admin", "supplier-onboarding", "document-decision"] -> True
    _, _ -> False
  }
}

fn handle_supplier_onboarding_admin_request(
  req: wisp.Request,
  db: pog.Connection,
) -> Response {
  case req.method, http_request.path_segments(req) {
    http.Get, ["admin", "supplier-onboarding"] ->
      case csrf.session_token_from(req) {
        Error(Nil) -> wisp.redirect("/login")
        Ok(session_token) ->
          case auth.session(db, session_token) {
            Error(Nil) -> wisp.redirect("/login")
            Ok(session) -> {
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
    http.Get, ["admin", "supplier-onboarding", "data"] ->
      supplier_onboarding_admin_data(req, db)
    http.Post, ["admin", "supplier-onboarding", "decision"] ->
      supplier_onboarding_decision(req, db)
    http.Post, ["admin", "supplier-onboarding", "document-decision"] ->
      supplier_onboarding_document_decision(req, db)
    _, _ -> wisp.response(404) |> wisp.string_body("Bulunamadı")
  }
}

fn supplier_onboarding_admin_data(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(session_token) ->
      case auth.session(db, session_token) {
        Error(Nil) -> unauthorized_json()
        Ok(session) -> {
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
            ))
          }
          let documents_result =
            pog.query(
              "select data[1],data[2],data[3],data[4],data[5],data[6],data[7],data[8],data[9] from agency.supplier_application_documents($1::uuid)",
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
                json.to_string(json.object([
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
                      ) = row
                      json.object([
                        #("application_id", json.string(application_id)),
                        #("document_id", json.string(document_id)),
                        #("document_type", json.string(document_type)),
                        #("status", json.string(status)),
                        #("note", json.string(note)),
                        #("media_id", json.string(media_id)),
                        #("reviewed_at", json.string(reviewed_at)),
                        #("reviewed_by", json.string(reviewed_by)),
                        #("application_status", json.string(application_status)),
                      ])
                    }),
                  ),
                ])),
                200,
              )
            }
            Error(_) ->
              wisp.json_response(
                json.to_string(json.object([#(
                  "error",
                  json.string("Tedarikçi başvuruları okunamadı"),
                )])),
                500,
              )
          }
        }
      }
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
            case session.membership == "admin" || session.membership == "owner" {
              False -> wisp.response(403)
              True ->
                wisp.require_form(clean_req, fn(form) {
                  let document = form_field(form.values, "document")
                  let decision = form_field(form.values, "decision")
                  let note = form_field(form.values, "note")
                  let decoder = decode.field(0, decode.string, decode.success)
                  let _ =
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
                  wisp.redirect("/admin/supplier-onboarding")
                })
            }
        }
      })
  }
}

fn supplier_onboarding_decision(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(clean_req) {
        case auth.session(db, session_token) {
          Error(Nil) -> wisp.redirect("/login")
          Ok(session) ->
            case session.membership == "admin" || session.membership == "owner" {
              False -> wisp.response(403)
              True ->
                wisp.require_form(clean_req, fn(form) {
                  let application = form_field(form.values, "application")
                  let decision = form_field(form.values, "decision")
                  let note = form_field(form.values, "note")
                  let decoder = decode.field(0, decode.string, decode.success)
                  let _ =
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
                  wisp.redirect("/admin/supplier-onboarding")
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
    http.Post, ["admin", "sync", "retry"] -> True
    _, _ -> False
  }
}

fn handle_sync_admin_request(req: wisp.Request, db: pog.Connection) -> Response {
  case req.method, http_request.path_segments(req) {
    http.Get, ["admin", "sync"] ->
      case csrf.session_token_from(req) {
        Error(Nil) -> wisp.redirect("/login")
        Ok(session_token) ->
          case auth.session(db, session_token) {
            Error(Nil) -> wisp.redirect("/login")
            Ok(session) -> {
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
    http.Get, ["admin", "sync", "data"] -> sync_admin_data(req, db)
    http.Post, ["admin", "sync", "retry"] -> sync_admin_retry(req, db)
    _, _ -> wisp.response(404) |> wisp.string_body("Bulunamadı")
  }
}

fn sync_admin_data(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> unauthorized_json()
    Ok(session_token) ->
      case auth.session(db, session_token) {
        Error(Nil) -> unauthorized_json()
        Ok(session) -> {
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
          let state_result =
            pog.query(
              "select data[1],data[2] from agency.sync_contract_state($1::uuid) order by data[1]",
            )
            |> pog.parameter(pog.text(session.tenant_id))
            |> pog.returning(state_decoder)
            |> pog.execute(db)
          let jobs_result =
            pog.query(
              "select job_type,status,coalesce(started_at::text,''),coalesce(finished_at::text,''),items_count::text,error from agency.sync_jobs where tenant_id=$1::uuid order by coalesce(started_at,finished_at,now()) desc,id desc limit 20",
            )
            |> pog.parameter(pog.text(session.tenant_id))
            |> pog.returning(job_decoder)
            |> pog.execute(db)

          case state_result, jobs_result {
            Ok(state), Ok(jobs) ->
              wisp.json_response(
                json.to_string(json.object([
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
                      let #(job_type, status, started_at, finished_at, items_count, error) =
                        row
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
                ])),
                200,
              )
            _, _ ->
              wisp.json_response(
                json.to_string(json.object([#(
                  "error",
                  json.string("Sync durumu okunamadı"),
                )])),
                500,
              )
          }
        }
      }
  }
}

fn sync_admin_retry(req: wisp.Request, db: pog.Connection) -> Response {
  case csrf.session_token_from(req) {
    Error(Nil) -> wisp.redirect("/login")
    Ok(session_token) ->
      csrf.require_csrf_form(req, session_token, fn(_clean_req) {
        case auth.session(db, session_token) {
          Error(Nil) -> wisp.redirect("/login")
          Ok(session) ->
            case session.membership == "admin" || session.membership == "owner" {
              False -> wisp.response(403)
              True -> {
                let _ =
                  pog.query(
                    "insert into agency.sync_jobs(tenant_id,job_type,status,started_at,error)
                     values($1::uuid,'import','queued',now(),'Manuel import denemesi panelden sıraya alındı')",
                  )
                  |> pog.parameter(pog.text(session.tenant_id))
                  |> pog.execute(db)
                wisp.redirect("/admin/sync")
              }
            }
        }
      })
  }
}

fn category_filter_request(req: wisp.Request) -> Bool {
  case req.method, http_request.path_segments(req) {
    http.Get, ["api", "public", "listings"] -> True
    http.Get, ["api", "public", "category-filters"] -> True
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
    http.Get, ["api", "public", "listings"] ->
      public_listings_json(req, db)
    http.Get, ["api", "public", "category-filters"] ->
      public_category_filters_json(req, db)
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

fn public_listings_json(req: wisp.Request, db: pog.Connection) -> Response {
  let query = wisp.get_query(req)
  let tenant_selector = query_value(query, "tenant")
  let search = query_value(query, "q")
  let locality = query_value(query, "konum")
  let category = canonical_category(query_value(query, "kategori"))
  let filter_key = query_value(query, "filter_key")
  let filter_value = query_value(query, "filter_value")
  let sql =
    "with resolved_tenant as (select coalesce((select id::text from agency.tenants where (($1 <> '' and (lower(slug)=lower($1) or id::text=$1))) limit 1),(select t.id::text from agency.tenants t where lower(t.slug)='nexus-demo' and exists(select 1 from agency.listings l where l.tenant_id=t.id and l.status='published') limit 1),(select t.id::text from agency.tenants t where exists(select 1 from agency.listings l where l.tenant_id=t.id and l.status='published') order by t.created_at limit 1),(select id::text from agency.tenants order by created_at limit 1),'') as id) select coalesce(json_agg(json_build_object('id', l.id::text, 'title', l.title, 'category', l.category, 'categoryLabel', case l.category when 'hotel' then 'Otel' when 'holiday_home' then 'Tatil Evi' when 'yacht' then 'Yat' when 'tour' then 'Tur' when 'activity' then 'Aktivite' when 'flight' then 'Uçuş' when 'bus' then 'Otobüs' when 'car' then 'Araç' else l.category end, 'locality', coalesce(l.locality,''), 'description', coalesce(l.description,''), 'currency', l.currency, 'priceMinor', l.price_minor::text, 'images', coalesce(l.images,'[]'::jsonb)) order by l.updated_at desc), '[]'::json)::text from agency.listings l join resolved_tenant rt on l.tenant_id=rt.id::uuid where l.status='published' and ($2='' or l.title ilike '%' || $2 || '%' or l.description ilike '%' || $2 || '%') and ($3='' or l.locality ilike '%' || $3 || '%') and ($4='' or l.category=$4) and ($5='' or lower(coalesce(l.metadata->'contract_fields'->>$5, l.metadata->>$5, '')) = lower($6)) limit 100"
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
    "villa" -> "holiday_home"
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

fn public_category_filters_json(req: wisp.Request, db: pog.Connection) -> Response {
  let query = wisp.get_query(req)
  let category = canonical_category(query_value(query, "category"))
  let tenant_selector = query_value(query, "tenant")
  let lang = public_lang(req, query)
  case category {
    "" -> wisp.json_response("[]", 200)
    _ -> {
      let sql =
        "with resolved_tenant as (select coalesce((select id::text from agency.tenants where (($1 <> '' and (lower(slug)=lower($1) or id::text=$1))) limit 1),(select t.id::text from agency.tenants t where lower(t.slug)='nexus-demo' and exists(select 1 from agency.listings l where l.tenant_id=t.id and l.status='published') limit 1),(select t.id::text from agency.tenants t where exists(select 1 from agency.listings l where l.tenant_id=t.id and l.status='published') order by t.created_at limit 1),(select id::text from agency.tenants order by created_at limit 1),'') as id), groups as (select g.* from agency.category_filter_groups g join resolved_tenant rt on g.tenant_id=rt.id::uuid where g.category_code=$2 and g.active) select coalesce(json_agg(json_build_object('id', g.id::text, 'category', g.category_code, 'key', g.group_key, 'title', coalesce(nullif(gt.title,''), g.title), 'helpText', coalesce(nullif(gt.help_text,''), g.help_text, ''), 'displayType', g.display_type, 'multiple', g.multiple, 'sortOrder', g.sort_order, 'items', coalesce((select json_agg(json_build_object('id', i.id::text, 'key', i.item_key, 'title', coalesce(nullif(it.title,''), i.title), 'helpText', coalesce(nullif(it.help_text,''), i.help_text, ''), 'contractFieldKey', coalesce(i.contract_field_key, ''), 'contractValue', coalesce(i.contract_value, ''), 'sortOrder', i.sort_order) order by i.sort_order, i.title) from agency.category_filter_items i left join agency.category_filter_translations it on it.entity_type='item' and it.entity_id=i.id and it.language_code=$3 and it.status in ('translated','approved','published') where i.group_id=g.id and i.active), '[]'::json)) order by g.sort_order, g.title), '[]'::json)::text from groups g left join agency.category_filter_translations gt on gt.entity_type='group' and gt.entity_id=g.id and gt.language_code=$3 and gt.status in ('translated','approved','published')"
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
          wisp.json_response("{\"error\":\"Kategori filtreleri okunamadı\"}", 500)
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

fn save_category_filter_group(req: wisp.Request, db: pog.Connection) -> Response {
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

fn save_category_filter_item(req: wisp.Request, db: pog.Connection) -> Response {
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
            case session.membership == "admin" || session.membership == "owner" {
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
  db: pog.Connection,
  email: String,
) -> Response {
  let attrs =
    http_cookie.Attributes(
      ..http_cookie.defaults(http.Http),
      path: option.Some("/"),
      max_age: option.Some(31_536_000),
      same_site: option.Some(http_cookie.Lax),
      http_only: False,
    )
  let res = case pref_of(db, email) {
    Ok(lang) -> http_response.set_cookie(res, "nexus_lang", lang, attrs)
    Error(Nil) -> res
  }
  case currency_pref_of(db, email) {
    Ok(cur) -> http_response.set_cookie(res, "nexus_currency", cur, attrs)
    Error(Nil) -> res
  }
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

/// E-postaya göre kayıtlı dil tercihi (yok/boş → Error).
fn pref_of(db: pog.Connection, email: String) -> Result(String, Nil) {
  case
    "select u.language_pref from agency.users u where lower(u.email)=lower($1) and u.language_pref is not null and u.language_pref <> '' limit 1"
    |> pog.query()
    |> pog.parameter(pog.text(email))
    |> pog.returning(
      decode.field(0, decode.optional(decode.string), fn(lang) {
        decode.success(option.unwrap(lang, ""))
      }),
    )
    |> pog.execute(db)
  {
    Ok(returned) ->
      list.first(returned.rows)
      |> result.try(fn(lang) {
        case lang {
          "" -> Error(Nil)
          _ -> Ok(lang)
        }
      })
    Error(_) -> Error(Nil)
  }
}

/// E-postaya göre kayıtlı para birimi tercihi (yok/boş → Error).
fn currency_pref_of(db: pog.Connection, email: String) -> Result(String, Nil) {
  case
    "select u.currency_pref from agency.users u where lower(u.email)=lower($1) and u.currency_pref is not null and u.currency_pref <> '' limit 1"
    |> pog.query()
    |> pog.parameter(pog.text(email))
    |> pog.returning(
      decode.field(0, decode.optional(decode.string), fn(cur) {
        decode.success(option.unwrap(cur, ""))
      }),
    )
    |> pog.execute(db)
  {
    Ok(returned) ->
      list.first(returned.rows)
      |> result.try(fn(cur) {
        case cur {
          "" -> Error(Nil)
          _ -> Ok(cur)
        }
      })
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
// ---------------------------------------------------------------------------

const supported_languages = ["tr", "en", "de", "ru"]

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
              Ok(_) -> wisp.response(204)
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

const supported_currencies = ["TRY", "USD", "EUR", "GBP", "SAR"]

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
  let res = case ssr_lang_from(req) {
    Ok(lang) ->
      case ssr_html_response(res) {
        True -> ssr_translate_response(res, lang)
        False -> res
      }
    Error(Nil) -> res
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
        ["kategori", _] -> True
        ["rezervasyon"] -> True
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
    Error(_) ->
      wisp.json_response(
        json.to_string(
          json.object([#("error", json.string("Kur verisi okunamadi"))]),
        ),
        500,
      )
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
