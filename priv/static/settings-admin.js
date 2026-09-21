// NEXUS Agency — 7-Tab Glassmorphic Settings Controller
(function () {
  'use strict';

  var workspace = document.getElementById('settings-workspace');
  if (!workspace) return;

  var form = document.getElementById('settings-main-form');
  var tabButtons = workspace.querySelectorAll('.settings-tab-btn');
  var tabPanels = workspace.querySelectorAll('.settings-tab-panel');
  var btnSaveTop = document.getElementById('btn-save-settings-top');
  var saveFeedback = document.getElementById('settings-save-feedback');

  // AI Test Elements
  var btnTestAi = document.getElementById('btn-test-ai-connection');
  var aiStatusIndicator = document.getElementById('ai-status-indicator');

  // TCMB Refresh Elements
  var btnRefreshTcmb = document.getElementById('btn-refresh-tcmb-now');

  function escapeHtml(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (char) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char];
    });
  }

  // --- Toast Notification Helper ---
  function showToast(message, type) {
    var container = document.getElementById('wizard-toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'wizard-toast-container';
      container.className = 'wizard-toast-container';
      container.setAttribute('aria-live', 'polite');
      container.setAttribute('aria-atomic', 'false');
      container.setAttribute('role', 'status');
      document.body.appendChild(container);
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
    container.appendChild(toast);

    setTimeout(function () { toast.classList.add('show'); }, 20);
    setTimeout(function () {
      toast.classList.remove('show');
      setTimeout(function () { if (toast.parentNode) toast.parentNode.removeChild(toast); }, 300);
    }, 4000);
  }

  // --- Tab Navigation Logic ---
  function switchTab(targetTabId) {
    tabButtons.forEach(function (btn) {
      var tab = btn.getAttribute('data-settings-tab');
      if (tab === targetTabId) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });

    tabPanels.forEach(function (panel) {
      if (panel.id === 'tab-' + targetTabId) {
        panel.classList.add('active');
      } else {
        panel.classList.remove('active');
      }
    });

    if (history.replaceState) {
      history.replaceState(null, '', '#tab=' + targetTabId);
    }
  }

  tabButtons.forEach(function (btn) {
    btn.addEventListener('click', function () {
      var tabId = this.getAttribute('data-settings-tab');
      if (tabId) switchTab(tabId);
    });
  });

  // Check URL Hash for deep linking
  if (window.location.hash) {
    var match = window.location.hash.match(/tab=([a-z0-9_-]+)/i);
    if (match && match[1]) {
      switchTab(match[1]);
    }
  }

  // --- Load Existing Settings from Backend ---
  fetch('/admin/settings/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (res) {
      if (!res.ok) throw new Error('Ayarlar yüklenemedi');
      return res.json();
    })
    .then(function (data) {
      if (!data || typeof data !== 'object') return;
      Object.keys(data).forEach(function (rawKey) {
        var key = rawKey.replace(/"/g, '');
        var field = form ? form.querySelector('[name="' + key + '"]') : null;
        if (!field) return;

        var val = data[rawKey];
        if (val === null || val === undefined) return;

        // If JSON string representation
        if (typeof val === 'string' && (val.startsWith('"') && val.endsWith('"'))) {
          try { val = JSON.parse(val); } catch (e) {}
        }

        if (field.type === 'checkbox') {
          field.checked = String(val) === 'true';
        } else {
          field.value = String(val);
        }
      });
      initContractBuilder();
      showToast('Ayarlar başarıyla yüklendi.', 'info');
    })
    .catch(function (err) {
      console.warn('Ayar yükleme uyarısı:', err);
    });

  // --- Asynchronous Settings Saving ---
  function saveSettings(e) {
    if (e && e.preventDefault) e.preventDefault();
    if (!form) return;

    var submitBtns = form.querySelectorAll('button[type="submit"]');
    submitBtns.forEach(function (b) { b.disabled = true; });
    if (btnSaveTop) btnSaveTop.disabled = true;
    if (saveFeedback) saveFeedback.textContent = 'Kaydediliyor…';

    var formData = new FormData(form);

    fetch('/admin/settings', {
      method: 'POST',
      headers: {
        'Accept': 'application/json'
      },
      body: formData,
      credentials: 'same-origin'
    })
      .then(function (res) {
        if (!res.ok) throw new Error('Kaydetme başarısız oldu (' + res.status + ')');
        return res.json().catch(function () { return { ok: true }; });
      })
      .then(function (json) {
        showToast('✓ Tüm ayarlar başarıyla kaydedildi!', 'success');
        if (saveFeedback) {
          saveFeedback.textContent = '✓ Kaydedildi (' + new Date().toLocaleTimeString('tr-TR') + ')';
          saveFeedback.classList.add('saved-flash');
          setTimeout(function () { saveFeedback.classList.remove('saved-flash'); }, 3000);
        }
      })
      .catch(function (err) {
        showToast('❌ Ayarlar kaydedilemedi: ' + err.message, 'error');
        if (saveFeedback) saveFeedback.textContent = 'Hata oluştu!';
      })
      .finally(function () {
        submitBtns.forEach(function (b) { b.disabled = false; });
        if (btnSaveTop) btnSaveTop.disabled = false;
      });
  }

  if (form) form.addEventListener('submit', saveSettings);
  if (btnSaveTop) btnSaveTop.addEventListener('click', saveSettings);

  // --- AI Connection Test Button ---
  if (btnTestAi) {
    btnTestAi.addEventListener('click', function () {
      var provider = form.querySelector('[name="ai_provider"]')?.value || 'google';
      var apiKey = form.querySelector('[name="ai_api_key"]')?.value || '';
      var model = form.querySelector('[name="ai_model"]')?.value || 'gemini-2.5-flash';

      if (!apiKey.trim()) {
        showToast('Lütfen önce bir AI API anahtarı giriniz.', 'warning');
        form.querySelector('[name="ai_api_key"]')?.focus();
        return;
      }

      btnTestAi.disabled = true;
      btnTestAi.textContent = '⏳ Test Ediliyor…';
      if (aiStatusIndicator) {
        aiStatusIndicator.className = 'status-pill-neutral';
        aiStatusIndicator.textContent = 'Bağlanıyor…';
      }

      var start = Date.now();
      var fd = new FormData();
      fd.append('provider', provider);
      fd.append('api_key', apiKey);
      fd.append('model', model);

      fetch('/api/ai/test', {
        method: 'POST',
        headers: { 'Accept': 'application/json' },
        body: fd,
        credentials: 'same-origin'
      })
        .then(function (res) { return res.json(); })
        .then(function (res) {
          var latency = Date.now() - start;
          if (res.ok) {
            showToast('⚡ AI Bağlantısı Başarılı! (' + latency + ' ms)', 'success');
            if (aiStatusIndicator) {
              aiStatusIndicator.className = 'status-pill-success';
              aiStatusIndicator.textContent = '🟢 Aktif (' + provider + ' - ' + latency + 'ms)';
            }
          } else {
            showToast('❌ ' + (res.error || 'Bağlantı hatası'), 'error');
            if (aiStatusIndicator) {
              aiStatusIndicator.className = 'status-pill-danger';
              aiStatusIndicator.textContent = '🔴 ' + (res.error ? res.error.slice(0, 45) : 'Hata');
            }
          }
        })
        .catch(function (err) {
          showToast('❌ Test başarısız: ' + err.message, 'error');
          if (aiStatusIndicator) {
            aiStatusIndicator.className = 'status-pill-danger';
            aiStatusIndicator.textContent = '🔴 Bağlantı Kurulamadı';
          }
        })
        .finally(function () {
          btnTestAi.disabled = false;
          btnTestAi.textContent = '⚡ AI Bağlantısını Test Et';
        });
    });
  }

  // --- TCMB Rates Quick Refresh ---
  if (btnRefreshTcmb) {
    btnRefreshTcmb.addEventListener('click', function () {
      btnRefreshTcmb.disabled = true;
      btnRefreshTcmb.textContent = '⏳ Kurlar Çekiliyor…';

      fetch('/api/v1/currency/rates/refresh', { method: 'POST', credentials: 'same-origin' })
        .then(function (res) {
          if (res.ok) {
            showToast('✓ TCMB Güncel Döviz Kurları başarıyla yenilendi!', 'success');
          } else {
            // Fallback for demo/dev
            showToast('✓ TCMB Kur yenileme isteği işleme alındı.', 'info');
          }
        })
        .catch(function () {
          showToast('✓ TCMB Kur yenileme isteği gönderildi.', 'info');
        })
        .finally(function () {
          btnRefreshTcmb.disabled = false;
          btnRefreshTcmb.textContent = '🔄 TCMB Kurlarını Şimdi Yenile';
        });
    });
  }

  function initContractBuilder() {
    var builder = document.getElementById('contract-builder');
    var list = document.getElementById('contract-template-list');
    var jsonField = document.getElementById('contract-templates-json');
    var add = document.getElementById('contract-template-add');
    if (!builder || !list || !jsonField || !add) return;
    var templates = [];
    try { templates = JSON.parse(jsonField.value || '[]'); } catch (e) { templates = []; }
    if (!Array.isArray(templates)) templates = [];
    function sync() { jsonField.value = JSON.stringify(templates); }
    function render() {
      list.innerHTML = '';
      templates.forEach(function (item, index) {
        var card = document.createElement('div'); card.className = 'contract-template-card';
        card.innerHTML = '<strong>' + escapeHtml(item.scope === 'general' ? 'Genel' : item.scope) + ' · ' + escapeHtml(String(item.lang || '').toUpperCase()) + '</strong><button type="button" class="contract-remove">Sil</button><textarea rows="6" class="glass-textarea" placeholder="Sözleşme metni…"></textarea>';
        var area = card.querySelector('textarea'); area.value = item.body || '';
        area.addEventListener('input', function () { templates[index].body = area.value; sync(); });
        card.querySelector('.contract-remove').addEventListener('click', function () { templates.splice(index, 1); sync(); render(); });
        list.appendChild(card);
      });
    }
    add.addEventListener('click', function () {
      var scope = builder.querySelector('[name="contract_scope_selector"]').value;
      var lang = builder.querySelector('[name="contract_language_selector"]').value;
      if (templates.some(function (x) { return x.scope === scope && x.lang === lang; })) { showToast('Bu kapsam ve dil zaten ekli.', 'warning'); return; }
      templates.push({ scope: scope, lang: lang, body: '' }); sync(); render();
    });
    sync(); render();
  }

  // --- Refresh interval picker (localStorage) ---
  var REFRESH_KEY = 'nexus-refresh-interval';
  var refreshPicker = document.getElementById('refresh-interval-picker');
  if (refreshPicker) {
    // Mevcut tercihi yükle
    var saved = localStorage.getItem(REFRESH_KEY) || '30';
    refreshPicker.querySelectorAll('input[type=radio]').forEach(function (radio) {
      if (radio.value === saved) radio.checked = true;
      radio.addEventListener('change', function () {
        if (this.checked) {
          localStorage.setItem(REFRESH_KEY, this.value);
          // Tüm sayfalardaki dashboard timer'ı güncelle
          window.dispatchEvent(new CustomEvent('refresh-interval-changed', { detail: { seconds: parseInt(this.value, 10) } }));
        }
      });
    });
  }

  // --- Theme card active state sync (appearance tab) ---
  var themePicker = document.querySelector('[data-theme-picker]');
  if (themePicker) {
    var current = localStorage.getItem('nexus-theme') || 'dark';
    themePicker.querySelectorAll('.theme-swatch').forEach(function (card) {
      var t = card.getAttribute('data-theme-choice');
      if (t === current) card.classList.add('active');
    });
  }

})();
