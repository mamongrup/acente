(function () {
  'use strict';
  var translations = {
    tr: ['Müşteri hizmetleri', 'Size nasıl yardımcı olabiliriz?', 'Seyahat Asistanı', 'Canlı destek', 'WhatsApp', 'Kapat'],
    en: ['Customer service', 'How can we help you?', 'Travel Assistant', 'Live support', 'WhatsApp', 'Close'],
    de: ['Kundenservice', 'Wie können wir Ihnen helfen?', 'Reiseassistent', 'Live-Support', 'WhatsApp', 'Schließen'],
    ru: ['Служба поддержки', 'Как мы можем вам помочь?', 'Помощник в путешествии', 'Поддержка', 'WhatsApp', 'Закрыть'],
    fr: ['Service client', 'Comment pouvons-nous vous aider ?', 'Assistant voyage', 'Assistance', 'WhatsApp', 'Fermer'],
    zh: ['客户服务', '我们能如何帮助您？', '旅行助手', '在线支持', 'WhatsApp', '关闭']
  };
  var phone = '+905323977957';
  var sheet, backdrop, lastFocus, supportSettings = {}, tawkLoading = false;
  function normalizedPhone(value) {
    var digits = String(value || '').replace(/\D/g, '');
    return digits.length >= 10 && digits.length <= 15 ? digits : '';
  }
  function tawkUrl(value) {
    var match = String(value || '').match(/https:\/\/embed\.tawk\.to\/[a-zA-Z0-9]+\/[a-zA-Z0-9]+/);
    return match ? match[0] : '';
  }
  function applySettings() {
    if (!sheet) return;
    var call = sheet.querySelector('.nx-support-option[href^="tel:"]');
    var whatsapp = sheet.querySelector('.nx-support-option[href^="https://wa.me/"]');
    var callDigits = normalizedPhone(supportSettings.contact_phone) || normalizedPhone(phone);
    var whatsappDigits = normalizedPhone(supportSettings.whatsapp) || callDigits;
    call.href = 'tel:+' + callDigits;
    call.querySelector('span:nth-child(2)').textContent = supportSettings.contact_phone || phone;
    whatsapp.href = 'https://wa.me/' + whatsappDigits;
  }
  function loadSettings() {
    return fetch('/api/public/support-settings', { credentials: 'same-origin' })
      .then(function (response) { return response.ok ? response.json() : {}; })
      .then(function (data) { supportSettings = data || {}; applySettings(); })
      .catch(function () { applySettings(); });
  }
  function openLiveSupport(event) {
    var url = tawkUrl(supportSettings.tawk_embed_code);
    if (!url) return;
    event.preventDefault();
    close();
    window.Tawk_API = window.Tawk_API || {};
    if (typeof window.Tawk_API.toggle === 'function') { window.Tawk_API.toggle(); return; }
    if (tawkLoading) return;
    tawkLoading = true;
    window.Tawk_LoadStart = new Date();
    window.Tawk_API.onLoad = function () {
      if (typeof window.Tawk_API.showWidget === 'function') window.Tawk_API.showWidget();
      if (typeof window.Tawk_API.maximize === 'function') window.Tawk_API.maximize();
    };
    var script = document.createElement('script');
    script.async = true;
    script.src = url;
    script.onerror = function () { tawkLoading = false; window.location.href = '/iletisim?kanal=canli-destek'; };
    document.head.appendChild(script);
  }
  function copy() {
    var locale = (window.NEXUS_LOCALE && window.NEXUS_LOCALE.lang) || document.documentElement.lang || 'tr';
    return translations[locale] || translations.tr;
  }
  function icon(name) { return '<i class="hgi-stroke ' + name + '" aria-hidden="true"></i>'; }
  function create() {
    if (sheet) return;
    backdrop = document.createElement('div');
    backdrop.className = 'nx-support-backdrop';
    backdrop.addEventListener('click', close);
    sheet = document.createElement('section');
    sheet.className = 'nx-support-sheet';
    sheet.setAttribute('role', 'dialog');
    sheet.setAttribute('aria-modal', 'true');
    sheet.setAttribute('aria-labelledby', 'nx-support-title');
    sheet.innerHTML = '<span class="nx-support-handle" aria-hidden="true"></span>' +
      '<div class="nx-support-heading"><span class="nx-support-heading-icon">' + icon('hgi-headset') + '</span><div><strong id="nx-support-title"></strong><small class="nx-support-subtitle"></small></div></div>' +
      '<div class="nx-support-options">' +
      '<a class="nx-support-option" href="tel:+905323977957"><span class="nx-support-option-icon phone">' + icon('hgi-call-02') + '</span><span>' + phone + '</span>' + icon('hgi-arrow-right-01') + '</a>' +
      '<button type="button" class="nx-support-option" data-channel="assistant"><span class="nx-support-option-icon assistant">' + icon('hgi-magic-wand-01') + '</span><span class="nx-support-assistant-label"></span>' + icon('hgi-arrow-right-01') + '</button>' +
      '<a class="nx-support-option" href="/iletisim?kanal=canli-destek"><span class="nx-support-option-icon live">' + icon('hgi-message-02') + '</span><span class="nx-support-live-label"></span>' + icon('hgi-arrow-right-01') + '</a>' +
      '<a class="nx-support-option" href="https://wa.me/905323977957" target="_blank" rel="noopener noreferrer"><span class="nx-support-option-icon whatsapp">' + icon('hgi-whatsapp') + '</span><span class="nx-support-whatsapp-label"></span>' + icon('hgi-arrow-right-01') + '</a>' +
      '</div><button type="button" class="nx-support-close"></button>';
    sheet.querySelector('.nx-support-close').addEventListener('click', close);
    sheet.querySelector('[data-channel="assistant"]').addEventListener('click', function () {
      close();
      var chat = document.querySelector('#nexus-chat');
      if (typeof window.NEXUS_OPEN_TRAVEL_ASSISTANT === 'function') window.NEXUS_OPEN_TRAVEL_ASSISTANT();
    });
    sheet.querySelector('.nx-support-option[href^="/iletisim"]').addEventListener('click', openLiveSupport);
    document.body.appendChild(backdrop);
    document.body.appendChild(sheet);
  }
  function translate() {
    var labels = copy();
    sheet.querySelector('#nx-support-title').textContent = labels[0];
    sheet.querySelector('.nx-support-subtitle').textContent = labels[1];
    sheet.querySelector('.nx-support-assistant-label').textContent = labels[2];
    sheet.querySelector('.nx-support-live-label').textContent = labels[3];
    sheet.querySelector('.nx-support-whatsapp-label').textContent = labels[4];
    sheet.querySelector('.nx-support-close').textContent = labels[5];
  }
  function open() {
    create(); translate();
    loadSettings();
    lastFocus = document.activeElement;
    backdrop.classList.add('open'); sheet.classList.add('open');
    document.body.classList.add('nx-support-open');
    sheet.querySelector('.nx-support-option').focus();
  }
  function close() {
    if (!sheet) return;
    backdrop.classList.remove('open'); sheet.classList.remove('open');
    document.body.classList.remove('nx-support-open');
    if (lastFocus && lastFocus.focus) lastFocus.focus();
  }
  document.addEventListener('nexus:support-chooser', open);
  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape' && sheet && sheet.classList.contains('open')) close();
  });
  if (window.location.pathname === '/iletisim' && new URLSearchParams(window.location.search).get('kanal') === 'canli-destek') {
    var contactHeading = document.querySelector('main.contact-page h1');
    var contactEyebrow = document.querySelector('main.contact-page .eyebrow');
    var contactSubmit = document.querySelector('main.contact-page .inquiry-form button[type="submit"]');
    var contactNotice = document.querySelector('main.contact-page > .muted');
    if (contactHeading) contactHeading.textContent = 'Destek ekibine ulaşın';
    if (contactEyebrow) contactEyebrow.textContent = 'CANLI DESTEK TALEBİ';
    if (contactSubmit) contactSubmit.textContent = 'Destek talebi gönder';
    if (contactNotice) contactNotice.textContent = 'Mesajınızı bırakın; destek ekibimiz size geri dönüş yapsın.';
  }
})();
