//// Haftalık özet zamanlayıcı: her Pazartesi 08:00'te (Türkiye saati, UTC+3)
//// tüm aktif tenant'lar için haftalık özeti hesaplayıp
//// agency.notifications kuyruğuna yazar. Dış postacı (scripts/ veya Windows
//// zamanlanmış görevi) kuyruktaki kayıtları işler.
////
//// Çalışma modeli: nexus_listing_sync ile aynı — process.spawn + döngü.
//// Her 60 saniyede bir saat kontrolü yapılır; tetikleme yalnızca
//// Pazartesi 08:00:00–08:00:59 penceresinde ve yalnızca bir kez gerçekleşir
//// (sonraki Pazartesi'ye kadar draft_flag sıfırlanmaz).

import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import nexus_agency/weekly_digest
import pog

/// 60 saniye-aralıkla kontrol
const check_interval_ms = 60_000

/// UTC+3 ofseti (Türkiye, DST kullanmaz)
const turkey_offset_minutes = 180

pub fn start(db: pog.Connection) {
  process.spawn(fn() { loop(db, "") })
  Nil
}

fn loop(db: pog.Connection, last_trigger: String) {
  let new_trigger = check_and_trigger(db, last_trigger)
  process.sleep(check_interval_ms)
  loop(db, new_trigger)
}

/// Mevcut Türkiye saati kontrolü: Pazartesi 08:00 ise tetikle.
/// Güncellenmiş last_trigger döndürür.
fn check_and_trigger(db: pog.Connection, last_trigger: String) -> String {
  let now = timestamp.system_time()
  let offset = duration.seconds(turkey_offset_seconds())
  let #(date, time) = timestamp.to_calendar(now, offset)
  let day = day_of_week(date.year, date.month |> month_to_int, date.day)
  // Pazartesi (1) && saat 08 && dakika 0-1 && aynı gün tetiklenmedi
  let date_key =
    int.to_string(date.year)
    <> "-"
    <> int_to_pad2(month_to_int(date.month))
    <> "-"
    <> int_to_pad2(date.day)
  case day == 1 && time.hours == 8 && time.minutes == 0 && last_trigger != date_key {
    True -> {
      io.println(
        "Weekly digest scheduler: Pazartesi 08:00 — tetikleniyor (" <> date_key <> ")",
      )
      enqueue_for_all_tenants(db)
      date_key
    }
    False -> last_trigger
  }
}

/// Tüm aktif tenant'lar için haftalık özeti kuyruğa yaz.
fn enqueue_for_all_tenants(db: pog.Connection) {
  case
    "select id::text from agency.tenants where active = true"
    |> pog.query()
    |> pog.returning(decode.at([0], decode.string))
    |> pog.execute(db)
  {
    Ok(result) -> {
      list.each(result.rows, fn(tenant_id) { enqueue_tenant(db, tenant_id) })
      io.println(
        "Weekly digest scheduler: "
        <> int.to_string(list.length(result.rows))
        <> " tenant için kuyruğa yazıldı",
      )
    }
    Error(e) -> {
      io.println("Weekly digest scheduler: Tenant listesi alınamadı: " <> string.inspect(e))
    }
  }
}

