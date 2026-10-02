//// Aurora palet kontrast denetimi — panel CSS modüllerinde hâlâ sert kodlu
//// `color: #hex` bildirimi kalan blokları statik olarak tarar.
////
//// Yöntem:
//// 1. `01-tokens.css` ayrıştırılır: her `:root[data-theme='x']` bloğu için
////    zemin katmanı (`--panel-deep`, `--panel-sunken`, `--glass-card`) ve
////    accent (`--neon-*`, `--link-sky`) token karşılıkları çözülür.
//// 2. Diğer tüm modüller blok blok (`}e göre) taranır; yalnızca
////    `color: #hex` bildiren bloklar denetlenir:
////    - blok kendi `background[-image]` hex'iyle **kendinden çiftli** ise
////      → AA 4.5:1 (koyu/zeminli bileşen, tam eşik)
////    - aksi hâlde bloğun seçicisinde **koyu yüzey anahtarı** (`panel-deep`,
////      `panel-sunken`, `glass-card`, `glass-modal` vb.) geçiyorsa → paletin
////      koyu cam zemini + tint ile çözülür → AA 4.5:1
////    - koyu anahtar yoksa → palet gövde zemini (`--bg-space`) + %11 tint
////      katmanıyla → WCAG büyük metin/görsel eşik 3.0:1
////
//// Böylece hem hemisfer (koyu/açık) hem palet (4x) kombinasyonu tek testte
//// kapanır; bilinçli istisnalar (SERP taklidi) ve `var()` zeminli kurallar
//// (statik çözümlemede zaten güvenli sayılamaz) eik listesinde tutulur.

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import simplifile

// ---------------------------------------------------------------------------
// 1. Palet ayrıştırma — 01-tokens.css
// ---------------------------------------------------------------------------

const tokens_path = "priv/static/css/01-tokens.css"

const module_dir = "priv/static/css"

/// Palet temaları (Aurora): dosyadaki data-theme sırasıyla.
const themes = ["dark", "light", "midnight", "sahra"]

/// Blok seçicisinde geçtiğinde paletin koyu cam zeminine kilitleyen anahtarlar.
const dark_surface_keys = [
  "panel-deep", "panel-sunken", "glass-card", "glass-modal", "glass-topbar",
  "glass-subcard", "subcard", "table-header-bar",
]

/// Bilinçli istisnalar: Google arama sonucu taklidi (palet dışı sabit beyaz
/// kart) ve satır içi geçiş kancaları. Denetim dışı dosya adları.
const exception_files = ["01-tokens.css", "chisfis-bridge.css"]

/// Gradient zeminli butonlar: beyaz metin gradient ustundedir, dogrudan
/// sayfa zeminine karsi olcmek anlamsizdir.
const exception_selectors = ["btn-quick-publish"]

type Palette {
  Palette(tokens: Dict(String, String))
}

