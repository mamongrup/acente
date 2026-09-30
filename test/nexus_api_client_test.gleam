import gleam/string
import gleeunit/should
import nexus_agency/nexus_api_client

pub fn contract_state_json_decoding_test() {
  let state_res =
    nexus_api_client.fetch_contract_state("http://invalid.local", "")
  case state_res {
    Error(err) -> {
      string.contains(err, "NEXUS sözleşme API çağrısı başarısız")
      |> should.be_true
    }
    Ok(_) -> panic as "invalid contract origin unexpectedly succeeded"
  }
}

pub fn listings_feed_url_and_fallback_test() {
  let feed_res =
    nexus_api_client.fetch_listings_feed(
      "http://invalid.local",
      "test-key",
      "tenant-123",
    )
  case feed_res {
    Error(err) -> {
      string.contains(err, "NEXUS ilan feed API çağrısı başarısız")
      |> should.be_true
    }
    Ok(_) -> panic as "invalid listing origin unexpectedly succeeded"
  }
}

pub fn webhook_payload_dispatch_failure_resilience_test() {
  let webhook_res =
    nexus_api_client.send_reservation_webhook(
      "http://invalid.local",
      "test-key",
      "{\"idempotency_key\":\"test-1\"}",
    )
  case webhook_res {
    Error(err) -> {
      string.contains(err, "NEXUS rezervasyon webhook hatası")
      |> should.be_true
    }
    Ok(_) -> panic as "invalid webhook origin unexpectedly succeeded"
  }
}

pub fn webhook_receipt_requires_explicit_success_test() {
  let created = "{\"event_type\":\"reservation.created\"}"
  nexus_api_client.validate_reservation_webhook_reply(
    created,
    "{\"ok\": false, \"status\":\"failed\",\"booking_reference\":\"\"}",
  )
  |> should.be_error
  nexus_api_client.validate_reservation_webhook_reply(
    created,
    "{\"status\":\"processed\",\"booking_reference\":\"B-1\"}",
  )
  |> should.be_error
  nexus_api_client.validate_reservation_webhook_reply(
    created,
    "{\"ok\":true,\"status\":\"processed\",\"booking_reference\":\"\"}",
  )
  |> should.be_error
  nexus_api_client.validate_reservation_webhook_reply(
    created,
    "{\"ok\":true,\"status\":\"processed\",\"booking_reference\":\"B-1\"}",
  )
  |> should.be_error
  nexus_api_client.validate_reservation_webhook_reply(
    created,
    "{\"ok\":true,\"status\":\"processed\",\"booking_reference\":\"11111111-1111-4111-8111-111111111111\",\"total_minor\":12500,\"currency\":\"TRY\",\"expires_at\":\"2026-09-29T12:00:00+03:00\"}",
  )
  |> should.be_ok
}

pub fn status_webhook_receipt_does_not_need_new_booking_reference_test() {
  nexus_api_client.validate_reservation_webhook_reply(
    "{\"event_type\":\"reservation.status_changed\",\"reservation_status\":\"confirmed\"}",
    "{\"ok\":true,\"status\":\"processed\",\"reservation_status\":\"confirmed\"}",
  )
  |> should.be_ok
  nexus_api_client.validate_reservation_webhook_reply(
    "{\"event_type\":\"reservation.status_changed\",\"reservation_status\":\"cancelled\"}",
    "{\"ok\":true,\"status\":\"processed\",\"reservation_status\":\"confirmed\"}",
  )
  |> should.be_error
}

pub fn fetch_inventory_failure_resilience_test() {
  let inv_res =
    nexus_api_client.fetch_inventory(
      "http://invalid.local",
      "test-key",
      "tenant-123",
      "prop-123",
    )
  case inv_res {
    Error(err) -> {
      string.contains(err, "NEXUS envanter çağrısı başarısız")
      |> should.be_true
    }
    Ok(_) -> panic as "invalid inventory origin unexpectedly succeeded"
  }
}

pub fn fetch_contract_filters_failure_resilience_test() {
  let filter_res =
    nexus_api_client.fetch_contract_filters("http://invalid.local", "test-key")
  case filter_res {
    Error(err) -> {
      string.contains(err, "NEXUS sözleşme filtreleri çağrısı başarısız")
      |> should.be_true
    }
    Ok(_) -> panic as "invalid filter origin unexpectedly succeeded"
  }
}
