/**
 * panel-tab-bar.js — Panel mobil bottom tab bar
 *
 * 1. Mevcut URL'ye göre aktif sekmeyi işaretler
 * 2. "More" butonu → sidebar drawer'ını açar
 * 3. Sayfa değişiminde aktif sekmeyi günceller
 */
(function () {
  "use strict";

  var BREAKPOINT = 820;

  // URL path → tab eşleme
  var TAB_MAP = {
    "/admin": 0,
    "/admin/listings": 1,
    "/admin/catalog": 1,
    "/admin/reservations": 2,
    "/admin/offers": 2,
    "/admin/inquiries": 2,
    "/admin/customers": 2,
    "/admin/reports": 2,
    "/admin/cms": 3,
    "/admin/campaigns": 3,
    "/admin/media": 3,
    "/admin/popups": 3,
  };

  function getTabIndex(path) {
    // Tam eşleşme
    if (TAB_MAP[path] !== undefined) return TAB_MAP[path];

    // Prefix eşleme (en uzun eşleşme)
    var best = -1;
    var bestLen = 0;
    for (var key in TAB_MAP) {
      if (path.startsWith(key) && key.length > bestLen) {
        best = TAB_MAP[key];
        bestLen = key.length;
      }
    }
    return best >= 0 ? best : -1;
  }

  function setActiveTab() {
    if (window.innerWidth >= BREAKPOINT) return;

    var bar = document.querySelector(".panel-tab-bar");
    if (!bar) return;

    var path = window.location.pathname;
    var idx = getTabIndex(path);

    var items = bar.querySelectorAll(".panel-tab-item");
    items.forEach(function (item, i) {
      item.classList.remove("active", "is-active");
      if (i === idx) {
        item.classList.add("active");
      }
    });
  }

  function init() {
    var bar = document.querySelector(".panel-tab-bar");
    if (!bar) return;

    // More butonu → sidebar drawer'ını aç
    var moreBtn = bar.querySelector("[data-panel-tab-more]");
    if (moreBtn) {
      moreBtn.addEventListener("click", function () {
        var dashboard = document.querySelector(".dashboard");
        if (dashboard) {
          dashboard.classList.add("mobile-nav-open");
          document.body.classList.add("panel-menu-open");
        }
      });
    }

    setActiveTab();
    window.addEventListener("resize", setActiveTab);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
