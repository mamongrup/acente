import gleam/erlang/process
import pog

/// Döviz kuru güncellemeleri asıl olarak scripts/currency-worker.ps1
/// (Windows zamanlanmış görevi) tarafından yürütülür: TCMB kurlarını çeker,
/// agency.currencies tablosunu günceller ve kuyruktaki
/// agency.task_runs 'currency.refresh' işlerini işler.
///
/// Bu modül bir zamanlar her 60 saniyede bir schedule tablosunu sayan ama
/// hiçbir iş yapmayan bir yoklama döngüsü çalıştırıyordu; bu döngü hem
/// yanıltıcı log üretiyor hem de gereksiz veritabanı sorgusu yapıyordu.
/// Artık yalnızca uyumluluk için korunuyor ve sonsuza dek uyuyor.
pub fn start(_db: pog.Connection) {
  process.spawn(fn() { sleep_forever() })
  Nil
}

fn sleep_forever() {
  process.sleep_forever()
}
