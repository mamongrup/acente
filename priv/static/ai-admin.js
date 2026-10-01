// AI yanıtları ve sunucu hata mesajları asla innerHTML ile basılmaz (XSS);
// güvenli metin düğümleri için ortak yardımcı.
function setAiHtmlSafe(container, html) {
  container.replaceChildren();
  var template = document.createElement('template');
  template.innerHTML = html;
  container.appendChild(template.content);
}
function setAiText(container, text) {
  container.replaceChildren();
  container.textContent = text;
}
// AI tarafından üretilen HTML'i güvenli arındırıcıyla süzüp hedefe basar.
// script/iframe/style/nesne etiketleri, tüm on* olay öznitelikleri ve
// javascript: URL'leri kaldırılır; bağlantılar güvenli protokolle sınırlanır.
function sanitizeAiHtmlInto(target, rawHtml) {
  var template = document.createElement('template');
  template.innerHTML = String(rawHtml || '');
  var forbidden = { SCRIPT: 1, IFRAME: 1, OBJECT: 1, EMBED: 1, LINK: 1, META: 1, STYLE: 1, BASE: 1, FORM: 1 };
  var walk = function (root) {
    Array.prototype.slice.call(root.children).forEach(function (node) {
      if (forbidden[node.tagName]) { node.remove(); return; }
      Array.prototype.slice.call(node.attributes).forEach(function (attr) {
        var name = attr.name.toLowerCase();
        var value = String(attr.value || '').trim().toLowerCase();
        if (name.indexOf('on') === 0) { node.removeAttribute(attr.name); return; }
        if ((name === 'href' || name === 'src' || name === 'xlink:href') &&
            !/^(https?:|mailto:|tel:|\/|#)/i.test(attr.value.trim())) {
          node.removeAttribute(attr.name); return;
        }
        if (value.indexOf('javascript:') === 0 || value.indexOf('data:text/html') === 0) {
          node.removeAttribute(attr.name);
        }
      });
      walk(node);
    });
  };
  walk(template.content);
  target.replaceChildren(template.content);
}

(function () {
  var table = document.getElementById('ai-table-body');
  if (!table) return;

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }

  fetch('/admin/ai/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('AI sağlayıcıları yüklenemedi');
      return response.json();
    })
    .then(function (providers) {
      table.textContent = '';
      if (!providers.length) {
        var empty = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 4;
        message.className = 'empty-state';
        message.textContent = 'Henüz AI sağlayıcısı eklenmedi.';
        empty.appendChild(message);
        table.appendChild(empty);
        return;
      }
      providers.forEach(function (provider) {
        var row = document.createElement('tr');
        row.appendChild(cell(provider.provider));
        row.appendChild(cell(provider.model));
        row.appendChild(cell(provider.status));
        row.appendChild(cell(provider.configured === 'Evet' ? 'Kayıtlı' : 'Eksik'));
        table.appendChild(row);
      });
    })
    .catch(function (error) {
      table.textContent = '';
      var row = document.createElement('tr');
      var message = document.createElement('td');
      message.colSpan = 4;
      message.className = 'empty-state error';
      message.textContent = error.message;
      row.appendChild(message);
      table.appendChild(row);
    });

  var supervisorStatus = document.getElementById('ai-supervisor-status');
  function refreshSupervisorStatus() {
    if (!supervisorStatus) return;
    fetch('/admin/ai/supervisor/status', { credentials: 'same-origin', cache: 'no-store' })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (data) {
        if (!data) return;
        supervisorStatus.textContent = 'Durum: ' + data.status + ' · Bekleyen: ' + data.queued + ' · Başarısız: ' + data.failed + (data.checkedAt ? ' · Son kontrol: ' + data.checkedAt : '');
        supervisorStatus.className = 'ai-supervisor-status ' + (data.status === 'ok' ? 'is-ok' : 'is-degraded');
      }).catch(function () { supervisorStatus.textContent = 'AI Müdür durumu alınamadı.'; });
  }
  refreshSupervisorStatus();
  setInterval(refreshSupervisorStatus, 30000);
})();

