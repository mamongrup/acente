// NEXUS Agency — Storefront Akıllı Seyahat Asistanı (AI Concierge Widget)
(function () {
  'use strict';

  function initConcierge() {
    if (document.getElementById('nexus-concierge-root')) return;

    var style = document.createElement('style');
    style.id = 'nexus-concierge-styles';
    style.textContent = [
      '#nexus-concierge-btn {',
      '  position: fixed;',
      '  bottom: 24px;',
      '  right: 24px;',
      '  z-index: 9990;',
      '  display: flex;',
      '  align-items: center;',
      '  gap: 8px;',
      '  background: var(--gradient-primary, linear-gradient(135deg, #0e7490, #0284c7));',
      '  color: var(--on-accent, #ffffff);',
      '  border: 1px solid rgba(255, 255, 255, 0.25);',
      '  padding: 11px 18px;',
      '  border-radius: 999px;',
      '  font-family: inherit;',
      '  font-size: 14px;',
      '  font-weight: 700;',
      '  cursor: pointer;',
      '  box-shadow: 0 8px 24px rgba(14, 116, 144, 0.4);',
      '  transition: transform 0.2s cubic-bezier(0.16, 1, 0.3, 1), box-shadow 0.2s ease;',
      '}',
      '#nexus-concierge-btn:hover {',
      '  transform: translateY(-2px) scale(1.02);',
      '  box-shadow: 0 12px 28px rgba(14, 116, 144, 0.55);',
      '}',
      '#nexus-concierge-btn .sparkle {',
      '  font-size: 16px;',
      '  animation: ai-pulse 2s infinite ease-in-out;',
      '}',
      '@keyframes ai-pulse {',
      '  0%, 100% { transform: scale(1); }',
      '  50% { transform: scale(1.2); }',
      '}',
      '#nexus-concierge-panel {',
      '  position: fixed;',
      '  bottom: 84px;',
      '  right: 24px;',
      '  width: 380px;',
      '  max-width: calc(100vw - 32px);',
      '  max-height: 540px;',
      '  background: rgba(15, 23, 42, 0.94);',
      '  backdrop-filter: blur(20px);',
      '  -webkit-backdrop-filter: blur(20px);',
      '  border: 1px solid rgba(255, 255, 255, 0.15);',
      '  border-radius: 20px;',
      '  box-shadow: 0 20px 48px rgba(0, 0, 0, 0.5);',
      '  z-index: 9991;',
      '  display: none;',
      '  flex-direction: column;',
      '  overflow: hidden;',
      '  font-family: inherit;',
      '  color: #f8fafc;',
      '  animation: slide-up 0.25s cubic-bezier(0.16, 1, 0.3, 1);',
      '}',
      '@keyframes slide-up {',
      '  from { opacity: 0; transform: translateY(12px) scale(0.98); }',
      '  to { opacity: 1; transform: translateY(0) scale(1); }',
      '}',
      '#nexus-concierge-panel.open { display: flex; }',
      '.concierge-header {',
      '  padding: 16px 18px;',
      '  background: linear-gradient(180deg, rgba(255,255,255,0.06), rgba(255,255,255,0));',
      '  border-bottom: 1px solid rgba(255, 255, 255, 0.08);',
      '  display: flex;',
      '  justify-content: space-between;',
      '  align-items: center;',
      '}',
      '.concierge-header h4 {',
      '  margin: 0;',
      '  font-size: 15px;',
      '  font-weight: 700;',
      '  display: flex;',
      '  align-items: center;',
      '  gap: 8px;',
      '}',
      '.concierge-close {',
      '  background: transparent;',
      '  border: none;',
      '  color: #94a3b8;',
      '  font-size: 18px;',
      '  cursor: pointer;',
      '  padding: 4px 8px;',
      '  border-radius: 6px;',
      '  transition: color 0.15s;',
      '}',
      '.concierge-close:hover { color: #ffffff; }',
      '.concierge-body {',
      '  padding: 16px;',
      '  overflow-y: auto;',
      '  flex: 1;',
      '  display: flex;',
      '  flex-direction: column;',
      '  gap: 12px;',
      '}',
      '.concierge-intro {',
      '  font-size: 13px;',
      '  color: #94a3b8;',
      '  line-height: 1.45;',
      '  margin: 0;',
      '}',
      '.concierge-chips {',
      '  display: flex;',
      '  flex-wrap: wrap;',
      '  gap: 6px;',
      '}',
      '.concierge-chip {',
      '  background: rgba(255, 255, 255, 0.08);',
      '  border: 1px solid rgba(255, 255, 255, 0.1);',
      '  border-radius: 999px;',
      '  padding: 5px 11px;',
      '  font-size: 12px;',
      '  color: #cbd5e1;',
      '  cursor: pointer;',
      '  transition: all 0.15s ease;',
      '}',
      '.concierge-chip:hover {',
      '  background: rgba(34, 211, 238, 0.2);',
      '  border-color: #22d3ee;',
      '  color: #ffffff;',
      '}',
      '.concierge-input-row {',
      '  display: flex;',
      '  gap: 8px;',
      '  margin-top: 4px;',
      '}',
      '.concierge-input {',
      '  flex: 1;',
      '  background: rgba(0, 0, 0, 0.35);',
      '  border: 1px solid rgba(255, 255, 255, 0.15);',
      '  border-radius: 10px;',
      '  padding: 10px 12px;',
      '  font-size: 13px;',
      '  color: #ffffff;',
      '  outline: none;',
      '}',
      '.concierge-input:focus {',
      '  border-color: #38bdf8;',
      '  box-shadow: 0 0 0 2px rgba(56, 189, 248, 0.2);',
      '}',
      '.concierge-submit {',
      '  background: #0284c7;',
      '  border: none;',
      '  color: #ffffff;',
      '  font-weight: 700;',
      '  font-size: 13px;',
      '  padding: 0 16px;',
      '  border-radius: 10px;',
      '  cursor: pointer;',
      '  transition: background 0.15s;',
      '}',
      '.concierge-submit:hover { background: #0369a1; }',
      '.concierge-results {',
      '  display: flex;',
      '  flex-direction: column;',
      '  gap: 10px;',
      '  margin-top: 8px;',
      '}',
      '.concierge-intent {',
      '  background: rgba(34, 211, 238, 0.1);',
      '  border: 1px solid rgba(34, 211, 238, 0.25);',
      '  border-radius: 8px;',
      '  padding: 8px 12px;',
      '  font-size: 12px;',
      '  color: #38bdf8;',
      '}',
      '.concierge-card {',
      '  display: flex;',
      '  gap: 10px;',
      '  background: rgba(255, 255, 255, 0.05);',
      '  border: 1px solid rgba(255, 255, 255, 0.08);',
      '  border-radius: 12px;',
      '  padding: 8px;',
      '  text-decoration: none;',
      '  color: inherit;',
      '  transition: all 0.15s ease;',
      '}',
      '.concierge-card:hover {',
      '  background: rgba(255, 255, 255, 0.1);',
      '  transform: translateY(-1px);',
      '}',
      '.concierge-card img {',
      '  width: 72px;',
      '  height: 60px;',
      '  object-fit: cover;',
      '  border-radius: 8px;',
      '}',
      '.concierge-card-info {',
      '  flex: 1;',
      '  display: flex;',
      '  flex-direction: column;',
      '  justify-content: center;',
      '  gap: 3px;',
      '}',
      '.concierge-card-title {',
      '  font-size: 13px;',
      '  font-weight: 700;',
      '  line-height: 1.25;',
      '  color: #f1f5f9;',
      '}',
      '.concierge-card-sub {',
      '  font-size: 11px;',
      '  color: #94a3b8;',
      '}',
      '@media (max-width: 600px) {',
      '  #nexus-concierge-btn span.label { display: none; }',
      '  #nexus-concierge-panel { bottom: 76px; right: 12px; width: calc(100vw - 24px); }',
      '}'
    ].join('\n');
    document.head.appendChild(style);

    var container = document.createElement('div');
    container.id = 'nexus-concierge-root';
    container.innerHTML = [
      '<button id="nexus-concierge-btn" type="button" aria-label="Akıllı Seyahat Asistanı">',
      '  <span class="sparkle">✨</span>',
      '  <span class="label">Seyahat Asistanı</span>',
      '</button>',
      '<div id="nexus-concierge-panel" role="dialog" aria-modal="true" aria-label="Seyahat Asistanı">',
      '  <div class="concierge-header">',
      '    <h4><span>✨</span> NEXUS Seyahat Asistanı</h4>',
      '    <button type="button" class="concierge-close" id="concierge-btn-close">✕</button>',
      '  </div>',
      '  <div class="concierge-body">',
      '    <p class="concierge-intro">Nasıl bir tatil planlıyorsunuz? Serbestçe yazın, yapay zeka en uygun seçenekleri anında listelesin.</p>',
      '    <div class="concierge-chips">',
      '      <span class="concierge-chip" data-q="Kaş havuzlu lüks villa">🌴 Kaş Villa</span>',
      '      <span class="concierge-chip" data-q="Fethiye gulet yat turu">⛵ Fethiye Yat</span>',
      '      <span class="concierge-chip" data-q="Bodrum butik otel tatili">🏨 Bodrum Otel</span>',
      '      <span class="concierge-chip" data-q="Antalya araç kiralama">🚙 Antalya Araç</span>',
      '    </div>',
      '    <div class="concierge-input-row">',
      '      <input type="text" class="concierge-input" id="concierge-input-text" placeholder="ör. Kaş\'ta balayı için manzaralı villa..." />',
      '      <button type="button" class="concierge-submit" id="concierge-btn-submit">Bul</button>',
      '    </div>',
      '    <div class="concierge-results" id="concierge-results-box"></div>',
      '  </div>',
      '</div>'
    ].join('');
    document.body.appendChild(container);

    var btn = document.getElementById('nexus-concierge-btn');
    var panel = document.getElementById('nexus-concierge-panel');
    var closeBtn = document.getElementById('concierge-btn-close');
    var input = document.getElementById('concierge-input-text');
    var submitBtn = document.getElementById('concierge-btn-submit');
    var resultsBox = document.getElementById('concierge-results-box');

    function togglePanel() {
      if (panel.classList.contains('open')) {
        panel.classList.remove('open');
      } else {
        panel.classList.add('open');
        input.focus();
      }
    }

    btn.addEventListener('click', togglePanel);
    closeBtn.addEventListener('click', function () { panel.classList.remove('open'); });

    function searchConcierge(text) {
      var q = text || (input ? input.value.trim() : '');
      if (!q) return;

      resultsBox.innerHTML = '<div style="text-align:center;padding:16px;color:#94a3b8;font-size:13px;">⏳ Yapay zeka en uygun alternatifleri eşleştiriyor…</div>';
      submitBtn.disabled = true;

      fetch('/api/public/concierge?q=' + encodeURIComponent(q), { credentials: 'same-origin' })
        .then(function (res) { return res.json(); })
        .then(function (data) {
          if (!data.ok) throw new Error(data.error || 'Arama yapılamadı');

          resultsBox.replaceChildren();
          if (data.parsed) {
            var intent = document.createElement('div');
            intent.className = 'concierge-intent';
            var intentTitle = document.createElement('strong');
            intentTitle.textContent = '🎯 AI Analizi: ';
            intent.appendChild(intentTitle);
            appendIntentText(intent, (data.parsed.locality ? data.parsed.locality + ' bölgesi · ' : '') +
              (data.parsed.category ? 'Kategori: ' + data.parsed.category : ''));
            if (data.parsed.summary) {
              intent.appendChild(document.createElement('br'));
              var small = document.createElement('small');
              small.style.color = '#cbd5e1';
              small.textContent = data.parsed.summary;
              intent.appendChild(small);
            }
            resultsBox.appendChild(intent);
          }

          if (data.listings && data.listings.length > 0) {
            var heading = document.createElement('div');
            heading.style.cssText = 'font-size:12px;font-weight:700;color:#94a3b8;margin-top:4px;';
            heading.textContent = 'Bulunan İlanlar (' + data.listings.length + '):';
            resultsBox.appendChild(heading);
            data.listings.forEach(function (item) {
              var img = safeImage((item.images && item.images[0] && item.images[0].url)) || '/static/placeholder.jpg';
              var price = item.priceMinor ? (parseInt(item.priceMinor, 10) / 100).toLocaleString('tr-TR') + ' ' + (item.currency || 'TRY') : '';
              var link = document.createElement('a');
              link.href = '/ilan/' + encodeURIComponent(item.id || '');
              link.className = 'concierge-card';
              var image = document.createElement('img');
              image.src = img;
              image.alt = '';
              image.onerror = function () { image.onerror = null; image.src = '/static/placeholder.jpg'; };
              var info = document.createElement('div');
              info.className = 'concierge-card-info';
              var title = document.createElement('span');
              title.className = 'concierge-card-title';
              title.textContent = item.title || 'İlan';
              var sub = document.createElement('span');
              sub.className = 'concierge-card-sub';
              sub.textContent = (item.locality || '') + ' · ' + (item.categoryLabel || item.category || '') + (price ? ' · ' : '');
              if (price) {
                var strong = document.createElement('strong');
                strong.textContent = price;
                sub.appendChild(strong);
              }
              info.append(title, sub);
              link.append(image, info);
              resultsBox.appendChild(link);
            });
          } else {
            var empty = document.createElement('div');
            empty.style.cssText = 'font-size:12.5px;color:#94a3b8;padding:8px 0;';
            empty.textContent = 'Bu kriterlere tam uyan anlık ilan bulunamadı. Genel vitrinimizi inceleyebilirsiniz.';
            resultsBox.appendChild(empty);
          }
        })
        .catch(function (err) {
          var error = document.createElement('div');
          error.style.cssText = 'color:#f87171;font-size:12px;padding:8px;';
          error.textContent = 'Hata: ' + (err && err.message ? err.message : 'Arama yapılamadı');
          resultsBox.replaceChildren(error);
        })
        .finally(function () {
          submitBtn.disabled = false;
        });
    }

    // AI çıktısı ve ilan verileri asla innerHTML ile basılmaz (XSS riski);
    // yalnızca textContent/element API kullanılır.
    function appendIntentText(parent, value) {
      parent.appendChild(document.createTextNode(value));
    }

    function safeImage(value) {
      var url = String(value || '').trim();
      return /^https?:\/\//i.test(url) || /^\/(?!\/)/.test(url) ? url : '';
    }

    submitBtn.addEventListener('click', function () { searchConcierge(); });
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') searchConcierge();
    });

    var chips = document.querySelectorAll('.concierge-chip');
    chips.forEach(function (chip) {
      chip.addEventListener('click', function () {
        var query = chip.getAttribute('data-q');
        if (input) input.value = query;
        searchConcierge(query);
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initConcierge);
  } else {
    initConcierge();
  }
})();
