//// Lighthouse tarzı ön yüz denetimi — gleeunit tarayıcı çalıştıramadığı için
//// Lighthouse "accessibility / best-practices" sınıfı ihlalleri, router
//// üzerinden render edilen gerçek halka açık HTML'ler üzerinde statik aranır:
////
//// 1. **Başlık hiyerarşisi** (Lighthouse `heading-order`):
////    h1 önce gelmeli; başlık düzeyleri birer birer atlamadan inmeli.
//// 2. **Performans uyarıları**:
////    - `render-blocking-resources`: `<head>` içinde defer/async'siz `<script src>`
////    - `uses-responsive-images` (CLS): `<img>` etiketleri width/height/loading/
////      decoding özniteliklerinden en az birini taşımali
////    - stylesheet sayısı 8'i aşmamali (bağlantı tasarrufu üst sınırı)
////    - satır içi `<style>` bloğu 4 KB'yi asmamali
//// 3. **Kontrast** (`color-contrast`): chisfis-bridge.css kural bloklarında
////    bildirilen sabit renk çiftleri WCAG 2.1 eşılerine göre puanlanır:
////    - aynı blokta color+background hex'i varsa gerçek çift → 4.5:1 (AA)
////    - yalnız color'lı bloklar temaya göre sayfa zeminine karşı → 3:1
////      (html.dark blokları koyu zeminle, diğerleri açık zeminle)
////
//// Bulgular test mesajında sayfa/selector + ölçüm ile listelenir.

import gleam/erlang/process
import gleam/float
import gleam/http
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import nexus_agency/router
import pog
import simplifile
import wisp/simulate

const origin = "http://localhost:8082"

fn fake_db() -> pog.Connection {
  pog.named_connection(process.new_name("lighthouse_audit_db"))
}

fn get_html(path: String) -> String {
  simulate.browser_request(http.Get, path)
  |> router.handle(fake_db(), origin)
  |> simulate.read_body
}

/// Denetlenen halka açık sayfalar: #(ad, HTML). Tümü DB'siz render edilir.
fn audit_pages() -> List(#(String, String)) {
  let detail =
    "/urunler/6381a4d4-af56-4263-b2d1-b274da897487?tenant=ca43626b-4d77-41d8-898c-317576e991b5"
  [
    #("home", get_html("/")),
    #("iletisim", get_html("/iletisim")),
    #("urunler", get_html("/urunler")),
    #("ilan-detay", get_html(detail)),
  ]
}

// ---------------------------------------------------------------------------
// 1. Başlık hiyerarşisi (heading-order)
// ---------------------------------------------------------------------------

