(function () {
  'use strict';
  var copy = {
    tr: ['Nereye?', 'Şehir, bölge veya ilan ara', 'Popüler destinasyonlar', 'Temizle', 'Ara', 'Kapat', 'Tarih, kişi', 'Otel', 'Villa', 'Yat', 'Tur', 'Aktivite', 'Devamı', 'Tarih seçin', 'Kişi sayısı', 'Giriş', 'Çıkış', 'Yetişkin', 'Çocuk', 'Bebek', '13 yaş ve üzeri', '2–12 yaş', '0–2 yaş', 'Sesli arama', 'Dinleniyor…', 'Sesli arama bu tarayıcıda desteklenmiyor'],
    en: ['Where to?', 'Search city, area or listing', 'Popular destinations', 'Clear', 'Search', 'Close', 'Dates, guests', 'Hotel', 'Villa', 'Yacht', 'Tour', 'Activity', 'More', 'Select dates', 'Guests', 'Check in', 'Check out', 'Adults', 'Children', 'Infants', 'Age 13+', 'Ages 2–12', 'Ages 0–2', 'Voice search', 'Listening…', 'Voice search is not supported in this browser'],
    de: ['Wohin?', 'Stadt, Region oder Angebot suchen', 'Beliebte Reiseziele', 'Löschen', 'Suchen', 'Schließen', 'Datum, Gäste', 'Hotel', 'Villa', 'Yacht', 'Tour', 'Aktivität', 'Mehr', 'Datum wählen', 'Gäste', 'Anreise', 'Abreise', 'Erwachsene', 'Kinder', 'Kleinkinder', 'Ab 13 Jahren', '2–12 Jahre', '0–2 Jahre', 'Sprachsuche', 'Höre zu…', 'Sprachsuche wird in diesem Browser nicht unterstützt'],
    ru: ['Куда?', 'Поиск города, региона или предложения', 'Популярные направления', 'Очистить', 'Поиск', 'Закрыть', 'Даты, гости', 'Отель', 'Вилла', 'Яхта', 'Тур', 'Активность', 'Ещё', 'Выберите даты', 'Гости', 'Заезд', 'Выезд', 'Взрослые', 'Дети', 'Младенцы', 'От 13 лет', '2–12 лет', '0–2 года', 'Голосовой поиск', 'Слушаю…', 'Голосовой поиск не поддерживается этим браузером'],
    fr: ['Où aller ?', 'Rechercher une ville, une région ou une annonce', 'Destinations populaires', 'Effacer', 'Rechercher', 'Fermer', 'Dates, voyageurs', 'Hôtel', 'Villa', 'Yacht', 'Circuit', 'Activité', 'Plus', 'Choisir les dates', 'Voyageurs', 'Arrivée', 'Départ', 'Adultes', 'Enfants', 'Bébés', '13 ans et plus', '2–12 ans', '0–2 ans', 'Recherche vocale', 'Écoute…', 'La recherche vocale n’est pas prise en charge par ce navigateur'],
    zh: ['去哪里？', '搜索城市、地区或产品', '热门目的地', '清除', '搜索', '关闭', '日期、人数', '酒店', '别墅', '游艇', '旅游', '活动', '更多', '选择日期', '客人', '入住', '退房', '成人', '儿童', '婴儿', '13岁及以上', '2–12岁', '0–2岁', '语音搜索', '正在聆听…', '此浏览器不支持语音搜索']
  };
  var categories = [
    ['hotel', 'hgi-building-03', 7], ['holiday_home', 'hgi-home-01', 8],
    ['yacht', 'hgi-anchor-point', 9], ['tour', 'hgi-adventure', 10],
    ['activity', 'hgi-hot-air-balloon', 11], ['', 'hgi-menu-01', 12]
  ];
  var extraCategories = [
    ['flight', 'hgi-airplane-01', ['Uçuş', 'Flight', 'Flug', 'Авиарейсы', 'Vol', '航班']],
    ['car', 'hgi-car-01', ['Araç', 'Car', 'Auto', 'Авто', 'Voiture', '租车']],
    ['visa', 'hgi-passport', ['Vize', 'Visa', 'Visum', 'Виза', 'Visa', '签证']],
    ['ferry', 'hgi-ferry-boat', ['Feribot', 'Ferry', 'Fähre', 'Паром', 'Ferry', '渡轮']],
    ['transfer', 'hgi-bus-01', ['Transfer', 'Transfer', 'Transfer', 'Трансфер', 'Transfert', '接送']],
    ['beach', 'hgi-beach', ['Şezlong', 'Beach', 'Strand', 'Пляж', 'Plage', '海滩']],
    ['cinema', 'hgi-film-01', ['Sinema', 'Cinema', 'Kino', 'Кино', 'Cinéma', '影院']],
    ['event', 'hgi-calendar-03', ['Etkinlik', 'Event', 'Veranstaltung', 'Событие', 'Événement', '活动']],
    ['restaurant', 'hgi-restaurant-02', ['Restoran', 'Restaurant', 'Restaurant', 'Ресторан', 'Restaurant', '餐厅']],
    ['bus', 'hgi-bus-01', ['Otobüs', 'Bus', 'Bus', 'Автобус', 'Bus', '巴士']]
  ];
  var languages = ['tr', 'en', 'de', 'ru', 'fr', 'zh'];
  var moreExpanded = false;
  var places = ['Antalya', 'İstanbul', 'Bodrum, Muğla', 'Fethiye, Muğla', 'Kaş, Antalya'];
  var panel, input, list, currentCategory = '', selectedPlace = '', selectedListing = null, previousFocus, listings = [], blogPosts = [];
  var checkIn, checkOut, adults, children, infants, ages, recognition, compactMode = false;
  function lang() { var value = (window.NEXUS_LOCALE && window.NEXUS_LOCALE.lang) || document.documentElement.lang || 'tr'; return copy[value] ? value : 'tr'; }
  function t(index) { return copy[lang()][index]; }
  function icon(name) { return '<i class="hgi-stroke ' + name + '" aria-hidden="true"></i>'; }
  function setVoiceState(listening, message) {
    var button = panel.querySelector('.nx-search-mic');
    button.classList.toggle('is-listening', listening);
    button.setAttribute('aria-pressed', String(listening));
    button.setAttribute('aria-label', listening ? t(24) : t(23));
    button.title = listening ? t(24) : t(23);
    panel.querySelector('.nx-search-voice-status').textContent = message || '';
  }
  function startVoiceSearch() {
    if (recognition) { recognition.stop(); return; }
    var SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) { setVoiceState(false, t(25)); return; }
    var locales = { tr: 'tr-TR', en: 'en-US', de: 'de-DE', ru: 'ru-RU', fr: 'fr-FR', zh: 'zh-CN' };
    recognition = new SpeechRecognition();
    recognition.lang = locales[lang()] || 'tr-TR';
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;
    recognition.onstart = function () { setVoiceState(true, t(24)); };
    recognition.onresult = function (event) {
      var result = event.results && event.results[0] && event.results[0][0];
      if (!result || !result.transcript.trim()) return;
      input.value = result.transcript.trim();
      selectedPlace = ''; selectedListing = null;
      renderPlaces(); input.focus();
    };
    recognition.onend = function () { recognition = null; setVoiceState(false, ''); };
    recognition.onerror = function () { recognition = null; setVoiceState(false, ''); };
    try { recognition.start(); } catch (_) { recognition = null; setVoiceState(false, t(25)); }
  }
  function renderCategories() {
    var rail = panel.querySelector('.nx-search-categories');
    rail.replaceChildren();
    (moreExpanded ? categories.concat(extraCategories) : categories).forEach(function (entry) {
      var button = document.createElement('button');
      button.type = 'button'; button.className = 'nx-search-category';
      button.dataset.category = entry[0];
      button.setAttribute('aria-pressed', String(currentCategory === entry[0] && !!entry[0]));
      if (!entry[0]) button.setAttribute('aria-expanded', String(moreExpanded));
      button.innerHTML = '<span>' + icon(entry[1]) + '</span><small></small>';
      button.querySelector('small').textContent = typeof entry[2] === 'number' ? t(entry[2]) : entry[2][languages.indexOf(lang())];
      button.addEventListener('click', function () {
        if (!entry[0]) { moreExpanded = !moreExpanded; renderCategories(); return; }
        currentCategory = currentCategory === entry[0] ? '' : entry[0];
        renderCategories();
        updateGuestMode();
      });
      rail.appendChild(button);
    });
    rail.classList.toggle('is-expanded', moreExpanded);
  }
  function renderPlaces() {
    list.replaceChildren();
    var query = input.value.trim().toLocaleLowerCase(lang());
    if (compactMode && query.length < 3) return;
    var destinations = Array.from(new Set(listings.map(function (item) { return item.locality || ''; }).filter(Boolean)));
    (destinations.length ? destinations : places).filter(function (place) { return !query || place.toLocaleLowerCase(lang()).includes(query); }).slice(0, 8).forEach(function (place) {
      var button = document.createElement('button'); button.type = 'button'; button.className = 'nx-search-place';
      button.innerHTML = icon('hgi-location-01') + '<span><strong></strong><small></small></span>';
      button.querySelector('strong').textContent = place;
      button.querySelector('small').textContent = ({tr:'Bölge',en:'Destination',de:'Reiseziel',ru:'Направление',fr:'Destination',zh:'目的地'})[lang()];
      button.addEventListener('click', function () { input.value = place; selectedPlace = place; selectedListing = null; if (compactMode) { navigateCompact(); return; } renderPlaces(); checkIn.focus(); });
      list.appendChild(button);
    });
    if (query) listings.filter(function (item) { return ((item.title || '') + ' ' + (item.locality || '')).toLocaleLowerCase(lang()).includes(query); }).slice(0, 8).forEach(function (item) {
      var button = document.createElement('button'); button.type = 'button'; button.className = 'nx-search-place';
      button.innerHTML = icon('hgi-building-03') + '<span><strong></strong><small></small></span>';
      if (compactMode && item.images && item.images[0]) { var image = document.createElement('img'); image.src = item.images[0]; image.alt = ''; button.prepend(image); }
      button.querySelector('strong').textContent = item.title;
      button.querySelector('small').textContent = [item.categoryLabel || '', item.locality || ''].filter(Boolean).join(' · ');
      button.addEventListener('click', function () { input.value = item.title; selectedListing = item; selectedPlace = ''; currentCategory = item.category || ''; if (compactMode) { navigateCompact(); return; } renderCategories(); updateGuestMode(); renderPlaces(); checkIn.focus(); });
      list.appendChild(button);
    });
    if (compactMode && query) blogPosts.filter(function (post) { return ((post.title || '') + ' ' + (post.description || '')).toLocaleLowerCase(lang()).includes(query); }).slice(0, 5).forEach(function (post) {
      var button = document.createElement('button'); button.type = 'button'; button.className = 'nx-search-place';
      button.innerHTML = icon('hgi-news-01') + '<span><strong></strong><small></small></span>';
      button.querySelector('strong').textContent = post.title;
      button.querySelector('small').textContent = ({tr:'Blog',en:'Blog',de:'Blog',ru:'Блог',fr:'Blog',zh:'博客'})[lang()];
      button.addEventListener('click', function () { window.location.href = '/blog/' + encodeURIComponent(post.slug); });
      list.appendChild(button);
    });
  }
  function loadListings() {
    var params = new URLSearchParams();
    if (document.body.dataset.tenant) params.set('tenant', document.body.dataset.tenant);
    fetch('/api/public/listings?' + params, { credentials: 'same-origin' })
      .then(function (response) { return response.ok ? response.json() : []; })
      .then(function (items) { listings = Array.isArray(items) ? items : []; renderPlaces(); })
      .catch(function () { listings = []; });
  }
  function loadBlogPosts() {
    fetch('/blog/gezilesi-yerler', { credentials: 'same-origin' }).then(function (response) { return response.ok ? response.text() : ''; }).then(function (html) {
      var doc = new DOMParser().parseFromString(html, 'text/html');
      var source = doc.querySelector('.builder-region-places[data-posts]');
      blogPosts = source ? JSON.parse(source.getAttribute('data-posts') || '[]') : [];
      if (compactMode) renderPlaces();
    }).catch(function () { blogPosts = []; });
  }
  function renderAges() {
    if (currentCategory !== 'hotel') { ages.replaceChildren(); return; }
    var count = Math.max(0, Math.min(8, parseInt(children.value, 10) || 0));
    var previous = Array.from(ages.querySelectorAll('select')).map(function (select) { return select.value; });
    ages.replaceChildren();
    for (var index = 0; index < count; index++) {
      var label = document.createElement('label');
      label.textContent = (index + 1) + '. ' + t(18) + ' · ' + t(21);
      var select = document.createElement('select'); select.required = true;
      select.innerHTML = '<option value="">—</option>' + Array.from({ length: 11 }, function (_, offset) { var age = offset + 2; return '<option value="' + age + '">' + age + '</option>'; }).join('');
      if (previous[index]) select.value = previous[index];
      label.appendChild(select); ages.appendChild(label);
    }
  }
  function updateGuestMode() {
    if (!panel) return;
    panel.querySelector('.nx-trip-children').hidden = currentCategory !== 'hotel';
    panel.querySelector('.nx-trip-infants').hidden = currentCategory !== 'hotel';
    if (currentCategory !== 'hotel') { children.value = '0'; infants.value = '0'; updateCounters(); }
    renderAges();
  }
  function updateCounters() {
    panel.querySelectorAll('.nx-guest-row').forEach(function (row) {
      var field = row.querySelector('input');
      row.querySelector('.nx-guest-value').textContent = field.value;
      row.querySelector('[data-step="-1"]').disabled = Number(field.value) <= Number(field.min || 0);
      row.querySelector('[data-step="1"]').disabled = Number(field.value) >= Number(field.max || 30);
    });
    document.dispatchEvent(new CustomEvent('nexus:guests-changed'));
  }
  function open(compact) {
    if (!panel) return;
    compactMode = !!compact;
    panel.classList.toggle('is-compact', compactMode);
    input.value = '';
    selectedPlace = ''; selectedListing = null;
    translate();
    if (!currentCategory && window.NEXUS_NAV && window.NEXUS_NAV.pathCategory) currentCategory = window.NEXUS_NAV.pathCategory;
    if (extraCategories.some(function (entry) { return entry[0] === currentCategory; })) moreExpanded = true;
    previousFocus = document.activeElement;
    panel.hidden = false;
    document.documentElement.classList.add('nx-mobile-search-open');
    renderCategories(); updateGuestMode(); updateCounters(); renderPlaces(); loadListings();
    if (compactMode) loadBlogPosts();
    setTimeout(function () { input.focus(); }, 30);
  }
  function close() {
    if (recognition) recognition.stop();
    panel.hidden = true;
    compactMode = false;
    panel.classList.remove('is-compact');
    document.documentElement.classList.remove('nx-mobile-search-open');
    if (previousFocus && previousFocus.focus) previousFocus.focus();
  }
  function submit(event) {
    event.preventDefault();
    if (compactMode) { navigateCompact(); return; }
    var params = new URLSearchParams();
    var query = input.value.trim();
    if (!query) { input.focus(); return; }
    if (!checkIn.value || !checkOut.value || checkOut.value <= checkIn.value) {
      var dateTrigger = panel.querySelector('.nx-date-trigger');
      if (dateTrigger) { dateTrigger.click(); dateTrigger.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
      else checkIn.focus();
      return;
    }
    if (selectedListing && selectedListing.title === query) params.set('listing', selectedListing.id);
    else params.set(selectedPlace === query ? 'konum' : 'q', query);
    params.set('check_in', checkIn.value); params.set('check_out', checkOut.value);
    var dateFlex = panel.querySelector('[name="date_flex"]');
    if (dateFlex && dateFlex.value !== '0') params.set('date_flex', dateFlex.value);
    params.set('adults', String(parseInt(adults.value, 10) || 1));
    params.set('guests', String((parseInt(adults.value, 10) || 1) + (parseInt(children.value, 10) || 0)));
    if (parseInt(children.value, 10)) {
      params.set('children', children.value);
      params.set('child_ages', Array.from(ages.querySelectorAll('select')).map(function (select) { return select.value; }).join(','));
    }
    if (parseInt(infants.value, 10)) params.set('infants', infants.value);
    if (currentCategory) params.set('kategori', currentCategory);
    if (document.body.dataset.tenant) params.set('tenant', document.body.dataset.tenant);
    var path = selectedListing && selectedListing.title === query ? (window.NEXUS_LISTING_URL ? window.NEXUS_LISTING_URL(selectedListing) : '/urunler/' + encodeURIComponent(selectedListing.id)) : '/urunler';
    params.delete('listing');
    window.location.href = path + (params.toString() ? '?' + params : '');
  }
  function navigateCompact() {
    var query = input.value.trim();
    if (!query) { input.focus(); return; }
    var params = new URLSearchParams();
    if (document.body.dataset.tenant) params.set('tenant', document.body.dataset.tenant);
    var path = '/urunler';
    if (selectedListing && selectedListing.title === query) path += '/' + encodeURIComponent(selectedListing.id);
    else params.set(selectedPlace === query ? 'konum' : 'q', query);
    window.location.href = path + (params.toString() ? '?' + params : '');
  }
  function translate() {
    if (!panel) return;
    panel.querySelector('.nx-search-close').setAttribute('aria-label', t(5));
    panel.querySelector('.nx-search-title').textContent = t(0);
    input.placeholder = compactMode ? ({tr:'İlan adı, bölge veya blog ara',en:'Search listings, places or blog',de:'Angebote, Orte oder Blog suchen',ru:'Поиск объявлений, мест и блога',fr:'Rechercher annonces, lieux ou blog',zh:'搜索房源、地区或博客'})[lang()] : t(1);
    panel.querySelector('.nx-search-inline-submit').setAttribute('aria-label', t(4));
    var mic = panel.querySelector('.nx-search-mic');
    mic.setAttribute('aria-label', t(23)); mic.title = t(23);
    panel.querySelector('.nx-search-popular-title').textContent = t(2);
    panel.querySelector('.nx-search-clear').textContent = t(3);
    panel.querySelector('.nx-search-submit span').textContent = t(4);
    panel.querySelector('.nx-trip-date-title').textContent = t(13);
    panel.querySelector('.nx-trip-guest-title').textContent = t(14);
    panel.querySelector('.nx-trip-dates label:first-child span').textContent = t(15);
    panel.querySelector('.nx-trip-dates label:last-child span').textContent = t(16);
    panel.querySelector('.nx-trip-adults-label').textContent = t(17);
    panel.querySelector('.nx-trip-children-label').textContent = t(18);
    panel.querySelector('.nx-trip-infants-label').textContent = t(19);
    panel.querySelector('.nx-trip-adults-help').textContent = t(20);
    panel.querySelector('.nx-trip-children-help').textContent = t(21);
    panel.querySelector('.nx-trip-infants-help').textContent = t(22);
    renderCategories(); renderPlaces();
  }
  function init() {
    if (panel) return;
    panel = document.createElement('div'); panel.className = 'nx-mobile-search-panel'; panel.hidden = true;
    panel.setAttribute('role', 'dialog'); panel.setAttribute('aria-modal', 'true');
    panel.innerHTML = '<div class="nx-search-top"><button class="nx-search-close" type="button" aria-label="Kapat">×</button><div class="nx-search-categories"></div></div>' +
      '<form class="nx-search-form"><div class="nx-search-body"><h2 class="nx-search-title"></h2><div class="nx-search-compact-row"><div class="nx-search-input-wrap"><input type="search" autocomplete="off"><button type="submit" class="nx-search-inline-submit" aria-label="Ara">' + icon('hgi-search-01') + '</button><button type="button" class="nx-search-mic" aria-label="Sesli arama" aria-pressed="false">' + icon('hgi-mic-01') + '</button></div><button type="button" class="nx-search-compact-close" aria-label="Kapat">×</button></div><p class="nx-search-voice-status" role="status" aria-live="polite"></p><h3 class="nx-search-popular-title"></h3><div class="nx-search-places"></div>' +
      '<div class="nx-search-trip"><h3>2 · <span class="nx-trip-date-title">Tarih seçin</span></h3><div class="nx-trip-dates"><label><span>Giriş</span><input name="check_in" type="date" required></label><label><span>Çıkış</span><input name="check_out" type="date" required></label></div>' +
      '<h3>3 · <span class="nx-trip-guest-title">Kişi sayısı</span></h3><div class="nx-trip-guests">' +
      '<div class="nx-guest-row"><div><strong class="nx-trip-adults-label">Yetişkin</strong><small class="nx-trip-adults-help"></small></div><div class="nx-guest-controls"><button type="button" data-step="-1" aria-label="Yetişkin azalt">−</button><output class="nx-guest-value">2</output><button type="button" data-step="1" aria-label="Yetişkin artır">+</button><input name="adults" type="number" min="1" max="30" value="2" required hidden></div></div>' +
      '<div class="nx-guest-row nx-trip-children"><div><strong class="nx-trip-children-label">Çocuk</strong><small class="nx-trip-children-help"></small></div><div class="nx-guest-controls"><button type="button" data-step="-1" aria-label="Çocuk azalt">−</button><output class="nx-guest-value">0</output><button type="button" data-step="1" aria-label="Çocuk artır">+</button><input name="children" type="number" min="0" max="8" value="0" hidden></div></div>' +
      '<div class="nx-guest-row nx-trip-infants"><div><strong class="nx-trip-infants-label">Bebek</strong><small class="nx-trip-infants-help"></small></div><div class="nx-guest-controls"><button type="button" data-step="-1" aria-label="Bebek azalt">−</button><output class="nx-guest-value">0</output><button type="button" data-step="1" aria-label="Bebek artır">+</button><input name="infants" type="number" min="0" max="8" value="0" hidden></div></div></div><div class="nx-trip-ages"></div></div></div><div class="nx-search-actions"><button class="nx-search-clear" type="button"></button><button class="nx-search-submit" type="submit">' + icon('hgi-search-01') + '<span></span></button></div></form>';
    document.body.appendChild(panel);
    input = panel.querySelector('input'); list = panel.querySelector('.nx-search-places');
    checkIn = panel.querySelector('[name="check_in"]'); checkOut = panel.querySelector('[name="check_out"]');
    adults = panel.querySelector('[name="adults"]'); children = panel.querySelector('[name="children"]'); infants = panel.querySelector('[name="infants"]'); ages = panel.querySelector('.nx-trip-ages');
    panel.querySelectorAll('.nx-guest-controls button').forEach(function (button) {
      button.addEventListener('click', function () {
        var field = button.parentElement.querySelector('input');
        field.value = String(Math.max(Number(field.min || 0), Math.min(Number(field.max || 30), Number(field.value) + Number(button.dataset.step))));
        updateCounters(); if (field === children) renderAges();
      });
    });
    checkIn.min = new Date().toLocaleDateString('en-CA'); checkOut.min = checkIn.min;
    checkIn.addEventListener('change', function () { checkOut.min = checkIn.value; if (checkOut.value && checkOut.value <= checkIn.value) checkOut.value = ''; });
    children.addEventListener('change', renderAges);
    panel.querySelector('.nx-search-close').addEventListener('click', close);
    panel.querySelector('.nx-search-mic').addEventListener('click', startVoiceSearch);
    panel.querySelector('.nx-search-compact-close').addEventListener('click', close);
    panel.addEventListener('click', function (event) { if (compactMode && event.target === panel) close(); });
    panel.querySelector('.nx-search-clear').addEventListener('click', function () { input.value = ''; selectedPlace = ''; selectedListing = null; currentCategory = ''; checkIn.value = ''; checkOut.value = ''; var dateFlex = panel.querySelector('[name="date_flex"]'); if (dateFlex) { dateFlex.value = '0'; panel.querySelectorAll('.nx-date-flex-option').forEach(function (option) { option.setAttribute('aria-pressed', String(option.dataset.days === '0')); }); } adults.value = '2'; children.value = '0'; infants.value = '0'; updateGuestMode(); updateCounters(); renderCategories(); renderPlaces(); input.focus(); });
    panel.querySelector('form').addEventListener('submit', submit);
    input.addEventListener('input', function () { selectedPlace = ''; selectedListing = null; renderPlaces(); });
    document.addEventListener('keydown', function (event) { if (event.key === 'Escape' && !panel.hidden) close(); });
    document.addEventListener('click', function (event) {
      if (innerWidth > 1023) return;
      var footerSearch = event.target.closest('.bnav [data-act="search"]');
      if (!footerSearch && !event.target.closest('.nx-mobile-search')) return;
      event.preventDefault(); event.stopPropagation(); event.stopImmediatePropagation(); open(!!footerSearch);
    }, true);
    document.addEventListener('nexus:lang', translate);
    translate();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true }); else init();
})();
