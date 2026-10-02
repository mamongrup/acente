//// Mobil çekmece kapanış animasyonu (slide-out + fade) — statik regresyon.
////
//// Önceki davranış: çekmece kapanışta ANINDA `display: none` oluyordu; açılışta
//// oynayan slide-in'in tersi hiç görünmüyordu. Artık `mm-closing` sınıfıyla
//// MM_CLOSE_MS boyunca görünür kalır, sağa kayarak ve sönerek kapanır
//// (custom.css `.mobile-menu.mm-closing`).
////
//// Sabitlenen sözleşmeler:
////
////   A) Kayma + sönme stilleri tanımlı; çocuklar kapanış boyunca opacity 1'de
////      tutulur (açılış stagger'ı `data-state="open"`e bağlı olduğu için
////      kapanışta kalkar, kural olmazsa panel boş görünerek kayar).
////   B) `MM_CLOSE_MS` (JS) ile CSS `.28s` süresi aynı olmalı — biri değişip
////      diğeri kalırsa test kırmızı olur.
////   C) Kapanış yolu: `data-state` ANINDA `closed` (bnav göstergesi ve "açık
////      mı?" mantığı beklemez), `mm-closing` eklenir, gizleme zamanlayıcıya
////      bırakılır.
////   D) Yeniden açılış bekleyen gizlemeyi iptal eder — hem `set(true)` hem
////      ayrı IIFE'deki `openMenu()` (aksi halde zamanlayıcı ateşlenip açık
////      çekmeceyi kapatırdı).
////   E) `prefers-reduced-motion: reduce` altında animasyon yok; JS anında
////      kapatır.
////   F) Sayfa kaydırma kilidi sönme bitene kadar sürer (panel kayarken
////      arkadaki sayfa oynamasın).

import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const main_js_path = "priv/static/chisfis/js/main.js"

const drawer_css_path = "priv/static/chisfis/css/custom.css"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
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

fn take_digits(src: String) -> String {
  src
  |> string.to_graphemes
  |> list.take_while(fn(g) { string.contains("0123456789", g) })
  |> string.concat
}

/// JS'teki `var MM_CLOSE_MS = <n>;` değeri (ms).
fn close_ms(src: String) -> Result(Int, Nil) {
  src |> after("var MM_CLOSE_MS = ") |> take_digits |> int.parse
}

/// CSS'teki `transition: transform .<n>s ...` değeri (1/100 sn).
fn close_css_hundredths(css: String) -> Result(Int, Nil) {
  css
  |> after(
    ".mobile-menu.mm-closing .mobile-menu__panel {\n  opacity: 0;\n  transform: translateX(100%);\n  transition: transform .",
  )
  |> take_digits
  |> int.parse
}

pub fn drawer_close_sources_readable_test() {
  read_file(main_js_path) |> string.is_empty |> should.be_false
  read_file(drawer_css_path) |> string.is_empty |> should.be_false
}

// ---- A) Kayma + sönme stilleri ----

pub fn drawer_close_styles_present_test() {
  let css = read_file(drawer_css_path)
  contains_all(css, [
    ".mobile-menu.mm-closing {",
    "display: block;",
    "pointer-events: none",
    ".mobile-menu.mm-closing .mobile-menu__backdrop {",
    ".mobile-menu.mm-closing .mobile-menu__panel {",
    "transform: translateX(100%);",
    // RTL'de panel solda durur; kayma yönü ters olmalı
    "html[dir=\"rtl\"] .mobile-menu.mm-closing .mobile-menu__panel {",
    "transform: translateX(-100%);",
  ])
  |> should.be_true
}

/// Çocuk kuralı: kapanış boyunca opacity 1 ve stagger animasyonu kapalı.
pub fn drawer_close_keeps_children_visible_test() {
  let css = read_file(drawer_css_path)
  contains_all(css, [
    ".mobile-menu.mm-closing .mobile-menu__panel > * {",
    "opacity: 1;",
    "animation: none;",
  ])
  |> should.be_true
}

// ---- B) Süre eşleşmesi ----

pub fn drawer_close_duration_matches_css_test() {
  let css = read_file(drawer_css_path)
  let assert Ok(hundredths) = close_css_hundredths(css)
  let expected_ms = hundredths * 10

  main_js_path |> read_file |> close_ms |> should.equal(Ok(expected_ms))
}

// ---- C) Kapanış yolu: durum anında, gizleme gecikmeli ----

pub fn drawer_close_defers_hiding_test() {
  let src = read_file(main_js_path)
  contains_all(src, [
    "function mmFinishClose() {",
    "menu.classList.remove('mm-closing');",
    "menu.setAttribute('data-state', 'closed');",
    "menu.classList.add('mm-closing');",
    "menu.__mmCloseTimer = setTimeout(mmFinishClose, MM_CLOSE_MS);",
  ])
  |> should.be_true
}

// ---- D) Yeniden açılış bekleyen gizlemeyi iptal eder ----

pub fn drawer_reopen_cancels_pending_close_test() {
  let src = read_file(main_js_path)
  // Hem ortak `set(...)` yolu (iptal + finish) hem de ayrı IIFE'deki
  // `openMenu()` iptal etmeli.
  src
  |> string.split(
    "if (menu.__mmCloseTimer) { clearTimeout(menu.__mmCloseTimer); menu.__mmCloseTimer = null; }",
  )
  |> list.length
  |> fn(n) { n - 1 }
  |> should.equal(2)

  src
  |> string.split(
    "if (m.__mmCloseTimer) { clearTimeout(m.__mmCloseTimer); m.__mmCloseTimer = null; }",
  )
  |> list.length
  |> fn(n) { n - 1 }
  |> should.equal(1)

  contains_all(src, [
    "function openMenu() {",
    "m.classList.remove('mm-closing');",
  ])
  |> should.be_true
}

// ---- E) Hareket azaltma ----

pub fn drawer_close_respects_reduced_motion_test() {
  let css = read_file(drawer_css_path)
  contains_all(css, [
    "@media (prefers-reduced-motion: reduce) {",
    ".mobile-menu.mm-closing .mobile-menu__backdrop,",
    ".mobile-menu.mm-closing .mobile-menu__panel {",
    "transition: none;",
  ])
  |> should.be_true

  let src = read_file(main_js_path)
  contains_all(src, [
    "function mmReducedMotion() {",
    "prefers-reduced-motion: reduce",
    "} else if (mmReducedMotion()) {",
  ])
  |> should.be_true
}

// ---- F) Kaydırma kilidi sönme bitene kadar sürer ----

pub fn drawer_scroll_lock_released_after_fade_test() {
  let src = read_file(main_js_path)
  contains_all(src, [
    "document.documentElement.classList.remove('overflow-hidden');",
    "if (open) document.documentElement.classList.add('overflow-hidden');",
  ])
  |> should.be_true
}
