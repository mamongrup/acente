//// Scroll-reveal (kademeli giriş animasyonu) — statik regresyon testleri.
////
//// Kapsam: header (yapışkan satırlarıyla), hero arama formu ve tüm ana sayfa
//// bölümlerinin görünür olduklarında kademeli belirmesi.
////
//// Sistem üç dosyaya yayılır:
////   1) priv/static/reveal-boot.js       — ilk boyamadan önce `html.has-reveal`
////   2) priv/static/chisfis-bridge.css   — gizli başlangıç durumu + geçiş
////   3) priv/static/chisfis/js/main.js   — hedefleri işaretler, gözlemler, açar
////
//// Sabitlenen davranışlar (her biri gerçek bir hata sınıfını kapatır):
////
////   A) Gizli durum YALNIZ `html.has-reveal` varken uygulanır ve bu sınıfı
////      ilk boyamadan önce boot script ekler. JS yoksa/çökerse içerik görünür
////      kalır (progressive enhancement) + 3 sn güvenlik ağı vardır.
////   B) Kurallar render-blocking `chisfis-bridge.css`'te yaşar; gecikmeli
////      yüklenen `custom.css`'e taşınırsa hero bir an görünüp gizlenir (FOUC)
////      ve geçişin başlangıç durumu kaybolur.
////   C) Geçiş bittiğinde `transform: none` (kalıcı transform yok) → şablonun
////      `position: sticky` yapışkan header satırı bozulmaz.
////   D) `prefers-reduced-motion: reduce` altında hiç gizleme/geçiş yok.
////   E) Hedefler: header + hero arama formu parçaları + `body > section` /
////      `main > section` bölümleri; ızgara çocukları kademeli (0.06s adım).
////   F) Gözlemci birincil, kaydırma taraması ikincil kapıdır: IO geri çağrısı
////      atlanırsa içerik gizli kalmaz (settle + `[data-reveal]` temizliği).
////   G) Eski kaba `main > div { animation: fadeInUp }` kuralı geri gelmemeli
////      (aynı elemanlarda çift transform/opaklık çakışması).

import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const bridge_css_path = "priv/static/chisfis-bridge.css"

const main_js_path = "priv/static/chisfis/js/main.js"

const custom_css_path = "priv/static/chisfis/css/custom.css"

const boot_js_path = "priv/static/reveal-boot.js"

const router_erl_path = "src/nexus_agency/erl/nexus_agency@router_impl.erl"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

fn contains_all(haystack: String, needles: List(String)) -> Bool {
  list.all(needles, fn(needle) { string.contains(haystack, needle) })
}

/// Üç parça da okunabilmeli (yol kayarsa test sessizce yeşil kalmasın).
pub fn reveal_sources_readable_test() {
  read_file(boot_js_path) |> string.is_empty |> should.be_false
  read_file(bridge_css_path) |> string.is_empty |> should.be_false
  read_file(main_js_path) |> string.is_empty |> should.be_false
}

// ---- A) Boot zinciri ve progressive enhancement ----

/// Boot script ilk boyamadan önce gizli durumu işaretler; hareket azaltma
/// tercihinde hiç dokunmaz ve denetleyici devralmazsa 3 sn sonra geri alır.
pub fn reveal_boot_marks_first_paint_test() {
  let boot = read_file(boot_js_path)
  contains_all(boot, [
    "classList.add('has-reveal')",
    "prefers-reduced-motion: reduce",
    "data-reveal-ready",
    "setTimeout",
    "classList.remove('has-reveal')",
  ])
  |> should.be_true
}

