//// Mağaza navigasyonu — aktif kategori vurgusu regresyon testleri.
////
//// Kapsam: mobil menü (mm-acc/mm-direct) VE masaüstü Keşfet popover'ı
//// (.nc-pop__link). İki katman da /urunler?kategori=<slug> filtresini
//// vurgular; slug kümeleri aynı olmak zorundadır.
////
//// Sabitlenen davranışlar:
////
////   1) Aktif kategori yalnız pathname ile değil, liste sayfasının
////      `?kategori=<slug>` sorgu parametresiyle de eşleşir
////      (/urunler?kategori=tour → /kategori/tour linki vurgulanır).
////   2) `custom.css` içindeki generic "panel düz link" seçicisi
////      (`.mobile-menu__panel > a:not(.mobile-menu__brand)`) `.mm-direct`
////      bileşen linkini kapsamamalıdır. Bu seçici daha yüksek özgünlükte
////      olduğu için bileşenin flex düzenini, padding/radius'unu ve rengini
////      eziyordu; aktif vurgu da bu yüzden boyanmıyordu.

import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import simplifile

const main_js_path = "priv/static/chisfis/js/main.js"

const custom_css_path = "priv/static/chisfis/css/custom.css"

const header_js_path = "priv/static/header-popovers.js"

const erl_path = "src/nexus_agency/erl/nexus_agency@router_impl.erl"

const bridge_css_path = "priv/static/chisfis-bridge.css"

const bnav_css_path = "priv/static/chisfis/css/custom.css"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    // Windows checkout'ları CRLF yazar; iğneler LF varsayar. Satır sonlarını
    // LF'e indirerek test checkout-bağımsız olur.
    Ok(content) -> string.replace(content, "\r\n", "\n")
    Error(_) -> ""
  }
}

/// Menü üreticisi dosyası okunabilmeli (yol kayarsa test sessizce geçmesin).
pub fn mobile_menu_scripts_readable_test() {
  read_file(main_js_path) |> string.is_empty |> should.be_false
  read_file(custom_css_path) |> string.is_empty |> should.be_false
}

/// Aktif kategori eşleşmesi TEK kaynaktan gelir ve iki formu da bilir:
/// kategori yolu (`/kategori/<slug>`) ve liste filtresi (`?kategori=<slug>`).
///
/// Neden tek kaynak: aynı soru iki dosyada iki kopya olarak yanıtlanıyordu ve
/// kopyalar ayrıştı — masaüstü yalnız sorgu filtresini biliyordu, çekmece ise
/// yolu da biliyordu; `/kategori/hotel` sayfasında mobil menü vurgulu,
/// masaüstü header menüsü vurgusuz kalıyordu.
pub fn nav_active_single_source_test() {
  let src = read_file(main_js_path)
  // Tek tanım (ikinci kopya geri gelirse kapı kırılır)
  src |> count_occurrences("window.NEXUS_NAV = ") |> should.equal(1)
  // Kısa kategori yolu ve liste filtresi aynı predicate içinde.
  src |> string.contains("[?&]kategori=([^&]*)") |> should.be_true
  src |> string.contains("window.NEXUS_CATEGORY_CODE(path)") |> should.be_true
  src
  |> string.contains("LISTING_PATHS = ['/urunler', '/products']")
  |> should.be_true
  // Ortak API
  src |> string.contains("function isActiveCategory(slug)") |> should.be_true
  src |> string.contains("function isActiveHref(href)") |> should.be_true
}

