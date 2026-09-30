import envoy
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleeunit/should
import nexus_agency/nexus_listing_sync
import pog

pub fn canonical_feed_categories_test() {
  nexus_listing_sync.canonical_feed_category("OTEL")
  |> should.equal(Ok("hotel"))
  nexus_listing_sync.canonical_feed_category("VILLA")
  |> should.equal(Ok("holiday_home"))
  nexus_listing_sync.canonical_feed_category("HAC_UMRE")
  |> should.equal(Ok("pilgrimage"))
  nexus_listing_sync.canonical_feed_category("yacht")
  |> should.equal(Ok("yacht"))
  nexus_listing_sync.canonical_feed_category("gulet")
  |> should.be_error
  nexus_listing_sync.canonical_feed_category("spa")
  |> should.be_error
}

fn sql(db: pog.Connection, statement: String) -> String {
  let assert Ok(rows) = pog.query(statement)
    |> pog.returning(decode.field(0, decode.string, decode.success))
    |> pog.execute(db)
  let assert Ok(value) = list.first(rows.rows)
  value
}

pub fn remote_failure_closes_only_nexus_stock_test() {
  let name = process.new_name("nexus_stock_suspend_test")
  let config = pog.default_config(name)
    |> pog.host(envoy.get("PGHOST") |> result.unwrap("127.0.0.1"))
    |> pog.port(envoy.get("PGPORT") |> result.try(int.parse) |> result.unwrap(5432))
    |> pog.database(envoy.get("PGDATABASE") |> result.unwrap("nexus_agency"))
    |> pog.user(envoy.get("PGUSER") |> result.unwrap("agency_app"))
    |> pog.password(option.Some(envoy.get("PGPASSWORD") |> result.unwrap("")))
  let assert Ok(_) = pog.start(config)
  let outcome = pog.transaction(pog.named_connection(name), fn(db) {
    let tenant = sql(db,
      "insert into agency.tenants(legal_name,brand_name,slug) values('Stock Test','Stock Test','stock-'||gen_random_uuid()) returning id::text",
    )
    let base =
      "insert into agency.listings(tenant_id,code,category,title,locality,description,currency,price_minor,status,source,metadata,images,owner_info,cancellation_policy) values('"
      <> tenant
      <> "',"
    let tail =
      ",'hotel','Stock Test','Test','Test listing','TRY',10000,'published',"
    let metadata =
      ",jsonb_build_object('property_type','Otel','room_types','Standart Oda','board_type','Oda Kahvaltı','check_in_time','14:00','check_out_time','12:00'),jsonb_build_array(jsonb_build_object('url','/static/placeholder.jpg')),jsonb_build_object('provider','Test'),jsonb_build_object('policy','Test')) returning id::text"
    let remote = sql(db, base <> "'NEXUS-REMOTE'" <> tail <> "'nexus'" <> metadata)
    let local = sql(db, base <> "'LOCAL-LOCAL'" <> tail <> "'manual'" <> metadata)
    let _ = sql(db,
      "insert into agency.availability(listing_id,day,units_total,units_available,closed,price_minor) values('"
      <> remote <> "',current_date+1,1,1,false,10000) returning listing_id::text",
    )
    let _ = sql(db,
      "insert into agency.availability(listing_id,day,units_total,units_available,closed,price_minor) values('"
      <> local <> "',current_date+1,1,1,false,10000) returning listing_id::text",
    )
    nexus_listing_sync.suspend_nexus_catalog(db, tenant)
    sql(db,
      "select status||'|'||a.units_available::text||'|'||a.closed::text from agency.listings l join agency.availability a on a.listing_id=l.id where l.id='"
      <> remote <> "'",
    ) |> should.equal("paused|0|true")
    sql(db,
      "select status||'|'||a.units_available::text||'|'||a.closed::text from agency.listings l join agency.availability a on a.listing_id=l.id where l.id='"
      <> local <> "'",
    ) |> should.equal("published|1|false")
    Error("verified_rollback")
  })
  case outcome {
    Error(pog.TransactionRolledBack("verified_rollback")) -> Nil
    _ -> panic as "Stock suspension fixture did not roll back"
  }
}
