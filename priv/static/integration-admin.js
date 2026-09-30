(function () {
  var table = document.getElementById('integrations-table-body');
  if (!table) return;

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }

  document.querySelectorAll('.integration-test-btn').forEach(function (button) {
    button.addEventListener('click', function () {
      var provider = button.getAttribute('data-provider');
      var kind = button.getAttribute('data-kind');
      button.disabled = true; button.textContent = 'Kontrol ediliyor…';
      fetch('/admin/integrations/test?provider=' + encodeURIComponent(provider) + '&kind=' + encodeURIComponent(kind), { credentials: 'same-origin', cache: 'no-store' })
        .then(function (r) { return r.json(); })
        .then(function (data) { button.textContent = data.ok ? '✓ Kayıt var (servis doğrulanmadı)' : '⚠ Bilgi eksik'; button.classList.toggle('is-valid', !!data.ok); })
        .catch(function () { button.textContent = 'Kontrol başarısız'; })
        .finally(function () { button.disabled = false; });
    });
  });

  var nexusRequestButton = document.getElementById('nexus-connection-request');
  if (nexusRequestButton) {
    nexusRequestButton.addEventListener('click', function () {
      var card = nexusRequestButton.closest('form');
      var endpoint = card && card.querySelector('[name="endpoint"]');
      var apiKey = card && card.querySelector('[name="api_key"]');
      var agencyCode = card && card.querySelector('[name="agency_code"]');
      if (!endpoint || !endpoint.value.trim() || !apiKey || !apiKey.value.trim()) {
        nexusRequestButton.textContent = 'Önce adres ve API anahtarını girin';
        nexusRequestButton.classList.add('is-invalid');
        setTimeout(function () { nexusRequestButton.textContent = 'NEXUS\'a bağlantı isteği gönder'; nexusRequestButton.classList.remove('is-invalid'); }, 3500);
        return;
      }
      nexusRequestButton.disabled = true;
      nexusRequestButton.textContent = '⏳ NEXUS bekleniyor…';
      var fd = new FormData();
      fd.append('endpoint', endpoint.value.trim());
      fd.append('api_key', apiKey.value.trim());
      fd.append('agency_code', agencyCode ? agencyCode.value.trim() : '');
      fetch('/admin/nexus/connection-request', { method: 'POST', body: fd, credentials: 'same-origin', headers: { 'Accept': 'application/json' } })
        .then(function (r) { return r.json().catch(function () { return {}; }).then(function (data) { if (!r.ok || data.ok === false) throw new Error(data.error || 'Bağlantı isteği gönderilemedi'); return data; }); })
        .then(function (data) { nexusRequestButton.textContent = '✓ İstek NEXUS onayına gönderildi'; nexusRequestButton.classList.add('is-valid'); if (data.message) nexusRequestButton.title = data.message; })
        .catch(function (error) { nexusRequestButton.textContent = '⚠ ' + error.message; nexusRequestButton.classList.add('is-invalid'); })
        .finally(function () { setTimeout(function () { nexusRequestButton.disabled = false; }, 1200); });
    });
  }

  fetch('/admin/integrations/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('Entegrasyonlar yüklenemedi');
      return response.json();
    })
    .then(function (integrations) {
      table.textContent = '';
      if (!integrations.length) {
        var empty = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 4;
        message.className = 'empty-state';
        message.textContent = 'Henüz bağlantı kaydedilmedi.';
        empty.appendChild(message);
        table.appendChild(empty);
        return;
      }
      integrations.forEach(function (integration) {
        var row = document.createElement('tr');
        row.appendChild(cell(integration.provider));
        row.appendChild(cell(integration.kind));
        row.appendChild(cell(integration.status));
        row.appendChild(cell(integration.configured === 'Evet' ? 'Bilgiler kaydedildi' : 'Bilgi bekleniyor'));
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
})();
