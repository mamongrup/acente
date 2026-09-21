(() => {
  const body = document.getElementById('notifications-table-body');
  if (!body) return;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
  window.loadNotifications = async () => {
    const response = await fetch('/admin/notifications/data', { credentials: 'same-origin' });
    const rows = await response.json();
    body.innerHTML = rows.length ? rows.map(row => {
      const retry = row.status === 'failed' ? `<form method="post" action="/admin/notifications/retry" style="display:inline"><input type="hidden" name="id" value="${esc(row.id)}"><button type="submit" class="link-button">Tekrar dene</button></form>` : '';
      const detail = row.last_error ? `<small class="muted" title="${esc(row.last_error)}">${esc(row.last_error.slice(0, 80))}</small>` : '';
      return `<tr><td>${esc(row.channel)}</td><td>${esc(row.template)}</td><td>${esc(row.recipient || '-')}</td><td>${esc(row.status)} ${detail}</td><td>${esc(row.attempts || 0)} ${retry}</td></tr>`;
    }).join('') : '<tr><td colspan="5">Bildirim kuyruğu boş.</td></tr>';
  };
  window.loadNotifications();
})();
