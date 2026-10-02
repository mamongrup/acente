//// Haftalık özet (weekly digest): 14 günlük seri verilerinden son 7 günün
//// derlemesi — metric kartlarında kullanılan serilerin aynısı, artık
//// contacts + conversion dahil. Üç çıktı üretir:
////   1) JSON özeti (rapor kartı + email + PDF ortak kaynak)
////   2) E-posta HTML gövdesi (inline stilli; istemci uyumluluğu için)
////   3) Yazdırılabilir PDF rapor sayfası (standalone HTML + print CSS;
////      harici PDF bağımlılığı yok — tarayıcının Yazdır → PDF'i hedefi)
////
//// Veri kaynağı: /admin/dashboard/series ile aynı SQL (router.gleam) —
//// agency.listings, agency.reservations, agency.contact_requests.

import gleam/int
import gleam/json
import gleam/list
import gleam/string

pub type Digest {
  Digest(
    period: String,
    published_total: Int,
    published_end: Int,
    pending_total: Int,
    upcoming_total: Int,
    contacts_total: Int,
    conversion_avg: Int,
    days: List(Day),
  )
}

pub type Day {
  Day(
    label: String,
    published: Int,
    pending: Int,
    upcoming: Int,
    contacts: Int,
    conversion: Int,
  )
}

fn sum_ints(values: List(Int)) -> Int {
  list.fold(values, 0, fn(acc, v) { acc + v })
}

fn avg_ints(values: List(Int)) -> Int {
  case values {
    [] -> 0
    _ -> sum_ints(values) / list.length(values)
  }
}

/// 14 günlük serilerin son 7 gününü derle.
pub fn build(
  labels l: List(String),
  published p: List(Int),
  pending pe: List(Int),
  upcoming u: List(Int),
  contacts c: List(Int),
  conversion cv: List(Int),
) -> Result(Digest, Nil) {
  case
    list.length(list.drop(l, 7)) == 7
    && list.length(list.drop(p, 7)) == 7
    && list.length(list.drop(pe, 7)) == 7
    && list.length(list.drop(u, 7)) == 7
    && list.length(list.drop(c, 7)) == 7
    && list.length(list.drop(cv, 7)) == 7
  {
    False -> Error(Nil)
    True -> {
      let ls = list.drop(l, 7)
      let ps = list.drop(p, 7)
      let pes = list.drop(pe, 7)
      let us = list.drop(u, 7)
      let cs = list.drop(c, 7)
      let cvs = list.drop(cv, 7)
      let days =
        ls
        |> list.index_map(fn(label, i) {
          Day(
            label: label,
            published: at(ps, i),
            pending: at(pes, i),
            upcoming: at(us, i),
            contacts: at(cs, i),
            conversion: at(cvs, i),
          )
        })
      let period = case days {
        [first, ..] -> first.label <> " – " <> last_label(days)
        _ -> ""
      }
      Ok(Digest(
        period: period,
        published_total: sum_ints(list.map(days, fn(d) { d.published })),
        published_end: case list.last(list.map(days, fn(d) { d.published })) {
          Ok(v) -> v
          Error(_) -> 0
        },
        pending_total: sum_ints(list.map(days, fn(d) { d.pending })),
        upcoming_total: sum_ints(list.map(days, fn(d) { d.upcoming })),
        contacts_total: sum_ints(list.map(days, fn(d) { d.contacts })),
        conversion_avg: avg_ints(list.map(days, fn(d) { d.conversion })),
        days: days,
      ))
    }
  }
}

fn at(values: List(Int), index: Int) -> Int {
  case list.drop(values, index) {
    [v, ..] -> v
    _ -> 0
  }
}

/// JSON özeti — rapor kartının dolduracağı haftalık toplamlar.
pub fn build_json(digest: Digest) -> json.Json {
  json.object([
    #("period", json.string(digest.period)),
    #("publishedTotal", json.int(digest.published_total)),
    #("publishedEnd", json.int(digest.published_end)),
    #("pendingTotal", json.int(digest.pending_total)),
    #("upcomingTotal", json.int(digest.upcoming_total)),
    #("contactsTotal", json.int(digest.contacts_total)),
    #("conversionAvg", json.int(digest.conversion_avg)),
    #(
      "days",
      json.array(digest.days, fn(day) {
        json.object([
          #("label", json.string(day.label)),
          #("published", json.int(day.published)),
          #("pending", json.int(day.pending)),
          #("upcoming", json.int(day.upcoming)),
          #("contacts", json.int(day.contacts)),
          #("conversion", json.int(day.conversion)),
        ])
      }),
    ),
  ])
}

fn last_label(days: List(Day)) -> String {
  case list.last(days) {
    Ok(day) -> day.label
    Error(_) -> ""
  }
}

/// E-posta HTML gövdesi — inline stilli, istemci uyumlu tablo düzeni.
pub fn email_html(digest: Digest, agency_name: String) -> String {
  let rows =
    digest.days
    |> list.map(fn(day) {
      "<tr>"
      <> cell(day.label)
      <> cell(int.to_string(day.published))
      <> cell(int.to_string(day.pending))
      <> cell(int.to_string(day.upcoming))
      <> cell(int.to_string(day.contacts))
      <> cell(int.to_string(day.conversion) <> "%")
      <> "</tr>"
    })
    |> string.join("")
  "<div style=\"font-family:Segoe UI,Arial,sans-serif;max-width:640px;margin:0 auto;\">"
  <> "<h2 style=\"color:#0e7490;margin:0 0 4px;\">📊 Haftalık Özet — "
  <> agency_name
  <> "</h2>"
  <> "<p style=\"color:#5f6368;margin:0 0 16px;\">Dönem: "
  <> digest.period
  <> "</p>"
  <> stat_grid(digest)
  <> "<table style=\"border-collapse:collapse;width:100%;font-size:13px;\">"
  <> "<thead><tr style=\"background:#0e7490;color:#fff;\">"
  <> th("Gün")
  <> th("Yayın")
  <> th("Bekleyen")
  <> th("Giriş")
  <> th("Talep")
  <> th("Dönüşüm")
  <> "</tr></thead><tbody>"
  <> rows
  <> "</tbody></table>"
  <> "<p style=\"color:#9aa0a6;font-size:11px;margin-top:14px;\">NEXUS Agency otomatik haftalık raporu.</p>"
  <> "</div>"
}

