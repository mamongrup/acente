(function () {
  var tasks = document.getElementById('report-tasks-body');
  var audits = document.getElementById('report-audits-body');
  if (!tasks || !audits) return;

  // ---- Haftalık özet (contacts + conversion dahil) -----------------------
  var summary = document.getElementById('digest-summary');
  var emailForm = document.getElementById('digest-email-form');
  var emailBtn = document.getElementById('digest-email-btn');
  var pdfBtn = document.getElementById('digest-pdf-btn');

  function stat(label, value) {
    var box = document.createElement('div');
    box.className = 'digest-stat';
    var k = document.createElement('span'); k.className = 'digest-stat-k'; k.textContent = label;
    var v = document.createElement('strong'); v.className = 'digest-stat-v'; v.textContent = value;
    box.appendChild(k); box.appendChild(v);
    return box;
  }

  // Mini sparkline: 7 günlük seriyi inline SVG olarak çizer
  function renderSparkline(container, series, color, label) {
    var W = 120, H = 32, PAD = 3;
    var ns = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
    svg.setAttribute('preserveAspectRatio', 'none');
    svg.classList.add('digest-spark-svg');
    svg.setAttribute('aria-label', label + ' haftalık trend');
    var max = Math.max.apply(null, series);
    var min = Math.min.apply(null, series);
    var span = max - min; if (span === 0) span = 1;
    var n = series.length;
    var px = function (i) { return PAD + (i * (W - 2 * PAD)) / (n - 1); };
    var py = function (v) { return H - PAD - ((v - min) * (H - 2 * PAD)) / span; };
    // Alan dolgusu
    var pts = series.map(function (v, i) { return px(i).toFixed(1) + ',' + py(v).toFixed(1); });
    var area = document.createElementNS(ns, 'polygon');
    area.setAttribute('points',
      PAD + ',' + H + ' ' + pts.join(' ') + ' ' + (W - PAD) + ',' + H);
    area.setAttribute('fill', color.replace(')', ',0.12)').replace('rgb', 'rgba'));
    svg.appendChild(area);
    // Çizgi
    var line = document.createElementNS(ns, 'polyline');
    line.setAttribute('points', pts.join(' '));
    line.setAttribute('fill', 'none');
    line.setAttribute('stroke', color);
    line.setAttribute('stroke-width', '1.8');
    line.setAttribute('stroke-linecap', 'round');
    svg.appendChild(line);
    // Son nokta
    var dot = document.createElementNS(ns, 'circle');
    dot.setAttribute('cx', px(n - 1).toFixed(1));
    dot.setAttribute('cy', py(series[n - 1]).toFixed(1));
    dot.setAttribute('r', '2.5');
    dot.setAttribute('fill', color);
    svg.appendChild(dot);
    var wrap = document.createElement('div');
    wrap.className = 'digest-spark-item';
    var lbl = document.createElement('span');
    lbl.className = 'digest-spark-label';
    lbl.textContent = label;
    wrap.appendChild(svg);
    wrap.appendChild(lbl);
    container.appendChild(wrap);
  }

  fetch('/admin/reports/weekly-digest', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (r) { if (!r.ok) throw new Error('Özet yüklenemedi'); return r.json(); })
    .then(function (d) {
      if (!summary) return;
      summary.textContent = '';
      var head = document.createElement('span');
      head.className = 'digest-period';
      head.textContent = 'Dönem ' + (d.period || '—');
      summary.appendChild(head);
      summary.appendChild(stat('Yeni yayın', d.publishedTotal));
      summary.appendChild(stat('Bekleyen', d.pendingTotal));
      summary.appendChild(stat('Yaklaşan giriş', d.upcomingTotal));
      summary.appendChild(stat('Müşteri talebi', d.contactsTotal));
      summary.appendChild(stat('Ort. dönüşüm', d.conversionAvg + '%'));
      // Sparkline'ları çiz
      var sparkHost = document.getElementById('digest-sparklines');
      if (sparkHost && d.days && d.days.length) {
        sparkHost.textContent = '';
        var published = d.days.map(function (day) { return day.published || 0; });
        var pending = d.days.map(function (day) { return day.pending || 0; });
        var contacts = d.days.map(function (day) { return day.contacts || 0; });
        renderSparkline(sparkHost, published, 'rgb(34,211,238)', 'Yayın');
        renderSparkline(sparkHost, pending, 'rgb(245,158,11)', 'Talep');
        renderSparkline(sparkHost, contacts, 'rgb(167,139,250)', 'Müşteri');
      }
    })
    .catch(function () {
      if (summary) summary.textContent = 'Haftalık özet yüklenemedi.';
    });

  if (pdfBtn) {
    pdfBtn.addEventListener('click', function () {
      window.open('/admin/reports/weekly-digest/pdf', '_blank', 'noopener');
    });
  }

  if (emailBtn && emailForm) {
    emailBtn.addEventListener('click', function () {
      var willShow = emailForm.hasAttribute('hidden');
      if (willShow) emailForm.removeAttribute('hidden');
      else emailForm.setAttribute('hidden', 'hidden');
      if (willShow) emailForm.querySelector('input[name="to"]').focus();
    });
  }
  var cancelBtn = document.getElementById('digest-email-cancel');
  if (cancelBtn && emailForm) {
    cancelBtn.addEventListener('click', function () {
      emailForm.setAttribute('hidden', 'hidden');
    });
  }
  if (emailForm) {
    emailForm.addEventListener('submit', function (e) {
      e.preventDefault();
      var feedback = document.getElementById('digest-email-feedback');
      var fd = new FormData(emailForm);
      var btn = emailForm.querySelector('button[type=submit]');
      if (btn) btn.disabled = true;
      fetch('/admin/reports/weekly-digest/email', { method: 'POST', credentials: 'same-origin', body: fd })
        .then(function (r) { return r.json().then(function (j) { return { status: r.status, body: j }; }); })
        .then(function (res) {
          if (btn) btn.disabled = false;
          if (feedback) {
            feedback.textContent = res.status === 201
              ? '✓ ' + res.body.to + ' adresine kuyruğa alındı — Bildirim Merkezi gönderecek.'
              : (res.body && res.body.error) || 'Gönderim başarısız.';
            feedback.classList.toggle('digest-ok', res.status === 201);
          }
          if (res.status === 201) emailForm.setAttribute('hidden', 'hidden');
        })
        .catch(function () {
          if (btn) btn.disabled = false;
          if (feedback) feedback.textContent = 'Gönderim başarısız.';
        });
    });
  }
  function cell(value) { var td = document.createElement('td'); td.textContent = value || '—'; return td; }
  function empty(table, count, message) { var row = document.createElement('tr'); var td = cell(message); td.colSpan = count; td.className = 'empty-state'; row.appendChild(td); table.appendChild(row); }
  function actionCell(label, handler) {
    var td = document.createElement('td');
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'secondary audit-detail-btn';
    btn.textContent = label;
    btn.addEventListener('click', handler);
    td.appendChild(btn);
    return td;
  }
  function pretty(value) {
    if (value === null || value === undefined || value === '') return '—';
    if (typeof value === 'string') {
      try { return JSON.stringify(JSON.parse(value), null, 2); } catch (_) { return value; }
    }
    try { return JSON.stringify(value, null, 2); } catch (_) { return String(value); }
  }
  var auditDialog = null;
  function ensureAuditDialog() {
    if (auditDialog) return auditDialog;
    auditDialog = document.createElement('div');
    auditDialog.className = 'audit-detail-dialog';
    auditDialog.setAttribute('hidden', 'hidden');
    auditDialog.innerHTML =
      '<div class="audit-detail-backdrop" data-close="1"></div>' +
      '<section class="audit-detail-card" role="dialog" aria-modal="true" aria-labelledby="audit-detail-title">' +
      '<button type="button" class="audit-detail-close" data-close="1" aria-label="Kapat">×</button>' +
      '<h3 id="audit-detail-title">Denetim detayı</h3>' +
      '<dl class="audit-detail-list">' +
      '<div><dt>İşlem</dt><dd data-audit-field="action"></dd></div>' +
      '<div><dt>Varlık</dt><dd data-audit-field="entity"></dd></div>' +
      '<div><dt>Varlık ID</dt><dd data-audit-field="entityId"></dd></div>' +
      '<div><dt>Kullanıcı</dt><dd data-audit-field="user"></dd></div>' +
      '<div><dt>IP</dt><dd data-audit-field="ip"></dd></div>' +
      '<div><dt>Tarayıcı</dt><dd data-audit-field="userAgent"></dd></div>' +
      '<div><dt>Request ID</dt><dd data-audit-field="requestId"></dd></div>' +
      '<div><dt>Tarih</dt><dd data-audit-field="createdAt"></dd></div>' +
      '</dl>' +
      '<h4>Metadata</h4><pre data-audit-field="metadata"></pre>' +
      '</section>';
    auditDialog.addEventListener('click', function (event) {
      if (event.target && event.target.getAttribute('data-close')) closeAuditDialog();
    });
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && auditDialog && !auditDialog.hasAttribute('hidden')) closeAuditDialog();
    });
    document.body.appendChild(auditDialog);
    return auditDialog;
  }
  function setAuditField(dialog, name, value) {
    var el = dialog.querySelector('[data-audit-field="' + name + '"]');
    if (el) el.textContent = value || '—';
  }
  function openAuditDialog(audit) {
    var dialog = ensureAuditDialog();
    setAuditField(dialog, 'action', audit.action);
    setAuditField(dialog, 'entity', audit.entityType || audit.entity);
    setAuditField(dialog, 'entityId', audit.entityId);
    setAuditField(dialog, 'user', audit.userName || audit.userEmail || audit.userId);
    setAuditField(dialog, 'ip', audit.ip);
    setAuditField(dialog, 'userAgent', audit.userAgent);
    setAuditField(dialog, 'requestId', audit.requestId);
    setAuditField(dialog, 'createdAt', audit.createdAt);
    setAuditField(dialog, 'metadata', pretty(audit.metadata));
    dialog.removeAttribute('hidden');
    var close = dialog.querySelector('.audit-detail-close');
    if (close) close.focus();
  }
  function closeAuditDialog() {
    if (auditDialog) auditDialog.setAttribute('hidden', 'hidden');
  }
  var auditSearch = document.getElementById('audit-search');
  var auditEntity = document.getElementById('audit-entity');
  var auditExport = document.getElementById('audit-export-csv');
  function auditUrl(path) {
    var params = new URLSearchParams();
    if (auditSearch && auditSearch.value.trim()) params.set('q', auditSearch.value.trim());
    if (auditEntity && auditEntity.value) params.set('entity', auditEntity.value);
    params.set('limit', '200');
    return path + '?' + params.toString();
  }
  function renderAudits(rows) {
    audits.textContent = '';
    if (!rows.length) return empty(audits, 5, 'Henüz denetim kaydı yok.');
    rows.forEach(function (audit) {
      var row = document.createElement('tr');
      row.appendChild(cell(audit.action));
      row.appendChild(cell(audit.entityType || audit.entity));
      row.appendChild(cell(audit.userName || audit.userEmail || audit.userId));
      row.appendChild(cell(audit.createdAt));
      row.appendChild(actionCell('Detay', function () { openAuditDialog(audit); }));
      audits.appendChild(row);
    });
  }
  function loadAudits() {
    audits.textContent = '';
    empty(audits, 5, 'Denetim kayıtları yükleniyor…');
    fetch(auditUrl('/admin/reports/audits'), { credentials: 'same-origin', cache: 'no-store' })
      .then(function (response) { if (!response.ok) throw new Error('Denetim kayıtları yüklenemedi'); return response.json(); })
      .then(renderAudits)
      .catch(function (error) { audits.textContent = ''; empty(audits, 5, error.message); });
  }
  var auditTimer = null;
  if (auditSearch) auditSearch.addEventListener('input', function () {
    clearTimeout(auditTimer);
    auditTimer = setTimeout(loadAudits, 250);
  });
  if (auditEntity) auditEntity.addEventListener('change', loadAudits);
  if (auditExport) auditExport.addEventListener('click', function () {
    window.open(auditUrl('/admin/reports/audits.csv'), '_blank', 'noopener');
  });
  fetch('/admin/reports/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) { if (!response.ok) throw new Error('Rapor yüklenemedi'); return response.json(); })
    .then(function (data) {
      document.getElementById('report-published').textContent = data.publishedListings;
      document.getElementById('report-reservations').textContent = data.reservations;
      document.getElementById('report-customers').textContent = data.customers;
      document.getElementById('report-contacts').textContent = data.newContacts;
      tasks.textContent = '';
      if (!data.tasks.length) empty(tasks, 4, 'Henüz görev kaydı yok.');
      data.tasks.forEach(function (task) { var row = document.createElement('tr'); row.appendChild(cell(task.task)); row.appendChild(cell(task.status)); row.appendChild(cell(task.attempt)); row.appendChild(cell(task.finishedAt)); tasks.appendChild(row); });
      loadAudits();
    })
    .catch(function (error) { tasks.textContent = ''; audits.textContent = ''; empty(tasks, 4, error.message); empty(audits, 5, error.message); });
})();
