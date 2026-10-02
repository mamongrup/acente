//// E-posta gönderici arka plan görevi: her 30 saniyede bir
//// agency.notifications kuyruğunu işler, queued e-postaları SMTP ile gönderir.
//// nexus_listing_sync ve weekly_digest_scheduler ile aynı deseni izler.

import gleam/erlang/process
import gleam/io
import nexus_agency/email_sender
import pog

@external(erlang, "customer_phone_worker", "run")
fn process_phone_queue(db: pog.Connection) -> Nil

const poll_interval_ms = 30_000

pub fn start(db: pog.Connection) {
  process.spawn(fn() { loop(db) })
  io.println("Email worker: başlatıldı (30sn aralıkla)")
  Nil
}

fn loop(db: pog.Connection) {
  // Hata durumunda bile döngü devam et
  case safe_process_queue(db) {
    Ok(_) -> Nil
    Error(e) -> io.println("Email worker: döngü hatası: " <> e)
  }
  process.sleep(poll_interval_ms)
  loop(db)
}

fn safe_process_queue(db: pog.Connection) -> Result(Nil, String) {
  // email_sender.process_queue kendi hata yönetimini yapıyor,
  // ama yine de dış sarmalayıcı bir güvenlik katmanı ekler
  process_phone_queue(db)
  email_sender.process_queue(db)
  Ok(Nil)
}
