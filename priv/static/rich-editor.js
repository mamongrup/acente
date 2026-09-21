// NEXUS Agency — Ultra Modern Dark-Glass Rich Text Editor (WYSIWYG & Markdown)
(function () {
  'use strict';

  // AI output and source-mode HTML are rendered in an admin contenteditable
  // element. Keep the editor useful for semantic content while preventing
  // scripts, event handlers and javascript: URLs from executing.
  function sanitizeHtml(value) {
    var template = document.createElement('template');
    template.innerHTML = String(value == null ? '' : value);
    var allowed = { H2: true, H3: true, H4: true, P: true, UL: true, OL: true, LI: true, STRONG: true, EM: true, U: true, S: true, BR: true, BLOCKQUOTE: true, HR: true, A: true };
    Array.prototype.slice.call(template.content.querySelectorAll('*')).forEach(function (node) {
      if (!allowed[node.tagName]) {
        if (node.parentNode) node.parentNode.removeChild(node);
        return;
      }
      Array.prototype.slice.call(node.attributes).forEach(function (attribute) {
        var keep = node.tagName === 'A' && attribute.name.toLowerCase() === 'href';
        if (!keep || /^\s*javascript:/i.test(attribute.value)) node.removeAttribute(attribute.name);
      });
    });
    return template.innerHTML;
  }

  function escapeHtml(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (char) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char];
    });
  }

  function initRichEditors() {
    var textareas = document.querySelectorAll(
      'textarea.rich-textarea, textarea[name="description"]:not([name="seo_description"]), textarea[name="content"], #input-description, [data-rich-editor="true"]'
    );
    textareas.forEach(function (textarea) {
      if (textarea.dataset.richEditorInitialized === 'true') return;
      textarea.dataset.richEditorInitialized = 'true';
      setupEditor(textarea);
    });
  }

  function setupEditor(textarea) {
    // Hide original textarea but keep it in the DOM for form submission
    textarea.style.display = 'none';

    // Create editor container
    var wrapper = document.createElement('div');
    wrapper.className = 'rich-editor-container';

    // Create toolbar
    var toolbar = document.createElement('div');
    toolbar.className = 'rich-editor-toolbar';

    // Format buttons definitions
    var tools = [
      { cmd: 'bold', label: 'B', title: 'Kalın (Ctrl+B)', icon: '<strong>B</strong>' },
      { cmd: 'italic', label: 'I', title: 'İtalik (Ctrl+I)', icon: '<em>I</em>' },
      { cmd: 'underline', label: 'U', title: 'Altı Çizili (Ctrl+U)', icon: '<span style="text-decoration:underline">U</span>' },
      { cmd: 'strikeThrough', label: 'S', title: 'Üstü Çizili', icon: '<span style="text-decoration:line-through">S</span>' },
      { type: 'sep' },
      { cmd: 'formatBlock', arg: 'h2', label: 'H2', title: 'Büyük Başlık (H2)', icon: 'H2' },
      { cmd: 'formatBlock', arg: 'h3', label: 'H3', title: 'Alt Başlık (H3)', icon: 'H3' },
      { cmd: 'formatBlock', arg: 'p', label: 'P', title: 'Normal Paragraf', icon: '¶' },
      { type: 'sep' },
      { cmd: 'insertUnorderedList', label: '• List', title: 'Madde İmli Liste', icon: '•≡' },
      { cmd: 'insertOrderedList', label: '1. List', title: 'Numaralı Liste', icon: '1≡' },
      { cmd: 'formatBlock', arg: 'blockquote', label: 'Quote', title: 'Alıntı Kutusu', icon: '❝' },
      { cmd: 'insertHorizontalRule', label: 'HR', title: 'Ayırıcı Çizgi', icon: '―' },
      { type: 'sep' },
      { cmd: 'createLink', label: 'Link', title: 'Bağlantı Ekle', icon: '🔗' },
      { cmd: 'removeFormat', label: 'Clear', title: 'Biçimlendirmeyi Temizle', icon: '🧹' },
      { type: 'spacer' },
      {
        type: 'custom',
        id: 'ai-enhance',
        label: '✨ AI İle Zenginleştir',
        title: 'Yapay Zeka ile Tanıtım Metnini zenginleştir',
        className: 'rich-btn-ai'
      },
      {
        type: 'custom',
        id: 'toggle-source',
        label: '‹/› HTML',
        title: 'HTML Kaynak Kodu / Görsel Editör Geçişi',
        className: 'rich-btn-source'
      }
    ];

    tools.forEach(function (tool) {
      if (tool.type === 'sep') {
        var sep = document.createElement('span');
        sep.className = 'rich-toolbar-sep';
        toolbar.appendChild(sep);
      } else if (tool.type === 'spacer') {
        var spacer = document.createElement('span');
        spacer.className = 'rich-toolbar-spacer';
        toolbar.appendChild(spacer);
      } else if (tool.type === 'custom') {
        var customBtn = document.createElement('button');
        customBtn.type = 'button';
        customBtn.className = 'rich-tool-btn ' + (tool.className || '');
        customBtn.title = tool.title || tool.label;
        customBtn.innerHTML = tool.label;
        customBtn.dataset.customAction = tool.id;
        toolbar.appendChild(customBtn);
      } else {
        var btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'rich-tool-btn';
        btn.title = tool.title || tool.label;
        btn.innerHTML = tool.icon || tool.label;
        btn.dataset.cmd = tool.cmd;
        if (tool.arg) btn.dataset.arg = tool.arg;
        toolbar.appendChild(btn);
      }
    });

    // Content Editable Area
    var editorArea = document.createElement('div');
    editorArea.className = 'rich-editor-content';
    editorArea.contentEditable = 'true';
    editorArea.setAttribute('role', 'textbox');
    editorArea.setAttribute('aria-multiline', 'true');
    editorArea.setAttribute('spellcheck', 'true');

    // Initial content
    var initialVal = textarea.value || '';
    if (initialVal.trim().indexOf('<') !== -1) {
      editorArea.innerHTML = sanitizeHtml(initialVal);
    } else if (initialVal.trim()) {
      editorArea.innerHTML = '<p>' + escapeHtml(initialVal).replace(/\n\n/g, '</p><p>').replace(/\n/g, '<br>') + '</p>';
    } else {
      editorArea.innerHTML = '<p><br></p>';
    }

    // Source view textarea (hidden by default)
    var sourceArea = document.createElement('textarea');
    sourceArea.className = 'rich-editor-source hidden';
    sourceArea.spellcheck = false;

    // Footer with word / char count and status
    var footer = document.createElement('div');
    footer.className = 'rich-editor-footer';
    footer.innerHTML = `
      <div class="rich-status-left">
        <span class="rich-sync-indicator" title="Senkronize">● Kaydedildi</span>
        <span class="rich-stat-words">0 kelime</span>
        <span class="rich-stat-chars">0 karakter</span>
      </div>
      <div class="rich-status-right">
        <span class="rich-editor-badge">NEXUS RichText 2.0</span>
      </div>
    `;

    // Assemble DOM
    wrapper.appendChild(toolbar);
    wrapper.appendChild(editorArea);
    wrapper.appendChild(sourceArea);
    wrapper.appendChild(footer);
    textarea.parentNode.insertBefore(wrapper, textarea.nextSibling);

    // Sync helpers
    var isSourceMode = false;
    var wordStat = footer.querySelector('.rich-stat-words');
    var charStat = footer.querySelector('.rich-stat-chars');
    var syncIndicator = footer.querySelector('.rich-sync-indicator');

    function updateStats() {
      var text = editorArea.innerText || '';
      var trimmed = text.trim();
      var words = trimmed ? trimmed.split(/\s+/).length : 0;
      var chars = text.length;
      if (wordStat) wordStat.textContent = words + ' kelime';
      if (charStat) charStat.textContent = chars + ' karakter';
    }

    function syncToTextarea() {
      if (isSourceMode) {
        textarea.value = sourceArea.value;
      } else {
        var html = editorArea.innerHTML;
        // Clean empty tags
        if (html === '<p><br></p>' || html === '<p></p>') html = '';
        textarea.value = html;
      }
      updateStats();
      if (syncIndicator) {
        syncIndicator.classList.add('active');
        setTimeout(function () {
          syncIndicator.classList.remove('active');
        }, 600);
      }
      // Trigger native input event on original textarea
      var evt = new Event('input', { bubbles: true });
      textarea.dispatchEvent(evt);
    }

    // Sync from outside (e.g. AI auto-fill or programmatic changes)
    var observer = new MutationObserver(function () {
      if (document.activeElement !== editorArea && document.activeElement !== sourceArea) {
        loadFromTextarea();
      }
    });
    observer.observe(textarea, { attributes: true, attributeFilter: ['value'] });

    function loadFromTextarea() {
      var val = textarea.value || '';
      if (val.indexOf('<') !== -1) {
        editorArea.innerHTML = sanitizeHtml(val);
      } else if (val.trim()) {
        editorArea.innerHTML = '<p>' + escapeHtml(val).replace(/\n\n/g, '</p><p>').replace(/\n/g, '<br>') + '</p>';
      } else {
        editorArea.innerHTML = '<p><br></p>';
      }
      sourceArea.value = editorArea.innerHTML;
      updateStats();
    }

    // Input events
    editorArea.addEventListener('input', syncToTextarea);
    sourceArea.addEventListener('input', function () {
      textarea.value = sourceArea.value;
      editorArea.innerHTML = sanitizeHtml(sourceArea.value);
      updateStats();
    });

    // Keyboard shortcuts in editor
    editorArea.addEventListener('keydown', function (e) {
      if (e.key === 'Tab') {
        e.preventDefault();
        document.execCommand('insertHTML', false, '&nbsp;&nbsp;&nbsp;&nbsp;');
      }
    });

    // Toolbar click handler
    toolbar.addEventListener('click', function (e) {
      var btn = e.target.closest('button');
      if (!btn) return;
      e.preventDefault();

      var customAction = btn.dataset.customAction;
      if (customAction === 'toggle-source') {
        isSourceMode = !isSourceMode;
        if (isSourceMode) {
          sourceArea.value = editorArea.innerHTML;
          editorArea.classList.add('hidden');
          sourceArea.classList.remove('hidden');
          btn.classList.add('active');
          btn.innerHTML = '👁️ Görsel';
          sourceArea.focus();
        } else {
          editorArea.innerHTML = sanitizeHtml(sourceArea.value);
          sourceArea.classList.add('hidden');
          editorArea.classList.remove('hidden');
          btn.classList.remove('active');
          btn.innerHTML = '‹/› HTML';
          editorArea.focus();
        }
        syncToTextarea();
        return;
      }

      if (customAction === 'ai-enhance') {
        enhanceWithAi(editorArea, syncToTextarea);
        return;
      }

      var cmd = btn.dataset.cmd;
      var arg = btn.dataset.arg || null;

      if (cmd === 'createLink') {
        var url = prompt('Bağlantı URL adresini girin (https://...):', 'https://');
        if (url && url !== 'https://') {
          document.execCommand(cmd, false, url);
        }
      } else if (cmd === 'formatBlock' && arg === 'blockquote') {
        document.execCommand('formatBlock', false, '<blockquote>');
      } else if (cmd === 'formatBlock') {
        document.execCommand('formatBlock', false, '<' + arg + '>');
      } else if (cmd) {
        document.execCommand(cmd, false, arg);
      }

      syncToTextarea();
      editorArea.focus();
    });

    // Initial stats
    updateStats();
  }

  // AI enhancement: connects to backend AI content generator with local smart fallback
  function enhanceWithAi(editorArea, onDone) {
    var wrapper = editorArea.closest('.rich-editor-container');
    var form = editorArea.closest('form');

    // Detect title from current form or document
    var titleEl = form ? form.querySelector('[name="name"], [name="title"], #input-title') : document.getElementById('input-title');
    var title = titleEl ? titleEl.value.trim() : 'Özel Destinasyon & Tatil Portföyü';

    // Context detection
    var pageUrl = window.location.pathname;
    var context = 'region';
    if (pageUrl.indexOf('/catalog') !== -1 || pageUrl.indexOf('/listings') !== -1) {
      context = 'hotel';
    } else if (pageUrl.indexOf('/categories') !== -1) {
      context = 'category';
    } else if (pageUrl.indexOf('/cms') !== -1) {
      context = 'cms';
    }

    editorArea.classList.add('ai-loading-pulse');
    editorArea.style.opacity = '0.6';

    var formData = new FormData();
    formData.append('mode', 'description');
    formData.append('context', context);
    formData.append('title', title || 'Kaş');
    formData.append('description', editorArea.innerText.trim());
    formData.append('action', 'ota');
    formData.append('prompt', '');

    fetch('/admin/ai/content-enhance', {
      method: 'POST',
      body: formData,
      credentials: 'same-origin'
    })
      .then(function (r) {
        if (!r.ok) throw new Error('AI servisi yanıt vermedi');
        return r.json();
      })
      .then(function (data) {
        editorArea.classList.remove('ai-loading-pulse');
        editorArea.style.opacity = '1';
        if (data.description_html) {
          editorArea.innerHTML = sanitizeHtml(data.description_html);
          editorArea.classList.add('ai-highlight');
          setTimeout(function () { editorArea.classList.remove('ai-highlight'); }, 2000);
        }
        if (onDone) onDone();
      })
      .catch(function () {
        editorArea.classList.remove('ai-loading-pulse');
        editorArea.style.opacity = '1';

        // Local Heuristic Fallback
        var t = title || 'Kaş';
        var fallbackHtml = `
          <h2>✨ ${t} — Eşsiz Keşif & Ayrıcalıklı Tatil Rehberi</h2>
          <p><strong>${t}</strong>, Akdeniz ve Ege'nin muhteşem doğası, berrak turkuaz koyları ve tarihi dokusuyla misafirlerine huzur ve konforu bir arada sunan seçkin bir tatil destinasyonudur.</p>
          <h3>Öne Çıkan Ayrıcalıklar & Gezilecek Noktalar</h3>
          <ul>
            <li><strong>Doğa & Plajlar:</strong> Mavi bayraklı koylar, bakir kumsallar ve panoramik gün batımı seyir noktaları.</li>
            <li><strong>Konaklama Çeşitliliği:</strong> Özel havuzlu korunaklı villalar, denize sıfır butik oteller ve lüks süitler.</li>
            <li><strong>Aktivite & Gastronomi:</strong> Tekne turları, su sporları, tarihi Likya yolu yürüyüşleri ve yerel lezzetler.</li>
            <li><strong>NEXUS Acente Güvencesi:</strong> 7/24 concierge desteği, hijyen garantili hizmet ve kolay rezervasyon.</li>
          </ul>
          <blockquote>“Huzur, lüks ve doğanın mükemmel uyumu ile hayalinizdeki tatili NEXUS güvencesiyle gerçeğe dönüştürün.”</blockquote>
          <p>Detaylı bilgi ve erken rezervasyon fırsatları için seyahat danışmanlarımız 7/24 hizmetinizdedir.</p>
        `;
        editorArea.innerHTML = sanitizeHtml(fallbackHtml);
        editorArea.classList.add('ai-highlight');
        setTimeout(function () { editorArea.classList.remove('ai-highlight'); }, 2000);
        if (onDone) onDone();
      });
  }

  // Auto-init on DOMContentLoaded and on window load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initRichEditors);
  } else {
    initRichEditors();
  }

  // Expose helper to window
  window.initNexusRichEditors = initRichEditors;
})();
