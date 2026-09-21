// NEXUS Agency — Popups & Banner Live Management
(function () {
  var table = document.getElementById('popups-table-body');
  if (!table) return;

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }

  fetch('/admin/popups/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('Popuplar yüklenemedi');
      return response.json();
    })
    .then(function (popups) {
      table.textContent = '';
      if (!popups.length) {
        var empty = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 5;
        message.className = 'empty-state';
        message.textContent = 'Henüz oluşturulmuş popup yok.';
        empty.appendChild(message);
        table.appendChild(empty);
        return;
      }
      popups.forEach(function (p) {
        var row = document.createElement('tr');
        row.appendChild(cell(p.title));
        row.appendChild(cell(p.kind));
        row.appendChild(cell(p.delaySeconds + ' sn'));
        row.appendChild(cell(p.status));

        var actionTd = document.createElement('td');
        var previewBtn = document.createElement('button');
        previewBtn.className = 'secondary';
        previewBtn.style.padding = '6px 12px';
        previewBtn.style.fontSize = '12px';
        previewBtn.textContent = '👁️ Önizle';
        previewBtn.onclick = function () {
          alert('Popup Başlığı: ' + p.title + '\nİçerik: ' + p.content + '\nButon: ' + p.buttonText);
        };
        actionTd.appendChild(previewBtn);
        row.appendChild(actionTd);
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