(function () {
  var list = document.getElementById('ai-worker-health-list');
  if (!list) return;
  fetch('/admin/ai/workers', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('AI işçi durumları yüklenemedi');
      return response.json();
    })
    .then(function (workers) {
      list.textContent = '';
      if (!workers.length) {
        list.textContent = 'Henüz işçi sağlık kaydı yok.';
        return;
      }
      workers.forEach(function (worker) {
        var row = document.createElement('p');
        var reason = worker.details && worker.details.executor === 'not_configured'
          ? ' · yürütücü yapılandırılmamış' : '';
        var gates = worker.details && worker.details.preflightReasons;
        if (gates && Object.keys(gates).length) {
          reason += ' · ön kontrol: ' + Object.keys(gates).map(function (key) {
            return key + ' (' + gates[key] + ')';
          }).join(', ');
        }
        row.textContent = worker.worker_key + ' · ' + worker.status + ' · bekleyen: '
          + worker.queue_depth + reason;
        list.appendChild(row);
      });
    })
    .catch(function (error) { list.textContent = error.message; });
})();

(function () {
  var list = document.getElementById('ai-campaign-runs-list');
  if (!list) return;
  var labels = {
    scheduled: 'Zamanlandı', running: 'Gönderiliyor', paused: 'Müdahale gerekiyor',
    completed: 'SMTP tarafından kabul edildi', cancelled: 'İptal edildi', draft: 'Taslak'
  };
  var reasons = {
    ready: 'Hazır', run_not_found: 'Kayıt bulunamadı', not_due: 'Henüz zamanı gelmedi',
    channel_executor_unavailable: 'Bu kanalın gönderim işçisi yok', campaign_inactive: 'Kampanya etkin değil',
    audience_or_offer_missing: 'Alıcı veya mesaj eksik', invalid_audience_id: 'Alıcı kimliği geçersiz',
    audience_consent_missing: 'Alıcıların pazarlama izni eksik'
  };
  fetch('/admin/ai/campaign-runs', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (r) { if (!r.ok) throw new Error('Kampanya teslimatları yüklenemedi'); return r.json(); })
    .then(function (runs) {
      list.textContent = '';
      if (!runs.length) { list.textContent = 'Henüz AI kampanyası yok.'; return; }
      runs.forEach(function (run) {
        var row = document.createElement('p');
        var metrics = run.metrics || {};
        var parts = [run.campaign_name || 'Kampanya', labels[run.status] || run.status, run.channel];
        if (metrics.queued != null) parts.push('kuyruk: ' + metrics.queued);
        if (metrics.submitted != null) parts.push('SMTP kabul: ' + metrics.submitted);
        if (metrics.failed) parts.push('başarısız: ' + metrics.failed);
        if (metrics.cancelled) parts.push('iptal: ' + metrics.cancelled);
        if (run.preflight_reason && run.preflight_reason !== 'ready') {
          parts.push(reasons[run.preflight_reason] || run.preflight_reason);
        }
        row.textContent = parts.join(' · ');
        list.appendChild(row);
      });
    })
    .catch(function (error) { list.textContent = error.message; });
})();

(function () {
  var list = document.getElementById('ai-quality-cases-list');
  if (!list) return;
  var results = { pending: 'Bekliyor', passed: 'Geçti', failed: 'Başarısız' };
  var states = {
    output_missing: 'Model çıktısı kaydedilmemiş',
    unsupported_rules: 'Beklenen kurallar veya çıktı desteklenmiyor',
    evaluated: 'Değerlendirildi'
  };
  fetch('/admin/ai/quality-cases', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (r) { if (!r.ok) throw new Error('Kalite testleri yüklenemedi'); return r.json(); })
    .then(function (cases) {
      list.textContent = '';
      if (!cases.length) { list.textContent = 'Henüz kalite testi yok.'; return; }
      cases.forEach(function (item) {
        var row = document.createElement('p');
        row.textContent = [item.suite_key + ' / ' + item.name,
          results[item.last_result] || item.last_result,
          item.last_error || states[item.evaluation_state] || item.evaluation_state,
          'Kural: ' + JSON.stringify(item.expected || {})].join(' · ');
        list.appendChild(row);
        var form = document.createElement('form');
        form.method = 'post';
        form.action = '/admin/ai/quality-cases/output';
        var id = document.createElement('input');
        id.type = 'hidden'; id.name = 'case_id'; id.value = item.id;
        var label = document.createElement('label');
        label.textContent = 'Gerçek model çıktısı';
        var output = document.createElement('textarea');
        output.name = 'actual_text'; output.required = true; output.maxLength = 10000;
        output.rows = 2; output.placeholder = 'Test sırasında alınan gerçek yanıtı girin';
        label.appendChild(output);
        var button = document.createElement('button');
        button.type = 'submit'; button.textContent = 'Çıktıyı değerlendir';
        form.appendChild(id); form.appendChild(label); form.appendChild(button);
        list.appendChild(form);
      });
    })
    .catch(function (error) { list.textContent = error.message; });
})();