fn stat_grid(digest: Digest) -> String {
  [
    #("Yeni yayın", int.to_string(digest.published_total)),
    #("Bekleyen talep", int.to_string(digest.pending_total)),
    #("Yaklaşan giriş", int.to_string(digest.upcoming_total)),
    #("Yeni müşteri talebi", int.to_string(digest.contacts_total)),
    #("Ort. dönüşüm", int.to_string(digest.conversion_avg) <> "%"),
    #("Yayın (dönem sonu)", int.to_string(digest.published_end)),
  ]
  |> list.map(fn(stat) {
    let #(k, v) = stat
    "<div style=\"display:inline-block;width:180px;margin:0 12px 12px 0;padding:10px 14px;border:1px solid #e0e0e0;border-radius:10px;\">"
    <> "<div style=\"font-size:11px;color:#5f6368;text-transform:uppercase;\">"
    <> k
    <> "</div><div style=\"font-size:22px;font-weight:700;color:#1a73e8;\">"
    <> v
    <> "</div></div>"
  })
  |> string.join("")
}

fn cell(value: String) -> String {
  "<td style=\"border:1px solid #e0e0e0;padding:6px 10px;text-align:center;\">"
  <> value
  <> "</td>"
}

fn th(value: String) -> String {
  "<th style=\"padding:8px 10px;text-align:center;\">" <> value <> "</th>"
}

/// Yazdırılabilir PDF rapor sayfası — standalone HTML (Aurora paletinden
/// bağımsız; yazdırmada beyaz zemin güvenli). Tarayıcı Yazdır → PDF hedefi.
pub fn print_html(digest: Digest, agency_name: String) -> String {
  let rows =
    digest.days
    |> list.map(fn(day) {
      "<tr><td>"
      <> day.label
      <> "</td><td>"
      <> int.to_string(day.published)
      <> "</td><td>"
      <> int.to_string(day.pending)
      <> "</td><td>"
      <> int.to_string(day.upcoming)
      <> "</td><td>"
      <> int.to_string(day.contacts)
      <> "</td><td>"
      <> int.to_string(day.conversion)
      <> "%</td></tr>"
    })
    |> string.join("")
  "<!doctype html><html lang=\"tr\"><head><meta charset=\"utf-8\">"
  <> "<title>Haftalık Özet — "
  <> agency_name
  <> "</title><style>"
  <> "body{font-family:Segoe UI,Arial,sans-serif;color:#1f2937;margin:40px;}"
  <> "h1{color:#0e7490;font-size:22px;margin:0 0 2px;}"
  <> ".sub{color:#6b7280;font-size:13px;margin:0 0 24px;}"
  <> ".stats{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:0 0 28px;}"
  <> ".stat{border:1px solid #e5e7eb;border-radius:12px;padding:14px 18px;}"
  <> ".stat .k{font-size:11px;color:#6b7280;text-transform:uppercase;letter-spacing:.04em;}"
  <> ".stat .v{font-size:26px;font-weight:700;color:#0e7490;}"
  <> "table{border-collapse:collapse;width:100%;font-size:13px;}"
  <> "th{background:#0e7490;color:#fff;padding:8px 10px;}"
  <> "td{border:1px solid #e5e7eb;padding:7px 10px;text-align:center;}"
  <> "tr:nth-child(even) td{background:#f8fafc;}"
  <> ".foot{margin-top:24px;color:#9ca3af;font-size:11px;}"
  <> "@media print{button{display:none}}"
  <> "</style></head><body>"
  <> "<h1>📊 Haftalık Özet — "
  <> agency_name
  <> "</h1><p class=\"sub\">Dönem: "
  <> digest.period
  <> "</p>"
  <> "<div class=\"stats\">"
  <> print_stat("Yeni yayın", digest.published_total)
  <> print_stat("Bekleyen talep", digest.pending_total)
  <> print_stat("Yaklaşan giriş", digest.upcoming_total)
  <> print_stat("Yeni müşteri talebi", digest.contacts_total)
  <> print_stat("Ort. dönüşüm", digest.conversion_avg)
  <> print_stat("Yayın (dönem sonu)", digest.published_end)
  <> "</div>"
  <> "<table><thead><tr><th>Gün</th><th>Yayın</th><th>Bekleyen</th><th>Giriş</th><th>Talep</th><th>Dönüşüm</th></tr></thead><tbody>"
  <> rows
  <> "</tbody></table>"
  <> "<p class=\"foot\">NEXUS Agency otomatik haftalık raporu · Yazdır → PDF ile kaydedin.</p>"
  <> "<button onclick=\"window.print()\" style=\"margin-top:16px;padding:10px 18px;border-radius:8px;border:0;background:#0e7490;color:#fff;font-size:14px;cursor:pointer;\">🖨 PDF olarak kaydet / Yazdır</button>"
  <> "</body></html>"
}

fn print_stat(k: String, v: Int) -> String {
  "<div class=\"stat\"><div class=\"k\">"
  <> k
  <> "</div><div class=\"v\">"
  <> int.to_string(v)
  <> "</div></div>"
}
