//// Mobil menü mikro etkileşimleri — aydınlık/karanlık parite sözleşmesi.
////
//// Ölçüm (gerçek tarayıcı, computed style + WCAG, iki temada):
////
////   | Hedef                | Aydınlık        | Karanlık (ÖNCE)  | Karanlık (SONRA) |
////   |----------------------|-----------------|------------------|------------------|
////   | akordeon başlığı     | 17.7 →  6.3 hv  | 13.3 →  3.3 hv   | 13.3 →  7.4 hv   |
////   | alt link             | 10.3 →  6.0 hv  |  9.9 →  1.6 hv   |  9.9 →  5.2 hv   |
////   | doğrudan link        | 17.7 →  6.3 hv  | 13.3 →  3.3 hv   | 13.3 →  7.4 hv   |
////   | ikon düğmesi         | 10.3 →  6.3 hv  | 13.3 →  3.3 hv   | 13.3 →  7.4 hv   |
////   | aktif alt link       |  6.3            |  3.3             |  7.4             |
////   | seçili seçenek tik   |  5.7            |  1.6             |  5.2             |
////
//// Karanlıkta vurgu rengi `--color-primary-500` (3.3) veya aydınlıktan miras
//// kalan `--color-primary-600` (1.6) idi — ikisi de AA (4.5) altı. Vurgu artık
//// tek token üzerinden (`--mm-accent` = primary-300) yönetilir.
////
//// Sabitlenen sözleşmeler:
////   A) `--mm-accent` yalnız karanlıkta tanımlı ve primary-300'e bağlı.
////   B) Karanlık hover/aktif/focus kuralları metin-ikon rengini bu token'dan
////      alır; aydınlık tema primary-600'ünü korur (6.0–6.3:1).
////   C) Alt link hover'ının karanlık rengi EKSİK DEĞİL (eski hata: yalnız zemin
////      vardı, metin aydınlık primary-600'ü miras alıyordu).
////   D) Zemin katmanları (`color-mix` %14 primary-500) token'a çevrilmez —
////      yalnız metin/ikon rengi değişir.
////   E) Karanlıkta ikon rozeti aydınlık lavanta zeminini taşımaz.
////   F) `prefers-reduced-motion` bloğu yeni seçicileri de kapsar.

import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import simplifile

const css_path = "priv/static/chisfis/css/custom.css"

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

pub fn parity_source_readable_test() {
  read_file(css_path) |> string.is_empty |> should.be_false
}

// ---- A) Token ----

pub fn dark_accent_token_defined_test() {
  let css = read_file(css_path)
  contains_all(css, [
    ".dark .mobile-menu {",
    "--mm-accent: var(--color-primary-300, #a5b4fc);",
  ])
  |> should.be_true
  // Token yalnız karanlıkta tanımlanır (aydınlık tema primary-600'de kalır)
  occurrences(css, "--mm-accent:") |> should.equal(1)
}

// ---- B) Karanlık vurgular token'dan gelir ----

pub fn dark_accents_route_through_token_test() {
  let css = read_file(css_path)
  contains_all(css, [
    ".dark .mm-acc-head:hover {\n  color: var(--mm-accent, #a5b4fc);\n}",
    ".dark .mm-acc-head:hover .mm-acc-chev {\n  color: var(--mm-accent, #a5b4fc);\n}",
    ".dark .mm-direct:hover {\n  border-color: var(--mm-accent, #a5b4fc);\n  color: var(--mm-accent, #a5b4fc);\n}",
    ".dark .mm-ico:hover {\n  border-color: var(--mm-accent, #a5b4fc);\n  color: var(--mm-accent, #a5b4fc);\n}",
    ".dark .mm-acc-head:focus-visible {\n  color: var(--mm-accent, #a5b4fc);\n}",
  ])
  |> should.be_true

  // Eski (AA altı) karanlık vurgu değerleri kalmamalı — kural gövdeleri
  // birebir aranır (dosyanın başka yerlerindeki border-color değerleri serbest)
  [
    ".dark .mm-acc-head:hover {\n  color: var(--color-primary-500",
    ".dark .mm-acc-head:hover .mm-acc-chev {\n  color: var(--color-primary-500",
    ".dark .mm-ico:hover {\n  border-color: var(--color-primary-500",
    ".dark .mm-direct:hover {\n  border-color: var(--color-primary-500",
    ".dark .mm-acc-head:focus-visible {\n  color: var(--color-primary-500",
    ".dark .mm-pop__tick,\nhtml.dark .mm-pop__tick {\n  color: var(--color-primary-600",
  ]
  |> list.each(fn(old) { css |> string.contains(old) |> should.be_false })
}