(function () {
  var list = document.getElementById('social-review-list');
  if (!list) return;

  function node(tag, text, className) {
    var element = document.createElement(tag);
    if (text != null) element.textContent = text;
    if (className) element.className = className;
    return element;
  }

  function actionForm(post, action, label, needsConfirmation) {
    var form = document.createElement('form');
    form.method = 'post';
    form.action = '/admin/social/posts/action';
    form.style.display = 'inline-flex';
    form.style.gap = '8px';
    form.style.alignItems = 'center';
    var id = document.createElement('input');
    id.type = 'hidden'; id.name = 'post_id'; id.value = post.id;
    form.appendChild(id);
    var act = document.createElement('input');
    act.type = 'hidden'; act.name = 'action'; act.value = action;
    form.appendChild(act);
    if (needsConfirmation) {
      var confirmLabel = node('label', 'Sosyal ağda yayınlanmadığını kontrol ettim');
      var checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.name = 'confirmed_not_published';
      checkbox.value = 'true';
      checkbox.required = true;
      confirmLabel.prepend(checkbox);
      form.appendChild(confirmLabel);
    }
    var button = node('button', label);
    button.type = 'submit';
    form.appendChild(button);
    return form;
  }

  fetch('/admin/social/posts', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('Gönderiler yüklenemedi');
      return response.json();
    })
    .then(function (posts) {
      list.textContent = '';
      if (!posts.length) {
        list.appendChild(node('p', 'Henüz sosyal gönderi yok.', 'muted'));
        return;
      }
      posts.forEach(function (post) {
        var card = node('article', null, 'glass-subcard');
        card.style.marginBottom = '12px';
        card.appendChild(node('strong', post.network + ' · ' + post.language_code + ' · ' + post.status));
        card.appendChild(node('p', post.content));
        if (post.external_post_id) card.appendChild(node('small', 'Gönderi kimliği: ' + post.external_post_id, 'muted'));
        if (post.error) card.appendChild(node('p', post.error, 'muted'));
        var actions = node('div');
        actions.style.display = 'flex';
        actions.style.flexWrap = 'wrap';
        actions.style.gap = '8px';
        if (post.status === 'queued' && !post.approved_at) {
          actions.appendChild(actionForm(post, 'approve', 'Onayla', false));
        }
        if (post.status === 'failed' && post.failure_code === 'delivery_unknown') {
          actions.appendChild(actionForm(post, 'retry', 'Yeniden kuyruğa al', true));
        }
        if (post.status === 'queued' || post.status === 'failed') {
          actions.appendChild(actionForm(post, 'cancel', 'İptal et', false));
        }
        card.appendChild(actions);
        list.appendChild(card);
      });
    })
    .catch(function (error) {
      list.textContent = error.message;
    });
})();

// ── AI Listing Fast-Fill ────────────────────────────────────────────────────
(function () {
  var btn = document.getElementById('btn-ai-fastfill');
  if (!btn) return;

  function getCsrf() {
    var m = document.querySelector('meta[name="csrf-token"]');
    if (m && m.content) return m.content;
    return (document.cookie.match(/(?:^|;\s*)(?:nexus_csrf|agency_csrf)=([^;]*)/) || ['', ''])[1];
  }

  btn.addEventListener('click', function () {
    var raw = document.getElementById('ai-fastfill-raw').value.trim();
    var cat = document.getElementById('ai-fastfill-category').value;
    var res = document.getElementById('ai-fastfill-result');
    if (!raw) {
      setAiText(res, 'Lütfen ilan metni/notlarını girin.');
      res.firstElementChild && (res.firstElementChild.style.color = 'var(--status-warn)');
      return;
    }
    btn.disabled = true;
    setAiText(res, '⏳ Yapay zeka alanları çıkarıyor…');
    var params = new URLSearchParams();
    params.append('csrf', getCsrf());
    params.append('csrf_token', getCsrf());
    params.append('category', cat);
    params.append('raw_text', raw);
    fetch('/admin/ai/extract-listing-fields', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
      credentials: 'same-origin'
    })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (d.ok && d.specs) {
        try {
          var obj = JSON.parse(d.specs);
          setAiHtmlSafe(res, '<pre style="font-size:11px;overflow:auto;background:rgba(0,0,0,0.35);padding:12px;border-radius:8px;color:var(--text-pure)"></pre>' +
            '<p style="font-size:12px;color:var(--status-ok)">✅ Alanlar başarıyla çıkarıldı. Kopyalayarak ilan formuna yapıştırabilirsiniz.</p>');
          res.querySelector('pre').textContent = JSON.stringify(obj, null, 2);
        } catch (e) {
          setAiHtmlSafe(res, '<pre style="font-size:11px;"></pre>');
          res.querySelector('pre').textContent = d.specs;
        }
      } else {
        setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
        res.querySelector('p').textContent = 'Hata: ' + (d.error || 'Çıkarma başarısız');
      }
    })
    .catch(function (e) {
      setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
      res.querySelector('p').textContent = e && e.message ? e.message : String(e);
    })
    .finally(function () { btn.disabled = false; });
  });
})();

