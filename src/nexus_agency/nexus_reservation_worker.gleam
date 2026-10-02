import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import nexus_agency/nexus_api_client
import pog

const poll_interval_ms = 30_000

type Delivery =
  #(
    String,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
    String,
  )

pub fn start(
  db: pog.Connection,
  api_origin: String,
  api_key: String,
  tenant_id: String,
  remote_tenant_id: String,
) {
  let pid =
    process.spawn_unlinked(fn() {
      loop(db, api_origin, api_key, tenant_id, remote_tenant_id)
    })
  io.println("NEXUS reservation worker: started")
  pid
}

fn loop(
  db: pog.Connection,
  api_origin: String,
  api_key: String,
  tenant_id: String,
  remote_tenant_id: String,
) {
  process_queue(db, api_origin, api_key, tenant_id, remote_tenant_id)
  process.sleep(poll_interval_ms)
  loop(db, api_origin, api_key, tenant_id, remote_tenant_id)
}

fn process_queue(
  db: pog.Connection,
  api_origin: String,
  api_key: String,
  tenant_id: String,
  remote_tenant_id: String,
) {
  let decoder = {
    use delivery_id <- decode.field(0, decode.string)
    use reservation_id <- decode.field(1, decode.string)
    use agency_id <- decode.field(2, decode.string)
    use nexus_listing_id <- decode.field(3, decode.string)
    use guest_name <- decode.field(4, decode.string)
    use guest_email <- decode.field(5, decode.string)
    use guest_phone <- decode.field(6, decode.string)
    use check_in <- decode.field(7, decode.string)
    use check_out <- decode.field(8, decode.string)
    use guests <- decode.field(9, decode.string)
    use event_type <- decode.field(10, decode.string)
    use reservation_status <- decode.field(11, decode.string)
    use amount_minor <- decode.field(12, decode.string)
    use currency <- decode.field(13, decode.string)
    decode.success(#(
      delivery_id,
      reservation_id,
      agency_id,
      nexus_listing_id,
      guest_name,
      guest_email,
      guest_phone,
      check_in,
      check_out,
      guests,
      event_type,
      reservation_status,
      amount_minor,
      currency,
    ))
  }

  case
    pog.query(
      "with stale as (
         update agency.nexus_reservation_deliveries
            set status=case when attempts >= 8 then 'failed' else 'pending' end,
                started_at=null,
                next_attempt_at=case when attempts >= 8 then next_attempt_at else now() end,
                last_error=case when attempts >= 8 then 'Maksimum deneme sayısına ulaşıldı.' else 'Rezervasyon işçisi yeniden başlatıldığı için kuyruk yeniden açıldı.' end,
                updated_at=now()
          where tenant_id=$1::uuid and status='processing'
            and (started_at is null or started_at < now() - interval '10 minutes')
         returning id
       ),
       picked as (
         select d.id
           from agency.nexus_reservation_deliveries d
           join agency.reservations r on r.id=d.reservation_id and r.tenant_id=d.tenant_id
           join agency.listings l on l.id=r.listing_id and l.tenant_id=r.tenant_id
          where d.tenant_id=$1::uuid and d.status in ('pending','failed')
            and d.next_attempt_at<=now()
            and (d.attempts<8 or (d.event_type='reservation.status_changed'
              and r.payment_status='paid' and d.attempts<100))
            and l.source='nexus'
            and (d.event_type='reservation.created'
              or agency.nexus_reservation_ready(d.tenant_id,d.reservation_id)
              or (d.event_type='reservation.status_changed'
                and r.payment_status='paid'))
          order by d.created_at
          for update of d skip locked
          limit 20
       ),
       claimed as (
         update agency.nexus_reservation_deliveries d
            set status='processing',
                started_at=now(),
                attempts=d.attempts+1,
                updated_at=now()
           from picked
          where d.id=picked.id
         returning d.id,d.reservation_id,d.tenant_id,d.event_type,d.reservation_status
       )
       select c.id::text,r.id::text,r.tenant_id::text,
         coalesce(l.metadata->>'nexus_listing_id',''),
         coalesce(cu.full_name,''),coalesce(cu.email,''),coalesce(cu.phone,''),
         coalesce(r.check_in::text,''),coalesce(r.check_out::text,''),
         r.guest_count::text,
         c.event_type,
         coalesce(nullif(c.reservation_status,''),r.status),
         coalesce(o.total_minor::text,''),coalesce(o.currency::text,'')
       from claimed c
       join agency.reservations r on r.id=c.reservation_id and r.tenant_id=c.tenant_id
       join agency.listings l on l.id=r.listing_id and l.tenant_id=r.tenant_id
       left join agency.customers cu on cu.id=r.customer_id and cu.tenant_id=r.tenant_id
       left join lateral (
         select orders.total_minor,orders.currency from agency.orders orders
         where orders.reservation_id=r.id and orders.tenant_id=r.tenant_id
         order by orders.created_at desc limit 1
       ) o on true
       order by c.id
       ",
    )
    |> pog.parameter(pog.text(tenant_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(result) ->
      result.rows
      |> list.each(fn(delivery) {
        deliver(db, api_origin, api_key, remote_tenant_id, delivery)
      })
    Error(error) ->
      io.println(
        "NEXUS reservation worker: queue unavailable: "
        <> query_error_summary(error),
      )
  }
}