/// Boot script HTML'e girmeli ve main.js'ten ÖNCE yüklenmeli (main.js `defer`
/// ile gelir; gizleme ondan önce kurulmazsa titreme olur).
pub fn reveal_boot_served_before_controller_test() {
  let erl = read_file(router_erl_path)
  string.contains(erl, "/static/reveal-boot.js") |> should.be_true
  let assert Ok(#(before_boot, after_boot)) =
    string.split_once(erl, "/static/reveal-boot.js")
  // theme-boot.js'ten sonra (aynı boot deseni), main.js'ten önce.
  string.contains(before_boot, "/static/theme-boot.js") |> should.be_true
  string.contains(after_boot, "main.js?v=") |> should.be_true
}

// ---- B) Gizli durumun yeri: render-blocking stylesheet ----

/// Gizli başlangıç durumu render-blocking bridge CSS'te yaşamalı.
///
/// `custom.css` `media="print"` hilesiyle gecikmeli yüklenir; kurallar oraya
/// taşınırsa sayfa önce görünür, sonra gizlenip yeniden açılır.
pub fn reveal_hidden_state_lives_in_render_blocking_sheet_test() {
  let bridge = read_file(bridge_css_path)
  contains_all(bridge, [
    "html.has-reveal [data-reveal] {",
    "opacity: 0;",
    "translate3d(0, var(--reveal-rise, 18px), 0)",
    "html.has-reveal [data-reveal].is-revealed",
    "--reveal-delay",
    "header.chisfis-header-root[data-reveal]",
  ])
  |> should.be_true

  let custom = read_file(custom_css_path)
  string.contains(custom, "html.has-reveal")
  |> should.be_false
}

// ---- C) Sticky güvenliği ----

/// Geçiş bitiş değeri `transform: none` olmalı.
///
/// Kalıcı bir transform, yapışkan (`position: sticky`) header satırı için
/// containing block yaratır ve şablonun sticky davranışını bozar.
pub fn reveal_finishes_without_persisted_transform_test() {
  let bridge = read_file(bridge_css_path)
  let assert Ok(#(_, revealed_block)) =
    string.split_once(bridge, "html.has-reveal [data-reveal].is-revealed {")
  let assert Ok(#(block, _)) = string.split_once(revealed_block, "}")
  // Bitiş opaklığı hedefin KENDİ değeridir (`--reveal-op`); değişken yoksa 1.
  contains_all(block, [
    "transform: none",
    "opacity: var(--reveal-op, 1);",
    "transition:",
  ])
  |> should.be_true
  // Geçiş süresi/ivmelendirmesi gizli durumdaki kaymayı hedefler.
  string.contains(block, "cubic-bezier") |> should.be_true
}

// ---- D) Hareket azaltma sözleşmesi ----

pub fn reveal_respects_reduced_motion_test() {
  let bridge = read_file(bridge_css_path)
  let assert Ok(#(_, tail)) = string.split_once(bridge, "html.has-reveal")
  string.contains(tail, "@media (prefers-reduced-motion: reduce)")
  |> should.be_true
  string.contains(tail, "transition: none")
  |> should.be_true

  // Denetleyici de aynı tercihte hiç gizlemez / işaretlemez.
  let js = read_file(main_js_path)
  contains_all(js, [
    "prefers-reduced-motion: reduce",
    "classList.remove('has-reveal')",
    "if (!html.classList.contains('has-reveal')) return;",
  ])
  |> should.be_true
}

// ---- E) Hedef kümesi ve kademe ----

/// Header + hero arama formu + tüm ana sayfa bölümleri işaretlenmeli;
/// kademe 0.06s adımla ve üst sınıra kadar uygulanır.
pub fn reveal_marks_header_hero_and_sections_test() {
  let js = read_file(main_js_path)
  contains_all(js, [
    // Header (yapışkan satırları da içinde)
    "$('header.chisfis-header-root')",
    // Hero arama formu: sekmeler + alanlar + buton kademeli
    "$('.hero-search-form')",
    "$('[role=\"tablist\"]', heroForm)",
    "$$('form > *', heroForm)",
    // Bölümler (builder çıktısı `body > section`, alternatif `main > section`)
    "'body > section, main > section, main > div, body > div'",
    // Izgara çocukları tek tek kademeli (`/-grid$/` regex'i)
    "function isGrid(el)",
    "-grid$/",
    // Kademe değerleri
    "var STEP = 0.06;",
    "var MAX_DELAY = 0.42;",
    // Görünmez dallar işaretlenmez (asılı hedef kalmasın)
    "getClientRects",
  ])
  |> should.be_true
}

// ---- F) Gözlemci + ikinci kapı + temizlik ----

/// IO birincil, kaydırma taraması ikincil kapı olmalı ve reveal sonunda
/// `data-reveal` temizlenmeli (kalıcı işaret = kalıcı gizlenme riski).
pub fn reveal_observer_and_sweep_contract_test() {
  let js = read_file(main_js_path)
  contains_all(js, [
    "new IntersectionObserver(",
    "io.observe(el)",
    "function sweep()",
    "window.addEventListener('scroll', scheduleSweep, { passive: true, capture: true })",
    "window.addEventListener('resize', scheduleSweep",
    "html.setAttribute('data-reveal-ready', '')",
    // Temizlik: işaret kaldırılır ki kartların kendi hover geçişleri emilmesin
    "el.removeAttribute('data-reveal')",
    "el.classList.remove('is-revealed')",
  ])
  |> should.be_true
}

/// Gizli durum hesaplanmadan açılırsa geçiş oynamaz; kapı korunmalı.
pub fn reveal_waits_for_hidden_state_test() {
  let js = read_file(main_js_path)
  contains_all(js, [
    "function whenHidden(cb)",
    "parseFloat(getComputedStyle(probe).opacity) === 0",
    "requestAnimationFrame(cb)",
  ])
  |> should.be_true
}

// ---- G) Eski kaba giriş animasyonu geri gelmemeli ----

pub fn legacy_fade_in_animation_removed_test() {
  let custom = read_file(custom_css_path)
  string.contains(custom, "animation: fadeInUp")
  |> should.be_false
}

// ---- H) Mağaza sayfaları (ilan listesi / kategori / detay) ----

/// Başlık bloğu hedefi: mağaza sayfalarında eyebrow, kırıntı, `h1` ve lede
/// `main`in DOĞRUDAN çocuklarıdır ve `div`/`section` DEĞİLDİR — genel blok
/// taraması (`main > section, main > div`) onları atlar. Bu yüzden ayrı bir
/// "başlık bloğu" geçişi gerekir: bayt bayt bu adım olmazsa sayfa başlığı
/// animasyonsuz açılırken altındaki filtre/ızgara kademeli girer (asimetri).
pub fn reveal_covers_store_page_heading_test() {
  let js = read_file(main_js_path)
  contains_all(js, [
    "$$('main > *').forEach(function (el) {",
    "if (el.tagName === 'DIV' || el.tagName === 'SECTION') return;",
    "if (el.tagName === 'SCRIPT' || el.tagName === 'STYLE' || el.tagName === 'TEMPLATE' || el.tagName === 'LINK') return;",
    "mark(el, headingDelay);",
    "headingDelay += STEP;",
  ])
  |> should.be_true

  // `div`/`section` çocukları ATLANMALI: onlar blok taramasının kapsamında ve
  // iki geçişte birden işaretlenirse sarmalayıcı ile çocukları iç içe iki kez
  // animasyon oynatır (sarmalayıcının transform'u alt ağacı taşır).
  js
  |> string.contains(
    "if (el.tagName === 'DIV' || el.tagName === 'SECTION') return;",
  )
  |> should.be_true
}

/// Kendi opaklığı 1'den küçük hedefler: (a) `opacity: 0` olan hover katmanı
/// (zoom merceği) hiç işaretlenmez — reveal onu bir an görünür yapardı;
/// (b) yarı saydam eleman (`.category-hero-image` → .92) animasyon boyunca 1'e
/// zorlanmaz, kendi değerine `--reveal-op` ile ulaşır. Aksi halde animasyon
/// sonunda parlaklık sıçraması olur.
pub fn reveal_preserves_own_opacity_test() {
  let js = read_file(main_js_path)
  contains_all(js, [
    "var own = parseFloat(getComputedStyle(el).opacity);",
    "if (!(own > 0)) return;",
    "el.style.setProperty('--reveal-op', String(own));",
    "el.style.removeProperty('--reveal-op');",
  ])
  |> should.be_true

  // CSS hedefi değişkeni okumalı; sabit `1` kalmamalı
  let css = read_file(bridge_css_path)
  contains_all(css, [
    "opacity: var(--reveal-op, 1);",
    // Azaltılmış harekette yine hiç gizleme yok
    "html.has-reveal [data-reveal].is-revealed {",
  ])
  |> should.be_true
}

/// Store sayfalarının kendi kademesi `STEP` (.06s) ile artmalı ve gecikme
/// üstten sınırlanmalı (`MAX_DELAY`) — uzun listede tüm kartlar sıraya girip
/// son kartı dakikalarca bekletmesin.
pub fn reveal_store_delays_bounded_test() {
  let js = read_file(main_js_path)
  contains_all(js, [
    "var STEP = 0.06;",
    "var MAX_DELAY = 0.42;",
    "Math.min(Math.max(delay, 0), MAX_DELAY)",
  ])
  |> should.be_true
}
