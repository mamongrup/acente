/**
 * public-favorites.js — Mobil favoriler şeridi
 *
 * Her sayfa yüklenmesinde ziyaret sayısını localStorage'da artırır.
 * En çok ziyaret edilen 5 sayfayı (ana sayfa hariç) mobil menü
 * üstünde yatay şerit olarak gösterir.
 *
 * Veri yapısı: { "/urunler": 12, "/kategori/hotel": 8, ... }
 * depolama anahtarı: "nexus_fav_pages"
 */
(function () {
  "use strict";

  var STORAGE_KEY = "nexus_fav_pages";
  var MAX_ITEMS = 5;
  var BREAKPOINT = 1024;

  // Sayfa adı eşleme — path → kısa etiket + ikon
  var PAGE_MAP = {
    "/": { label: "Ana Sayfa", icon: "⌂" },
    "/urunler": { label: "Ürünler", icon: "🔍" },
    "/kategori/hotel": { label: "Oteller", icon: "🏨" },
    "/kategori/holiday_home": { label: "Tatil Evleri", icon: "🏡" },
    "/kategori/tour": { label: "Turlar", icon: "🗺️" },
    "/kategori/activity": { label: "Aktivite", icon: "🎯" },
    "/kategori/yacht": { label: "Yat", icon: "⛵" },
    "/kategori/car": { label: "Araçlar", icon: "🚗" },
    "/kategori/transfer": { label: "Transfer", icon: "🚐" },
    "/kategori/flight": { label: "Uçuşlar", icon: "✈️" },
    "/kategori/bus": { label: "Otobüs", icon: "🚌" },
    "/kategori/pilgrimage": { label: "Hac & Umre", icon: "🕌" },
    "/kategori/beach": { label: "Şezlong", icon: "🏖️" },
    "/kategori/event": { label: "Etkinlik", icon: "🎉" },
    "/kategori/restaurant": { label: "Restoran", icon: "🍽️" },
    "/iletisim": { label: "İletişim", icon: "📞" },
    "/hakkimizda": { label: "Hakkımızda", icon: "ℹ️" },
    "/blog": { label: "Blog", icon: "📝" },
    "/kullanim-kosullari": { label: "Koşullar", icon: "📋" },
    "/gizlilik-politikasi": { label: "Gizlilik", icon: "🔒" },
  };

  // Tenant parametresini temizle, path'i normalleştir
  function normalizePath(pathname, search) {
    // tenant parametresini kaldır
    var params = new URLSearchParams(search);
    params.delete("tenant");
    params.delete("tenant_slug");
    var clean = pathname;
    var qs = params.toString();
    if (qs) clean += "?" + qs;
    return clean;
  }

  // Sayfa haritasında bilinmeyen path'ler için varsayılan
  function getPageInfo(path) {
    // Tam eşleşme kontrolü
    if (PAGE_MAP[path]) return PAGE_MAP[path];

    // Slug ile eşleşen kategori sayfaları
    var slugMatch = path.match(/^\/kategori\/([a-z_]+)/);
    if (slugMatch && PAGE_MAP["/kategori/" + slugMatch[1]]) {
      return PAGE_MAP["/kategori/" + slugMatch[1]];
    }

    // Ürün detay sayfası
    if (path.match(/^\/urunler\/[a-f0-9-]+/)) {
      return { label: "İlan Detayı", icon: "📄" };
    }

    // Kategori sayfası (genel)
    if (path.startsWith("/kategori/")) {
      return { label: "Kategori", icon: "📂" };
    }

    return null;
  }

  // Ziyaret sayısını artır
  function trackVisit(path) {
    if (path === "/" || !path) return; // Ana sayfayı sayma
    try {
      var data = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
      data[path] = (data[path] || 0) + 1;
      localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
    } catch (e) {
      // localStorage dolu veya devre dışı — sessizce geç
    }
  }

  // En çok ziyaret edilen sayfaları sıralı getir
  function getTopPages() {
    try {
      var data = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
      return Object.keys(data)
        .map(function (path) {
          return { path: path, count: data[path] };
        })
        .sort(function (a, b) {
          return b.count - a.count;
        })
        .slice(0, MAX_ITEMS);
    } catch (e) {
      return [];
    }
  }

  // Tenant query'yi mevcut sayfadan al
  function getTenantQuery() {
    var params = new URLSearchParams(window.location.search);
    var tenant = params.get("tenant") || params.get("tenant_slug");
    return tenant ? "?tenant=" + tenant : "";
  }

  // Favori şeridini render et
  function renderFavorites(container, tenantQuery) {
    var topPages = getTopPages();
    if (topPages.length === 0) {
      container.style.display = "none";
      return;
    }

    container.innerHTML = "";
    container.style.display = "";

    topPages.forEach(function (item) {
      var info = getPageInfo(item.path);
      if (!info) return;

      var a = document.createElement("a");
      a.href = item.path + (item.path.indexOf("?") === -1 ? tenantQuery : "");
      a.className = "mobile-fav-item";

      // Aktif sayfa işareti
      var currentPath = normalizePath(
        window.location.pathname,
        window.location.search
      );
      if (currentPath === item.path || currentPath === item.path + "?") {
        a.classList.add("is-active");
      }

      var icon = document.createElement("span");
      icon.className = "mobile-fav-icon";
      icon.textContent = info.icon;

      var label = document.createElement("span");
      label.className = "mobile-fav-label";
      label.textContent = info.label;

      var badge = document.createElement("span");
      badge.className = "mobile-fav-badge";
      badge.textContent = item.count;

      a.appendChild(icon);
      a.appendChild(label);
      a.appendChild(badge);
      container.appendChild(a);
    });
  }

  function init() {
    if (window.innerWidth >= BREAKPOINT) return;

    var currentPath = normalizePath(
      window.location.pathname,
      window.location.search
    );
    trackVisit(currentPath);

    var container = document.querySelector(".mobile-favorites");
    if (!container) return;

    var tenantQuery = getTenantQuery();
    renderFavorites(container, tenantQuery);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