/// Betik sırası: `main.js` (NEXUS_NAV'ı tanımlar) `header-popovers.js`'ten
/// ÖNCE yürümeli — aksi halde masaüstü menü ortak predicate'i bulamaz.
///
/// Sıra metinsel değil YAPISALDIR: `main.js` `<head>` yardımcısından
/// (`chisfis_head`), `header-popovers.js` ise gövde sonundaki
/// `public_header_popovers_script()` çağrısından basılır. Bu yüzden erl
/// dosyasındaki ham konumlar yanıltıcıdır (gövde yardımcısının TANIMI
/// dosyanın başında durur); zincir çağrı yerleri üzerinden kurulur.
pub fn nav_source_load_order_test() {
  let erl = read_file(erl_path)
  erl |> string.is_empty |> should.be_false
  let head_def = index_of(erl, "chisfis_head() ->") |> result.unwrap(-1)
  let main_js = index_of(erl, "main.js?v=") |> result.unwrap(-1)
  let head_call = index_of(erl, "| chisfis_head()]") |> result.unwrap(-1)
  let popovers_def =
    index_of(erl, "public_header_popovers_script() ->") |> result.unwrap(-1)
  let popovers_js = index_of(erl, "header-popovers.js?v=") |> result.unwrap(-1)
  let popovers_call =
    index_of(erl, "public_header_popovers_script()]") |> result.unwrap(-1)
  // Tüm işaretler bulundu mu? (yol/isim kayarsa test sessizce geçmesin)
  list.all(
    [head_def, main_js, head_call, popovers_def, popovers_js, popovers_call],
    fn(i) { i >= 0 },
  )
  |> should.be_true
  // main.js <head> yardımcısının içinde tanımlı...
  { head_def < main_js } |> should.be_true
  // ...ve head çağrısı gövdedeki popover çağrısından önce gelir.
  { main_js < head_call } |> should.be_true
  { head_call < popovers_call } |> should.be_true
  { popovers_def < popovers_js } |> should.be_true
}

/// Çekmece tetikleyicisi ETİKETE bağlı olmamalı.
///
/// Sunucudan basılan hamburger etiketini sayfa diline göre çevirir
/// ("Ana menüyü aç" / "Hauptmenü öffnen" / …). Yalnız İngilizce "Open main
/// menu" metnine bakan eski seçim, İngilizce dışındaki her dilde çekmeceyi
/// hiç KURMUYORDU; bu yüzden yapısal iz (menü ikonu) de aranmalıdır.
pub fn drawer_trigger_is_language_independent_test() {
  let js = read_file(main_js_path)
  js |> string.contains("header .hgi-menu-01") |> should.be_true
  // Erken çıkış yedeklerden SONRA gelmeli (tek kapı).
  js |> count_occurrences("if (!burger) return;") |> should.equal(1)
  let before_bail =
    js
    |> string.split("if (!burger) return;")
    |> list.first
    |> result.unwrap("")
  before_bail |> string.contains("header .hgi-menu-01") |> should.be_true
  before_bail
  |> string.contains(".bnav-item[data-act=\"menu\"]")
  |> should.be_true
}

/// Metnin ilk geçtiği konum (graphem cinsinden); yoksa Error.
/// İki konum da aynı yöntemle ölçüldüğü için sıralama karşılaştırması geçerlidir.
fn index_of(haystack: String, needle: String) -> Result(Int, Nil) {
  case string.split(haystack, needle) {
    [before, ..] -> Ok(string.length(before))
    [] -> Error(Nil)
  }
}

/// Çekmece kendi kopyasını tutmamalı; ortak predicate'i çağırmalı.
pub fn drawer_uses_shared_nav_predicate_test() {
  let src = read_file(main_js_path)
  src
  |> string.contains("var hrefActive = window.NEXUS_NAV.isActiveHref;")
  |> should.be_true
  // Yerel kopyadan kalanlar silinmiş olmalı.
  src |> string.contains("var listCategory") |> should.be_false
  src |> string.contains("var onListing") |> should.be_false
  src |> string.contains("onListing && !!listCategory") |> should.be_false
}

/// Doğrudan link slug eşlemesi (Araçlar/Uçuşlar) korunmalı.
pub fn mobile_menu_direct_slug_mapping_test() {
  let src = read_file(main_js_path)
  src |> string.contains("DIRECT_SLUGS") |> should.be_true
  src |> string.contains("'/arac': 'car'") |> should.be_true
  src |> string.contains("'/ucus': 'flight'") |> should.be_true
  src |> string.contains("'/otobus': 'bus'") |> should.be_true
}