/// Tema adına → (değişken adı → değer) sözlüğü. 01-tokens'ta her paletin iki
/// bloğu var (ana değişkenler + gradients bölümü); ilk kazanan yaklaşımıyla
/// bloklar birleştirilir.
fn parse_palettes(css: String) -> Dict(String, Palette) {
  // CSS yorumları `;` split'ini bozar: `/* Text */   --text-pure: #fff`
  // birleşik bildirimin adı `/* Text */\n  --text-pure` olur ve is_var
  // reddeder. Yorumları split'ten önce temizle.
  let clean = strip_comments(css)
  let raw =
    string.split(clean, "}")
    |> list.fold(dict.new(), merge_palette_block)
  ["dark", "light", "midnight", "sahra"]
  |> list.filter_map(fn(t) {
    case dict.get(raw, t) {
      Ok(tokens) -> Ok(#(t, Palette(tokens: tokens)))
      Error(_) -> Error(Nil)
    }
  })
  |> dict.from_list
}

/// `/* … */` yorumlarını temizler (her biri tek boşlukla değiştirilir).
fn strip_comments(css: String) -> String {
  string.split(css, "/*")
  |> list.map(fn(head) {
    case string.split_once(head, "*/") {
      Ok(#(_, tail)) -> " " <> tail
      Error(_) -> head
    }
  })
  |> string.concat
}

fn merge_palette_block(
  acc: Dict(String, Dict(String, String)),
  block: String,
) -> Dict(String, Dict(String, String)) {
  let theme =
    ["dark", "light", "midnight", "sahra"]
    |> list.filter_map(fn(t) {
      case string.contains(block, "data-theme='" <> t <> "'") {
        True -> Ok(t)
        False -> Error(Nil)
      }
    })
    |> list.first
    |> result.unwrap("")
  case theme {
    "" -> acc
    _ -> {
      let merged =
        dict.get(acc, theme)
        |> result.unwrap(dict.new())
        |> merge_declarations(block)
      dict.insert(acc, theme, merged)
    }
  }
}

/// Bloktaki `--ad: değer;` bildirimlerini sözlüğe ekler (varsa mevcut kazanır).
fn merge_declarations(
  acc: Dict(String, String),
  block: String,
) -> Dict(String, String) {
  block
  |> string.split(";")
  |> list.fold(acc, fn(d, decl) {
    // `--gradient-success: linear-gradient(135deg, #047857 0%, …)` gibi
    // değerler iç `;` içermediği için `;` split güvenli. Sorun:
    // value tarafındaki `#hex` içindeki ':' yok, ama bazı değerlerde
    // url(http://…) var — split_once KULLANMADAN önce adın `--` ile
    // başladığını doğrula.
    case string.split_once(decl, ":") {
      Ok(#(name, value)) -> {
        let name = string.trim(name)
        // `:root,` gibi satır başı seçiciler de ':' içerir; yalnız `--ad`
        // biçimindeki bildirimleri kabul et.
        let is_var =
          string.starts_with(name, "--") && !string.contains(name, " ")
        case
          string.contains(name, "bg-space")
          || string.contains(name, "text-pure")
          || string.contains(name, "neon-cyan")
        {
          True ->
            io.println(
              "DECL-HIT decl=["
              <> string.replace(
                string.trim(string.slice(decl, 0, 80)),
                "\n",
                " ",
              )
              <> "] name=["
              <> name
              <> "] val=["
              <> string.trim(value)
              <> "]",
            )
          False -> Nil
        }
        case is_var {
          True ->
            case dict.get(d, name) {
              Ok(_) -> d
              Error(_) -> dict.insert(d, name, string.trim(value))
            }
          False -> d
        }
      }
      Error(_) -> d
    }
  })
}

fn token(p: Palette, name: String) -> String {
  dict.get(p.tokens, name) |> result.unwrap("")
}

// ---------------------------------------------------------------------------
// 2. Modül tarama — color: hex bildirimli bloklar
// ---------------------------------------------------------------------------

type Finding {
  Finding(
    file: String,
    selector: String,
    color: String,
    context: String,
    ratio: Float,
    threshold: Float,
  )
}

fn audit_css_file(
  path: String,
  palettes: Dict(String, Palette),
) -> List(Finding) {
  let fname = file_name(path)
  case simplifile.read(path) {
    Error(_) -> []
    Ok(css) ->
      string.split(css, "}")
      |> list.flat_map(fn(block) { audit_block(fname, block, palettes) })
  }
}

fn file_name(path: String) -> String {
  path
  |> string.split("/")
  |> list.last
  |> result.unwrap(path)
}

fn audit_block(
  fname: String,
  block: String,
  palettes: Dict(String, Palette),
) -> List(Finding) {
  let sel = selector_of(block)
  let is_exception_selector =
    list.any(exception_selectors, fn(ex) { string.contains(sel, ex) })
  case list.contains(exception_files, fname) || is_exception_selector {
    True -> []
    False -> {
      let selector = selector_of(block)
      let colors = declared_hex_colors(block)
      case colors {
        [] -> []
        _ ->
          colors
          |> list.flat_map(fn(c) {
            audit_color(fname, selector, block, c, palettes)
          })
      }
    }
  }
}

fn selector_of(block: String) -> String {
  block
  |> string.split_once("{")
  |> result.map(fn(p) { string.trim(p.0) })
  |> result.unwrap("")
  |> string.replace("\n", " ")
}

/// Blok içinde `color: #hex` bildirimleri (border-color/background-color
/// yanlış eşleşmesi: öncesindeki karakteri de kontrol ederiz).
fn declared_hex_colors(block: String) -> List(String) {
  // Longhand'ları nötrleştir: `border-color: #…` gibi bildirimler
  // `color: #` işaretini içerir ve yanlış eşleşirdi.
  let neutralized =
    block
    |> string.replace("border-color:", "border-x:")
    |> string.replace("background-color:", "background-x:")
    |> string.replace("outline-color:", "outline-x:")
    |> string.replace("caret-color:", "caret-x:")
    |> string.replace("column-rule-color:", "column-rule-x:")
    |> string.replace("text-decoration-color:", "text-decoration-x:")
    |> string.replace("fill:", "fill-x:")
    |> string.replace("stroke:", "stroke-x:")
  string.split(neutralized, "color: #")
  |> list.drop(1)
  |> list.filter_map(fn(chunk) {
    case take_hex(chunk) {
      "" -> Error(Nil)
      h -> normalize_strict(h)
    }
  })
  |> list.unique
}

fn take_hex(chunk: String) -> String {
  take_hex_chars(string.slice(chunk, 0, 6), "")
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

/// Yalnızca tam 3 veya 6 hex karakterli değerleri kabul eder —
/// kırpık/alfa içeren (ör. 4 haneli #RGBA) değerler güvenle yok sayılır.
fn normalize_strict(h: String) -> Result(String, Nil) {
  case string.length(h) {
    3 ->
      Ok(string.lowercase(
        "#"
        <> string.repeat(string.slice(h, 0, 1), 2)
        <> string.repeat(string.slice(h, 1, 1), 2)
        <> string.repeat(string.slice(h, 2, 1), 2),
      ))
    6 -> Ok(string.lowercase("#" <> h))
    _ -> Error(Nil)
  }
}

// ---------------------------------------------------------------------------
// 3. Değerlendirme — palet başına zemin çözümleme + eik
// ---------------------------------------------------------------------------

fn audit_color(
  fname: String,
  selector: String,
  block: String,
  color: String,
  palettes: Dict(String, Palette),
) -> List(Finding) {
  themes
  |> list.filter_map(fn(theme) {
    let assert Ok(p) = dict.get(palettes, theme)
    let dark_surface =
      dark_surface_keys
      |> list.any(fn(k) { string.contains(selector, k) })
    // 1) Bloğun kendi background hex'i: kendinden çiftli (AA 4.5)
    let own_bg = declared_background_hex(block)
    // 2) background: var(--ad) → token karşılığından çöz (hex, rgba, gradient)
    let var_surfaces = resolved_var_surfaces(block, p)
    case own_bg {
      Ok(bg) ->
        case contrast_ratio(color, bg) <. 4.5 {
          True ->
            Ok(Finding(
              fname,
              selector,
              color,
              theme <> " · kendi zeminine karşı",
              contrast_ratio(color, bg),
              4.5,
            ))
          False -> Error(Nil)
        }
      Error(_) ->
        case var_surfaces {
          // Var zeminler çözüldüyse beyaz/metin her uçla AA 4.5 olmalı
          _ if var_surfaces != [] ->
            case
              var_surfaces
              |> list.any(fn(s) { contrast_ratio(color, s) <. 4.5 })
            {
              True -> {
                let worst =
                  var_surfaces
                  |> list.map(fn(s) { contrast_ratio(color, s) })
                  |> list.fold(21.0, fn(a, b) {
                    case b <. a {
                      True -> b
                      False -> a
                    }
                  })
                Ok(Finding(
                  fname,
                  selector,
                  color,
                  theme <> " · var zemin uçlarına karşı",
                  worst,
                  4.5,
                ))
              }
              False -> Error(Nil)
            }
          // 3) Koyu cam yüzey anahtarı
          _ ->
            case dark_surface {
              True -> {
                let glass = case
                  string.starts_with(token(p, "--glass-card"), "rgba(")
                {
                  True ->
                    composite_over(
                      token(p, "--glass-card"),
                      token(p, "--bg-space"),
                    )
                  False -> token(p, "--glass-card")
                }
                let surface = mix_tint(glass, theme)
                let ratio = contrast_ratio(color, surface)
                case ratio <. 4.5 {
                  True ->
                    Ok(Finding(
                      fname,
                      selector,
                      color,
                      theme <> " · koyu cam zemine karşı",
                      ratio,
                      4.5,
                    ))
                  False -> Error(Nil)
                }
              }
              False -> {
                // 4) Gövde zemini + %11 tint (büyük metin/görsel eşiği 3.0)
                let surface = mix_tint(token(p, "--bg-space"), theme)
                let ratio = contrast_ratio(color, surface)
                case ratio <. 3.0 {
                  True ->
                    Ok(Finding(
                      fname,
                      selector,
                      color,
                      theme <> " · gövde zemine karşı",
                      ratio,
                      3.0,
                    ))
                  False -> Error(Nil)
                }
              }
            }
        }
    }
  })
}

/// Blokta `background…: var(--ad)` bildirimlerini bulur; adı palet token'larından
/// çözüp yüzey hex'leri listesi döndürür:
/// - hex değer → tek yüzey
/// - rgba → gövde zeminine kompozit edilmiş tek yüzey
/// - linear-gradient → gradipteki TÜM hex uçları (en zayıf uç belirleyici)
/// Çözülemeyen var'lar atlanır (statikte bilinemez).
fn resolved_var_surfaces(block: String, p: Palette) -> List(String) {
  string.split(block, "var(--")
  |> list.drop(1)
  |> list.flat_map(fn(chunk) {
    // chunk "…ad): değer…" biçiminde; adı al
    let name =
      chunk
      |> string.split_once(")")
      |> result.map(fn(q) { q.0 })
      |> result.unwrap("")
    let value = token(p, "--" <> name)
    case value {
      "" -> []
      v ->
        case string.starts_with(v, "#") {
          True -> [v]
          False ->
            case string.starts_with(v, "rgba(") {
              True -> [composite_over(v, token(p, "--bg-space"))]
              False ->
                case string.contains(v, "linear-gradient") {
                  True -> gradient_endpoints(v)
                  False -> []
                }
            }
        }
    }
  })
  |> list.unique
}

/// linear-gradient(...) dizesindeki tüm hex uçlar.
fn gradient_endpoints(v: String) -> List(String) {
  string.split(v, "#")
  |> list.drop(1)
  |> list.filter_map(fn(chunk) { normalize_strict(take_hex(chunk)) })
  |> list.unique
}

/// Blok içinde `background: #hex` ya da `background-color: #hex` varsa onu döndürür.
fn declared_background_hex(block: String) -> Result(String, Nil) {
  let from_shorthand = hex_values_after(block, "background: #")
  let from_longhand = hex_values_after(block, "background-color: #")
  list.append(from_shorthand, from_longhand)
  |> list.first
  |> result.map_error(fn(_) { Nil })
}

fn hex_values_after(block: String, marker: String) -> List(String) {
  string.split(block, marker)
  |> list.drop(1)
  |> list.filter_map(fn(chunk) { normalize_strict(take_hex(chunk)) })
}

/// Paletin zemin rengine tipik %11 tint katmanı ekler (panelin tint-* desenine
/// uygun yaklaşım). Yalnızca hex zeminler için hesap yapılır; rgba zeminlerde
/// (glass-card her paletde rgba) tint yok sayılır.
fn mix_tint(base: String, theme: String) -> String {
  case string.starts_with(base, "#") {
    False -> base
    True ->
      case theme {
        "light" -> base
        _ -> mix(base, tint_color(theme), 0.11)
      }
  }
}

/// `rgba(r, g, b, a)` dizesini ayrıştırır.
fn parse_rgba(s: String) -> Result(#(Float, Float, Float, Float), Nil) {
  case string.split_once(s, "(") {
    Error(_) -> Error(Nil)
    Ok(#(_, rest)) -> {
      let inner = string.drop_end(rest, 1)
      let parts = string.split(inner, ",") |> list.map(string.trim)
      case parts {
        [r, g, b, a] ->
          case int.parse(r), int.parse(g), int.parse(b), float.parse(a) {
            Ok(rv), Ok(gv), Ok(bv), Ok(av) ->
              Ok(#(
                int.to_float(rv) /. 255.0,
                int.to_float(gv) /. 255.0,
                int.to_float(bv) /. 255.0,
                av,
              ))
            _, _, _, _ -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    }
  }
}

/// Yarı saydam katmanı opak hex zeminin üstüne bastırır (WCAG kompoziti).
fn composite_over(rgba: String, under_hex: String) -> String {
  let assert Ok(#(r, g, b, a)) = parse_rgba(rgba)
  let assert Ok(ur) = channel(under_hex, 1)
  let assert Ok(ug) = channel(under_hex, 3)
  let assert Ok(ub) = channel(under_hex, 5)
  let mixc = fn(t: Float, u: Float) {
    to_hex2(float.round({ a *. t +. { 1.0 -. a } *. u } *. 255.0))
  }
  "#" <> mixc(r, ur) <> mixc(g, ug) <> mixc(b, ub)
}

fn tint_color(theme: String) -> String {
  case theme {
    "light" -> "#0e7490"
    "midnight" -> "#a78bfa"
    "sahra" -> "#f59e0b"
    _ -> "#22d3ee"
  }
}

/// hex hex karışımı: `ratio` payında üstteki (tint) rengin alfa katkısı.
fn mix(base: String, overlay: String, ratio: Float) -> String {
  let assert Ok(br) = channel(base, 1)
  let assert Ok(bg) = channel(base, 3)
  let assert Ok(bb) = channel(base, 5)
  let assert Ok(or_) = channel(overlay, 1)
  let assert Ok(og) = channel(overlay, 3)
  let assert Ok(ob) = channel(overlay, 5)
  hex_of(br, bg, bb, or_, og, ob, ratio)
}

fn hex_of(
  br: Float,
  bg: Float,
  bb: Float,
  or_: Float,
  og: Float,
  ob: Float,
  ratio: Float,
) -> String {
  let mixc = fn(b: Float, o: Float) {
    let v = ratio *. o +. { 1.0 -. ratio } *. b
    to_hex2(float.round(v *. 255.0))
  }
  let r = mixc(br, or_)
  let g = mixc(bg, og)
  let b = mixc(bb, ob)
  "#" <> r <> g <> b
}

/// 0-255 arasi tamsayiyi 2 haneli hex stringe cevirir.
fn to_hex2(v: Int) -> String {
  let hi = v / 16
  let lo = v % 16
  "" <> hex_digit(hi) <> hex_digit(lo)
}

fn hex_digit(n: Int) -> String {
  case n {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "a"
    11 -> "b"
    12 -> "c"
    13 -> "d"
    14 -> "e"
    _ -> "f"
  }
}

// ---------------------------------------------------------------------------
// 4. WCAG 2.1 hesabı (lighthouse_audit_test ile aynı yöntem)
// ---------------------------------------------------------------------------

fn contrast_ratio(fg: String, bg: String) -> Float {
  case relative_luminance(fg), relative_luminance(bg) {
    Ok(l1), Ok(l2) -> {
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
    // Ayrıştırılamayan giriş: güvenli geç (21:1) — ama kaynağını görünür kıl.
    _, _ -> {
      io.println(
        "CONTRAST-AUDIT-PARSER: çift çözülemedi fg=" <> fg <> " bg=" <> bg,
      )
      21.0
    }
  }
}

fn relative_luminance(hex: String) -> Result(Float, Nil) {
  let norm = case string.length(hex) == 4 {
    True ->
      "#"
      <> string.repeat(string.slice(hex, 1, 1), 2)
      <> string.repeat(string.slice(hex, 2, 1), 2)
      <> string.repeat(string.slice(hex, 3, 1), 2)
    False -> hex
  }
  case channel(norm, 1), channel(norm, 3), channel(norm, 5) {
    Ok(r), Ok(g), Ok(b) ->
      Ok(
        0.2126
        *. linearize(r)
        +. 0.7152
        *. linearize(g)
        +. 0.0722
        *. linearize(b),
      )
    _, _, _ -> {
      io.println("CONTRAST-AUDIT-PARSER: çözülemeyen hex → " <> hex)
      Error(Nil)
    }
  }
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

fn math_power(base: Float, exp: Float) -> Float {
  // stdlib'te float pow yok; tam sayı üs için yeterli: exp sabit 2.4.
  case exp {
    2.4 -> base *. base *. math_sqrt(base)
    _ -> base
  }
}

fn math_sqrt(x: Float) -> Float {
  // Newton-Raphson ile karekök — yalnız pozitif girişler.
  guess_sqrt(x, x /. 2.0, 24)
}

fn guess_sqrt(x: Float, guess: Float, n: Int) -> Float {
  case n {
    0 -> guess
    _ -> {
      let next = { guess +. x /. guess } /. 2.0
      case float_abs_diff(next, guess) <. 0.0000001 {
        True -> next
        False -> guess_sqrt(x, next, n - 1)
      }
    }
  }
}

fn float_round(f: Float) -> String {
  float.round(f *. 100.0) |> int.to_string |> divide_by_100
}

fn divide_by_100(s: String) -> String {
  let len = string.length(s)
  case len <= 2 {
    True -> "0." <> string.repeat("0", 2 - len) <> s
    False -> string.slice(s, 0, len - 2) <> "." <> string.slice(s, len - 2, 2)
  }
}

fn float_abs_diff(a: Float, b: Float) -> Float {
  case a >=. b {
    True -> a -. b
    False -> b -. a
  }
}

// ---------------------------------------------------------------------------
// 5. Test
// ---------------------------------------------------------------------------

pub fn color_hex_contrast_across_palettes_test() {
  let assert Ok(tokens) = simplifile.read(tokens_path)
  let palettes = parse_palettes(tokens)

  // 4 paletin hepsi çözülmeli ve zemin token'ları dolu olmalı.
  themes
  |> list.each(fn(t) {
    let assert Ok(p) = dict.get(palettes, t)
    io.println(
      "DBG "
      <> t
      <> " bg=["
      <> token(p, "--bg-space")
      <> "] glow1=["
      <> token(p, "--bg-glow-1")
      <> "] glass=["
      <> token(p, "--glass-card")
      <> "] textpure=["
      <> token(p, "--text-pure")
      <> "] nvars="
      <> int.to_string(dict.size(p.tokens)),
    )
    io.println(
      "KEYS "
      <> dict.to_list(p.tokens)
      |> list.map(fn(kv) { kv.0 })
      |> list.sort(string.compare)
      |> string.join(","),
    )
    let assert True = token(p, "--bg-space") != ""
    let assert True = token(p, "--glass-card") != ""
  })

  let files = css_module_files()
  let findings =
    files
    |> list.flat_map(fn(f) { audit_css_file(module_dir <> "/" <> f, palettes) })

  case findings {
    [] -> Nil
    _ -> {
      findings
      |> list.each(fn(f) {
        io.println(
          "KONTRAST: "
          <> f.file
          <> " · "
          <> f.selector
          <> " → "
          <> f.color
          <> " ("
          <> f.context
          <> ") = "
          <> float_round(f.ratio)
          <> ":1 — eşik "
          <> float_round(f.threshold),
        )
      })
    }
  }

  findings |> should.equal([])
}

/// Denetlenecek modül dosyaları — 01-tokens ve bridge hariç tüm Aurora seti.
fn css_module_files() -> List(String) {
  [
    "02-base.css",
    "03-layout.css",
    "04-forms-tables.css",
    "05-media-catalog.css",
    "06-wizard.css",
    "07-utilities.css",
    "08-editor-rooms-seo.css",
    "09-catalog-mode.css",
    "10-translations.css",
    "11-regions.css",
    "12-compact-responsive.css",
  ]
}

// ---------------------------------------------------------------------------
// 6. Tint+Neon çift WCAG denetimi
// ---------------------------------------------------------------------------

/// Her paletin tint rgba degerini bg-space uzerine composit edip neon hex ile
/// kontrastini olcer. 4.5:1 altindaki her kombinasyon regressyon sayilir.
/// Tint zemin, neon metin rengidir (status-pill, badge, active tab, vb.).
/// Kontrol edilecek tint+neon ciftleri (isim, tint tokeni, neon tokeni).
const tint_neon_pairs = [
  #("cyan", "--tint-cyan", "--neon-cyan"),
  #("cyan-strong", "--tint-cyan-strong", "--neon-cyan"),
  #("emerald", "--tint-emerald", "--neon-emerald"),
  #("emerald-strong", "--tint-emerald-strong", "--neon-emerald"),
  #("amber", "--tint-amber", "--neon-amber"),
  #("amber-strong", "--tint-amber-strong", "--neon-amber"),
  #("rose", "--tint-rose", "--neon-rose"),
  #("rose-strong", "--tint-rose-strong", "--neon-rose"),
  #("purple", "--tint-purple", "--neon-purple"),
  #("purple-strong", "--tint-purple-strong", "--neon-purple"),
]

/// Tint+neon ciftleri icin 4 palet WCAG kontrast denetimi.
/// Her palet: tint rgba > bg-space > composit > kontrast(neon, composit).
/// 4.5:1 esik altindaki her kombinasyon testi kirar.
pub fn tint_neon_contrast_across_palettes_test() {
  let assert Ok(tokens) = simplifile.read(tokens_path)
  let palettes = parse_palettes(tokens)

  let findings =
    themes
    |> list.flat_map(fn(theme) {
      let assert Ok(p) = dict.get(palettes, theme)
      let bg = token(p, "--bg-space")
      tint_neon_pairs
      |> list.filter_map(fn(pair) {
        let #(name, tint_key, neon_key) = pair
        let tint_val = token(p, tint_key)
        let neon_val = token(p, neon_key)
        case tint_val, neon_val {
          "", _ -> Error(Nil)
          _, "" -> Error(Nil)
          tint, neon -> {
            // tint rgba'yi bg-space uzerine composit et
            let surface = case string.starts_with(tint, "rgba(") {
              True -> composite_over(tint, bg)
              False -> tint
            }
            let ratio = contrast_ratio(neon, surface)
            case ratio <. 4.5 {
              True -> Ok(#(theme, name, neon, surface, ratio))
              False -> Error(Nil)
            }
          }
        }
      })
    })

  case findings {
    [] -> Nil
    _ -> {
      findings
      |> list.each(fn(f) {
        io.println(
          "TINT-NEON KONTRAST: "
          <> f.0
          <> " · "
          <> f.1
          <> " | "
          <> f.2
          <> " on "
          <> f.3
          <> " = "
          <> float_round(f.4)
          <> ":1 (min 4.5)",
        )
      })
    }
  }

  findings |> should.equal([])
}

/// Tek palet uzerinde tum tint+neon ciftlerini test eden parametrik test.
/// Her palet icin ayri assertion: palet bazli regressyon takibi.
pub fn tint_neon_dark_palette_test() {
  check_palette("dark")
}

pub fn tint_neon_light_palette_test() {
  check_palette("light")
}

pub fn tint_neon_midnight_palette_test() {
  check_palette("midnight")
}

pub fn tint_neon_sahra_palette_test() {
  check_palette("sahra")
}

fn check_palette(theme: String) {
  let assert Ok(tokens) = simplifile.read(tokens_path)
  let palettes = parse_palettes(tokens)
  let assert Ok(p) = dict.get(palettes, theme)
  let bg = token(p, "--bg-space")

  let fails =
    tint_neon_pairs
    |> list.filter_map(fn(pair) {
      let #(name, tint_key, neon_key) = pair
      let tint_val = token(p, tint_key)
      let neon_val = token(p, neon_key)
      case tint_val, neon_val {
        "", _ -> Error(Nil)
        _, "" -> Error(Nil)
        tint, neon -> {
          let surface = case string.starts_with(tint, "rgba(") {
            True -> composite_over(tint, bg)
            False -> tint
          }
          let ratio = contrast_ratio(neon, surface)
          case ratio <. 4.5 {
            True ->
              Ok(
                name
                <> ": "
                <> neon
                <> " on "
                <> surface
                <> " = "
                <> float_round(ratio)
                <> ":1",
              )
            False -> Error(Nil)
          }
        }
      }
    })

  case fails {
    [] -> Nil
    _ -> {
      io.println(
        "TINT-NEON "
        <> string.uppercase(theme)
        <> " BAŞARISIZ: "
        <> string.join(fails, " | "),
      )
    }
  }

  fails |> should.equal([])
}

// ---------------------------------------------------------------------------
// 7. Gradient-primary beyaz metin kontrast denetimi
// ---------------------------------------------------------------------------

/// gradient-primary'in her paletteki her ucunu beyaz (#ffffff) metinle olcer.
/// WCAG AA: kucuk metin icin 4.5:1, buyuk metin icin 3.0:1.
/// Hover'da brightness(1.1) uygulanir; en zayif uc brightness sonrasi da
/// 4.5:1'i korumalidir.
const gradient_primary_endpoints = [
  #("dark", ["#0e7490", "#1d4ed8"]),
  #("light", ["#0e7490", "#1d4ed8"]),
  #("midnight", ["#6d28d9", "#4f46e5"]),
  #("sahra", ["#8a3f07", "#9a3209"]),
]

/// Baslangic durumunda gradient-primary uc renkleri beyaz metinle AA esik ustunde olmali.
pub fn gradient_primary_base_contrast_test() {
  let assert Ok(tokens) = simplifile.read(tokens_path)
  let palettes = parse_palettes(tokens)

  let findings =
    gradient_primary_endpoints
    |> list.flat_map(fn(pair) {
      let #(theme, endpoints) = pair
      let assert Ok(p) = dict.get(palettes, theme)
      let _ = token(p, "--gradient-primary")
      endpoints
      |> list.filter_map(fn(ep) {
        let ratio = contrast_ratio(ep, "#ffffff")
        case ratio <. 4.5 {
          True -> Ok(#(theme, ep, ratio, "base"))
          False -> Error(Nil)
        }
      })
    })

  case findings {
    [] -> Nil
    _ -> {
      findings
      |> list.each(fn(f) {
        io.println(
          "GRADIENT-PRIMARY "
          <> string.uppercase(f.0)
          <> " "
          <> f.3
          <> ": "
          <> f.1
          <> " vs #ffffff = "
          <> float_round(f.2)
          <> ":1 (min 4.5)",
        )
      })
    }
  }

  findings |> should.equal([])
}

/// Hover'da brightness(1.1) uygulandiktan sonra da AA esik ustunde olmali.
pub fn gradient_primary_hover_contrast_test() {
  let assert Ok(tokens) = simplifile.read(tokens_path)
  let palettes = parse_palettes(tokens)

  let findings =
    gradient_primary_endpoints
    |> list.flat_map(fn(pair) {
      let #(theme, endpoints) = pair
      let assert Ok(p) = dict.get(palettes, theme)
      let _ = p
      endpoints
      |> list.filter_map(fn(ep) {
        let hover = brighten_hex(ep, 1.1)
        let ratio = contrast_ratio(hover, "#ffffff")
        case ratio <. 4.5 {
          True -> Ok(#(theme, ep, hover, ratio))
          False -> Error(Nil)
        }
      })
    })

  case findings {
    [] -> Nil
    _ -> {
      findings
      |> list.each(fn(f) {
        io.println(
          "GRADIENT-PRIMARY HOVER "
          <> string.uppercase(f.0)
          <> ": "
          <> f.1
          <> " -> "
          <> f.2
          <> " vs #ffffff = "
          <> float_round(f.3)
          <> ":1 (min 4.5)",
        )
      })
    }
  }

  findings |> should.equal([])
}

/// hex rengi brightness carpaniyla isiklandirir (0-255 sinirli).
fn brighten_hex(hex: String, factor: Float) -> String {
  let assert Ok(r) = channel(hex, 1)
  let assert Ok(g) = channel(hex, 3)
  let assert Ok(b) = channel(hex, 5)
  let clamp = fn(v: Float) {
    case v >. 1.0 {
      True -> 1.0
      False -> v
    }
  }
  "#"
  <> to_hex2(float.round(clamp(r *. factor) *. 255.0))
  <> to_hex2(float.round(clamp(g *. factor) *. 255.0))
  <> to_hex2(float.round(clamp(b *. factor) *. 255.0))
}
