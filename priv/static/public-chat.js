(function () {
  'use strict';
  if (document.getElementById('nexus-chat')) return;

  var box = document.createElement('aside');
  box.id = 'nexus-chat';
  box.className = 'nexus-chat';
  box.innerHTML = '<button class="nexus-chat-toggle" aria-label="AI seyahat danışmanı">✦</button>' +
    '<div class="nexus-chat-panel" role="dialog" aria-label="Seyahat danışmanı"><strong>AI Seyahat Danışmanı</strong>' +
    '<p class="nexus-chat-status">Size uygun konaklama ve deneyimleri birlikte bulalım.</p>' +
    '<div class="nexus-chat-messages" aria-live="polite"></div>' +
    '<div class="nexus-chat-suggestions"><button type="button">Otel bul</button><button type="button">Transfer ve uçuş</button><button type="button">Bölge öner</button></div>' +
    '<label>Adınız<input class="nexus-chat-name" autocomplete="name" placeholder="Adınız" aria-label="Adınız"></label>' +
    '<label>E-posta veya telefon<input class="nexus-chat-contact" autocomplete="email" placeholder="E-posta veya telefon" aria-label="E-posta veya telefon"></label>' +
    '<label>Mesajınız<textarea class="nexus-chat-message" rows="2" placeholder="Nereye gitmek istiyorsunuz?" aria-label="Mesajınız"></textarea></label>' +
    '<button type="button" class="primary nexus-chat-submit">Mesaj gönder →</button></div>';
  document.body.appendChild(box);

  var toggle = box.querySelector('.nexus-chat-toggle');
  var status = box.querySelector('.nexus-chat-status');
  var submit = box.querySelector('.nexus-chat-submit');
  var nameInput = box.querySelector('.nexus-chat-name');
  var contactInput = box.querySelector('.nexus-chat-contact');
  var messageInput = box.querySelector('.nexus-chat-message');
  var messages = box.querySelector('.nexus-chat-messages');
  var selectedNeed = '';
  var conversationId = '';

  toggle.addEventListener('click', function () {
    box.classList.toggle('open');
    if (box.classList.contains('open')) nameInput.focus();
  });

  box.querySelectorAll('.nexus-chat-suggestions button').forEach(function (btn) {
    btn.addEventListener('click', function () {
      selectedNeed = btn.textContent;
      status.textContent = 'Harika seçim. ' + selectedNeed + ' için en uygun seçenekleri hazırlıyorum.';
      if (messageInput && !messageInput.value) messageInput.value = selectedNeed + ' hakkında seçenekleri gösterir misiniz?';
    });
  });

  function cookie(name) {
    var prefix = name + '=';
    var parts = document.cookie.split(';');
    for (var i = 0; i < parts.length; i++) {
      var part = parts[i].trim();
      if (part.indexOf(prefix) === 0) return decodeURIComponent(part.slice(prefix.length));
    }
    return '';
  }

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return (meta && meta.content) || cookie('agency_csrf');
  }

  function currentListingId() {
    var match = window.location.pathname.match(/^\/urunler\/([^/]+)/);
    return match ? decodeURIComponent(match[1]) : '';
  }

  function addMessage(text, direction) {
    if (!messages || !text) return;
    var item = document.createElement('div');
    item.className = 'nexus-chat-message-item ' + (direction || 'outbound');
    item.textContent = text;
    messages.appendChild(item);
    messages.scrollTop = messages.scrollHeight;
  }

  submit.addEventListener('click', function () {
    var name = nameInput.value.trim();
    var contact = contactInput.value.trim();
    var message = messageInput.value.trim() || selectedNeed;
    if (name.length < 2 || message.length < 2) {
      status.textContent = 'Lütfen adınızı ve seyahat isteğinizi yazın.';
      return;
    }
    var fd = new FormData();
    fd.append('name', name);
    if (contact.indexOf('@') > 1) fd.append('email', contact);
    else fd.append('phone', contact);
    fd.append('message', message);
    fd.append('listing_id', currentListingId());
    var tenant = (document.body && document.body.dataset && document.body.dataset.tenant) || '';
    if (tenant) fd.append('tenant', tenant);
    fd.append('conversation_id', conversationId);
    fd.append('lang', document.documentElement.lang || 'tr');
    fd.append('csrf_token', csrfToken());

    addMessage(message, 'inbound');
    submit.disabled = true;
    submit.textContent = 'Gönderiliyor…';
    fetch('/api/public/chat', {
      method: 'POST',
      body: fd,
      credentials: 'same-origin',
      headers: { 'Accept': 'application/json' }
    }).then(function (response) {
      return response.text().then(function (body) {
        var payload = {};
        try { payload = JSON.parse(body); } catch (e) { payload = {}; }
        if (!response.ok || payload.ok === false) {
          throw new Error(payload.error || 'Talep gönderilemedi.');
        }
        conversationId = payload.conversationId || conversationId;
        addMessage(payload.reply || 'Talebinizi aldım. Size uygun seçenekleri hazırlıyorum.', 'outbound');
        status.textContent = payload.needsContact
          ? 'Size özel teklif için e-posta veya telefonunuzu paylaşabilirsiniz.'
          : 'Size uygun seçenekleri birlikte netleştirelim.';
        messageInput.value = '';
        submit.textContent = 'Mesaj gönder →';
        submit.disabled = false;
      });
    }).catch(function (error) {
      status.textContent = error.message || 'Talep gönderilemedi. Lütfen tekrar deneyin.';
      submit.textContent = 'Tekrar gönder →';
      submit.disabled = false;
    });
  });
})();
