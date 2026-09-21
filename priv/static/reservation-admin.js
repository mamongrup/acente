(function () {
  var table = document.getElementById('reservations-table-body');
  var listingSelect = document.getElementById('reservation-listing');
  var customerSelect = document.getElementById('reservation-customer');

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }

  function addOptions(select, values, emptyLabel) {
    if (!select || !values) return;
    values.forEach(function (item) {
      var option = document.createElement('option');
      option.value = item.id;
      option.textContent = item.name;
      select.appendChild(option);
    });
    if (!values.length) select.options[0].textContent = emptyLabel;
  }

  if (listingSelect || customerSelect) {
    fetch('/admin/reservations/options', { credentials: 'same-origin', cache: 'no-store' })
      .then(function (response) { return response.json(); })
      .then(function (options) {
        addOptions(listingSelect, options.listings, 'Henüz ilan yok');
        addOptions(customerSelect, options.customers, 'Henüz müşteri yok');
      });
  }

  if (!table) return;
  fetch('/admin/reservations/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('Rezervasyonlar yüklenemedi');
      return response.json();
    })
    .then(function (reservations) {
      table.textContent = '';
      if (!reservations.length) {
        var empty = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 5;
        message.className = 'empty-state';
        message.textContent = 'Henüz rezervasyon kaydı yok.';
        empty.appendChild(message);
        table.appendChild(empty);
        return;
      }
      reservations.forEach(function (reservation) {
        var row = document.createElement('tr');
        // Toplu işlem (bulk) modülü satır kimliği
        row.setAttribute('data-row-id', reservation.id);
        row.appendChild(cell(reservation.reference));
        row.appendChild(cell((reservation.customer || 'Müşteri yok') + ' · ' + (reservation.listing || 'İlan yok')));
        row.appendChild(cell((reservation.checkIn || '—') + ' → ' + (reservation.checkOut || '—')));
        row.appendChild(cell(reservation.total + ' ' + reservation.currency));
        row.appendChild(cell(reservation.status + ' / ' + reservation.paymentStatus));
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
