(function () {
  var table = document.getElementById('team-table-body');
  if (!table) return;
  var locale = (document.documentElement.lang || 'tr').slice(0, 2);
  var namesByLocale = {
    tr: { admin: 'Yönetici', sub_agency: 'Alt acente', supplier: 'Tedarikçi', staff: 'Personel', customer: 'Müşteri' },
    en: { admin: 'Administrator', sub_agency: 'Sub-agency', supplier: 'Supplier', staff: 'Staff', customer: 'Customer' },
    de: { admin: 'Administrator', sub_agency: 'Unteragentur', supplier: 'Lieferant', staff: 'Mitarbeiter', customer: 'Kunde' },
    ru: { admin: 'Администратор', sub_agency: 'Субагентство', supplier: 'Поставщик', staff: 'Персонал', customer: 'Клиент' },
    zh: { admin: '管理员', sub_agency: '子代理', supplier: '供应商', staff: '员工', customer: '客户' },
    fr: { admin: 'Administrateur', sub_agency: 'Sous-agence', supplier: 'Fournisseur', staff: 'Personnel', customer: 'Client' }
  };
  var names = namesByLocale[locale] || namesByLocale.tr;
  var copy = {
    tr: { all: 'Tüm yetkiler', count: 'yetki', none: 'Yetki tanımı yok' },
    en: { all: 'All permissions', count: 'permissions', none: 'No permission definition' },
    de: { all: 'Alle Berechtigungen', count: 'Berechtigungen', none: 'Keine Berechtigungsdefinition' },
    ru: { all: 'Все права', count: 'прав', none: 'Нет определения прав' },
    zh: { all: '全部权限', count: '项权限', none: '未定义权限' },
    fr: { all: 'Toutes les permissions', count: 'permissions', none: 'Aucune définition' }
  }[locale] || { all: 'Tüm yetkiler', count: 'yetki', none: 'Yetki tanımı yok' };
  function cell(value) { var td = document.createElement('td'); td.textContent = value || '—'; return td; }
  function permissionSummary(value) {
    try { var permissions = JSON.parse(value || '[]'); return permissions.indexOf('*') >= 0 ? copy.all : permissions.length + ' ' + copy.count; }
    catch (_) { return copy.none; }
  }
  fetch('/admin/team/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) { if (!response.ok) throw new Error('Üyeler yüklenemedi'); return response.json(); })
    .then(function (users) {
      table.textContent = '';
      if (!users.length) {
        var empty = document.createElement('tr'); var message = cell('Henüz üye yok.');
        message.colSpan = 7; message.className = 'empty-state'; empty.appendChild(message); table.appendChild(empty); return;
      }
      users.forEach(function (user) {
        var row = document.createElement('tr');
        row.appendChild(cell(user.name)); row.appendChild(cell(user.email)); row.appendChild(cell(names[user.membership] || user.membership));
        row.appendChild(cell(user.status)); row.appendChild(cell(user.login)); row.appendChild(cell(user.createdAt)); row.appendChild(cell(permissionSummary(user.permissions))); table.appendChild(row);
      });
    })
    .catch(function (error) { table.textContent = ''; var row = document.createElement('tr'); var message = cell(error.message); message.colSpan = 7; message.className = 'empty-state error'; row.appendChild(message); table.appendChild(row); });
})();