// ---- C) Alt link hover'ının karanlık rengi var ----

pub fn dark_sublink_hover_has_color_test() {
  let css = read_file(css_path)
  // Kurallar artık `@media (hover: hover)` İÇİNDE (bkz. G maddesi) — bu yüzden
  // iki boşluk daha girintili; kural gövdeleri birebir aynı.
  contains_all(css, [
    "  .dark .mm-acc-inner > a:hover {\n    background: var(--color-neutral-700, #404040);",
    "    color: var(--mm-accent, #a5b4fc);\n  }",
    "  .dark .mm-acc-inner > a:hover svg {\n    color: var(--mm-accent, #a5b4fc);\n  }",
  ])
  |> should.be_true
}

// ---- D) Zemin katmanları token'a çevrilmedi ----

pub fn dark_wash_layers_unchanged_test() {
  let css = read_file(css_path)
  // Aktif vurgu zeminleri primary-500 karışımı olarak kalır (metin rengi
  // token'a taşındı ama zemin doygunluğu aynı kaldı)
  occurrences(css, "background: color-mix(in srgb, var(--color-primary-500, #fb637e) 14%, transparent);")
  |> should.equal(2)
  // Token bir zemin değeri olarak kullanılmaz
  css |> string.contains("background: var(--mm-accent") |> should.be_false
}

// ---- E) Karanlık ikon rozeti + tik ----

pub fn dark_chip_and_tick_test() {
  let css = read_file(css_path)
  contains_all(css, [
    ".dark .mm-acc-ico {\n  background: color-mix(in srgb, var(--color-primary-500, #6366f1) 18%, transparent);\n  color: var(--mm-accent, #a5b4fc);\n}",
    ".dark .mm-pop__tick,\nhtml.dark .mm-pop__tick {\n  color: var(--mm-accent, #a5b4fc);\n}",
  ])
  |> should.be_true
}

// ---- G) Hover yeteneği kapısı + `.mm-direct` geçiş bütünlüğü ----

/// Canlı parite ölçümünde (gerçek tarayıcı, iki tema) çıkan iki gerçek boşluk:
///
///   1) `.mm-acc-inner > a:hover` zemin+renk kuralları `@media (hover: hover)`
///      DIŞINDAYDI → dokunmatikte yapışkan hover (dokunulan link "hover'lı"
///      görünüp öyle kalır). Ailenin kalanı bu kapının arkasında.
///   2) `.mm-direct`'in KENDİ rengi/çerçevesi geçişsizdi (`transition: all 0s`);
///      yalnız çocukları geçişliydi → ok 2–4 px kayarken kart renk atlıyordu.
///      Ayrıca aile dilindeki hover zemini (`.mm-acc-inner > a`, `.mm-ico`
///      box-shadow) bu bileşende yoktu.
pub fn hover_gate_and_direct_transition_test() {
  let css = read_file(css_path)
  contains_all(css, [
    // (1) kapı: zemin kuralı media bloğunun İÇİNDE ve girintili
    "@media (hover: hover) {\n  .mm-acc-inner > a:hover {\n    background: var(--color-neutral-50, #fafafa);",
    "  .dark .mm-acc-inner > a:hover svg {",
    // (2) geçiş + aydınlık/karanlık hover zemini
    "  .mm-direct {\n    transition: border-color .2s ease, color .2s ease, background-color .2s ease;\n  }",
    "    background: var(--color-neutral-50, #fafafa);\n  }",
    ".dark .mm-direct:hover {\n  background: var(--color-neutral-700, #404040);\n}",
  ])
  |> should.be_true

  // Kapı dışında kalan (yapışkan hover üreten) eski konum kalmamalı:
  // girintisiz `.mm-acc-inner > a:hover {` yalnız media bloğunun içindeki
  // kopyada bulunur, kök seviyede bulunmamalı.
  css
  |> string.contains("\n.mm-acc-inner > a:hover {")
  |> should.be_false

  // Hareket azaltma `.mm-direct`'in yeni geçişini de kapatır
  css
  |> string.contains("  .mm-direct,\n  .mm-direct .mm-dir-arrow,")
  |> should.be_true
}

