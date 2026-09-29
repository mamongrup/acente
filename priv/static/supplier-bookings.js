(function () {
  'use strict';
  var host = document.getElementById('supplier-bookings-list');
  if (!host) return;
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }
  var status = {inquiry:'Talep', option:'Ön rezervasyon', confirmed:'Onaylandı', cancelled:'İptal', completed:'Tamamlandı'};
  function serviceQueue(items) {
    var today = new Intl.DateTimeFormat('en-CA', {timeZone:'Europe/Istanbul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
    var pending = [];
    items.forEach(function (item) {
      if (item.status !== 'confirmed' && item.status !== 'completed') return;
      var tasks = Array.isArray(item.serviceTasks) ? item.serviceTasks : [];
      if (!tasks.length) {
        pending.push({item:item, task:null, due:item.checkIn || '', stage:'before'});
        return;
      }
      tasks.forEach(function (task) {
        if (task.status !== 'open') return;
        pending.push({item:item, task:task, due:task.stage === 'after' ? (item.checkOut || item.checkIn || '') : (item.checkIn || ''), stage:task.stage});
      });
    });
    pending.sort(function (a, b) { return (a.due || '9999').localeCompare(b.due || '9999') || a.item.reference.localeCompare(b.item.reference); });
    var overdue = pending.filter(function (entry) { return entry.due && entry.due < today; }).length;
    var weekEnd = new Intl.DateTimeFormat('en-CA', {timeZone:'Europe/Istanbul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(Date.now() + 7 * 86400000));
    var soon = pending.filter(function (entry) { return entry.due && entry.due >= today && entry.due <= weekEnd; }).length;
    var summary = '<section class="quick"><h3>Hizmet iş sırası</h3><p class="muted">Onaylanan rezervasyonların açık adımları. Tarih hizmetin giriş, sefer veya çıkış tarihinden alınır; kesin görev son saati değildir.</p><div class="metric-grid"><div class="metric"><strong>' + pending.length + '</strong><span>Açık adım</span></div><div class="metric"><strong>' + overdue + '</strong><span>Tarihi geçen</span></div><div class="metric"><strong>' + soon + '</strong><span>7 gün içinde</span></div></div>';
    if (!pending.length) return summary + '<p class="muted">Açık hizmet adımı yok.</p></section>';
    return summary + '<div class="table-wrap"><table class="data-table"><thead><tr><th>Tarih</th><th>Rezervasyon</th><th>Hizmet</th><th>İşlem</th></tr></thead><tbody>' + pending.slice(0, 30).map(function (entry) {
      var item = entry.item, task = entry.task;
      var stage = {before:'Öncesi',during:'Hizmet sırasında',after:'Sonrası'}[entry.stage] || entry.stage;
      var due = entry.due ? esc(entry.due) + (entry.due < today ? ' · Tarihi geçti' : '') : 'Tarih bekleniyor';
      var action = task ? '<form method="post" action="/admin/supplier-bookings/service-task" class="partner-action-form"><input type="hidden" name="task_id" value="' + esc(task.id) + '"><input name="note" maxlength="2000" aria-label="İşlem notu" placeholder="İşlem notu"><button type="submit" name="status" value="done">Tamamla</button></form>' : '<form method="post" action="/admin/supplier-bookings/service-start" class="partner-action-form"><input type="hidden" name="reservation_id" value="' + esc(item.id) + '"><button type="submit">Adımları başlat</button></form>';
      return '<tr><td>' + due + '</td><td><strong>' + esc(item.reference) + '</strong><br><small>' + esc(item.customer) + '</small></td><td>' + esc(task ? task.title : 'Hizmet adımlarını oluştur') + '<br><small>' + esc(item.listing) + ' · ' + esc(stage) + '</small></td><td>' + action + '</td></tr>';
    }).join('') + '</tbody></table></div>' + (pending.length > 30 ? '<p class="muted">İlk 30 açık adım gösteriliyor; diğerleri rezervasyon tablosunda.</p>' : '') + '</section>';
  }
  fetch('/admin/supplier-bookings/data', {credentials:'same-origin', headers:{Accept:'application/json'}, cache:'no-store'})
    .then(function (response) { if (!response.ok) throw Error('Rezervasyonlar yüklenemedi.'); return response.json(); })
    .then(function (items) {
      if (!Array.isArray(items) || !items.length) { host.innerHTML = '<p class="muted">Henüz ilanlarınıza ait rezervasyon yok.</p>'; return; }
      host.innerHTML = serviceQueue(items) + '<div class="table-wrap"><table class="data-table"><thead><tr><th>Rezervasyon</th><th>İlan</th><th>Misafir</th><th>Tarih</th><th>Durum</th><th>Tutar</th><th>Yanıt</th><th>Hizmet akışı</th><th>Mesajlar</th></tr></thead><tbody>' + items.map(function (item) {
        var amount = new Intl.NumberFormat('tr-TR',{style:'currency',currency:item.currency||'TRY'}).format(Number(item.amount||0)/100);
        var decision = item.decision ? '<strong>' + esc(item.decision === 'accepted' ? 'Kabul önerildi' : 'Ret önerildi') + '</strong><br><small>Yönetici incelemesinde</small>' : '';
        var action = item.status === 'inquiry' ? '<form method="post" action="/admin/supplier-bookings/decision" class="partner-action-form"><input type="hidden" name="reservation_id" value="'+esc(item.id)+'"><select name="decision" required><option value="accepted">Kabul öner</option><option value="rejected">Ret öner</option></select><input name="note" maxlength="1000" aria-label="Yanıt notu" placeholder="Karar notu"><button type="submit">Gönder</button></form>' : '';
        var messages = Array.isArray(item.messages) ? item.messages : [];
        var tasks = Array.isArray(item.serviceTasks) ? item.serviceTasks : [];
        var service = '';
        if (item.status === 'confirmed' || item.status === 'completed') {
          service = tasks.length ? '<details><summary>Adımlar (' + tasks.filter(function (task) { return task.status === 'done'; }).length + '/' + tasks.length + ')</summary><div class="partner-lead-list">' + tasks.map(function (task) {
            var stage = {before:'Öncesi', during:'Hizmet sırasında', after:'Sonrası'}[task.stage] || task.stage;
            var action = task.status === 'open' ? '<form method="post" action="/admin/supplier-bookings/service-task" class="partner-action-form"><input type="hidden" name="task_id" value="' + esc(task.id) + '"><input name="note" maxlength="2000" aria-label="İşlem notu" placeholder="İşlem notu"><button type="submit" name="status" value="done">Tamamla</button></form>' : '<small>' + esc(task.status === 'done' ? 'Tamamlandı' : 'Muaf tutuldu') + '</small>';
            return '<div><strong>' + esc(task.title) + '</strong><br><small>' + esc(stage) + '</small>' + action + '</div>';
          }).join('') + '</div></details>' : '<form method="post" action="/admin/supplier-bookings/service-start" class="partner-action-form"><input type="hidden" name="reservation_id" value="' + esc(item.id) + '"><button type="submit">Hizmet adımlarını başlat</button></form>';
        }
        var thread = '<details><summary>Mesajlar ('+messages.length+')</summary><div class="partner-lead-list">'+messages.map(function (m) { return '<p><strong>'+esc(m.author === 'customer' ? 'Misafir' : m.author === 'supplier' ? 'Tedarikçi' : 'Acente')+'</strong> · '+esc(m.createdAt)+'<br>'+esc(m.message)+'</p>'; }).join('')+'<form method="post" action="/admin/supplier-bookings/message" class="partner-action-form"><input type="hidden" name="reservation_id" value="'+esc(item.id)+'"><textarea name="message" minlength="2" maxlength="4000" required aria-label="Rezervasyon mesajı" placeholder="Misafire mesaj yazın"></textarea><button type="submit">Mesaj gönder</button></form></div></details>';
        return '<tr><td><strong>'+esc(item.reference)+'</strong><br><small>'+esc(item.createdAt)+'</small></td><td>'+esc(item.listing)+'<br><small>'+esc(item.category)+'</small></td><td>'+esc(item.customer)+'<br><small>'+Number(item.guests||0)+' kişi</small></td><td>'+esc(item.checkIn || '—')+(item.checkOut ? ' – '+esc(item.checkOut) : '')+'</td><td>'+esc(status[item.status]||item.status)+'<br><small>Ödeme: '+esc(item.paymentStatus)+'</small></td><td>'+esc(amount)+'</td><td>'+decision+action+'</td><td>'+service+'</td><td>'+thread+'</td></tr>';
      }).join('') + '</tbody></table></div>';
    })
    .catch(function (error) { host.textContent = error.message; });
}());
