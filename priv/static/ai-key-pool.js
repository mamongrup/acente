// NEXUS Agency — Gemini anahtar havuzu yönetimi
(function () {
  'use strict';

  var card = document.getElementById('ai-key-pool');
  if (!card) return;

  var statusBox = document.getElementById('ai-key-pool-status');
  var saveButton = document.getElementById('btn-save-ai-key-pool');
  var indexes = ['1','2','3','4','5','6','7','8','9','10'];

  function esc(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function setStatus(message, kind) {
    if (!statusBox) return;
    statusBox.className = 'ai-key-pool-status ' + (kind || '');
    statusBox.textContent = message;
  }

  function field(name) { return card.querySelector('[name="' + name + '"]'); }

  function fillRow(row) {
    var provider = row.provider || '';
    if (provider === 'google') {
      var index = String(row.priority || 0);
      if (indexes.indexOf(index) < 0) index = '1';
      var label = field('gemini_' + index + '_label');
      var model = field('gemini_' + index + '_model');
      var limit = field('gemini_' + index + '_limit');
      var active = field('gemini_' + index + '_active');
      if (label && row.label) label.value = row.label;
      if (model && row.model) model.value = row.model;
      if (limit) limit.value = String(row.dailyLimit || 0);
      if (active) active.value = row.active ? 'true' : 'false';
      var rowStatus = card.querySelector('[data-ai-status="' + index + '"]');
      if (rowStatus) rowStatus.textContent = row.configured ? ('Hazır · ' + (row.maskedKey || '••••')) : 'Anahtar eklenmedi';
      var key = field('gemini_' + index + '_key');
      if (key && row.maskedKey) key.placeholder = row.maskedKey + ' (değiştirmek için yeni anahtar)';
    } else if (provider === 'deepseek') {
      var dm = field('deepseek_model');
      var dl = field('deepseek_limit');
      var da = field('deepseek_active');
      if (dm && row.model) dm.value = row.model;
      if (dl) dl.value = String(row.dailyLimit || 0);
      if (da) da.value = row.active ? 'true' : 'false';
      var dk = field('deepseek_key');
      if (dk && row.maskedKey) dk.placeholder = row.maskedKey + ' (değiştirmek için yeni anahtar)';
      var ds = document.getElementById('deepseek-ai-status');
      if (ds) ds.textContent = row.configured ? ('Hazır · ' + (row.maskedKey || '••••')) : 'Anahtar eklenmedi';
    }
  }

  function renderUsage(rows) {
    if (!statusBox) return;
    if (!rows || !rows.length) {
      statusBox.textContent = 'Henüz anahtar eklenmedi. Gemini anahtarlarınızı yukarıdaki alanlardan kaydedin.';
      return;
    }
    var html = '<div class="ai-key-status-head"><strong>Günlük kullanım</strong><span>Son yenileme: ' + esc(new Date().toLocaleTimeString('tr-TR')) + '</span></div>';
    html += '<div class="ai-key-status-list">';
    rows.forEach(function (row) {
      var limit = Number(row.dailyLimit || 0);
      var used = Number(row.dailyUsed || 0);
      var quota = limit > 0 ? used + ' / ' + limit : used + ' / sınırsız';
      var state = !row.active ? 'Pasif' : row.cooldownUntil ? 'Beklemede' : row.configured ? 'Aktif' : 'Anahtar yok';
      html += '<div class="ai-key-status-item"><span><b>' + esc(row.provider === 'google' ? row.label : 'DeepSeek yedek') + '</b><small>' + esc(row.maskedKey || 'Anahtar yok') + '</small></span><span>' + esc(quota) + '</span><em class="status-pill-' + (state === 'Aktif' ? 'success' : state === 'Beklemede' ? 'warning' : 'neutral') + '">' + esc(state) + '</em></div>';
    });
    html += '</div>';
    statusBox.innerHTML = html;
  }

  function loadPool() {
    fetch('/admin/ai/key-pool/data', { credentials: 'same-origin', cache: 'no-store' })
      .then(function (res) { if (!res.ok) throw new Error('Havuz okunamadı'); return res.json(); })
      .then(function (data) {
        var rows = Array.isArray(data) ? data : (data && data.keys) || [];
        rows.forEach(fillRow);
        renderUsage(rows);
      })
      .catch(function (err) { setStatus(err.message, 'error'); });
  }

  if (saveButton) {
    saveButton.addEventListener('click', function () {
      saveButton.disabled = true;
      saveButton.textContent = '⏳ Kaydediliyor…';
      var fd = new FormData();
      indexes.forEach(function (index) {
        ['label','key','model','limit','active'].forEach(function (part) {
          var input = field('gemini_' + index + '_' + part);
          if (input) fd.append(input.name, input.value || '');
        });
      });
      ['deepseek_key','deepseek_model','deepseek_limit','deepseek_active'].forEach(function (name) {
        var input = field(name); if (input) fd.append(name, input.value || '');
      });
      fetch('/admin/ai/key-pool', { method: 'POST', body: fd, credentials: 'same-origin', headers: { 'Accept': 'application/json' } })
        .then(function (res) { return res.json().catch(function () { return {}; }).then(function (data) { if (!res.ok || data.ok === false) throw new Error(data.error || 'Havuz kaydedilemedi'); return data; }); })
        .then(function () { setStatus('Anahtar havuzu kaydedildi. Kota sayaçları hazır.', 'success'); loadPool(); })
        .catch(function (err) { setStatus(err.message, 'error'); })
        .finally(function () { saveButton.disabled = false; saveButton.textContent = '💾 Havuzu Kaydet'; });
    });
  }

  loadPool();
})();
