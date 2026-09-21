(() => {
  const body = document.getElementById('inquiries-table-body');
  if (!body) return;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
  window.loadInquiries = async () => {
    const response = await fetch('/admin/inquiries/data', { credentials: 'same-origin' });
    const rows = await response.json();
    body.innerHTML = rows.length ? rows.map(row => `<tr data-row-id="${esc(row.id)}"><td>${esc(row.full_name)}<br><small>${esc(row.email)}</small></td><td>${esc(row.listing_title || 'Genel talep')}</td><td>${esc(row.check_in || '-')} → ${esc(row.check_out || '-')}<br><small>${esc(row.guest_count || 1)} misafir</small></td><td><form method="post" action="/admin/inquiries/status"><input type="hidden" name="id" value="${esc(row.id)}"><select name="status" onchange="this.form.submit()"><option ${row.status === 'new' ? 'selected' : ''}>new</option><option ${row.status === 'contacted' ? 'selected' : ''}>contacted</option><option ${row.status === 'converted' ? 'selected' : ''}>converted</option><option ${row.status === 'closed' ? 'selected' : ''}>closed</option></select></form>${row.status !== 'converted' ? `<form method="post" action="/admin/inquiries/convert"><input type="hidden" name="id" value="${esc(row.id)}"><button type="submit" class="secondary">Rezervasyona dönüştür</button></form>` : ''}</td></tr>`).join('') : '<tr><td colspan="4">Açık teklif talebi yok.</td></tr>';
  };
  window.loadInquiries();
})();
