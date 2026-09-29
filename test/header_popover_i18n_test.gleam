//// Masaüstü header popover çevirisi — statik regresyon testleri.
////
//// Önceki durum: `header-popovers.js` panel gövdelerini SABİT Türkçe metinle
//// kuruyordu ("Misafirler", "Keşfet", "Bildirimler", "Giriş yap" …). Sunucunun
//// SSR çeviri geçişi bu HTML'e dokunamaz (paneller tamamen istemcide üretilir),
//// bu yüzden İngilizce ya da Almanca gezerken popover içerikleri Türkçe
//// kalıyordu.
////
//// Sabitlenen sözleşmeler:
////
////   A) `header-popovers.js`te yorum dışı hiçbir satırda sabit Türkçe etiket
////      yok — her etiket `T(...)` ile seçili dilden basılır.
////   B) Kullanılan T() anahtarlarının TAMAMI TR/DE/RU sözlüklerinde bulunur;
////      eksik anahtar sessizce EN'e düşer (kısmi çeviri) ve bu regresyondur.
////   C) Paneller statik dize değil `render` fonksiyonuyla kurulur — statik dize
////      dille birlikte tazelenemez.
////   D) `nexus:lang` olayı panelleri yeniden basar (açık panel de tazelenir).
////   E) **Misafir sayacı header popover'ında DEĞİL**: seçim arama bölümüne
////      (hero formu) taşındı ve detay sayfasının rezervasyon panelinde
////      `public-guests.js` bağlar. Aynı sayıyı iki yerde tutmak iki sözleşme
////      demektir; header'da stepper durumu/delege dinleyicisi geri gelirse bu
////      kapı kırmızı olur. (Davranış sözleşmeleri: `hero_guests_test`)
////   F) Yer tutucu `%s`'tir; süslü parantez KULLANILMAZ — `dict_parity_test`
////      sözlük bloklarını dengeli parantez taramasıyla çıkarır, değerdeki `{}`
////      taramayı kaydırıp anahtar eşleşmesini bozar. Sayaç özeti/aria şablonları
////      (`%s Guests`, `Decrease %s`, `Increase %s`) artık arama formunun
////      bağlayıcısında (`main.js` §4) kullanılır.

import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const popovers_js_path = "priv/static/header-popovers.js"
const main_js_path = "priv/static/chisfis/js/main.js"

