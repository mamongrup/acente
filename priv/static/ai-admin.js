(function () {
  var table = document.getElementById('ai-table-body');
  if (!table) return;

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }

  fetch('/admin/ai/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('AI sağlayıcıları yüklenemedi');
      return response.json();
    })
    .then(function (providers) {
      table.textContent = '';
      if (!providers.length) {
        var empty = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 4;
        message.className = 'empty-state';
        message.textContent = 'Henüz AI sağlayıcısı eklenmedi.';
        empty.appendChild(message);
        table.appendChild(empty);
        return;
      }
      providers.forEach(function (provider) {
        var row = document.createElement('tr');
        row.appendChild(cell(provider.provider));
        row.appendChild(cell(provider.model));
        row.appendChild(cell(provider.status));
        row.appendChild(cell(provider.configured === 'Evet' ? 'Kayıtlı' : 'Eksik'));
        table.appendChild(row);
      });
    })
    .catch(function (error) {
      table.textContent = '';
      var row = document.createElement('tr');
      var message = document.createElement('td');
      message.colSpan = 4;
      message.className = 'empty-state error';
      message.textContent = error.message;
      row.appendChild(message);
      table.appendChild(row);
    });

  var supervisorStatus = document.getElementById('ai-supervisor-status');
  function refreshSupervisorStatus() {
    if (!supervisorStatus) return;
    fetch('/admin/ai/supervisor/status', { credentials: 'same-origin', cache: 'no-store' })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (data) {
        if (!data) return;
        supervisorStatus.textContent = 'Durum: ' + data.status + ' · Bekleyen: ' + data.queued + ' · Başarısız: ' + data.failed + (data.checkedAt ? ' · Son kontrol: ' + data.checkedAt : '');
        supervisorStatus.className = 'ai-supervisor-status ' + (data.status === 'ok' ? 'is-ok' : 'is-degraded');
      }).catch(function () { supervisorStatus.textContent = 'AI Müdür durumu alınamadı.'; });
  }
  refreshSupervisorStatus();
  setInterval(refreshSupervisorStatus, 30000);
})();
