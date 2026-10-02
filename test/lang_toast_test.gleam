//// Dil değişimi bildirimi (geri al) — statik sözleşme bekçisi.
////
//// NEDEN: dil seçimi kalıcıdır (çerez + localStorage + sunucu tercihi).
//// Yanlışlıkla seçim yapan kullanıcı tek dokunuşla eski dile dönebilmeli.
//// Dört seçim yolu vardır ve hepsi aynı davranışı vermelidir:
////   A) masaüstü globe popover'ı (header-popovers.js → `nexus:lang`)
////   B) mobil mm-pill popover'ı (main.js → `dispatchLang`)
////   C) eski `.lang-toggle` döngüsü (main.js → `dispatchLang`)
////   D) geri-alma düğmesi (`revert: true` ile `nexus:lang`)
////
//// Sabitlenen sözleşmeler:
////   1) Bildirim TEK yerden üretilir (`nexus:lang` dinleyicisi); seçim
////      yolları doğrudan applyLang çağırmaz — yoksa bazı yollar sessiz kalır.
////   2) Bildirim yalnızca dil GERÇEKTEN değişince çıkar; aynı dilin yeniden
////      seçilmesi bildirimi tetiklemez.
////   3) Geri-alma `revert: true` taşır ve yeni bir bildirim doğurmaz
////      (döngü yok).
////   4) Bildirim erişilebilir bir durum duyurusudur (aria-live + role=status)
////      ve "Geri" düğmesi hedef dilde etiketlenir.
////   5) Görsel katman (custom.css) bildirimle senkron kalır: mobilde alt
////      sekme çubuğunun (bnav, z-40) üstünde konumlanır ve hareket azaltma
////      tercihine saygı duyar.

import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const main_js = "priv/static/chisfis/js/main.js"

const header_js = "priv/static/header-popovers.js"

const store_css = "priv/static/chisfis/css/custom.css"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

fn contains_all(haystack: String, needles: List(String)) -> Bool {
  list.all(needles, fn(needle) { string.contains(haystack, needle) })
}

fn occurrences(src: String, needle: String) -> Int {
  src |> string.split(needle) |> list.length |> fn(n) { n - 1 }
}

pub fn toast_sources_readable_test() {
  read_file(main_js) |> string.is_empty |> should.be_false
  read_file(store_css) |> string.is_empty |> should.be_false
  read_file(header_js) |> string.is_empty |> should.be_false
}

// ---- 1) Bildirim üretimi ve erişilebilirlik ----

pub fn toast_is_built_as_live_status_test() {
  let src = read_file(main_js)
  contains_all(src, [
    "function showLangToast(prevLang, newLang) {",
    "function dismissLangToast() {",
    "var LANG_TOAST_MS = 7000;",
    "host.id = 'store-toast-host';",
    "host.setAttribute('aria-live', 'polite');",
    "host.setAttribute('aria-atomic', 'true');",
    "toast.setAttribute('role', 'status');",
    "msg.textContent = t('Language changed') + ': ' + name;",
    "btn.textContent = t('Back');",
  ])
  |> should.be_true
}

/// Bildirim hedef dilde basılmalı: etiket `t()` (yeni dil) üzerinden çözülür.
pub fn toast_labels_come_from_active_language_test() {
  let src = read_file(main_js)
  // İki etiket de t() ile çözülür — sabit Türkçe metin yok
  contains_all(src, [
    "msg.textContent = t('Language changed')",
    "btn.textContent = t('Back')",
  ])
  |> should.be_true
}

// ---- 2) Tek kanal: seçim yolları doğrudan applyLang çağırmaz ----

pub fn all_selection_paths_funnel_through_nexus_lang_test() {
  let src = read_file(main_js)

  // Dil döngüsü artık olay yayar (doğrudan applyLang yok)
  src
  |> string.contains("applyLang(NEXT_LANG[currentLang] || 'en')")
  |> should.be_false
  contains_all(src, ["dispatchLang(NEXT_LANG[currentLang] || 'en');"])
  |> should.be_true

  // Mobil mm-pill dil seçimi de tek kanaldan geçer
  contains_all(src, [
    "if (kind === 'lang') { dispatchLang(val); refreshChecks(); }",
  ])
  |> should.be_true

  // Masaüstü globe popover'ı da aynı olayı yayar
  read_file(header_js)
  |> string.contains("new CustomEvent('nexus:lang'")
  |> should.be_true
}