fn read_file(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

fn after(src: String, marker: String) -> String {
  case string.split_once(src, marker) {
    Ok(#(_, rest)) -> rest
    Error(_) -> ""
  }
}

fn until(src: String, stop: String) -> String {
  case string.split_once(src, stop) {
    Ok(#(before, _)) -> before
    Error(_) -> ""
  }
}

/// `marker` geçen her yerde `marker` ile `stop` arasındaki parçaları toplar.
fn occurrences(src: String, marker: String, stop: String) -> List(String) {
  do_occurrences(src, marker, stop, [])
}

fn do_occurrences(
  src: String,
  marker: String,
  stop: String,
  acc: List(String),
) -> List(String) {
  case string.split_once(src, marker) {
    Error(_) -> list.reverse(acc)
    Ok(#(_, rest)) -> {
      let piece = until(rest, stop)
      case piece {
        "" -> list.reverse(acc)
        _ -> do_occurrences(after(rest, stop), marker, stop, [piece, ..acc])
      }
    }
  }
}

/// Yorum satırlarını düşürür: kod içinde değil, yalnız açıklamada geçen
/// Türkçe kelimeler kapıyı kırmasın.
fn strip_comments(src: String) -> String {
  src
  |> string.split("\n")
  |> list.filter(fn(line) {
    let t = string.trim(line)
    !string.starts_with(t, "//")
    && !string.starts_with(t, "/*")
    && !string.starts_with(t, "*")
  })
  |> string.join("\n")
}

/// main.js içindeki `var NAME = { ... }` sözlük bloğu.
/// `stop_marker` bloğun sonunu belirleyen tam metindir: TR/DE/RU için
/// sıradaki sözlük başlığı, RU için sözlükleri izleyen açıklama satırı
/// (döngü/çeviri tablosu yorumu).
fn dict_block(src: String, name: String, stop_marker: String) -> String {
  src |> after("var " <> name <> " = {") |> until(stop_marker)
}

fn has_key(block: String, key: String) -> Bool {
  string.contains(block, "'" <> key <> "': ")
}

pub fn header_popover_sources_readable_test() {
  read_file(popovers_js_path) |> string.is_empty |> should.be_false
  read_file(main_js_path) |> string.is_empty |> should.be_false
}

// ---- A) Yorum dışı sabit Türkçe etiket yok ----

pub fn no_hardcoded_turkish_labels_test() {
  let source = read_file(popovers_js_path)
    |> until("/* Category landings use the shared hero")
    |> strip_comments
  // The new travel/mega menu carries explicit per-language copy, including
  // Turkish. Exclude only that locale dictionary, not the rendered templates.
  let menu_code = case string.split_once(source, "var MENU_COPY = {") {
    Ok(#(before, rest)) -> before <> after(rest, "function menuText(")
    Error(_) -> source
  }
  let code = case string.split_once(menu_code, "var CATALOG_COPY = {") {
    Ok(#(before, rest)) -> before <> after(rest, "function catalogMarkup(")
    Error(_) -> menu_code
  }

  // Panel gövdelerinde görünen Türkçe etiketlerin tamamı: biri geri gelirse
  // panel yine dile göre değişmez.
  let forbidden = [
    "Misafirler",
    "Keşfet",
    "Bildirimler",
    "Giriş yap",
    "Hesap oluştur",
    "Ev sahibi",
    "Yetişkin",
    "Çocuk",
    "Bebek",
    "Oteller",
    "Villalar",
    "Turlar",
    "Aktiviteler",
    // "azalt"/"artır" yalnız stepper aria etiketlerinde görünür; sayaç artık
    // bu dosyada olmadığı için (bkz. E) burada da listelenmez.
  ]

  let leftovers =
    list.filter(forbidden, fn(word) { string.contains(code, word) })

  case leftovers {
    [] -> Nil
    _ -> {
      let msg =
        "header-popovers.js'te sabit Türkçe etiket kaldı: "
        <> string.join(leftovers, " | ")
      msg |> should.equal("")
    }
  }
}

// ---- B) T() anahtarları üç sözlükte de var ----

pub fn every_t_key_exists_in_all_dicts_test() {
  let src = read_file(popovers_js_path)

  let literal_keys = occurrences(src, "T('", "'")

  // Ayıklama sessizce bozulursa (marker değişirse) boş liste döner ve tüm
  // kontroller boşa geçerdi — beklenen asgari sayı sabitlenir.
  // Panel gövdelerindeki T() anahtarları (Bildirimler/hesap paneli + para
  // birimi başlığı). Kategori/mega menü etiketleri henüz T() dışında; onlar
  // T() ile sarıldığında bu alt sınır yükseltilir.
  literal_keys |> list.length |> fn(n) { n >= 6 } |> should.be_true

  let dicts = read_file(main_js_path)
  let tr = dict_block(dicts, "TR", "var DE = {")
  let de = dict_block(dicts, "DE", "var RU = {")
  // RU bloğunun bitişi: sözlük seti TR/EN/DE/RU/FR/ZH'ye çıktığında araya
  // giren yorum satırı kalktı; sınır artık FR bloğunun başlangıcı.
  let ru = dict_block(dicts, "RU", "var FR = {")

  [tr, de, ru]
  |> list.each(fn(block) {
    block |> string.is_empty |> should.be_false
  })

  let missing_tr = list.filter(literal_keys, fn(k) { !has_key(tr, k) })
  let missing_de = list.filter(literal_keys, fn(k) { !has_key(de, k) })
  let missing_ru = list.filter(literal_keys, fn(k) { !has_key(ru, k) })

  // Başarısızlık çıktısında eksik anahtarların listesi görünsün: beklenen
  // değer bilerek boş dizeye karşılaştırılır (başarısızsa mesaj basılır).
  let report = fn(label: String, missing: List(String)) {
    case missing {
      [] -> Nil
      _ -> {
        let msg = label <> ": " <> string.join(missing, " | ")
        msg |> should.equal("")
      }
    }
  }
  report("TR eksik", missing_tr)
  report("DE eksik", missing_de)
  report("RU eksik", missing_ru)
}

// ---- C) Paneller render fonksiyonuyla kurulur ----

pub fn panels_render_as_functions_test() {
  let src = read_file(popovers_js_path)

  // Dört gövde üreten panel + sekmeli locale popover'ı (kendi içeriği var)
  src
  |> string.split("render: function () {")
  |> list.length
  |> fn(n) { n - 1 }
  |> should.equal(4)

  // Statik `html:` gövdesi kalmamalı: dille tazelenemez
  src |> string.contains("html: ") |> should.be_false
  src
  |> string.contains("pop.innerHTML = def.render ? def.render() : (def.html || '');")
  |> should.be_true
}

// ---- D) Dil değişiminde paneller tazelenir ----

pub fn panels_refresh_on_language_change_test() {
  let src = read_file(popovers_js_path)

  [
    "var REGISTRY = [];",
    "function refreshPanels() {",
    "entry.panel.innerHTML = entry.def.render();",
    "document.addEventListener('nexus:lang', refreshPanels);",
    // Kayıt, paneller kurulurken yapılır
    "REGISTRY.push({ btn: btn, panel: panel, def: PANELS[btnId] });",
  ]
  |> list.all(fn(needle) { string.contains(src, needle) })
  |> should.be_true

  // Sekmeli locale popover'ı kendi nexus:lang dinleyicisine sahip; onun
  // gövdesi render ile tazelenmez (çift tazeleme olmasın).
  src
  |> string.contains("if (!entry.def.render) return;")
  |> should.be_true
}

// ---- E) Misafir sayacı header'da değil ----

pub fn guests_counter_left_the_header_test() {
  let src = read_file(popovers_js_path) |> strip_comments

  // Eski sahipliğin kalıntıları: sayaç durumu, satır tanımları, delege
  // bağlayıcı, stepper markup'ı. Biri geri gelirse iki yüzey aynı sayıyı
  // ayrı ayrı tutar (ve header'da `guests` parametresi olmayan bir sayaç olur).
  let remnants = [
    "GUEST_STATE",
    "GUEST_ROWS",
    "guestRow",
    "nc-stepper",
    "data-guest=",
    "bindSteppers",
    "initSteppers",
    "'adults'",
    "'infants'",
  ]

  let leftovers = list.filter(remnants, fn(word) { string.contains(src, word) })

  case leftovers {
    [] -> Nil
    _ -> {
      let msg =
        "Misafir sayacı header popover'ında geri gelmiş: "
        <> string.join(leftovers, " | ")
      msg |> should.equal("")
    }
  }

  // Sayacın yeni sahibi işaret edilir: okuyan kişi nereye bakacağını bilsin.
  let notes = read_file(popovers_js_path)
  notes
  |> string.contains("hero")
  |> should.be_true
  notes
  |> string.contains("public-guests.js")
  |> should.be_true
}

// ---- F) Yer tutucu `%s`, süslü parantez yok ----

pub fn percent_placeholder_and_no_braces_test() {
  let dicts = read_file(main_js_path)
  let tr = dict_block(dicts, "TR", "var DE = {")
  let de = dict_block(dicts, "DE", "var RU = {")
  let ru = dict_block(dicts, "RU", "var FR = {")

  // Sayaç sözleşmesinin şablonları üç sözlükte de `%s` taşır:
  // özet etiketi ve stepper aria adları.
  let templates = ["%s Guests", "Decrease %s", "Increase %s"]

  [tr, de, ru]
  |> list.each(fn(block) {
    templates
    |> list.each(fn(key) {
      has_key(block, key) |> should.be_true
    })
    block |> string.contains("{label}") |> should.be_false
  })

  // Şablonlar parametreyi tek noktadan alır (süslü parantezli yer tutucu yok).
  let main = read_file(main_js_path)
  main
  |> string.contains("t(template).replace('%s', t(labelKey))")
  |> should.be_true
  main |> string.contains("{label}") |> should.be_false
}

// ---- Ek: ARIA etiketleri de çevrilir ----

pub fn aria_labels_are_translated_test() {
  let main = read_file(main_js_path)

  // "Yetişkin azalt" gibi aria etiketleri de sözlükten basılır: satır etiketi
  // `data-i18n` anahtarı üzerinden çevrilir, şablon da sözlükten gelir.
  [
    "guestNamed('Decrease %s', labelKey)",
    "guestNamed('Increase %s', labelKey)",
    "minus.setAttribute('aria-label'",
    "plus.setAttribute('aria-label'",
  ]
  |> list.all(fn(needle) { string.contains(main, needle) })
  |> should.be_true

  // Header popover'ında stepper aria şablonu kalmamalı (sayaç orada değil).
  let popovers = read_file(popovers_js_path)
  popovers
  |> string.contains("T('Decrease %s'")
  |> should.be_false
  popovers
  |> string.contains("T('Increase %s'")
  |> should.be_false
}
