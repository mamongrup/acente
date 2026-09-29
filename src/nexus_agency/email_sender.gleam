//// E-posta gönderici: agency.notifications kuyruğundaki 'queued' kayıtları
//// çeker, SMTP ayarlarını bulur ve gönderir. Başarısız gönderimler 'failed'
//// olarak işaretlenir; 3 denemeden sonra vazgeçilir.

import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/string
import nexus_agency/secrets
import nexus_agency/smtp_client
import pog

/// Kuyruktan çekilecek maksimum satır sayısı (her döngüde)
const batch_size = 5

/// Maksimum deneme sayısı
const max_attempts = 3

/// Kuyruktaki queued e-postaları çek ve gönder.
pub fn process_queue(db: pog.Connection) {
  // SMTP ayarlarını her tenant için ayrı ayrı çek
  let queued_sql =
    "select n.id::text, n.tenant_id::text, n.template, n.payload::text, n.attempts "
    <> "from agency.notifications n "
    <> "where n.status = 'queued' and n.channel = 'email' "
    <> "and (n.next_attempt_at is null or n.next_attempt_at <= now()) "
    <> "order by n.created_at asc limit "
    <> int.to_string(batch_size)

  let row_decoder = {
    use id <- decode.field(0, decode.string)
    use tenant_id <- decode.field(1, decode.string)
    use template <- decode.field(2, decode.string)
    use payload <- decode.field(3, decode.string)
    use attempts <- decode.field(4, decode.int)
    decode.success(#(id, tenant_id, template, payload, attempts))
  }

  case
    queued_sql
    |> pog.query()
    |> pog.returning(row_decoder)
    |> pog.execute(db)
  {
    Ok(result) -> {
      list.each(result.rows, fn(row) {
        process_one(db, row.0, row.1, row.2, row.3, row.4)
      })
      case list.length(result.rows) {
        0 -> Nil
        n ->
          io.println("Email sender: " <> int.to_string(n) <> " mesaj işlendi")
      }
    }
    Error(pog.ConnectionUnavailable) -> Nil
    Error(e) -> {
      io.println("Email sender: Kuyruk okunamadı: " <> string.inspect(e))
    }
  }
}

/// Tek bir bildirimi işle: SMTP ayarlarını çek, gönder, durumu güncelle.
fn process_one(
  db: pog.Connection,
  id: String,
  tenant_id: String,
  template: String,
  payload_json: String,
  attempts: Int,
) {
  // SMTP ayarlarını çek
  case fetch_smtp_settings(db, tenant_id) {
    Error(e) -> {
      io.println(
        "Email sender: SMTP ayarları okunamadı (" <> tenant_id <> "): " <> e,
      )
      mark_failed(db, id, attempts, "SMTP ayarları eksik: " <> e)
    }
    Ok(smtp) -> {
      // Payload'dan email bilgilerini çıkar
      case parse_payload(template, payload_json) {
        Error(e) -> {
          io.println("Email sender: Payload ayrıştırılamadı: " <> e)
          mark_failed(db, id, attempts, e)
        }
        Ok(email) -> {
          // Gönder
          mark_sending(db, id)
          case
            smtp_client.send(
              smtp.host,
              smtp.port,
              smtp.username,
              smtp.password,
              smtp.from,
              email.to,
              email.subject,
              email.html_body,
            )
          {
            Ok(_) -> {
              mark_sent(db, id)
              io.println(
                "Email sender: Gönderildi → "
                <> email.to
                <> " ("
                <> template
                <> ")",
              )
            }
            Error(e) -> {
              io.println(
                "Email sender: Gönderilemedi → " <> email.to <> ": " <> e,
              )
              mark_failed(db, id, attempts, e)
            }
          }
        }
      }
    }
  }
}

type SmtpSettings {
  SmtpSettings(
    host: String,
    port: Int,
    username: String,
    password: String,
    legacy_password: String,
    password_sealed: String,
    from: String,
  )
}

type EmailData {
  EmailData(to: String, subject: String, html_body: String)
}

/// Tenant'ın SMTP ayarlarını çek.
fn fetch_smtp_settings(
  db: pog.Connection,
  tenant_id: String,
) -> Result(SmtpSettings, String) {
  let sql =
    "select coalesce((select trim(both '\"' from value::text) from agency.settings where tenant_id=$1::uuid and key='smtp_host'),''),"
    <> "coalesce((select trim(both '\"' from value::text) from agency.settings where tenant_id=$1::uuid and key='smtp_username'),''),"
    <> "coalesce((select trim(both '\"' from value::text) from agency.settings where tenant_id=$1::uuid and key='smtp_password'),''),"
    <> "coalesce((select trim(both '\"' from value::text) from agency.settings where tenant_id=$1::uuid and key='smtp_password_sealed'),''),"
    <> "coalesce((select value from agency.settings where tenant_id=$1::uuid and key='smtp_port')::text,'587'),"
    <> "coalesce((select trim(both '\"' from value::text) from agency.settings where tenant_id=$1::uuid and key='smtp_from'),'')"

  let decoder = {
    use host <- decode.field(0, decode.string)
    use username <- decode.field(1, decode.string)
    use password_plain <- decode.field(2, decode.string)
    use password_sealed <- decode.field(3, decode.string)
    use port_str <- decode.field(4, decode.string)
    use from <- decode.field(5, decode.string)
    let port = case int.parse(port_str) {
      Ok(p) -> p
      Error(_) -> 587
    }
    let password =
      open_setting_secret(
        tenant_id,
        "smtp_password",
        password_plain,
        password_sealed,
      )
    decode.success(SmtpSettings(
      host: host,
      port: port,
      username: username,
      password: password,
      legacy_password: password_plain,
      password_sealed: password_sealed,
      from: from,
    ))
  }

  case
    sql
    |> pog.query()
    |> pog.parameter(pog.text(tenant_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(result) -> {
      case result.rows {
        [settings, ..] -> {
          case string.trim(settings.password_sealed) {
            "" ->
              migrate_plain_setting_secret(
                db,
                tenant_id,
                "smtp_password",
                settings.legacy_password,
              )
            _ -> Nil
          }
          case settings.host {
            "" -> Error("SMTP sunucusu tanımlı değil")
            _ -> Ok(settings)
          }
        }
        [] -> Error("SMTP ayarları bulunamadı")
      }
    }
    Error(e) -> Error("SQL hatası: " <> string.inspect(e))
  }
}

fn open_setting_secret(
  tenant_id: String,
  key: String,
  plain: String,
  sealed: String,
) -> String {
  case string.trim(sealed) {
    "" -> plain
    value ->
      case secrets.open_for_tenant(tenant_id, "settings." <> key, value) {
        Ok(opened) -> opened
        Error(_) -> ""
      }
  }
}

fn migrate_plain_setting_secret(
  db: pog.Connection,
  tenant_id: String,
  key: String,
  value: String,
) -> Nil {
  case string.trim(value) {
    "" -> Nil
    trimmed -> {
      let sealed_key = key <> "_sealed"
      case secrets.seal_for_tenant(tenant_id, "settings." <> key, trimmed) {
        Ok(sealed) -> {
          let sql =
            "with saved as ("
            <> "insert into agency.settings(tenant_id,key,value,updated_at) "
            <> "values($1::uuid,$2,to_jsonb($3::text),now()) "
            <> "on conflict(tenant_id,key) do update set value=excluded.value,updated_at=now() "
            <> "returning 1) "
            <> "delete from agency.settings where tenant_id=$1::uuid and key=$4"

          let _ =
            sql
            |> pog.query()
            |> pog.parameter(pog.text(tenant_id))
            |> pog.parameter(pog.text(sealed_key))
            |> pog.parameter(pog.text(sealed))
            |> pog.parameter(pog.text(key))
            |> pog.execute(db)
          Nil
        }
        Error(_) -> Nil
      }
    }
  }
}

/// Template'e göre payload'dan email bilgilerini çıkar.
fn parse_payload(
  template: String,
  payload_json: String,
) -> Result(EmailData, String) {
  case json.parse(from: payload_json, using: payload_decoder()) {
    Ok(data) -> {
      case template {
        "weekly_digest" -> {
          let subject = case data.subject {
            "" -> "Haftalık Özet"
            s -> s
          }
          Ok(EmailData(to: data.to, subject: subject, html_body: data.html_body))
        }
        "abandoned_cart" -> {
          Ok(EmailData(
            to: data.to,
            subject: "Sepetinizi bekliyoruz",
            html_body: "<p>Sayın "
              <> data.name
              <> ", bıraktığınız sepetteki ürünler hâlâ sizleri bekliyor.</p>",
          ))
        }
        "new_public_inquiry" -> {
          Ok(EmailData(
            to: data.to,
            subject: "Yeni Müşteri Talebi",
            html_body: "<p>"
              <> data.name
              <> " adlı müşteriden yeni bir talep geldi.</p>",
          ))
        }
        _ -> {
          // Genel: payload'taki to/html alanlarını kullan
          case data.to {
            "" -> Error("Alıcı e-posta adresi eksik")
            _ ->
              Ok(EmailData(
                to: data.to,
                subject: data.subject,
                html_body: data.html_body,
              ))
          }
        }
      }
    }
    Error(_) -> Error("JSON ayrıştırma hatası")
  }
}

fn payload_decoder() {
  use to <- decode.field("to", decode.string)
  use subject <- decode.optional_field("subject", "", decode.string)
  use html <- decode.optional_field("html", "", decode.string)
  use name <- decode.optional_field("name", "", decode.string)
  decode.success(PayloadData(
    to: to,
    subject: subject,
    html_body: html,
    name: name,
  ))
}

type PayloadData {
  PayloadData(to: String, subject: String, html_body: String, name: String)
}

/// Bildirimi 'sending' olarak işaretle.
fn mark_sending(db: pog.Connection, id: String) {
  "update agency.notifications set status='sending', last_error='' where id=$1::uuid"
  |> pog.query()
  |> pog.parameter(pog.text(id))
  |> pog.execute(db)
  |> fn(_) { Nil }
}

/// Bildirimi 'sent' olarak işaretle.
fn mark_sent(db: pog.Connection, id: String) {
  "update agency.notifications set status='sent', sent_at=now(), attempts=attempts+1 where id=$1::uuid"
  |> pog.query()
  |> pog.parameter(pog.text(id))
  |> pog.execute(db)
  |> fn(_) { Nil }
}

/// Bildirimi 'failed' olarak işaretle; max attempts aşıldıysa vazgeç.
fn mark_failed(db: pog.Connection, id: String, attempts: Int, error: String) {
  case attempts + 1 >= max_attempts {
    True ->
      "update agency.notifications set status='failed', last_error=$2, attempts=attempts+1 where id=$1::uuid"
      |> pog.query()
      |> pog.parameter(pog.text(id))
      |> pog.parameter(pog.text(error))
      |> pog.execute(db)
      |> fn(_) { Nil }
    False ->
      "update agency.notifications set status='queued', next_attempt_at=now() + interval '5 minutes', last_error=$2, attempts=attempts+1 where id=$1::uuid"
      |> pog.query()
      |> pog.parameter(pog.text(id))
      |> pog.parameter(pog.text(error))
      |> pog.execute(db)
      |> fn(_) { Nil }
  }
}