// ---- F) Hareket azaltma kapsamı ----

pub fn reduced_motion_block_still_covers_menu_test() {
  let css = read_file(css_path)
  contains_all(css, [
    "@media (prefers-reduced-motion: reduce) {\n  .mm-acc-head,",
    ".mm-pop__opt,\n  .mm-foot-btn {\n    transition: none !important;\n  }",
  ])
  |> should.be_true
}

// ---- J) Basma (:active) geri bildirimi ----

/// Dokunmatik kullanıcı için hover geri bildirimi yoktur (tüm hover kuralları
/// `@media (hover: hover)` arkasında) — yani basma hâli tek geri bildirimdir.
/// Bu sözleşmeler sabitlenir:
///   A) Basılı hâl `scale: .98` + bir basamak koyu zemin verir.
///   B) Shorthand `transform` DEĞİL, ayrı `scale` özelliği kullanılır: hover
///      `transform`'larıyla (translateY/translateX) çakışmadan bileşir.
///   C) `:active` kuralları hover kapısının DIŞINDADIR (dokunmatikte hover yok).
///   D) İki temada da tanımlı; WhatsApp düğmesi marka yeşilini korur.
///   E) Hareket azaltmada ölçek kapanır, zemin/renk geri bildirimi kalır.
pub fn press_feedback_contract_test() {
  let css = read_file(css_path)

  contains_all(css, [
    // A + B) ölçek ve basmaya özel hızlı süre
    ".mobile-menu__close:active {\n  scale: .98;\n  transition:\n    scale .1s ease,",
    // C) seçici listesi (hover kapısı dışında, kök seviyede)
    ".mm-acc-head:active,\n.mm-acc-inner > a:active,\n.mm-direct:active,\n.mm-ico:active,\n.mm-pill:active,\n.mm-pop__opt:active,\n.mm-pop__tab:active,\n.mm-foot-btn:active,",
    // D) aydınlık + karanlık zemin kararması
    //    Grup 1: hover zemini neutral-50 ya da yok → basılı neutral-100
    ".mm-ico:not(.mm-ico--wa):active,\n.mm-pill:active,\n.mm-pop__tab:active,\n.mobile-menu__close:active {\n  background: var(--color-neutral-100, #f5f5f5);\n}",
    //    Grup 2: hover zemini ZATEN neutral-100 → basılı neutral-200
    //    (ölçüm bulgusu: ilk sürümde footer düğmesi de neutral-100'dü, yani
    //    üstünde basılı tutan kullanıcı hiçbir değişiklik görmüyordu)
    ".mm-pop__opt:active,\n.mm-foot-btn:active {\n  background: var(--color-neutral-200, #e5e5e5);\n}",
    ".mm-ico--wa:active {\n  background: #16a34a;\n}",
    ".dark .mm-pop__opt:active {\n  background: var(--color-neutral-600, #525252);\n}",
    // E) hareket azaltma
    "    scale: none !important;\n    transition-duration: 0s !important;",
  ])
  |> should.be_true

  // B) Ölçek shorthand `transform` ile yazılmamalı — hover kaymasını sıfırlar
  css
  |> string.contains("transform: scale(.98)")
  |> should.be_false
}

/// C) `:active` kuralları `@media (hover: hover)` bloklarının İÇİNE
/// kaymamalı: kayarsa hover yeteneği olmayan dokunmatik cihazlarda basma geri
/// bildirimi tamamen kaybolur. Dosyayı satır satır tarayıp hover media
/// bloklarının derinliğini takip eder.
pub fn press_rules_outside_hover_media_test() {
  let css = read_file(css_path)

  css
  |> string.split("\n")
  |> list.fold(#(False, 0, False), fn(state, line) {
    let #(in_hover, depth, leaked) = state
    let opens =
      line |> string.split("{") |> list.length |> fn(n) { n - 1 }
    let closes =
      line |> string.split("}") |> list.length |> fn(n) { n - 1 }
    let is_media =
      line
      |> string.trim
      |> string.starts_with("@media (hover: hover)")

    case in_hover {
      True -> {
        let leaked_now = leaked || string.contains(line, ":active")
        let depth_new = depth + opens - closes
        case depth_new <= 0 {
          True -> #(False, 0, leaked_now)
          False -> #(True, depth_new, leaked_now)
        }
      }
      False -> {
        case is_media {
          True -> #(True, opens - closes, leaked)
          False -> #(False, 0, leaked)
        }
      }
    }
  })
  |> fn(state) {
    let #(_, _, leaked) = state
    leaked
  }
  |> should.be_false
}

