(function () {
  'use strict';
  var host = document.getElementById('assigned-inquiries-list');
  if (!host) return;
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }
  fetch('/admin/assigned-inquiries/data', {credentials:'same-origin',headers:{Accept:'application/json'},cache:'no-store'})
    .then(function (response) { if (!response.ok) throw Error('Atanmış talepler yüklenemedi.'); return response.json(); })
    .then(function (items) {
      if (!Array.isArray(items) || !items.length) { host.innerHTML = '<p class="muted">Kuruluşunuza atanmış talep bulunmuyor.</p>'; return; }
      host.innerHTML = '<div class="table-wrap"><table class="data-table"><thead><tr><th>Tarih</th><th>İlan</th><th>Müşteri</th><th>Talep</th><th>Durum</th></tr></thead><tbody>' + items.map(function (item) {
        return '<tr><td>' + esc(item.createdAt) + '</td><td>' + esc(item.listing || 'Genel talep') + '</td><td><strong>' + esc(item.name) + '</strong><br><small>' + esc(item.email) + ' · ' + esc(item.phone) + '</small></td><td>' + esc(item.message) + '</td><td>' + esc(item.status) + '</td></tr>';
      }).join('') + '</tbody></table></div>';
    }).catch(function (error) { host.textContent = error.message; });
}());
