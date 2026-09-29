// table-expand.js — Tablo satırlarına expand/collapse davranışı ekler.
// Kullanım: <table data-expand-table> veya <table data-expand-table data-expand-cols="3">
//   <tr data-row-id="7"> ...  (tbody satırları, data-expand-detail içeren gizli td)
// Davranış: Satıra tıkla → gizli detay satırı açılır/kapanır.
// data-expand-detail attribute'u olan <td> genişletme içeriğini taşır.

(function () {
  "use strict";

  var EXPAND_CLASS = "row-expand";
  var EXPANDED_CLASS = "row-expanded";
  var CHEVRON_SVG = '<i class="hgi-stroke hgi-arrow-down-01 expand-chevron" aria-hidden="true"></i>';

  function esc(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  // Satırdaki visible td'lerden özet hücreleri topla (compact kart görünümü)
  function buildCompactSummary(row, table) {
    var ths = table.querySelectorAll("thead th");
    var cells = row.querySelectorAll("td:not(.expand-chevron-col):not(.bulk-check-col)");
    if (cells.length === 0 || ths.length === 0) return null;

    // İsim/sütun eşlemesi — ilk sütun genelde başlık/hücre
    var parts = [];
    var maxShow = Math.min(cells.length, 3);
    for (var i = 0; i < maxShow; i++) {
      var thText = ths[i + 1] ? ths[i + 1].textContent.trim() : "";
      var cellText = cells[i].textContent.trim();
      if (cellText && cellText.length > 0) {
        parts.push(
          '<span class="compact-label">' + esc(thText) + '</span>' +
          '<span class="compact-value">' + esc(cellText) + '</span>'
        );
      }
    }
    return parts.length > 0 ? '<div class="compact-summary">' + parts.join("") + "</div>" : null;
  }

  function createExpandRow(row, table) {
    // varsa data-expand-detail içeren td'yi ara
    var detailTd = row.querySelector("[data-expand-detail]");
    if (!detailTd) return null;

    var tr = document.createElement("tr");
    tr.className = EXPAND_CLASS;
    var colspan = row.querySelectorAll("td").length;
    var td = document.createElement("td");
    td.setAttribute("colspan", String(colspan));
    td.className = "expand-detail-cell";

    var inner = document.createElement("div");
    inner.className = "expand-detail-content";
    inner.innerHTML = detailTd.getAttribute("data-expand-detail") || detailTd.innerHTML;
    td.appendChild(inner);
    tr.appendChild(td);
    return tr;
  }

  function toggleRow(row, table) {
    var nextRow = row.nextElementSibling;
    var isExpanded = row.classList.contains(EXPANDED_CLASS);

    if (isExpanded) {
      // Kapat
      row.classList.remove(EXPANDED_CLASS);
      if (nextRow && nextRow.classList.contains(EXPAND_CLASS)) {
        nextRow.style.maxHeight = "0";
        nextRow.style.opacity = "0";
        setTimeout(function () {
          if (nextRow.parentNode) nextRow.parentNode.removeChild(nextRow);
        }, 250);
      }
    } else {
      // Diğer açık satırları kapat
      var tbody = row.closest("tbody");
      if (tbody) {
        tbody.querySelectorAll("tr." + EXPANDED_CLASS).forEach(function (openRow) {
          toggleRow(openRow, table);
        });
      }

      // Aç
      row.classList.add(EXPANDED_CLASS);
      var expandRow = createExpandRow(row, table);
      if (expandRow) {
        row.parentNode.insertBefore(expandRow, row.nextSibling);
        // Animasyon
        requestAnimationFrame(function () {
          expandRow.style.maxHeight = expandRow.scrollHeight + "px";
          expandRow.style.opacity = "1";
        });
      }
    }
  }

  // Chevron kolonu ekle
  function injectChevron(row) {
    if (row.querySelector(".expand-chevron-col")) return;
    var td = document.createElement("td");
    td.className = "expand-chevron-col";
    td.innerHTML = CHEVRON_SVG;
    td.setAttribute("aria-hidden", "true");
    row.appendChild(td);
  }

  function bindTable(table) {
    if (table.getAttribute("data-expand-bound")) return;
    table.setAttribute("data-expand-bound", "true");

    // Chevron kolonu ekle
    var theadRow = table.querySelector("thead tr");
    if (theadRow && !theadRow.querySelector(".expand-chevron-col")) {
      var th = document.createElement("th");
      th.className = "expand-chevron-col";
      th.setAttribute("aria-label", "Genişlet");
      theadRow.appendChild(th);
    }

    // Event delegation
    table.addEventListener("click", function (e) {
      var row = e.target.closest ? e.target.closest("tr[data-row-id]") : null;
      if (!row) return;
      // Buton, link, checkbox, select, input tıklamasını yoksay
      if (e.target.closest("button, a, input, select, textarea, .bulk-check-col")) return;
      // data-expand-detail içermeyen satırları atla
      if (!row.querySelector("[data-expand-detail]")) return;
      e.preventDefault();
      toggleRow(row, table);
    });
  }

  function mount() {
    document.querySelectorAll("table[data-expand-table]").forEach(function (table) {
      // Tüm satırlara chevron ekle
      table.querySelectorAll("tbody tr[data-row-id]").forEach(injectChevron);
      bindTable(table);
    });
  }

  // Dinamik satır ekleme için gözlemci
  function observeDynamicRows() {
    if (document.documentElement.hasAttribute("data-expand-observed")) return;
    document.documentElement.setAttribute("data-expand-observed", "true");
    var observer = new MutationObserver(function (mutations) {
      mutations.forEach(function (m) {
        Array.prototype.forEach.call(m.addedNodes, function (node) {
          if (node.nodeType !== 1) return;
          var table =
            node.matches && node.matches("table[data-expand-table]")
              ? node
              : node.parentElement
                ? node.parentElement.closest("table[data-expand-table]")
                : null;
          if (!table) return;
          if (node.tagName === "TR" && node.getAttribute("data-row-id")) {
            injectChevron(node);
            bindTable(table);
          }
        });
      });
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      mount();
      observeDynamicRows();
    });
  } else {
    mount();
    observeDynamicRows();
  }

  window.TableExpand = { mount: mount };
})();