/// Aktif kategori vurgusu hem akordeon linklerine hem doğrudan linklere
/// uygulanabilmeli (paylaşılan sınıf + aria-current).
pub fn mobile_menu_active_class_applied_to_links_test() {
  let src = read_file(main_js_path)
  src |> string.contains("mm-acc-link-active") |> should.be_true
  src |> string.contains("aria-current=\"page\"") |> should.be_true
  let css = read_file(custom_css_path)
  // CSS tarafında her iki link tipi için de vurgu kuralı bulunmalı.
  css
  |> string.contains(".mm-acc-inner > a.mm-acc-link-active")
  |> should.be_true
  css |> string.contains(".mm-direct.mm-acc-link-active") |> should.be_true
}

/// Generic panel-link seçicisi `.mm-direct` bileşenini kapsam dışı bırakmalı.
///
/// Bu, "generic element seçicisi bileşeni eziyor" hata sınıfının regresyon
/// kapısıdır: yeni bir `.mobile-menu__panel > a...` kuralı `:not(.mm-direct)`
/// taşımıyorsa test kırılır.
pub fn panel_link_selector_excludes_direct_component_test() {
  let css = read_file(custom_css_path)
  let offenders =
    css
    |> css_rule_selectors()
    |> list.filter(fn(selector) {
      string.contains(selector, ".mobile-menu__panel > a")
      && !string.contains(selector, ":not(.mm-direct)")
    })
  offenders
  |> list.is_empty
  |> should.be_true
}

// ---------------------------------------------------------------------------
// Mobil alt bar (bnav) — aktif sayfa göstergesi
// ---------------------------------------------------------------------------

/// bnav öğeleri uygulamanın GERÇEK rotalarına bağlanmalı.
/// Şablon kalıntısı index.html / account.html bu uygulamada 404 verir.
pub fn bottom_bar_uses_real_routes_test() {
  let js = read_file(main_js_path)
  js |> string.contains("NAV_HREFS = { home: '/'") |> should.be_true
  js |> string.contains("account: '/hesap'") |> should.be_true
  // Yedek logo bağlantısı da 404'e gitmemeli.
  js
  |> string.contains("'<a class=\"mobile-menu__brand\" href=\"index.html\">")
  |> should.be_false
}

/// Aktif sayfa tespiti yol bazlı olmalı ve öğeye is-active + aria-current
/// bırakmalı (bnav'da eski davranış .html dosya adına bakıyordu ve hiçbir
/// gerçek rota eşleşmediği için gösterge hiç görünmüyordu).
pub fn bottom_bar_marks_active_page_test() {
  let js = read_file(main_js_path)
  js |> string.contains("routeActive") |> should.be_true
  js
  |> string.contains("'bnav-item' + (on ? ' is-active' : '')")
  |> should.be_true
  js |> string.contains("aria-current=\"page\"") |> should.be_true
  // Şablonun Tailwind kırmızısı yerine proje tokenları kullanılmalı.
  js |> string.contains("text-red-600 dark:text-red-500") |> should.be_false
}

/// Çekmece iki ayrı yoldan açılıyor (üst bar hamburger'ı + alt bar Menü
/// düğmesi); ikisi de alt bardaki göstergeyi senkronlamalı.
pub fn bottom_bar_menu_state_synced_test() {
  let js = read_file(main_js_path)
  js |> string.contains("function syncBnavMenu") |> should.be_true
  js |> string.contains("syncBnavMenu(open)") |> should.be_true
  js |> string.contains("syncBnavMenu(true)") |> should.be_true
}

/// Aktif gösterge stili tanımlı olmalı: primary renk + nokta işareti ve
/// iki tema varyantı.
pub fn bottom_bar_active_style_defined_test() {
  let css = read_file(bnav_css_path)
  css |> string.contains(".bnav-item.is-active") |> should.be_true
  css |> string.contains(".bnav-item.is-active::before") |> should.be_true
  css |> string.contains(".dark .bnav-item.is-active") |> should.be_true
}

// ---------------------------------------------------------------------------
// Masaüstü Keşfet popover'ı (.nc-pop__link)
// ---------------------------------------------------------------------------

/// Masaüstü menü kaynakları okunabilmeli.
pub fn header_popover_assets_readable_test() {
  read_file(header_js_path) |> string.is_empty |> should.be_false
  read_file(bridge_css_path) |> string.is_empty |> should.be_false
}

