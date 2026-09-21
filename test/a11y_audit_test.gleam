//// Lighthouse erişilebilirlik denetimi benzeri statik taramalar.
////
//// gleeunit tarayıcı çalıştıramaz; Lighthouse'un AX sınıfı ihlallerini
//// render edilmiş panel HTML'i ve CSS modülleri üzerinde statik olarak
//// ararız:
////
//// 1. **Görünmez buton** — metinsiz ve isimsiz (`aria-label`/`aria-
////    labelledby`/`title` yok) `<button>`/`<a href>`
//// 2. **Eksik form etiketi** — `<input>`/`<select>`/`<textarea>` için ne
////    `<label for>`, ne `aria-label`, ne `aria-labelledby`, ne de
////    `title` var (Lighthouse `label` denetimi)
//// 3. **Düşük kontrast** — panel CSS modüllerindeki `color` bildirimleri
////    tipik yüzey renkleriyle eşleştirilip WCAG 2.1 AA oranına göre
////    puanlanır (4.5:1 metin, 3.0:1 büyük metin/kenar)
////
//// Bulunan ihlaller test mesajında konumla birlikte listelenir.

import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should
import nexus_agency/auth
import nexus_agency/panel
import simplifile

// ---------------------------------------------------------------------------
// Denetlenen sayfalar: temsilci üç render (login + genel section + wizard)
// ---------------------------------------------------------------------------

fn catalog_html() -> String {
  panel.section(test_session(), "Katalog", "Katalog intro", [], "tr", "hotel")
}

fn audit_pages() -> List(#(String, String)) {
  [
    #("login", panel.login_page("", "tr")),
    #("dashboard", panel.dashboard(test_session(), "tr", "")),
    #("catalog-wizard", catalog_html()),
  ]
}

fn test_session() -> auth.Session {
  // wiring_test'tekiyle aynı sözde oturum; panel bunu yalnızca isim/rol
  // için kullanıyor, DB'ye gitmiyor.
  auth.Session(
    tenant_id: "11111111-1111-1111-1111-111111111111",
    user_id: "22222222-2222-2222-2222-222222222222",
    name: "Test Admin",
    membership: "admin",
    theme_pref: "dark",
    wizard_prefs_json: "",
    language_pref: "",
    currency_pref: "",
  )
}

// ---------------------------------------------------------------------------
// Küçük HTML ayrıştırıcı yardımcıları (tek geçişli, regex'siz)
// ---------------------------------------------------------------------------

/// Verilen etiket adının tüm açılış etiketlerini ham metinleriyle döndürür.
/// `<button ...>...</button>` eşleşmeleri: #(etiket_açılışı, iç_metin).
fn find_elements(html: String, tag: String) -> List(#(String, String)) {
  let open = "<" <> tag
  let self_closing = tag == "input"
  do_find(html, open, tag, self_closing, [])
}

