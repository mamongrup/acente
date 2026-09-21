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
    Ok(_) -> Nil
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
    Ok(_) -> Nil
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
    Ok(_) -> Nil
  }
}

pub fn fetch_inventory_failure_resilience_test() {
  let inv_res =
    nexus_api_client.fetch_inventory(
      "http://invalid.local",
      "test-key",
      "prop-123",
    )
  case inv_res {
    Error(err) -> {
      string.contains(err, "NEXUS envanter çağrısı başarısız")
      |> should.be_true
    }
    Ok(_) -> Nil
  }
}

pub fn fetch_contract_filters_failure_resilience_test() {
  let filter_res =
    nexus_api_client.fetch_contract_filters(
      "http://invalid.local",
      "test-key",
    )
  case filter_res {
    Error(err) -> {
      string.contains(err, "NEXUS sözleşme filtreleri çağrısı başarısız")
      |> should.be_true
    }
    Ok(_) -> Nil
  }
}

