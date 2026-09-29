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
