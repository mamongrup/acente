// table-cards.js — Mobil kırılımda tabloların kart görünümüne dönüşmesi için
// her td'ye thead'den türetilen data-label etiketi basar. CSS (04-forms-tables)
// ≤640px'te satırları kartlara çevirir. Statik Gleam tabloları ve 14 JS modülünün
// dinamik satırları (MutationObserver) otomatik kapsanır.
(function () {
  "use strict";

  var BREAKPOINT = 640;

  function isMobile() {
    return window.matchMedia("(max-width: " + BREAKPOINT + "px)").matches;
  }

  // Bir thead satırından başlık listesi üret.
  function headersOf(table) {
    var heads = [];
    table.querySelectorAll("thead th").forEach(function (th) {
      heads.push({
        text: (th.textContent || "").trim(),
        isCheck: th.classList.contains("bulk-check-col"),
        isActions: th.classList.contains("text-right"),
      });
    });
    return heads;
  }

  // Satırın hücrelerine data-label bas. Colspan'lı (empty-state vb.) hücreler
  // etiketsiz kalır — kart değil tam genişlik bilgi bloğu olarak render edilir.
  function labelRow(table, heads, row) {
    var cells = row.children;
    for (var i = 0; i < cells.length; i++) {
      var td = cells[i];
      var head = heads[i];
      if (!head) continue;
      // Colspan'lı bilgi blokları (empty-state vb.) önce yakalanır —
      // tek hücreli satır bulk sütunuyla eşleşmesin.
      if (td.hasAttribute("colspan")) {
        td.removeAttribute("data-label");
        td.removeAttribute("data-card-check");
        continue;
      }
      // Bulk onay kutusu hücresi: etiket yerine kompakt sınıf.
      if (head.isCheck || td.classList.contains("bulk-check-col")) {
        td.setAttribute("data-card-check", "true");
        td.removeAttribute("data-label");
        continue;
      }
      if (!head.text) {
        td.removeAttribute("data-label");
        continue;
      }
      td.setAttribute("data-label", head.text);
      if (head.isActions) td.setAttribute("data-card-actions", "true");
    }
  }

  function enhanceTable(table) {
    if (table.getAttribute("data-cards") === "ready") {
      // Yeni satırlar mı gelmiş? Yeniden tara (satır bazlı idempotent).
    }
    var heads = headersOf(table);
    if (!heads.length) return;
    table.querySelectorAll("tbody tr").forEach(function (row) {
      // Zaten işlenmiş satırların hücre sayısı değişmediyse atla.
      labelRow(table, heads, row);
    });
    table.setAttribute("data-cards", "ready");
  }

  function enhanceAll() {
    document.querySelectorAll("table.data-table").forEach(enhanceTable);
  }

  function mount() {
    enhanceAll();
    // Dinamik satırlar: fetch ile dolduran 14 admin modülü için.
    var observer = new MutationObserver(function (mutations) {
      var touched = new Set();
      mutations.forEach(function (mutation) {
        Array.prototype.forEach.call(mutation.addedNodes, function (node) {
          if (node.nodeType !== 1) return;
          var table =
            node.matches && node.matches("table.data-table")
              ? node
              : node.parentElement
                ? node.parentElement.closest("table.data-table")
                : null;
          if (table) touched.add(table);
        });
      });
      touched.forEach(enhanceTable);
    });
    observer.observe(document.body, { childList: true, subtree: true });

    // Kırılım geçişlerinde yeniden hizala (etiketler kırılımdan bağımsız olduğu
    // için çoğunlukla gereksiz; yine de bulk enjeksiyonu sonrası güvenli).
    var lastMobile = isMobile();
    window.addEventListener("resize", function () {
      var m = isMobile();
      if (m !== lastMobile) {
        lastMobile = m;
        enhanceAll();
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", mount);
  } else {
    mount();
  }

  window.TableCards = { enhanceAll: enhanceAll };
})();