// ── AI Blog Engine ──────────────────────────────────────────────────────────
(function () {
  var btn = document.getElementById('btn-ai-blog');
  if (!btn) return;

  function getCsrf() {
    var m = document.querySelector('meta[name="csrf-token"]');
    if (m && m.content) return m.content;
    return (document.cookie.match(/(?:^|;\s*)(?:nexus_csrf|agency_csrf)=([^;]*)/) || ['', ''])[1];
  }

  btn.addEventListener('click', function () {
    var dest = document.getElementById('ai-blog-destination').value.trim();
    var cat  = document.getElementById('ai-blog-category').value;
    var lang = document.getElementById('ai-blog-lang').value;
    var res  = document.getElementById('ai-blog-result');
    if (!dest) {
      setAiText(res, 'Lütfen bir destinasyon girin.');
      res.firstElementChild && (res.firstElementChild.style.color = 'var(--status-warn)');
      return;
    }
    btn.disabled = true;
    setAiText(res, '⏳ Yapay zeka gezi rehberi hazırlıyor…');
    var params = new URLSearchParams();
    params.append('csrf', getCsrf());
    params.append('csrf_token', getCsrf());
    params.append('destination', dest);
    params.append('category', cat);
    params.append('language_code', lang);
    fetch('/admin/ai/generate-blog', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
      credentials: 'same-origin'
    })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (d.ok && d.content) {
        var wrapper = document.createElement('div');
        wrapper.style.cssText = 'border:1px solid rgba(255,255,255,0.1);border-radius:10px;padding:16px;background:rgba(0,0,0,0.2);max-height:440px;overflow-y:auto;';
        // AI HTML çıktısı güvenli arındırıcıdan geçmeden innerHTML'e basılmaz.
        sanitizeAiHtmlInto(wrapper, d.content);
        var actions = document.createElement('div');
        actions.style.cssText = 'margin-top:10px;display:flex;gap:8px;';
        var copyBtn = document.createElement('button');
        copyBtn.type = 'button';
        copyBtn.className = 'secondary';
        copyBtn.textContent = '📋 HTML Kopyala';
        copyBtn.onclick = function () { navigator.clipboard.writeText(wrapper.innerHTML); };
        var cmsLink = document.createElement('a');
        cmsLink.href = '/admin/cms';
        cmsLink.className = 'secondary btn';
        cmsLink.target = '_blank';
        cmsLink.style.fontSize = '12px';
        cmsLink.textContent = "📝 CMS'e Git";
        actions.appendChild(copyBtn);
        actions.appendChild(cmsLink);
        res.textContent = '';
        res.appendChild(wrapper);
        res.appendChild(actions);
      } else {
        setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
        res.querySelector('p').textContent = 'Hata: ' + (d.error || 'Blog üretilemedi');
      }
    })
    .catch(function (e) {
      setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
      res.querySelector('p').textContent = e && e.message ? e.message : String(e);
    })
    .finally(function () { btn.disabled = false; });
  });
})();

