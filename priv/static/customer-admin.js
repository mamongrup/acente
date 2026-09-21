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
