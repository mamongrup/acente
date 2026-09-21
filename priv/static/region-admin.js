(function () {
  var table = document.getElementById('regions-table-body');
  if (!table) return;

  var nameInput = document.getElementById('region-input-name');
  var latInput = document.getElementById('region-input-latitude');
  var lonInput = document.getElementById('region-input-longitude');
  var status = document.getElementById('region-ai-status');
  var geocode = document.getElementById('btn-ai-geocode');
  if (geocode) geocode.addEventListener('click', function () {
    var name = (nameInput && nameInput.value || '').trim();
    if (!name) { if (status) status.textContent = 'Önce ülke veya şehir adı girin.'; return; }
    geocode.disabled = true; if (status) status.textContent = 'Koordinat aranıyor…';
    fetch('https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q=' + encodeURIComponent(name), { headers: { Accept: 'application/json' } })
      .then(function (r) { return r.json(); }).then(function (rows) {
        if (!rows.length) throw new Error('Konum bulunamadı');
        if (latInput) latInput.value = rows[0].lat; if (lonInput) lonInput.value = rows[0].lon;
        if (status) status.textContent = 'Koordinatlar dolduruldu: ' + rows[0].display_name;
      }).catch(function (e) { if (status) status.textContent = e.message; }).finally(function () { geocode.disabled = false; });
  });
  var enrich = document.getElementById('btn-ai-region-enrich');
  if (enrich) enrich.addEventListener('click', function () {
    var desc = document.getElementById('region-input-description'); var name = (nameInput && nameInput.value || '').trim();
    if (!name || !desc) return;
    desc.value = '<h2>' + name + ' keşif rehberi</h2><p>' + name + ' çevresindeki konaklama, ulaşım ve deneyim seçeneklerini tek yerde keşfedin.</p><h3>Yakın deneyimler</h3><ul><li>Yerel lezzetler ve popüler mekanlar</li><li>Doğa, kültür ve deniz aktiviteleri</li><li>Transfer ve araç kiralama seçenekleri</li></ul>';
    if (status) status.textContent = 'Bölge taslağı ve yakın mekan başlıkları oluşturuldu; kaydetmeden önce düzenleyebilirsiniz.';
  });

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }

  fetch('/admin/regions/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('Bölgeler yüklenemedi');
      return response.json();
    })
    .then(function (regions) {
      table.textContent = '';
      if (!regions.length) {
        var empty = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 5;
        message.className = 'empty-state';
        message.textContent = 'Henüz bölge kaydı yok.';
        empty.appendChild(message);
        table.appendChild(empty);
        return;
      }
      regions.forEach(function (region) {
        var row = document.createElement('tr');
        row.appendChild(cell(region.name));
        row.appendChild(cell(region.slug));
        row.appendChild(cell(region.countryCode));
        row.appendChild(cell(region.status));
        row.appendChild(cell(region.createdAt));
        table.appendChild(row);
      });
    })
    .catch(function (error) {
      table.textContent = '';
      var row = document.createElement('tr');
      var message = document.createElement('td');
      message.colSpan = 5;
      message.className = 'empty-state error';
      message.textContent = error.message;
      row.appendChild(message);
      table.appendChild(row);
    });
})();