/// `dispatchLang` tek olay tanımına sahiptir ve revert bayrağını taşır.
pub fn dispatch_lang_carries_revert_flag_test() {
  let src = read_file(main_js)
  contains_all(src, [
    "function dispatchLang(lang, revert) {",
    "new CustomEvent('nexus:lang', { detail: { lang: lang, revert: !!revert } })",
  ])
  |> should.be_true
}

// ---- 3) Yalnızca gerçek değişimde bildir; revert bildirim doğurmaz ----

pub fn toast_only_on_real_change_and_not_on_revert_test() {
  let src = read_file(main_js)
  contains_all(src, [
    "var lang = e.detail && e.detail.lang;",
    "if (!lang || lang === currentLang) return;",
    "var prev = currentLang;",
    "applyLang(lang);",
    "if (!(e.detail && e.detail.revert)) showLangToast(prev, lang);",
  ])
  |> should.be_true

  // Geri düğmesi revert bayrağıyla yayar → dinleyici bildirimi atlar
  src
  |> string.contains("dispatchLang(prevLang, true);")
  |> should.be_true
}

// ---- 4) Sözlükler: bildirim anahtarları üç dilde de var ----

pub fn toast_keys_present_in_all_dicts_test() {
  let src = read_file(main_js)
  contains_all(src, [
    "'Language changed': 'Dil değiştirildi',",
    "'Back': 'Geri',",
    "'Language changed': 'Sprache geändert',",
    "'Back': 'Zurück',",
    "'Language changed': 'Язык изменён',",
    "'Back': 'Назад',",
  ])
  |> should.be_true
}

// ---- 5) Görsel katman: konum, tema, hareket azaltma ----

pub fn toast_css_matches_markup_test() {
  let css = read_file(store_css)
  // main.js'in ürettiği sınıflarla birebir eşleşmeli
  contains_all(css, [
    ".store-toast-host {",
    ".store-toast {",
    ".store-toast--in {",
    ".store-toast__msg {",
    ".store-toast__action {",
  ])
  |> should.be_true
}

/// Bildirim alt sekme çubuğunun (bnav, z-40) üstünde ve mobilde onun
/// yüksekliğinin üzerinde konumlanmalı; aksi halde Menü düğmesini örter.
/// Ayrıca mobil menü çekmecesinin (z-index 90) üstünde olmalıdır: çekmece
/// açıkken dil seçilirse "Geri" düğmesi aksi halde dokunulamaz.
pub fn toast_sits_above_overlays_test() {
  let css = read_file(store_css)
  contains_all(css, [
    "z-index: 95;",
    "bottom: calc(env(safe-area-inset-bottom, 0px) + 5.25rem);",
  ])
  |> should.be_true
  // Çekmece katmanı gerçekten 90 olmalı ki 95'in onu geçtiği kanıtlansın
  css |> string.contains("z-index: 90;") |> should.be_true
}

/// Karanlık tema yüzeyi ve vurgu token'ı; ayrıca hareket azaltma.
pub fn toast_theme_and_reduced_motion_test() {
  let css = read_file(store_css)
  contains_all(css, [
    ".dark .store-toast",
    ".dark .store-toast__action",
    "@media (prefers-reduced-motion: reduce) {",
  ])
  |> should.be_true
  // Bildirim giriş animasyonu sönme+ kayma ile yapılır; reduced-motion'da kapanır
  css
  |> string.contains("transform: translateY(8px);")
  |> should.be_true
}

/// Ölçek güvenliği: host yalnızca bir kez oluşturulur (id ataması tektir);
/// diğer erişimler `getElementById` ile bulur.
pub fn toast_host_is_singleton_test() {
  let src = read_file(main_js)
  occurrences(src, "host.id = 'store-toast-host';") |> should.equal(1)
  occurrences(src, "getElementById('store-toast-host')") |> should.equal(2)
}
