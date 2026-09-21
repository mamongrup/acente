/**
 * public-category-nav.js — Kategori pill auto-scroll + breadcrumb
 *
 * 1. Sayfa yüklendiğinde aktif kategori pill'ini görünür alana kaydırır
 * 2. Mobilde yatay scroll container'ında aktif pill'e keyboard ile erişim
 */
(function () {
  "use strict";

  var BREAKPOINT = 1024;

  function scrollToActivePill() {
    var pills = document.querySelector(".product-category-pills");
    if (!pills) return;

    var active = pills.querySelector("a.active");
    if (!active) return;

    // Masaüstünde scroll gerekmez
    if (window.innerWidth >= BREAKPOINT) return;

    // Aktif pill'i container'ın ortasına kaydır
    var containerRect = pills.getBoundingClientRect();
    var pillRect = active.getBoundingClientRect();
    var scrollLeft = pills.scrollLeft;

    // Pill'in solu ile container'ın solu arasındaki fark
    var targetScroll =
      scrollLeft + pillRect.left - containerRect.left - containerRect.width / 2 + pillRect.width / 2;

    pills.scrollTo({
      left: Math.max(0, targetScroll),
      behavior: "smooth",
    });
  }

  function init() {
    // İlk yüklemede kaydır (biraz gecikme ile layout bitsin)
    setTimeout(scrollToActivePill, 100);

    // Pencere yeniden boyutlandırıldığında da kontrol et
    var resizeTimer;
    window.addEventListener("resize", function () {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(scrollToActivePill, 200);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
