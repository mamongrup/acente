(() => {
  const root = document.getElementById('control-center-workspace');
  if (!root) return;
  const status = document.getElementById('control-center-status');
  const summary = document.getElementById('control-center-summary');
  const results = document.getElementById('control-center-results');
  const refresh = document.getElementById('control-center-refresh');
  const labels = { ok: 'Normal', attention: 'İnceleme gerekli', optional: 'İsteğe bağlı' };

  function node(tag, className, value) {
    const el = document.createElement(tag);
    if (className) el.className = className;
    if (value != null) el.textContent = String(value);
    return el;
  }

  function render(checks, generatedAt) {
    const attention = checks.filter((check) => check.status === 'attention').length;
    const ok = checks.filter((check) => check.status === 'ok').length;
    const optional = checks.filter((check) => check.status === 'optional').length;
    summary.replaceChildren();
    for (const [label, count] of [['Normal', ok], ['İnceleme gerekli', attention], ['İsteğe bağlı', optional]]) {
      const card = node('div', 'metric-card');
      card.append(node('strong', '', count), node('span', '', label));
      summary.append(card);
    }
    const table = node('table', 'data-table');
    const head = node('thead');
    const headRow = node('tr');
    for (const title of ['Kontrol', 'Durum', 'Sonuç', 'İşlem']) headRow.append(node('th', '', title));
    head.append(headRow);
    const body = node('tbody');
    for (const check of checks) {
      const row = node('tr');
      const name = node('td');
      name.setAttribute('data-label', 'Kontrol');
      name.append(node('strong', '', check.title), node('small', 'muted', check.detail));
      const state = node('td');
      state.setAttribute('data-label', 'Durum');
      const badge = node('span', `control-status control-status-${check.status}`, labels[check.status] || check.status);
      state.append(badge);
      const metric = node('td', '', check.metric);
      metric.setAttribute('data-label', 'Sonuç');
      const action = node('td');
      action.setAttribute('data-label', 'İşlem');
      const link = node('a', 'secondary', 'Yönet');
      link.href = check.href;
      action.append(link);
      row.append(name, state, metric, action);
      body.append(row);
    }
    table.append(head, body);
    results.replaceChildren(table);
    const time = generatedAt ? new Date(generatedAt).toLocaleString('tr-TR') : '';
    status.textContent = `${checks.length} canlı denetim · ${time}`;
  }

  async function load() {
    refresh.disabled = true;
    status.textContent = 'Denetimler güncelleniyor…';
    try {
      const response = await fetch('/admin/control-center/data', { credentials: 'same-origin', cache: 'no-store' });
      if (!response.ok) throw new Error(response.status === 403 ? 'Bu alana erişim yetkiniz yok.' : 'Denetimler okunamadı.');
      const data = await response.json();
      render(Array.isArray(data.checks) ? data.checks : [], data.generatedAt);
    } catch (error) {
      status.textContent = error.message || 'Denetimler okunamadı.';
    } finally {
      refresh.disabled = false;
    }
  }

  refresh.addEventListener('click', load);
  load();
})();
