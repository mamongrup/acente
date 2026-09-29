import envoy
import gleam/result
import gleam/string

@external(erlang, "nexus_agency_secrets", "seal")
pub fn seal(value: String, key: String, context: String) -> Result(String, Nil)

@external(erlang, "nexus_agency_secrets", "open")
pub fn open(value: String, key: String, context: String) -> Result(String, Nil)

@external(erlang, "nexus_agency_secrets", "valid_https")
pub fn valid_https(value: String) -> Bool

pub fn key() -> Result(String, Nil) {
  case envoy.get("NEXUS_CONFIG_KEY") {
    Ok(value) -> {
      let trimmed = string.trim(value)
      case string.length(trimmed) >= 64 {
        True -> Ok(trimmed)
        False -> secret_key_base()
      }
    }
    Error(_) -> secret_key_base()
  }
}

fn secret_key_base() -> Result(String, Nil) {
  case envoy.get("SECRET_KEY_BASE") {
    Ok(value) -> {
      let trimmed = string.trim(value)
      case string.length(trimmed) >= 64 {
        True -> Ok(trimmed)
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

pub fn seal_for_tenant(
  tenant_id: String,
  field: String,
  value: String,
) -> Result(String, Nil) {
  use k <- result.try(key())
  seal(value, k, context(tenant_id, field))
}

pub fn open_for_tenant(
  tenant_id: String,
  field: String,
  value: String,
) -> Result(String, Nil) {
  use k <- result.try(key())
  open(value, k, context(tenant_id, field))
}

fn context(tenant_id: String, field: String) -> String {
  string.trim(tenant_id) <> ":agency.integrations:" <> string.trim(field)
}
