(function () {
  var table = document.getElementById('categories-table-body');
  if (!table) return;
  var parentSelect = document.getElementById('category-parent-id');
  var fieldCategorySelect = document.getElementById('field-category-id');
  var filterCategorySelect = document.getElementById('filter-category-code');
  var filterItemGroupSelect = document.getElementById('filter-item-group-id');
  var fieldsTable = document.getElementById('category-fields-table-body');
  var filterGroupsTable = document.getElementById('category-filter-groups-table-body');

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }

  function csrfInput() {
    var source = document.querySelector('input[name="csrf"], input[name="_csrf"]');
    if (!source) return '';
    return '<input type="hidden" name="' + source.name + '" value="' + source.value.replace(/"/g, '&quot;') + '">';
  }

  function postButton(action, hiddenName, hiddenValue, label) {
    var form = document.createElement('form');
    form.method = 'post';
    form.action = action;
    form.className = 'inline-action-form';
    form.innerHTML = csrfInput()
      + '<input type="hidden" name="' + hiddenName + '" value="' + String(hiddenValue || '').replace(/"/g, '&quot;') + '">'
      + '<button type="submit" class="link-danger" data-confirm="Bu filtreyi pasifleştirmek istediğinize emin misiniz?">' + label + '</button>';
    return form;
  }

  fetch('/admin/categories/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('Kategoriler yüklenemedi');
      return response.json();
    })
    .then(function (categories) {
      table.textContent = '';
      if (parentSelect) {
        parentSelect.textContent = '';
        var rootOption = document.createElement('option');
        rootOption.value = '';
        rootOption.textContent = 'Üst kategori yok';
        parentSelect.appendChild(rootOption);
        categories.forEach(function (category) {
          var option = document.createElement('option');
          option.value = category.id;
          option.textContent = category.name + ' · ' + category.code;
          parentSelect.appendChild(option);
        });
      }
      if (fieldCategorySelect) {
        fieldCategorySelect.textContent = '';
        var chooseOption = document.createElement('option');
        chooseOption.value = '';
        chooseOption.textContent = 'Kategori seçin';
        fieldCategorySelect.appendChild(chooseOption);
        categories.forEach(function (category) {
          var fieldOption = document.createElement('option');
          fieldOption.value = category.id;
          fieldOption.textContent = category.name + ' · ' + category.code;
          fieldCategorySelect.appendChild(fieldOption);
        });
      }
      if (filterCategorySelect) {
        filterCategorySelect.textContent = '';
        var filterChooseOption = document.createElement('option');
        filterChooseOption.value = '';
        filterChooseOption.textContent = 'Kategori seçin';
        filterCategorySelect.appendChild(filterChooseOption);
        categories.forEach(function (category) {
          var filterOption = document.createElement('option');
          filterOption.value = category.code;
          filterOption.textContent = category.name + ' · ' + category.code;
          filterCategorySelect.appendChild(filterOption);
        });
      }
      if (!categories.length) {
        var empty = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 6;
        message.className = 'empty-state';
        message.textContent = 'Henüz kategori kaydı yok.';
        empty.appendChild(message);
        table.appendChild(empty);
        return;
      }
      categories.forEach(function (category) {
        var row = document.createElement('tr');
        row.appendChild(cell(category.parent));
        row.appendChild(cell(category.code));
        row.appendChild(cell(category.name));
        row.appendChild(cell(category.slug));
        row.appendChild(cell(category.status));
        row.appendChild(cell(category.sortOrder));
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

  if (fieldsTable) {
    fetch('/admin/categories/fields-data', { credentials: 'same-origin', cache: 'no-store' })
      .then(function (response) {
        if (!response.ok) throw new Error('Kategori alanları yüklenemedi');
        return response.json();
      })
      .then(function (fields) {
        fieldsTable.textContent = '';
        if (!fields.length) {
          var empty = document.createElement('tr');
          var message = document.createElement('td');
          message.colSpan = 6;
          message.className = 'empty-state';
          message.textContent = 'Henüz kategori alanı tanımlanmadı.';
          empty.appendChild(message);
          fieldsTable.appendChild(empty);
          return;
        }
        fields.forEach(function (field) {
          var row = document.createElement('tr');
          row.appendChild(cell(field.category + ' · ' + field.categoryCode));
          row.appendChild(cell(field.key));
          row.appendChild(cell(field.label));
          row.appendChild(cell(field.type));
          row.appendChild(cell(field.required));
          row.appendChild(cell(field.sortOrder));
          fieldsTable.appendChild(row);
        });
      })
      .catch(function (error) {
        fieldsTable.textContent = '';
        var row = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 6;
        message.className = 'empty-state error';
        message.textContent = error.message;
        row.appendChild(message);
        fieldsTable.appendChild(row);
      });
  }

  if (filterGroupsTable) {
    fetch('/admin/categories/filter-data', { credentials: 'same-origin', cache: 'no-store' })
      .then(function (response) {
        if (!response.ok) throw new Error('Kategori filtreleri yüklenemedi');
        return response.json();
      })
      .then(function (groups) {
        filterGroupsTable.textContent = '';
        if (filterItemGroupSelect) {
          filterItemGroupSelect.textContent = '';
          var chooseGroup = document.createElement('option');
          chooseGroup.value = '';
          chooseGroup.textContent = 'Grup seçin';
          filterItemGroupSelect.appendChild(chooseGroup);
          groups.forEach(function (group) {
            var option = document.createElement('option');
            option.value = group.id;
            option.textContent = group.category + ' · ' + group.title + ' (' + group.key + ')';
            filterItemGroupSelect.appendChild(option);
          });
        }
        if (!groups.length) {
          var empty = document.createElement('tr');
          var message = document.createElement('td');
          message.colSpan = 6;
          message.className = 'empty-state';
          message.textContent = 'Henüz yönetilebilir filtre grubu yok.';
          empty.appendChild(message);
          filterGroupsTable.appendChild(empty);
          return;
        }
        groups.forEach(function (group) {
          var row = document.createElement('tr');
          var items = (group.items || []).map(function (item) {
            return item.title + ' (' + item.key + ')';
          }).join(', ');
          var queued = Number(group.translationsQueued || 0) + (group.items || []).reduce(function (total, item) {
            return total + Number(item.translationsQueued || 0);
          }, 0);
          row.appendChild(cell(group.category));
          row.appendChild(cell(group.title + ' · ' + group.displayType + (group.multiple ? ' · çoklu' : '')));
          row.appendChild(cell(group.key));
          row.appendChild(cell(items || 'Madde yok'));
          row.appendChild(cell(queued ? queued + ' kayıt kuyrukta' : 'Hazır'));
          var actions = document.createElement('td');
          actions.className = 'table-actions';
          actions.appendChild(postButton('/admin/categories/filter-groups/deactivate', 'group_id', group.id, 'Grubu pasifleştir'));
          (group.items || []).forEach(function (item) {
            actions.appendChild(postButton('/admin/categories/filter-items/deactivate', 'item_id', item.id, 'Madde: ' + (item.title || item.key)));
          });
          row.appendChild(actions);
          filterGroupsTable.appendChild(row);
        });
      })
      .catch(function (error) {
        filterGroupsTable.textContent = '';
        var row = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 6;
        message.className = 'empty-state error';
        message.textContent = error.message;
        row.appendChild(message);
        filterGroupsTable.appendChild(row);
      });
  }

  document.addEventListener('submit', function (event) {
    var button = event.submitter;
    var message = button && button.getAttribute('data-confirm');
    if (message && !confirm(message)) event.preventDefault();
  });
})();
