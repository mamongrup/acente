(function () {
  'use strict';
  var host = document.getElementById('supplier-operations-content');
  if (!host) return;
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>"']/g, function (char) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[char]; }); }
  function csrf() { var part = document.cookie.split('; ').find(function (item) { return item.indexOf('nexus_csrf=') === 0; }); return part ? decodeURIComponent(part.slice(11)) : ''; }
  function money(minor, currency) { try { return new Intl.NumberFormat('tr-TR', {style:'currency',currency:currency || 'TRY'}).format(Number(minor || 0) / 100); } catch (_) { return (Number(minor || 0) / 100) + ' ' + esc(currency); } }
  function hidden(name, value) { return '<input type="hidden" name="' + esc(name) + '" value="' + esc(value) + '">'; }
  function formStart(path) { return '<form method="post" action="' + path + '" class="partner-action-form">' + hidden('csrf', csrf()); }
  function table(title, rows, columns) {
    return '<section class="quick" style="margin-top:18px"><h3>' + esc(title) + ' <small>(' + rows.length + ')</small></h3>' +
      (rows.length ? '<div class="table-wrap"><table class="data-table"><thead><tr>' + columns.map(function (column) { return '<th>' + esc(column[0]) + '</th>'; }).join('') + '</tr></thead><tbody>' + rows.map(function (row) { return '<tr>' + columns.map(function (column) { return '<td>' + column[1](row) + '</td>'; }).join('') + '</tr>'; }).join('') + '</tbody></table></div>' : '<p class="muted">Henüz kayıt yok.</p>') + '</section>';
  }
  fetch('/admin/supplier-operations/data', {credentials:'same-origin', headers:{Accept:'application/json'}, cache:'no-store'})
    .then(function (response) { if (!response.ok) throw Error('Tedarikçi kayıtları yüklenemedi.'); return response.json(); })
    .then(async function (data) {
      var admin = data.role === 'admin';
      var applicationData = admin ? null : await fetch('/admin/supplier-operations/application', {credentials:'same-origin',cache:'no-store'}).then(function (response) { if (!response.ok) throw Error('Başvuru durumu yüklenemedi.'); return response.json(); });
      var p = data.performance || {};
      var stats = '<section class="quick"><h3>Performans</h3><div class="metric-grid">' +
        [['Rezervasyon',p.bookings],['Onaylanan',p.confirmed],['İptal',p.cancelled],['İlan talebi',p.inquiries],['Yanıtlanan',p.replied]]
          .map(function (item) { return '<div class="metric"><strong>' + esc(item[1] || 0) + '</strong><span>' + esc(item[0]) + '</span></div>'; }).join('') + '</div></section>';
      var upload = admin ? '' : '<section class="quick" style="margin-top:18px"><h3>Belge yenile</h3><p class="muted">Güvenli HTTPS belge bağlantısını girin. Yeni belge incelemeye alınır; önceki onay kaydı saklanır.</p>' + formStart('/admin/supplier-operations/document') +
        '<select name="document_type" required aria-label="Belge türü"><option value="">Belge türü seçin</option>' + (data.documentTypes || []).map(function (type) { return '<option value="' + esc(type) + '">' + esc(type) + '</option>'; }).join('') + '</select>' +
        '<input name="document_url" type="url" required pattern="https://.*" maxlength="1008" placeholder="https://..." aria-label="Belge bağlantısı"><input name="expires_on" type="date" aria-label="Son geçerlilik tarihi"><button type="submit">İncelemeye gönder</button></form></section>';
      var application = '';
      if (!admin) {
        var currentApplications = applicationData.applications || [];
        var fields = [
          ['supplier_type','Tedarikçi türü'],['legal_name','Resmî unvan'],['display_name','Görünen ad'],
          ['tax_country','Vergi ülkesi'],['tax_office','Vergi dairesi'],['tax_number','Vergi numarası'],
          ['authorized_person_name','Yetkili adı soyadı'],['authorized_person_email','Yetkili e-posta'],
          ['authorized_person_phone','Yetkili telefon'],['service_regions','Hizmet bölgeleri'],
          ['default_currency','Varsayılan para birimi'],['invoice_address','Fatura adresi'],
          ['support_email','Destek e-posta'],['support_phone','Destek telefonu']
        ];
        application = '<section class="quick" style="margin-top:18px"><h3>Tedarikçi başvurularım</h3>' +
          (currentApplications.length ? '<ul>' + currentApplications.map(function (item) { return '<li>' + esc(item.category) + ' · ' + esc(item.status) + ' · Kimlik: ' + esc(item.identityStatus) + '</li>'; }).join('') + '</ul>' : '<p class="muted">Henüz başvurunuz yok.</p>') +
          '<p class="muted">Başvuru, seçilen kategori için kimlik ve zorunlu belge incelemesine alınır. Belgeleri aşağıdaki formdan iletebilirsiniz.</p>' +
          formStart('/admin/supplier-operations/application') +
          '<label>Kategori <select name="category_code" required><option value="">Kategori seçin</option>' + (applicationData.categories || []).map(function (cat) { return '<option value="' + esc(cat.code) + '">' + esc(cat.name) + '</option>'; }).join('') + '</select></label>' +
          fields.map(function (field) { var type = field[0].includes('email') ? 'email' : 'text'; var initial = field[0] === 'tax_country' ? 'TR' : field[0] === 'default_currency' ? 'TRY' : ''; return '<label>' + esc(field[1]) + ' <input name="' + esc(field[0]) + '" type="' + type + '" value="' + initial + '" required minlength="2" maxlength="160"></label>'; }).join('') +
          '<button type="submit">Başvuruyu gönder</button><p class="muted" role="status" id="supplier-application-notice" hidden></p></form></section>';
      }
      var docs = table('Belgeler', data.documents || [], [
        ['Tedarikçi',function (x) { return esc(x.supplier); }], ['Tür',function (x) { return esc(x.type); }],
        ['Durum',function (x) { return esc(x.status) + (x.expiresOn && x.expiresOn < new Date().toISOString().slice(0,10) ? ' · Süresi doldu' : ''); }],
        ['Geçerlilik',function (x) { return esc(x.expiresOn || 'Belirtilmedi'); }],
        ['Belge',function (x) { return /^https:\/\//.test(x.url || '') ? '<a href="' + esc(x.url) + '" target="_blank" rel="noopener noreferrer">Aç</a>' : ''; }],
        ['İnceleme',function (x) { return admin && x.status === 'pending' ? formStart('/admin/supplier-operations/document-review') + hidden('document_id',x.id) + '<input name="note" maxlength="1000" placeholder="İnceleme notu" aria-label="İnceleme notu"><button name="decision" value="approved">Onayla</button><button name="decision" value="rejected">Reddet</button></form>' : esc(x.note || ''); }]
      ]);
      var propose = admin && (data.eligibleReservations || []).length ? '<section class="quick" style="margin-top:18px"><h3>Hakediş oluştur</h3><p class="muted">Yalnızca ödenmiş rezervasyon ve geçerli komisyon kuralı için hesaplanır.</p>' + formStart('/admin/supplier-operations/settlement') + '<select name="reservation_id" required aria-label="Rezervasyon"><option value="">Rezervasyon seçin</option>' + data.eligibleReservations.map(function (x) { return '<option value="' + esc(x.id) + '">' + esc(x.reference + ' · ' + x.supplier + ' · ' + money(x.amount,x.currency)) + '</option>'; }).join('') + '</select><input name="due_on" type="date" required min="' + new Date().toISOString().slice(0,10) + '" aria-label="Ödeme tarihi"><button type="submit">Hakediş taslağı aç</button></form></section>' : '';
      var policy = data.settlementPolicy || {};
      var schedule = admin ? '<section class="quick" style="margin-top:18px"><h3>Otomatik hakediş takvimi</h3><p class="muted">Tamamlanmış ve tahsil edilmiş rezervasyonlar için taslak hakediş oluşturur. Bankaya ödeme talimatı göndermez.</p>' + formStart('/admin/supplier-operations/settlement-policy') + '<label>Takvim durumu <select name="enabled"><option value="false"' + (policy.enabled ? '' : ' selected') + '>Kapalı</option><option value="true"' + (policy.enabled ? ' selected' : '') + '>Etkin</option></select></label><label>Çıkıştan kaç gün sonra <input name="days_after_checkout" type="number" min="0" max="90" value="' + esc(policy.daysAfterCheckout == null ? 7 : policy.daysAfterCheckout) + '" required></label><button type="submit">Takvimi kaydet</button></form>' + (policy.enabled ? formStart('/admin/supplier-operations/settlement-generate') + '<button type="submit">Şimdi taslak oluştur</button></form>' : '') + '</section>' : '';
      var settlements = table('Hakedişler',data.settlements || [],[
        ['Rezervasyon',function (x) { return esc(x.reference); }],['Tedarikçi',function (x) { return esc(x.supplier); }],
        ['Brüt',function (x) { return esc(money(x.gross,x.currency)); }],['Komisyon',function (x) { return esc(money(x.commission,x.currency)); }],['Net',function (x) { return esc(money(x.net,x.currency)); }],
        ['Vade',function (x) { return esc(x.dueOn); }],['Durum',function (x) { return esc(x.status) + (x.externalReference ? ' · ' + esc(x.externalReference) : ''); }],
        ['İşlem',function (x) { if (!admin || (x.status !== 'pending' && x.status !== 'approved')) return ''; var form = formStart('/admin/supplier-operations/settlement-action') + hidden('settlement_id',x.id); if (x.status === 'pending') return form + '<button name="action" value="approved">Onayla</button><button name="action" value="cancelled">İptal</button></form>'; return form + '<input name="external_reference" minlength="3" maxlength="160" placeholder="Banka işlem no" aria-label="Banka işlem numarası"><button name="action" value="paid">Ödendi kaydet</button><button name="action" value="cancelled">İptal</button></form>'; }]
      ]);
      host.innerHTML = stats + application + upload + docs + schedule + propose + settlements + '<p class="muted">“Ödendi” kaydı harici banka referansına dayanır; sistem bankaya otomatik ödeme talimatı göndermez.</p>';
    })
    .catch(function (error) { host.textContent = error.message; });
  host.addEventListener('submit', async function (event) {
    if (event.target.action.split('?')[0] !== location.origin + '/admin/supplier-operations/application') return;
    event.preventDefault();
    var form = event.target;
    var notice = form.querySelector('#supplier-application-notice');
    var button = form.querySelector('button[type="submit"]');
    button.disabled = true;
    try {
      var response = await fetch(form.action, {method:'POST',credentials:'same-origin',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams(new FormData(form))});
      notice.textContent = response.ok ? 'Başvuru kaydedildi. Durumu görmek için sayfayı yenileyin.' : 'Başvuru kaydedilemedi. Zorunlu alanları ve kategori seçimini kontrol edin.';
    } catch (_) { notice.textContent = 'Bağlantı hatası nedeniyle başvuru kaydedilemedi.'; }
    notice.hidden = false;
    button.disabled = false;
  });
}());