// ── 1. AI Dynamic Pricing Optimizer ─────────────────────────────────────────
(function () {
  var btn = document.getElementById('btn-ai-pricing');
  if (!btn) return;

  function getCsrf() {
    var m = document.querySelector('meta[name="csrf-token"]');
    if (m && m.content) return m.content;
    return (document.cookie.match(/(?:^|;\s*)(?:nexus_csrf|agency_csrf)=([^;]*)/) || ['', ''])[1];
  }

  btn.addEventListener('click', function () {
    var loc = (document.getElementById('ai-pricing-locality') || {}).value || '';
    var cat = (document.getElementById('ai-pricing-category') || {}).value || 'holiday_home';
    var price = (document.getElementById('ai-pricing-price') || {}).value || '5000';
    var curr = (document.getElementById('ai-pricing-currency') || {}).value || 'TRY';
    var season = (document.getElementById('ai-pricing-season') || {}).value || 'medium';
    var occ = (document.getElementById('ai-pricing-occupancy') || {}).value || '60';
    var res = document.getElementById('ai-pricing-result');
    if (!res) return;

    btn.disabled = true;
    setAiText(res, '⏳ Dinamik fiyat stratejisi hesaplanıyor…');

    var params = new URLSearchParams();
    params.append('csrf', getCsrf());
    params.append('csrf_token', getCsrf());
    params.append('locality', loc.trim());
    params.append('category', cat);
    params.append('price', price);
    params.append('currency', curr);
    params.append('season', season);
    params.append('occupancy_rate', occ);

    fetch('/admin/ai/optimize-pricing', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
      credentials: 'same-origin'
    })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (d.ok && d.result) {
        var p = typeof d.result === 'string' ? JSON.parse(d.result) : d.result;
        var html = '<div style="border:1px solid rgba(255,255,255,0.1);border-radius:10px;padding:16px;background:rgba(0,0,0,0.25);margin-top:12px;">';
        html += '<h4 style="margin:0 0 10px 0;color:var(--neon-cyan, #22d3ee);">📊 Gelir Optimizasyonu & Fiyat Önerileri</h4>';
        html += '<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px;margin-bottom:12px;">';
        html += '<div style="background:rgba(255,255,255,0.05);padding:10px;border-radius:8px;text-align:center;"><small style="color:var(--text-muted)">Önerilen Taban</small><div data-slot="base-price" style="font-size:18px;font-weight:bold;color:#4ade80;"></div></div>';
        html += '<div style="background:rgba(255,255,255,0.05);padding:10px;border-radius:8px;text-align:center;"><small style="color:var(--text-muted)">Hafta Sonu</small><div data-slot="weekend-price" style="font-size:18px;font-weight:bold;color:#38bdf8;"></div></div>';
        html += '<div style="background:rgba(255,255,255,0.05);padding:10px;border-radius:8px;text-align:center;"><small style="color:var(--text-muted)">Yüksek Sezon / Bayram</small><div data-slot="high-season-price" style="font-size:18px;font-weight:bold;color:#fbbf24;"></div></div>';
        html += '<div style="background:rgba(255,255,255,0.05);padding:10px;border-radius:8px;text-align:center;"><small style="color:var(--text-muted)">Min. Gece Kuralı</small><div data-slot="min-stay" style="font-size:18px;font-weight:bold;color:#c084fc;"></div></div>';
        html += '</div>';
        if (p.occupancy_boost_action) {
          html += '<p data-slot="action" style="margin:6px 0;font-size:13px;color:#e2e8f0;"><strong>🎯 Aksiyon:</strong> <span data-value></span></p>';
        }
        if (p.strategy_summary) {
          html += '<p data-slot="summary" style="margin:6px 0;font-size:13px;color:var(--text-muted);"><span data-value></span></p>';
        }
        html += '</div>';
        setAiHtmlSafe(res, html);
        var fillSlot = function (slot, value) {
          var node = res.querySelector('[data-slot="' + slot + '"]');
          if (node) node.textContent = value;
        };
        fillSlot('base-price', (p.base_price_suggested || price) + ' ' + curr);
        fillSlot('weekend-price', (p.weekend_price_suggested || '-') + ' ' + curr);
        fillSlot('high-season-price', (p.high_season_price || '-') + ' ' + curr);
        fillSlot('min-stay', (p.min_stay_days || 3) + ' Gece');
        var actionSlot = res.querySelector('[data-slot="action"] [data-value]');
        if (actionSlot) actionSlot.textContent = p.occupancy_boost_action || '';
        var summarySlot = res.querySelector('[data-slot="summary"] [data-value]');
        if (summarySlot) summarySlot.textContent = p.strategy_summary || '';
      } else {
        setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
        res.querySelector('p').textContent = 'Hata: ' + (d.error || 'Fiyat analizi yapılamadı');
      }
    })
    .catch(function (e) {
      setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
      res.querySelector('p').textContent = e && e.message ? e.message : String(e);
    })
    .finally(function () { btn.disabled = false; });
  });
})();

