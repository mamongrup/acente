//// SMTP yanıt kodu eşleşmesi — sahte başarıyı kapatan regresyon testi.
////
//// `smtp_ffi:send/8`, çağıran tarafından `{ok, _}` durumunda
//// `agency.notifications` satırını `sent` olarak işaretlediği için
//// (bkz. `email_sender.process_one`) sunucunun döndürdüğü kod
//// karşılaştırılmazsa **teslim edilmemiş bir e-posta gönderilmiş gibi
//// raporlanır** ve bir daha denenmez.
////
//// Önceki sürüm `expect/4` içinde beklenen kodu gölgeliyor
//// (`Code=list_to_integer([A,B,C])`) ve hiçbir karşılaştırma yapmadan
//// `ok` dönüyordu. Bu test, gerçek bir loopback soketi üzerinden
//// `535` / `550` / `554` yanıtlarının **reddedildiğini** kanıtlar.
////
//// Test sunucu bağlantısı kurulduktan *sonra* yanıtı bekler; bu
//// sıralama `send/8`'in TLS öncesi aşamasını (STARTTLS yükseltmesinden
//// hemen önce `gen_tcp` üzerinde çalışması) taklit eder.

import gleam/string
import gleeunit/should

@external(erlang, "agency_test_smtp", "roundtrip")
fn smtp_reply(lines: List(BitArray), want: Int) -> Result(Nil, String)

@external(erlang, "agency_test_smtp", "roundtrip_ok")
fn smtp_final_reply(line: BitArray) -> Result(Nil, String)

// ---------------------------------------------------------------------------
// Kabul edilen yollar
// ---------------------------------------------------------------------------

pub fn greeting_220_accepted_test() {
  smtp_reply([<<"220 mx.example.com ESMTP ready\r\n">>], 220)
  |> should.be_ok()
}

pub fn auth_235_accepted_test() {
  smtp_reply([<<"235 2.7.0 Authentication successful\r\n">>], 235)
  |> should.be_ok()
}

/// EHLO çok satırlı yanıt döner (`250-` devam satırları, `250 ` son satır).
/// Yalnızca son satırın kodu beklenenle karşılaştırılmalı.
pub fn multiline_ehlo_accepted_by_last_line_test() {
  smtp_reply(
    [
      <<"250-mx.example.com\r\n">>,
      <<"250-PIPELINING\r\n">>,
      <<"250-SIZE 35882577\r\n">>,
      <<"250 AUTH LOGIN PLAIN\r\n">>,
    ],
    250,
  )
  |> should.be_ok()
}

pub fn quit_221_accepted_test() {
  smtp_final_reply(<<"221 2.0.0 Bye\r\n">>) |> should.be_ok()
}

/// RFC 5321 221 önerir ama kapı 250/3xx ile de kapanabilir. Mesaj DATA
/// sonrası zaten teslim edilmiştir; kapatma adımı teslimatı geri
/// almadığı için katı 221 beklemek mükerrer e-postaya yol açar.
pub fn quit_250_also_accepted_test() {
  smtp_final_reply(<<"250 2.0.0 Ok\r\n">>) |> should.be_ok()
}

// ---------------------------------------------------------------------------
// Reddedilen yollar — asıl sözleşme burada
// ---------------------------------------------------------------------------

/// 535: kimlik doğrulama reddi. Sahte başarının en sessiz hâli — eski
/// kodda bildirim `sent` işaretlenir, müşteriye hiçbir şey ulaşmaz.
pub fn auth_rejection_is_an_error_test() {
  smtp_reply([<<"535 5.7.8 Authentication credentials invalid\r\n">>], 235)
  |> error_should_mention("535")
}

/// 550: alıcı reddi (geçersiz/alıcı yok). Gönderi var diye gösterilir,
/// teslim yoktur.
pub fn recipient_rejection_is_an_error_test() {
  smtp_reply([<<"550 5.1.1 <yok@example.com>: Recipient address rejected\r\n">>], 250)
  |> error_should_mention("550")
}

/// 554: mesaj gövdesi reddi (spam/bağlantı kotası). DATA sonrası
/// gelen red — bildirim yine "gönderildi" işaretlenirdi.
pub fn message_rejection_after_data_is_an_error_test() {
  smtp_reply([<<"554 5.7.1 Message rejected by policy\r\n">>], 250)
  |> error_should_mention("554")
}

/// 421: sunucu kapatıyor. Beklenen kod 250 iken hata olmalı.
pub fn service_closing_421_is_an_error_test() {
  smtp_reply([<<"421 4.7.0 Too many connections\r\n">>], 250)
  |> error_should_mention("421")
}

/// Sunucu SMTP dışı bir şey dönerse protokol hatası sayılmalı —
/// sessizce `ok` sayılmamalı.
pub fn non_smtp_reply_is_a_protocol_error_test() {
  smtp_reply([<<"<html>502 Bad Gateway</html>\r\n">>], 220)
  |> error_should_mention("beklenmeyen")
}

/// QUIT için 5xx yine hatadır: sunucu bağlantıyı düşürüyor.
pub fn quit_5xx_is_an_error_test() {
  smtp_final_reply(<<"554 5.3.0 Shutting down\r\n">>)
  |> error_should_mention("beklenmeyen")
}

/// Hata metni gönderilen adımın kodunu **ve** sunucunun kendi
/// cevabını taşımalı; `mark_failed(reason)` operatörün kuyrukta
/// nedenini görebilmesi için.
pub fn error_text_keeps_the_server_reply_test() {
  let message = rejected(<<"535 5.7.8 Bad credentials\r\n">>, 235)
  string.contains(message, "535") |> should.be_true()
  string.contains(message, "credentials") |> should.be_true()
}

// ---------------------------------------------------------------------------

/// Beklenen hata yolunu sınar: `Error` mesajı `needle` dizisini içermeli.
fn error_should_mention(result: Result(Nil, String), needle: String) -> Nil {
  case result {
    Ok(_) -> panic as "SMTP yanıtı reddedilmedi; sunucu hata kodu dondurmedi"
    Error(message) -> string.contains(message, needle) |> should.be_true()
  }
}

fn rejected(line: BitArray, want: Int) -> String {
  smtp_reply([line], want) |> should.be_error()
}
