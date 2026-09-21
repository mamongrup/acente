// table-bulk.js — Tablolara satır seçim kutuları + toplu işlem çubuğu enjekte eder.
// Kullanım: <table data-bulk-table data-bulk-label="İlan">
//           <tr data-row-id="7"> ...  (tbody satırları)
//           <form data-bulk-form action="/panel/.../bulk-delete" method="post">
// Geriye uyumluluk: table-bulk-applying sınıfı ekleme sırasında varsa ekleme atlanır.

(function () {
  "use strict";

  var CHECK_COL = "bulk-check-col";
  var TOOLBAR_ID = "bulk-toolbar";
  var COUNTER_ID = "bulk-count";

  function labelFor(table) {
    var label = table.getAttribute("data-bulk-label") || "Kayıt";
    return label.charAt(0).toUpperCase() + label.slice(1);
  }

  function closeAll() {
    document.querySelectorAll("tbody tr[data-row-id]").forEach(function (row) {
      var cb = row.querySelector('input[type="checkbox"]');
      if (cb) cb.checked = false;
      row.classList.remove("bulk-row-selected");
    });
    document.querySelectorAll("thead .bulk-check-all").forEach(function (cb) {
      cb.checked = false;
      cb.indeterminate = false;
    });
    refreshToolbars();
  }

  function refreshToolbar(toolbar) {
    if (!toolbar) return;
    var form = toolbar.closest("[data-bulk-form]") || document.querySelector("[data-bulk-form]");
    var table = document.querySelector("[data-bulk-table]");
    var selected = [];
    if (table) {
      table.querySelectorAll("tbody tr[data-row-id]").forEach(function (row) {
        var cb = row.querySelector('input[type="checkbox"]');
        if (cb && cb.checked) selected.push(row.getAttribute("data-row-id"));
      });
    }
    var counter = document.getElementById(COUNTER_ID);
    if (counter) counter.textContent = String(selected.length);
    toolbar.classList.toggle("bulk-toolbar-hidden", selected.length === 0);
    var deleteBtn = toolbar.querySelector("[data-bulk-delete]");
    if (deleteBtn) {
      deleteBtn.disabled = selected.length === 0;
      deleteBtn.setAttribute(
        "aria-label",
        labelFor(table || document) + " seçilenleri sil (" + selected.length + ")"
      );
    }
    // Diğer aksiyonlar da yalnız seçim varken aktif.
    toolbar
      .querySelectorAll(
        "button[data-bulk-publish], button[data-bulk-unpublish], button[data-bulk-csv-export]"
      )
      .forEach(function (btn) {
        btn.disabled = selected.length === 0;
      });
    if (form) {
      form.querySelectorAll('input[name="ids"]').forEach(function (input) {
        input.remove();
      });
      selected.forEach(function (id) {
        var input = document.createElement("input");
        input.type = "hidden";
        input.name = "ids";
        input.value = id;
        form.appendChild(input);
      });
    }
  }

  function refreshToolbars() {
    document.querySelectorAll("[data-bulk-toolbar]").forEach(refreshToolbar);
  }

  function injectRowCheck(table, row) {
    if (!row.getAttribute("data-row-id")) return;
    if (row.querySelector("td." + CHECK_COL)) return;
    row.setAttribute("data-bulk-row", "true");
    var td = document.createElement("td");
    td.className = CHECK_COL;
    var cb = document.createElement("input");
    cb.type = "checkbox";
    cb.setAttribute(
      "aria-label",
      labelFor(table) + " satırı " + row.getAttribute("data-row-id") + " seç",
    );
    td.appendChild(cb);
    row.insertBefore(td, row.firstChild);
  }

  function ensureCheckColumn(table, labelText) {
    var theadRow = table.querySelector("thead tr");
    var exists = table.querySelector("th." + CHECK_COL);
    if (theadRow && !exists) {
      var th = document.createElement("th");
      th.className = CHECK_COL;
      th.setAttribute("scope", "col");
      var cb = document.createElement("input");
      cb.type = "checkbox";
      cb.className = "bulk-check-all";
      cb.setAttribute("aria-label", "Tüm " + labelText.toLowerCase() + " seç (Ctrl+A)");
      th.appendChild(cb);
      theadRow.insertBefore(th, theadRow.firstChild);
    }
    table.querySelectorAll("tbody tr").forEach(function (row) {
      injectRowCheck(table, row);
    });
  }  function buildToolbar(labelText) {
    var host = document.querySelector("[data-bulk-form]");
    if (!host) return null;
    var existing = document.getElementById(TOOLBAR_ID);
    if (existing) return existing;
    // Sunucu tarafı aksiyonlar (publish/unpublish) yalnızca ilgili action
    // tanımlıysa gösterilir; CSV dışa aktarma her tabloda kullanılabilir.
    var formAction = (host.getAttribute("action") || "").replace(/\/bulk-delete$/, "");
    var hasPublish = host.hasAttribute("data-bulk-publish");
    var hasUnpublish = host.hasAttribute("data-bulk-unpublish");
    var hasCsv = host.hasAttribute("data-bulk-csv");
    var csvName = host.getAttribute("data-bulk-csv-name") || "bulk-secim";
    var csvBase = host.getAttribute("data-bulk-csv-base") || location.origin;
    var bar = document.createElement("div");
    bar.className = "bulk-toolbar bulk-toolbar-hidden";
    bar.id = TOOLBAR_ID;
    bar.setAttribute("data-bulk-toolbar", "true");
    bar.setAttribute("role", "toolbar");
    bar.setAttribute("aria-label", "Toplu işlemler");
    bar.innerHTML =
      '<span class="bulk-toolbar-count" aria-live="polite">' +
      '<strong id="' + COUNTER_ID + '">0</strong> ' + labelText.toLowerCase() + " seçildi" +
      "</span>" +
      '<button type="button" class="bulk-toolbar-btn bulk-toolbar-delete" data-bulk-delete disabled>Sil</button>' +
      (hasPublish
        ? '<button type="button" class="bulk-toolbar-btn bulk-toolbar-publish" data-bulk-publish disabled>Yayınla</button>'
        : "") +
      (hasUnpublish
        ? '<button type="button" class="bulk-toolbar-btn bulk-toolbar-unpublish" data-bulk-unpublish disabled>Yayından Kaldır</button>'
        : "") +
      (hasCsv
        ? '<button type="button" class="bulk-toolbar-btn bulk-toolbar-csv" data-bulk-csv-export disabled>CSV indir</button>'
        : "") +
      '<button type="button" class="bulk-toolbar-btn bulk-toolbar-clear" data-bulk-clear>Vazgeç</button>';
    host.insertBefore(bar, host.firstChild);
    if (hasCsv) {
      bar.querySelector("[data-bulk-csv-export]").addEventListener("click", function () {
        exportCsvSelected(csvBase, csvName);
      });
    }
    return bar;
  }

  // Seçili satırları data endpoint'inden çekip istemcide CSV üretir.
  // Sütunlar tablodaki gerçek <th> metinlerinden alınır; BOM eklenir ki
  // Excel Türkçe karakterleri doğru açsın.
  function exportCsvSelected(base, name) {
    var table = document.querySelector("[data-bulk-table]");
    if (!table) return;
    var selected = [];
    table.querySelectorAll("tbody tr[data-row-id]").forEach(function (row) {
      var cb = row.querySelector('input[type="checkbox"]');
      if (cb && cb.checked) selected.push(row.getAttribute("data-row-id"));
    });
    if (!selected.length) return;
    var endpoint =
      base +
      (base.indexOf("?") >= 0 ? "&" : "?") +
      "ids=" +
      encodeURIComponent(selected.join(","));
    fetch(endpoint, { credentials: "same-origin", cache: "no-store" })
      .then(function (response) {
        if (!response.ok) throw new Error("Veri alınamadı");
        return response.json();
      })
      .then(function (items) {
        if (!Array.isArray(items) || !items.length) return;
        // Endpoint tüm satırları döndürebilir; yalnız seçili kimlikleri CSV'e al.
        // languages'ta PK code olduğundan id yoksa code'a bakılır.
        var filtered = items.filter(function (item) {
          return selected.indexOf(String(item.id || item.code)) >= 0;
        });
        if (!filtered.length) return;
        var headers = [];
        table.querySelectorAll("thead th").forEach(function (th) {
          if (!th.classList.contains(CHECK_COL)) headers.push(th.textContent.trim());
        });
        var lines = [headers.map(csvCell).join(";")];
        filtered.forEach(function (item) {
          var line = itemColumns(item)
            .map(csvCell)
            .join(";");
          lines.push(line);
        });
        var blob = new Blob(["\ufeff" + lines.join("\r\n")], { type: "text/csv;charset=utf-8;" });
        var link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = name + "-" + new Date().toISOString().slice(0, 10) + ".csv";
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(link.href);
      })
      .catch(function () {});
  }

  function csvCell(value) {
    var text = value === null || value === undefined ? "" : String(value);
    // Excel'in formül enjeksiyonuna karşı = + - @ ile başlayan hücreleri tek tırnakla nötrle
    if (/^[=+\-@]/.test(text)) text = "'" + text;
    if (/[";\r\n]/.test(text)) text = '"' + text.replace(/"/g, '""') + '"';
    return text;
  }

  // Her varlık için CSV sütun sırası — tablo başlıklarıyla aynı düzende.
  // Ayrıştırıcı alanlar çakışmaları önler (listings de code taşır).
  function itemColumns(item) {
    if (item.reference !== undefined)
      return [
        item.reference,
        (item.customer || "Müşteri yok") + " · " + (item.listing || "İlan yok"),
        (item.checkIn || "—") + " → " + (item.checkOut || "—"),
        item.total + " " + item.currency,
        item.status + " / " + item.paymentStatus,
      ];
    if (item.full_name !== undefined)
      return [
        item.full_name,
        item.listing_title || "Genel talep",
        (item.check_in || "-") + " → " + (item.check_out || "-"),
        item.status,
      ];
    if (item.nativeName !== undefined)
      return [item.code, item.name, item.nativeName, item.status, item.defaultLabel];
    if (item.locality !== undefined)
      return [
        item.code,
        item.title,
        item.category,
        item.locality,
        Number(item.priceMinor || 0) / 100 + " " + (item.currency || "TRY"),
        item.status,
      ];
    return [item.name, item.email, item.phone, item.createdAt];
  }

  function syncAllCheckbox(table) {
    var all = document.querySelectorAll("thead .bulk-check-all");
    if (all.length === 0) return;
    var boxes = [];
    table.querySelectorAll("tbody tr[data-row-id] input[type=checkbox]").forEach(function (cb) {
      boxes.push(cb);
    });
    var checked = boxes.filter(function (cb) {
      return cb.checked;
    }).length;
    var anyIndeterminate = checked > 0 && checked < boxes.length;
    var allChecked = boxes.length > 0 && checked === boxes.length;
    all.forEach(function (cb) {
      cb.checked = allChecked;
      cb.indeterminate = anyIndeterminate;
    });
  }

  function annotateRow(row, table, checked) {
    row.classList.toggle("bulk-row-selected", checked);
    syncAllCheckbox(table);
    refreshToolbars();
  }

  function delegateClick(e) {
    var row = e.target.closest ? e.target.closest("tr[data-row-id]") : null;
    if (!row) return;
    var table = row.closest("table[data-bulk-table]");
    if (!table) return;
    if (e.target.closest('td:not(.' + CHECK_COL + ') input, a, button, select, textarea')) return;
    var cb = row.querySelector("td." + CHECK_COL + ' input[type="checkbox"]');
    if (!cb) return;
    if (e.target !== cb) {
      e.preventDefault();
      cb.checked = !cb.checked;
    }
    annotateRow(row, table, cb.checked);
  }

  function delegateChange(e) {
    var cb = e.target;
    if (!cb || cb.type !== "checkbox") return;
    if (cb.classList.contains("bulk-check-all")) {
      var table = cb.closest("table[data-bulk-table]");
      if (!table) return;
      table.querySelectorAll("tbody tr[data-row-id]").forEach(function (row) {
        var rcb = row.querySelector("td." + CHECK_COL + ' input[type="checkbox"]');
        if (!rcb) return;
        rcb.checked = cb.checked;
        row.classList.toggle("bulk-row-selected", cb.checked);
      });
      syncAllCheckbox(table);
      refreshToolbars();
      return;
    }
    var row = cb.closest("tr[data-row-id]");
    if (row && row.closest("table[data-bulk-table]")) {
      annotateRow(row, row.closest("table[data-bulk-table]"), cb.checked);
    }
  }

  function bindToolbar(onTempForm) {
    document.addEventListener("click", function (e) {
      var target = e.target.closest ? e.target : null;
      // Yayınla / Yayından Kaldır: bulk-delete formuna ASLA dokunmaz — kendi
      // geçici formunu oluşturup /bulk-publish veya /bulk-unpublish'e gönderir.
      // DİKKAT: seçici button ile nitelenir; form'un data-bulk-publish
      // niteliği closest eşleşmesine yakalanmasın (bug: bulk4).
      var publishBtn = e.target.closest ? e.target.closest("button[data-bulk-publish]") : null;
      var unpublishBtn = e.target.closest ? e.target.closest("button[data-bulk-unpublish]") : null;
      if (publishBtn || unpublishBtn) {
        e.preventDefault();
        var bulkForm = (publishBtn || unpublishBtn).closest("[data-bulk-form]");
        if (!bulkForm) return;
        var selectedIds = [];
        document
          .querySelectorAll("[data-bulk-table] tbody tr[data-row-id]")
          .forEach(function (row) {
            var cb = row.querySelector('input[type="checkbox"]');
            if (cb && cb.checked) selectedIds.push(row.getAttribute("data-row-id"));
          });
        if (!selectedIds.length) return;
        var verb = publishBtn ? "yayınlanacak" : "yayından kaldırılacak";
        var ok = window.confirm(
          selectedIds.length + " kayıt " + verb + ". Onaylıyor musunuz?"
        );
        if (!ok) return;
        var bulkAction = bulkForm.getAttribute("action") || "";
        var base = bulkAction.replace(/\/bulk-delete$/, "");
        var action = base + (publishBtn ? "/bulk-publish" : "/bulk-unpublish");
        // Geçici form: sayfada görünmez, ids + aksiyona özgü endpoint taşır.
        var tmp = document.createElement("form");
        tmp.method = "post";
        tmp.action = action;
        tmp.style.display = "none";
        selectedIds.forEach(function (id) {
          var input = document.createElement("input");
          input.type = "hidden";
          input.name = "ids";
          input.value = id;
          tmp.appendChild(input);
        });
        document.body.appendChild(tmp);
        if (onTempForm) onTempForm(tmp);
        tmp.submit();
        return;
      }
      var btn = e.target.closest ? e.target.closest("[data-bulk-delete]") : null;
      if (btn) {
        e.preventDefault();
        var form = btn.closest("[data-bulk-form]");
        if (!form) return;
        var count = document.querySelectorAll(
          "[data-bulk-table] tbody tr[data-row-id] input:checked"
        ).length;
        var label = labelFor(document.querySelector("[data-bulk-table]") || document);
        if (count === 0) return;
        var ok = window.confirm(count + " kayıt silinecek. Bu işlem geri alınamaz. Onaylıyor musunuz?");
        if (!ok) return;
        form.submit();
      }
      var clear = e.target.closest ? e.target.closest("[data-bulk-clear]") : null;
      if (clear) {
        e.preventDefault();
        closeAll();
      }
    });
    document.addEventListener("keydown", function (e) {
      var table = document.querySelector("[data-bulk-table]");
      if (!table) return;
      if ((e.ctrlKey || e.metaKey) && (e.key === "a" || e.key === "A")) {
        var tag = (e.target.tagName || "").toLowerCase();
        if (tag === "input" || tag === "textarea") return;
        e.preventDefault();
        var all = document.querySelector("thead .bulk-check-all");
        if (all) {
          var willCheck = !table.querySelectorAll(
            "tbody tr[data-row-id] input:checked"
          ).length;
          all.checked = willCheck;
          table.querySelectorAll("tbody tr[data-row-id]").forEach(function (row) {
            var cb = row.querySelector("td." + CHECK_COL + ' input[type="checkbox"]');
            if (cb) {
              cb.checked = willCheck;
              row.classList.toggle("bulk-row-selected", willCheck);
            }
          });
          syncAllCheckbox(table);
          refreshToolbars();
        }
      }
      if (e.key === "Escape") closeAll();
    });
  }

  function observeDynamicRows() {
    if (document.documentElement.hasAttribute("data-bulk-observed")) return;
    document.documentElement.setAttribute("data-bulk-observed", "true");
    var observer = new MutationObserver(function (mutations) {
      mutations.forEach(function (mutation) {
        Array.prototype.forEach.call(mutation.addedNodes, function (node) {
          if (node.nodeType !== 1) return;
          var table =
            node.matches && node.matches("table[data-bulk-table]")
              ? node
              : node.parentElement
                ? node.parentElement.closest("table[data-bulk-table]")
                : null;
          if (!table) return;
          if (node.tagName === "TR") {
            injectRowCheck(table, node);
          } else {
            ensureCheckColumn(table, labelFor(table));
          }
        });
      });
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  function mount() {
    var tables = document.querySelectorAll("[data-bulk-table]");
    if (tables.length === 0) return;
    var table = tables[0];
    var labelText = labelFor(table);
    ensureCheckColumn(table, labelText);
    var toolbar = buildToolbar(labelText);
    if (toolbar) refreshToolbar(toolbar);
    refreshToolbars();
    observeDynamicRows();
    if (!document.documentElement.hasAttribute("data-bulk-bound")) {
      document.documentElement.setAttribute("data-bulk-bound", "true");
      document.addEventListener("click", delegateClick);
      document.addEventListener("change", delegateChange);
      bindToolbar();
    }
    // CSRF: bulk-delete host formuna token'ı şimdi ve publish/unpublish
    // geçici formlarına submit anında ekle (csrf-guard submit yakalayıcısı
    // ile birlikte savunma derinliği).
    if (window.__NexusCsrf) {
      window.__NexusCsrf.tagForm(document.querySelector("[data-bulk-form]"));
      bindToolbar(function (form) {
        window.__NexusCsrf.tagForm(form);
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", mount);
  } else {
    mount();
  }

  window.TableBulk = { mount: mount, closeAll: closeAll };
})();