// ── 2. AI Review Sentiment & Auto-Responder ─────────────────────────────────
(function () {
  var btn = document.getElementById('btn-ai-review');
  if (!btn) return;

  function getCsrf() {
    var m = document.querySelector('meta[name="csrf-token"]');
    if (m && m.content) return m.content;
    return (document.cookie.match(/(?:^|;\s*)(?:nexus_csrf|agency_csrf)=([^;]*)/) || ['', ''])[1];
  }

  btn.addEventListener('click', function () {
    var title = (document.getElementById('ai-review-listing') || {}).value || '';
    var rating = (document.getElementById('ai-review-rating') || {}).value || '5';
    var text = (document.getElementById('ai-review-text') || {}).value || '';
    var res = document.getElementById('ai-review-result');
    if (!res) return;

    if (!text.trim()) {
      setAiText(res, 'Lütfen analiz edilecek misafir yorumunu girin.');
      res.firstElementChild && (res.firstElementChild.style.color = 'var(--status-warn)');
      return;
    }

    btn.disabled = true;
    setAiText(res, '⏳ Misafir yorumu analiz ediliyor ve yanıt hazırlanıyor…');

    var params = new URLSearchParams();
    params.append('csrf', getCsrf());
    params.append('csrf_token', getCsrf());
    params.append('listing_title', title.trim());
    params.append('rating', rating);
    params.append('review_text', text.trim());

    fetch('/admin/ai/review-sentiment', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
      credentials: 'same-origin'
    })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (d.ok && d.result) {
        var p = typeof d.result === 'string' ? JSON.parse(d.result) : d.result;
        var sentColor = p.sentiment === 'positive' ? '#4ade80' : (p.sentiment === 'neutral' ? '#fbbf24' : '#f87171');
        var sentLabel = p.sentiment === 'positive' ? 'Pozitif Memnuniyet' : (p.sentiment === 'neutral' ? 'Dengeli / Nötr' : 'Geliştirilmeli / Şikayet');

        var html = '<div style="border:1px solid rgba(255,255,255,0.1);border-radius:10px;padding:16px;background:rgba(0,0,0,0.25);margin-top:12px;">';
        html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">';
        html += '<span data-slot="sentiment" style="display:inline-block;padding:4px 10px;border-radius:20px;font-size:12px;font-weight:bold;background:rgba(255,255,255,0.08);color:' + sentColor + ';"></span>';
        html += '</div>';

        html += '<div style="margin-bottom:10px;padding:12px;background:rgba(255,255,255,0.04);border-radius:8px;">';
        html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;"><strong style="font-size:13px;color:#38bdf8;">Standart Kurumsal Yanıt</strong><button type="button" class="secondary" style="font-size:11px;padding:2px 8px;" id="btn-copy-review-std">📋 Kopyala</button></div>';
        html += '<p id="ai-review-std-text" style="margin:0;font-size:13px;color:#e2e8f0;line-height:1.5;"></p>';
        html += '</div>';

        html += '<div style="padding:12px;background:rgba(255,255,255,0.04);border-radius:8px;">';
        html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;"><strong style="font-size:13px;color:#a78bfa;">Aksiyon & Telafi / Tekrar Davet Yanıtı</strong><button type="button" class="secondary" style="font-size:11px;padding:2px 8px;" id="btn-copy-review-act">📋 Kopyala</button></div>';
        html += '<p id="ai-review-act-text" style="margin:0;font-size:13px;color:#e2e8f0;line-height:1.5;"></p>';
        html += '</div>';
        // AI metinleri textContent ile basılıyor — innerHTML kullanılmıyor.

        html += '</div>';
        setAiHtmlSafe(res, html);
        var sentSlot = res.querySelector('[data-slot="sentiment"]');
        if (sentSlot) sentSlot.textContent = sentLabel + ' (Skor: ' + (p.score || 80) + '/100)';
        var stdText = document.getElementById('ai-review-std-text');
        if (stdText) stdText.textContent = p.suggested_reply_standard || '';
        var actText = document.getElementById('ai-review-act-text');
        if (actText) actText.textContent = p.suggested_reply_action_oriented || '';

        var b1 = document.getElementById('btn-copy-review-std');
        if (b1) b1.onclick = function () { navigator.clipboard.writeText((document.getElementById('ai-review-std-text') || {}).innerText || ''); b1.textContent = '✅ Kopyalandı'; };
        var b2 = document.getElementById('btn-copy-review-act');
        if (b2) b2.onclick = function () { navigator.clipboard.writeText((document.getElementById('ai-review-act-text') || {}).innerText || ''); b2.textContent = '✅ Kopyalandı'; };
      } else {
        setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
        res.querySelector('p').textContent = 'Hata: ' + (d.error || 'Yorum analizi yapılamadı');
      }
    })
    .catch(function (e) {
      setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
      res.querySelector('p').textContent = e && e.message ? e.message : String(e);
    })
    .finally(function () { btn.disabled = false; });
  });
})();

