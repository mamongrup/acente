//// FAB modallarının (sepet + site arama) kapanış animasyonu — statik regresyon.
////
//// Önceki davranış: iki modal da kapanışta `hidden` sınıfını ANINDA ekliyordu;
//// `display: none` geçişi kestiği için ne kapanış ne açılış animasyonu vardı.
//// Artık `nx-modal-closing` sınıfıyla MODAL_CLOSE_MS boyunca sönüp aşağı
//// kayıyor, süre bitince `hidden` uygulanıyor (bridge CSS
//// `#cart-modal` / `#search-modal` bloğu); açılış aynı yolu `nx-modal-opening`
//// ile tersine kullanıyor.
////
//// Sabitlenen sözleşmeler:
////
////   A) Sönme + kayma stilleri tanımlı: kök opaklığı söner, panel 12px aşağı
////      kayıp hafifçe küçülür; açılış aynı başlangıç durumundan gelir.
////   B) `MODAL_CLOSE_MS` (JS) ile CSS `0.2s` süresi aynı olmalı — biri
////      değişip diğeri kalırsa test kırmızı olur.
////   C) Gizleme gecikmeli: `finish()` zamanlayıcıya bırakılır, sönme sürerken
////      modal DOM'da kalır.
////   D) Yinelenen kapatma isteği (Escape + backdrop) tek zamanlayıcı kurar;
////      `__nxModalOpen` kapısı ikinci çağrıyı erken döndürür.
////   E) Yeniden açılış bekleyen gizlemeyi iptal eder — hem `showModal` hem
////      alt bardaki `openCart()` köprüsü (aksi hâlde zamanlayıcı ateşlenip
////      AÇIK modalı gizlerdi).
////   F) `prefers-reduced-motion: reduce` altında geçiş yok; JS anında gizler.
////   G) Her iki modal tek yol üzerinden açılıp kapanır; doğrudan `hidden`
////      değiştiren eski aç/kapat gövdeleri kalmamalı.
////   H) Arama girdisi sönme BİTİNCE temizlenir (animasyon sürerken sonuçlar
////      bir anda kaybolmasın; yeniden açılırsa sorgu korunur).

import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const main_js_path = "priv/static/chisfis/js/main.js"
const bridge_css_path = "priv/static/chisfis-bridge.css"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    // Windows checkout'ları CRLF yazar; iğneler LF varsayar. Satır sonlarını
    // LF'e indirerek test checkout-bağımsız olur.
    Ok(content) -> string.replace(content, "\r\n", "\n")
    Error(_) -> ""
  }
}

fn contains_all(haystack: String, needles: List(String)) -> Bool {
  list.all(needles, fn(needle) { string.contains(haystack, needle) })
}