fn query_error_summary(error: pog.QueryError) -> String {
  case error {
    pog.ConstraintViolated(message, constraint, detail) ->
      message <> " " <> constraint <> " " <> detail
    pog.PostgresqlError(code, name, message) ->
      code <> " " <> name <> " " <> message
    pog.UnexpectedArgumentCount(expected, got) ->
      "argument count " <> int.to_string(expected) <> "/" <> int.to_string(got)
    pog.UnexpectedArgumentType(expected, got) ->
      "argument type " <> expected <> "/" <> got
    pog.UnexpectedResultType(_) -> "unexpected result type"
    pog.QueryTimeout -> "query timeout"
    pog.ConnectionUnavailable -> "connection unavailable"
  }
}

fn deliver(
  db: pog.Connection,
  api_origin: String,
  api_key: String,
  remote_tenant_id: String,
  delivery: Delivery,
) {
  let #(
    delivery_id,
    reservation_id,
    _agency_id,
    nexus_listing_id,
    guest_name,
    guest_email,
    guest_phone,
    check_in,
    check_out,
    guests,
    event_type,
    reservation_status,
    amount_minor,
    currency,
  ) = delivery

  let idempotency_key = case event_type {
    "reservation.status_changed" ->
      "agency-reservation-status:"
      <> reservation_id
      <> ":"
      <> reservation_status
    _ -> "agency-reservation:" <> reservation_id
  }

  let payload =
    json.object([
      #("idempotency_key", json.string(idempotency_key)),
      #("event_type", json.string(event_type)),
      #("agency_id", json.string(remote_tenant_id)),
      #("listing_id", json.string(nexus_listing_id)),
      #("reservation_id", json.string(reservation_id)),
      #("reservation_status", json.string(reservation_status)),
      #("guest_name", json.string(guest_name)),
      #("guest_email", json.string(guest_email)),
      #("guest_phone", json.string(guest_phone)),
      #("check_in", json.string(check_in)),
      #("check_out", json.string(check_out)),
      #("guests", json.int(int.parse(guests) |> result.unwrap(1))),
      #("amount_minor", json.string(amount_minor)),
      #("currency", json.string(currency)),
    ])
    |> json.to_string

  case nexus_api_client.send_reservation_webhook(api_origin, api_key, payload) {
    Ok(reply) -> {
      let _ =
        pog.query(
          "update agency.nexus_reservation_deliveries
           set status='sent',started_at=null,last_response=$2,last_error='',sent_at=now(),updated_at=now()
           where id=$1::uuid and status='processing'",
        )
        |> pog.parameter(pog.text(delivery_id))
        |> pog.parameter(pog.text(reply))
        |> pog.execute(db)
      Nil
    }
    Error(error) -> {
      let terminal = string.contains(error, "booking_expired")
      let _ =
        pog.query(
          "update agency.nexus_reservation_deliveries
           set status='failed',last_error=$2,
             attempts=case when $3::boolean then 100 else attempts end,
             started_at=null,
             next_attempt_at=now() + (least(attempts,8) * interval '2 minutes'),
             updated_at=now()
           where id=$1::uuid and status='processing'",
        )
        |> pog.parameter(pog.text(delivery_id))
        |> pog.parameter(pog.text(error))
        |> pog.parameter(pog.bool(terminal))
        |> pog.execute(db)
      Nil
    }
  }
}
