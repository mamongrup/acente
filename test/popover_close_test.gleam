//// Popover kapanış sönmesi — statik regresyon testleri.
////
//// Önceki davranış: `closePanel` paneli ANINDA `display: none` yapıyordu.
//// Şimdi 140 ms'lik bir opacity sönmesi oynatılıyor; süre bitince gizleniyor
//// (chisfis-bridge.css `.nx-closing` + `nx-panel-out` / `nx-child-out`).
////
//// Sabitlenen sözleşmeler:
////
////   A) Sönme animasyonu ve kapanış sınıfı CSS'te tanımlı; çocuk kuralı
////      `.nc-pop` / `.mm-pop` ile sınırlı (yalnız onların çocukları
////      `opacity: 0` temelli, `forwards` dolgulu stagger'a bağlı).
////   B) `CLOSE_FADE_MS` (JS) ile CSS süresi aynı olmalı — biri değişip
////      diğeri kalırsa test kırmızı olur.
////   C) Kapanış yolu: `data-state` ANINDA `closed` (düğme mantığı ve
////      aria-expanded bozulmasın), `hidden` ise zamanlayıcıdan sonra.
////   D) `openPanel` bekleyen gizlemeyi iptal eder (hızlı aç/kapa yarışı yok).
////   E) `prefers-reduced-motion: reduce` altında sönme yok; JS anında kapatır.
////   F) mm-pop (mobil dil/para popover'ı) de aynı yolu kullanmalı — ham
////      `pop.hidden = true` çağrıları kalmamalı.

import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const popovers_js_path = "priv/static/header-popovers.js"

const main_js_path = "priv/static/chisfis/js/main.js"

const bridge_css_path = "priv/static/chisfis-bridge.css"

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

/// JS'teki `var CLOSE_FADE_MS = <n>;` değeri (ms).
fn close_fade_ms(src: String) -> Result(Int, Nil) {
  src |> after("var CLOSE_FADE_MS = ") |> take_digits |> int.parse
}

/// CSS'teki `animation: nx-panel-out .<n>s ...` değeri (1/100 sn).
fn close_fade_css_hundredths(css: String) -> Result(Int, Nil) {
  css |> after("nx-panel-out .") |> take_digits |> int.parse
}

pub fn popover_close_sources_readable_test() {
  read_file(popovers_js_path) |> string.is_empty |> should.be_false
  read_file(main_js_path) |> string.is_empty |> should.be_false
  read_file(bridge_css_path) |> string.is_empty |> should.be_false
}

// ---- A) Sönme stili ----

pub fn close_fade_styles_present_test() {
  let css = read_file(bridge_css_path)
  contains_all(css, [
    ".nx-closing {",
    "animation: nx-panel-out",
    "@keyframes nx-panel-out {",
    "@keyframes nx-child-out {",
    // Çocuk sönmesi yalnız bu iki popover için (diğer panellerin çocukları
    // böyle bir animasyona sahip değil)
    ".nc-pop.nx-closing > *,",
    ".mm-pop.nx-closing > *",
    "pointer-events: none",
  ])
  |> should.be_true
}

// ---- B) Süre eşleşmesi ----

pub fn close_fade_duration_matches_both_js_files_test() {
  let css = read_file(bridge_css_path)
  let assert Ok(hundredths) = close_fade_css_hundredths(css)
  let expected_ms = hundredths * 10

  // İki dosyadan da tam olarak beklenen değer okunmalı; biri eksik/bozuksa
  // liste kısa kalır ve test kırılır.
  [popovers_js_path, main_js_path]
  |> list.filter_map(fn(path) { close_fade_ms(read_file(path)) })
  |> should.equal([expected_ms, expected_ms])
}

// ---- C) Kapanış yolu: durum anında, gizleme gecikmeli ----

pub fn close_fade_defers_hiding_test() {
  [popovers_js_path, main_js_path]
  |> list.each(fn(path) {
    let src = read_file(path)
    contains_all(src, [
      // Kapanış: önce durum, sonra sönme, en son gizleme
      "function closePanel(panel) {",
      "panel.setAttribute('data-state', 'closed');",
      "panel.classList.add('nx-closing');",
      "panel.__nxHideTimer = setTimeout(function () { hidePanel(panel); }, CLOSE_FADE_MS);",
      // Gizleme tek bir yerde toplanmış
      "function hidePanel(panel) {",
      "panel.hidden = true;",
      "panel.style.display = 'none';",
    ])
    |> should.be_true
  })
}

// ---- D) Yeniden açılış bekleyen gizlemeyi iptal eder ----

pub fn reopen_cancels_pending_fade_test() {
  [popovers_js_path, main_js_path]
  |> list.each(fn(path) {
    let src = read_file(path)
    contains_all(src, [
      "function openPanel(panel) {",
      "if (panel.__nxHideTimer) { clearTimeout(panel.__nxHideTimer); panel.__nxHideTimer = null; }",
      "panel.classList.remove('nx-closing');",
    ])
    |> should.be_true
  })
}

// ---- E) Hareket azaltma ----

pub fn close_fade_respects_reduced_motion_test() {
  let css = read_file(bridge_css_path)
  contains_all(css, [
    "@media (prefers-reduced-motion: reduce) {",
    ".nx-closing,",
    "animation: none !important;",
  ])
  |> should.be_true

  [popovers_js_path, main_js_path]
  |> list.each(fn(path) {
    let src = read_file(path)
    src |> string.contains("function reducedMotion()") |> should.be_true
    src
    |> string.contains("if (reducedMotion()) { hidePanel(panel); return; }")
    |> should.be_true
  })
}

// ---- F) mm-pop da aynı yolu kullanıyor ----

/// Mobil dil/para popover'ının kapanışları ham `pop.hidden = true` yerine
/// `closePanel(pop)` çağırmalı; ham çağrı yalnız oluşturulurken (başlangıçta
/// gizli) kalmalı.
pub fn mm_pop_uses_shared_close_fade_test() {
  let src = read_file(main_js_path)
  let raw_closes =
    src
    |> string.split("pop.hidden = true")
    |> list.length
    |> fn(n) { n - 1 }

  raw_closes |> should.equal(1)
  contains_all(src, [
    "function isMmPopOpen()",
    "if (nowOpen) { closePanel(pop); } else { openPanel(pop); }",
    "$('.mobile-menu__backdrop', menu).addEventListener('click', function () { closePanel(pop); });",
    "$('.mobile-menu__close', menu).addEventListener('click', function () { closePanel(pop); });",
  ])
  |> should.be_true
}
