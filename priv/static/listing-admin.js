// NEXUS Agency — Catalog & Service Inventory (Interactive Live Sync, Real Data Selection & Actions)
(function () {
  var table = document.getElementById('listings-table-body');
  if (!table) return;

  var allListings = [];
  var currentCategory = 'all';
  var selectedListingId = null;

  // İlan hazırlık hesaplama — zorunlu alanların doluluğuna göre puan
  var REQUIRED_FIELDS = [
    { key: 'code', label: 'Kod' },
    { key: 'title', label: 'Başlık' },
    { key: 'category', label: 'Kategori' },
    { key: 'locality', label: 'Konum' },
    { key: 'priceMinor', label: 'Fiyat', test: function (v) { return v && v > 0; } },
    { key: 'currency', label: 'Para birimi' },
    { key: 'description', label: 'Açıklama' },
    { key: 'images', label: 'Görsel', test: function (v) { return Array.isArray(v) ? v.length > 0 : !!v; } },
    { key: 'cancellationPolicy', label: 'İptal/iade politikası' },
    { key: 'status', label: 'Durum', test: function (v) { return v && v !== 'draft'; } },
  ];

  function parseListingMetadata(listing) {
    if (!listing || !listing.metadata) return {};
    if (typeof listing.metadata === 'object') return listing.metadata;
    try { return JSON.parse(listing.metadata) || {}; } catch (_) { return {}; }
  }

  function listingContractState(listing) {
    var meta = parseListingMetadata(listing);
    var complete = meta.contract_required_complete;
    if (complete === undefined && meta.extra_metadata && typeof meta.extra_metadata === 'object') {
      complete = meta.extra_metadata.contract_required_complete;
    }
    return {
      complete: complete !== false,
      version: meta.contract_version || (meta.extra_metadata && meta.extra_metadata.contract_version) || '1.0.0'
    };
  }

  function calcReadiness(listing) {
    var filled = 0;
    var missing = [];
    var meta = parseListingMetadata(listing);
    REQUIRED_FIELDS.forEach(function (f) {
      var val = listing[f.key];
      if ((val === undefined || val === null || val === '') && meta) {
        if (f.key === 'cancellationPolicy') {
          val = listing.cancellation_policy || meta.cancellation_policy || meta.cancellationPolicy;
        } else {
          val = meta[f.key];
        }
      }
      var ok = f.test ? f.test(val) : !!val && String(val).trim() !== '';
      if (ok) filled++;
      else missing.push(f.label);
    });
    var contract = listingContractState(listing);
    if (!contract.complete) {
      missing.push('Sözleşme alanları');
    }
    var total = REQUIRED_FIELDS.length + (contract.complete ? 0 : 1);
    return { filled: filled, total: total, pct: Math.round((filled / total) * 100), missing: missing };
  }

  function readinessBadge(r) {
    var cls, icon;
    if (r.pct === 100) { cls = 'readiness-full'; icon = '✓'; }
    else if (r.pct >= 70) { cls = 'readiness-good'; icon = r.pct + '%'; }
    else if (r.pct >= 40) { cls = 'readiness-partial'; icon = r.pct + '%'; }
    else { cls = 'readiness-low'; icon = r.pct + '%'; }
    var tip = r.pct === 100
      ? 'Tüm zorunlu alanlar dolu — yayına hazır'
      : r.missing.length + ' eksik alan: ' + r.missing.join(', ');
    return '<span class="readiness-badge ' + cls + '" title="' + tip.replace(/"/g, '&quot;') + '">' + icon + '</span>';
  }

  var categoryLabels = {
    hotel: '🏨 Otel',
    holiday_home: '🏡 Tatil Evi',
    yacht: '⛵ Yat',
    tour: '🗺️ Tur',
    activity: '🪂 Aktivite',
    flight: '✈️ Uçuş',
    car: '🚗 Araç',
    cruise: '🚢 Kruvaziyer',
    pilgrimage: '🕌 Hac & Umre',
    visa: '🛂 Vize',
    ferry: '⛴️ Feribot',
    transfer: '🚐 Transfer',
    beach: '🏖️ Şezlong',
    cinema: '🎬 Sinema',
    event: '🎭 Etkinlik',
    restaurant: '🍽️ Restoran',
    bus: '🚌 Otobüs',
    villa: '🏡 Tatil Evi',
    flight_bus: '✈️ Uçuş',
    hajj: '🕌 Hac & Umre',
    sunbed: '🏖️ Şezlong',
    car_rental: '🚗 Araç'
  };

  var categoryUnits = {
    hotel: 'gece', holiday_home: 'gece', villa: 'gece', yacht: 'gün',
    tour: 'kişi', activity: 'kişi', flight_bus: 'kişi', flight: 'kişi',
    bus: 'kişi', ferry: 'kişi', cruise: 'kişi', hajj: 'kişi',
    pilgrimage: 'kişi', visa: 'kişi', event: 'kişi', cinema: 'kişi',
    restaurant: 'kişi', sunbed: 'kişi', beach: 'kişi', car: 'gün',
    car_rental: 'gün', transfer: 'transfer'
  };

  function canonicalCategory(category) {
    var c = (category || '').toLowerCase();
    if (c === 'villa') return 'holiday_home';
    if (c === 'flight_bus') return 'flight';
    if (c === 'hajj') return 'pilgrimage';
    if (c === 'sunbed') return 'beach';
    if (c === 'car_rental') return 'car';
    return c;
  }

  function categoryUnit(category) {
    return categoryUnits[(category || '').toLowerCase()] || 'hizmet';
  }

  function formatPrice(minor, currency) {
    if (minor === undefined || minor === null) return '—';
    var val = Number(minor) / 100;
    var formatted = val.toLocaleString('tr-TR', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
    var sym = currency === 'TRY' ? '₺' : (currency === 'USD' ? '$' : (currency === 'EUR' ? '€' : (currency === 'GBP' ? '£' : '')));
    return (sym ? sym + ' ' : '') + formatted + (sym ? '' : ' ' + currency);
  }

  function formatStatus(status) {
    var s = (status || 'published').toLowerCase();
    var label = 'Yayında';
    var cls = 'published';
    if (s === 'draft') {
      label = 'Taslak';
      cls = 'draft';
    } else if (s === 'review') {
      label = 'İncelemede';
      cls = 'review';
    } else if (s === 'paused') {
      label = 'Duraklatıldı';
      cls = 'warning';
    }
    return '<span class="status-pill ' + cls + '">' + label + '</span>';
  }

  function selectListing(listing, rowElem) {
    if (!listing) return;
    selectedListingId = listing.id;

    // Highlight row
    document.querySelectorAll('.catalog-row.selected-row').forEach(function (r) {
      r.classList.remove('selected-row');
    });
    if (rowElem) {
      rowElem.classList.add('selected-row');
    } else {
      var found = table.querySelector('[data-id="' + listing.id + '"]');
      if (found) found.classList.add('selected-row');
    }

    // Load into wizard and update live preview card
    if (window.loadListingIntoWizard) {
      window.loadListingIntoWizard(listing);
    }
  }

  function renderRows(items) {
    table.textContent = '';

    // Update count badge
    var countBadge = document.getElementById('listings-count-badge');
    if (countBadge) {
      countBadge.textContent = items.length + ' İlan';
    }

    if (!items.length) {
      var empty = document.createElement('tr');
      var message = document.createElement('td');
      message.colSpan = 7;
      message.className = 'empty-state';
      message.textContent = currentCategory === 'all'
        ? 'Henüz kayıtlı hizmet veya ilan yok. Yukarıdaki formdan ilk ilanınızı ekleyebilirsiniz.'
        : 'Bu kategoride henüz kayıtlı ürün bulunmuyor.';
      empty.appendChild(message);
      table.appendChild(empty);
      return;
    }

    items.forEach(function (listing) {
      var row = document.createElement('tr');
      row.className = 'catalog-row clickable-row' + (selectedListingId === listing.id ? ' selected-row' : '');
      row.setAttribute('data-id', listing.id);
      row.setAttribute('data-row-id', listing.id);
      row.setAttribute('data-code', listing.code);

      // Code
      var tdCode = document.createElement('td');
      var codeBadge = document.createElement('span');
      codeBadge.className = 'code-badge';
      codeBadge.textContent = listing.code || '—';
      tdCode.appendChild(codeBadge);
      row.appendChild(tdCode);

      // Title
      var tdTitle = document.createElement('td');
      var titleText = document.createElement('strong');
      titleText.className = 'listing-title-text';
      titleText.textContent = listing.title || '—';
      tdTitle.appendChild(titleText);
      var contractState = listingContractState(listing);
      if (!contractState.complete) {
        var contractWarn = document.createElement('small');
        contractWarn.className = 'contract-warning';
        contractWarn.textContent = '⚠ Sözleşme alanları eksik';
        contractWarn.title = 'Bu ilan zorunlu kategori sözleşme alanları tamamlanmadan yayına alınamaz.';
        tdTitle.appendChild(contractWarn);
      }
      row.appendChild(tdTitle);

      // Category
      var tdCat = document.createElement('td');
      var catKey = canonicalCategory(listing.category);
      var catName = categoryLabels[catKey] || listing.category || '—';
      var catPill = document.createElement('span');
      catPill.className = 'cat-pill';
      catPill.textContent = catName;
      tdCat.appendChild(catPill);
      row.appendChild(tdCat);

      // Locality
      var tdLoc = document.createElement('td');
      tdLoc.textContent = listing.locality ? '📍 ' + listing.locality : '—';
      row.appendChild(tdLoc);

      // Price
      var tdPrice = document.createElement('td');
      var priceStrong = document.createElement('span');
      priceStrong.className = 'price-strong';
      priceStrong.textContent = formatPrice(listing.priceMinor, listing.currency || 'TRY');
      var priceUnit = document.createElement('small');
      priceUnit.className = 'text-muted';
      priceUnit.textContent = ' / ' + categoryUnit(catKey);
      tdPrice.appendChild(priceStrong);
      tdPrice.appendChild(priceUnit);
      row.appendChild(tdPrice);

      // Status
      var tdStatus = document.createElement('td');
      tdStatus.innerHTML = formatStatus(listing.status);
      row.appendChild(tdStatus);

      // Readiness
      var tdReady = document.createElement('td');
      tdReady.className = 'readiness-cell';
      var readiness = calcReadiness(listing);
      tdReady.innerHTML = readinessBadge(readiness);
      row.appendChild(tdReady);

      // Actions Column
      var tdActions = document.createElement('td');
      tdActions.className = 'text-right action-cell';

      var editBtn = document.createElement('button');
      editBtn.className = 'btn-table-action btn-edit-listing';
      editBtn.type = 'button';
      editBtn.innerHTML = '✏️ Düzenle';
      editBtn.title = 'İlanı Sihirbaza Yükle ve Canlı İncele';
      editBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        selectListing(listing, row);
      });
      tdActions.appendChild(editBtn);

      var deleteBtn = document.createElement('button');
      deleteBtn.className = 'btn-table-action btn-delete-listing';
      deleteBtn.type = 'button';
      deleteBtn.innerHTML = '🗑️';
      deleteBtn.title = 'İlanı Sil';
      deleteBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        if (confirm('"' + (listing.title || listing.code) + '" ilanını katalogdan silmek istediğinize emin misiniz?')) {
          var fd = new FormData();
          fd.append('id', listing.id);
          fetch('/admin/catalog/delete', {
            method: 'POST',
            body: fd,
            credentials: 'same-origin'
          }).then(function () {
            window.location.reload();
          });
        }
      });
      tdActions.appendChild(deleteBtn);

      row.appendChild(tdActions);

      // Clicking anywhere on the row selects it and updates preview
      row.addEventListener('click', function () {
        selectListing(listing, row);
      });

      table.appendChild(row);
    });
  }

  function populateListingSelectors(listings) {
    var selectors = [
      document.getElementById('rate-listing-id'),
      document.getElementById('availability-listing-id')
    ];
    selectors.forEach(function (select) {
      if (!select) return;
      var curVal = select.value;
      select.innerHTML = '<option value="">İlan seçin...</option>';
      listings.forEach(function (item) {
        var opt = document.createElement('option');
        opt.value = item.id;
        opt.textContent = (item.code ? '[' + item.code + '] ' : '') + item.title + (item.locality ? ' — ' + item.locality : '');
        select.appendChild(opt);
      });
      if (curVal) select.value = curVal;
    });
  }

  function filterByCategory(cat) {
    currentCategory = cat;
    if (!cat || cat === 'all') {
      renderRows(allListings);
    } else {
      var filtered = allListings.filter(function (item) {
        var c = canonicalCategory(item.category);
        return c === canonicalCategory(cat);
      });
      renderRows(filtered);
    }
  }

  // Bind top table "+ Yeni İlan Ekle" button
  // Keep the create/edit flow focused: the inventory table belongs to “Tüm İlanlar”.
  function syncCatalogEditorMode() {
    var inventory = document.querySelector('.catalog-listings-table');
    if (!inventory) return;
    var params = new URLSearchParams(window.location.search);
    var editorMode = window.location.hash === '#catalog-workspace' || params.has('code');
    inventory.classList.toggle('editor-mode-hidden', editorMode);
    inventory.setAttribute('aria-hidden', editorMode ? 'true' : 'false');
  }
  syncCatalogEditorMode();
  window.addEventListener('hashchange', syncCatalogEditorMode);

  var btnTableNew = document.getElementById('btn-table-new-listing');
  if (btnTableNew) {
    btnTableNew.addEventListener('click', function () {
      selectedListingId = null;
      if (window.resetWizardForm) {
        window.resetWizardForm();
      }
      var targetElem = document.getElementById('catalog-workspace');
      if (targetElem) {
        targetElem.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  }

  // Fetch real listings
  fetch('/admin/catalog/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (res) {
      if (!res.ok) return fetch('/admin/listings/data', { credentials: 'same-origin', cache: 'no-store' });
      return res;
    })
    .then(function (response) {
      if (!response.ok) throw new Error('Katalog verileri yüklenemedi');
      return response.json();
    })
    .then(function (listings) {
      allListings = listings || [];
      populateListingSelectors(allListings);

      var urlParams = new URLSearchParams(window.location.search);
      var catParam = urlParams.get('cat');
      var codeParam = urlParams.get('code');

      if (catParam) {
        currentCategory = catParam;
        filterByCategory(catParam);
        var catInput = document.getElementById('catalog-category-input');
        if (catInput) catInput.value = catParam;
      } else {
        renderRows(allListings);
      }

      // If listings exist, load either requested code or the first listing into the wizard & live preview card!
      if (allListings.length > 0) {
        var toSelect = allListings[0];
        if (codeParam) {
          var found = allListings.find(function (it) { return it.code === codeParam; });
          if (found) toSelect = found;
        }
        selectListing(toSelect);
      }
    })
    .catch(function (error) {
      table.textContent = '';
      var row = document.createElement('tr');
      var message = document.createElement('td');
      message.colSpan = 7;
      message.className = 'empty-state error';
      message.textContent = error.message;
      row.appendChild(message);
      table.appendChild(row);
    });
})();
