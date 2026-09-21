(() => {
  const body = document.getElementById('search-analytics-table-body');
  if (!body) return;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
  window.loadSearchAnalytics = async () => {
    const response = await fetch('/admin/search-analytics/data', { credentials: 'same-origin' });
    const rows = await response.json();
    body.innerHTML = rows.length ? rows.map(row => `<tr><td>${esc(row.category || 'Genel')}</td><td>${esc(row.location || 'Belirtilmemiş')}</td><td>${esc(row.searches)}</td></tr>`).join('') : '<tr><td colspan="3">Henüz arama verisi yok.</td></tr>';
  };
  window.loadSearchAnalytics();
})();
