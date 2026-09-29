/**
 * public-listings.js — Mobil filtre paneli toggle
 *
 * Listing sayfasındaki filtre + arama alanını mobilde
 * katlanabilir (collapsible) panele dönüştürür.
 * Masaüstünde her zaman açıktır, mobilde toggle ile açılır.
 */
(function () {
  "use strict";

  const BREAKPOINT = 1024;
  const MONEY = new Intl.NumberFormat("tr-TR");

  function currentLang() {
    const match = document.cookie.match(/(?:^|;\s*)nexus_lang=([^;]*)/);
    return match ? decodeURIComponent(match[1]) : "tr";
  }

  function esc(value) {
    return String(value == null ? "" : value).replace(/[&<>"']/g, function (ch) {
      return ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[ch];
    });
  }

  function firstImage(images) {
    if (Array.isArray(images) && images.length) return images[0];
    try {
      const parsed = JSON.parse(images || "[]");
      if (Array.isArray(parsed) && parsed.length) return parsed[0];
    } catch (_) {}
    return "/static/chisfis/images/hero-right.webp";
  }

  function currencySymbol(code) {
    return { TRY: "₺", USD: "$", EUR: "€", GBP: "£", SAR: "﷼", RUB: "₽", CNY: "¥" }[String(code || "TRY").toUpperCase()] || code || "₺";
  }

  function priceUnit(category) {
    return ["hotel", "holiday_home", "villa"].indexOf(category) !== -1 ? "gece" : category === "yacht" || category === "car" ? "gün" : "kişi";
  }

  function canonicalCategory(value) {
    const slug = String(value || "").trim().toLowerCase();
    if (slug === "villa") return "holiday_home";
    if (slug === "flight_bus") return "flight";
    if (slug === "hajj") return "pilgrimage";
    if (slug === "sunbed") return "beach";
    return slug;
  }

  function renderCard(item, tenant) {
    const image = firstImage(item.images);
    const price = MONEY.format(Math.round(Number(item.priceMinor || 0) / 100));
    const href = (window.NEXUS_LISTING_URL ? window.NEXUS_LISTING_URL(item) : "/urunler/" + encodeURIComponent(item.id)) + (tenant ? "?tenant=" + encodeURIComponent(tenant) : "");
    return '' +
      '<article class="product-card">' +
      '<div class="product-card-media" data-images="' + esc(JSON.stringify([image])) + '" style="background-image:url(' + esc(image) + ')"><button class="card-favorite" type="button" aria-label="Favorilere ekle">♡</button></div>' +
      '<div class="product-card-body">' +
      '<span class="card-type">' + esc(item.categoryLabel || item.category) + (item.locality ? " · " + esc(item.locality) : "") + '</span>' +
      '<h2><a href="' + esc(href) + '">' + esc(item.title) + '</a></h2>' +
      '<div class="card-divider"></div>' +
      '<div class="card-price-row"><div class="card-price"><strong data-price-minor="' + esc(item.priceMinor) + '" data-price-cur="' + esc(item.currency) + '">' + esc(currencySymbol(item.currency)) + ' ' + esc(price) + '</strong><span class="card-price-unit">/ ' + esc(priceUnit(item.category)) + '</span></div><span class="card-rating">★ 4.9</span></div>' +
      '</div>' +
      '</article>';
  }

  function renderEmpty(grid, message) {
    grid.innerHTML = '<p class="empty-state">' + esc(message) + '</p>';
  }

  function initManagedFiltersAndResults() {
    const main = document.querySelector(".products-page");
    const panel = document.querySelector("[data-filter-panel]");
    const body = panel && panel.querySelector(".listing-filter-body");
    const form = body && body.querySelector(".product-search");
    const grid = document.querySelector(".products-page > .product-grid");
    if (!main || !body || !form || !grid) return;

    const params = new URLSearchParams(location.search);
    const tenant = params.get("tenant") || document.body.dataset.tenant || "";
    const category = canonicalCategory(params.get("kategori") || "");
    const selectedKey = params.get("filter_key") || "";
    const selectedValue = params.get("filter_value") || "";

    function loadListings() {
      const apiParams = new URLSearchParams(new FormData(form));
      if (category) apiParams.set("kategori", category);
      if (selectedKey && selectedValue) {
        apiParams.set("filter_key", selectedKey);
        apiParams.set("filter_value", selectedValue);
      }
      fetch("/api/public/listings?" + apiParams.toString(), { credentials: "same-origin", cache: "no-store" })
        .then(function (response) {
          if (!response.ok) throw new Error("İlanlar yüklenemedi");
          return response.json();
        })
        .then(function (items) {
          if (!Array.isArray(items) || !items.length) {
            renderEmpty(grid, "Seçiminize uygun yayınlanmış ürün bulunamadı.");
            return;
          }
          grid.innerHTML = items.map(function (item) { return renderCard(item, tenant); }).join("");
        })
        .catch(function (error) {
          renderEmpty(grid, error.message || "İlanlar yüklenemedi.");
        });
    }

    if (category) {
      const categorySelect = form.querySelector('select[name="kategori"]');
      if (categorySelect) categorySelect.value = category;
    }

    if (category) {
      const filterParams = new URLSearchParams();
      filterParams.set("category", category);
      filterParams.set("lang", currentLang());
      if (tenant) filterParams.set("tenant", tenant);
      fetch("/api/public/category-filters?" + filterParams.toString(), { credentials: "same-origin", cache: "no-store" })
        .then(function (response) { return response.ok ? response.json() : []; })
        .then(function (groups) {
          if (!Array.isArray(groups) || !groups.length) return;
          const wrap = document.createElement("div");
          wrap.className = "listing-managed-filters";
          groups.forEach(function (group) {
            const fieldKey = (group.items && group.items[0] && group.items[0].contractFieldKey) || group.key;
            const block = document.createElement("div");
            block.className = "listing-managed-filter-group";
            block.innerHTML = '<strong>' + esc(group.title || group.key) + '</strong><div></div>';
            const chips = block.querySelector("div");
            if (selectedKey && selectedValue && selectedKey === fieldKey) {
              const clear = document.createElement("a");
              const clearParams = new URLSearchParams(location.search);
              clearParams.set("kategori", category);
              clearParams.delete("filter_key");
              clearParams.delete("filter_value");
              if (tenant) clearParams.set("tenant", tenant);
              clear.href = location.pathname + "?" + clearParams.toString();
              clear.textContent = "Tümünü göster";
              clear.className = "clear-filter";
              chips.appendChild(clear);
            }
            (group.items || []).forEach(function (item) {
              const value = item.contractValue || item.key;
              const link = document.createElement("a");
              const next = new URLSearchParams(location.search);
              next.set("kategori", category);
              next.set("filter_key", item.contractFieldKey || fieldKey);
              next.set("filter_value", value);
              if (tenant) next.set("tenant", tenant);
              link.href = location.pathname + "?" + next.toString();
              link.textContent = item.title || item.key;
              if ((item.contractFieldKey || fieldKey) === selectedKey && value === selectedValue) link.className = "active";
              chips.appendChild(link);
            });
            wrap.appendChild(block);
          });
          body.appendChild(wrap);
        });
    }

    if (selectedKey && selectedValue) loadListings();
  }

  function init() {
    const panel = document.querySelector("[data-filter-panel]");
    if (!panel) return;

    const toggle = panel.querySelector(".listing-filter-toggle");
    const body = panel.querySelector(".listing-filter-body");
    if (!toggle || !body) return;

    /* Açık/kapalı durumunun TEK kaynağı: body'nin `is-open` sınıfı.
     * `aria-expanded` türetilmiş etikettir, girdi değil — çünkü main.js §12
     * (dış tıklama geçişi) belgedeki her `[aria-expanded="true"]` düğmeyi
     * sıfırlar, bu panel ise kapanmaz. Etiketi girdi olarak okumak "dışarı
     * tıkla → düğmeye bas → panel kapanır" hatasını üretirdi. */
    function isExpanded() {
      return body.classList.contains("is-open");
    }

    function syncAria() {
      toggle.setAttribute("aria-expanded", isExpanded() ? "true" : "false");
    }

    // Varsayılan durum: masaüstünde açık, mobilde kapalı
    function sync() {
      if (window.innerWidth >= BREAKPOINT) {
        toggle.style.display = "none";
        body.classList.add("is-open");
        body.style.maxHeight = "none";
        body.style.opacity = "1";
        body.style.pointerEvents = "auto";
      } else {
        toggle.style.display = "flex";
        // İlk yüklemede kapalı bırak
        if (!body.hasAttribute("data-initialized")) {
          body.classList.remove("is-open");
          body.style.maxHeight = "0";
          body.style.opacity = "0";
          body.style.pointerEvents = "none";
          body.setAttribute("data-initialized", "1");
        }
      }
      syncAria();
    }

    function togglePanel() {
      const expanded = isExpanded();
      if (expanded) {
        // Kapat
        body.style.maxHeight = body.scrollHeight + "px";
        // Force reflow
        body.offsetHeight;
        body.style.maxHeight = "0";
        body.style.opacity = "0";
        body.style.pointerEvents = "none";
        body.classList.remove("is-open");
      } else {
        // Aç
        body.classList.add("is-open");
        body.style.maxHeight = body.scrollHeight + "px";
        body.style.opacity = "1";
        body.style.pointerEvents = "auto";
        // Animasyon bitince maxHeight'i kaldır (içerik değişebilir)
        setTimeout(function () {
          if (isExpanded()) {
            body.style.maxHeight = "none";
          }
        }, 400);
      }
      syncAria();
    }

    toggle.addEventListener("click", togglePanel);
    window.addEventListener("resize", sync);
    sync();
    initManagedFiltersAndResults();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
