// NEXUS Agency — top-level sidebar groups
(function () {
  var groups = document.querySelectorAll('[data-sidebar-group]');
  if (!groups.length) return;

  function setOpen(group, open) {
    group.classList.toggle('is-open', open);
    var button = group.querySelector('.sidebar-menu-toggle');
    if (button) button.setAttribute('aria-expanded', open ? 'true' : 'false');
  }

  var currentPath = window.location.pathname;
  var inCatalogContext = currentPath.indexOf('/admin/catalog') === 0 ||
    new URLSearchParams(window.location.search).has('cat');
  groups.forEach(function (group) {
    var groupId = group.getAttribute('data-sidebar-group');
    var key = 'nexus.sidebar.' + groupId;
    var button = group.querySelector('.sidebar-menu-toggle');
    var stored = null;
    try { stored = window.localStorage.getItem(key); } catch (_) {}

    // A catalog category is opened by the server when it is the active page.
    // Other groups open automatically when one of their links is active.
    var hasActiveLink = Array.prototype.some.call(group.querySelectorAll('a'), function (link) {
      try { return new URL(link.href, window.location.origin).pathname === currentPath; } catch (_) { return false; }
    });
    var initiallyOpen = group.classList.contains('is-open') || hasActiveLink;
    if (groupId === 'catalog' && !inCatalogContext) initiallyOpen = false;
    if (stored === 'open') initiallyOpen = true;
    if (stored === 'closed') initiallyOpen = false;
    if (groupId === 'catalog' && !inCatalogContext) initiallyOpen = false;
    setOpen(group, initiallyOpen);

    if (!button) return;
    button.addEventListener('click', function () {
      var next = !group.classList.contains('is-open');
      // Keep the menu tidy: one top-level group at a time.
      groups.forEach(function (other) { if (other !== group) setOpen(other, false); });
      setOpen(group, next);
      try { window.localStorage.setItem(key, next ? 'open' : 'closed'); } catch (_) {}
    });
  });
})();

/* Mobile panel navigation */
(function () {
  var toggle = document.getElementById('mobile-nav-toggle');
  var dashboard = document.querySelector('.dashboard');
  if (!toggle || !dashboard) return;

  function isOpen() { return dashboard.classList.contains('mobile-nav-open'); }

  var close = function () {
    dashboard.classList.remove('mobile-nav-open');
    dashboard.classList.remove('mobile-nav-closing');
    toggle.setAttribute('aria-expanded', 'false');
    document.body.classList.remove('panel-menu-open');
  };

  toggle.addEventListener('click', function () {
    var open = dashboard.classList.toggle('mobile-nav-open');
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    document.body.classList.toggle('panel-menu-open', open);
  });

  dashboard.addEventListener('click', function (event) {
    if (!dashboard.classList.contains('mobile-nav-open')) return;
    var insideSidebar = event.target.closest && event.target.closest('.sidebar');
    if (!insideSidebar && event.target !== toggle) close();
  });

  dashboard.querySelectorAll('.sidebar a').forEach(function (link) {
    link.addEventListener('click', function () {
      if (window.matchMedia('(max-width: 820px)').matches) close();
    });
  });

  window.addEventListener('resize', function () {
    if (!window.matchMedia('(max-width: 820px)').matches) close();
  });

  // Mobil menüde aktif sayfa göstergesi: href'i mevcut pathname (varsa
  // kategori paramıyla) eşleşen link .active + aria-current="page" alır.
  var currentPath = window.location.pathname;
  var currentSearch = window.location.search;
  var catParam = new URLSearchParams(currentSearch).get('cat');
  document.querySelectorAll('.sidebar a[href]').forEach(function (link) {
    var target;
    try { target = new URL(link.href, window.location.origin); } catch (_) { return; }
    if (target.origin !== window.location.origin) return;
    if (target.pathname !== currentPath) return;
    // Kategori bağlamı: /admin/catalog?cat=hotel aktifken ?cat'i olmayan
    // /admin/catalog linki "aktif" sayılmaz.
    var linkCat = target.searchParams.get('cat');
    if (catParam && target.pathname.indexOf('/admin/catalog') === 0 && linkCat && linkCat !== catParam) return;
    link.classList.add('active');
    link.setAttribute('aria-current', 'page');
  });

  // Swipe-to-close: menü açıkken herhangi bir noktadan sağa doğru sürükleme
  // menüyü kapatır (drawer parmakla itilir gibi). Menü içi dikey kaydırma
  // korunur — ilk 10px'te eksen kilitlenir.
  var sidebar = dashboard.querySelector('.sidebar');
  if (!sidebar) return;
  var touchStartX = 0, touchStartY = 0, tracking = false, horizontal = null;
  var SWIPE_THRESHOLD = 60, AXIS_LOCK = 10;

  function onTouchStart(e) {
    if (!isOpen()) return;
    var touch = e.touches[0];
    touchStartX = touch.clientX;
    touchStartY = touch.clientY;
    horizontal = null;
    tracking = true;
  }

  function onTouchMove(e) {
    if (!tracking) return;
    var touch = e.touches[0];
    var dx = touch.clientX - touchStartX;
    var dy = touch.clientY - touchStartY;
    if (horizontal === null && (Math.abs(dx) > AXIS_LOCK || Math.abs(dy) > AXIS_LOCK)) {
      horizontal = Math.abs(dx) > Math.abs(dy) ? 'x' : 'y';
      if (horizontal === 'y') { tracking = false; return; }
    }
    if (horizontal !== 'x') return;
    if (dx > 0) {
      var progress = Math.min(dx / 180, 1);
      sidebar.style.transform = 'translateX(' + (progress * 24) + '%)';
      sidebar.style.transition = 'none';
      dashboard.classList.add('swipe-dragging');
      if (e.cancelable) e.preventDefault();
    } else {
      sidebar.style.transform = '';
      dashboard.classList.remove('swipe-dragging');
    }
  }

  function onTouchEnd(e) {
    if (!tracking) return;
    tracking = false;
    var touch = e.changedTouches[0];
    var dx = touch.clientX - touchStartX;
    sidebar.style.transform = '';
    sidebar.style.transition = '';
    dashboard.classList.remove('swipe-dragging');
    if (horizontal === 'x' && dx > SWIPE_THRESHOLD) {
      close();
    }
  }

  document.addEventListener('touchstart', onTouchStart, { passive: true });
  document.addEventListener('touchmove', onTouchMove, { passive: false });
  document.addEventListener('touchend', onTouchEnd, { passive: true });
  document.addEventListener('touchcancel', function () {
    tracking = false;
    sidebar.style.transform = '';
    sidebar.style.transition = '';
    dashboard.classList.remove('swipe-dragging');
  }, { passive: true });

  // Dokunmatik olmayan cihazlar ve klavye kullanıcıları için görünür
  // kapatma butonu (menü başında, 40px dokunma hedefi).
  var brand = sidebar.querySelector('.brand');
  if (brand && !sidebar.querySelector('.mobile-nav-close')) {
    var closeBtn = document.createElement('button');
    closeBtn.type = 'button';
    closeBtn.className = 'mobile-nav-close';
    closeBtn.setAttribute('aria-label', 'Menüyü kapat');
    closeBtn.textContent = '✕';
    closeBtn.addEventListener('click', close);
    brand.appendChild(closeBtn);
  }
})();

