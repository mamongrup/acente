//// Mağaza çeviri sözlüğü kapsam denetimi.
////
//// main.js'teki TR sözlüğü referans alınır: her TR anahtarının DE ve RU
//// sözlüklerinde de birebir bulunması gerekir. Eksik anahtar, çeviri
//// zincirinde o metnin EN'te kalmasına (fallback) yol açtığından regresyon
//// sayılır. Test, sözlük bloklarını kaynak üzerinden statik olarak tarar
//// — JS çalıştırmadan anahtar eşleşmesi doğrulanır.

import gleam/io
import gleam/list
import gleam/string
import gleeunit/should
import simplifile

const main_js_path = "priv/static/chisfis/js/main.js"

pub fn dict_parity_test() {
  let assert Ok(src) = simplifile.read(main_js_path)

  let assert Ok(tr_keys) = dict_keys(src, "TR")
  let assert Ok(de_keys) = dict_keys(src, "DE")
  let assert Ok(ru_keys) = dict_keys(src, "RU")

  // Her sözlük boş olmamalı (blok taranabilmeli)
  should.be_true(tr_keys != [])
  should.be_true(de_keys != [])
  should.be_true(ru_keys != [])

  let de_missing = list.filter(tr_keys, fn(k) { !list.contains(de_keys, k) })
  let ru_missing = list.filter(tr_keys, fn(k) { !list.contains(ru_keys, k) })

  case de_missing, ru_missing {
    [], [] -> Nil
    _, _ ->
      io.println(
        "Eksik çeviri anahtarları — TR'de olup DE'de yok: "
        <> string.join(de_missing, " | ")
        <> " — TR'de olup RU'da yok: "
        <> string.join(ru_missing, " | "),
      )
  }

  de_missing |> list.length |> should.equal(0)
  ru_missing |> list.length |> should.equal(0)
}

/// main.js kaynağından `var NAME = { ... };` sözlük bloğunun anahtarlarını
/// çıkarır. Anahtar biçimi: satır başında `'...'` (kaçışlı tırnak dahil)
/// ardından `:`. Değerler aynı biçimde olduğundan yalnız anahtar
/// konumundaki (satır başı) girdiler alınır.
fn dict_keys(src: String, name: String) -> Result(List(String), Nil) {
  let marker = "var " <> name <> " = {"
  case string.contains(src, marker) {
    False -> Error(Nil)
    True -> {
      let after_marker = drop_until(src, marker)
      let block = balanced_block(after_marker)
      let keys =
        block
        |> string.split("\n")
        |> list.filter_map(fn(line) {
          case string.trim(line) |> string.starts_with("'") {
            True ->
              case string.split_once(string.trim(line), "': ") {
                Ok(#(key, _)) ->
                  Ok(string.replace(key, "\\'", "'") |> string.drop_start(1))
                Error(Nil) -> Error(Nil)
              }
            False -> Error(Nil)
          }
        })
      Ok(keys)
    }
  }
}

fn drop_until(src: String, marker: String) -> String {
  case string.split_once(src, marker) {
    Ok(#(_, rest)) -> rest
    Error(Nil) -> ""
  }
}

/// Blok başlangıcındaki `{`'den itibaren dengeli süslü parantez aralığını
/// döndürür (kaçışlı tırnak içindeki parantezler sayılmaz — basitleştirilmiş
/// tarama sözlük değerlerinde `{}` içermediği için yeterlidir).
fn balanced_block(src: String) -> String {
  do_balanced(string.to_graphemes(src), 0, [])
}

fn do_balanced(chars: List(String), depth: Int, acc: List(String)) -> String {
  case chars, depth {
    [], _ -> string.concat(list.reverse(acc))
    ["{", ..rest], 0 -> do_balanced(rest, 1, ["{", ..acc])
    ["{", ..rest], d -> do_balanced(rest, d + 1, ["{", ..acc])
    ["}", ..], 1 -> string.concat(list.reverse(["}", ..acc]))
    ["}", ..rest], d -> do_balanced(rest, d - 1, ["}", ..acc])
    [c, ..rest], d -> do_balanced(rest, d, [c, ..acc])
  }
}