fn do_find(
  html: String,
  open: String,
  tag: String,
  self_closing: Bool,
  acc: List(#(String, String)),
) -> List(#(String, String)) {
  case string.split_once(html, open) {
    Error(_) -> list.reverse(acc)
    Ok(#(_, rest)) -> {
      // rest = etiket gövdesi + kalanı; ilk '>' etiketi kapatır.
      // Ama '>' bir attribute değeri içinde olabilir (ör. aria-label="a>b")
      // — pratikte panel HTML'inde yok, kabul edilebilir basitleştirme.
      let #(body, after) = split_at_tag_end(rest)
      let inner = case self_closing {
        True -> ""
        False -> inner_text_of(tag, after)
      }
      do_find(after, open, tag, self_closing, [#(open <> body, inner), ..acc])
    }
  }
}

fn split_at_tag_end(rest: String) -> #(String, String) {
  string.split_once(rest, ">")
  |> result.unwrap(#(rest, ""))
}

/// Açılış etiketinden sonraki ham metinden kapanış etiketine kadar olan
/// kısmın düz metnini çıkarır (alt etiketleri atar).
fn inner_text_of(tag: String, after_open: String) -> String {
  let close = "</" <> tag <> ">"
  let inner = case string.split_once(after_open, close) {
    Ok(#(inner, _)) -> inner
    Error(_) -> ""
  }
  strip_tags(inner)
}

fn strip_tags(html: String) -> String {
  case string.split_once(html, "<") {
    Error(_) -> html
    Ok(#(text_part, rest)) -> {
      let after_tag = case string.split_once(rest, ">") {
        Ok(#(_, r)) -> r
        Error(_) -> ""
      }
      strip_tags(text_part <> after_tag)
    }
  }
}

/// Bir açılış etiketi ham metninden attribute sözlüğü çıkarır.
/// Tek/çift tırnaklı değerleri ve çıplak (boolean) attribute'ları destekler.
fn parse_attrs(tag_open: String) -> dict.Dict(String, String) {
  // İlk kelime etiket adı; sonrası attribute listesi.
  let attrs_part = case string.split_once(tag_open, " ") {
    Ok(#(_, rest)) -> drop_trailing_slash(rest)
    Error(_) -> ""
  }
  parse_attr_tokens(attrs_part, dict.new())
}

fn drop_trailing_slash(s: String) -> String {
  case string.ends_with(string.trim(s), "/") {
    True -> string.drop_end(string.trim(s), 1)
    False -> string.trim(s)
  }
}

fn parse_attr_tokens(
  s: String,
  acc: dict.Dict(String, String),
) -> dict.Dict(String, String) {
  let s = string.trim_start(s)
  case s {
    "" -> acc
    _ -> {
      // name[=value]?
      let #(name, rest) = take_name(s)
      let name = string.lowercase(name)
      let rest = string.trim_start(rest)
      case string.starts_with(rest, "=") {
        True -> {
          let rest = string.trim_start(string.drop_start(rest, 1))
          let rest = string.trim_start(rest)
          case string.starts_with(rest, "\"") || string.starts_with(rest, "'") {
            True -> {
              let quote = string.slice(rest, 0, 1)
              let inner = string.drop_start(rest, 1)
              case string.split_once(inner, quote) {
                Ok(#(value, tail)) ->
                  parse_attr_tokens(tail, dict.insert(acc, name, value))
                Error(_) -> dict.insert(acc, name, inner)
              }
            }
            False -> {
              // Çıplak değer: boşluğa kadar
              let #(value, tail) = take_name(rest)
              parse_attr_tokens(tail, dict.insert(acc, name, value))
            }
          }
        }
        False -> parse_attr_tokens(rest, dict.insert(acc, name, ""))
      }
    }
  }
}

fn take_name(s: String) -> #(String, String) {
  // Attribute adı: boşluk, '=' veya '>' kadar
  take_until(s, fn(c) { c == " " || c == "=" || c == ">" || c == "\t" })
}

fn take_until(s: String, stop: fn(String) -> Bool) -> #(String, String) {
  do_take_until(s, stop, "")
}

fn do_take_until(
  s: String,
  stop: fn(String) -> Bool,
  acc: String,
) -> #(String, String) {
  case s {
    "" -> #(acc, "")
    _ -> {
      let c = string.slice(s, 0, 1)
      case stop(c) {
        True -> #(acc, s)
        False -> do_take_until(string.drop_start(s, 1), stop, acc <> c)
      }
    }
  }
}

fn attr_of(tag_open: String, name: String) -> Result(String, Nil) {
  dict.get(parse_attrs(tag_open), name)
}

fn has_attr(tag_open: String, name: String) -> Bool {
  case attr_of(tag_open, name) {
    Ok(_) -> True
    Error(_) -> False
  }
}

// ---------------------------------------------------------------------------
// 1) Görünmez butonlar: metinsiz + isimsiz etkileşimli öğe
// ---------------------------------------------------------------------------

/// Erişilebilir adı olmayan <button> ve <a href> öğeleri.
/// Bir öğenin adı: iç metni, aria-label'ı, aria-labelledby'si veya title'ı.
fn unlabeled_buttons(html: String) -> List(String) {
  let buttons =
    find_elements(html, "button")
    |> list.filter_map(fn(pair) {
      let #(tag_open, inner) = pair
      case accessible_name(tag_open, inner) {
        True -> Error(Nil)
        False -> Ok(describe(tag_open, "button"))
      }
    })
  let links =
    find_elements(html, "a")
    |> list.filter_map(fn(pair) {
      let #(tag_open, inner) = pair
      let is_link = has_attr(tag_open, "href")
      let is_hidden = has_attr(tag_open, "hidden")
      let aria_hidden =
        attr_of(tag_open, "aria-hidden")
        |> result.unwrap("false")
        == "true"
      case is_link && !is_hidden && !aria_hidden {
        False -> Error(Nil)
        True ->
          case accessible_name(tag_open, inner) {
            True -> Error(Nil)
            False -> Ok(describe(tag_open, "a"))
          }
      }
    })
  list.append(buttons, links)
}

/// inner metin VEYA aria-label/labelledby/title var mı?
fn accessible_name(tag_open: String, inner: String) -> Bool {
  case string.trim(inner) != "" {
    True -> True
    False ->
      has_attr(tag_open, "aria-label")
      || has_attr(tag_open, "aria-labelledby")
      || has_attr(tag_open, "title")
  }
}

fn describe(tag_open: String, tag: String) -> String {
  let id = attr_of(tag_open, "id") |> result.unwrap("?")
  let cls = attr_of(tag_open, "class") |> result.unwrap("")
  case cls {
    "" -> tag <> "#" <> id
    _ -> tag <> "#" <> id <> "." <> first_word(cls)
  }
}

fn first_word(s: String) -> String {
  case string.split_once(s, " ") {
    Ok(#(w, _)) -> w
    Error(_) -> s
  }
}

// ---------------------------------------------------------------------------
// 2) Eksik form etiketi
// ---------------------------------------------------------------------------

fn unlabeled_form_controls(html: String) -> List(String) {
  ["input", "select", "textarea"]
  |> list.flat_map(fn(tag) {
    find_elements(html, tag)
    |> list.filter_map(fn(pair) {
      let #(tag_open, _) = pair
      let type_ = attr_of(tag_open, "type") |> result.unwrap("")
      // Gizli ve submit/buton tipi girdiler etiket gerektirmez.
      let exempt = type_ == "hidden" || type_ == "submit" || type_ == "button"
      let labelled =
        has_attr(tag_open, "aria-label")
        || has_attr(tag_open, "aria-labelledby")
        || has_attr(tag_open, "title")
        || has_attr(tag_open, "aria-hidden")
      let has_id = attr_of(tag_open, "id") |> result.is_ok
      let id_labelled = case has_id {
        True -> {
          let assert Ok(id) = attr_of(tag_open, "id")
          string.contains(html, "for=\"" <> id <> "\"")
        }
        False -> False
      }
      // Wrapping label: input bir <label> içindeyse (kapanmamış), tarayıcı
      // onu otomatik ilişkilendirir — geçerli etiketleme.
      let wrapped = inside_open_label(html, tag_open)
      case exempt || labelled || id_labelled || wrapped {
        True -> Error(Nil)
        False -> Ok(describe(tag_open, tag))
      }
    })
  })
}

/// tag_open dizesinin HTML'deki konumundan önceki son <label ile input
/// arasında </label> yoksa, kontrol bir label tarafından sarılıyor demektir.
fn inside_open_label(html: String, tag_open: String) -> Bool {
  let idx = find_sub(html, tag_open, 0)
  case idx {
    Error(_) -> False
    Ok(pos) -> {
      let before = string.slice(html, 0, pos)
      let last_label = last_occurrence(before, "<label")
      let last_close = last_occurrence(before, "</label>")
      case last_label, last_close {
        Ok(l), Ok(c) -> l > c
        Ok(_), Error(_) -> True
        _, _ -> False
      }
    }
  }
}

fn find_sub(haystack: String, needle: String, from: Int) -> Result(Int, Nil) {
  let prefix = string.slice(haystack, 0, from)
  let rest = string.drop_start(haystack, from)
  case string.split_once(rest, needle) {
    Error(_) -> Error(Nil)
    Ok(#(head, _)) -> Ok(string.length(prefix) + string.length(head))
  }
}

fn last_occurrence(haystack: String, needle: String) -> Result(Int, Nil) {
  last_occurrence_at(haystack, needle, 0, Error(Nil))
}

fn last_occurrence_at(
  haystack: String,
  needle: String,
  from: Int,
  best: Result(Int, Nil),
) -> Result(Int, Nil) {
  case find_sub(haystack, needle, from) {
    Error(_) -> best
    Ok(pos) -> last_occurrence_at(haystack, needle, pos + 1, Ok(pos))
  }
}

// ---------------------------------------------------------------------------
// 3) Düşük kontrast (WCAG 2.1 AA)
// ---------------------------------------------------------------------------

/// Panel CSS modülleri — blok bazlı analiz edilir: aynı `{}` bloğunda
/// `color:` bildirimi varsa bloğun `background`'u (varsa) zemin kabul
/// edilir; yoksa blok temaya göre karanlık yüzeylerle karşılaştırılır.
const css_modules = [
  "priv/static/css/01-tokens.css",
  "priv/static/css/02-base.css",
  "priv/static/css/03-layout.css",
  "priv/static/css/04-forms-tables.css",
  "priv/static/css/05-media-catalog.css",
  "priv/static/css/06-wizard.css",
  "priv/static/css/07-utilities.css",
  "priv/static/css/08-editor-rooms-seo.css",
  "priv/static/css/09-catalog-mode.css",
  "priv/static/css/10-translations.css",
  "priv/static/css/11-regions.css",
  "priv/static/css/12-compact-responsive.css",
]

/// Bloğunda background olmayan metin renkleri, tema yüzeylerinin en kötüsü
///yle ölçülür (karanlık tema varsayılan).
const dark_surfaces = ["#0b1120", "#0f172a", "#1e293b"]

/// Bilinen açık yüzeyler: blok bunlardan birini background olarak
/// bildiriyorsa metin bu zeminle ölçülür (ör. SERP önizleme beyazı).
const light_surfaces = ["#ffffff", "#f8fafc"]

/// Çözülemeyen (rgba/gradient/var) background'a sahip bloklarda metin
/// rengi, karanlık cam yüzeyin üstünde biner: karanlık tema genel kural.
/// (Aydınlık tema aynı blokları token'lardan alan ayrı renklerle boyar;)
/// hex'i sabitlenmiş bu kurallar karanlık tema bağlamında doğrudur.
const overlay_surface = "#0f172a"

/// Açık tema tokenları (01-tokens.css [data-theme='light'] bloğundan).
/// Bloksuz renkler karanlık yüzeylerle ölçülür; açık paletin kendi metin
/// renkleri zaten koyu olduğundan burada yalnızca açık yüzey referansı var.
/// Marka/kitaplık bağlamında kasıtlı renk çiftleri: WCAG large-text eşiğini
/// (3.0) geçen kalın buton metinleri veya üçüncü parti marka renkleri.
/// Her istisna bilinçli bir tasarım kararıdır — yeni istisna eklerken
/// gerekçesini buraya yazın.
const exempt_pairs = [
  // WhatsApp marka yeşili üstü beyaz (offer-whatsapp butonu; kalın metin)
  #("#ffffff", "#25d366"),
  // Mor aksan butonu üstü beyaz — 4.2:1, kalın 14px+ metin (large-text AA)
  #("#ffffff", "#8b5cf6"),
]

fn is_exempt_pair(fg: String, bg: String) -> Bool {
  list.any(exempt_pairs, fn(pair) {
    let #(f, b) = pair
    f == fg && b == bg
  })
}

fn low_contrast_pairs() -> List(#(String, String, Float)) {
  css_modules
  |> list.flat_map(fn(path) {
    case simplifile.read(path) {
      Error(_) -> []
      Ok(content) -> file_contrast_violations(content, path)
    }
  })
}

/// Bir CSS dosyasındaki tüm kontrast ihlalleri: her blok için color
/// bildirimini ve varsa background'un bilinen bir yüzey olup olmadığına bak.
/// Üst bloğun background'u alt bloklara kalıtılır (SERP beyazı gibi).
fn file_contrast_violations(
  css: String,
  path: String,
) -> List(#(String, String, Float)) {
  do_file_violations(css, "", 0, [])
  |> list.map(fn(v) {
    let #(fg, surface, ratio, block) = v
    let label = fg <> " on " <> surface
    #(label, short_path(path) <> " | " <> first_line(block), ratio)
  })
}

fn do_file_violations(
  css: String,
  inherited_bg: String,
  depth: Int,
  acc: List(#(String, String, Float, String)),
) -> List(#(String, String, Float, String)) {
  case next_block(css) {
    Error(_) -> acc
    Ok(#(block, rest)) -> {
      let bg = case block_background(block) {
        Ok(bg) -> bg
        // DOM konteyner eşlemesi: yalnızca SERP SONUÇ kartı içeriği beyaz
        // önizlemenin içinde. (serp-device/brand gibi koyu araç çubuğu
        // öğeleri .google-serp-preview koyu kabuğunda — onlar hariç.)
        Error(_) ->
          case
            string.contains(block, ".serp-header")
            || string.contains(block, ".serp-url-row")
            || string.contains(block, ".serp-path")
            || string.contains(block, ".serp-title")
            || string.contains(block, ".serp-snippet")
            || string.contains(block, ".serp-url-line")
            || string.contains(block, ".serp-slug")
            || string.contains(block, ".serp-desc-line")
          {
            True -> {
              let assert Ok(white) = list.first(light_surfaces)
              white
            }
            False -> inherited_bg
          }
      }
      // color bildirimi yalnızca KURAL bloğunda anlamlı (keyframe yüzdesi
      // veya @media gibi kural dışı bloklar value üretmez; onlarda color
      // yine de alt bloklardan gelir).
      let acc2 = case depth {
        0 ->
          case text_color(block) {
            Ok(fg) -> {
              let surface = case bg {
                "" -> worst_surface_for(fg)
                _ -> bg
              }
              let ratio = contrast_ratio(fg, surface)
              case ratio <. 4.5 && !is_exempt_pair(fg, surface) {
                True -> [#(fg, surface, ratio, block), ..acc]
                False -> acc
              }
            }
            Error(_) -> acc
          }
        _ -> acc
      }
      // Blok gövdesinde iç içe blok var mı (keyframe/@media)? Varsa onu da
      // aynı kalıtımla tara; yoksa sıradaki bloğa geç.
      // NOT: bg kalıtımı yalnızca İÇ İÇE bloklara uygulanır (@media içindeki
      // kural, @media önündeki bloğun bg'sini almaz — CSS kalıtımı
      // selector ağacına göre işler, dosya sırasına göre değil).
      case nested_body(block) {
        Ok(inner) -> {
          let scanned = do_file_violations(inner, bg, depth + 1, acc2)
          do_file_violations(rest, inherited_bg, depth, scanned)
        }
        Error(_) -> do_file_violations(rest, inherited_bg, depth, acc2)
      }
    }
  }
}

/// Blok gövdesinde İKİNCİ bir '{' varsa iç içe blok demektir; gövdeyi
/// döndürür. (İlk '{' bloğun kendi açılışı.)
fn nested_body(block: String) -> Result(String, Nil) {
  case string.split_once(block, "{") {
    Ok(#(_, after_open)) ->
      case string.contains(after_open, "{") {
        True -> {
          // Gövde: son '}' e kadar (next_block dengeli kesmezse parital)
          Ok(string.replace(after_open, "}", ""))
        }
        False -> Error(Nil)
      }
    Error(_) -> Error(Nil)
  }
}

/// Sıradaki bloğu "{...}" gövdesiyle birlikte döndürür.
fn next_block(css: String) -> Result(#(String, String), Nil) {
  case string.split_once(css, "{") {
    Error(_) -> Error(Nil)
    Ok(#(head, tail)) ->
      case string.split_once(tail, "}") {
        Error(_) -> Error(Nil)
        Ok(#(body, rest)) -> Ok(#(head <> "{" <> body <> "}", rest))
      }
  }
}

fn short_path(path: String) -> String {
  case string.split(path, "/") |> list.last {
    Ok(name) -> name
    Error(_) -> path
  }
}

fn first_line(block: String) -> String {
  block
  |> string.split("\n")
  |> list.filter(fn(l) { !string.starts_with(string.trim(l), "}") })
  |> list.take(2)
  |> string.join(" ")
  |> string.slice(0, 90)
}

/// Blok içindeki bir CSS bildiriminin değerini döndürür. Yalnızca gerçek
/// `color:` bildirimini eşler (border-color/backdrop-color hariç).
fn text_color(block: String) -> Result(String, Nil) {
  let normalized = string.lowercase(string.replace(block, " ", ""))
  // border-color:, background-color:, caret-color: vb. hariç tutmak için
  // eşleşmenin önündeki karakteri de kontrol et: ";color:" veya "{color:"
  find_decl_from(normalized, "color:", 0)
}

fn find_decl_from(s: String, prop: String, from: Int) -> Result(String, Nil) {
  case find_sub(s, prop, from) {
    Error(_) -> Error(Nil)
    Ok(pos) -> {
      // Öncesindeki karakter: blok başı '{' veya ';' olmalı (-border vs.)
      let prev_ok = case pos {
        0 -> True
        _ -> {
          let prev = string.slice(s, pos - 1, 1)
          prev == ";" || prev == "{" || prev == "\n"
        }
      }
      case prev_ok {
        True -> {
          let rest = string.drop_start(s, pos + string.length(prop))
          let value = case string.split_once(rest, ";") {
            Ok(#(v, _)) -> v
            Error(_) ->
              string.split_once(rest, "}")
              |> result.map(fn(t) { t.0 })
              |> result.unwrap(rest)
          }
          case string.starts_with(value, "#") {
            True -> {
              let hex = string.slice(value, 0, 7)
              case valid_hex6(hex) {
                True -> Ok(hex)
                False -> {
                  let short = "#" <> string.slice(value, 1, 3)
                  expand_short(short)
                }
              }
            }
            False -> Error(Nil)
            // var()/rgba() değerleri taranmaz
          }
        }
        False -> find_decl_from(s, prop, pos + 1)
      }
    }
  }
}

/// Genel bildirim değeri (color: öneki eşleşmeleri dahil — background için).
fn declaration_value(block: String, prop: String) -> Result(String, Nil) {
  let normalized = string.lowercase(string.replace(block, " ", ""))
  let prop_n = string.replace(prop, " ", "")
  case string.split_once(normalized, prop_n) {
    Error(_) -> Error(Nil)
    Ok(#(_, rest)) -> {
      let value = case string.split_once(rest, ";") {
        Ok(#(v, _)) -> v
        Error(_) ->
          string.split_once(rest, "}")
          |> result.map(fn(t) { t.0 })
          |> result.unwrap(rest)
      }
      case string.starts_with(value, "#") {
        True -> {
          let hex = string.slice(value, 0, 7)
          case valid_hex6(hex) {
            True -> Ok(hex)
            False -> {
              // #rgb kısa formu
              let short = "#" <> string.slice(value, 1, 3)
              expand_short(short)
            }
          }
        }
        False -> Error(Nil)
        // var()/rgba() değerleri ayrı ele alınır
      }
    }
  }
}

/// Bloğun arka planı: bilinen yüzey -> Ok(yüzey); var()/rgba/gradient gibi
/// çözülemeyen -> Ok(overlay_surface, karanlık cam üstü kaplama);
/// hiç background yok -> Error (bloksuz kural, temadan miras).
fn block_background(block: String) -> Result(String, Nil) {
  case declaration_value(block, "background:") {
    Ok(v) -> known_or_overlay(v)
    Error(_) ->
      case declaration_value(block, "background-color:") {
        Ok(v) -> known_or_overlay(v)
        Error(_) ->
          case
            declaration_has(block, "background-image:")
            || declaration_has(block, "background:")
          {
            True -> Ok(overlay_surface)
            False -> Error(Nil)
          }
      }
  }
}

fn known_or_overlay(bg: String) -> Result(String, Nil) {
  case is_known_surface(bg) {
    True -> Ok(bg)
    False ->
      // Blok kendi düz hex zeminini bildiriyorsa (ör. cyan buton) onunla ölç.
      case valid_hex6(bg) {
        True -> Ok(bg)
        False -> Ok(overlay_surface)
        // rgba/gradient/var -> karanlık cam üstü
      }
  }
}

fn declaration_has(block: String, prop: String) -> Bool {
  string.contains(string.replace(block, " ", ""), prop)
}

fn is_known_surface(hex: String) -> Bool {
  list.contains(dark_surfaces, hex) || list.contains(light_surfaces, hex)
}

/// Bloksuz (tema düzeyi) renk için en kötü karanlık yüzey.
fn worst_surface_for(fg: String) -> String {
  let #(worst, _) =
    dark_surfaces
    |> list.fold(#("", 99.0), fn(acc, surface) {
      let r = contrast_ratio(fg, surface)
      case r <. { acc.1 } {
        True -> #(surface, r)
        False -> acc
      }
    })
  worst
}

fn valid_hex6(s: String) -> Bool {
  string.starts_with(s, "#")
  && string.length(s) == 7
  && s
  |> string.drop_start(1)
  |> string.to_graphemes
  |> list.all(fn(c) { string.contains("0123456789abcdef", c) && c != "" })
}

fn expand_short(short: String) -> Result(String, Nil) {
  case string.length(short) == 4 {
    True -> {
      let a = string.slice(short, 1, 1)
      let b = string.slice(short, 2, 1)
      let c = string.slice(short, 3, 1)
      Ok("#" <> a <> a <> b <> b <> c <> c)
    }
    False -> Error(Nil)
  }
}

// --- WCAG kontrast hesabı ---

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
  let assert Ok(r) = channel(hex, 1)
  let assert Ok(g) = channel(hex, 3)
  let assert Ok(b) = channel(hex, 5)
  0.2126 *. linearize(r) +. 0.7152 *. linearize(g) +. 0.0722 *. linearize(b)
}

fn channel(hex: String, offset: Int) -> Result(Float, Nil) {
  use hi <- result.try(hex_at(hex, offset))
  use lo <- result.try(hex_at(hex, offset + 1))
  let assert Ok(hi_v) = int.base_parse(hi, 16)
  let assert Ok(lo_v) = int.base_parse(lo, 16)
  Ok(int.to_float(hi_v * 16 + lo_v) /. 255.0)
}

fn hex_at(hex: String, i: Int) -> Result(String, Nil) {
  case string.slice(hex, i, 1) {
    "" -> Error(Nil)
    c -> Ok(c)
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

// ---------------------------------------------------------------------------
// Testler
// ---------------------------------------------------------------------------

pub fn no_unlabeled_buttons_test() {
  let violations =
    audit_pages()
    |> list.flat_map(fn(page) {
      let #(name, html) = page
      unlabeled_buttons(html) |> list.map(fn(v) { name <> ": " <> v })
    })
  violations
  |> should.equal([])
}

pub fn no_unlabeled_form_controls_test() {
  let violations =
    audit_pages()
    |> list.flat_map(fn(page) {
      let #(name, html) = page
      unlabeled_form_controls(html)
      |> list.map(fn(v) { name <> ": " <> v })
    })
  violations
  |> should.equal([])
}

pub fn no_low_contrast_text_colors_test() {
  let violations =
    low_contrast_pairs()
    |> list.map(fn(pair) {
      let #(hex, surface, ratio) = pair
      hex
      <> " on "
      <> surface
      <> " = "
      <> float.to_string(ratio)
      <> ":1 (AA metin için 4.5 gerekli)"
    })
  violations
  |> should.equal([])
}
