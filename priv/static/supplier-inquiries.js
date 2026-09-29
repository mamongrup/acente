(function () {
  'use strict';
  var host = document.getElementById('supplier-inquiries-list');
  if (!host) return;
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }
  var status = {new:'Yeni', in_progress:'İşlemde', answered:'Yanıtlandı', closed:'Kapalı'};
  fetch('/admin/supplier-inquiries/data', {credentials:'same-origin', headers:{Accept:'application/json'}, cache:'no-store'})
    .then(function (response) { if (!response.ok) throw Error('İlan talepleri yüklenemedi.'); return response.json(); })
    .then(function (items) {
      if (!Array.isArray(items) || !items.length) { host.innerHTML = '<p class="muted">Henüz ilanlarınıza gelen talep yok.</p>'; return; }
      host.innerHTML = '<div class="table-wrap"><table class="data-table"><thead><tr><th>İlan</th><th>Müşteri</th><th>Talep</th><th>Durum</th><th>Tarih</th><th>Yanıt</th></tr></thead><tbody>' + items.map(function (item) {
        var reply = item.status === 'closed' ? '' : '<form method="post" action="/admin/supplier-inquiries/reply" class="partner-action-form"><input type="hidden" name="contact_request_id" value="'+esc(item.id)+'"><input name="message" minlength="2" maxlength="4000" required aria-label="Müşteri talebine yanıt" placeholder="Yanıtınızı yazın"><button type="submit">Kaydet</button></form>';
        return '<tr><td><strong>'+esc(item.listing)+'</strong></td><td>'+esc(item.name)+'<br><small>'+esc(item.email)+' '+esc(item.phone)+'</small></td><td>'+esc(item.message)+'</td><td>'+esc(status[item.status]||item.status)+'</td><td>'+esc(item.createdAt)+'</td><td><small>'+esc(item.lastReply||'')+'</small>'+reply+'</td></tr>';
      }).join('') + '</tbody></table></div>';
    })
    .catch(function (error) { host.textContent = error.message; });
}());
