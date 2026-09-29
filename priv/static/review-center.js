(function () {
  'use strict';
  var host = document.getElementById('review-center-list');
  if (!host) return;
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>"']/g, function (char) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[char]; }); }
  function csrf() { var part = document.cookie.split('; ').find(function (item) { return item.indexOf('nexus_csrf=') === 0; }); return part ? decodeURIComponent(part.slice(11)) : ''; }
  function assignment(type, id, data) {
    var current = (data.assignments || []).find(function (item) { return item.entityType === type && item.entityId === id; });
    var state = current ? '<small>' + esc(current.assignee) + ' · ' + esc(current.dueAt) + (current.overdue ? ' · Süre aşıldı' : '') + '</small>' : '<small>Atanmamış</small>';
    var form = '<form method="post" action="/admin/review-center/assign" class="partner-action-form review-assign-form">' +
      '<input type="hidden" name="csrf" value="' + esc(csrf()) + '"><input type="hidden" name="entity_type" value="' + esc(type) + '"><input type="hidden" name="entity_id" value="' + esc(id) + '">' +
      '<select name="assignee_user_id" required aria-label="Sorumlu"><option value="">Sorumlu seçin</option>' + (data.reviewers || []).map(function (user) { return '<option value="' + esc(user.id) + '">' + esc(user.name) + '</option>'; }).join('') + '</select>' +
      '<input type="datetime-local" name="due_local" required aria-label="Son tarih"><input type="hidden" name="due_at"><button type="submit">Ata</button></form>';
    return '<div>' + state + form + '</div>';
  }
  function row(title, subtitle, type, id, data, extra) { return '<div class="partner-lead-row"><div><strong>' + esc(title) + '</strong><br><small>' + esc(subtitle) + '</small></div>' + assignment(type,id,data) + (extra || '') + '</div>'; }
  function group(title, items, render, empty) { return '<h3>' + esc(title) + '</h3><div class="partner-lead-list">' + (items.length ? items.map(render).join('') : '<p class="muted">' + esc(empty) + '</p>') + '</div>'; }
  host.addEventListener('submit', function (event) { if (!event.target.matches('.review-assign-form')) return; var instant = new Date(event.target.querySelector('[name=due_local]').value); if (Number.isNaN(instant.getTime())) { event.preventDefault(); return; } event.target.querySelector('[name=due_at]').value = instant.toISOString(); });
  host.addEventListener('submit', function (event) {
    if (!event.target.matches('.review-bulk-form')) return;
    var ids = Array.from(host.querySelectorAll('.review-bulk-check:checked')).map(function (box) { return box.value; });
    if (!ids.length || ids.length > 50) { event.preventDefault(); alert('1 ile 50 arasında rezervasyon seçin.'); return; }
    event.target.querySelector('[name=reservation_ids]').value = ids.join(',');
  });
  fetch('/admin/review-center/data', {credentials:'same-origin', headers:{Accept:'application/json'}, cache:'no-store'})
    .then(function (response) { if (!response.ok) throw Error('İnceleme kuyruğu yüklenemedi.'); return response.json(); })
    .then(function (data) {
      var bookings=data.bookingDecisions||[], listings=data.listings||[], applications=data.applications||[], expiring=data.expiringDocuments||[];
      var overdue=(data.assignments||[]).filter(function (item) { return item.notifiable; }).length;
      host.innerHTML='<div class="partner-org-grid">'+[['Tedarikçi yanıtı',bookings.length],['İlan incelemesi',listings.length],['Başvuru',applications.length],['Belge uyarısı',expiring.length]].map(function(x){return '<article class="partner-org-card"><strong>'+x[1]+'</strong><p>'+esc(x[0])+'</p></article>';}).join('')+'</div>'+
        (overdue ? '<form method="post" action="/admin/review-center/notify-overdue" class="partner-action-form"><input type="hidden" name="csrf" value="'+esc(csrf())+'"><span>'+overdue+' gecikmiş görev</span><button type="submit">Sorumlulara bildirim gönder</button></form>' : '')+
        (bookings.length ? '<form method="post" action="/admin/review-center/booking-decisions-bulk" class="partner-action-form review-bulk-form"><input type="hidden" name="csrf" value="'+esc(csrf())+'"><input type="hidden" name="reservation_ids"><button type="submit">Seçili kararları uygula</button></form>' : '')+
        group('Rezervasyon kararları',bookings,function(x){var action='<label><input class="review-bulk-check" type="checkbox" value="'+esc(x.reservationId)+'" aria-label="'+esc(x.reference)+' kararını seç"> Seç</label><form method="post" action="/admin/review-center/booking-decision" class="partner-action-form"><input type="hidden" name="csrf" value="'+esc(csrf())+'"><input type="hidden" name="action" value="apply"><input type="hidden" name="reservation_id" value="'+esc(x.reservationId)+'"><button type="submit">Kararı uygula</button></form>';return row(x.reference,x.listing+' · '+x.supplier+' · '+x.decision+' · '+x.date,'booking_decision',x.reservationId,data,action);},'Bekleyen tedarikçi kararı yok.')+
        '<p><a href="/admin/catalog#catalog-workspace">Katalog inceleme ekranını aç</a></p>'+group('İlan incelemeleri',listings,function(x){return row(x.title,x.category+' · '+x.owner+' · '+x.createdAt,'listing',x.id,data,'');},'İncelenecek ilan yok.')+
        '<p><a href="/admin/supplier-onboarding">Başvuru inceleme ekranını aç</a></p>'+group('Tedarikçi başvuruları',applications,function(x){return row(x.name,x.type+' · '+x.submittedAt,'application',x.id,data,'');},'Bekleyen başvuru yok.')+
        '<p><a href="/admin/supplier-operations">Belge inceleme ekranını aç</a></p>'+group('Süresi dolan veya yaklaşan belgeler',expiring,function(x){return '<div class="partner-lead-row"><strong>'+esc(x.supplier)+'</strong><span>'+esc(x.type)+' · '+esc(x.expiresOn)+'</span></div>';},'30 gün içinde sona erecek belge yok.');
    }).catch(function(error){host.textContent=error.message;});
}());