/// Keşfet popover'ı aktif sayfa vurgusunu üretmeli (sınıf + aria-current)
/// ve kararı ORTAK predicate'ten (window.NEXUS_NAV) almalı.
///
/// Masaüstü tarafı `/kategori/<slug>` sayfalarını da vurgular — bu, eskiden
/// yalnız sorgu filtresini bilen kopyanın kaçırdığı durumdur.
pub fn discover_popover_marks_active_link_test() {
  let js = read_file(header_js_path)
  js |> string.contains("nc-pop__link--active") |> should.be_true
  js |> string.contains("aria-current=\"page\"") |> should.be_true
  js |> string.contains("window.NEXUS_NAV") |> should.be_true
  js |> string.contains("nav.isActiveCategory(slug)") |> should.be_true
  js |> string.contains("discoverLinks") |> should.be_true
  // Kendi kopyası OLMAMALI: ayrışmanın kaynağı buydu.
  js |> string.contains("[?&]kategori=([^&]*)") |> should.be_false
  js |> string.contains("location.search") |> should.be_false
  // Vurgu stili köprüsünde tanımlı olmalı (iki tema için).
  let css = read_file(bridge_css_path)
  css |> string.contains(".nc-pop__link--active") |> should.be_true
  css |> string.contains("html.dark .nc-pop__link--active") |> should.be_true
}

/// Kanonik kategori regresyonu: villa artık geçerli kategori slug'ıdır;
/// eski holiday_home sadece geriye dönük alias olarak kalabilir.
///
/// Ayrıca paneller şablonun DEMO adreslerine değil mağaza rotalarına
/// gitmeli: `/car`, `/experiences`, `/flights`, `/real-estate`, `/account`,
/// `/register`, `/authors`, `/blog`, `/rezervasyon` bu uygulamada 404 verir
/// — menüde tıklanabilir görünüp hiçbir yere gitmeyen öğeler.
pub fn desktop_popover_targets_are_store_routes_test() {
  let js = read_file(header_js_path)
  js |> string.contains("'holiday_home'") |> should.be_true
  // Demo dönemi kalıntısı: hiçbir BAĞLANTI `.html` sayfasına gitmemeli
  // (`def.html` eski statik gövde alanıdır, o kalabilir — burada tırnaklı
  // href değeri aranır).
  js |> string.contains(".html\"") |> should.be_false

  let demo_paths = [
    "/car\"",
    "/experiences\"",
    "/flights\"",
    "/real-estate\"",
    "/account\"",
    "/register\"",
    "/authors\"",
    "/blog\"",
    "/rezervasyon\"",
  ]

  let leftovers =
    list.filter(demo_paths, fn(path) { string.contains(js, "href=\"" <> path) })

  case leftovers {
    [] -> Nil
    _ -> {
      let msg =
        "header panellerinde 404 veren demo adresi kaldı: "
        <> string.join(leftovers, " | ")
      msg |> should.equal("")
    }
  }
}

/// Masaüstü ve mobil kategori menüleri aynı kanonik kodları kısa URL
/// sözleşmesine vermeli; kategori sayfasına liste filtresi üzerinden gidilmez.
pub fn desktop_and_mobile_category_slugs_agree_test() {
  let mobile = read_file(main_js_path)
  let desktop = read_file(header_js_path)
  list.each(["hotel", "holiday_home", "yacht", "tour", "activity"], fn(code) {
    mobile |> string.contains("['" <> code <> "', '") |> should.be_true
    desktop |> string.contains("['" <> code <> "', 'hgi-") |> should.be_true
  })
  mobile |> string.contains("window.NEXUS_CATEGORY_URL") |> should.be_true
  desktop |> string.contains("window.NEXUS_CATEGORY_URL") |> should.be_true
  desktop |> string.contains("href=\"/urunler?kategori=") |> should.be_false
}

// ---------------------------------------------------------------------------
// Masaüstü popover hover mikro etkileşimi — mobil menüyle parite
// ---------------------------------------------------------------------------

