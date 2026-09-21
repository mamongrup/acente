(function () {
  var table = document.getElementById('languages-table-body');
  if (!table) return;

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }

  fetch('/admin/languages/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('Diller yüklenemedi');
      return response.json();
    })
    .then(function (languages) {
      table.textContent = '';
      languages.forEach(function (language) {
        var row = document.createElement('tr');
        // Toplu işlem (bulk) modülü satır kimliği — languages PK'si code
        row.setAttribute('data-row-id', language.code);
        row.appendChild(cell(language.code));
        row.appendChild(cell(language.name));
        row.appendChild(cell(language.nativeName));
        row.appendChild(cell(language.status));
        row.appendChild(cell(language.defaultLabel));
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
