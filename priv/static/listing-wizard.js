// NEXUS Agency — gelişmiş ilan oluşturma ve manuel giriş motoru
(function () {
  'use strict';

  var form = document.getElementById('airbnb-listing-form');
  if (!form) return;

  var categoryInput = document.getElementById('catalog-category-input');
  var currentCat = categoryInput ? categoryInput.value : 'hotel';
  var isHotel = currentCat === 'hotel' || currentCat === 'otel';
  var isVilla = currentCat === 'holiday_home' || currentCat === 'villa';
  var isYacht = currentCat === 'yacht';
  var isTour = currentCat === 'tour';
  var isCar = currentCat === 'car';
  var isTransfer = currentCat === 'transfer';
  var isActivity = currentCat === 'activity';

  // --- State ---
  var currentStep = 1;
  var totalSteps = 7;
  var formMode = 'stepper'; // 'stepper' or 'full'

  var selectedAmenities = [];

  // --- Dirty Form Guard ---
  // Form ilk yüklendiğindeki halini.snapshot alır, değişim olup olmadığını kontrol eder.
  var formSnapshot = '';
  var suppressDirtyGuard = false;

  function captureFormSnapshot() {
    if (!form) return '';
    var parts = [];
    var fields = form.querySelectorAll('input, select, textarea');
    fields.forEach(function (f) {
      if (f.type === 'hidden' || f.type === 'submit' || f.type === 'button') return;
      parts.push(f.name + '=' + (f.value || ''));
    });
    return parts.join('|');
  }

  function isFormDirty() {
    if (suppressDirtyGuard) return false;
    return captureFormSnapshot() !== formSnapshot;
  }

  function markFormClean() {
    formSnapshot = captureFormSnapshot();
  }

  // Guard: form kirliyse onay iste, izin verirse devam et
  function guardDirty(action) {
    if (!isFormDirty()) { action(); return; }
    if (confirm('Kaydedilmemiş değişiklikler var. Yine de devam etmek istiyor musunuz?')) {
      action();
    }
  }
  var images = [];
  var roomTypes = [];
  // Editorial sections only: these do not change category validation rules.
  var hotelSections = [];
  var hotelContract = '';
  var hotelHouseRules = {};
  var hotelSectionTitles = ['Konsept', 'Otel Olanakları', 'Yeme & İçme', 'Spor & Eğlence', 'Plaj', 'Çocuk & Bebek', 'Spa & Wellness', 'Balayı'];
  function renderHotelSections() {
    var anchor = document.getElementById('room-types-container');
    if (!anchor) return;
    var editor = document.getElementById('hotel-sections-editor');
    if (!editor) { editor = document.createElement('section'); editor.id = 'hotel-sections-editor'; anchor.after(editor); }
    editor.replaceChildren();
    var contractLabel = document.createElement('label'); contractLabel.textContent = 'Otele ait sözleşme';
    var contractInput = document.createElement('textarea'); contractInput.value = hotelContract; contractInput.rows = 6; contractInput.setAttribute('aria-label', 'Otele ait sözleşme'); contractInput.style.cssText = 'display:block;width:100%;margin:10px 0 24px'; contractInput.addEventListener('input', function () { hotelContract = contractInput.value; }); contractLabel.appendChild(contractInput); editor.appendChild(contractLabel);
    [['children', 'Çocuklara uygun'], ['pets', 'Evcil hayvan kabul edilir'], ['events', 'Etkinliklere uygun'], ['smoking', 'İç mekanda sigara içilir']].forEach(function (rule) {
      var label = document.createElement('label'); label.textContent = rule[1] + ' '; label.style.cssText = 'display:block;margin:12px 0';
      var select = document.createElement('select'); select.setAttribute('aria-label', rule[1]);
      [['', 'Belirtilmedi'], ['yes', 'Evet'], ['no', 'Hayır']].forEach(function (option) { var node = document.createElement('option'); node.value = option[0]; node.textContent = option[1]; select.appendChild(node); });
      select.value = hotelHouseRules[rule[0]] || ''; select.addEventListener('change', function () { hotelHouseRules[rule[0]] = select.value; }); label.appendChild(select); editor.appendChild(label);
    });
    var heading = document.createElement('h3'); heading.textContent = 'Tesis bilgi bölümleri'; editor.appendChild(heading);
    hotelSections.forEach(function (entry, index) {
      var row = document.createElement('div'); row.style.cssText = 'padding:16px;border:1px solid #e5e7eb;border-radius:12px;margin:12px 0';
      var title = document.createElement('input'); title.value = entry.title || ''; title.placeholder = 'Bölüm başlığı'; title.setAttribute('aria-label', 'Bölüm başlığı');
      title.addEventListener('input', function () { entry.title = title.value; });
      var body = document.createElement('textarea'); body.value = entry.content || ''; body.placeholder = 'Bölüm açıklaması'; body.rows = 4; body.setAttribute('aria-label', 'Bölüm açıklaması'); body.style.cssText = 'display:block;width:100%;margin:10px 0'; body.addEventListener('input', function () { entry.content = body.value; });
      row.append(title, body);
      [['Yukarı', -1], ['Aşağı', 1], ['Sil', 0]].forEach(function (action) {
        var button = document.createElement('button'); button.type = 'button'; button.textContent = action[0]; button.style.marginRight = '10px';
        button.addEventListener('click', function () { if (!action[1]) hotelSections.splice(index, 1); else { var target = index + action[1]; if (target < 0 || target >= hotelSections.length) return; var item = hotelSections.splice(index, 1)[0]; hotelSections.splice(target, 0, item); } renderHotelSections(); }); row.appendChild(button);
      }); editor.appendChild(row);
    });
    var add = document.createElement('button'); add.type = 'button'; add.textContent = 'Bölüm ekle'; add.addEventListener('click', function () { hotelSections.push({title: '', content: ''}); renderHotelSections(); }); editor.appendChild(add);
  }
  hotelSections = hotelSectionTitles.map(function (title) { return {title: title, content: ''}; });
  setTimeout(renderHotelSections, 0);

  var stepLabels = [
    isYacht ? 'Kalkış Limanı & Rota →' : isTransfer ? 'Güzergâh & Bölgeler →' : 'Konum & Lokasyon →',
    isHotel ? 'Oda Tipleri & Kapasite →' : isYacht ? 'Kabin, Mürettebat & Tekne →' : isTour ? 'Tur Süresi & Güzergâh →' : isCar ? 'Araç Sınıfı & Kasko →' : 'Kapasite, Odalar & Havuz →',
    isHotel ? 'Tesis İmkânları →' : isYacht ? 'Tekne Donanımları →' : isTour ? 'Dahil / Hariç Hizmetler →' : 'Tatil Evi Donanımları →',
    'Fotoğraflar & Galeri →',
    isHotel ? 'Fiyat & Çocuk Politikası →' : isVilla ? 'Fiyat, Ek Masraflar & iCal →' : 'Fiyatlandırma & Takvim →',
    'Önizleme & Onay →',
    '✓ Kataloğa Kaydet ve Yayınla'
  ];

  // --- Toast Notification Helper ---
  var toastContainer = document.getElementById('wizard-toast-container');
  function escapeHtml(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (char) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char];
    });
  }

  function showToast(message, type) {
    if (!toastContainer) {
      toastContainer = document.createElement('div');
      toastContainer.id = 'wizard-toast-container';
      toastContainer.className = 'wizard-toast-container';
      toastContainer.setAttribute('aria-live', 'polite');
      toastContainer.setAttribute('aria-atomic', 'false');
      toastContainer.setAttribute('role', 'status');
      document.body.appendChild(toastContainer);
    }

    var toast = document.createElement('div');
    toast.className = 'wizard-toast toast-' + (type || 'info');
    toast.setAttribute('role', 'alert');
    toast.setAttribute('aria-atomic', 'true');

    var icon = 'ℹ️';
    if (type === 'success') icon = '✅';
    if (type === 'warning') icon = '⚠️';
    if (type === 'error') icon = '❌';

    var srLabel = type === 'success' ? 'Basarili' : type === 'warning' ? 'Uyari' : type === 'error' ? 'Hata' : 'Bilgi';
    toast.innerHTML = '<span class="toast-icon" aria-hidden="true">' + icon + '</span>'
      + '<span class="toast-msg">' + escapeHtml(message) + '</span>'
      + '<span class="wizard-sr-only">' + srLabel + ': ' + escapeHtml(message) + '</span>';
    toastContainer.appendChild(toast);

    setTimeout(function () {
      toast.classList.add('show');
    }, 20);

    setTimeout(function () {
      toast.classList.remove('show');
      setTimeout(function () {
        if (toast.parentNode) toast.parentNode.removeChild(toast);
      }, 300);
    }, 3800);
  }

  // --- Shared supplier/listing contract fields ---
  var contractFields = [];
  var contractFieldsReady = false;

  function normalizeContractCategory(value) {
    var slug = String(value || 'hotel').trim().toLowerCase();
    if (slug === 'villa') return 'holiday_home';
    if (slug === 'flight_bus') return 'flight';
    if (slug === 'hajj') return 'pilgrimage';
    if (slug === 'sunbed') return 'beach';
    return slug || 'hotel';
  }

  function loadManagedFilterSelects() {
    var selects = Array.prototype.slice.call(form.querySelectorAll('select'));
    if (!selects.length) return;
    fetch('/admin/categories/filter-data', { credentials: 'same-origin', cache: 'no-store' })
      .then(function (response) {
        if (!response.ok) throw new Error('Yönetilebilir filtreler okunamadı');
        return response.json();
      })
      .then(function (groups) {
        if (!Array.isArray(groups)) return;
        var categoryGroups = groups.filter(function (item) {
          return normalizeContractCategory(item.category) === normalizeContractCategory(currentCat);
        });
        if (!categoryGroups.length) return;
        selects.forEach(function (select) {
          var explicitCategory = select.getAttribute('data-managed-filter-category');
          var category = normalizeContractCategory(explicitCategory || currentCat);
          if (category !== normalizeContractCategory(currentCat)) return;
          var key = select.getAttribute('data-managed-filter-key')
            || select.dataset.contractField
            || select.name
            || '';
          if (key.indexOf('attr_') === 0) key = key.slice(5);
          var selected = select.value;
          var group = categoryGroups.find(function (item) {
            return item.key === key || item.contractFieldKey === key;
          });
          if (!group || !Array.isArray(group.items) || !group.items.length) return;
          select.textContent = '';
          var empty = document.createElement('option');
          empty.value = '';
          empty.textContent = 'Seçiniz';
          select.appendChild(empty);
          group.items.forEach(function (item) {
            var option = document.createElement('option');
            option.value = item.contractValue || item.title || item.key;
            option.textContent = item.title || item.key;
            option.setAttribute('data-filter-item-key', item.key || '');
            select.appendChild(option);
          });
          var canKeepSelected = Array.prototype.some.call(select.options, function (option) {
            return option.value === selected;
          });
          if (canKeepSelected) select.value = selected;
          select.dispatchEvent(new Event('change', { bubbles: true }));
        });
        markFormClean();
      })
      .catch(function () {
        // Bağımsız çalışma modunda veya geçici ağ hatasında formdaki fallback
        // seçenekler kullanılmaya devam eder.
      });
  }

  function parseContractOptions(raw) {
    if (!raw) return [];
    var value = raw;
    if (typeof raw === 'string') {
      try { value = JSON.parse(raw); } catch (_) { return []; }
    }
    if (Array.isArray(value)) return value;
    if (Array.isArray(value.values)) return value.values;
    if (value && typeof value === 'object') {
      return Object.keys(value).map(function (key) {
        return { value: key, label: value[key] };
      });
    }
    return [];
  }

  function contractFieldId(field) {
    return 'contract-field-' + String(field.key || '').replace(/[^a-z0-9_-]/gi, '-');
  }

  function renderContractField(field) {
    var id = contractFieldId(field);
    var type = String(field.type || 'text').toLowerCase();
    var options = parseContractOptions(field.options);
    var wrapper = document.createElement('label');
    wrapper.className = 'contract-field';
    wrapper.innerHTML =
      '<span>' + escapeHtml(field.label || field.key) + (field.required ? ' <em>*</em>' : '') + '</span>';

    var control;
    if (type === 'textarea' || type === 'json') {
      control = document.createElement('textarea');
      control.rows = type === 'json' ? 4 : 3;
    } else if (type === 'select' || options.length) {
      control = document.createElement('select');
      var empty = document.createElement('option');
      empty.value = '';
      empty.textContent = 'Seçiniz';
      control.appendChild(empty);
      options.forEach(function (option) {
        var optionEl = document.createElement('option');
        if (option && typeof option === 'object') {
          optionEl.value = option.value || option.code || option.label || '';
          optionEl.textContent = option.label || option.name || option.value || option.code || '';
        } else {
          optionEl.value = option;
          optionEl.textContent = option;
        }
        control.appendChild(optionEl);
      });
    } else if (type === 'boolean') {
      control = document.createElement('select');
      [['', 'Seçiniz'], ['true', 'Evet'], ['false', 'Hayır']].forEach(function (pair) {
        var optionEl = document.createElement('option');
        optionEl.value = pair[0];
        optionEl.textContent = pair[1];
        control.appendChild(optionEl);
      });
    } else {
      control = document.createElement('input');
      control.type = type === 'number' || type === 'integer' ? 'number' : 'text';
      if (type === 'number') control.step = '0.01';
    }

    control.id = id;
    control.dataset.contractField = field.key || '';
    control.dataset.contractType = type;
    control.dataset.managedFilterCategory = normalizeContractCategory(currentCat);
    control.dataset.managedFilterKey = field.key || '';
    control.required = !!field.required;
    wrapper.appendChild(control);
    return wrapper;
  }

  function ensureContractFieldsContainer() {
    var existing = document.getElementById('wizard-contract-fields');
    if (existing) return existing;

    var section = document.createElement('section');
    section.id = 'wizard-contract-fields';
    section.className = 'wizard-contract-fields hidden';
    section.innerHTML =
      '<div class="contract-fields-head">' +
      '<div><strong>Kategori sözleşme alanları</strong><p>Bu alanlar NEXUS tedarikçi sözleşmesinden gelir ve iki projede aynı tutulur.</p></div>' +
      '<span class="contract-version">v1.0.0</span>' +
      '</div>' +
      '<div class="contract-fields-grid" data-contract-fields-grid></div>';

    var extraMetaInput = document.getElementById('wizard-extra-metadata-input');
    if (extraMetaInput && extraMetaInput.parentNode) {
      extraMetaInput.parentNode.insertBefore(section, extraMetaInput.nextSibling);
    } else {
      form.appendChild(section);
    }
    return section;
  }

  function ensurePublishReadinessPanel() {
    var existing = document.getElementById('wizard-publish-readiness');
    if (existing) return existing;

    var panel = document.createElement('section');
    panel.id = 'wizard-publish-readiness';
    panel.className = 'wizard-publish-readiness';
    panel.innerHTML =
      '<div class="readiness-head">' +
      '<div><strong>Yayına hazırlık kontrolü</strong><p>Ortak ilan sözleşmesi ve kategori zorunluları canlı kontrol edilir.</p></div>' +
      '<span class="readiness-score" data-readiness-score>0%</span>' +
      '</div>' +
      '<ul class="readiness-list" data-readiness-list></ul>';

    var contractSection = ensureContractFieldsContainer();
    if (contractSection && contractSection.parentNode) {
      contractSection.parentNode.insertBefore(panel, contractSection);
    } else {
      form.insertBefore(panel, form.firstChild);
    }
    return panel;
  }

  function contractFieldValue(key) {
    var el = form.querySelector('[data-contract-field="' + String(key || '').replace(/"/g, '\\"') + '"]');
    if (el && String(el.value || '').trim() !== '') return String(el.value || '').trim();
    var meta = syncContractFieldsToMetadata(existingContractMetadata());
    return String((meta.contract_fields || {})[key] || '').trim();
  }

  function publishReadinessIssues() {
    var issues = [];
    var checks = [
      { key: 'code', label: 'İlan kodu', el: 'input-code', step: 1 },
      { key: 'title', label: 'Başlık', el: 'input-title', step: 1 },
      { key: 'locality', label: 'Konum', el: 'input-locality', step: 2 },
      { key: 'description', label: 'Açıklama', el: 'input-description', step: 7 },
      { key: 'price_minor', label: 'Fiyat', el: 'input-price-minor', step: 6, positive: true },
      { key: 'currency', label: 'Para birimi', el: 'input-currency', step: 6 },
      { key: 'owner_name', label: 'Sahip/tedarikçi adı', el: 'input-owner-name', step: 6, optionalWhenMissing: true },
      { key: 'owner_phone', label: 'Sahip/tedarikçi iletişimi', el: 'input-owner-phone', step: 6, optionalWhenMissing: true },
      { key: 'media', label: 'En az 1 görsel', step: 4, custom: function () { return images.length > 0; } },
      { key: 'cancellation_policy', label: 'İptal/iade politikası', el: 'input-cancellation', step: 6 }
    ];

    checks.forEach(function (check) {
      var ok;
      if (check.custom) {
        ok = check.custom();
      } else {
        var el = document.getElementById(check.el);
        if (!el && check.optionalWhenMissing) return;
        var value = el ? String(el.value || '').trim() : '';
        ok = check.positive ? Number(value || 0) > 0 : value !== '';
      }
      if (!ok) issues.push(check);
    });

    contractFields.forEach(function (field) {
      if (!field || !field.required) return;
      if (!contractFieldValue(field.key)) {
        issues.push({
          key: 'contract_' + field.key,
          label: 'Kategori alanı: ' + (field.label || field.key),
          contractKey: field.key,
          step: 3
        });
      }
    });

    return issues;
  }

  function focusReadinessIssue(issue) {
    if (!issue) return;
    var el = issue.el ? document.getElementById(issue.el) : null;
    if (!el && issue.contractKey) {
      el = form.querySelector('[data-contract-field="' + String(issue.contractKey).replace(/"/g, '\\"') + '"]');
    }
    if (issue.step) goToStep(issue.step);
    if (el) {
      window.setTimeout(function () {
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        el.focus();
        el.classList.add('field-highlight');
        setTimeout(function () { el.classList.remove('field-highlight'); }, 2000);
      }, 120);
    }
  }

  function updatePublishReadiness() {
    var panel = ensurePublishReadinessPanel();
    var list = panel.querySelector('[data-readiness-list]');
    var score = panel.querySelector('[data-readiness-score]');
    var issues = publishReadinessIssues();
    panel.classList.toggle('is-ready', issues.length === 0);
    panel.classList.toggle('has-missing', issues.length > 0);
    if (score) score.textContent = issues.length === 0 ? 'Hazır' : issues.length + ' eksik';
    if (!list) return;
    if (issues.length === 0) {
      list.innerHTML = '<li class="ready"><span>✓</span><button type="button">Yayına almak için zorunlu alanlar tamam.</button></li>';
      return;
    }
    list.innerHTML = issues.map(function (issue, index) {
      return '<li><span>!</span><button type="button" data-readiness-index="' + index + '">' + escapeHtml(issue.label) + '</button></li>';
    }).join('');
    list.querySelectorAll('[data-readiness-index]').forEach(function (button) {
      button.addEventListener('click', function () {
        var idx = Number(button.getAttribute('data-readiness-index'));
        focusReadinessIssue(issues[idx]);
      });
    });
  }

  var readinessRaf = 0;
  function schedulePublishReadinessUpdate() {
    if (readinessRaf) return;
    readinessRaf = window.requestAnimationFrame(function () {
      readinessRaf = 0;
      updatePublishReadiness();
    });
  }

  function existingContractMetadata() {
    var input = document.getElementById('wizard-extra-metadata-input');
    if (!input || !input.value) return {};
    try { return JSON.parse(input.value) || {}; } catch (_) { return {}; }
  }

  function populateContractFieldsFromMetadata() {
    var meta = existingContractMetadata();
    var values = meta.contract_fields || meta.contractFields || {};
    values = normalizeContractFieldValues(values, meta);
    Object.keys(values).forEach(function (key) {
      var el = form.querySelector('[data-contract-field="' + key.replace(/"/g, '\\"') + '"]');
      if (el) el.value = values[key] == null ? '' : values[key];
    });
  }

  function firstFilled() {
    for (var i = 0; i < arguments.length; i += 1) {
      var value = arguments[i];
      if (value !== undefined && value !== null && String(value).trim() !== '') return value;
    }
    return '';
  }

  function inputValue(id) {
    var el = document.getElementById(id);
    return el ? el.value : '';
  }

  function normalizeContractFieldValues(values, meta) {
    var out = Object.assign({}, values || {});
    var source = meta || {};
    var category = normalizeContractCategory(
      (source.category_code || source.category || (categoryInput ? categoryInput.value : currentCat))
    );

    if (category === 'holiday_home') {
      out.property_type = firstFilled(out.property_type, source.property_type, source.place_type, source.villa_type, 'Villa');
      out.bedroom_count = firstFilled(out.bedroom_count, source.bedroom_count, source.bedrooms, source.bedrooms_count);
      out.bathroom_count = firstFilled(out.bathroom_count, source.bathroom_count, source.bathrooms, source.bathrooms_count);
      out.guest_capacity = firstFilled(out.guest_capacity, source.guest_capacity, source.guests, source.capacity);
      out.pool_type = firstFilled(out.pool_type, source.pool_type, source.sheltered_pool === 'true' ? 'Korunaklı Havuz' : '', source.pool_dimensions ? 'Özel Havuz' : '');
      out.kitchen = firstFilled(out.kitchen, source.kitchen);
      out.season_rules = firstFilled(out.season_rules, source.season_rules, source.season_start || source.season_end ? JSON.stringify({
        season_start: source.season_start || '',
        season_end: source.season_end || '',
        season_price: source.season_price || ''
      }) : '');
    }

    if (category === 'yacht') {
      out.yacht_type = firstFilled(out.yacht_type, source.yacht_type, source.boat_type);
      out.capacity = firstFilled(out.capacity, source.capacity, source.guest_capacity, source.berth_count);
      out.cabin_count = firstFilled(out.cabin_count, source.cabin_count, source.cabins_count);
      out.departure_port = firstFilled(out.departure_port, source.departure_port, source.port_name, source.departure_marina);
      out.route = firstFilled(out.route, source.route, source.boat_times);
      out.captain_included = firstFilled(out.captain_included, source.captain_included, source.crew_status ? 'true' : '');
      out.fuel_policy = firstFilled(out.fuel_policy, source.fuel_policy);
    }

    return out;
  }

  function collectLegacyContractValues(baseData) {
    var data = Object.assign({}, baseData || {});
    var category = normalizeContractCategory(categoryInput ? categoryInput.value : currentCat);

    if (category === 'holiday_home') {
      data.property_type = firstFilled(data.property_type, inputValue('input-property-type'), 'Villa');
      data.bedroom_count = firstFilled(data.bedroom_count, inputValue('input-bedrooms'));
      data.bathroom_count = firstFilled(data.bathroom_count, inputValue('input-bathrooms'));
      data.guest_capacity = firstFilled(data.guest_capacity, inputValue('input-guests'));
      data.pool_type = firstFilled(
        data.pool_type,
        inputValue('input-pool-type'),
        inputValue('input-sheltered-pool') === 'true' ? 'Korunaklı Havuz' : '',
        inputValue('input-pool-dimensions') ? 'Özel Havuz' : ''
      );
      data.kitchen = firstFilled(data.kitchen, inputValue('input-kitchen'));
      data.season_rules = firstFilled(data.season_rules, data.season_start || data.season_end ? JSON.stringify({
        season_start: data.season_start || '',
        season_end: data.season_end || '',
        season_price: data.season_price || ''
      }) : '');
    }

    if (category === 'yacht') {
      data.yacht_type = firstFilled(data.yacht_type, inputValue('input-boat-type'));
      data.capacity = firstFilled(data.capacity, inputValue('input-guests'), inputValue('input-berth-count'));
      data.cabin_count = firstFilled(data.cabin_count, inputValue('input-cabin-count'));
      data.departure_port = firstFilled(data.departure_port, inputValue('input-port-name'));
      data.route = firstFilled(data.route, inputValue('input-route'), inputValue('input-boat-times'));
      data.captain_included = firstFilled(data.captain_included, inputValue('input-crew-status') ? 'true' : '');
      data.fuel_policy = firstFilled(data.fuel_policy, inputValue('input-fuel-policy'));
    }

    return data;
  }

  function loadContractFields() {
    var category = normalizeContractCategory(categoryInput ? categoryInput.value : currentCat);
    var section = ensureContractFieldsContainer();
    var grid = section.querySelector('[data-contract-fields-grid]');
    if (!grid) return;
    grid.innerHTML = '<p class="contract-fields-loading">Sözleşme alanları yükleniyor…</p>';
    section.classList.remove('hidden');

    fetch('/admin/catalog/fields?category=' + encodeURIComponent(category), {
      headers: { 'Accept': 'application/json' }
    })
      .then(function (res) {
        if (!res.ok) throw new Error('Sözleşme alanları alınamadı');
        return res.json();
      })
      .then(function (fields) {
        contractFields = Array.isArray(fields) ? fields : [];
        grid.innerHTML = '';
        if (!contractFields.length) {
          section.classList.add('hidden');
          contractFieldsReady = true;
          return;
        }
        contractFields.forEach(function (field) {
          grid.appendChild(renderContractField(field));
        });
        loadManagedFilterSelects();
        populateContractFieldsFromMetadata();
        contractFieldsReady = true;
        schedulePublishReadinessUpdate();
      })
      .catch(function () {
        contractFields = [];
        contractFieldsReady = false;
        grid.innerHTML = '<p class="contract-fields-loading">Sözleşme alanları şu anda yüklenemedi. Kayıt yapılabilir; alanlar daha sonra tamamlanabilir.</p>';
        schedulePublishReadinessUpdate();
      });
  }

  function syncContractFieldsToMetadata(baseData) {
    var data = baseData || {};
    var category = normalizeContractCategory(categoryInput ? categoryInput.value : currentCat);
    var values = collectLegacyContractValues(data);
    contractFields.forEach(function (field) {
      if (!field || !field.key) return;
      var el = form.querySelector('[data-contract-field="' + field.key.replace(/"/g, '\\"') + '"]');
      if (!el) {
        if (values[field.key] === undefined) values[field.key] = '';
        return;
      }
      var value = el.value;
      if (String(field.type || '').toLowerCase() === 'number' && value !== '') {
        var numeric = Number(value);
        value = Number.isFinite(numeric) ? numeric : value;
      }
      values[field.key] = firstFilled(value, values[field.key]);
    });
    values = normalizeContractFieldValues(values, data);
    data.contract_version = '1.1.0';
    data.category_code = category;
    data.contract_fields = values;
    data.contract_fields_ready = contractFieldsReady;
    return data;
  }

  // DOM Elements
  var stepTabs = document.querySelectorAll('.wizard-step-tab');
  var stepPanels = document.querySelectorAll('.wizard-step-panel');
  var progressFill = document.getElementById('wizard-progress-fill');
  var stepCounterText = document.getElementById('wizard-step-text');
  var btnPrev = document.getElementById('btn-wizard-prev');
  var btnNext = document.getElementById('btn-wizard-next');
  var btnSubmit = document.getElementById('btn-wizard-submit');

  var btnModeStepper = document.getElementById('btn-mode-stepper');
  var btnModeFull = document.getElementById('btn-mode-full');
  var stepperWrap = document.getElementById('wizard-stepper-wrap');
  var fullFormQuickNav = document.getElementById('full-form-quick-nav');
  var formModeText = document.getElementById('form-mode-text');

  var btnToggleAiCard = document.getElementById('btn-toggle-ai-card');
  var aiImportCard = document.getElementById('ai-import-card');
  var btnFillSample = document.getElementById('btn-fill-sample');
  var btnResetForm = document.getElementById('btn-reset-form');

  var btnGenCode = document.getElementById('btn-gen-code');
  var btnAiTitle = document.getElementById('btn-ai-title');
  var btnAiDesc = document.getElementById('btn-ai-desc');
  var btnAiSeo = document.getElementById('btn-ai-seo');

  var btnQuickDraft = document.getElementById('btn-quick-draft');
  var btnQuickPublish = document.getElementById('btn-quick-publish');

  // Preview elements
  var previewImg = document.getElementById('preview-cover-img') || document.getElementById('preview-img');
  var previewPhotoCount = document.getElementById('preview-photo-count');
  var previewTitle = document.getElementById('preview-title');
  var previewLocality = document.getElementById('preview-locality');
  var previewSpecs = document.getElementById('preview-specs');
  var previewPrice = document.getElementById('preview-price');
  var previewPricePeriod = document.getElementById('preview-price-period') || document.querySelector('.showcase-price-period');
  var previewStatus = document.getElementById('preview-status') || document.getElementById('preview-status-pill');
  var previewRating = document.getElementById('preview-rating') || document.querySelector('.showcase-rating-badge');
  var previewAmenities = document.getElementById('preview-amenities-icons');

  // Hidden form inputs
  var amenitiesInput = document.getElementById('wizard-amenities-input');
  var imagesInput = document.getElementById('wizard-images-input');
  var roomTypesInput = document.getElementById('wizard-room-types-input');
  var inputPriceMinor = document.getElementById('input-price-minor');
  var inputPriceDisplay = document.getElementById('input-price-display');

  // Photo elements
  var photosGallery = document.getElementById('wizard-photos-gallery');
  var photoDropzone = document.getElementById('photo-dropzone');
  var photoFileInput = document.getElementById('photo-file-input');
  var btnBrowsePhotos = document.getElementById('btn-browse-photos');
  var mediaUrlInput = document.getElementById('media-new-url-input');
  var btnAddPhoto = document.getElementById('btn-add-photo');

  // Room modal elements
  var roomTypeModal = document.getElementById('room-type-modal');
  var btnAddRoomType = document.getElementById('btn-add-room-type');
  var btnCloseRoomModal = document.getElementById('btn-close-room-modal');
  var btnCancelRoomModal = document.getElementById('btn-cancel-room-modal');
  var btnSaveRoomModal = document.getElementById('btn-save-room-modal');
  var roomTypesContainer = document.getElementById('room-types-container');

  // SEO Elements
  var inputSeoTitle = document.getElementById('input-seo-title');
  var inputSeoSlug = document.getElementById('input-seo-slug');
  var inputSeoDesc = document.getElementById('input-seo-desc');
  var seoTitleCount = document.getElementById('seo-title-count');
  var seoDescCount = document.getElementById('seo-desc-count');
  var serpPreviewTitle = document.getElementById('serp-preview-title');
  var serpPreviewSlug = document.getElementById('serp-preview-slug');
  var serpPreviewDesc = document.getElementById('serp-preview-desc');

  // AI Elements
  var aiInput = document.getElementById('ai-import-input');
  var aiBtn = document.getElementById('ai-import-btn');
  var aiStatus = document.getElementById('ai-import-status');
  var aiStatusText = document.getElementById('ai-status-text');
  var sampleChips = document.querySelectorAll('.ai-quick-chip');

  // Map amenity codes to icons
  var amenityIcons = {
    // Villa
    pool: '🏊',
    jacuzzi: '♨️',
    sauna: '🧖',
    wifi: '📶',
    sea_view: '🌊',
    sheltered: '🛡️',
    bbq: '🥩',
    fireplace: '🔥',
    ac: '❄️',
    parking: '🚗',
    pet_friendly: '🐾',
    ev_charge: '⚡',
    baby_friendly: '👶',
    sunset_terrace: '🌅',
    breakfast: '🍳',
    boat_pier: '⛵',
    generator: '⚡',
    smart_tv: '📺',
    // Hotel
    private_beach: '🏖️',
    open_pool: '🏊',
    aquapark: '🌊',
    heated_indoor_pool: '♨️',
    spa_hamam: '🧖',
    alacarte: '🍽️',
    kids_club: '🧒',
    all_inclusive_bar: '🍸',
    reception_24h: '🛎️',
    fitness: '🏋️',
    valet_parking: '🚗',
    room_service: '🛎️',
    airport_shuttle: '🚐',
    conference_room: '💼',
    live_music: '🎭',
    tennis_court: '🎾',
    wheelchair_access: '♿'
  };

  // --- Tam Form Accordion: bölümler başlıklarından açılır/kapanır ---
  // Tam form modunda 7 bölüm tek sayfada accordion olarak durur; quick-nav
  // pill'leri ve doğrulama akışı (goToStep) hedef bölümü otomatik açar.
  var accordionBuilt = false;
  var ACCORDION_COLLAPSED = 'wizard-collapsed';

  // --- Accordion durum kalıcılığı (sunucu + localStorage fallback) ---
  // Tam form modunda hangi bölümlerin açık olduğu saklanır; sayfa yenilendiğinde
  // aynı bölüm kombinasyonu geri gelir. Tercih sunucuya (wizard_prefs) yazılır;
  // localStorage fallback olarak kalır.
  var ACC_STATE_KEY = 'nexus.wizard.accordion.open';
  var ACC_MODE_KEY = 'nexus.wizard.mode';

  // --- Sunucu tarafı tercih yönetimi ---
  // data-wizard-prefs attribute'undan sunucu tercihlerini okur.
  function getServerPrefs() {
    try {
      var raw = document.documentElement.getAttribute('data-wizard-prefs');
      if (!raw) return null;
      var parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== 'object') return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  // Mevcut tercihleri sunucuya asenkron olarak kaydeder.
  var _prefsSaveTimer = null;
  function saveWizardPrefsServer() {
    var prefs = { mode: formMode, accordion_open: [] };
    if (formMode === 'full' && accordionBuilt) {
      stepPanels.forEach(function (panel, i) {
        if (!panel.classList.contains(ACCORDION_COLLAPSED)) prefs.accordion_open.push(i + 1);
      });
    }
    // localStorage fallback (hemen yaz)
    try {
      window.localStorage.setItem(ACC_MODE_KEY, formMode);
      window.localStorage.setItem(ACC_STATE_KEY, JSON.stringify(prefs.accordion_open.reduce(function (a, n) { a[String(n)] = true; return a; }, {})));
    } catch (_) {}
    // Sunucuya debounce ile yaz (aynı anda birden fazla tetikleme birleşir)
    if (_prefsSaveTimer) clearTimeout(_prefsSaveTimer);
    _prefsSaveTimer = setTimeout(function () {
      try {
        // CSRF token'ı nexus_csrf cookie'sinden oku
        var csrfToken = '';
        var cookies = document.cookie.split(';');
        for (var ci = 0; ci < cookies.length; ci++) {
          var c = cookies[ci].trim();
          if (c.indexOf('nexus_csrf=') === 0) { csrfToken = c.substring(11); break; }
        }
        // Form-encoded gönder: wisp.require_form + CSRF guard bekliyor
        var body = 'csrf=' + encodeURIComponent(csrfToken) + '&prefs=' + encodeURIComponent(JSON.stringify(prefs));
        fetch('/admin/preferences/wizard', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: body,
          credentials: 'same-origin',
        }).catch(function () {}); // sessizce başarısız ol — localStorage fallback zaten yapıldı
      } catch (_) {}
    }, 300);
  }

  function loadAccState() {
    // 1) Sunucudan gelen tercihi dene
    var serverPrefs = getServerPrefs();
    if (serverPrefs && serverPrefs.accordion_open) {
      var open = {};
      stepPanels.forEach(function (_, i) {
        if (serverPrefs.accordion_open.indexOf(i + 1) !== -1) open[i + 1] = true;
      });
      return open;
    }
    // 2) localStorage fallback
    try {
      var raw = window.localStorage.getItem(ACC_STATE_KEY);
      if (!raw) return null;
      var parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== 'object') return null;
      var open = {};
      stepPanels.forEach(function (_, i) {
        if (parsed[String(i + 1)] === true) open[i + 1] = true;
      });
      return open;
    } catch (_) {
      return null;
    }
  }

  function saveAccState() {
    if (formMode !== 'full' || !accordionBuilt) return;
    saveWizardPrefsServer();
  }

  function accordionLabel(open) {
    return open ? 'Bölümü daralt' : 'Bölümü genişlet';
  }

  function buildAccordion() {
    if (accordionBuilt) return;
    stepPanels.forEach(function (panel, idx) {
      var heading = panel.querySelector('.step-heading');
      if (!heading || heading.getAttribute('data-acc-ready') === '1') return;
      heading.setAttribute('data-acc-ready', '1');
      heading.classList.add('acc-heading');

      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'acc-toggle';
      btn.setAttribute('aria-expanded', 'true');
      btn.setAttribute('aria-controls', 'sec-' + (idx + 1) + '-acc-body');
      btn.setAttribute('title', accordionLabel(true));
      btn.addEventListener('click', function () {
        var isOpen = !panel.classList.contains(ACCORDION_COLLAPSED);
        setPanelCollapsed(panel, isOpen);
        saveAccState();
      });

      var chev = document.createElement('span');
      chev.className = 'acc-chevron';
      chev.setAttribute('aria-hidden', 'true');
      chev.textContent = '⌄';
      btn.appendChild(chev);

      // Başlık içeriği (badge + h3 + açıklama) buton gövdesine taşınır;
      // böylece başlığın herhangi bir yerine tıklamak bölümü çevirir.
      var bodyWrap = document.createElement('span');
      bodyWrap.className = 'acc-heading-body';
      while (heading.firstChild) bodyWrap.appendChild(heading.firstChild);
      btn.appendChild(bodyWrap);
      heading.appendChild(btn);

      // Gövde sarmalayıcı: daraltma bu öğenin display'i üzerinden yapılır
      var body = document.createElement('div');
      body.className = 'acc-body';
      body.id = 'sec-' + (idx + 1) + '-acc-body';
      while (panel.childNodes.length > 1) {
        body.appendChild(panel.firstChild);
      }
      panel.appendChild(body);
    });
    accordionBuilt = true;
  }

  function setPanelCollapsed(panel, collapse) {
    var heading = panel.querySelector('.step-heading');
    var body = panel.querySelector('.acc-body');
    if (!heading || !body) return;
    var btn = heading.querySelector('.acc-toggle');
    panel.classList.toggle(ACCORDION_COLLAPSED, collapse);
    if (btn) {
      btn.setAttribute('aria-expanded', collapse ? 'false' : 'true');
      btn.setAttribute('title', accordionLabel(!collapse));
    }
    if (collapse) body.style.maxHeight = '0px';
    else body.style.maxHeight = '';
  }

  // Accordion sırası: yalnızca hedef adım açık, diğerleri daraltılmış.
  // Quick-nav ile tetiklenen geçişlerde kullanıcı düzeni aşan bu senkron,
  // kullanıcı tıklamalarının (setPanelCollapsed + saveAccState) üzerine yazar.
  function syncAccordionPanels(step) {
    if (formMode !== 'full' || !accordionBuilt) return;
    stepPanels.forEach(function (panel, i) {
      setPanelCollapsed(panel, i !== step - 1);
    });
    saveAccState();
    var target = stepPanels[step - 1];
    if (target) {
      window.requestAnimationFrame(function () {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
    }
  }

  function initAccordion(collapseAll) {
    buildAccordion();
    if (formMode !== 'full') return;
    if (collapseAll) {
      // Yalnızca kayıtlı düzen yokken: ilk bölüm açık, diğerleri kapalı.
      var restored = loadAccState();
      if (restored) {
        applyAccState(restored);
        return;
      }
    }
    stepPanels.forEach(function (panel, i) {
      setPanelCollapsed(panel, collapseAll ? i !== 0 : false);
    });
    if (collapseAll) saveAccState();
  }

  function applyAccState(openMap) {
    stepPanels.forEach(function (panel, i) {
      setPanelCollapsed(panel, !openMap[i + 1]);
    });
  }

  function destroyAccordion() {
    if (!accordionBuilt) return;
    stepPanels.forEach(function (panel) {
      panel.classList.remove(ACCORDION_COLLAPSED);
      var body = panel.querySelector('.acc-body');
      if (body) body.style.maxHeight = '';
    });
  }

  // --- Bölüm tamamlanma rozetleri ---
  // Her accordion bölüm başlığında zorunlu alanların doluluk durumunu yansıtan
  // canlı bir rozet gösterir: tümü doluysa yeşil tik, eksik varsa uyarı ikonu.
  var BADGE_OK = '✓';
  var BADGE_WARN = '!';
  var ACC_BADGE_OK = 'acc-badge-ok';
  var ACC_BADGE_WARN = 'acc-badge-warn';

  // Alan ID → okunabilir label eşlemesi
  var FIELD_LABELS = {
    'input-code': 'İlan Kodu',
    'input-title': 'İlan Başlığı',
    'input-status': 'Yayın Durumu',
    'input-locality': 'Konum',
    'input-price-minor': 'Fiyat',
    'input-description': 'Açıklama'
  };

  // Her bölüm için eksik alan listesi (popup için) — updateCompletionBadges tarafından doldurulur
  var sectionMissingFields = {};

  // Popup oluştur (bir kez, DOM'a eklenir)
  var missingFieldsPopup = null;
  function ensureMissingFieldsPopup() {
    if (missingFieldsPopup) return missingFieldsPopup;
    missingFieldsPopup = document.createElement('div');
    missingFieldsPopup.className = 'missing-fields-popup';
    missingFieldsPopup.setAttribute('role', 'dialog');
    missingFieldsPopup.setAttribute('aria-label', 'Eksik zorunlu alanlar');
    missingFieldsPopup.innerHTML = '<div class="missing-fields-popup-head"><span class="missing-fields-popup-title">⚠️ Eksik Zorunlu Alanlar</span><button class="missing-fields-popup-close" type="button" aria-label="Kapat">✕</button></div><div class="missing-fields-popup-body"></div>';
    document.body.appendChild(missingFieldsPopup);
    // Kapatma
    missingFieldsPopup.querySelector('.missing-fields-popup-close').addEventListener('click', hideMissingFieldsPopup);
    // Overlay tıklaması
    missingFieldsPopup.addEventListener('click', function (e) {
      if (e.target === missingFieldsPopup) hideMissingFieldsPopup();
    });
    return missingFieldsPopup;
  }

  function showMissingFieldsPopup(stepNo, badgeEl) {
    var fields = sectionMissingFields[stepNo] || [];
    if (fields.length === 0) return;
    var popup = ensureMissingFieldsPopup();
    var body = popup.querySelector('.missing-fields-popup-body');
    var html = '<p class="missing-fields-desc">Bu bölümdeki <strong>' + fields.length + ' zorunlu alan</strong> hâlâ boş:</p><ul class="missing-fields-list">';
    fields.forEach(function (fieldId) {
      var label = FIELD_LABELS[fieldId] || fieldId;
      html += '<li class="missing-fields-item" data-field="' + fieldId + '"><span class="missing-fields-dot">●</span><span class="missing-fields-name">' + label + '</span></li>';
    });
    html += '</ul><p class="missing-fields-hint">Listedeki alana tıklayarak ilgili bölüme gidebilirsiniz.</p>';
    body.innerHTML = html;
    // Her maddeye tıklama → ilgili alana kaydır
    body.querySelectorAll('.missing-fields-item').forEach(function (item) {
      item.addEventListener('click', function () {
        var fieldId = item.getAttribute('data-field');
        var el = document.getElementById(fieldId);
        if (el) {
          hideMissingFieldsPopup();
          el.scrollIntoView({ behavior: 'smooth', block: 'center' });
          el.focus();
          el.classList.add('field-highlight');
          setTimeout(function () { el.classList.remove('field-highlight'); }, 2000);
        }
      });
    });
    // Pozisyon: rozetin altında
    if (badgeEl) {
      var rect = badgeEl.getBoundingClientRect();
      popup.style.position = 'fixed';
      popup.style.top = Math.min(rect.bottom + 8, window.innerHeight - 300) + 'px';
      popup.style.right = Math.max(16, window.innerWidth - rect.right) + 'px';
    }
    popup.classList.add('is-open');
  }

  function hideMissingFieldsPopup() {
    if (missingFieldsPopup) missingFieldsPopup.classList.remove('is-open');
  }

  // Zorunlu alanlar → bölüm eşlemesi (panel.gleam sec-1..sec-7 ile birebir).
  var SECTION_REQUIRED_FIELDS = {
    1: ['input-code', 'input-title', 'input-status'],
    2: ['input-locality'],
    6: ['input-price-minor'],
    7: ['input-description']
  };
  // Yayın durumuna göre opsiyonel hale gelen alanlar (validateAndSubmit ile uyumlu):
  // status=draft iken konum ve fiyat zorunlu değildir.
  var DRAFT_OPTIONAL = { 2: ['input-locality'], 6: ['input-price-minor'] };

  function accBadgeEl(panel) {
    // Accordion kuruluyken başlık gövdesine, değilse doğrudan başlığa bağlanır.
    // buildAccordion() sonradan çalışırsa mevcut rozet bodyWrap'e taşınır —
    // burada bulunduğu için çift rozet üretilmez.
    var heading = panel.querySelector('.step-heading');
    if (!heading) return null;
    var host = heading.querySelector('.acc-heading-body') || heading;
    var badge = host.querySelector('.acc-completion-badge');
    if (!badge) {
      badge = document.createElement('span');
      badge.className = 'acc-completion-badge';
      badge.setAttribute('aria-hidden', 'true');
      host.appendChild(badge);
    }
    return badge;
  }

  function sectionFieldMissing(id) {
    var el = document.getElementById(id);
    if (!el) return false;
    if (el.disabled || el.type === 'hidden') return false;
    var v = (el.value || '').trim();
    if (el.type === 'select-one' || el.tagName === 'SELECT') {
      var opt = el.selectedOptions && el.selectedOptions[0];
      if (opt && opt.disabled) return true;
      return !v;
    }
    return !v;
  }

  function updateCompletionBadges() {
    stepPanels.forEach(function (panel, idx) {
      var badge = accBadgeEl(panel);
      if (!badge) return;
      var stepNo = idx + 1;
      var fields = SECTION_REQUIRED_FIELDS[stepNo] || [];
      // Yayın durumu draft ise konum/fiyat opsiyoneldir (validateAndSubmit ile
      // aynı kural — moda değil, yalnızca duruma bağlıdır).
      if (DRAFT_OPTIONAL[stepNo]) {
        var statusSel = document.getElementById('input-status');
        var isDraft = statusSel && (statusSel.value || '') === 'draft';
        if (isDraft) {
          fields = fields.filter(function (id) {
            return DRAFT_OPTIONAL[stepNo].indexOf(id) === -1;
          });
        }
      }
      var missing = fields.filter(sectionFieldMissing);
      var warn = missing.length > 0;
      badge.classList.toggle(ACC_BADGE_WARN, warn);
      badge.classList.toggle(ACC_BADGE_OK, !warn);
      var tip = warn
        ? 'Bölümde ' + missing.length + ' zorunlu alan eksik — tıkla'
        : 'Zorunlu alanlar tamam';
      badge.textContent = warn ? BADGE_WARN : BADGE_OK;
      badge.setAttribute('title', tip);
      // Tıklanabilir rozet — eksik alan listesini göster
      if (warn) {
        badge.style.cursor = 'pointer';
        badge.setAttribute('aria-hidden', 'false');
        badge.setAttribute('role', 'button');
        badge.setAttribute('tabindex', '0');
        // Eksik alan listesini sakla
        sectionMissingFields[stepNo] = missing.map(function (id) { return id; });
        // Eski handler'ları temizle ve yenisini bağla (çift biniyi önle)
        var newBadge = badge.cloneNode(true);
        badge.parentNode.replaceChild(newBadge, badge);
        (function (sn, b) {
          b.addEventListener('click', function (e) {
            e.stopPropagation();
            showMissingFieldsPopup(sn, b);
          });
          b.addEventListener('keydown', function (e) {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault();
              showMissingFieldsPopup(sn, b);
            }
          });
        })(stepNo, newBadge);
      } else {
        sectionMissingFields[stepNo] = [];
      }
      var heading = panel.querySelector('.step-heading');
      if (heading) heading.setAttribute('data-complete', warn ? '0' : '1');
    });

    // --- Stepper sekmelerinde rozet güncelle ---
    stepTabs.forEach(function (tab) {
      var tabStep = parseInt(tab.getAttribute('data-step'), 10);
      var badge = tab.querySelector('.tab-completion-badge');
      if (!badge) return;
      var fields = SECTION_REQUIRED_FIELDS[tabStep] || [];
      if (DRAFT_OPTIONAL[tabStep]) {
        var statusSel = document.getElementById('input-status');
        var isDraft = statusSel && (statusSel.value || '') === 'draft';
        if (isDraft) {
          fields = fields.filter(function (id) {
            return DRAFT_OPTIONAL[tabStep].indexOf(id) === -1;
          });
        }
      }
      var missing = fields.filter(sectionFieldMissing);
      var warn = missing.length > 0;
      badge.classList.toggle(ACC_BADGE_WARN, warn);
      badge.classList.toggle(ACC_BADGE_OK, !warn);
      badge.textContent = warn ? BADGE_WARN : BADGE_OK;
      badge.setAttribute('title', warn
        ? missing.length + ' eksik alan'
        : 'Tamam');
      // Tıklanabilirlik
      if (warn) {
        badge.style.cursor = 'pointer';
        badge.setAttribute('role', 'button');
        badge.setAttribute('tabindex', '0');
        badge.setAttribute('aria-hidden', 'false');
        var newBadge = badge.cloneNode(true);
        badge.parentNode.replaceChild(newBadge, badge);
        (function (sn, b) {
          b.addEventListener('click', function (e) {
            e.stopPropagation();
            showMissingFieldsPopup(sn, b);
          });
          b.addEventListener('keydown', function (e) {
            if (e.key === 'Enter' || e.key === ' ') {
              e.preventDefault();
              showMissingFieldsPopup(sn, b);
            }
          });
        })(tabStep, newBadge);
      }
    });
  }

  function initCompletionBadges() {
    // Accordion'u burada inşa ETME — stepper modda başlık tıklaması bölüm
    // daraltmamalı. Rozet .step-heading'e bağlanır; accordion kurulduğunda
    // buildAccordion() rozeti bodyWrap'e kendiliğinden taşır.
    updateCompletionBadges();
    // Geç dolumları yakala: tarayıcı form geri yükleme (reload/bfcache), otomatik
    // doldurma vb. DOMContentLoaded sonrası değer basar. pageshow + kısa gecikmeli
    // yeniden kontroller rozetleri gerçek durumuna getirir.
    window.addEventListener('pageshow', scheduleCompletionUpdate);
    window.setTimeout(scheduleCompletionUpdate, 250);
    window.setTimeout(scheduleCompletionUpdate, 1200);
  }

  var badgeRaf = 0;
  function scheduleCompletionUpdate() {
    if (badgeRaf) return;
    badgeRaf = window.requestAnimationFrame(function () {
      badgeRaf = 0;
      updateCompletionBadges();
    });
  }
  form.addEventListener('input', scheduleCompletionUpdate);
  form.addEventListener('change', scheduleCompletionUpdate);
  form.addEventListener('input', schedulePublishReadinessUpdate);
  form.addEventListener('change', schedulePublishReadinessUpdate);

  // --- Otomatik taslak (autosave) ---
  // Formda degisiklik oldugunda 3 sn sonra sessizce draft olarak kaydeder.
  // Kayit basariliysa dirty flag temizlenir; kullaniciya kucuk bir toast gosterilir.
  var _autosaveTimer = null;
  var _autosaveBusy = false;
  var AUTOSAVE_DELAY = 3000;

  function scheduleAutosave() {
    if (_autosaveBusy) return;
    if (!isFormDirty()) return;
    if (_autosaveTimer) clearTimeout(_autosaveTimer);
    _autosaveTimer = setTimeout(function () {
      runAutosave();
    }, AUTOSAVE_DELAY);
  }

  function runAutosave() {
    if (_autosaveBusy) return;
    if (!isFormDirty()) return;
    if (!form || !document.body.contains(form)) return;
    // Kod ve baslik zorunlu — bossa autosave yapma
    var codeVal = (document.getElementById('input-code') || {}).value || '';
    if (!codeVal.trim()) return;
    _autosaveBusy = true;
    markFormClean();
    // CSRF token'ni cookie'den al
    var csrfToken = '';
    var cookies = document.cookie.split(';');
    for (var ci = 0; ci < cookies.length; ci++) {
      var c = cookies[ci].trim();
      if (c.indexOf('nexus_csrf=') === 0) { csrfToken = c.substring(11); break; }
    }
    var autosaveExtraMetaInput = document.getElementById('wizard-extra-metadata-input');
    if (autosaveExtraMetaInput) {
      var autosaveMeta = existingContractMetadata();
      autosaveExtraMetaInput.value = JSON.stringify(syncContractFieldsToMetadata(autosaveMeta));
    }
    // FormData ile formu topla, draft olarak gonder
    var fd = new FormData(form);
    fd.set('status', 'draft');
    fd.set('csrf', csrfToken);
    var actionUrl = form.getAttribute('action') || window.location.pathname;
    fetch(actionUrl, {
      method: 'POST',
      body: fd,
      credentials: 'same-origin',
      redirect: 'follow',
    }).then(function (resp) {
      _autosaveBusy = false;
      if (resp.ok || resp.redirected) {
        showToast('Otomatik taslak kaydedildi', 'success');
      } else {
        showToast('Otomatik kayit basarisiz', 'warning');
      }
    }).catch(function () {
      _autosaveBusy = false;
      showToast('Otomatik kayit hatasi', 'warning');
    });
  }

  // Form input/change oto-kayit tetikleyicisi
  form.addEventListener('input', scheduleAutosave);
  form.addEventListener('change', scheduleAutosave);

  // Sayfa ayrilirken devam eden autosave varsa tamamla
  window.addEventListener('beforeunload', function (e) {
    if (_autosaveBusy) {
      e.returnValue = 'Taslak kaydediliyor...';
    }
  });

  // Yayin onay diyalogu ---
  // Ctrl+Enter veya yayin butonuna basinca acilir; kullanicinin yayin
  // oncesi son bir kez kontrol etmesini saglar.
  function confirmPublishModal() {
    if (validateAndSubmit._busy) return;
    var titleVal = (document.getElementById('input-title') || {}).value || '';
    var codeVal = (document.getElementById('input-code') || {}).value || '';
    var locVal = (document.getElementById('input-locality') || {}).value || '';
    var priceVal = (inputPriceDisplay || {}).value || '';
    // Mevcut aciklama panelini bul veya olustur
    var existing = document.getElementById('publish-confirm-backdrop');
    if (existing) existing.remove();
    var bd = document.createElement('div');
    bd.id = 'publish-confirm-backdrop';
    bd.setAttribute('role', 'dialog');
    bd.setAttribute('aria-modal', 'true');
    bd.setAttribute('aria-label', 'Yayin onayi');
    bd.style.cssText = 'display:flex;position:fixed;inset:0;z-index:10001;align-items:center;justify-content:center;background:rgba(3,7,18,0.72);backdrop-filter:blur(12px);-webkit-backdrop-filter:blur(12px);opacity:0;transition:opacity 0.2s ease';
    var card = document.createElement('div');
    card.className = 'shortcut-help-card';
    card.style.maxWidth = '460px';
    var hdr = document.createElement('header');
    hdr.className = 'shortcut-help-header';
    var h3 = document.createElement('h3');
    h3.textContent = 'Yayin Onayi';
    var closeBtn = document.createElement('button');
    closeBtn.className = 'shortcut-help-close';
    closeBtn.setAttribute('aria-label', 'Kapat');
    closeBtn.textContent = '\u2715';
    hdr.appendChild(h3);
    hdr.appendChild(closeBtn);
    // Ozet
    var summary = document.createElement('div');
    summary.style.cssText = 'padding:12px 20px;font-size:13px;color:var(--text-muted,#94a3b8);line-height:1.5;border-bottom:1px solid var(--line-faint,rgba(255,255,255,0.06))';
    var rows = [
      ['Kod', codeVal || '(bos)'],
      ['Baslik', titleVal || '(bos)'],
      ['Konum', locVal || '(bos)'],
      ['Fiyat', priceVal || '0']
    ];
    rows.forEach(function (r) {
      var row = document.createElement('div');
      row.style.cssText = 'display:flex;justify-content:space-between;padding:3px 0;gap:8px';
      var lbl = document.createElement('span');
      lbl.style.cssText = 'color:var(--text-dim,#64748b);flex-shrink:0';
      lbl.textContent = r[0];
      var val = document.createElement('span');
      val.style.cssText = 'color:var(--text-pure,#fff);font-weight:500;text-align:right;word-break:break-word';
      val.textContent = r[1];
      row.appendChild(lbl);
      row.appendChild(val);
      summary.appendChild(row);
    });
    // Uyari
    var warn = document.createElement('div');
    warn.style.cssText = 'padding:8px 20px 0;font-size:12px;color:var(--status-warn,#f59e0b)';
    warn.textContent = 'Ilan yayindayken musteriler tarafindan gorulebilir.';
    // Butonlar
    var footer = document.createElement('div');
    footer.style.cssText = 'display:flex;gap:8px;padding:16px 20px;justify-content:flex-end;border-top:1px solid var(--line-faint,rgba(255,255,255,0.06))';
    var cancelBtn = document.createElement('button');
    cancelBtn.className = 'btn-quick-util';
    cancelBtn.textContent = 'Iptal';
    cancelBtn.style.cssText = 'padding:8px 16px;font-size:13px;border-radius:8px;border:1px solid var(--line-faint,rgba(255,255,255,0.1));background:transparent;color:var(--text-muted,#94a3b8);cursor:pointer;transition:all 0.15s';
    var confirmBtn = document.createElement('button');
    confirmBtn.className = 'btn-quick-publish';
    confirmBtn.textContent = 'Yayinla';
    confirmBtn.style.cssText = 'padding:8px 20px;font-size:13px;font-weight:600;border-radius:8px;border:none;background:var(--gradient-primary,linear-gradient(135deg,#06b6d4,#8b5cf6));color:#fff;cursor:pointer;transition:all 0.15s';
    footer.appendChild(cancelBtn);
    footer.appendChild(confirmBtn);
    card.appendChild(hdr);
    card.appendChild(summary);
    card.appendChild(warn);
    card.appendChild(footer);
    bd.appendChild(card);
    document.body.appendChild(bd);
    requestAnimationFrame(function () { bd.style.opacity = '1'; });
    // Kapatma
    function close() { bd.style.opacity = '0'; setTimeout(function () { bd.remove(); }, 200); }
    closeBtn.addEventListener('click', close);
    bd.addEventListener('click', function (e) { if (e.target === bd) close(); });
    cancelBtn.addEventListener('click', close);
    confirmBtn.addEventListener('click', function () {
      close();
      validateAndSubmit('published');
    });
    // ESC
    function onKey(ev) {
      if (ev.key === 'Escape') { close(); document.removeEventListener('keydown', onKey); }
    }
    document.addEventListener('keydown', onKey);
    confirmBtn.focus();
  }

  // Yayin butonlarini onay diyalogu ile sar
  if (btnQuickPublish) {
    btnQuickPublish.removeEventListener('click', btnQuickPublish._origHandler);
    btnQuickPublish._origHandler = function (e) {
      e.preventDefault();
      confirmPublishModal();
    };
    btnQuickPublish.addEventListener('click', btnQuickPublish._origHandler);
  }
  if (btnSubmit) {
    btnSubmit.removeEventListener('click', btnSubmit._origHandler);
    btnSubmit._origHandler = function (e) {
      e.preventDefault();
      confirmPublishModal();
    };
    btnSubmit.addEventListener('click', btnSubmit._origHandler);
  }

  // --- Klavye kısayolları ---
  // Ctrl+→ / Ctrl+←: bölümler arası geçiş (her iki modda; tam formda hedef
  // bölüm açılır ve kayıtlı düzene yazılır). Ctrl+S: taslak kaydet
  // (btn-quick-draft ile aynı akış). Ctrl+K (quick-search) ile çakışmaz.
  var isMac = /Mac|iPod|iPhone|iPad/.test(navigator.platform || '');
  var SHORTCUT_HINT = isMac
    ? '⌘←/⌘→ bölüm geçişi · ⌘S taslak · ⌘Enter yayınla'
    : 'Ctrl+←/Ctrl+→ bölüm geçişi · Ctrl+S taslak · Ctrl+Enter yayınla';

  function wizardShortcutStep(delta) {
    if (!form || !document.body.contains(form)) return;
    var next = Math.min(totalSteps, Math.max(1, currentStep + delta));
    if (next === currentStep) {
      showToast(
        delta > 0 ? 'Zaten son bölümdesiniz.' : 'Zaten ilk bölümdesiniz.',
        'info'
      );
      return;
    }
    guardDirty(function () {
      goToStep(next);
      showToast(
        'Bölüm ' + next + ' / ' + totalSteps,
        'info'
      );
    });
  }

  window.addEventListener('keydown', function (e) {
    // ESC: eksik alan popup'ını kapat
    if (e.key === 'Escape') {
      hideMissingFieldsPopup();
      var pubConfirm = document.getElementById('publish-confirm-backdrop');
      if (pubConfirm) { pubConfirm.style.opacity = '0'; setTimeout(function () { pubConfirm.remove(); }, 200); }
      return;
    }
    if (!(e.ctrlKey || e.metaKey)) return;

    if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
      var tag = (e.target && e.target.tagName || '').toLowerCase();
      var inTextEntry =
        tag === 'select' ||
        (tag === 'input' && e.target.type !== 'checkbox' && e.target.type !== 'radio');
      // Metin alanlarında Ctrl+←/→ kelime sözcük imleç hareketidir — dokunma.
      if (inTextEntry) return;
      e.preventDefault();
      wizardShortcutStep(e.key === 'ArrowRight' ? 1 : -1);
      return;
    }

    if (e.key === 's' || e.key === 'S') {
      if (!form || !document.body.contains(form)) return;
      e.preventDefault();
      if (validateAndSubmit._busy) return;
      var draftBtn = document.getElementById('btn-quick-draft');
      if (draftBtn) draftBtn.click();
      else validateAndSubmit('draft');
      return;
    }

    // Ctrl+Enter: yayina al (onay diyalogu ile)
    if (e.key === 'Enter') {
      if (!form || !document.body.contains(form)) return;
      e.preventDefault();
      if (validateAndSubmit._busy) return;
      confirmPublishModal();
    }
  });

  // --- Kısayol Yardım Paneli (?) ---
  var shortcutHelpOpen = false;
  var shortcutHelpBackdrop = null;

  function buildShortcutHelp() {
    if (shortcutHelpBackdrop) return shortcutHelpBackdrop;
    var modKey = isMac ? '⌘' : 'Ctrl';
    var shortcuts = [
      { keys: '?', desc: 'Bu yardım panelini aç' },
      { keys: modKey + ' + →', desc: 'Sonraki bölüme geç' },
      { keys: modKey + ' + ←', desc: 'Önceki bölüme geç' },
      { keys: modKey + ' + S', desc: 'Taslak olarak kaydet' },
      { keys: modKey + ' + K', desc: 'Hızlı arama' },
      { keys: 'ESC', desc: 'Açılır pencereleri kapat' },
      { keys: 'Tab', desc: 'Sonraki form alanına geç' },
      { keys: 'Shift + Tab', desc: 'Önceki form alanına geç' },
      { keys: modKey + ' + Enter', desc: 'Yayına al (onay ile)' },
      { keys: 'Enter', desc: 'Rozete tıkla / listeden alanı seç' },
      { keys: modKey + ' + Shift + L', desc: 'Tema döngüsü' },
      { keys: modKey + ' + Alt + 1', desc: 'Karanlık tema' },
      { keys: modKey + ' + Alt + 2', desc: 'Aydnlık tema' },
      { keys: modKey + ' + Alt + 3', desc: 'Midnight tema' },
      { keys: modKey + ' + Alt + 4', desc: 'Sahra tema' },
    ];
    var rows = shortcuts.map(function (s) {
      return '<div class="shortcut-row">'
        + '<span class="shortcut-keys">' + s.keys.split(' + ').map(function (k) {
          return '<kbd>' + k + '</kbd>';
        }).join('<span class="shortcut-plus">+</span>') + '</span>'
        + '<span class="shortcut-desc">' + s.desc + '</span>'
        + '</div>';
    }).join('');
    var bd = document.createElement('div');
    bd.id = 'shortcut-help-backdrop';
    bd.setAttribute('role', 'dialog');
    bd.setAttribute('aria-modal', 'true');
    bd.setAttribute('aria-label', 'Klavye kisayollari');
    var card = document.createElement('div');
    card.className = 'shortcut-help-card';
    var hdr = document.createElement('header');
    hdr.className = 'shortcut-help-header';
    var h3 = document.createElement('h3');
    h3.textContent = 'Klavye Kisayollari';
    var closeBtn = document.createElement('button');
    closeBtn.className = 'shortcut-help-close';
    closeBtn.setAttribute('aria-label', 'Kapat');
    closeBtn.textContent = '\u2715';
    hdr.appendChild(h3);
    hdr.appendChild(closeBtn);
    var body = document.createElement('div');
    body.className = 'shortcut-help-body';
    body.innerHTML = rows;
    var ftr = document.createElement('footer');
    ftr.className = 'shortcut-help-footer';
    var hint = document.createElement('span');
    hint.className = 'shortcut-help-hint';
    hint.textContent = 'Bir kisayili ? tusuna basarak tekrar goruntuleyebilirsiniz.';
    ftr.appendChild(hint);
    card.appendChild(hdr);
    card.appendChild(body);
    card.appendChild(ftr);
    bd.appendChild(card);
    bd.style.cssText = 'display:none;position:fixed;inset:0;z-index:10000;align-items:center;justify-content:center;background:rgba(3,7,18,0.72);backdrop-filter:blur(12px);-webkit-backdrop-filter:blur(12px);opacity:0;transition:opacity 0.2s ease';
    document.body.appendChild(bd);
    closeBtn.addEventListener('click', closeShortcutHelp);
    bd.addEventListener('click', function (e) { if (e.target === bd) closeShortcutHelp(); });
    shortcutHelpBackdrop = bd;
    return bd;
  }

  function openShortcutHelp() {
    var bd = buildShortcutHelp();
    bd.style.display = 'flex';
    requestAnimationFrame(function () { bd.style.opacity = '1'; });
    shortcutHelpOpen = true;
    bd.querySelector('.shortcut-help-close').focus();
  }

  function closeShortcutHelp() {
    if (!shortcutHelpBackdrop) return;
    shortcutHelpBackdrop.style.opacity = '0';
    setTimeout(function () { shortcutHelpBackdrop.style.display = 'none'; }, 200);
    shortcutHelpOpen = false;
  }

  // ? tuşu: metin giriş alanı dışındaysa paneli aç
  window.addEventListener('keydown', function (e) {
    if (e.key === '?') {
      var tag = (e.target && e.target.tagName || '').toLowerCase();
      var inTextEntry = tag === 'input' || tag === 'textarea' || tag === 'select';
      if (inTextEntry) return;
      e.preventDefault();
      if (shortcutHelpOpen) closeShortcutHelp();
      else openShortcutHelp();
    }
    // ESC: yardım panelini de kapat
    if (e.key === 'Escape' && shortcutHelpOpen) {
      closeShortcutHelp();
    }
  });

  // Keşfedilebilirlik: mod düğmelerinin hover ipucunda kısayollar da görünsün.
  if (btnModeStepper) btnModeStepper.setAttribute('title', SHORTCUT_HINT + ' · ? yardımı açar');
  if (btnModeFull) btnModeFull.setAttribute('title', SHORTCUT_HINT + ' · ? yardımı açar');

  // --- Mode Switcher (Stepper vs Full Form) ---
  var suppressModeToast = false;

  function setMode(mode) {
    formMode = mode;
    if (btnModeFull) btnModeFull.setAttribute('aria-pressed', mode === 'full' ? 'true' : 'false');
    if (btnModeStepper) btnModeStepper.setAttribute('aria-pressed', mode === 'stepper' ? 'true' : 'false');
    if (fullFormQuickNav) fullFormQuickNav.setAttribute('aria-hidden', mode === 'full' ? 'false' : 'true');
    if (mode === 'full') {
      if (btnModeFull) btnModeFull.classList.add('active');
      if (btnModeStepper) btnModeStepper.classList.remove('active');
      if (stepperWrap) stepperWrap.classList.add('hidden');
      if (fullFormQuickNav) fullFormQuickNav.classList.remove('hidden');
      if (form) form.classList.add('full-mode');
      if (formModeText) formModeText.textContent = 'Hızlı Manuel Form (Tüm Bölümler Açık)';

      stepPanels.forEach(function (p) {
        p.classList.add('active');
      });
      initAccordion(true);
      if (!suppressModeToast) {
        showToast(
          '⚡ Hızlı Manuel Form aktif: Bölümler başlıklarından açılıp kapanır. ' +
            SHORTCUT_HINT,
          'info'
        );
      }
    } else {
      if (btnModeStepper) btnModeStepper.classList.add('active');
      if (btnModeFull) btnModeFull.classList.remove('active');
      if (stepperWrap) stepperWrap.classList.remove('hidden');
      if (fullFormQuickNav) fullFormQuickNav.classList.add('hidden');
      if (form) form.classList.remove('full-mode');
      if (formModeText) formModeText.textContent = 'Adım Adım Sihirbaz';

      destroyAccordion();
      goToStep(currentStep);
    }
    // Mod tercihini kaydet (sunucu + localStorage fallback).
    saveWizardPrefsServer();
  }

  if (btnModeStepper) {
    btnModeStepper.addEventListener('click', function () {
      guardDirty(function () { setMode('stepper'); });
    });
  }

  if (btnModeFull) {
    btnModeFull.addEventListener('click', function () {
      guardDirty(function () { setMode('full'); });
    });
  }

  // In-Form Category Switcher Pills
  var catPills = document.querySelectorAll('.cat-pill-btn');
  catPills.forEach(function (pill) {
    pill.addEventListener('click', function () {
      var cat = this.getAttribute('data-cat');
      if (cat && cat !== currentCat) {
        window.location.href = '/admin/catalog?category=' + encodeURIComponent(cat);
      }
    });
  });

  // Toggle AI Card
  if (btnToggleAiCard && aiImportCard) {
    btnToggleAiCard.addEventListener('click', function () {
      var isHidden = aiImportCard.classList.contains('hidden');
      if (isHidden) {
        aiImportCard.classList.remove('hidden');
        showToast('✨ AI Asistanı gösteriliyor.', 'info');
      } else {
        aiImportCard.classList.add('hidden');
        showToast('AI Asistanı gizlendi. Manuel girişe odaklanabilirsiniz.', 'info');
      }
    });
  }

  // --- Step Completion Calculation ---
  // Her adım panelindeki zorunlu alanların doluluk oranını hesaplar.
  var progressLabel = document.getElementById('wizard-progress-label');

  function calculateStepCompletion(panel) {
    if (!panel) return 0;
    var fields = panel.querySelectorAll(
      'input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="checkbox"]):not([type="radio"]):not([name*="amenity"]), select, textarea'
    );
    if (fields.length === 0) return 1; // Alan yoksa tam sayılır
    var filled = 0;
    fields.forEach(function (f) {
      var val = (f.value || '').trim();
      if (val !== '' && val !== '0' && val !== null) filled++;
    });
    return filled / fields.length;
  }

  function calculateOverallCompletion() {
    var totalScore = 0;
    stepPanels.forEach(function (panel) {
      totalScore += calculateStepCompletion(panel);
    });
    return Math.round((totalScore / totalSteps) * 100);
  }

  function updateProgressBar() {
    var pct = calculateOverallCompletion();
    if (progressFill) {
      progressFill.style.width = pct + '%';
      // Renk değişim: düşük = amber, orta = cyan, yüksek = emerald
      if (pct < 30) {
        progressFill.style.background = 'linear-gradient(90deg, #f59e0b, #f97316)';
      } else if (pct < 70) {
        progressFill.style.background = '';
      } else {
        progressFill.style.background = 'linear-gradient(90deg, #10b981, #34d399)';
      }
    }
    if (progressLabel) {
      progressLabel.textContent = pct + '% tamamlandı';
    }
    var progressTrack = document.querySelector('.wizard-progress-track[role="progressbar"]');
    if (progressTrack) {
      progressTrack.setAttribute('aria-valuenow', String(pct));
    }
  }

  // Her input değişiminde ilerlemeyi güncelle
  if (form) {
    form.addEventListener('input', function () {
      requestAnimationFrame(updateProgressBar);
    });
    form.addEventListener('change', function () {
      requestAnimationFrame(updateProgressBar);
    });
  }

  // --- Step Navigation (Stepper Mode) ---
  // goToStepUser: kullanıcı etkileşiminden çağrılır, dirty guard uygular.
  // goToStep: dahili/programatik çağrılarda guardsız çalışır.
  function goToStep(step) {
    if (step < 1 || step > totalSteps) return;
    currentStep = step;

    if (formMode === 'full') {
      syncAccordionPanels(currentStep);
      return;
    }

    updateProgressBar();

    stepTabs.forEach(function (tab) {
      var tabStep = parseInt(tab.getAttribute('data-step'), 10);
      if (tabStep === currentStep) {
        tab.classList.add('active');
        tab.classList.remove('completed');
        tab.setAttribute('aria-current', 'step');
      } else if (tabStep < currentStep) {
        tab.classList.remove('active');
        tab.classList.add('completed');
        tab.setAttribute('aria-current', 'false');
      } else {
        tab.classList.remove('active', 'completed');
        tab.setAttribute('aria-current', 'false');
      }
    });

    stepPanels.forEach(function (panel) {
      var pStep = parseInt(panel.getAttribute('data-step-content'), 10);
      if (pStep === currentStep) {
        panel.classList.add('active');
      } else {
        panel.classList.remove('active');
      }
    });

    if (stepCounterText) {
      stepCounterText.textContent = 'Adım ' + currentStep + ' / ' + totalSteps;
    }
    if (btnPrev) {
      btnPrev.disabled = currentStep === 1;
    }
    if (btnNext && btnSubmit) {
      if (currentStep === totalSteps) {
        btnNext.classList.add('hidden');
        btnSubmit.classList.remove('hidden');
      } else {
        btnNext.classList.remove('hidden');
        btnSubmit.classList.add('hidden');
        btnNext.textContent = 'Sonraki: ' + stepLabels[currentStep - 1];
      }
    }
  }

  stepTabs.forEach(function (tab) {
    tab.addEventListener('click', function () {
      var targetStep = parseInt(this.getAttribute('data-step'), 10);
      guardDirty(function () { goToStep(targetStep); });
    });
  });

  if (btnPrev) {
    btnPrev.addEventListener('click', function () {
      guardDirty(function () { goToStep(currentStep - 1); });
    });
  }

  if (btnNext) {
    btnNext.addEventListener('click', function () {
      guardDirty(function () { goToStep(currentStep + 1); });
    });
  }

  // Step Footer Navigation Buttons (← Geri & Sonraki Adım →)
  document.querySelectorAll('.btn-step-nav').forEach(function (btn) {
    btn.addEventListener('click', function (e) {
      e.preventDefault();
      var targetStep = parseInt(this.getAttribute('data-target-step'), 10);
      if (targetStep && !isNaN(targetStep)) {
        guardDirty(function () {
          goToStep(targetStep);
          var stepperWrap = document.getElementById('wizard-stepper-wrap') || document.getElementById('top-live-preview-wrapper');
          if (stepperWrap) {
            stepperWrap.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }
        });
      }
    });
  });

  // --- Full Form Quick Nav Highlighting ---
  var navPills = document.querySelectorAll('.full-form-quick-nav .nav-pill');
  navPills.forEach(function (pill) {
    pill.addEventListener('click', function (e) {
      // Accordion modunda pill, hedef bölümü açıp diğerlerini daraltır
      var targetStep = parseInt((this.getAttribute('href') || '').replace('#sec-', ''), 10);
      if (formMode === 'full' && accordionBuilt && targetStep && !isNaN(targetStep)) {
        e.preventDefault();
        guardDirty(function () { goToStep(targetStep); });
      }
      navPills.forEach(function (p) {
        p.classList.remove('active');
        p.setAttribute('aria-current', 'false');
      });
      this.classList.add('active');
      this.setAttribute('aria-current', 'true');
    });
  });

  // --- Currency & Price Formatter ---
  function parseMinorFromDisplay(val) {
    if (!val) return '0';
    var clean = String(val).replace(/[^0-9]/g, '');
    if (!clean) return '0';
    return String(parseInt(clean, 10) * 100);
  }

  function formatDisplayFromMinor(minor) {
    var num = parseFloat(minor || 0) / 100;
    if (isNaN(num)) return '0';
    return num.toLocaleString('tr-TR', { maximumFractionDigits: 0 });
  }

  if (inputPriceDisplay && inputPriceMinor) {
    inputPriceDisplay.addEventListener('input', function () {
      var minor = parseMinorFromDisplay(this.value);
      inputPriceMinor.value = minor;
      updateLivePreview();
    });

    inputPriceDisplay.addEventListener('blur', function () {
      var minor = inputPriceMinor.value;
      this.value = formatDisplayFromMinor(minor);
    });
  }

  function formatCurrency(amountMinor, curr) {
    var num = parseFloat(amountMinor || 0) / 100;
    var symbol = '₺';
    if (curr === 'USD') symbol = '$';
    if (curr === 'EUR') symbol = '€';
    if (curr === 'GBP') symbol = '£';
    return symbol + num.toLocaleString('tr-TR', { maximumFractionDigits: 0 });
  }

  function getCategoryFallbackImage(cat) {
    var c = (cat || '').toLowerCase();
    if (c === 'hotel') return 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80';
    if (c === 'villa') return 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=800&q=80';
    if (c === 'yacht') return 'https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=800&q=80';
    if (c === 'tour') return 'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?auto=format&fit=crop&w=800&q=80';
    if (c === 'car_rental' || c === 'car') return 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=800&q=80';
    if (c === 'bungalow') return 'https://images.unsplash.com/photo-1518780664697-55e3ad937233?auto=format&fit=crop&w=800&q=80';
    if (c === 'caravan') return 'https://images.unsplash.com/photo-1523987355523-c7b5b0dd90a7?auto=format&fit=crop&w=800&q=80';
    if (c === 'thermal') return 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?auto=format&fit=crop&w=800&q=80';
    if (c === 'ski') return 'https://images.unsplash.com/photo-1551524559-8af4e6624178?auto=format&fit=crop&w=800&q=80';
    if (c === 'transfer') return 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=800&q=80';
    return 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=800&q=80';
  }

  // --- Real-time Live Preview Sync ---
  function updateLivePreview() {
    var titleInput = document.getElementById('input-title');
    var locInput = document.getElementById('input-locality');
    var currInput = document.getElementById('input-currency');
    var statusInput = document.getElementById('input-status');

    var titleVal = (titleInput && titleInput.value ? titleInput.value : '').trim();
    var locVal = (locInput && locInput.value ? locInput.value : '').trim();
    var priceVal = inputPriceMinor && inputPriceMinor.value ? inputPriceMinor.value : '0';
    var currVal = currInput && currInput.value ? currInput.value : 'TRY';
    var statusVal = statusInput && statusInput.value ? statusInput.value : 'published';
    var activeCat = currentCat || 'hotel';

    // 1. Cover Image & Photo Count
    var coverImg = document.getElementById('preview-cover-img') || document.getElementById('preview-img');
    if (coverImg) {
      if (images && images.length > 0 && images[0]) {
        coverImg.src = images[0];
      } else {
        coverImg.src = getCategoryFallbackImage(activeCat);
      }
    }

    var photoCountEl = document.getElementById('preview-photo-count');
    if (photoCountEl) {
      photoCountEl.textContent = '📸 ' + (images ? images.length : 0) + ' Fotoğraf';
    }

    // 2. Title
    var titleEl = document.getElementById('preview-title');
    if (titleEl) {
      titleEl.textContent = titleVal || 'İlan Başlığı Buraya Gelecek...';
      titleEl.style.color = titleVal ? '#f8fafc' : 'rgba(255, 255, 255, 0.45)';
    }

    // 3. Price & Currency & Period
    var priceEl = document.getElementById('preview-price');
    if (priceEl) {
      var num = parseFloat(priceVal || 0) / 100;
      priceEl.textContent = isNaN(num) ? '0' : num.toLocaleString('tr-TR', { maximumFractionDigits: 0 });
    }

    var priceCurrencyEl = document.querySelector('.showcase-price-currency');
    if (priceCurrencyEl) {
      var symbol = '₺';
      if (currVal === 'USD') symbol = '$';
      if (currVal === 'EUR') symbol = '€';
      if (currVal === 'GBP') symbol = '£';
      priceCurrencyEl.textContent = ' ' + symbol;
    }

    var periodEl = document.getElementById('preview-price-period') || document.querySelector('.showcase-price-period');

    // 4. Locality & Category Specific Specs
    var localityEl = document.getElementById('preview-locality');
    var specsContainer = document.getElementById('preview-specs');
    var ratingEl = document.getElementById('preview-rating') || document.querySelector('.showcase-rating-badge');

    if (isHotel) {
      var beachSel = document.getElementById('input-beach-distance');
      var beachText = beachSel && beachSel.options[beachSel.selectedIndex] ? beachSel.options[beachSel.selectedIndex].text : '';
      var beachShort = beachText ? (beachText.indexOf('Sıfır') !== -1 ? 'Denize Sıfır' : beachText.split(' (')[0]) : 'Plaj Yakını';
      if (localityEl) {
        localityEl.textContent = locVal ? '📍 ' + locVal + ' (' + beachShort + ')' : '📍 Konum Seçilmedi (Şehir / Bölge)';
      }

      var starsSel = document.getElementById('input-hotel-stars');
      var starsText = starsSel && starsSel.options[starsSel.selectedIndex] ? starsSel.options[starsSel.selectedIndex].text : '5 Yıldızlı';
      var starsShort = starsText.split(' ')[0] + ' ' + (starsText.split(' ')[1] || 'Resort');
      if (ratingEl) ratingEl.textContent = '★ 4.96 · ' + starsShort;

      var boardSel = document.getElementById('input-board-type');
      var boardText = boardSel && boardSel.options[boardSel.selectedIndex] ? boardSel.options[boardSel.selectedIndex].text : '';
      var boardShort = boardText ? boardText.split(' (')[0] : 'Oda & Kahvaltı';

      if (specsContainer) {
        specsContainer.innerHTML =
          '<span class="spec-pill">🏨 ' + escapeHtml(roomTypes.length ? roomTypes.length + ' Oda Tipi' : 'Oda Tipi Eklenmedi') + '</span>' +
          '<span class="spec-pill">🍽️ ' + escapeHtml(boardShort) + '</span>' +
          '<span class="spec-pill">🏖️ ' + escapeHtml(beachShort) + '</span>';
      }

      var pricingModelSel = document.getElementById('input-pricing-model');
      var isPerPerson = pricingModelSel && pricingModelSel.value === 'per_person';
      if (periodEl) {
        periodEl.textContent = isPerPerson ? ' / kişi / gece' : ' / gece / oda';
      }
    } else if (isYacht) {
      if (localityEl) localityEl.textContent = locVal ? '⚓ ' + locVal + ' Limanı' : '⚓ Liman Seçilmedi';
      if (ratingEl) ratingEl.textContent = '★ 4.95 (Lüks Yat)';

      var guestsVal = (document.getElementById('input-guests') && document.getElementById('input-guests').value) || '—';
      var cabinsVal = (document.getElementById('input-bedrooms') && document.getElementById('input-bedrooms').value) || '—';
      if (specsContainer) {
        specsContainer.innerHTML =
          '<span class="spec-pill">⚓ Kaptanlı & Klimalı</span>' +
          '<span class="spec-pill">🛏️ ' + escapeHtml(cabinsVal) + ' Kabin</span>' +
          '<span class="spec-pill">👥 ' + escapeHtml(guestsVal) + ' Misafir</span>';
      }
      if (periodEl) periodEl.textContent = ' / gün';
    } else if (isTour) {
      if (localityEl) localityEl.textContent = locVal ? '🗺️ ' + locVal : '🗺️ Tur Bölgesi Seçilmedi';
      if (ratingEl) ratingEl.textContent = '★ 4.92 (Rehberli Tur)';

      if (specsContainer) {
        specsContainer.innerHTML =
          '<span class="spec-pill">⏱️ Tam Günlük Tur</span>' +
          '<span class="spec-pill">🍱 Öğle Yemeği Dahil</span>' +
          '<span class="spec-pill">🚐 Otel Transferli</span>';
      }
      if (periodEl) periodEl.textContent = ' / kişi';
    } else if (isCar) {
      if (localityEl) localityEl.textContent = locVal ? '🚗 ' + locVal + ' Teslim' : '🚗 Teslim Noktası Seçilmedi';
      if (ratingEl) ratingEl.textContent = '★ 4.90 (Kiralık Araç)';

      if (specsContainer) {
        specsContainer.innerHTML =
          '<span class="spec-pill">🕹️ Otomatik Vites</span>' +
          '<span class="spec-pill">⛽ Benzin / Dizel</span>' +
          '<span class="spec-pill">🛡️ Full Kasko & Muafiyetsiz</span>';
      }
      if (periodEl) periodEl.textContent = ' / gün';
    } else if (isTransfer) {
      if (localityEl) localityEl.textContent = locVal ? '🚐 ' + locVal : '🚐 Transfer Güzergâhı';
      if (ratingEl) ratingEl.textContent = '★ 4.98 (VIP Transfer)';

      if (specsContainer) {
        specsContainer.innerHTML =
          '<span class="spec-pill">🚐 Mercedes Vito / VIP</span>' +
          '<span class="spec-pill">✈️ Havalimanı Karşılama</span>' +
          '<span class="spec-pill">⏱️ 7/24 Kesintisiz</span>';
      }
      if (periodEl) periodEl.textContent = ' / araç tek yön';
    } else if (isActivity) {
      if (localityEl) localityEl.textContent = locVal ? '🎯 ' + locVal : '🎯 Etkinlik Bölgesi';
      if (ratingEl) ratingEl.textContent = '★ 4.94 (Aktivite)';

      if (specsContainer) {
        specsContainer.innerHTML =
          '<span class="spec-pill">🪂 Ekstrem / Macera</span>' +
          '<span class="spec-pill">⏱️ 2 - 3 Saat</span>' +
          '<span class="spec-pill">🛡️ Profesyonel Eğitmenli</span>';
      }
      if (periodEl) periodEl.textContent = ' / kişi';
    } else {
      // Villa / Holiday Home
      if (localityEl) localityEl.textContent = locVal ? '📍 ' + locVal : '📍 Konum Seçilmedi (Şehir / Bölge)';
      if (ratingEl) ratingEl.textContent = '★ 4.98 (Lüks Villa)';

      var guestsVal = (document.getElementById('input-guests') && document.getElementById('input-guests').value) || '6';
      var bedsVal = (document.getElementById('input-bedrooms') && document.getElementById('input-bedrooms').value) || '3';
      var bathsVal = (document.getElementById('input-bathrooms') && document.getElementById('input-bathrooms').value) || '2';
      var poolVal = (document.getElementById('input-pool-dimensions') && document.getElementById('input-pool-dimensions').value) || '';
      var shelteredVal = document.getElementById('input-sheltered-pool') && document.getElementById('input-sheltered-pool').value;

      var poolLabel = poolVal ? '🏊 ' + poolVal : (shelteredVal === 'yes' ? '🏊 Korunaklı Havuz' : '🏊 Özel Havuz');

      if (specsContainer) {
        specsContainer.innerHTML =
          '<span class="spec-pill">🛏️ ' + escapeHtml(bedsVal) + ' Yatak Odası</span>' +
          '<span class="spec-pill">👥 ' + escapeHtml(guestsVal) + ' Kişi Kapasite</span>' +
          '<span class="spec-pill">🚿 ' + escapeHtml(bathsVal) + ' Banyo</span>' +
          '<span class="spec-pill">' + escapeHtml(poolLabel) + '</span>';
      }
      if (periodEl) periodEl.textContent = ' / gece';
    }

    // 5. Status Pill
    var statusPill = document.getElementById('preview-status') || document.getElementById('preview-status-pill');
    if (statusPill) {
      if (statusVal === 'published') {
        statusPill.textContent = '🟢 Yayında';
        statusPill.className = 'card-status-pill published';
      } else if (statusVal === 'draft') {
        statusPill.textContent = '🟡 Taslak Modu';
        statusPill.className = 'card-status-pill draft';
      } else if (statusVal === 'paused') {
        statusPill.textContent = '⏸️ Duraklatıldı';
        statusPill.className = 'card-status-pill warning';
      } else {
        statusPill.textContent = '🟣 İncelemede';
        statusPill.className = 'card-status-pill review';
      }
    }

    // 6. Dynamic Amenities Showcase Pills
    var amenitiesBox = document.getElementById('preview-amenities-icons');
    if (amenitiesBox) {
      amenitiesBox.innerHTML = '';
      if (selectedAmenities && selectedAmenities.length > 0) {
        selectedAmenities.forEach(function (amenityCode) {
          var chipEl = document.querySelector('.amenity-toggle-chip[data-amenity="' + amenityCode + '"]');
          var text = chipEl ? (chipEl.querySelector('.chip-text') ? chipEl.querySelector('.chip-text').textContent : amenityCode) : amenityCode;
          var icon = amenityIcons[amenityCode] || (chipEl && chipEl.querySelector('.chip-icon') ? chipEl.querySelector('.chip-icon').textContent : '✦');

          var pill = document.createElement('span');
          pill.className = 'live-amenity-pill';
          pill.innerHTML = '<span class="pill-icon">' + escapeHtml(icon) + '</span> <span class="pill-label">' + escapeHtml(text) + '</span>';
          amenitiesBox.appendChild(pill);
        });
      } else {
        var placeholder = document.createElement('span');
        placeholder.className = 'amenity-placeholder';
        placeholder.textContent = "Adım 4'ten özellik seçildiğinde burada canlı listelenecektir.";
        amenitiesBox.appendChild(placeholder);
      }
    }

    // 7. Sync SEO SERP Preview
    var sTitle = (inputSeoTitle && inputSeoTitle.value) || titleVal;
    var sSlug = (inputSeoSlug && inputSeoSlug.value) || slugify(titleVal);
    var sDesc = (inputSeoDesc && inputSeoDesc.value) || ((document.getElementById('input-description') && document.getElementById('input-description').value) || '');

    if (serpPreviewTitle) serpPreviewTitle.textContent = sTitle || 'İlan Başlığı | Nexus Travel';
    if (serpPreviewSlug) serpPreviewSlug.textContent = ' › ' + (isHotel ? 'otel' : 'villa') + ' › ' + (sSlug || 'yeni-ilan');
    if (serpPreviewDesc) serpPreviewDesc.textContent = (sDesc || 'Nexus Travel ayrıcalığıyla hemen rezervasyon yapın.').slice(0, 160);

    if (seoTitleCount && inputSeoTitle) {
      seoTitleCount.textContent = inputSeoTitle.value.length + ' / 60 karakter';
    }
    if (seoDescCount && inputSeoDesc) {
      seoDescCount.textContent = inputSeoDesc.value.length + ' / 160 karakter';
    }
  }

  // Global Listing Loader: Binds table selection directly to form and live preview card
  window.loadListingIntoWizard = function (listing) {
    if (!listing) return;

    // Show active edit banner
    var banner = document.getElementById('wizard-edit-mode-banner');
    var bannerCode = document.getElementById('banner-listing-code');
    var bannerTitle = document.getElementById('banner-listing-title');
    if (banner) banner.classList.remove('hidden');
    if (bannerCode) bannerCode.textContent = listing.code || '';
    if (bannerTitle) bannerTitle.textContent = listing.title || '';

    // Basic fields
    var codeInput = document.getElementById('input-code');
    var titleInput = document.getElementById('input-title');
    var locInput = document.getElementById('input-locality');
    var descInput = document.getElementById('input-description');
    var currInput = document.getElementById('input-currency');
    var statusInput = document.getElementById('input-status');

    if (codeInput) codeInput.value = listing.code || '';
    if (titleInput) titleInput.value = listing.title || '';
    if (locInput) locInput.value = listing.locality || '';
    if (descInput) descInput.value = listing.description || '';
    if (currInput) currInput.value = listing.currency || 'TRY';
    if (statusInput) statusInput.value = listing.status || 'published';

    // Price
    if (inputPriceMinor) inputPriceMinor.value = listing.priceMinor || '0';
    if (inputPriceDisplay) {
      var num = Number(listing.priceMinor || 0) / 100;
      inputPriceDisplay.value = num > 0 ? num.toLocaleString('tr-TR') : '0';
    }

    // Category
    var catInputField = document.getElementById('catalog-category-input');
    if (listing.category && catInputField) {
      catInputField.value = listing.category;
    }

    // Parse metadata
    var meta = {};
    if (typeof listing.metadata === 'string') {
      try { meta = JSON.parse(listing.metadata); } catch (e) { meta = {}; }
    } else if (typeof listing.metadata === 'object' && listing.metadata !== null) {
      meta = listing.metadata;
    }

    hotelContract = typeof meta.extra_metadata?.hotel_contract === 'string' ? meta.extra_metadata.hotel_contract : '';
    hotelHouseRules = Object.assign({}, meta.extra_metadata?.hotel_house_rules || {});
    hotelSections = Array.isArray(meta.extra_metadata?.hotel_sections) ? meta.extra_metadata.hotel_sections.map(function (entry) { return Object.assign({}, entry); }) : hotelSectionTitles.map(function (title) { return {title: title, content: ''}; });
    renderHotelSections();
    // Populate metadata fields
    var guestsInput = document.getElementById('input-guests');
    var bedroomsInput = document.getElementById('input-bedrooms');
    var bedsInput = document.getElementById('input-beds');
    var bathsInput = document.getElementById('input-bathrooms');
    var poolInput = document.getElementById('input-pool-dimensions');
    var shelteredInput = document.getElementById('input-sheltered-pool');
    var cleaningInput = document.getElementById('input-cleaning-fee');
    var minStayInput = document.getElementById('input-min-stay');
    var icalInput = document.getElementById('input-ical-url');

    var canonicalMeta = normalizeContractFieldValues(meta.contract_fields || {}, meta);
    if (guestsInput && (meta.guests !== undefined || canonicalMeta.guest_capacity !== undefined)) guestsInput.value = firstFilled(meta.guests, canonicalMeta.guest_capacity);
    if (bedroomsInput && (meta.bedrooms !== undefined || canonicalMeta.bedroom_count !== undefined)) bedroomsInput.value = firstFilled(meta.bedrooms, canonicalMeta.bedroom_count);
    if (bedsInput && meta.beds !== undefined) bedsInput.value = meta.beds;
    if (bathsInput && (meta.bathrooms !== undefined || canonicalMeta.bathroom_count !== undefined)) bathsInput.value = firstFilled(meta.bathrooms, canonicalMeta.bathroom_count);
    if (poolInput && meta.pool_dimensions !== undefined) poolInput.value = meta.pool_dimensions;
    if (shelteredInput && meta.sheltered_pool !== undefined) shelteredInput.value = meta.sheltered_pool;
    if (cleaningInput && meta.cleaning_fee !== undefined) cleaningInput.value = meta.cleaning_fee;
    if (minStayInput && meta.min_stay_days !== undefined) minStayInput.value = meta.min_stay_days;
    if (icalInput && meta.ical_url !== undefined) icalInput.value = meta.ical_url;

    // Hotel specific metadata
    var starsInput = document.getElementById('input-hotel-stars');
    var boardInput = document.getElementById('input-board-type');
    var beachInput = document.getElementById('input-beach-distance');
    var airportInput = document.getElementById('input-airport-distance');
    var pricingModelInput = document.getElementById('input-pricing-model');
    var checkInInput = document.getElementById('input-check-in');
    var checkOutInput = document.getElementById('input-check-out');

    if (starsInput && meta.hotel_stars !== undefined) starsInput.value = meta.hotel_stars;
    if (boardInput && meta.board_type !== undefined) boardInput.value = meta.board_type;
    if (beachInput && meta.beach_distance !== undefined) beachInput.value = meta.beach_distance;
    if (airportInput && meta.airport_distance !== undefined) airportInput.value = meta.airport_distance;
    if (pricingModelInput && meta.pricing_model !== undefined) pricingModelInput.value = meta.pricing_model;
    if (checkInInput && meta.check_in_time !== undefined) checkInInput.value = meta.check_in_time;
    if (checkOutInput && meta.check_out_time !== undefined) checkOutInput.value = meta.check_out_time;

    // SEO fields
    if (inputSeoTitle) inputSeoTitle.value = meta.seo_title || listing.title || '';
    if (inputSeoDesc) inputSeoDesc.value = meta.seo_description || listing.description || '';
    if (inputSeoSlug) inputSeoSlug.value = meta.slug || slugify(listing.title || '');

    // Parse images
    var parsedImgs = [];
    if (Array.isArray(listing.images)) {
      parsedImgs = listing.images;
    } else if (typeof listing.images === 'string') {
      try { parsedImgs = JSON.parse(listing.images); } catch (e) { parsedImgs = []; }
    }
    images = Array.isArray(parsedImgs) ? parsedImgs : [];
    renderPhotos();

    // Parse amenities
    var parsedAmenities = [];
    if (Array.isArray(listing.amenities)) {
      parsedAmenities = listing.amenities;
    } else if (typeof listing.amenities === 'string') {
      try { parsedAmenities = JSON.parse(listing.amenities); } catch (e) { parsedAmenities = []; }
    }
    selectedAmenities = Array.isArray(parsedAmenities) ? parsedAmenities : [];
    var amenityCheckboxes = document.querySelectorAll('.wizard-amenities-grid input[type="checkbox"]');
    amenityCheckboxes.forEach(function (cb) {
      cb.checked = selectedAmenities.indexOf(cb.value) !== -1;
    });
    syncAmenities();

    // Parse Room Types
    if (isHotel) {
      var parsedRooms = meta.room_types || [];
      if (typeof parsedRooms === 'string') {
        try { parsedRooms = JSON.parse(parsedRooms); } catch (e) { parsedRooms = []; }
      }
      roomTypes = Array.isArray(parsedRooms) ? parsedRooms : [];
      renderRoomTypes();
    }

    // Submit button label update
    var submitBtn = document.getElementById('btn-wizard-submit');
    var topPublishBtn = document.getElementById('btn-quick-publish');
    if (submitBtn) submitBtn.textContent = '✓ Değişiklikleri Güncelle ve Kaydet';
    if (topPublishBtn) topPublishBtn.textContent = '🚀 Güncellemeleri Kaydet';

    updateLivePreview();

    // Smooth scroll to wizard
    var targetElem = document.getElementById('catalog-workspace');
    if (targetElem) {
      targetElem.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }

    showToast('✓ ' + (listing.code || 'İlan') + ' başarıyla yüklendi. Düzenleyebilirsiniz.', 'success');
  };

  // Global Wizard Reset
  window.resetWizardForm = function () {
    var banner = document.getElementById('wizard-edit-mode-banner');
    if (banner) banner.classList.add('hidden');

    if (form) form.reset();

    var codeInput = document.getElementById('input-code');
    if (codeInput) codeInput.value = '';

    if (inputPriceMinor) inputPriceMinor.value = '0';
    if (inputPriceDisplay) inputPriceDisplay.value = '';

    images = [];
    renderPhotos();

    selectedAmenities = [];
    var amenityCheckboxes = document.querySelectorAll('.wizard-amenities-grid input[type="checkbox"]');
    amenityCheckboxes.forEach(function (cb) { cb.checked = false; });
    syncAmenities();

    if (isHotel) {
      roomTypes = [];
      renderRoomTypes();
    }

    var submitBtn = document.getElementById('btn-wizard-submit');
    var topPublishBtn = document.getElementById('btn-quick-publish');
    if (submitBtn) submitBtn.textContent = '✓ Kataloğa Kaydet ve Yayınla';
    if (topPublishBtn) topPublishBtn.textContent = '🚀 Kataloğa Kaydet ve Yayınla';

    document.querySelectorAll('.catalog-row.selected-row').forEach(function (r) {
      r.classList.remove('selected-row');
    });

    goToStep(1);
    updateLivePreview();
    showToast('Yeni ilan oluşturma moduna geçildi. Alanlar temizlendi.', 'info');
  };

  // Cancel edit banner button
  var btnCancelEdit = document.getElementById('btn-cancel-edit-mode');
  if (btnCancelEdit) {
    btnCancelEdit.addEventListener('click', function () {
      window.resetWizardForm();
    });
  }

  function slugify(text) {
    if (!text) return '';
    var trMap = { 'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'Ç': 'c', 'Ğ': 'g', 'İ': 'i', 'Ö': 'o', 'Ş': 's', 'Ü': 'u' };
    return text
      .split('')
      .map(function (c) { return trMap[c] || c; })
      .join('')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 50);
  }

  // Listen to input changes across the form
  form.addEventListener('input', updateLivePreview);
  form.addEventListener('change', updateLivePreview);

  // Auto generate slug from title if slug is empty
  var inputTitle = document.getElementById('input-title');
  if (inputTitle && inputSeoSlug) {
    inputTitle.addEventListener('input', function () {
      if (!inputSeoSlug.dataset.manual) {
        inputSeoSlug.value = slugify(this.value);
      }
    });
    inputSeoSlug.addEventListener('input', function () {
      this.dataset.manual = 'true';
    });
  }

  // --- Hotel Room Types Manager & In-Page Modal ---
  function renderRoomTypes() {
    if (roomTypesInput) {
      roomTypesInput.value = JSON.stringify(roomTypes);
    }
    if (!roomTypesContainer) return;

    roomTypesContainer.textContent = '';
    roomTypes.forEach(function (room, index) {
      var card = document.createElement('div');
      card.className = 'room-type-card';
      card.setAttribute('data-room-id', room.id || String(index + 1));

      var header = document.createElement('div');
      header.className = 'room-type-header';

      var titleRow = document.createElement('div');
      titleRow.className = 'room-type-title-row';
      titleRow.innerHTML = '<span class="room-type-icon">🛏️</span><strong class="room-type-name">' + escapeHtml(room.title || 'Oda Tipi') + '</strong>';

      var actionsRow = document.createElement('div');
      actionsRow.className = 'room-type-actions';

      var countBadge = document.createElement('span');
      countBadge.className = 'room-type-count-badge';
      countBadge.textContent = (room.count || '1') + ' Oda';

      var delBtn = document.createElement('button');
      delBtn.type = 'button';
      delBtn.className = 'room-action-btn';
      delBtn.textContent = '🗑️';
      delBtn.title = 'Oda tipini sil';
      delBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        if (roomTypes.length <= 1) {
          showToast('Tesis bünyesinde en az bir oda tipi bulunmalıdır.', 'warning');
          return;
        }
        roomTypes.splice(index, 1);
        renderRoomTypes();
        showToast('Oda tipi silindi.', 'info');
      });

      actionsRow.appendChild(countBadge);
      actionsRow.appendChild(delBtn);
      header.appendChild(titleRow);
      header.appendChild(actionsRow);

      var specs = document.createElement('div');
      specs.className = 'room-type-specs';
      specs.innerHTML =
        '<span class="room-spec-pill">📐 ' + escapeHtml(room.size_m2 || '30') + ' m²</span>' +
        '<span class="room-spec-pill">👥 ' + escapeHtml(room.adults || '2') + ' Yetişkin + ' + escapeHtml(room.children || '0') + ' Çocuk</span>' +
        '<span class="room-spec-pill">🛌 ' + escapeHtml(room.bed || '1 Çift Kişilik') + '</span>' +
        '<span class="room-spec-pill">🌅 ' + escapeHtml(room.view_type || 'Kara / Deniz') + '</span>';

      card.appendChild(header);
      card.appendChild(specs);
      roomTypesContainer.appendChild(card);
    });

    updateLivePreview();
  }

  // Room Type Modal Handlers
  if (btnAddRoomType && roomTypeModal) {
    btnAddRoomType.addEventListener('click', function () {
      roomTypeModal.classList.remove('hidden');
      roomTypeModal.setAttribute('aria-hidden', 'false');
      var titleInput = document.getElementById('modal-room-title');
      if (titleInput) titleInput.value = '';
      if (window.FocusTrap) {
        // Tab döngüsü modal içinde kalır; ESC kapatır, kapanınca odak geri döner
        FocusTrap.activate(roomTypeModal, {
          onEscape: closeRoomModal,
          initialFocus: titleInput || undefined,
        });
      } else if (titleInput) {
        titleInput.focus();
      }
    });
  }

  function closeRoomModal() {
    if (roomTypeModal) {
      if (window.FocusTrap && FocusTrap.isActive(roomTypeModal)) FocusTrap.deactivate();
      roomTypeModal.classList.add('hidden');
      roomTypeModal.setAttribute('aria-hidden', 'true');
      if (btnAddRoomType) btnAddRoomType.focus();
    }
  }

  if (btnCloseRoomModal) btnCloseRoomModal.addEventListener('click', closeRoomModal);
  if (btnCancelRoomModal) btnCancelRoomModal.addEventListener('click', closeRoomModal);

  if (btnSaveRoomModal) {
    btnSaveRoomModal.addEventListener('click', function () {
      var title = (document.getElementById('modal-room-title')?.value || '').trim();
      if (!title) {
        showToast('Lütfen oda tipi adını giriniz.', 'warning');
        document.getElementById('modal-room-title')?.focus();
        return;
      }
      var size = document.getElementById('modal-room-size')?.value || '35';
      var adults = document.getElementById('modal-room-adults')?.value || '2';
      var children = document.getElementById('modal-room-children')?.value || '1';
      var bed = document.getElementById('modal-room-bed')?.value || '1 Çift Kişilik King Size';
      var view = document.getElementById('modal-room-view')?.value || 'Deniz Manzaralı';
      var count = document.getElementById('modal-room-count')?.value || '10';

      roomTypes.push({
        id: String(Date.now()),
        title: title,
        size_m2: size,
        adults: adults,
        children: children,
        bed: bed,
        view_type: view,
        count: count
      });

      renderRoomTypes();
      closeRoomModal();
      showToast('✓ Yeni oda tipi başarıyla eklendi: ' + title, 'success');
    });
  }

  // --- Amenities Matrix ---
  function syncAmenities() {
    if (amenitiesInput) {
      amenitiesInput.value = JSON.stringify(selectedAmenities);
    }
    document.querySelectorAll('.amenity-toggle-chip').forEach(function (chip) {
      var code = chip.getAttribute('data-amenity');
      var on = selectedAmenities.indexOf(code) !== -1;
      if (on) {
        chip.classList.add('active');
      } else {
        chip.classList.remove('active');
      }
      chip.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
    updateLivePreview();
  }

  document.querySelectorAll('.amenity-toggle-chip').forEach(function (chip) {
    chip.addEventListener('click', function () {
      var code = this.getAttribute('data-amenity');
      var idx = selectedAmenities.indexOf(code);
      if (idx === -1) {
        selectedAmenities.push(code);
      } else {
        selectedAmenities.splice(idx, 1);
      }
      syncAmenities();
    });
  });

  // --- Photos Gallery & Drag-and-Drop Uploader ---
  function renderPhotos() {
    if (imagesInput) {
      imagesInput.value = JSON.stringify(images);
    }
    if (!photosGallery) return;

    photosGallery.textContent = '';
    if (!images.length) {
      var emptyNote = document.createElement('div');
      emptyNote.className = 'gallery-empty-note';
      emptyNote.textContent = 'Henüz görsel eklenmedi. Yukarıdan fotoğraf seçebilir veya URL yapıştırabilirsiniz.';
      photosGallery.appendChild(emptyNote);
      return;
    }

    images.forEach(function (url, index) {
      var card = document.createElement('div');
      card.className = 'photo-card' + (index === 0 ? ' is-cover' : '');

      var img = document.createElement('img');
      img.src = url;
      img.alt = 'Galeri Fotoğrafı ' + (index + 1);

      var actions = document.createElement('div');
      actions.className = 'photo-actions';

      var coverBtn = document.createElement('button');
      coverBtn.type = 'button';
      coverBtn.className = 'photo-cover-btn';
      coverBtn.textContent = index === 0 ? '★ Kapak' : '☆ Kapak Yap';
      coverBtn.title = 'Kapak fotoğrafı olarak belirle';
      coverBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        var item = images.splice(index, 1)[0];
        images.unshift(item);
        renderPhotos();
        showToast('Kapak fotoğrafı güncellendi.', 'success');
      });

      var delBtn = document.createElement('button');
      delBtn.type = 'button';
      delBtn.className = 'photo-delete-btn';
      delBtn.textContent = '🗑️';
      delBtn.title = 'Fotoğrafı kaldır';
      delBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        images.splice(index, 1);
        renderPhotos();
        showToast('Fotoğraf silindi.', 'info');
      });

      actions.appendChild(coverBtn);
      actions.appendChild(delBtn);

      card.appendChild(img);
      card.appendChild(actions);
      photosGallery.appendChild(card);
    });

    updateLivePreview();
    schedulePublishReadinessUpdate();
  }

  // Handle local file uploads via FileReader
  function handleFiles(fileList) {
    if (!fileList || !fileList.length) return;
    var loadedCount = 0;
    var totalFiles = fileList.length;

    Array.prototype.forEach.call(fileList, function (file) {
      if (!file.type.match('image.*')) return;
      var reader = new FileReader();
      reader.onload = function (e) {
        images.push(e.target.result);
        loadedCount++;
        if (loadedCount === totalFiles) {
          renderPhotos();
          showToast('📸 ' + totalFiles + ' adet fotoğraf başarıyla eklendi!', 'success');
        }
      };
      reader.readAsDataURL(file);
    });
  }

  if (btnBrowsePhotos && photoFileInput) {
    btnBrowsePhotos.addEventListener('click', function (e) {
      e.stopPropagation();
      photoFileInput.click();
    });
  }

  if (photoDropzone && photoFileInput) {
    photoDropzone.addEventListener('click', function () {
      photoFileInput.click();
    });

    photoDropzone.addEventListener('dragover', function (e) {
      e.preventDefault();
      photoDropzone.classList.add('dragover');
    });

    photoDropzone.addEventListener('dragleave', function () {
      photoDropzone.classList.remove('dragover');
    });

    photoDropzone.addEventListener('drop', function (e) {
      e.preventDefault();
      photoDropzone.classList.remove('dragover');
      if (e.dataTransfer && e.dataTransfer.files) {
        handleFiles(e.dataTransfer.files);
      }
    });

    photoFileInput.addEventListener('change', function () {
      if (this.files) {
        handleFiles(this.files);
      }
    });
  }

  if (btnAddPhoto && mediaUrlInput) {
    btnAddPhoto.addEventListener('click', function () {
      var url = (mediaUrlInput.value || '').trim();
      if (!url) return;
      images.push(url);
      mediaUrlInput.value = '';
      renderPhotos();
      showToast('Fotoğraf URL üzerinden eklendi.', 'success');
    });
  }

  // --- Automatic Unique Code Generator ---
  if (btnGenCode) {
    btnGenCode.addEventListener('click', function () {
      var prefix = isHotel ? 'HTL' : 'VIL';
      if (currentCat === 'yacht') prefix = 'YCT';
      if (currentCat === 'tour') prefix = 'TUR';
      if (currentCat === 'car') prefix = 'CAR';
      if (currentCat === 'transfer') prefix = 'TRF';
      if (currentCat === 'activity') prefix = 'ACT';

      var rand = Math.floor(100 + Math.random() * 900);
      var year = new Date().getFullYear();
      var code = prefix + '-' + year + '-' + rand;

      var inputCode = document.getElementById('input-code');
      if (inputCode) {
        inputCode.value = code;
        inputCode.classList.add('ai-highlight');
        setTimeout(function () { inputCode.classList.remove('ai-highlight'); }, 1500);
      }
      showToast('⚡ Benzersiz kod üretildi: ' + code, 'success');
    });
  }

  // --- Sample Template Fill & Form Reset ---
  if (btnFillSample) {
    btnFillSample.addEventListener('click', function () {
      function set(id, val) {
        var el = document.getElementById(id);
        if (el) {
          el.value = val;
          el.dispatchEvent(new Event('input', { bubbles: true }));
        }
      }

      if (isHotel) {
        set('input-code', 'HTL-' + new Date().getFullYear() + '-' + Math.floor(100 + Math.random() * 900));
        set('input-title', 'Bodrum Luxury Resort & Spa (Ultra Her Şey Dahil)');
        set('input-hotel-stars', '5_star');
        set('input-board-type', 'uai');
        set('input-locality', 'Torba, Bodrum, Muğla');
        set('input-beach-distance', 'zero');
        set('input-airport-dist', '32 km');
        set('input-hotel-rooms', '180');
        set('input-hotel-beds', '420');
        set('input-hotel-pools', '3 Açık Havuz, 1 Aquapark, 1 Kapalı Termal');
        set('input-price-minor', '1850000');
        if (inputPriceDisplay) inputPriceDisplay.value = '18.500';
        set('input-currency', 'TRY');
        set('input-pricing-model', 'per_room');
        set('input-child-policy-1', 'free_0_12');
        set('input-child-discount', '%50 İndirimli');
        set('input-commission-percent', '15.00');
        set('input-checkin', '14:00');
        set('input-checkout', '12:00');
        set('input-cancellation', 'Giriş tarihinden 48 saat öncesine kadar %100 kesintisiz iade hakkı.');
        set('input-seo-title', 'Bodrum Luxury Resort & Spa | 5 Yıldızlı Ultra Her Şey Dahil Otel');
        set('input-seo-slug', 'bodrum-luxury-resort-spa-ultra-all-inclusive');
        set('input-seo-desc', 'Bodrum Torba mevkiinde denize sıfır, özel plajlı, spa ve aquapark olanaklarına sahip 5 yıldızlı ultra her şey dahil resort otel.');
        set('input-description', 'Bodrum Torba sahilinde denize sıfır konumda yer alan Bodrum Luxury Resort & Spa, 5 yıldızlı konforu ve Ultra Her Şey Dahil konseptiyle unutulmaz bir tatil deneyimi sunar.');

        selectedAmenities = ['private_beach', 'open_pool', 'aquapark', 'heated_indoor_pool', 'spa_hamam', 'alacarte', 'kids_club', 'wifi', 'fitness', 'valet_parking'];
      } else {
        set('input-code', 'VIL-' + new Date().getFullYear() + '-' + Math.floor(100 + Math.random() * 900));
        set('input-title', 'Bodrum Yalıkavak Panoramik Deniz Manzaralı Lüks Balayı Villası');
        set('input-villa-concept', 'luxury_sea_view');
        set('input-locality', 'Yalıkavak, Bodrum, Muğla');
        set('input-guests', '8');
        set('input-bedrooms', '4');
        set('input-beds', '5');
        set('input-bathrooms', '4');
        set('input-pool-dimensions', '4x10m Derinlik 1.55m (Sonsuzluk Havuzu)');
        set('input-sheltered-pool', 'true');
        set('input-license-no', '48-8472');
        set('input-price-minor', '2500000');
        if (inputPriceDisplay) inputPriceDisplay.value = '25.000';
        set('input-currency', 'TRY');
        set('input-cleaning-fee', '2500');
        set('input-min-stay', '3');
        set('input-deposit-percent', '35.00');
        set('input-commission-percent', '15.00');
        set('input-cancellation', 'Giriş tarihinden 14 gün öncesine kadar %100 kesintisiz iade hakkı.');
        set('input-seo-title', 'Bodrum Yalıkavak Lüks Kiralık Havuzlu Villa | Acente');
        set('input-seo-slug', 'bodrum-yalikavak-luks-kiralik-havuzlu-villa');
        set('input-seo-desc', 'Bodrum Yalıkavak\'ta özel havuzlu, panoramik deniz manzaralı ve 4 yatak odalı lüks kiralık tatil villası.');
        set('input-description', 'Bodrum Yalıkavak koyuna hakim panoramik manzarası, özel sonsuzluk havuzu ve lüks iç mimarisiyle seçkin bir tatil mülküdür.');

        selectedAmenities = ['pool', 'sheltered', 'jacuzzi', 'sea_view', 'ac', 'wifi', 'bbq', 'parking'];
      }

      syncAmenities();
      updateLivePreview();
      markFormClean();
      showToast('📋 Örnek şablon başarıyla yüklendi! Alanları dilediğiniz gibi özelleştirebilirsiniz.', 'success');
    });
  }

  if (btnResetForm) {
    btnResetForm.addEventListener('click', function () {
      if (!confirm('Formdaki tüm alanları temizlemek istediğinizden emin misiniz?')) return;
      form.reset();
      selectedAmenities = [];
      images = [];
      syncAmenities();
      renderPhotos();
      if (inputPriceDisplay) inputPriceDisplay.value = '';
      if (inputPriceMinor) inputPriceMinor.value = '0';
      updateLivePreview();
      markFormClean();
      showToast('🗑️ Form sıfırlandı. Yeni ilanınızı manuel doldurabilirsiniz.', 'info');
    });
  }

  // --- Görünümü Sıfırla ---
  var btnResetView = document.getElementById('btn-reset-view');
  if (btnResetView) {
    btnResetView.addEventListener('click', function () {
      // Kayıtlı görünüm tercihlerini temizle (sunucu + localStorage)
      try {
        localStorage.removeItem(ACC_MODE_KEY);
        localStorage.removeItem(ACC_STATE_KEY);
      } catch (_) {}
      // Sunucuda da temizle
      try {
        var csrfToken = '';
        var cookies = document.cookie.split(';');
        for (var ci = 0; ci < cookies.length; ci++) {
          var c = cookies[ci].trim();
          if (c.indexOf('nexus_csrf=') === 0) { csrfToken = c.substring(11); break; }
        }
        var body = 'csrf=' + encodeURIComponent(csrfToken) + '&prefs=' + encodeURIComponent(JSON.stringify({ mode: 'stepper', accordion_open: [] }));
        fetch('/admin/preferences/wizard', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: body,
          credentials: 'same-origin',
        }).catch(function () {});
      } catch (_) {}
      showToast('🔄 Görünüm sıfırlandı — sayfa yeniden yükleniyor…', 'info');
      setTimeout(function () { window.location.reload(); }, 600);
    });
  }

  // --- AI Title Assistant ---
  if (btnAiTitle) {
    btnAiTitle.addEventListener('click', function () {
      var t = document.getElementById('input-title');
      if (!t) return;
      var cur = t.value.trim() || (isHotel ? 'Bodrum Luxury Resort' : 'Bodrum Lüks Villa');
      var loc = document.getElementById('input-locality')?.value || 'Bodrum';

      if (isHotel) {
        t.value = cur.split(' (')[0] + ' (Ultra Her Şey Dahil · Özel Kum Plajlı & Aquapark)';
      } else if (currentCat === 'yacht') {
        t.value = cur.split(' (')[0] + ' (Lüks Gulet · Kaptanlı & Klimalı Mavi Yolculuk)';
      } else if (currentCat === 'tour') {
        t.value = cur.split(' (')[0] + ' (Rehberli VIP Tur · Transfer & Öğle Yemeği Dahil)';
      } else if (currentCat === 'car') {
        t.value = cur.split(' (')[0] + ' (Otomatik Vites · Tam Kaskolu & Sınırsız Km)';
      } else {
        t.value = cur.split(' (')[0] + ' (Özel Sonsuzluk Havuzlu · %100 Korunaklı Balayı Villası)';
      }
      t.dispatchEvent(new Event('input', { bubbles: true }));
      showToast('✨ AI Başlık önerisi uygulandı!', 'success');
    });
  }

  // --- AI Description Assistant (Real LLM Integration) ---
  if (btnAiDesc) {
    btnAiDesc.addEventListener('click', function () {
      var d = document.getElementById('input-description');
      var t = (document.getElementById('input-title')?.value || '').trim() || (isHotel ? 'Lüks Resort Hotel' : 'Özel Villa');
      var loc = document.getElementById('input-locality')?.value || 'Bodrum / Muğla';
      if (!d) return;

      btnAiDesc.disabled = true;
      var origText = btnAiDesc.textContent;
      btnAiDesc.textContent = '⏳ AI Üretiyor…';
      showToast('🤖 AI zengin tanıtım metnini üretiyor, lütfen bekleyin…', 'info');

      var attrSummary = 'Konum: ' + loc + ', Kategori: ' + currentCat + ', Seçili donanımlar: ' + selectedAmenities.join(', ');
      var fd = new FormData();
      fd.append('category', currentCat);
      fd.append('title', t);
      fd.append('attributes', attrSummary);
      fd.append('lang', 'tr');

      fetch('/api/ai/generate-content', {
        method: 'POST',
        headers: { 'Accept': 'application/json' },
        body: fd,
        credentials: 'same-origin'
      })
        .then(function (res) { return res.json(); })
        .then(function (json) {
          if (json.ok && json.html) {
            d.value = json.html;
            d.dispatchEvent(new Event('input', { bubbles: true }));
            showToast('✨ AI Tanıtım Açıklaması başarıyla üretildi ve uygulandı!', 'success');
          } else {
            throw new Error(json.error || 'AI yanıtı alınamadı');
          }
        })
        .catch(function (err) {
          console.warn('AI endpoint fallback:', err);
          if (isHotel) {
            d.value = '<h2>' + t + ' ile Ayrıcalıklı Bir Tatil</h2><p>' + loc + ' bölgesinin en seçkin sahil şeridinde yer alan tesisimiz, 5 yıldızlı konseptiyle misafirlerine lüks ve konforu bir arada sunmaktadır.</p><h3>Öne Çıkan Ayrıcalıklar</h3><ul><li>Mavi Bayraklı Özel Plaj ve Güneşlenme İskelesi</li><li>Açık / Kapalı Yüzme Havuzları ve Aquapark</li><li>Gurme Alakart Restoranlar & Zengin Açık Büfe</li><li>Geleneksel Türk Hamamı ve Spa & Wellness Merkezi</li></ul>';
          } else {
            d.value = '<h2>' + t + '</h2><p>' + loc + ' mevkiinde doğa ve deniz manzarasını buluşturan seçkin villamız, müstakil tatil ayrıcalığı sunar.</p><h3>Villa Donanım ve Özellikleri</h3><ul><li>Geniş güneşlenme terası ve özel yüzme havuzu</li><li>%100 korunaklı yapı ile tam mahremiyet</li><li>Lüks en-suite ebeveyn yatak odaları</li><li>Yüksek hızlı Wi-Fi ve barbekü alanı</li></ul>';
          }
          d.dispatchEvent(new Event('input', { bubbles: true }));
          showToast('✨ Tanıtım açıklaması güncellendi!', 'info');
        })
        .finally(function () {
          btnAiDesc.disabled = false;
          btnAiDesc.textContent = origText;
        });
    });
  }

  // --- AI SEO Assistant (Real LLM Integration) ---
  if (btnAiSeo) {
    btnAiSeo.addEventListener('click', function () {
      var t = (document.getElementById('input-title')?.value || '').trim() || (isHotel ? 'Bodrum Luxury Resort & Spa' : 'Bodrum Lüks Villa');
      var d = (document.getElementById('input-description')?.value || '').trim();
      var loc = document.getElementById('input-locality')?.value || 'Bodrum';

      btnAiSeo.disabled = true;
      var origText = btnAiSeo.textContent;
      btnAiSeo.textContent = '⏳ SEO Üretiliyor…';

      var fd = new FormData();
      fd.append('category', currentCat);
      fd.append('title', t);
      fd.append('description', d || loc);

      fetch('/api/ai/generate-seo', {
        method: 'POST',
        headers: { 'Accept': 'application/json' },
        body: fd,
        credentials: 'same-origin'
      })
        .then(function (res) { return res.json(); })
        .then(function (json) {
          if (json.ok) {
            if (inputSeoTitle && json.title) inputSeoTitle.value = json.title;
            if (inputSeoSlug) inputSeoSlug.value = slugify(t);
            if (inputSeoDesc && json.description) inputSeoDesc.value = json.description;
            updateLivePreview();
            showToast('✨ Google SERP ve SEO Meta Snippet başarıyla oluşturuldu!', 'success');
          } else {
            throw new Error(json.error || 'SEO üretilemedi');
          }
        })
        .catch(function () {
          var seoTitle = t + ' | En İyi Fiyat Garantisi';
          var seoSlug = slugify(t);
          var seoDesc = loc + ' bölgesinde unutulmaz bir tatil. En iyi fiyat garantisi, %100 güvenli rezervasyon ve acente güvencesiyle hemen yerinizi ayırtın.';
          if (inputSeoTitle) inputSeoTitle.value = seoTitle.slice(0, 68);
          if (inputSeoSlug) inputSeoSlug.value = seoSlug;
          if (inputSeoDesc) inputSeoDesc.value = seoDesc;
          updateLivePreview();
          showToast('✨ SEO Meta Snippet uygulandı!', 'info');
        })
        .finally(function () {
          btnAiSeo.disabled = false;
          btnAiSeo.textContent = origText;
        });
    });
  }

  // --- AI 6-Language Multi-Translation Suite ---
  var btnAiTranslate6 = document.getElementById('btn-ai-translate-6');
  var aiTranslationsCard = document.getElementById('ai-translations-card');
  var transContentPanel = document.getElementById('trans-content-panel');
  var btnCloseTransCard = document.getElementById('btn-close-trans-card');
  var transTabBtns = document.querySelectorAll('.trans-tab-btn');
  window._wizardTranslations = window._wizardTranslations || {};
  var activeTransLang = 'en';

  function renderTranslationPanel(lang) {
    if (!transContentPanel) return;
    var data = (window._wizardTranslations && window._wizardTranslations[lang]) || { title: '', description: '' };
    var langNames = { en: 'İngilizce (English)', de: 'Almanca (Deutsch)', ru: 'Rusça (Русский)', zh: 'Çince (中文)', fr: 'Fransızca (Français)' };

    transContentPanel.innerHTML =
      '<div class="trans-editor-grid">' +
        '<div class="trans-field-group">' +
          '<label class="trans-label">' + (langNames[lang] || lang) + ' Başlık:</label>' +
          '<input type="text" id="trans-input-title-' + lang + '" class="trans-input" value="' + escapeHtml(data.title || '') + '" placeholder="Çevrilmiş başlık...">' +
        '</div>' +
        '<div class="trans-field-group">' +
          '<label class="trans-label">' + (langNames[lang] || lang) + ' HTML Tanıtım Açıklaması:</label>' +
          '<textarea id="trans-input-desc-' + lang + '" class="trans-textarea" rows="4" placeholder="Çevrilmiş açıklama...">' + escapeHtml(data.description || '') + '</textarea>' +
        '</div>' +
      '</div>';

    var inTitle = document.getElementById('trans-input-title-' + lang);
    var inDesc = document.getElementById('trans-input-desc-' + lang);

    if (inTitle) {
      inTitle.addEventListener('input', function () {
        if (!window._wizardTranslations[lang]) window._wizardTranslations[lang] = {};
        window._wizardTranslations[lang].title = this.value;
      });
    }
    if (inDesc) {
      inDesc.addEventListener('input', function () {
        if (!window._wizardTranslations[lang]) window._wizardTranslations[lang] = {};
        window._wizardTranslations[lang].description = this.value;
      });
    }
  }

  if (transTabBtns && transTabBtns.length > 0) {
    transTabBtns.forEach(function (btn) {
      btn.addEventListener('click', function () {
        transTabBtns.forEach(function (b) { b.classList.remove('active'); });
        this.classList.add('active');
        activeTransLang = this.getAttribute('data-lang') || 'en';
        renderTranslationPanel(activeTransLang);
      });
    });
  }

  if (btnCloseTransCard) {
    btnCloseTransCard.addEventListener('click', function () {
      if (aiTranslationsCard) aiTranslationsCard.classList.add('hidden');
    });
  }

  if (btnAiTranslate6) {
    btnAiTranslate6.addEventListener('click', function () {
      var t = (document.getElementById('input-title')?.value || '').trim() || (isHotel ? 'Lüks Resort Otel' : 'Lüks Özel Villa');
      var d = (document.getElementById('input-description')?.value || '').trim();

      if (!d) {
        showToast('⚠️ Lütfen önce Türkçe tanıtım açıklamasını girin veya AI ile oluşturun.', 'warning');
        return;
      }

      btnAiTranslate6.disabled = true;
      var origText = btnAiTranslate6.textContent;
      btnAiTranslate6.textContent = '⏳ 6 Dile Çevriliyor…';
       showToast('🌍 AI başlık ve açıklamayı 6 dile yerelleştiriyor (EN, DE, RU, ZH, FR)…', 'info');

      var fd = new FormData();
      fd.append('title', t);
      fd.append('description', d);

      fetch('/api/ai/translate-all', {
        method: 'POST',
        headers: { 'Accept': 'application/json' },
        body: fd,
        credentials: 'same-origin'
      })
        .then(function (res) { return res.json(); })
        .then(function (json) {
          if (json.ok && json.translations) {
            window._wizardTranslations = json.translations;
            if (aiTranslationsCard) aiTranslationsCard.classList.remove('hidden');
            renderTranslationPanel(activeTransLang);
            showToast('✅ 6 dilde çeviriler başarıyla tamamlandı!', 'success');
          } else {
            throw new Error(json.error || 'Çeviri hatası');
          }
        })
        .catch(function (err) {
          console.warn('Translate endpoint fallback:', err);
          window._wizardTranslations = {
            en: { title: t, description: d },
            de: { title: t, description: d },
            ru: { title: t, description: d },
             zh: { title: t, description: d },
            fr: { title: t, description: d }
          };
          if (aiTranslationsCard) aiTranslationsCard.classList.remove('hidden');
          renderTranslationPanel(activeTransLang);
          showToast('🌍 6 Dil modülü hazırlandı, yerelleştirmeleri düzenleyebilirsiniz.', 'info');
        })
        .finally(function () {
          btnAiTranslate6.disabled = false;
          btnAiTranslate6.textContent = origText;
        });
    });
  }

  // --- Smart Form Validation & Submission ---
  function validateAndSubmit(statusTarget) {
    // Çift tetikleme kilidi: form.submit() sayfayı post ettiği için ikinci
    // çağrı (hızlı çift Ctrl+S vb.) ilk gönderimi bozar.
    if (validateAndSubmit._busy) return false;
    // 1. Check Code
    var codeInput = document.getElementById('input-code');
    if (!codeInput || !codeInput.value.trim()) {
      goToStep(1);
      if (formMode === 'full') {
        codeInput?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
      codeInput?.focus();
      codeInput?.classList.add('ai-highlight');
      showToast('⚠️ Lütfen Tesis / Hizmet Kodunu giriniz.', 'warning');
      return false;
    }

    // 2. Check Title
    var titleInput = document.getElementById('input-title');
    if (!titleInput || !titleInput.value.trim()) {
      goToStep(1);
      if (formMode === 'full') {
        titleInput?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
      titleInput?.focus();
      titleInput?.classList.add('ai-highlight');
      showToast('⚠️ Lütfen İlan Başlığını / Tesis Adını giriniz.', 'warning');
      return false;
    }

    // If publishing, check locality and price
    if (statusTarget === 'published') {
      var issues = publishReadinessIssues();
      if (issues.length) {
        var first = issues[0];
        focusReadinessIssue(first);
        updatePublishReadiness();
        showToast('⚠️ Yayına almadan önce eksikleri tamamlayın: ' + issues.map(function (issue) { return issue.label; }).slice(0, 4).join(', '), 'warning');
        return false;
      }

      var locInput = document.getElementById('input-locality');
      if (!locInput || !locInput.value.trim()) {
        goToStep(2);
        if (formMode === 'full') {
          locInput?.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
        locInput?.focus();
        locInput?.classList.add('ai-highlight');
        showToast('⚠️ Lütfen Konum / Lokasyon bilgisini giriniz.', 'warning');
        return false;
      }

      var priceVal = inputPriceMinor?.value || '0';
      if (!priceVal || priceVal === '0') {
        goToStep(6);
        if (formMode === 'full') {
          inputPriceDisplay?.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
        inputPriceDisplay?.focus();
        showToast('⚠️ Lütfen Gecelik Fiyat bilgisini giriniz.', 'warning');
        return false;
      }
    }

    // Set Status
    var statusSelect = document.getElementById('input-status');
    if (statusSelect) {
      statusSelect.value = statusTarget;
    }

    // Sync all hidden JSON inputs
    if (amenitiesInput) amenitiesInput.value = JSON.stringify(selectedAmenities);
    if (imagesInput) imagesInput.value = JSON.stringify(images);
    if (roomTypesInput) roomTypesInput.value = JSON.stringify(roomTypes);

    var extraMetaInput = document.getElementById('wizard-extra-metadata-input');
    if (extraMetaInput) {
      var extraData = {
        hotel_sections: hotelSections.filter(function (entry) { return entry.title.trim(); }),
        hotel_contract: hotelContract,
        hotel_house_rules: hotelHouseRules,
        damage_deposit: document.getElementById('input-damage-deposit')?.value || '',
        short_stay_fee: document.getElementById('input-short-stay-fee')?.value || '',
        short_stay_min_nights: document.getElementById('input-short-stay-nights')?.value || '',
        pool_heating_fee: document.getElementById('input-pool-heating-fee')?.value || '',
        pool_heating_status: document.getElementById('input-pool-heating-status')?.value || '',
        boat_type: document.getElementById('input-boat-type')?.value || '',
        cabin_count: document.getElementById('input-cabin-count')?.value || '',
        berth_count: document.getElementById('input-berth-count')?.value || '',
        crew_status: document.getElementById('input-crew-status')?.value || '',
        fuel_policy: document.getElementById('input-fuel-policy')?.value || '',
        boat_length: document.getElementById('input-boat-length')?.value || '',
        port_name: document.getElementById('input-port-name')?.value || '',
        boat_times: document.getElementById('input-boat-times')?.value || '',
        duration_hours: document.getElementById('input-duration-hours')?.value || '',
        difficulty_level: document.getElementById('input-difficulty-level')?.value || '',
        guide_languages: document.getElementById('input-guide-languages')?.value || '',
        meeting_point: document.getElementById('input-meeting-point')?.value || '',
        group_size: document.getElementById('input-group-size')?.value || '',
        vehicle_segment: document.getElementById('input-vehicle-segment')?.value || '',
        transmission: document.getElementById('input-transmission')?.value || '',
        fuel_type: document.getElementById('input-fuel-type')?.value || '',
        car_capacity: document.getElementById('input-car-capacity')?.value || '',
        car_deposit: document.getElementById('input-car-deposit')?.value || '',
        driver_requirement: document.getElementById('input-driver-req')?.value || '',
        translations: window._wizardTranslations || {}
      };
      extraMetaInput.value = JSON.stringify(syncContractFieldsToMetadata(extraData));
    }

    showToast(statusTarget === 'draft' ? '💾 Taslak kaydediliyor...' : '🚀 İlan yayınlanıyor...', 'info');

    // Submit natively — göndermeden önce dirty flag'ı temizle
    validateAndSubmit._busy = true;
    markFormClean();
    setTimeout(function () {
      form.submit();
    }, 400);

    return true;
  }

  if (btnQuickDraft) {
    btnQuickDraft.addEventListener('click', function (e) {
      e.preventDefault();
      validateAndSubmit('draft');
    });
  }

  // Intercept form submit event to avoid HTML5 un-focusable errors
  form.addEventListener('submit', function (e) {
    e.preventDefault();
    var currentStatus = document.getElementById('input-status')?.value || 'published';
    if (currentStatus === 'published') {
      confirmPublishModal();
    } else {
      validateAndSubmit(currentStatus);
    }
  });

  // --- AI Auto-Fill Engine (Collapsible Card) ---
  function runAiImport(queryUrl, queryText) {
    if (aiStatus) aiStatus.classList.remove('hidden');
    if (aiStatusText) {
      aiStatusText.textContent = isHotel
        ? 'Yapay Zeka otel oda tiplerini, konseptini ve tesis imkânlarını hazırlıyor...'
        : 'Yapay Zeka tatil evi kapasitesini, havuz niteliklerini ve fiyatını hazırlıyor...';
    }
    if (aiBtn) {
      aiBtn.disabled = true;
      aiBtn.classList.add('loading');
    }

    var catVal = categoryInput ? categoryInput.value : 'hotel';
    var body = new URLSearchParams();
    body.append('url', queryUrl || '');
    body.append('text', queryText || '');
    body.append('category', catVal);

    fetch('/admin/catalog/ai-import', {
      method: 'POST',
      body: body,
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    })
      .then(function (res) {
        if (!res.ok) throw new Error('AI analizi başarısız oldu');
        return res.json();
      })
      .then(function (data) {
        if (!data || !data.ok) throw new Error('Geçersiz veri');

        function setVal(id, val) {
          var el = document.getElementById(id);
          if (el && val !== undefined && val !== null) {
            el.value = val;
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.classList.add('ai-highlight');
            setTimeout(function () { el.classList.remove('ai-highlight'); }, 2500);
          }
        }

        setVal('input-code', data.code);
        setVal('input-title', data.title);
        setVal('input-locality', data.locality);
        setVal('input-price-minor', data.price_minor);
        if (inputPriceDisplay && data.price_minor) {
          inputPriceDisplay.value = formatDisplayFromMinor(data.price_minor);
        }
        setVal('input-currency', data.currency || 'TRY');
        setVal('input-status', data.status || 'published');
        setVal('input-description', data.description);
        setVal('input-cancellation', data.cancellation_policy);
        setVal('input-commission-percent', data.commission_percent);
        setVal('input-owner-name', data.owner_name);
        setVal('input-owner-phone', data.owner_phone);

        if (isHotel) {
          setVal('input-hotel-stars', data.hotel_stars || '5_star');
          setVal('input-board-type', data.board_type || 'uai');
          setVal('input-hotel-rooms', data.hotel_total_rooms || '180');
          setVal('input-hotel-beds', data.hotel_total_beds || '420');
          setVal('input-hotel-pools', data.hotel_pools_count || '3 Açık Havuz, 1 Aquapark, 1 Kapalı');
          setVal('input-beach-distance', data.beach_distance || 'zero');
          setVal('input-airport-dist', data.airport_distance || '32 km');
          setVal('input-pricing-model', data.pricing_model || 'per_room');
          setVal('input-child-policy-1', data.child_policy_1 || 'free_0_12');
          setVal('input-child-discount', data.child_policy_2_discount || '%50 İndirimli');
          setVal('input-checkin', data.check_in_time || '14:00');
          setVal('input-checkout', data.check_out_time || '12:00');

          if (Array.isArray(data.room_types) && data.room_types.length) {
            roomTypes = data.room_types;
            renderRoomTypes();
          }
        } else {
          setVal('input-guests', data.guests);
          setVal('input-bedrooms', data.bedrooms);
          setVal('input-beds', data.beds);
          setVal('input-bathrooms', data.bathrooms);
          setVal('input-pool-dimensions', data.pool_dimensions);
          setVal('input-sheltered-pool', data.sheltered_pool);
          setVal('input-cleaning-fee', data.cleaning_fee);
          setVal('input-min-stay', data.min_stay_days);
          setVal('input-deposit-percent', data.deposit_percent);
        }

        if (Array.isArray(data.amenities) && data.amenities.length) {
          selectedAmenities = data.amenities;
          syncAmenities();
        }

        if (Array.isArray(data.images) && data.images.length) {
          images = data.images;
          renderPhotos();
        }

        updateLivePreview();
        showToast('✓ Yapay zeka tüm alanları başarıyla doldurdu!', 'success');

        if (aiStatusText) {
          aiStatusText.textContent = isHotel
            ? '✓ Otel tesisi ve oda tipleri hazırlandı!'
            : '✓ Tatil evi ilanı hazırlandı!';
        }
        setTimeout(function () {
          if (aiStatus) aiStatus.classList.add('hidden');
        }, 3500);
      })
      .catch(function (err) {
        if (aiStatusText) aiStatusText.textContent = 'Hata: ' + err.message;
        showToast('AI analizi başarısız: ' + err.message, 'error');
      })
      .finally(function () {
        if (aiBtn) {
          aiBtn.disabled = false;
          aiBtn.classList.remove('loading');
        }
      });
  }

  if (aiBtn) {
    aiBtn.addEventListener('click', function () {
      var val = (aiInput?.value || '').trim();
      if (!val) {
        showToast(isHotel ? 'Lütfen bir link veya otel açıklaması girin.' : 'Lütfen bir link veya tatil evi açıklaması girin.', 'warning');
        return;
      }
      if (val.indexOf('http') === 0) {
        runAiImport(val, '');
      } else {
        runAiImport('', val);
      }
    });
  }

  sampleChips.forEach(function (chip) {
    chip.addEventListener('click', function () {
      var prompt = this.getAttribute('data-prompt');
      if (aiInput) aiInput.value = prompt;
      runAiImport('', prompt);
    });
  });

  // Initialize
  if (isHotel) {
    renderRoomTypes();
  }
  syncAmenities();
  loadManagedFilterSelects();
  loadContractFields();
  renderPhotos();
  goToStep(1);
  updateLivePreview();
  initCompletionBadges();
  schedulePublishReadinessUpdate();
  updateProgressBar();

  // İlk form durumunu snapshot olarak kaydet (dirty guard başlangıç noktası)
  suppressDirtyGuard = true;
  suppressDirtyGuard = false;
  formSnapshot = captureFormSnapshot();

  // Sayfa ayrılırken dirty uyarısı
  window.addEventListener('beforeunload', function (e) {
    if (!isFormDirty()) return;
    e.preventDefault();
    e.returnValue = '';
  });

  // Kayıtlı görünüm tercihini geri yükle: tam form modu + açık bölüm kombinasyonu.
  // setMode yerine setModeRestore kullanılır — toast ve stepper hariç, accordion
  // initAccordion(true) içindeki restore yoluyla açılır.
  (function restoreViewPreference() {
    // 1) Sunucu tercihinden dene
    var serverPrefs = getServerPrefs();
    var savedMode = serverPrefs && serverPrefs.mode ? serverPrefs.mode : null;
    // 2) localStorage fallback
    if (!savedMode) {
      try { savedMode = window.localStorage.getItem(ACC_MODE_KEY); } catch (_) {}
    }
    if (savedMode !== 'full') return; // stepper varsayılan — kayda gerek yok
    suppressModeToast = true;
    setMode('full');
    suppressModeToast = false;
    // Accordion restore, DOM'daki açık bölümü geri yüklüyor; currentStep'i de
    // en düşük numaralı açık bölümle senkronla — yoksa Ctrl+→/← ve quick-nav
    // eski stepper adımından devam edip yanlış bölüme atlar.
    var firstOpen = -1;
    stepPanels.forEach(function (p, i) {
      if (firstOpen === -1 && !p.classList.contains(ACCORDION_COLLAPSED)) firstOpen = i;
    });
    if (firstOpen >= 0) currentStep = firstOpen + 1;
  })();
})();