/// Masaüstü header popover'larındaki hover mikro etkileşimi (ikon kayması +
/// zemin geçişi) mobil menüdeki karşılıklarıyla aynı dilde kalmalı.
///
/// Mobil referans (custom.css): `.mm-acc-inner > a:hover svg` ikonu primary
/// renge çevirir ve 3px kaydırır; `.mm-pop__opt:hover` zemini soldurup satırı
/// 2px kaydırır. Masaüstünde (bridge CSS) aynı mesafeler ve "hover yeteneği"
/// kapısı beklenir.
pub fn desktop_popover_hover_matches_mobile_test() {
  let mobile = read_file(custom_css_path)
  let desktop = read_file(bridge_css_path)

  // Mobil referans yerinde (silinirse parite testi anlamsızlaşır)
  mobile |> string.contains(".mm-acc-inner > a:hover svg {") |> should.be_true
  mobile |> string.contains(".mm-pop__opt:hover {") |> should.be_true

  // Masaüstü karşılığı: link ikonu 3px kayar
  desktop |> string.contains(".nc-pop__link i,") |> should.be_true
  desktop |> string.contains(".nc-pop__link:hover i,") |> should.be_true
  desktop |> string.contains(".nc-pop__link:hover svg {") |> should.be_true
  desktop |> string.contains("transform: translateX(3px);") |> should.be_true
  // Seçenek satırı 2px kayar (mobil `.mm-pop__opt` mesafesiyle aynı)
  desktop |> string.contains("transform: translateX(2px);") |> should.be_true
  // Kayma yalnız hover yetenekli cihazlarda uygulanır
  desktop |> string.contains("@media (hover: hover) {") |> should.be_true
}

/// Misafirler satırındaki kayma satırın İÇERİĞİNE verilmeli.
///
/// Panel çocukları açılışta `nc-stagger-in` animasyonunu `forwards` dolgusuyla
/// tutar; animasyon kaynaklı değerler normal bildirimleri ezdiği için satırın
/// kendisine yazılan bir `transform` hover'da hiç uygulanmaz (bu hata canlı
/// ölçümde yakalandı). Kural, hem normal hem `prefers-reduced-motion`
/// bloğunda bulunmalı → dosyada en az iki kez geçer.
pub fn popover_row_slide_targets_content_test() {
  let desktop = read_file(bridge_css_path)
  desktop |> string.contains(".nc-pop__row > * {") |> should.be_true
  desktop |> string.contains(".nc-pop__row:hover > * {") |> should.be_true
  // Satırın kendisinde hover transformu olmamalı
  desktop
  |> string.contains(".nc-pop__row:hover {\n    background")
  |> should.be_true
  // Hem temel geçiş hem reduced-motion karşılığı (en az iki kullanım)
  desktop
  |> count_occurrences(".nc-pop__row > * {")
  |> fn(n) { n >= 2 }
  |> should.be_true
  desktop
  |> count_occurrences(".nc-pop__row:hover > * {")
  |> fn(n) { n >= 2 }
  |> should.be_true
}

fn count_occurrences(src: String, needle: String) -> Int {
  src
  |> string.split(needle)
  |> list.length
  |> fn(n) { n - 1 }
}

/// `{` öncesi metni selector kabul eden kaba tarayıcı.
///
/// At-kuralları (`@media`, `@keyframes`, `@supports`) ve bildirim blokları
/// selector sayılmaz; yalnız `{` hemen öncesindeki metin döner.
fn css_rule_selectors(css: String) -> List(String) {
  css
  |> string.replace("}", "}\u{0}")
  |> string.split("\u{0}")
  |> list.filter_map(fn(chunk) {
    case string.split_once(chunk, "{") {
      Error(_) -> Error(Nil)
      Ok(#(before, _rest)) -> {
        let selector =
          before
          |> string.split("\n")
          |> list.last
          |> result.unwrap("")
          |> string.trim
        case selector {
          "" -> Error(Nil)
          _ ->
            case string.starts_with(selector, "@") {
              True -> Error(Nil)
              False -> Ok(selector)
            }
        }
      }
    }
  })
}
