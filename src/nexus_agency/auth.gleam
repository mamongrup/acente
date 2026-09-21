import gleam/dynamic/decode
import gleam/list
import gleam/option
import pog

pub type Session {
  Session(
    tenant_id: String,
    user_id: String,
    name: String,
    membership: String,
    theme_pref: String,
    wizard_prefs_json: String,
    language_pref: String,
    currency_pref: String,
  )
}

fn decoder() {
  use tenant <- decode.field(0, decode.string)
  use user <- decode.field(1, decode.string)
  use name <- decode.field(2, decode.string)
  use membership <- decode.field(3, decode.string)
  // NULL → boş string; uygulama "dark" varsayılanına düşer.
  use theme <- decode.field(4, decode.optional(decode.string))
  use wiz <- decode.field(5, decode.optional(decode.string))
  // NULL → boş string; uygulama varsayılan dile (en) düşer.
  use lang <- decode.field(6, decode.optional(decode.string))
  // NULL → boş string; uygulama varsayılan para birimine (TRY) düşer.
  use cur <- decode.field(7, decode.optional(decode.string))
  decode.success(Session(
    tenant_id: tenant,
    user_id: user,
    name: name,
    membership: membership,
    theme_pref: option.unwrap(theme, ""),
    wizard_prefs_json: option.unwrap(wiz, ""),
    language_pref: option.unwrap(lang, ""),
    currency_pref: option.unwrap(cur, ""),
  ))
}

pub type LoginError {
  InvalidCredentials
  AccountLocked
  AmbiguousAccount
  DatabaseError
}

pub fn login(
  db: pog.Connection,
  email: String,
  password: String,
  token: String,
) -> Result(Session, LoginError) {
  login_with_tenant(db, email, password, token, "")
}

pub fn login_with_tenant(
  db: pog.Connection,
  email: String,
  password: String,
  token: String,
  tenant_slug: String,
) -> Result(Session, LoginError) {
  let decoder = {
    // Invalid and locked credentials deliberately return a row whose session
    // fields are NULL. Decode those fields as optional so the database can
    // communicate the specific error code instead of becoming a DatabaseError.
    use tenant <- decode.field(0, decode.optional(decode.string))
    use user <- decode.field(1, decode.optional(decode.string))
    use name <- decode.field(2, decode.optional(decode.string))
    use membership <- decode.field(3, decode.optional(decode.string))
    use error_code <- decode.field(4, decode.optional(decode.string))
    decode.success(#(tenant, user, name, membership, error_code))
  }
  let query = case tenant_slug == "" {
    True -> "select * from auth.login($1,$2,$3)"
    False -> "select * from auth.login($1,$2,$3,$4)"
  }
  let execution =
    query
    |> pog.query()
    |> pog.parameter(pog.text(email))
    |> pog.parameter(pog.text(password))
    |> pog.parameter(pog.text(token))
    |> pog.returning(decoder)
  let execution = case tenant_slug == "" {
    True -> execution
    False -> execution |> pog.parameter(pog.text(tenant_slug))
  }
  case execution |> pog.execute(db) {
    Ok(result) -> {
      case list.first(result.rows) {
        Ok(#(tenant, user, name, membership, error_code)) -> {
          case error_code {
            option.Some("account_locked") -> Error(AccountLocked)
            option.Some("ambiguous_account") -> Error(AmbiguousAccount)
            option.Some(_) -> Error(InvalidCredentials)
            option.None ->
              case tenant, user, name, membership {
                option.Some(tenant),
                  option.Some(user),
                  option.Some(name),
                  option.Some(membership)
                ->
                  Ok(Session(
                    tenant_id: tenant,
                    user_id: user,
                    name: name,
                    membership: membership,
                    theme_pref: "",
                    wizard_prefs_json: "",
                    language_pref: "",
                    currency_pref: "",
                  ))
                _, _, _, _ -> Error(InvalidCredentials)
              }
          }
        }
        Error(_) -> Error(InvalidCredentials)
      }
    }
    Error(_) -> Error(DatabaseError)
  }
}

pub fn session(db: pog.Connection, token: String) -> Result(Session, Nil) {
  case
    pog.query("select * from auth.session($1)")
    |> pog.parameter(pog.text(token))
    |> pog.returning(decoder())
    |> pog.execute(db)
  {
    Ok(result) -> list.first(result.rows)
    Error(_) -> Error(Nil)
  }
}

pub fn logout(db: pog.Connection, token: String) {
  pog.query("select auth.logout($1)")
  |> pog.parameter(pog.text(token))
  |> pog.execute(db)
  |> fn(_) { Nil }
}
