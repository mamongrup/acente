(function () {
  var body = document.getElementById('customers-table-body');
  if (!body) return;

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }

  fetch('/admin/customers/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('Müşteriler yüklenemedi');
      return response.json();
    })
    .then(function (customers) {
      body.textContent = '';
      if (document.querySelector('[data-panel-role="admin"]') && !document.getElementById('customer-recommendation-form')) {
        var workspace = document.getElementById('customers-workspace');
        var form = document.createElement('form');
        form.id = 'customer-recommendation-form';
        form.className = 'customer-form';
        form.method = 'post';
        form.action = '/admin/customers/recommend';
        var csrf = document.cookie.split('; ').find(function (part) { return part.indexOf('nexus_csrf=') === 0; });
        var token = document.createElement('input'); token.type = 'hidden'; token.name = 'csrf'; token.value = csrf ? decodeURIComponent(csrf.slice(11)) : ''; form.appendChild(token);
        var title = document.createElement('h3'); title.textContent = 'Kişisel ilan önerisi gönder'; form.appendChild(title);
        var recipient = document.createElement('select'); recipient.name = 'customer_id'; recipient.required = true;
        var first = document.createElement('option'); first.value = ''; first.textContent = 'Müşteri seçin'; recipient.appendChild(first);
        customers.forEach(function (customer) { var opt = document.createElement('option'); opt.value = customer.id; opt.textContent = customer.name + ' · ' + customer.email; recipient.appendChild(opt); });
        form.appendChild(recipient);
        var listing = document.createElement('input'); listing.name = 'listing_id'; listing.placeholder = 'Yayınlanmış ilan bağlantısı veya kimliği'; listing.required = true; form.appendChild(listing);
        var channel = document.createElement('select'); channel.name = 'channel';
        [['email', 'E-posta'], ['whatsapp', 'WhatsApp']].forEach(function (entry) { var opt = document.createElement('option'); opt.value = entry[0]; opt.textContent = entry[1]; channel.appendChild(opt); }); form.appendChild(channel);
        var send = document.createElement('button'); send.type = 'submit'; send.className = 'primary'; send.textContent = 'Öneri gönder'; form.appendChild(send);
        var note = document.createElement('p'); note.className = 'muted'; note.textContent = 'Yalnızca hesabı bulunan ve seçilen kanala izin veren müşteriler için gönderim kuyruğu oluşturulur.'; form.appendChild(note);
        form.addEventListener('submit', function (event) {
          event.preventDefault();
          var match = listing.value.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i);
          if (!match) { listing.setCustomValidity('Geçerli ilan bağlantısı veya kimliği girin.'); listing.reportValidity(); return; }
          listing.setCustomValidity('');
          var values = new URLSearchParams(new FormData(form)); values.set('listing_id', match[0]);
          send.disabled = true; note.textContent = 'Öneri kuyruğa alınıyor…';
          fetch(form.action, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: values.toString() })
            .then(function (response) { if (!response.ok) throw new Error('Öneri gönderilemedi. Müşteri iznini, hesabını ve ilanın yayın durumunu kontrol edin.'); note.textContent = 'Öneri kuyruğa alındı. Teslim edildiğinde müşterinin hesabında görünecek.'; listing.value = ''; })
            .catch(function (error) { note.textContent = error.message; })
            .finally(function () { send.disabled = false; });
        });
        workspace.insertBefore(form, workspace.querySelector('.table-wrap'));
      }
      if (!customers.length) {
        var empty = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 4;
        message.className = 'empty-state';
        message.textContent = 'Henüz müşteri kaydı yok.';
        empty.appendChild(message);
        body.appendChild(empty);
        return;
      }
      customers.forEach(function (customer) {
        var row = document.createElement('tr');
        // Toplu işlem (bulk) modülü satır kimliği
        row.setAttribute('data-row-id', customer.id);
        row.appendChild(cell(customer.name));
        row.appendChild(cell(customer.email));
        row.appendChild(cell(customer.phone));
        row.appendChild(cell(customer.createdAt));
        body.appendChild(row);
      });
    })
    .catch(function (error) {
      body.textContent = '';
      var row = document.createElement('tr');
      var message = document.createElement('td');
      message.colSpan = 4;
      message.className = 'empty-state error';
      message.textContent = error.message;
      row.appendChild(message);
      body.appendChild(row);
    });
})();