// ---- I) `.mm-pill` (Site settings) etkileşim sözleşmesi ----

/// Canlı ölçümde bulundu: dil/para popover'ının açıcısı olan `.mm-pill`
/// `transition: all 0s` idi — ne hover kuralı ne geçiş vardı; `aria-expanded`
/// taşımasına rağmen açık durumunun görsel karşılığı da yoktu. Aynı satırdaki
/// `.mm-ico`'ların tamamı bu dili taşır.
pub fn mm_pill_interaction_contract_test() {
  let css = read_file(css_path)
  contains_all(css, [
    "@media (hover: hover) {\n  .mm-pill {\n    transition: border-color .2s ease, color .2s ease;\n  }",
    "  .mm-pill:hover {\n    border-color: var(--color-primary-600, #e61e4d);\n    color: var(--color-primary-600, #e61e4d);\n  }",
    ".mm-pill[aria-expanded=\"true\"] {\n  border-color: var(--color-primary-600, #e61e4d);\n  color: var(--color-primary-600, #e61e4d);\n}",
    ".dark .mm-pill:hover,\n.dark .mm-pill[aria-expanded=\"true\"] {\n  border-color: var(--mm-accent, #a5b4fc);",
    // Hareket azaltma yeni geçişi de kapatır
    "  .mm-ico,\n  .mm-pill,\n  .mm-pop__opt,",
  ])
  |> should.be_true
}

// ---- H) Kopya kural temizliği ----

/// `.mm-acc-inner > a svg` iki kez tanımlıydı; ikinci kopya `transition`
/// bildirmiyordu ve dosyayı okuyanı yanıltıyordu (ilk kuralın geçişini
/// sessizce miras alıyordu). Tek tanım kalmalı.
pub fn sublink_svg_declared_once_test() {
  let css = read_file(css_path)
  occurrences(css, ".mm-acc-inner > a svg {") |> should.equal(1)
}

// ---- I) Çekmece KURULUM kapısı (tetikleyici çeşitliliği) ----
//
// §10 çekmeceyi kurarken tetikleyiciyi şablonun gizli `.sr-only` metninden
// ("Open main menu") buluyordu ve bulamazsa `return` ediyordu. Mağaza
// sayfalarında (ana sayfa dahil) üst bar hamburgeri yok — menüyü ALT BARIN
// "Menü" düğmesi açıyor. Sonuç: çekmece hiç kurulmuyor, basılabilir görünen
// düğme hiçbir şey açmıyordu (14 e2e testi kırmızı). Bağlama kodu zaten
// `[aria-label="Open menu"]`'ı da bağlıyordu; eksik olan yalnız KURULUM
// kapısının erken çıkışıydı. Kapı artık iki tetikleyiciden birinin varlığına
// bakar ve erken çıkış yedeklerden SONRA gelir.

const main_js_path = "priv/static/chisfis/js/main.js"

pub fn drawer_build_gate_fallbacks_test() {
  let src = read_file(main_js_path)
  src |> string.is_empty |> should.be_false
  // Erken çıkış tek olmalı: iki kapı olursa fallback'siz bir kapı geri gelir.
  occurrences(src, "if (!burger) return;") |> should.equal(1)
  // Yedek tetikleyiciler erken çıkıştan ÖNCE denenmeli.
  let before_bail =
    src |> string.split("if (!burger) return;") |> list.first |> result.unwrap("")
  contains_all(before_bail, [
    ".bnav-item[data-act=\"menu\"]",
    "button[aria-label=\"Open menu\"]",
  ])
  |> should.be_true
  // Alt bar düğmesi gerçekten çekmeceyi AÇIYOR olmalı (kurulduktan sonra).
  string.contains(src, "[aria-label=\"Open menu\"]")
  |> should.be_true
  string.contains(src, "bottomMenuBtn.addEventListener('click'")
  |> should.be_true
}