fn after(src: String, marker: String) -> String {
  case string.split_once(src, marker) {
    Ok(#(_, rest)) -> rest
    Error(_) -> ""
  }
}

fn count_of(src: String, needle: String) -> Int {
  src |> string.split(needle) |> list.length |> fn(n) { n - 1 }
}

fn take_digits(src: String) -> String {
  src
  |> string.to_graphemes
  |> list.take_while(fn(g) { string.contains("0123456789", g) })
  |> string.concat
}

/// JS'teki `var MODAL_CLOSE_MS = <n>;` değeri (ms).
fn close_ms(src: String) -> Result(Int, Nil) {
  src |> after("var MODAL_CLOSE_MS = ") |> take_digits |> int.parse
}

/// CSS'teki panel geçişi `transition: transform 0.<n>s ...` değeri.
/// Ondalık kısım tek basamak yazılır (`0.2s`); dönen değer 1/10 sn'dir, ms'e
/// çevirmek için 100 ile çarpılır.
fn close_css_tenths(css: String) -> Result(Int, Nil) {
  css
  |> after("#cart-modal > div,\n#search-modal > div {\n  transition: transform 0.")
  |> take_digits
  |> int.parse
}

pub fn modal_close_sources_readable_test() {
  read_file(main_js_path) |> string.is_empty |> should.be_false
  read_file(bridge_css_path) |> string.is_empty |> should.be_false
}

// ---- A) Sönme + kayma stilleri ----

pub fn modal_close_styles_present_test() {
  let css = read_file(bridge_css_path)
  contains_all(css, [
    "#cart-modal,\n#search-modal {\n  transition: opacity 0.2s ease;\n}",
    "#cart-modal > div,\n#search-modal > div {\n  transition: transform 0.2s cubic-bezier(0.2, 0.8, 0.3, 1), opacity 0.2s ease;\n}",
    ".nx-modal-opening,\n.nx-modal-closing {\n  opacity: 0;\n}",
    ".nx-modal-closing {\n  pointer-events: none;",
    ".nx-modal-opening > div,\n.nx-modal-closing > div {\n  transform: translateY(12px) scale(0.98);\n}",
    ".nx-modal-closing > div {\n  opacity: 0;\n}",
  ])
  |> should.be_true
}

// ---- B) Süre eşleşmesi ----

pub fn modal_close_duration_matches_css_test() {
  let css = read_file(bridge_css_path)
  let assert Ok(tenths) = close_css_tenths(css)
  let expected_ms = tenths * 100

  main_js_path |> read_file |> close_ms |> should.equal(Ok(expected_ms))
}

// ---- C) Gizleme gecikmeli ----

pub fn modal_close_defers_hiding_test() {
  let src = read_file(main_js_path)
  contains_all(src, [
    "function showModal(el) {",
    "function hideModal(el, done) {",
    "el.classList.add('nx-modal-closing');",
    "el.__nxModalTimer = setTimeout(finish, MODAL_CLOSE_MS);",
    // Sönme tamamlanınca gerçekten gizlenir
    "el.classList.remove('nx-modal-closing', 'flex');",
    "el.classList.add('hidden');",
  ])
  |> should.be_true
}

// ---- D) Yinelenen kapatma tek zamanlayıcı ----

pub fn modal_close_deduplicates_requests_test() {
  let src = read_file(main_js_path)
  contains_all(src, [
    "// Yinelenen çağrı (Escape + backdrop aynı karede) ikinci bir zamanlayıcı",
    "if (!el || !el.__nxModalOpen) return;",
    "if (el.__nxModalOpen) return; // bu sırada yeniden açıldıysa gizleme",
  ])
  |> should.be_true
}

// ---- E) Yeniden açılış iptal eder ----

pub fn modal_reopen_cancels_pending_close_test() {
  let src = read_file(main_js_path)
  // İptal iki yerde: `showModal` girişi ve `finish` içi (zamanlayıcı temizliği).
  src
  |> count_of("if (el.__nxModalTimer) { clearTimeout(el.__nxModalTimer); el.__nxModalTimer = null; }")
  |> should.equal(2)

  // Alt bardaki "Sepet" düğmesi ayrı IIFE'de; köprüden geçmeli.
  contains_all(src, [
    "window.NEXUS_MODALS = {",
    "showCart: function () { showModal(cartModal); },",
    "var api = window.NEXUS_MODALS;",
    "if (api) { api.showCart(); return; }",
  ])
  |> should.be_true
}

// ---- F) Hareket azaltma ----

pub fn modal_close_respects_reduced_motion_test() {
  let css = read_file(bridge_css_path)
  contains_all(css, [
    "/* Hareket azaltma: geçiş yok, JS modalı anında gizler */\n@media (prefers-reduced-motion: reduce) {\n  #cart-modal,\n  #search-modal,\n  #cart-modal > div,\n  #search-modal > div {\n    transition: none;\n  }\n}",
  ])
  |> should.be_true

  let src = read_file(main_js_path)
  contains_all(src, [
    "if (reducedMotion()) return;",
    "if (reducedMotion()) { finish(); return; }",
  ])
  |> should.be_true
}

// ---- G) Tek yol: modallar paylaşılan yardımcıdan geçer ----

pub fn modal_close_single_path_test() {
  let src = read_file(main_js_path)
  contains_all(src, [
    "function openCartModal() { showModal(cartModal); }",
    "function closeCartModal() { hideModal(cartModal); }",
    "showModal(searchModal);",
    "hideModal(searchModal, function () {",
  ])
  |> should.be_true

  // Eski anında-gizleme gövdeleri kalmamalı
  count_of(src, "cartModal.classList.add('hidden')") |> should.equal(0)
  count_of(src, "searchModal.classList.add('hidden')") |> should.equal(0)
  count_of(src, "searchModal.classList.remove('flex')") |> should.equal(0)
  // Alt bar köprüsü bulunamazsa kalan tek doğrudan açma (fallback) korunur
  count_of(src, "m.classList.remove('hidden')") |> should.equal(1)
}

// ---- H) Arama girdisi sönme bitince temizlenir ----

pub fn modal_close_clears_search_input_after_fade_test() {
  let src = read_file(main_js_path)
  let close_body = src |> after("function closeSearchModal() {")
  contains_all(close_body, [
    "hideModal(searchModal, function () {",
    "var inp = searchModal.querySelector('#site-search');",
    "inp.value = '';",
    "inp.dispatchEvent(new Event('input'));",
  ])
  |> should.be_true
}

// ---- Kapanış yolları (Escape) hâlâ yardımcıları çağırır ----

pub fn modal_close_escape_paths_test() {
  let src = read_file(main_js_path)
  contains_all(src, [
    "if (e.key === 'Escape' && !cartModal.classList.contains('hidden')) {\n        closeCartModal();",
    "if (e.key === 'Escape' && !searchModal.classList.contains('hidden')) {\n        closeSearchModal();",
  ])
  |> should.be_true
}
