// NEXUS Agency — dashboard metrikleri + sparkline görselleştirmesi.
// Değerler /admin/dashboard/data, 14 günlük seriler /admin/dashboard/series
// üzerinden gelir. Seriler gerçek DB kümeleridir (agency.listings,
// agency.reservations, agency.contact_requests) — mock yok.
// Serili metric kartları tıklanabilir: 14 günlük büyük trend grafiği modalı.
(function () {
  if (!document.getElementById('dashboard-metrics')) return;

  // ---- Büyük trend modalı -------------------------------------------------
  var SERIES_META = {
    published: { label: 'Yayında', color: 'var(--neon-cyan)', icon: '📦' },
    pending: { label: 'Bekleyen talep', color: 'var(--neon-amber)', icon: '⏳' },
    upcoming: { label: 'Yaklaşan giriş', color: 'var(--neon-emerald)', icon: '🛎️' },
    contacts: { label: 'Yeni talepler', color: 'var(--neon-purple)', icon: '✉️' },
  };
  var CW = 640, CH = 260, CPAD = { top: 18, right: 18, bottom: 30, left: 40 };
  var modal = null, chartData = null, activeKeys = [], cursorIdx = -1, chartSvg = null;
  var currentDays = 14; // aralık seçici durumu

  // Renk paleti: çoklu seriler için hardcoded CSS değerleri (var() SVG'de çalışmaz)
  var SERIES_COLORS = {
    published: { main: '#22d3ee', area: 'rgba(34,211,238,0.12)' },
    pending:   { main: '#f59e0b', area: 'rgba(245,158,11,0.12)' },
    upcoming:  { main: '#34d399', area: 'rgba(52,211,153,0.12)' },
    contacts:  { main: '#a78bfa', area: 'rgba(167,139,250,0.12)' },
  };

  // Serileri belirli bir aralıkla çek
  function fetchSeries(days) {
    return fetch('/admin/dashboard/series?days=' + days, { credentials: 'same-origin', cache: 'no-store' })
      .then(function (r) { if (!r.ok) throw new Error('seriler'); return r.json(); });
  }

  // 7 günlük değişim yüzdesi hesapla: (son - 7g önce) / 7g önce * 100
  function calcDelta(key) {
    if (!chartData) return null;
    var raw = chartData[key];
    if (!raw || raw.length < 2) return null;
    var data = raw.map(Number);
    var last = data[data.length - 1];
    var agoIdx = Math.max(0, data.length - 8);
    var ago = data[agoIdx];
    var diff = last - ago;
    var pct = ago !== 0 ? ((diff / ago) * 100) : (diff > 0 ? 100 : diff < 0 ? -100 : 0);
    return { diff: diff, pct: Math.round(pct * 10) / 10 };
  }

  function deltaText(diff, pct) {
    if (diff === 0) return 'sabit';
    var arrow = diff > 0 ? '▲' : '▼';
    var sign = diff > 0 ? '+' : '';
    return arrow + ' ' + sign + diff + ' (' + sign + pct + '%)';
  }

  function updateChartTitle() {
    var title = modal ? modal.querySelector('#trend-chart-title') : null;
    var sub = modal ? modal.querySelector('.chart-modal-sub') : null;
    if (!title) return;
    // Başlık
    if (activeKeys.length > 1) {
      var names = activeKeys.map(function (k) { return SERIES_META[k] ? SERIES_META[k].label : k; });
      title.textContent = names.join(' + ') + ' — ' + currentDays + ' günlük karşılaştırma';
    } else if (activeKeys.length === 1 && SERIES_META[activeKeys[0]]) {
      var m = SERIES_META[activeKeys[0]];
      title.textContent = m.icon + ' ' + m.label + ' — ' + currentDays + ' günlük trend';
    } else {
      title.textContent = 'Trend grafiği';
    }
    // Alt başlık: 7g değişim yüzdesi
    if (sub && chartData) {
      var parts = [];
      activeKeys.forEach(function (k) {
        var delta = calcDelta(k);
        if (!delta) return;
        var meta = SERIES_META[k] || { label: k, icon: '' };
        var cls = delta.diff > 0 ? 'delta-up' : delta.diff < 0 ? 'delta-down' : 'delta-flat';
        parts.push(meta.icon + ' <span class="' + cls + '">' + deltaText(delta.diff, delta.pct) + '</span>');
      });
      if (parts.length) {
        sub.innerHTML = 'Son 7 gün: ' + parts.join(' · ');
      } else {
        sub.textContent = 'Acente veritabanından günlük kümeler';
      }
    }
  }

  function openTrendModal(key) {
    modal = document.getElementById('trend-chart-modal');
    if (!modal) return;
    activeKeys = [key];
    updateChartTitle();
    modal.removeAttribute('hidden');
    document.body.classList.add('modal-open');
    fetchSeries(currentDays)
      .then(function (s) { chartData = s; paintBigChart(); })
      .catch(function () {
        var host = document.getElementById('trend-chart-host');
        if (host) host.textContent = 'Seriler yüklenemedi — sayfayı yenileyip tekrar deneyin.';
      });
    // Aralık seçici butonlarını başlat
    var picker = document.getElementById('chart-range-picker');
    if (picker && !picker._bound) {
      picker._bound = true;
      picker.addEventListener('click', function (ev) {
        var btn = ev.target.closest('.range-btn');
        if (!btn) return;
        var days = parseInt(btn.getAttribute('data-days'), 10);
        if (days === currentDays) return;
        currentDays = days;
        picker.querySelectorAll('.range-btn').forEach(function (b) { b.classList.remove('active'); });
        btn.classList.add('active');
        updateChartTitle();
        fetchSeries(currentDays)
          .then(function (s) { chartData = s; cursorIdx = -1; paintBigChart(); })
          .catch(function () {});
      });
    }
    var close = modal.querySelector('.chart-modal-close');
    if (close) close.focus();
    if (window.FocusTrap) window.FocusTrap.activate(modal);
  }

  function closeTrendModal() {
    if (!modal) return;
    modal.setAttribute('hidden', 'hidden');
    document.body.classList.remove('modal-open');
    cursorIdx = -1;
    if (window.FocusTrap) window.FocusTrap.deactivate();
  }

  // ---- Çoklu seri grafik boyama -------------------------------------------
  function paintBigChart() {
    var host = document.getElementById('trend-chart-host');
    if (!host || !chartData || !activeKeys.length) return;
    var labels = chartData.labels || [];
    var n = labels.length;
    if (!n) { host.textContent = 'Veri yok.'; return; }
    // Seçili serilerin verisini topla
    var seriesList = [];
    activeKeys.forEach(function (k) {
      var raw = chartData[k];
      if (raw && raw.length) seriesList.push({ key: k, data: raw.map(Number) });
    });
    if (!seriesList.length) { host.textContent = 'Veri yok.'; return; }
    // Paylaşılan Y ekseni: tüm aktif serilerin birleşik min/max'ı
    var gMin = Infinity, gMax = -Infinity;
    seriesList.forEach(function (s) {
      s.data.forEach(function (v) { if (v < gMin) gMin = v; if (v > gMax) gMax = v; });
    });
    if (gMin === gMax) { gMax = gMin + 1; }
    buildTabs();
    host.textContent = '';
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('viewBox', '0 0 ' + CW + ' ' + CH);
    svg.setAttribute('role', 'img');
    svg.setAttribute('aria-label', activeKeys.length + ' serinin karşılaştırmalı trend grafiği');
    svg.classList.add('trend-svg');
    var innerW = CW - CPAD.left - CPAD.right;
    var innerH = CH - CPAD.top - CPAD.bottom;
    var px = function (i) { return CPAD.left + (i * innerW) / (n - 1); };
    var py = function (v) { return CPAD.top + innerH - ((v - gMin) * innerH) / (gMax - gMin); };
    // Izgara + y ekseni etiketleri (4 çizgi)
    for (var g = 0; g <= 3; g++) {
      var val = gMin + ((gMax - gMin) * g) / 3;
      var gy = py(val);
      var gl = document.createElementNS(ns, 'line');
      gl.setAttribute('x1', CPAD.left); gl.setAttribute('x2', CW - CPAD.right);
      gl.setAttribute('y1', gy.toFixed(1)); gl.setAttribute('y2', gy.toFixed(1));
      gl.setAttribute('class', 'trend-grid');
      svg.appendChild(gl);
      var gt = document.createElementNS(ns, 'text');
      gt.setAttribute('x', CPAD.left - 8); gt.setAttribute('y', (gy + 3.5).toFixed(1));
      gt.setAttribute('text-anchor', 'end'); gt.setAttribute('class', 'trend-axis');
      gt.textContent = Math.round(val);
      svg.appendChild(gt);
    }
    // Her seri için: alan dolgusu + çizgi + noktalar
    seriesList.forEach(function (s) {
      var colors = SERIES_COLORS[s.key] || { main: '#94a3b8', area: 'rgba(148,163,184,0.12)' };
      var pts = s.data.map(function (v, i) { return px(i).toFixed(1) + ',' + py(v).toFixed(1); });
      // Alan dolgusu
      var area = document.createElementNS(ns, 'polygon');
      area.setAttribute('points',
        CPAD.left + ',' + (CPAD.top + innerH) + ' ' + pts.join(' ') + ' ' + (CW - CPAD.right) + ',' + (CPAD.top + innerH));
      area.setAttribute('class', 'trend-area');
      area.setAttribute('fill', colors.area);
      svg.appendChild(area);
      // Çizgi
      var line = document.createElementNS(ns, 'polyline');
      line.setAttribute('points', pts.join(' '));
      line.setAttribute('class', 'trend-line');
      line.setAttribute('style', 'stroke:' + colors.main);
      svg.appendChild(line);
      // Noktalar
      for (var d = 0; d < s.data.length; d++) {
        var dot = document.createElementNS(ns, 'circle');
        dot.setAttribute('cx', px(d).toFixed(1)); dot.setAttribute('cy', py(s.data[d]).toFixed(1));
        dot.setAttribute('r', '3.2'); dot.setAttribute('class', 'trend-dot');
        dot.setAttribute('data-idx', String(d));
        dot.setAttribute('data-key', s.key);
        dot.setAttribute('fill', colors.main);
        svg.appendChild(dot);
      }
    });
    // X etiketleri (her 2. gün, 30 günde her 5. gün)
    var xStep = n > 20 ? 5 : 2;
    for (var i = 0; i < labels.length; i += xStep) {
      var xt = document.createElementNS(ns, 'text');
      xt.setAttribute('x', px(i).toFixed(1)); xt.setAttribute('y', CH - 8);
      xt.setAttribute('text-anchor', 'middle'); xt.setAttribute('class', 'trend-axis');
      xt.textContent = labels[i];
      svg.appendChild(xt);
    }
    // Etkileşim katmanı: gün başına hitbox
    for (var d = 0; d < n; d++) {
      var hit = document.createElementNS(ns, 'rect');
      hit.setAttribute('x', (px(d) - innerW / (n - 1) / 2).toFixed(1));
      hit.setAttribute('y', CPAD.top);
      hit.setAttribute('width', (innerW / (n - 1)).toFixed(1));
      hit.setAttribute('height', innerH);
      hit.setAttribute('fill', 'transparent');
      hit.setAttribute('class', 'trend-hit');
      hit.setAttribute('data-idx', String(d));
      hit.setAttribute('tabindex', '-1');
      svg.appendChild(hit);
    }
    // Legend: seçili serilerin renk göstergesi
    if (seriesList.length > 1) {
      var lg = document.createElementNS(ns, 'g'); lg.setAttribute('class', 'trend-legend');
      var lx = CPAD.left;
      seriesList.forEach(function (s) {
        var colors = SERIES_COLORS[s.key] || { main: '#94a3b8' };
        var meta = SERIES_META[s.key] || { label: s.key };
        var rect = document.createElementNS(ns, 'rect');
        rect.setAttribute('x', String(lx)); rect.setAttribute('y', String(CH - 22));
        rect.setAttribute('width', '10'); rect.setAttribute('height', '3');
        rect.setAttribute('rx', '1.5'); rect.setAttribute('fill', colors.main);
        lg.appendChild(rect);
        var txt = document.createElementNS(ns, 'text');
        txt.setAttribute('x', String(lx + 14)); txt.setAttribute('y', String(CH - 18));
        txt.setAttribute('class', 'trend-axis'); txt.textContent = meta.label;
        lg.appendChild(txt);
        lx += meta.label.length * 6.5 + 28;
      });
      svg.appendChild(lg);
    }
    // Klavye
    svg.setAttribute('tabindex', '0');
    svg.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowRight') { setCursor(Math.min(n - 1, Math.max(0, cursorIdx + 1))); e.preventDefault(); }
      else if (e.key === 'ArrowLeft') { setCursor(Math.max(0, cursorIdx - 1)); e.preventDefault(); }
      else if (e.key === 'Escape') { closeTrendModal(); }
    });
    chartSvg = svg;
    host.appendChild(svg);
    setCursor(n - 1);
  }

  // ---- Cursor / tooltip (çoklu seri) --------------------------------------
  function setCursor(idx) {
    if (!chartSvg || !chartData || !activeKeys.length) return;
    var labels = chartData.labels || [];
    var n = labels.length;
    if (idx < 0 || idx >= n) return;
    cursorIdx = idx;
    // Nokta vurgusu: sadece ilgili gün
    chartSvg.querySelectorAll('.trend-dot').forEach(function (dot) {
      var on = Number(dot.getAttribute('data-idx')) === idx;
      dot.classList.toggle('active', on);
    });
    // Tooltip oluştur
    var tip = chartSvg.querySelector('.trend-tip');
    if (!tip) {
      var ns = 'http://www.w3.org/2000/svg';
      var g = document.createElementNS(ns, 'g'); g.setAttribute('class', 'trend-tip');
      var box = document.createElementNS(ns, 'rect'); box.setAttribute('class', 'trend-tip-box');
      var tx = document.createElementNS(ns, 'text'); tx.setAttribute('class', 'trend-tip-text');
      g.appendChild(box); g.appendChild(tx); chartSvg.appendChild(g); tip = g;
    }
    // Tooltip içeriği: her aktif seri için değer
    var lines = [labels[idx] || ''];
    activeKeys.forEach(function (k) {
      var raw = chartData[k];
      if (!raw || !raw.length) return;
      var meta = SERIES_META[k] || { label: k, icon: '' };
      var val = raw[idx];
      var unit = document.querySelector('.metric[data-series="' + k + '"]');
      unit = unit ? (unit.getAttribute('data-unit') || '') : '';
      lines.push(meta.icon + ' ' + val + (unit ? ' ' + unit : ''));
    });
    var text = lines.join('  ');
    var tx = tip.querySelector('text'); tx.textContent = text;
    var w = Math.max(60, text.length * 5.8 + 16);
    var cx = CPAD.left + (idx * (CW - CPAD.left - CPAD.right)) / (n - 1);
    var bx = Math.min(Math.max(cx - w / 2, 4), CW - w - 4);
    var box = tip.querySelector('rect');
    box.setAttribute('x', bx.toFixed(1)); box.setAttribute('y', 2);
    box.setAttribute('width', w.toFixed(1)); box.setAttribute('height', 22);
    box.setAttribute('rx', '6');
    tx.setAttribute('x', (bx + w / 2).toFixed(1)); tx.setAttribute('y', 17);
    tx.setAttribute('text-anchor', 'middle');
    // Dikey imleç çizgisi
    var guide = chartSvg.querySelector('.trend-guide');
    if (!guide) {
      var gl = document.createElementNS('http://www.w3.org/2000/svg', 'line');
      gl.setAttribute('class', 'trend-guide'); chartSvg.appendChild(gl); guide = gl;
    }
    guide.setAttribute('x1', cx.toFixed(1)); guide.setAttribute('x2', cx.toFixed(1));
    guide.setAttribute('y1', CPAD.top); guide.setAttribute('y2', CH - CPAD.bottom);
  }

  // ---- Tab butonları (çoklu seçim toggle) ----------------------------------
  // İlk tıklama: o seriyi seç, diğerlerini kaldır.
  // Sonraki tıklama: seriyi listeden çıkar veya ekle (en az bir seride kalır).
  function buildTabs() {
    var tabs = document.getElementById('chart-series-tabs');
    if (!tabs || !chartData) return;
    tabs.textContent = '';
    Object.keys(SERIES_META).forEach(function (k) {
      if (!chartData[k] || !chartData[k].length) return;
      var selected = activeKeys.indexOf(k) !== -1;
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'chart-tab' + (selected ? ' active' : '');
      b.setAttribute('role', 'tab');
      b.setAttribute('aria-selected', selected ? 'true' : 'false');
      b.setAttribute('data-key', k);
      b.setAttribute('aria-label', SERIES_META[k].label + (selected ? ' (seçili)' : '') + ' — çoklu seçim için tekrar tıklayın');
      b.textContent = SERIES_META[k].icon + ' ' + SERIES_META[k].label;
      b.addEventListener('click', function () {
        var idx = activeKeys.indexOf(k);
        if (idx !== -1) {
          // Zaten seçili → çıkar (en az bir seride kal)
          if (activeKeys.length > 1) {
            activeKeys.splice(idx, 1);
          }
        } else {
          // Seçili değil → ekle
          activeKeys.push(k);
        }
        updateChartTitle();
        paintBigChart();
      });
      tabs.appendChild(b);
    });
  }

  function bindTrendModal() {
    var grid = document.getElementById('dashboard-metrics');
    if (!grid) return;
    grid.addEventListener('click', function (ev) {
      var card = ev.target.closest('.metric[data-series]');
      if (card) openTrendModal(card.getAttribute('data-series'));
    });
    grid.addEventListener('keydown', function (ev) {
      if (ev.key !== 'Enter' && ev.key !== ' ') return;
      var card = ev.target.closest('.metric[data-series]');
      if (card) { ev.preventDefault(); openTrendModal(card.getAttribute('data-series')); }
    });
    modal = document.getElementById('trend-chart-modal');
    if (!modal) return;
    modal.addEventListener('click', function (ev) {
      if (ev.target === modal) closeTrendModal();
      else if (ev.target.closest('.chart-modal-close')) closeTrendModal();
      else {
        var hit = ev.target.closest('.trend-hit');
        if (hit) setCursor(Number(hit.getAttribute('data-idx')));
      }
    });
    modal.addEventListener('mousemove', function (ev) {
      var hit = ev.target.closest('.trend-hit');
      if (hit) setCursor(Number(hit.getAttribute('data-idx')));
    });
    document.addEventListener('keydown', function (ev) {
      if (ev.key === 'Escape' && modal && !modal.hasAttribute('hidden')) closeTrendModal();
    });
  }
  bindTrendModal();

  function renderValue(id, text) {
    var el = document.getElementById(id);
    if (el) el.textContent = text;
  }

  // ---- Trend deltası ------------------------------------------------------
  // "▲ +2 / 7g" biçiminde; yükseliş emerald, düşüş rose, düz muted.
  function renderTrend(card, series) {
    var trend = card.querySelector('.metric-trend');
    if (!trend || series.length < 2) return;
    var last = series[series.length - 1];
    var weekAgo = series[series.length - 8]; // 7 gün önceki gün
    var diff = last - weekAgo;
    trend.className = 'metric-trend ' + (diff > 0 ? 'up' : diff < 0 ? 'down' : 'flat');
    var arrow = diff > 0 ? '▲' : diff < 0 ? '▼' : '▬';
    var sign = diff > 0 ? '+' : '';
    trend.textContent = weekAgo === last && diff === 0
      ? '▬ sabit'
      : arrow + ' ' + sign + diff + ' / 7g';
    trend.setAttribute('title', 'Son 7 gün değişimi: ' + (diff > 0 ? '+' : '') + diff);
  }

  // ---- Sparkline (saf SVG, bağımlılık yok) --------------------------------
  var W = 160, H = 36, PAD = 3;
  function sparkline(series) {
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
    svg.setAttribute('preserveAspectRatio', 'none');
    svg.classList.add('metric-spark-svg');
    var max = Math.max.apply(null, series);
    var min = Math.min.apply(null, series);
    var span = max - min;
    if (span === 0) span = 1; // düz çizgi de çizilsin
    var n = series.length;
    var px = function (i) { return PAD + (i * (W - 2 * PAD)) / (n - 1); };
    var py = function (v) { return H - PAD - ((v - min) * (H - 2 * PAD)) / span; };
    var pts = series.map(function (v, i) { return px(i).toFixed(1) + ',' + py(v).toFixed(1); });
    var line = document.createElementNS(ns, 'polyline');
    line.setAttribute('points', pts.join(' '));
    line.setAttribute('class', 'spark-line');
    svg.appendChild(line);
    // Son nokta vurgusu
    var dot = document.createElementNS(ns, 'circle');
    dot.setAttribute('cx', px(n - 1).toFixed(1));
    dot.setAttribute('cy', py(series[n - 1]).toFixed(1));
    dot.setAttribute('r', '2.6');
    dot.setAttribute('class', 'spark-dot');
    svg.appendChild(dot);
    // Hover katmanı: gün başına şeffaf hit + dikey imleç kılavuzu.
    // Tooltip HTML katmanında (preserveAspectRatio=none SVG metnini esitir).
    var guide = document.createElementNS(ns, 'line');
    guide.setAttribute('class', 'spark-guide');
    guide.setAttribute('y1', '0'); guide.setAttribute('y2', String(H));
    svg.appendChild(guide);
    var step = (W - 2 * PAD) / (n - 1);
    for (var d = 0; d < n; d++) {
      var hit = document.createElementNS(ns, 'rect');
      hit.setAttribute('x', (PAD + d * step - step / 2).toFixed(1));
      hit.setAttribute('y', '0');
      hit.setAttribute('width', step.toFixed(1));
      hit.setAttribute('height', String(H));
      hit.setAttribute('class', 'spark-hit');
      hit.setAttribute('data-idx', String(d));
      svg.appendChild(hit);
    }
    return svg;
  }

  // Spark hover: gün bazlı değer etiketi + trend deltası (7g önceki ile fark).
  // Klavye erişilebilirliği: tabindex=0 ile kartlar focuslanabilir, sol/sağ
  // ok tuşlarıyla gün gezilir, aria-live ile ekran okuyucuya duyurulur.
  function bindSparkHover(card, svg, series, labels, unit) {
    var tip = card.querySelector('.spark-tip');
    if (!tip) {
      tip = document.createElement('div');
      tip.className = 'spark-tip';
      tip.setAttribute('aria-hidden', 'true');
      card.appendChild(tip);
    }
    var announce = card.querySelector('.metric-announce');
    var guide = svg.querySelector('.spark-guide');
    var hoverDot = svg.querySelector('.spark-hover-dot');
    if (!hoverDot) {
      var ns2 = 'http://www.w3.org/2000/svg';
      hoverDot = document.createElementNS(ns2, 'circle');
      hoverDot.setAttribute('r', '3.2');
      hoverDot.setAttribute('class', 'spark-hover-dot');
      svg.appendChild(hoverDot);
    }
    var max = Math.max.apply(null, series);
    var min = Math.min.apply(null, series);
    var span = max - min; if (span === 0) span = 1;
    var pyAt = function (v) { return H - PAD - ((v - min) * (H - 2 * PAD)) / span; };
    // Aktif klavye odağı indeksi (mouse'da -1)
    var kbIdx = -1;

    function showTooltip(idx, clientX) {
      var v = series[idx];
      var text = (labels[idx] || '') + ' · ' + v + (unit ? ' ' + unit : '');
      // Trend deltası: bu gün vs 7 gün önce
      var weekAgoIdx = idx - 7;
      if (weekAgoIdx >= 0 && series[weekAgoIdx] != null) {
        var diff = v - series[weekAgoIdx];
        if (diff !== 0) {
          var arrow = diff > 0 ? '↑' : '↓';
          var sign = diff > 0 ? '+' : '';
          text += '  ' + arrow + ' ' + sign + diff + ' (7g)';
        }
      }
      tip.textContent = text;
      tip.classList.add('show');
      var cardW = card.getBoundingClientRect().width || 1;
      var xPct = clientX != null
        ? ((clientX - card.getBoundingClientRect().left) / cardW) * 100
        : (PAD + idx * ((W - 2 * PAD) / (series.length - 1))) / W * 100;
      var half = Math.min(50, (tip.offsetWidth / cardW) * 50);
      var left = Math.min(100 - half - 2, Math.max(half + 2, xPct));
      tip.style.left = left.toFixed(2) + '%';
      if (guide) {
        var gx = (PAD + idx * ((W - 2 * PAD) / (series.length - 1))).toFixed(1);
        guide.setAttribute('x1', gx); guide.setAttribute('x2', gx);
        guide.classList.add('show');
      }
      hoverDot.setAttribute('cx', (PAD + idx * ((W - 2 * PAD) / (series.length - 1))).toFixed(1));
      hoverDot.setAttribute('cy', pyAt(v).toFixed(1));
      hoverDot.classList.add('show');
    }
    function announceValue(idx) {
      if (!announce) return;
      var v = series[idx];
      var msg = (labels[idx] || 'Son gün') + ': ' + v + (unit ? ' ' + unit : '');
      var weekAgoIdx = idx - 7;
      if (weekAgoIdx >= 0 && series[weekAgoIdx] != null) {
        var diff = v - series[weekAgoIdx];
        if (diff !== 0) {
          msg += '. 7 gün önceye göre ' + (diff > 0 ? '+' : '') + diff;
        }
      }
      announce.textContent = msg;
    }
    function hide() {
      tip.classList.remove('show');
      if (guide) guide.classList.remove('show');
      hoverDot.classList.remove('show');
      kbIdx = -1;
    }
    function focusIdx(idx) {
      idx = Math.min(series.length - 1, Math.max(0, idx));
      kbIdx = idx;
      showTooltip(idx, null);
      announceValue(idx);
    }
    // Mouse hover
    svg.addEventListener('mousemove', function (e) {
      var rect = svg.getBoundingClientRect();
      if (!rect.width) return;
      var xView = ((e.clientX - rect.left) / rect.width) * W;
      var step = (W - 2 * PAD) / (series.length - 1);
      var idx = Math.round((xView - PAD) / step);
      idx = Math.min(series.length - 1, Math.max(0, idx));
      kbIdx = -1;
      showTooltip(idx, e.clientX);
    });
    svg.addEventListener('mouseleave', hide);
    // Klavye: tabindex ve ok tuşları
    svg.setAttribute('tabindex', '0');
    svg.setAttribute('role', 'img');
    svg.setAttribute('aria-label', 'Sparkline — sol/sağ ok tuşlarıyla günleri gezin');
    svg.addEventListener('focus', function () {
      // Odaklanınca son günün değerini göster
      if (kbIdx < 0) focusIdx(series.length - 1);
    });
    svg.addEventListener('blur', function () {
      // Mouse hala üzerindeyse blur'ı ertele
      setTimeout(function () {
        if (!svg.matches(':hover')) hide();
      }, 120);
    });
    svg.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowRight') {
        e.preventDefault();
        focusIdx(kbIdx < 0 ? series.length - 1 : kbIdx + 1);
      } else if (e.key === 'ArrowLeft') {
        e.preventDefault();
        focusIdx(kbIdx < 0 ? series.length - 2 : kbIdx - 1);
      } else if (e.key === 'Home') {
        e.preventDefault(); focusIdx(0);
      } else if (e.key === 'End') {
        e.preventDefault(); focusIdx(series.length - 1);
      }
    });
  }

  function renderSpark(card, series, labels) {
    var host = card.querySelector('.metric-spark');
    if (!host) return;
    host.textContent = '';
    var svg = sparkline(series);
    host.appendChild(svg);
    bindSparkHover(card, svg, series, labels || [], card.getAttribute('data-unit') || '');
  }

  // ---- Haftalık toplam etiketi --------------------------------------------
  // Son 7 günün toplamını "Bu hafta: X" biçiminde küçük etiket olarak gösterir.
  // İlk yüklemede sayaç animasyonu ile 0'dan hedefe sayar (600ms ease-out).
  // Yenilemede (30sn tick) yalnızca değer değiştiyse animasyon oynar.
  var weeklyPrev = {}; // card-key → bir önceki toplam (animasyon bypass)

  function renderWeeklyTotal(card, series, unit) {
    var el = card.querySelector('.metric-weekly');
    if (!el || series.length < 1) return;
    var last7 = series.slice(-7);
    var sum = 0;
    for (var i = 0; i < last7.length; i++) sum += Number(last7[i]);
    var key = card.getAttribute('data-series') || '';
    var prev = weeklyPrev[key];
    weeklyPrev[key] = sum;
    // Önceki değerle aynıysa atla (yenilemede gereksiz animasyon)
    if (prev === sum) return;
    var startVal = prev != null ? prev : 0;
    var from = Math.min(startVal, sum);
    var to = Math.max(startVal, sum);
    // prefers-reduced-motion: anında yaz
    if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      el.textContent = 'Bu hafta: ' + sum + (unit ? ' ' + unit : '');
      return;
    }
    var duration = 600;
    var startTime = null;
    el.classList.add('animating');
    function tick(now) {
      if (!startTime) startTime = now;
      var elapsed = now - startTime;
      var t = Math.min(1, elapsed / duration);
      // ease-out cubic
      var eased = 1 - Math.pow(1 - t, 3);
      var current = Math.round(startVal + (sum - startVal) * eased);
      el.textContent = 'Bu hafta: ' + current + (unit ? ' ' + unit : '');
      if (t < 1) {
        requestAnimationFrame(tick);
      } else {
        el.classList.remove('animating');
      }
    }
    requestAnimationFrame(tick);
  }

  // ---- Serileri getir ve kartlara dağıt ----------------------------------
  // Otomatik yenileme: 30 sn'de bir; yalnızca sayfa görünürken (visibilitychange
  // guard'ı) çalışır. Değer değişen kartlarda .value-bump pulse animasyonu oynar.
  var REFRESH_KEY = 'nexus-refresh-interval';
  var REFRESH_MS = parseInt(localStorage.getItem(REFRESH_KEY) || '30', 10) * 1000;
  var refreshTimer = null;
  var lastValues = {}; // kart id → son değer (değişim algılama)

  function loadSeries() {
    return fetch('/admin/dashboard/series', { credentials: 'same-origin', cache: 'no-store' })
      .then(function (r) { if (!r.ok) throw new Error('seriler'); return r.json(); })
      .then(function (s) {
        var labels = s.labels || [];
        if (chartData) chartData = s; // açık modal varsa verisini tazele
        document.querySelectorAll('.metric[data-series]').forEach(function (card) {
          var key = card.getAttribute('data-series');
          var series = s[key];
          if (!series || !series.length) return;
          series = series.map(Number);
          var sparkHost = card.querySelector('.metric-spark svg');
          if (!sparkHost) {
            renderSpark(card, series, labels);
          } else {
            // Yenileme: yalnızca çizgiyi/noktayı güncelle — hover katmanını
            // yeniden bağlamadan nokta konumlarını tazelemek yeterli değil;
            // en basiti yeniden render (hover katmanı renderSpark'ta bağlanır).
            renderSpark(card, series, labels);
          }
          renderTrend(card, series);
          renderWeeklyTotal(card, series, card.getAttribute('data-unit') || '');
        });
        // Açık trend modalı yeniden boyansın (veri değiştiyse)
        if (modal && !modal.hasAttribute('hidden') && activeKey) paintBigChart();
      })
      .catch(function () {
        // Seriler opsiyonel — kartlar değerlerle düzgün kalır, spark alanı boş.
      });
  }

  // ---- Mevcut canlı değerler ---------------------------------------------
  function loadValues() {
    return fetch('/admin/dashboard/data', { credentials: 'same-origin', cache: 'no-store' })
      .then(function (response) { if (!response.ok) throw new Error('Genel bakış yüklenemedi'); return response.json(); })
      .then(function (data) {
        bumpIfChanged('dashboard-published', data.published);
        bumpIfChanged('dashboard-pending', data.pending);
        bumpIfChanged('dashboard-upcoming', data.upcoming);
        bumpIfChanged('dashboard-nexus', data.nexus);
        renderValue('dashboard-published', data.published);
        renderValue('dashboard-pending', data.pending);
        renderValue('dashboard-upcoming', data.upcoming);
        renderValue('dashboard-nexus', data.nexus);
        updateTimestamp();
      })
      .catch(function () {
        renderValue('dashboard-nexus', 'Kontrol edilemedi');
      });
  }

  // Değer değiştiyse yönüyle renkli pulse animasyonu (ilk yüklemede oynamaz).
  // Artış → emerald kenar parlaması, azalış → rose kenar parlaması.
  function bumpIfChanged(id, value) {
    if (!(id in lastValues)) {
      lastValues[id] = String(value);
      return;
    }
    var old = parseInt(lastValues[id], 10);
    var cur = parseInt(String(value), 10);
    if (old === cur) return;
    lastValues[id] = String(value);
    var el = document.getElementById(id);
    if (!el) return;
    // Önceki animasyon sınıflarını temizle
    el.classList.remove('value-bump', 'value-bump-up', 'value-bump-down');
    // Reflow ile animasyonun yeniden tetiklenmesini garanti et
    void el.offsetWidth;
    // Yöne göre sınıf ekle
    var dir = cur > old ? 'up' : 'down';
    el.classList.add('value-bump-' + dir);
    // 2 sn sonra sınıfı kaldır
    setTimeout(function () {
      el.classList.remove('value-bump-up', 'value-bump-down');
    }, 2000);
    el.setAttribute('title', (dir === 'up' ? '▲' : '▼') + ' ' + (cur - old > 0 ? '+' : '') + (cur - old) + ' — güncelleme: ' + value);
  }

  // ---- Son güncelleme zaman damgası ----------------------------------------
  var lastUpdatedTime = 0;
  var timestampEl = document.getElementById('dashboard-last-updated');

  function updateTimestamp() {
    lastUpdatedTime = Date.now();
    renderTimestamp();
  }

  function renderTimestamp() {
    if (!timestampEl) return;
    var diff = Math.floor((Date.now() - lastUpdatedTime) / 1000);
    var text;
    if (diff < 5) text = '✓ Az önce güncellendi';
    else if (diff < 60) text = diff + ' sn önce güncellendi';
    else text = Math.floor(diff / 60) + ' dk ' + (diff % 60) + ' sn önce güncellendi';
    timestampEl.textContent = text;
  }

  // Her saniye zaman damgasını tazele (sayacı canlı tut)
  setInterval(renderTimestamp, 1000);

  // Tıklayınca anında tazele
  if (timestampEl) {
    timestampEl.style.cursor = 'pointer';
    timestampEl.setAttribute('title', 'Tıklayarak anında yenile');
    timestampEl.addEventListener('click', function () {
      tick();
      updateTimestamp();
    });
  }

  // ---- Otomatik yenileme döngüsü ------------------------------------------
  function tick() {
    if (document.visibilityState !== 'visible') return; // gizli sekmede ağ trafiği yok
    loadSeries();
    loadValues();
  }

  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') {
      // Sekmeye dönünce hemen tazele, sonra döngü devam etsin
      tick();
    }
  });

  function scheduleTick() {
    if (refreshTimer) clearInterval(refreshTimer);
    refreshTimer = setInterval(tick, REFRESH_MS);
  }

  // localStorage değişikliğini dinle (diğer sekmelerden gelen güncelleme)
  window.addEventListener('storage', function (ev) {
    if (ev.key === REFRESH_KEY && ev.newValue) {
      REFRESH_MS = parseInt(ev.newValue, 10) * 1000;
      scheduleTick();
    }
  });

  loadSeries();
  loadValues();
  scheduleTick();
})();