/// Tek bir tenant için haftalık özet hesapla ve kuyruğa yaz.
fn enqueue_tenant(db: pog.Connection, tenant_id: String) {
  // Serileri çek (aynı fetch_series SQL'i — 14 günlük pencere)
  let series_sql =
    "with days as (select generate_series(current_date - 13, current_date, interval '1 day')::date as d) "
    <> "select to_char(d,'MM-DD') as label, "
    <> "(select count(*) from agency.listings l where l.tenant_id=$1::uuid and l.status='published' and l.created_at::date <= d)::text, "
    <> "(select count(*) from agency.reservations r where r.tenant_id=$1::uuid and r.status in ('inquiry','option') and r.created_at::date = d)::text, "
    <> "(select count(*) from agency.reservations r where r.tenant_id=$1::uuid and r.check_in = d + 7)::text, "
    <> "(select count(*) from agency.contact_requests c where c.tenant_id=$1::uuid and c.created_at::date = d)::text, "
    <> "(select coalesce(round(100.0*count(*) filter (where r2.status in ('confirmed','completed'))/nullif(count(*),0)),0) from agency.reservations r2 where r2.tenant_id=$1::uuid and r2.created_at::date = d)::text "
    <> "from days order by d"
  let row_decoder = {
    use label <- decode.field(0, decode.string)
    use published <- decode.field(1, decode.string)
    use pending <- decode.field(2, decode.string)
    use upcoming <- decode.field(3, decode.string)
    use contacts <- decode.field(4, decode.string)
    use conversion <- decode.field(5, decode.string)
    decode.success(#(label, published, pending, upcoming, contacts, conversion))
  }
  case
    series_sql
    |> pog.query()
    |> pog.parameter(pog.text(tenant_id))
    |> pog.returning(row_decoder)
    |> pog.execute(db)
  {
    Ok(result) -> {
      let rows = result.rows
      case
        weekly_digest.build(
          labels: list.map(rows, fn(row) { row.0 }),
          published: int_series(rows, fn(row) { row.1 }),
          pending: int_series(rows, fn(row) { row.2 }),
          upcoming: int_series(rows, fn(row) { row.3 }),
          contacts: int_series(rows, fn(row) { row.4 }),
          conversion: int_series(rows, fn(row) { row.5 }),
        )
      {
        Ok(digest) -> {
          let payload =
            weekly_digest.build_json(digest)
            |> json.to_string
          let insert =
            "insert into agency.notifications(tenant_id,channel,template,payload,status) values ($1::uuid,'email','weekly_digest',$2::jsonb,'queued')"
            |> pog.query()
            |> pog.parameter(pog.text(tenant_id))
            |> pog.parameter(pog.text(payload))
            |> pog.returning(decode.at([0], decode.string))
          case insert |> pog.execute(db) {
            Ok(_) ->
              io.println(
                "Weekly digest: " <> tenant_id <> " kuyruğa yazıldı",
              )
            Error(e) ->
              io.println(
                "Weekly digest: " <> tenant_id <> " kuyruğa yazılamadı: " <> string.inspect(e),
              )
          }
        }
        Error(_) ->
          io.println(
            "Weekly digest: " <> tenant_id <> " veri derlenemedi",
          )
      }
    }
    Error(e) ->
      io.println(
        "Weekly digest: " <> tenant_id <> " sorgu hatası: " <> string.inspect(e),
      )
  }
}

// ---------------------------------------------------------------------------
// Yardımcı fonksiyonlar
// ---------------------------------------------------------------------------

fn int_series(
  rows: List(#(String, String, String, String, String, String)),
  pick: fn(#(String, String, String, String, String, String)) -> String,
) -> List(Int) {
  list.map(rows, fn(row) { pick(row) |> int.parse |> result.unwrap(0) })
}

fn turkey_offset_seconds() -> Int {
  turkey_offset_minutes * 60
}

/// Zeller benzeri gün hesaplama: 1=Pazartesi .. 7=Pazar
fn day_of_week(year: Int, month: Int, day: Int) -> Int {
  // Tomohiko Sakamoto algorithm
  let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
  let y = case month < 3 {
    True -> year - 1
    False -> year
  }
  let m = case month < 3 {
    True -> month + 9
    False -> month - 3
  }
  let idx = case m >= 0 && m < 12 {
    True -> m
    False -> 0
  }
  let anchor = case list.drop(t, idx) {
    [v, ..] -> v
    _ -> 0
  }
  let raw = { y + y / 4 - y / 100 + y / 400 + anchor + day } % 7
  // Sakamoto: 0=Pazar, 1=Pazartesi ... 6=Cumartesi
  // Bizim format: 1=Pazartesi ... 7=Pazar
  case raw {
    0 -> 7
    n -> n
  }
}

fn month_to_int(month: calendar.Month) -> Int {
  case month {
    calendar.January -> 1
    calendar.February -> 2
    calendar.March -> 3
    calendar.April -> 4
    calendar.May -> 5
    calendar.June -> 6
    calendar.July -> 7
    calendar.August -> 8
    calendar.September -> 9
    calendar.October -> 10
    calendar.November -> 11
    calendar.December -> 12
  }
}

fn int_to_pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}
