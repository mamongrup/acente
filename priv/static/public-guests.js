/**
 * public-guests.js — Misafir seçici (yetişkin / çocuk / bebek stepper'ı)
 *
 * `.chisfis-guest-range` bileşenini bağlar. Bileşen sunucuda İKİ yerde
 * basılır: detay sayfasının rezervasyon paneli ve ana sayfanın hero arama
 * formu. Sayacın tek davranış sözleşmesi olsun diye bağlama kodu tek
 * dosyada tutulur (daha önce public-detail.js içindeydi ve hero formunda
 * yalnızca SAHTE bir "4 Guests" alanı vardı — stepper'sız, değeri hiçbir
 * yere gitmeyen bir maket).
 *
 * Sözleşme:
 *   • Sınırlar: yetişkin ≥ 1, çocuk/bebek ≥ 0, toplam ≤ 16. Sınıra gelince
 *     ilgili düğme `disabled` olur (hem davranış hem görsel).
 *   • Toplam, bileşendeki `<input name="guests" data-guests-total>` alanına
 *     yazılır. Hero formu gerçek bir GET formu olduğu için (`action="/urunler"`)
 *     seçim arama URL'sine `guests=<toplam>` olarak KENDİLİĞİNDEN gider.
 *   • Tetikleyici özeti ("4 misafir") seçili dilden gelir: `window.NEXUS_T`
 *     (`main.js` sözlükleri). Sözlük yoksa İngilizce referansa düşer.
 *   • Dil değişiminde (`nexus:lang`) özet etiketi yeniden basılır — aksi
 *     hâlde sayfa İngilizceye geçerken "4 misafir" Türkçe kalırdı.
 */
(function () {
  "use strict";

  var ranges = [];

  function t(key) {
    return typeof window.NEXUS_T === "function" ? window.NEXUS_T(key) : key;
  }

  // Sözlük anahtarı İngilizce referanstır; `%s` yer tutucusu sayıyı taşır.
  // TR: "%s misafir" · EN: "%s guests" · DE: "%s Gäste" · RU: "%s гостей"
  function guestLabel(n) {
    return t("%s guests").replace("%s", String(n));
  }

  function initRange(container) {
    var trigger = container.querySelector(".chisfis-guest-trigger");
    var panel = container.querySelector(".chisfis-guest-panel");
    var hidden = container.querySelector("input[data-guests-total]");
    var valueLabel = container.querySelector(".chisfis-guest-value");
    if (!trigger || !panel || !hidden || !valueLabel) return;

    var counts = { adults: 2, children: 0, infants: 0 };
    var mins = { adults: 1, children: 0, infants: 0 };
    var maxTotal = 16;
    var total = function () {
      return counts.adults + counts.children + counts.infants;
    };

    function sync() {
      Object.keys(counts).forEach(function (key) {
        var value = counts[key];
        var el = container.querySelector('[data-guest-count="' + key + '"]');
        if (el) el.textContent = String(value);
        var minus = container.querySelector('[data-step="-1"][data-target="' + key + '"]');
        if (minus) minus.disabled = value <= mins[key];
        var plus = container.querySelector('[data-step="1"][data-target="' + key + '"]');
        if (plus) plus.disabled = total() >= maxTotal;
      });
      hidden.value = String(total());
      valueLabel.textContent = guestLabel(total());
    }

    function close() {
      panel.removeAttribute("data-open");
      trigger.setAttribute("aria-expanded", "false");
    }
    function open() {
      panel.setAttribute("data-open", "");
      trigger.setAttribute("aria-expanded", "true");
    }

    trigger.addEventListener("click", function (e) {
      e.stopPropagation();
      if (panel.hasAttribute("data-open")) close();
      else open();
    });
    panel.addEventListener("click", function (e) {
      e.stopPropagation();
    });
    document.addEventListener("click", function (e) {
      if (panel.hasAttribute("data-open") && !container.contains(e.target)) close();
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && panel.hasAttribute("data-open")) {
        close();
        trigger.focus();
      }
    });
    panel.addEventListener("click", function (e) {
      var btn = e.target.closest("button.guest-stepper-btn");
      if (!btn || btn.disabled) return;
      var key = btn.dataset.target;
      if (!(key in counts)) return;
      counts[key] = Math.min(maxTotal, Math.max(mins[key], counts[key] + Number(btn.dataset.step)));
      sync();
    });

    sync();
    ranges.push(sync);
  }

  function init() {
    var found = document.querySelectorAll(".chisfis-guest-range");
    for (var i = 0; i < found.length; i++) initRange(found[i]);
    if (ranges.length) {
      // Sözlük dil değişince özet etiketi eski dilde kalmasın.
      document.addEventListener("nexus:lang", function () {
        ranges.forEach(function (sync) {
          sync();
        });
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