// ── 3. AI Cross-Sell & Itinerary Bundle Assistant ───────────────────────────
(function () {
  var btn = document.getElementById('btn-ai-bundle');
  if (!btn) return;

  function getCsrf() {
    var m = document.querySelector('meta[name="csrf-token"]');
    if (m && m.content) return m.content;
    return (document.cookie.match(/(?:^|;\s*)(?:nexus_csrf|agency_csrf)=([^;]*)/) || ['', ''])[1];
  }

  btn.addEventListener('click', function () {
    var loc = (document.getElementById('ai-bundle-locality') || {}).value || '';
    var cat = (document.getElementById('ai-bundle-category') || {}).value || 'holiday_home';
    var style = (document.getElementById('ai-bundle-style') || {}).value || 'Lüks & Konfor';
    var guests = (document.getElementById('ai-bundle-guests') || {}).value || '2';
    var res = document.getElementById('ai-bundle-result');
    if (!res) return;

    btn.disabled = true;
    setAiText(res, '⏳ Akıllı çapraz satış paketi oluşturuluyor…');

    var params = new URLSearchParams();
    params.append('csrf', getCsrf());
    params.append('csrf_token', getCsrf());
    params.append('locality', loc.trim());
    params.append('category', cat);
    params.append('travel_style', style);
    params.append('guest_count', guests);

    fetch('/admin/ai/bundle-cross-sell', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
      credentials: 'same-origin'
    })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (d.ok && d.result) {
        var p = typeof d.result === 'string' ? JSON.parse(d.result) : d.result;
        var html = '<div style="border:1px solid rgba(255,255,255,0.1);border-radius:10px;padding:16px;background:rgba(0,0,0,0.25);margin-top:12px;">';
        html += '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;">';
        html += '<h4 data-slot="bundle-title" style="margin:0;color:var(--neon-cyan, #22d3ee);"></h4>';
        html += '<span data-slot="bundle-discount" style="background:rgba(74,222,128,0.15);color:#4ade80;padding:2px 8px;border-radius:12px;font-size:12px;font-weight:bold;"></span>';
        html += '</div>';

        if (p.pitch_copy) {
          html += '<p data-slot="pitch" style="font-size:13px;color:#cbd5e1;margin-bottom:12px;font-style:italic;"></p>';
        }

        if (Array.isArray(p.items)) {
          html += '<div style="display:flex;flex-direction:column;gap:8px;margin-bottom:12px;">';
          p.items.forEach(function (item, itemIndex) {
            html += '<div style="display:flex;justify-content:space-between;align-items:center;background:rgba(255,255,255,0.04);padding:8px 12px;border-radius:6px;">';
            html += '<div><strong data-slot="item-title-' + itemIndex + '"></strong><br><small data-slot="item-reason-' + itemIndex + '" style="color:var(--text-muted)"></small></div>';
            if (item.estimated_price) {
              html += '<span data-slot="item-price-' + itemIndex + '" style="font-weight:bold;color:#38bdf8;"></span>';
            }
            html += '</div>';
          });
          html += '</div>';
        }

        html += '<div style="display:flex;gap:8px;"><button type="button" class="secondary" id="btn-copy-bundle-pitch">📋 Paket Teklif Metnini Kopyala</button></div>';
        html += '</div>';
        setAiHtmlSafe(res, html);
        var titleSlot = res.querySelector('[data-slot="bundle-title"]');
        if (titleSlot) titleSlot.textContent = p.bundle_title || 'Özel Seyahat Paketi';
        var discountSlot = res.querySelector('[data-slot="bundle-discount"]');
        if (discountSlot) discountSlot.textContent = '%' + (p.bundle_discount_percent || 10) + ' İndirimli Paket';
        var pitchSlot = res.querySelector('[data-slot="pitch"]');
        if (pitchSlot) pitchSlot.textContent = '"' + (p.pitch_copy || '') + '"';
        (p.items || []).forEach(function (item, itemIndex) {
          var t = res.querySelector('[data-slot="item-title-' + itemIndex + '"]');
          if (t) t.textContent = item.title || '';
          var r = res.querySelector('[data-slot="item-reason-' + itemIndex + '"]');
          if (r) r.textContent = item.reason || '';
          var pr = res.querySelector('[data-slot="item-price-' + itemIndex + '"]');
          if (pr) pr.textContent = item.estimated_price ? item.estimated_price + ' TL' : '';
        });

        var cp = document.getElementById('btn-copy-bundle-pitch');
        if (cp) cp.onclick = function () { navigator.clipboard.writeText(p.pitch_copy || ''); cp.textContent = '✅ Kopyalandı'; };
      } else {
        setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
        res.querySelector('p').textContent = 'Hata: ' + (d.error || 'Paket oluşturulamadı');
      }
    })
    .catch(function (e) {
      setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
      res.querySelector('p').textContent = e && e.message ? e.message : String(e);
    })
    .finally(function () { btn.disabled = false; });
  });
})();

