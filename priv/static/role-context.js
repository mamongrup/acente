(function () {
  'use strict';
  var host = document.getElementById('role-context-content');
  if (!host) return;
  var labels = {admin:'Yönetici', staff:'Personel', supplier:'Tedarikçi', sub_agency:'Alt acente', customer:'Müşteri'};
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>"']/g, function (char) { return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[char]; }); }
  function csrf() { var value = document.cookie.split('; ').find(function (part) { return part.indexOf('nexus_csrf=') === 0; }); return value ? decodeURIComponent(value.slice(11)) : ''; }
  function option(value, label) { return '<option value="' + esc(value) + '">' + esc(label) + '</option>'; }
  fetch('/admin/role-context/data', {credentials:'same-origin', headers:{Accept:'application/json'}, cache:'no-store'})
    .then(function (response) { if (!response.ok) throw new Error('Görev alanları yüklenemedi.'); return response.json(); })
    .then(function (data) {
      var roles = data.roles || [];
      var roleForms = roles.map(function (role) {
        return '<form method="post" action="/admin/role-context/switch" class="partner-action-form">' +
          '<input type="hidden" name="csrf" value="' + esc(csrf()) + '">' +
          '<input type="hidden" name="role" value="' + esc(role) + '">' +
          '<button type="submit"' + (role === data.activeRole ? ' disabled aria-current="true"' : '') + '>' + esc(labels[role] || role) + (role === data.activeRole ? ' · Etkin' : '') + '</button></form>';
      }).join('');
      var grant = '';
      if (data.activeRole === 'admin') {
        var assignments = (data.users || []).map(function (user) {
          return (user.extraRoles || []).map(function (role) {
            return '<form method="post" action="/admin/role-context/revoke" class="partner-action-form">' +
              '<input type="hidden" name="csrf" value="' + esc(csrf()) + '">' +
              '<input type="hidden" name="user_id" value="' + esc(user.id) + '">' +
              '<input type="hidden" name="role" value="' + esc(role) + '">' +
              '<span>' + esc(user.name) + ' · ' + esc(labels[role] || role) + '</span>' +
              '<button type="submit">Kaldır</button></form>';
          }).join('');
        }).join('');
        grant = '<section class="quick" style="margin-top:20px"><h3>Kullanıcıya görev alanı ekle</h3><form method="post" action="/admin/role-context/grant" class="partner-action-form">' +
          '<input type="hidden" name="csrf" value="' + esc(csrf()) + '"><select name="user_id" required aria-label="Kullanıcı">' + option('', 'Kullanıcı seçin') +
          (data.users || []).map(function (user) { return option(user.id, user.name + ' · ' + user.email); }).join('') + '</select>' +
          '<select name="role" required aria-label="Görev alanı">' + option('', 'Görev alanı seçin') +
          ['admin','staff','supplier','sub_agency'].map(function (role) { return option(role, labels[role]); }).join('') +
          '</select><button type="submit">Rol ekle</button></form><p class="muted">Alt acente kayıtlarına erişim için ayrıca kuruluş üyeliği gerekir.</p>' +
          (assignments ? '<h3>Ek görev alanları</h3>' + assignments : '') + '</section>';
      }
      host.innerHTML = '<div class="partner-action-form">' + roleForms + '</div>' + grant;
    })
    .catch(function (error) { host.textContent = error.message; });
}());
