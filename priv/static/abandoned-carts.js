// NEXUS Agency — Abandoned Cart Recovery & Notification Trigger
(function () {
  var table = document.getElementById('abandoned-carts-table-body');
  if (!table) return;

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }

  fetch('/admin/abandoned-carts/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('Sepet verileri alınamadı');
      return response.json();
    })
    .then(function (carts) {
      table.textContent = '';
      if (!carts.length) {
        var empty = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 6;
        message.className = 'empty-state';
        message.textContent = 'Henüz bekleyen veya terk edilmiş sepet kaydı yok.';
        empty.appendChild(message);
        table.appendChild(empty);
        return;
      }
      carts.forEach(function (c) {
        var row = document.createElement('tr');
        row.appendChild(cell(c.customerName || 'Ziyaretçi'));
        row.appendChild(cell(c.customerContact || '—'));
        row.appendChild(cell(c.itemCount + ' Ürün'));
        row.appendChild(cell(c.totalMinor + ' ' + c.currency));
        row.appendChild(cell(c.lastActivity));

        var actionTd = document.createElement('td');
        var btn = document.createElement('button');
        btn.className = 'secondary';
        btn.style.padding = '6px 12px';
        btn.style.fontSize = '12px';
        btn.textContent = '🔔 Hatırlatma Gönder';
        btn.onclick = function () {
          btn.disabled = true;
          btn.textContent = 'Gönderiliyor…';
          fetch('/admin/abandoned-carts/notify', {
            method: 'POST',
            credentials: 'same-origin',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: 'cart_id=' + encodeURIComponent(c.id)
          }).then(function (r) {
            if (r.ok) {
              btn.textContent = '✓ Kuyruğa alındı (SMS/Mail)';
              btn.style.borderColor = '#10b981';
              btn.style.color = '#34d399';
            } else {
              btn.disabled = false;
              btn.textContent = 'Tekrar Dene';
            }
          }).catch(function () {
            btn.disabled = false;
            btn.textContent = 'Tekrar Dene';
          });
        };
        actionTd.appendChild(btn);
        row.appendChild(actionTd);
        table.appendChild(row);
      });
    })
    .catch(function (error) {
      table.textContent = '';
      var row = document.createElement('tr');
      var message = document.createElement('td');
      message.colSpan = 6;
      message.className = 'empty-state error';
      message.textContent = error.message;
      row.appendChild(message);
      table.appendChild(row);
    });
})();