pub fn heading_order_test() {
  audit_pages()
  |> list.flat_map(fn(page) {
    let #(name, html) = page
    let msg = heading_violations(html)
    case msg {
      "" -> []
      _ -> [#(name <> ": " <> msg)]
    }
  })
  |> should.equal([])
}

/// `<h1..h6>` etiket düzeylerini belgedeki sırayla döndürür.
///
/// Tarama `string.split("<h")` üzerinden yürür (doğrusal). Önceki sürüm
/// belgeyi karakter karakter `string.slice(html, i, 2)` ile geziyordu;
/// `slice` grapheme tabanlı olduğu için her adım dizenin başını yeniden
/// sayıyor ve ana sayfa şablonun export'ına (231 KB) geçilince O(n²) tarama
/// testi zaman aşımına sürükleyip **tüm suite'i iptal ettiriyordu**.
/// Aynı etiketleri aynı sırayla bulur, maliyeti tek geçiştir.
fn heading_levels(html: String) -> List(Int) {
  html
  |> string.split("<h")
  |> list.drop(1)
  |> list.filter_map(fn(rest) {
    case string.first(rest) {
      Ok("1") -> Ok(1)
      Ok("2") -> Ok(2)
      Ok("3") -> Ok(3)
      Ok("4") -> Ok(4)
      Ok("5") -> Ok(5)
      Ok("6") -> Ok(6)
      _ -> Error(Nil)
    }
  })
}

fn heading_violations(html: String) -> String {
  case heading_levels(html) {
    [] -> ""
    [first, ..rest] ->
      case first > 1 {
        True ->
          "sayfa h1 ile başlamıyor (ilk başlık h" <> int.to_string(first) <> ")"
        False -> check_step(rest, first, "")
      }
  }
}

fn check_step(rest: List(Int), prev: Int, acc: String) -> String {
  case rest {
    [] -> acc
    [lvl, ..more] -> {
      let acc = case lvl > prev + 1 {
        True ->
          acc
          <> "h"
          <> int.to_string(prev)
          <> " sonrası h"
          <> int.to_string(lvl)
          <> " atlaması; "
        False -> acc
      }
      check_step(more, lvl, acc)
    }
  }
}

// ---------------------------------------------------------------------------
// 2. Performans uyarıları (statik karşılıklar)
// ---------------------------------------------------------------------------

pub fn no_render_blocking_scripts_in_head_test() {
  audit_pages()
  |> list.flat_map(fn(page) {
    let #(name, html) = page
    case head_scripts_without_defer(html) {
      [] -> []
      vs -> [
        #(name <> ": defer'siz head scripti → " <> string.join(vs, ", ")),
      ]
    }
  })
  |> should.equal([])
}

/// `<head>...</head>` içindeki defer/async taşmayan `<script src>`'ler.
fn head_scripts_without_defer(html: String) -> List(String) {
  case string.split_once(html, "</head>") {
    Error(_) -> []
    Ok(#(head, _)) -> scripts_without_defer(head)
  }
}

fn scripts_without_defer(section: String) -> List(String) {
  string.split(section, "<script")
  |> list.drop(1)
  |> list.filter_map(fn(chunk) {
    case string.contains(chunk, " src=") {
      True ->
        case
          string.contains(chunk, "defer") || string.contains(chunk, "async")
        {
          True -> Error(Nil)
          False -> {
            // İki boot script'i kasıtlı olarak render-blocking'tir (FOUC önleme):
            //   theme-boot.js  → stylesheet'lerden önce data-theme'i ayarlar
            //   reveal-boot.js → scroll-reveal gizli durumunu ilk boyamadan
            //                    önce işaretler; `defer` ile gelseydi sayfa bir
            //                    an görünüp gizlenirdi.
            let src =
              chunk
              |> string.split_once("src=\"")
              |> result.try(fn(pair) {
                let #(_, after) = pair
                string.split_once(after, "\"")
                |> result.map(fn(p2) { p2.0 })
              })
              |> result.unwrap("?")
            // Boot script'leri kasıtlı render-blocking (FOUC önleme)
            case
              string.contains(src, "theme-boot.js")
              || string.contains(src, "reveal-boot.js")
            {
              True -> Error(Nil)
              False -> Ok(src)
            }
          }
        }
      False -> Error(Nil)
    }
  })
}

pub fn stylesheet_count_within_budget_test() {
  audit_pages()
  |> list.flat_map(fn(page) {
    let #(name, html) = page
    case string.split_once(html, "</head>") {
      Error(_) -> []
      Ok(#(head, _)) -> {
        let count =
          string.split(head, "rel=\"stylesheet\"")
          |> list.length
          |> fn(n) { n - 1 }
        case count > 8 {
          True -> [
            #(
              name
              <> ": "
              <> int.to_string(count)
              <> " stylesheet (üst sınır 8) — birleştirme gerekli",
            ),
          ]
          False -> []
        }
      }
    }
  })
  |> should.equal([])
}

pub fn body_images_lazy_or_sized_test() {
  audit_pages()
  |> list.flat_map(fn(page) {
    let #(name, html) = page
    // Sunucu HTML'indeki <img> etiketleri CLS önleme için width/height/
    // loading/decoding özniteliklerinden en az birini taşımali.
    let imgs = raw_tags(html, "<img")
    imgs
    |> list.filter(fn(tag) {
      !string.contains(tag, "width=")
      && !string.contains(tag, "height=")
      && !string.contains(tag, "loading=")
      && !string.contains(tag, "decoding=")
    })
    |> list.map(fn(tag) {
      name <> ": boyut/başrol özniteliksiz <img> → " <> first_n(tag, 90)
    })
  })
  |> should.equal([])
}

pub fn inline_style_block_budget_test() {
  audit_pages()
  |> list.flat_map(fn(page) {
    let #(name, html) = page
    inline_style_bytes(html)
    |> list.filter_map(fn(size) {
      case size > 4096 {
        True -> Ok(size)
        False -> Error(Nil)
      }
    })
    |> list.map(fn(size) {
      name
      <> ": satır içi <style> bloğu "
      <> int.to_string(size)
      <> " bayt (4 KB üstü) — CSS dosyasına taşınmalı"
    })
  })
  |> should.equal([])
}

fn inline_style_bytes(html: String) -> List(Int) {
  string.split(html, "<style")
  |> list.drop(1)
  |> list.map(fn(chunk) {
    case string.split_once(chunk, "</style>") {
      Ok(#(body, _)) -> string.length(body)
      Error(_) -> 0
    }
  })
}

// ---------------------------------------------------------------------------
// 3. Kontrast — chisfis-bridge.css sabit renk çiftleri (WCAG 2.1)
// ---------------------------------------------------------------------------

fn audited_css_files() -> List(#(String, String)) {
  [#("chisfis-bridge.css", read_static("priv/static/chisfis-bridge.css"))]
}

fn read_static(path: String) -> String {
  case simplifile.read(path) {
    Ok(content) -> content
    Error(_) -> ""
  }
}

pub fn no_low_contrast_declared_pairs_test() {
  audited_css_files()
  |> list.flat_map(fn(file) {
    let #(name, css) = file
    low_contrast_in_css(css)
    |> list.map(fn(v) { name <> ": " <> v })
  })
  |> should.equal([])
}

/// İki denetim katmanı (yanlış-pozitifleri önlemek için bağlam farkındalıklı):
///
/// 1. **Kendinden çiftli kurallar** — aynı blokta hem `color` hem `background`
///    hex olarak bildirilmişse çift gerçekten doğrulanabilirdir: AA 4.5:1.
/// 2. **Sayfa yüzeyi çiftleri** — yalnızca `color` bildiren bloklar, temaya göre
///    sayfa zeminine karşı puanlanır (light → white, `html.dark` → neutral-900).
///    Ancak rengi başka bir blokta `background` ile birlikte bildirilen
///    (bağlamı bileşen zeminine kilitli) hex'ler bu katmanda atlanır —
///    statik çözümleme ata zincirini bilemez; bunları raporlamak sahte
///    pozitif olurdu.
fn low_contrast_in_css(css: String) -> List(String) {
  let blocks = string.split(css, "}")
  let pinned =
    blocks
    |> list.filter(fn(b) { string.contains(b, "background") })
    |> list.flat_map(declared_colors)
  blocks
  |> list.flat_map(fn(block) {
    let selector =
      block
      |> string.split_once("{")
      |> result.map(fn(p) { p.0 })
      |> result.unwrap("")
    let colors = declared_colors(block)
    let backgrounds = declared_backgrounds(block)
    let dark = string.contains(block, "html.dark")
    let page_surface = case dark {
      True -> "#111827"
      False -> "#ffffff"
    }
    // 1) kendinden çiftli: color × background (ikisi de hex)
    let self_pairs =
      colors
      |> list.flat_map(fn(c) {
        backgrounds
        |> list.filter_map(fn(b) {
          let ratio = contrast_ratio(c, b)
          case ratio <. 4.5 {
            True ->
              Ok(
                selector
                <> " → "
                <> c
                <> " üstünde "
                <> b
                <> " = "
                <> float_round(ratio)
                <> ":1 (AA 4.5)",
              )
            False -> Error(Nil)
          }
        })
      })
    // 2) sayfa yüzeyi: yalnız color'lı bloklar, bağlam-kilitli renkler hariç
    let surface_pairs = case backgrounds {
      [] ->
        colors
        |> list.filter(fn(c) { !list.contains(pinned, c) })
        |> list.filter_map(fn(c) {
          let ratio = contrast_ratio(c, page_surface)
          case ratio <. 3.0 {
            True ->
              Ok(
                selector
                <> " → "
                <> c
                <> " vs sayfa "
                <> page_surface
                <> " = "
                <> float_round(ratio)
                <> ":1",
              )
            False -> Error(Nil)
          }
        })
      _ -> []
    }
    list.append(self_pairs, surface_pairs)
  })
  |> list.unique
}

/// Bir blok içindeki `background[-color]: #hex` bildirimleri.
/// Yalnızca komşu biçimle eşleşir; `border-color: #…` yanlış eşleşmesini
/// ve `var()` zeminleri saymaz.
fn declared_backgrounds(block: String) -> List(String) {
  let from_shorthand = hex_values_after(block, "background: #")
  let from_longhand = hex_values_after(block, "background-color: #")
  list.append(from_shorthand, from_longhand)
  |> list.unique
}

fn hex_values_after(block: String, marker: String) -> List(String) {
  string.split(block, marker)
  |> list.drop(1)
  |> list.filter_map(fn(chunk) {
    let normalized = take_hex_chars(string.slice(chunk, 0, 6), "")
    case string.length(normalized) {
      6 -> Ok(string.lowercase("#" <> normalized))
      3 -> Ok(string.lowercase("#" <> normalized))
      _ -> Error(Nil)
    }
  })
}

/// CSS içinde `color: #xxx;` / `color: #xxxxxx;` bildirimlerini toplar.
/// `border-color` ve `background-color` yanlış eşleşmelerini eler.
fn declared_colors(css: String) -> List(String) {
  css
  |> string.replace("border-color: #", "bc: #")
  |> string.replace("border-color:#", "bc:#")
  |> string.replace("background-color: #", "bgc: #")
  |> string.replace("background-color:#", "bgc:#")
  |> string.replace("outline-color: #", "oc: #")
  |> string.split("color: #")
  |> list.drop(1)
  |> list.filter_map(fn(chunk) {
    let normalized = take_hex_chars(string.slice(chunk, 0, 6), "")
    case string.length(normalized) {
      6 -> Ok(string.lowercase("#" <> normalized))
      3 -> Ok(string.lowercase("#" <> normalized))
      _ -> Error(Nil)
    }
  })
  |> list.unique
}

fn take_hex_chars(s: String, acc: String) -> String {
  case string.length(acc) >= 6 || s == "" {
    True -> acc
    False -> {
      let c = string.slice(s, 0, 1)
      case string.contains("0123456789abcdefABCDEF", c) && c != "" {
        True -> take_hex_chars(string.drop_start(s, 1), acc <> c)
        False -> acc
      }
    }
  }
}

// --- WCAG 2.1 hesabı (a11y_audit_test ile aynı yöntem) ---

fn contrast_ratio(fg: String, bg: String) -> Float {
  let l1 = relative_luminance(fg)
  let l2 = relative_luminance(bg)
  let lighter = case l1 >. l2 {
    True -> l1
    False -> l2
  }
  let darker = case l1 >. l2 {
    True -> l2
    False -> l1
  }
  let denom = lighter +. 0.05
  case denom == 0.0 {
    True -> 21.0
    False -> denom /. { darker +. 0.05 }
  }
}

fn relative_luminance(hex: String) -> Float {
  // Kısa form (#fff) 6 karaktere genişletilir.
  let norm = case string.length(hex) == 4 {
    True ->
      "#"
      <> string.repeat(string.slice(hex, 1, 1), 2)
      <> string.repeat(string.slice(hex, 2, 1), 2)
      <> string.repeat(string.slice(hex, 3, 1), 2)
    False -> hex
  }
  let assert Ok(r) = channel(norm, 1)
  let assert Ok(g) = channel(norm, 3)
  let assert Ok(b) = channel(norm, 5)
  0.2126 *. linearize(r) +. 0.7152 *. linearize(g) +. 0.0722 *. linearize(b)
}

fn channel(hex: String, offset: Int) -> Result(Float, Nil) {
  case string.slice(hex, offset, 2) {
    "" -> Error(Nil)
    s ->
      case int.base_parse(s, 16) {
        Ok(v) -> Ok(int.to_float(v) /. 255.0)
        Error(_) -> Error(Nil)
      }
  }
}

fn linearize(c: Float) -> Float {
  case c <=. 0.03928 {
    True -> c /. 12.92
    False -> math_power({ c +. 0.055 } /. 1.055, 2.4)
  }
}

@external(erlang, "math", "pow")
fn math_power(base: Float, exp: Float) -> Float

fn float_round(f: Float) -> String {
  float.to_string(f) |> string.slice(0, 4)
}

// --- yardımcılar ---

fn raw_tags(html: String, needle: String) -> List(String) {
  string.split(html, needle)
  |> list.drop(1)
}

fn first_n(s: String, n: Int) -> String {
  string.slice(s, 0, n)
}
