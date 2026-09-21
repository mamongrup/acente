// NEXUS Agency — Quick Search Modal (Ctrl+K)
(function () {
  var modalHtml =
    '<div id="quick-search-backdrop" role="dialog" aria-modal="true" aria-label="Hızlı arama" aria-hidden="true" style="display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(3,7,18,0.78);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);z-index:9999;align-items:center;justify-content:center;">' +
      '<div style="width:min(640px, calc(100% - 32px));background:rgba(15,23,42,0.92);border:1px solid rgba(255,255,255,0.12);border-radius:20px;padding:24px;box-shadow:0 25px 60px rgba(0,0,0,0.6);">' +
        '<div style="display:flex;align-items:center;gap:12px;border-bottom:1px solid rgba(255,255,255,0.08);padding-bottom:14px;margin-bottom:16px;">' +
          '<span style="color:#06b6d4;font-size:18px;" aria-hidden="true">🔍</span>' +
          '<input id="quick-search-input" type="search" autocomplete="off" placeholder="İlan kodu, ilan başlığı veya bölge ara… (Örn: VIL-001)" aria-label="Hızlı arama" style="flex:1;background:transparent;border:none;color:#fff;font-size:16px;outline:none;font-family:inherit;" />' +
          '<kbd style="background:rgba(255,255,255,0.08);padding:4px 8px;border-radius:6px;font-size:11px;color:#94a3b8;">ESC</kbd>' +
        '</div>' +
        '<div id="quick-search-results" role="listbox" aria-label="Arama sonuçları" style="max-height:300px;overflow-y:auto;display:flex;flex-direction:column;gap:8px;">' +
          '<p style="color:#64748b;font-size:13px;text-align:center;padding:20px;">Aramak için yazmaya başlayın…</p>' +
        '</div>' +
      '</div>' +
    '</div>';

  var container = document.createElement('div');
  container.innerHTML = modalHtml;
  document.body.appendChild(container);

  var backdrop = document.getElementById('quick-search-backdrop');
  var input    = document.getElementById('quick-search-input');
  var results  = document.getElementById('quick-search-results');

  // Debounce — her tuş vuruşunda istek atmayı önler
  var debounceTimer = null;
  function debounce(fn, delay) {
    return function () {
      var args = arguments;
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(function () { fn.apply(null, args); }, delay);
    };
  }

  // XSS-güvenli metin düğümü oluşturucu
  function safeText(str) {
    return document.createTextNode(str || '');
  }

  function setPlaceholder(msg, color) {
    results.textContent = '';
    var p = document.createElement('p');
    p.style.cssText = 'font-size:13px;text-align:center;padding:20px;color:' + (color || '#64748b') + ';';
    p.appendChild(safeText(msg));
    results.appendChild(p);
  }

  function openSearch() {
    backdrop.style.display = 'flex';
    backdrop.setAttribute('aria-hidden', 'false');
    input.value = '';
    setPlaceholder('Aramak için yazmaya başlayın…', '#64748b');
    if (window.FocusTrap) {
      // Tab sonuç listesi + input arasında döner, dışarı sızmaz; ESC kapatır
      FocusTrap.activate(backdrop, { onEscape: closeSearch, initialFocus: input });
    } else {
      input.focus();
    }
  }

  function closeSearch() {
    if (window.FocusTrap && FocusTrap.isActive(backdrop)) FocusTrap.deactivate();
    backdrop.style.display = 'none';
    backdrop.setAttribute('aria-hidden', 'true');
    clearTimeout(debounceTimer);
    var triggerBtn = document.getElementById('topbar-search-trigger');
    if (triggerBtn) triggerBtn.focus();
  }

  window.addEventListener('keydown', function (e) {
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
      e.preventDefault();
      if (backdrop.style.display === 'flex') closeSearch();
      else openSearch();
    }
    if (e.key === 'Escape' && backdrop.style.display === 'flex') {
      closeSearch();
    }
  });

  backdrop.addEventListener('click', function (e) {
    if (e.target === backdrop) closeSearch();
  });

  var triggerBtn = document.getElementById('topbar-search-trigger');
  if (triggerBtn) {
    triggerBtn.addEventListener('click', openSearch);
  }

  function doSearch(q) {
    fetch('/admin/listings/data', { credentials: 'same-origin' })
      .then(function (r) {
        if (!r.ok) throw new Error('network');
        return r.json();
      })
      .then(function (listings) {
        var matches = listings.filter(function (l) {
          return (l.code     && l.code.toLowerCase().indexOf(q)     !== -1) ||
                 (l.title    && l.title.toLowerCase().indexOf(q)    !== -1) ||
                 (l.locality && l.locality.toLowerCase().indexOf(q) !== -1);
        });

        if (!matches.length) {
          setPlaceholder('Sonuç bulunamadı.', '#94a3b8');
          return;
        }

        results.textContent = '';
        matches.slice(0, 6).forEach(function (m) {
          // XSS güvenliği: tüm dinamik içerik textContent ile ekleniyor
          var item = document.createElement('a');
          item.href = '/admin/listings#listings-workspace';
          item.setAttribute('role', 'option');
          item.style.cssText = 'display:flex;align-items:center;justify-content:space-between;padding:10px 14px;border-radius:10px;background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);text-decoration:none;';

          var left = document.createElement('div');

          var code = document.createElement('strong');
          code.style.cssText = 'color:#06b6d4;font-size:12px;';
          code.appendChild(safeText('[' + (m.code || 'NO-CODE') + ']'));
          left.appendChild(code);

          var titleSpan = document.createElement('span');
          titleSpan.style.cssText = 'color:#f1f5f9;font-size:13.5px;margin-left:6px;';
          titleSpan.appendChild(safeText(m.title || ''));
          left.appendChild(titleSpan);

          var meta = document.createElement('div');
          meta.style.cssText = 'font-size:11.5px;color:#94a3b8;margin-top:2px;';
          meta.appendChild(safeText((m.locality || '') + ' · ' + (m.category || '')));
          left.appendChild(meta);

          var price = document.createElement('span');
          price.style.cssText = 'font-weight:700;color:#10b981;font-size:13px;white-space:nowrap;margin-left:12px;';
          price.appendChild(safeText((m.priceMinor || '0') + ' ' + (m.currency || 'TRY')));

          item.appendChild(left);
          item.appendChild(price);
          results.appendChild(item);
        });
      })
      .catch(function () {
        setPlaceholder('Arama servisi geçici olarak yanıt vermedi.', '#f87171');
      });
  }

  input.addEventListener('input', debounce(function () {
    var q = input.value.trim().toLowerCase();
    if (!q) {
      setPlaceholder('Aramak için yazmaya başlayın…', '#64748b');
      return;
    }
    doSearch(q);
  }, 280));
})();
