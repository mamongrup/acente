// login-theme.js — Tema swatch butonlari + hover popover onizleme.
// Hem giris sayfasindaki login-theme-swatch-btn hem de topbar'daki
// [data-theme-choice] butonlarini calistirir.
(function () {
  // --- Palet tanimlari: bg, accent, text, isim ---
  var PALETTES = {
    dark:     { bg: '#0f172a', accent: '#22d3ee', text: '#f1f5f9', name: 'Abyss',      desc: 'Karanlik' },
    light:    { bg: '#f8fafc', accent: '#0891b2', text: '#0f172a', name: 'Porcelain',   desc: 'Aydinlik' },
    midnight: { bg: '#0c0a1a', accent: '#a78bfa', text: '#e8e0ff', name: 'Midnight',    desc: 'Gece moru' },
    sahra:    { bg: '#170f08', accent: '#f59e0b', text: '#fef3c7', name: 'Sahra',       desc: 'Col amberi' },
    auto:     { bg: '#0f172a', accent: '#94a3b8', text: '#e2e8f0', name: 'Otomatik',    desc: 'Saate gore' },
  };

  var popoverEl = null;

  function ensurePopover() {
    if (popoverEl) return popoverEl;
    popoverEl = document.createElement('div');
    popoverEl.className = 'theme-palette-popover';
    popoverEl.setAttribute('role', 'tooltip');
    popoverEl.setAttribute('aria-hidden', 'true');
    popoverEl.style.cssText = 'display:none;position:fixed;z-index:10002;pointer-events:none;opacity:0;transition:opacity 0.15s ease';
    document.body.appendChild(popoverEl);
    return popoverEl;
  }

  function showPopover(btn, themeKey) {
    var pal = PALETTES[themeKey];
    if (!pal) return;
    var pop = ensurePopover();
    pop.innerHTML =
      '<div class="palette-preview-card" style="background:' + pal.bg + ';color:' + pal.text + ';border:1px solid ' + pal.accent + '40;border-radius:10px;padding:12px 14px;min-width:150px;box-shadow:0 8px 24px rgba(0,0,0,0.3)">' +
        '<div style="font-size:11px;font-weight:700;color:' + pal.accent + ';margin-bottom:6px;letter-spacing:0.03em">' + pal.name + '</div>' +
        '<div style="display:flex;gap:6px;margin-bottom:8px">' +
          '<span style="width:18px;height:18px;border-radius:4px;background:' + pal.bg + ';border:1px solid ' + pal.accent + '30;display:inline-block" title="Arka plan"></span>' +
          '<span style="width:18px;height:18px;border-radius:4px;background:' + pal.accent + ';display:inline-block" title="Accent"></span>' +
          '<span style="width:18px;height:18px;border-radius:4px;background:' + pal.text + ';display:inline-block" title="Metin"></span>' +
        '</div>' +
        '<div style="font-size:10px;opacity:0.6">' + pal.desc + '</div>' +
      '</div>';
    pop.style.display = 'block';
    // Pozisyon: butonun hemen ustunde ortala
    var rect = btn.getBoundingClientRect();
    var popW = 170;
    var popH = 100;
    var left = rect.left + rect.width / 2 - popW / 2;
    var top = rect.top - popH - 8;
    // Ekran siniri kontrolu
    if (top < 4) top = rect.bottom + 8;
    if (left < 4) left = 4;
    if (left + popW > window.innerWidth - 4) left = window.innerWidth - popW - 4;
    pop.style.left = left + 'px';
    pop.style.top = top + 'px';
    requestAnimationFrame(function () { pop.style.opacity = '1'; });
  }

  function hidePopover() {
    if (!popoverEl) return;
    popoverEl.style.opacity = '0';
    setTimeout(function () {
      if (popoverEl) popoverEl.style.display = 'none';
    }, 150);
  }

  // --- Swatch butonlarini bagla ---
  function bindSwatches(selector, keyAttr) {
    var btns = document.querySelectorAll(selector);
    btns.forEach(function (btn) {
      var key = btn.getAttribute(keyAttr);
      if (!key) return;
      btn.addEventListener('mouseenter', function () { showPopover(btn, key); });
      btn.addEventListener('mouseleave', hidePopover);
      btn.addEventListener('focus', function () { showPopover(btn, key); });
      btn.addEventListener('blur', hidePopover);
    });
  }

  // Giris sayfasindaki swatch'lar
  bindSwatches('.login-theme-swatch-btn', 'data-theme-value');

  // Topbar'daki swatch'lar
  bindSwatches('[data-theme-choice]', 'data-theme-choice');

  // Footer tema kartlari
  bindSwatches('[data-theme-pick]', 'data-theme-pick');

  // --- Giris sayfasinda aktif isaret + tiklama ---
  var loginSwatches = document.querySelectorAll('.login-theme-swatch-btn');
  if (loginSwatches.length) {
    var current = document.documentElement.getAttribute('data-theme') || 'dark';
    loginSwatches.forEach(function (btn) {
      var val = btn.getAttribute('data-theme-value');
      if (val === current) btn.classList.add('active');
    });
    loginSwatches.forEach(function (btn) {
      btn.addEventListener('click', function () {
        var val = btn.getAttribute('data-theme-value');
        if (!val) return;
        try { localStorage.setItem('nexus-theme', val); } catch (e) {}
        document.documentElement.setAttribute('data-theme', val);
        loginSwatches.forEach(function (b) { b.classList.remove('active'); });
        btn.classList.add('active');
        // Footer kartlarini da guncelle
        syncFooterCards(val);
      });
    });
  }

  // --- Footer tema kartlari tiklama + aktif durum ---
  var footerCards = document.querySelectorAll('[data-theme-pick]');
  if (footerCards.length) {
    function syncFooterCards(theme) {
      footerCards.forEach(function (card) {
        if (card.getAttribute('data-theme-pick') === theme) {
          card.classList.add('active');
        } else {
          card.classList.remove('active');
        }
      });
    }
    // Ilk durumu ayarla
    var initTheme = document.documentElement.getAttribute('data-theme') || 'dark';
    syncFooterCards(initTheme);
    // Tiklama
    footerCards.forEach(function (card) {
      card.addEventListener('click', function () {
        var val = card.getAttribute('data-theme-pick');
        if (!val) return;
        // theme-toggle.js'in apply/mirror/persist fonksiyonlari varsa onlari kullan
        if (typeof window.ThemeToggle !== 'undefined') {
          window.ThemeToggle.set(val);
        } else {
          try { localStorage.setItem('nexus-theme', val); } catch (e) {}
          document.documentElement.setAttribute('data-theme', val);
        }
        syncFooterCards(val);
        // Giris sayfasindaki swatch'lari da guncelle
        var loginSw = document.querySelectorAll('.login-theme-swatch-btn');
        loginSw.forEach(function (b) {
          b.classList.toggle('active', b.getAttribute('data-theme-value') === val);
        });
      });
    });
    // theme-toggle.js tarafindan tema degistirildiginde dinle
    document.addEventListener('themechange', function (e) {
      syncFooterCards(e.detail && e.detail.theme ? e.detail.theme : document.documentElement.getAttribute('data-theme') || 'dark');
    });
  }
})();
