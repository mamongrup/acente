(function () {
  'use strict';
  var host = document.getElementById('partner-network-workspace');
  if (!host) return;
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]; }); }
  function cookie(name) { return (document.cookie.split('; ').find(function (part) { return part.indexOf(name + '=') === 0; }) || '').slice(name.length + 1); }
  function options(items, valueKey, labelKey, selected, empty) {
    return (empty ? '<option value="">' + esc(empty) + '</option>' : '') + items.map(function (item) {
      return '<option value="' + esc(item[valueKey]) + '"' + (String(item[valueKey]) === String(selected) ? ' selected' : '') + '>' + esc(item[labelKey]) + '</option>';
    }).join('');
  }
  function form(action, inner, button) {
    return '<form class="partner-action-form" data-partner-action="' + esc(action) + '">' + inner + '<button type="submit" class="primary">' + esc(button) + '</button></form>';
  }
  function render(data) {
    var orgs = data.organizations || [], users = data.users || [], leads = data.leads || [], legacy = data.legacyRecords || [];
    var active = orgs.filter(function (org) { return org.status === 'active'; });
    var orgOptions = options(active, 'id', 'name', null, 'Acente seçin');
    host.innerHTML = '<div class="section-heading"><div><h3>Alt acente kuruluşları</h3><p class="muted">Ekipleri ve atanan talepleri kuruluş bazında yönetin.</p></div></div>' +
      form('create', '<label>Yeni kuruluş adı<input name="name" required minlength="2" maxlength="160" placeholder="Acente unvanı"></label>', 'Kuruluş oluştur') +
      '<div class="partner-org-grid">' + (orgs.length ? orgs.map(function (org) {
        return '<article class="partner-org-card"><div><strong>' + esc(org.name) + '</strong> <span class="status-pill">' + esc(org.status === 'active' ? 'Aktif' : 'Askıda') + '</span></div>' +
          '<p class="muted">' + Number(org.customers || 0) + ' müşteri · ' + Number(org.reservations || 0) + ' rezervasyon · ' + Number(org.offers || 0) + ' teklif · ' + Number(org.leads || 0) + ' talep</p>' +
          '<p class="muted">' + (org.members || []).map(function (m) { return esc(m.name) + ' (' + esc(m.role) + ')'; }).join(', ') + '</p>' +
          form('status', '<input type="hidden" name="organization_id" value="' + esc(org.id) + '"><input type="hidden" name="status" value="' + (org.status === 'active' ? 'suspended' : 'active') + '">', org.status === 'active' ? 'Askıya al' : 'Yeniden aç') + '</article>';
      }).join('') : '<p class="muted">Henüz kuruluş bulunmuyor.</p>') + '</div>' +
      '<h3>Ekip üyesini kuruluşa ata</h3>' + form('member', '<label>Üye<select name="user_id" required>' + options(users, 'id', 'email', null, 'Üye seçin') + '</select></label><label>Kuruluş<select name="organization_id" required>' + orgOptions + '</select></label>', 'Üyeyi ata') +
      '<h3>Vitrin taleplerini yönlendir</h3><div class="partner-lead-list">' + (leads.length ? leads.map(function (lead) {
        return '<div class="partner-lead-row"><div><strong>' + esc(lead.name) + '</strong> · ' + esc(lead.listing || 'Genel talep') + '<br><small>' + esc(lead.createdAt) + ' · ' + esc(lead.status) + '</small></div>' +
          form('lead', '<input type="hidden" name="record_id" value="' + esc(lead.id) + '"><select name="organization_id">' + options(active, 'id', 'name', lead.organizationId, 'Atanmamış') + '</select>', 'Kaydet') + '</div>';
      }).join('') : '<p class="muted">Açık talep yok.</p>') + '</div>' +
      '<h3>Eski kayıtları açıkça ata</h3><p class="muted">Sahibi bilinmeyen kayıtlar otomatik paylaşılmaz. İlk 100 kayıt gösterilir.</p>' +
      '<div class="partner-legacy-list">' + (legacy.length ? legacy.map(function (item) {
        var label = {customer:'Müşteri',reservation:'Rezervasyon',offer:'Teklif'}[item.type] || item.type;
        return '<div class="partner-lead-row"><span>' + esc(label) + ': ' + esc(item.label) + '</span>' +
          form('transfer', '<input type="hidden" name="record_id" value="' + esc(item.id) + '"><input type="hidden" name="record_type" value="' + esc(item.type) + '"><select name="organization_id" required>' + orgOptions + '</select>', 'Ata') + '</div>';
      }).join('') : '<p class="muted">Atanmamış eski kayıt yok.</p>') + '</div>';
  }
  function load() {
    fetch('/admin/partner-network/data', {credentials:'same-origin',headers:{Accept:'application/json'},cache:'no-store'})
      .then(function (response) { if (!response.ok) throw Error('Acente ağı yüklenemedi.'); return response.json(); })
      .then(render).catch(function (error) { host.textContent = error.message; });
  }
  host.addEventListener('submit', function (event) {
    var target = event.target;
    if (!target.matches('.partner-action-form')) return;
    event.preventDefault();
    var body = new URLSearchParams(new FormData(target));
    body.set('action', target.dataset.partnerAction);
    body.set('csrf', decodeURIComponent(cookie('nexus_csrf')));
    var button = target.querySelector('button[type=submit]');
    button.disabled = true;
    fetch('/admin/partner-network/actions', {method:'POST',credentials:'same-origin',body:body})
      .then(function (response) { if (!response.ok) throw Error('İşlem tamamlanamadı. Kayıt ve yetkileri kontrol edin.'); load(); })
      .catch(function (error) { alert(error.message); })
      .finally(function () { button.disabled = false; });
  });
  load();
}());