// ── 4. AI Support & WhatsApp Co-Pilot ───────────────────────────────────────
(function () {
  var btn = document.getElementById('btn-ai-support');
  if (!btn) return;

  function getCsrf() {
    var m = document.querySelector('meta[name="csrf-token"]');
    if (m && m.content) return m.content;
    return (document.cookie.match(/(?:^|;\s*)(?:nexus_csrf|agency_csrf)=([^;]*)/) || ['', ''])[1];
  }

  btn.addEventListener('click', function () {
    var name = (document.getElementById('ai-support-name') || {}).value || '';
    var channel = (document.getElementById('ai-support-channel') || {}).value || 'whatsapp';
    var listing = (document.getElementById('ai-support-listing') || {}).value || '';
    var loc = (document.getElementById('ai-support-locality') || {}).value || '';
    var q = (document.getElementById('ai-support-question') || {}).value || '';
    var res = document.getElementById('ai-support-result');
    if (!res) return;

    if (!q.trim()) {
      setAiText(res, 'Lütfen misafirin sorusunu girin.');
      res.firstElementChild && (res.firstElementChild.style.color = 'var(--status-warn)');
      return;
    }

    btn.disabled = true;
    setAiText(res, '⏳ Destek yanıt taslağı hazırlanıyor…');

    var params = new URLSearchParams();
    params.append('csrf', getCsrf());
    params.append('csrf_token', getCsrf());
    params.append('customer_name', name.trim());
    params.append('channel', channel);
    params.append('listing_title', listing.trim());
    params.append('locality', loc.trim());
    params.append('question', q.trim());

    fetch('/admin/ai/support-copilot', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
      credentials: 'same-origin'
    })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      if (d.ok && d.result) {
        var p = typeof d.result === 'string' ? JSON.parse(d.result) : d.result;
        var replyText = p.reply_text || '';
        var html = '<div style="border:1px solid rgba(255,255,255,0.1);border-radius:10px;padding:16px;background:rgba(0,0,0,0.25);margin-top:12px;">';
        html += '<h4 style="margin:0 0 10px 0;color:var(--neon-cyan, #22d3ee);">💬 Hazırlanan Yanıt Taslağı (' + (channel === 'whatsapp' ? 'WhatsApp' : 'E-Posta') + ')</h4>';
        html += '<div id="ai-support-reply-content" style="white-space:pre-wrap;background:rgba(255,255,255,0.05);padding:14px;border-radius:8px;font-size:13px;line-height:1.6;color:#e2e8f0;margin-bottom:12px;"></div>';

        html += '<div style="display:flex;gap:8px;flex-wrap:wrap;">';
        html += '<button type="button" class="secondary" id="btn-copy-support-reply">📋 Yanıtı Kopyala</button>';
        if (channel === 'whatsapp') {
          var encodedText = encodeURIComponent(replyText);
          html += '<a href="https://web.whatsapp.com/send?text=' + encodedText + '" target="_blank" class="secondary btn" style="text-decoration:none;font-size:13px;">📲 WhatsApp Web\'de Aç</a>';
        }
        html += '</div>';
        html += '</div>';
        setAiHtmlSafe(res, html);
        var replySlot = document.getElementById('ai-support-reply-content');
        if (replySlot) replySlot.textContent = replyText;

        var cp = document.getElementById('btn-copy-support-reply');
        if (cp) cp.onclick = function () { navigator.clipboard.writeText(replyText); cp.textContent = '✅ Kopyalandı'; };
      } else {
        setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
        res.querySelector('p').textContent = 'Hata: ' + (d.error || 'Yanıt üretilemedi');
      }
    })
    .catch(function (e) {
      setAiHtmlSafe(res, '<p style="color:var(--status-error)"></p>');
      res.querySelector('p').textContent = e && e.message ? e.message : String(e);
    })
    .finally(function () { btn.disabled = false; });
  });
})();

