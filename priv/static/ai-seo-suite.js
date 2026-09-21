// NEXUS Agency — AI Content & SEO Suite (Yapay Zeka Destekli İçerik & SEO Modülü)
(function () {
  'use strict';

  // Transliterate Turkish characters to English URL slug
  function slugify(text) {
    var trMap = {
      'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g', 'ı': 'i', 'İ': 'i',
      'ö': 'o', 'Ö': 'o', 'ş': 's', 'Ş': 's', 'ü': 'u', 'Ü': 'u'
    };
    return text
      .split('')
      .map(function (c) { return trMap[c] || c; })
      .join('')
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-');
  }

  function initAiSeoSuite() {
    // 1. Find forms with title and SEO fields
    var forms = document.querySelectorAll('form');
    forms.forEach(function (form) {
      if (form.dataset.aiSeoInitialized === 'true') return;

      var hasSeoFields = form.querySelector('[name="seo_title"], [name="seo_description"]') !== null;
      var hasTitle = form.querySelector('[name="name"], [name="title"], #input-title') !== null;
      var hasDesc = form.querySelector('[name="description"], [name="content"]') !== null;

      if (hasSeoFields || (hasTitle && hasDesc)) {
        form.dataset.aiSeoInitialized = 'true';
        setupFormAiAndSeo(form);
      }
    });
  }

  function setupFormAiAndSeo(form) {
    var titleInput = form.querySelector('[name="name"], [name="title"], #input-title');
    var slugInput = form.querySelector('[name="slug"]');
    var seoTitleInput = form.querySelector('[name="seo_title"]');
    var seoDescInput = form.querySelector('[name="seo_description"]');
    var descTextarea = form.querySelector('[name="description"]:not([name="seo_description"]), [name="content"], .rich-textarea');

    // Determine Context
    var pageUrl = window.location.pathname;
    var context = 'region';
    if (pageUrl.indexOf('/catalog') !== -1 || pageUrl.indexOf('/listings') !== -1) {
      context = 'hotel';
    } else if (pageUrl.indexOf('/categories') !== -1) {
      context = 'category';
    } else if (pageUrl.indexOf('/cms') !== -1 || pageUrl.indexOf('/blog') !== -1) {
      context = 'cms';
    }

    // A. Inject AI Title Assistant
    if (titleInput) {
      setupAiTitleAssistant(titleInput, descTextarea, slugInput, context);
    }

    // B. Build and Inject AI SEO Suite Module if SEO fields exist
    if (seoTitleInput && seoDescInput) {
      setupSeoModule(form, titleInput, slugInput, seoTitleInput, seoDescInput, descTextarea, context);
    }
  }

  // =========================================================================
  // AI TITLE ASSISTANT (Yapay Zeka Başlık Düzenleyici)
  // =========================================================================
  function setupAiTitleAssistant(titleInput, descTextarea, slugInput, context) {
    var label = titleInput.closest('label');
    if (!label) return;
    if (label.querySelector('.ai-dropdown-wrapper')) return;

    var dropdownHtml = `
      <div class="ai-dropdown-wrapper">
        <button type="button" class="btn-ai-pill" title="Yapay zeka ile başlığı zenginleştir veya alternatifler üret">
          <span class="sparkle-icon">✨</span> AI Başlık Asistanı
        </button>
        <div class="ai-title-menu hidden">
          <div class="ai-menu-header">✨ AI Başlık Seçenekleri</div>
          <button type="button" class="ai-menu-item" data-action="seo">🎯 SEO & Arama Niyeti Odaklı Başlık</button>
          <button type="button" class="ai-menu-item" data-action="luxury">💎 Lüks & Prestijli Başlık</button>
          <button type="button" class="ai-menu-item" data-action="catchy">⚡ Çekici & Dönüşüm Odaklı Başlık</button>
          <button type="button" class="ai-menu-item" data-action="short">✂️ Sade & Net Başlık</button>
          <div class="ai-menu-custom">
            <input type="text" class="ai-custom-input" placeholder="Örn: Balayı için romantik başlık..." />
            <button type="button" class="ai-custom-submit">Uygula</button>
          </div>
        </div>
      </div>
    `;

    var temp = document.createElement('div');
    temp.innerHTML = dropdownHtml.trim();
    var dropdownEl = temp.firstElementChild;

    var labelBar = label.querySelector('.field-label-bar');
    if (!labelBar) {
      var rawLabel = '';
      var toRemove = [];
      for (var i = 0; i < label.childNodes.length; i++) {
        var node = label.childNodes[i];
        if (node.nodeType === Node.TEXT_NODE && node.textContent.trim()) {
          rawLabel += node.textContent.trim() + ' ';
          toRemove.push(node);
        }
      }
      toRemove.forEach(function (n) { n.remove(); });
      rawLabel = rawLabel.trim() || 'Başlık / İsim';

      labelBar = document.createElement('div');
      labelBar.className = 'field-label-bar';
      labelBar.innerHTML = '<span>' + rawLabel + '</span>';
      // titleInput etiketin doğrudan çocuğu olmayabilir (div sarmalayıcı);
      // insertBefore yalnızca kendi çocuğundan önce ekleyebilir —
      // sarmalayıcı zincirini label'ın doğrudan çocuğuna kadar çık.
      var anchor = titleInput;
      while (anchor && anchor.parentNode !== label) anchor = anchor.parentNode;
      if (anchor) label.insertBefore(labelBar, anchor);
      else label.appendChild(labelBar);
    }

    labelBar.appendChild(dropdownEl);

    var btn = dropdownEl.querySelector('.btn-ai-pill');
    var menu = dropdownEl.querySelector('.ai-title-menu');
    var customInput = dropdownEl.querySelector('.ai-custom-input');
    var customSubmit = dropdownEl.querySelector('.ai-custom-submit');

    // Toggle menu
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      document.querySelectorAll('.ai-title-menu').forEach(function (m) {
        if (m !== menu) m.classList.add('hidden');
      });
      menu.classList.toggle('hidden');
    });

    document.addEventListener('click', function (e) {
      if (!dropdownEl.contains(e.target)) {
        menu.classList.add('hidden');
      }
    });

    // Menu item clicks
    menu.querySelectorAll('.ai-menu-item').forEach(function (item) {
      item.addEventListener('click', function () {
        var action = item.dataset.action;
        menu.classList.add('hidden');
        requestAiTitle(titleInput, descTextarea, slugInput, context, action, '');
      });
    });

    customSubmit.addEventListener('click', function () {
      var prompt = customInput.value.trim();
      menu.classList.add('hidden');
      if (prompt) {
        requestAiTitle(titleInput, descTextarea, slugInput, context, 'custom', prompt);
      }
    });

    customInput.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') {
        e.preventDefault();
        customSubmit.click();
      }
    });

    // Auto-update slug if empty when typing in title
    titleInput.addEventListener('input', function () {
      if (slugInput && !slugInput.dataset.manuallyEdited) {
        slugInput.value = slugify(titleInput.value);
        var evt = new Event('input', { bubbles: true });
        slugInput.dispatchEvent(evt);
      }
    });

    if (slugInput) {
      slugInput.addEventListener('input', function () {
        if (slugInput.value.trim()) {
          slugInput.dataset.manuallyEdited = 'true';
        }
      });
    }
  }

  function requestAiTitle(titleInput, descTextarea, slugInput, context, action, prompt) {
    var rawTitle = titleInput.value.trim();
    var rawDesc = descTextarea ? descTextarea.value.trim() : '';

    titleInput.classList.add('ai-loading-pulse');

    var formData = new FormData();
    formData.append('mode', 'title');
    formData.append('context', context);
    formData.append('title', rawTitle || 'Özel Destinasyon');
    formData.append('description', rawDesc);
    formData.append('action', action);
    formData.append('prompt', prompt);

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
        titleInput.classList.remove('ai-loading-pulse');
        if (data.title) {
          titleInput.value = data.title;
          titleInput.classList.add('ai-highlight');
          setTimeout(function () { titleInput.classList.remove('ai-highlight'); }, 2000);

          if (slugInput && !slugInput.dataset.manuallyEdited && data.slug) {
            slugInput.value = slugify(data.slug);
            var slugEvt = new Event('input', { bubbles: true });
            slugInput.dispatchEvent(slugEvt);
          }

          var evt = new Event('input', { bubbles: true });
          titleInput.dispatchEvent(evt);
        }
      })
      .catch(function () {
        titleInput.classList.remove('ai-loading-pulse');
        // Fallback local heuristic
        var base = rawTitle || 'Kaş';
        var fallbackTitle = action === 'luxury'
          ? base + ': Eşsiz Doğa & Lüks Tatil Rehberi'
          : action === 'seo'
            ? base + ' Tatil Rehberi, Kiralık Villa & Oteller'
            : action === 'short'
              ? base + ' Gezi Rehberi'
              : 'Büyüleyici Bir Tatil: ' + base;
        titleInput.value = fallbackTitle;
        titleInput.classList.add('ai-highlight');
        setTimeout(function () { titleInput.classList.remove('ai-highlight'); }, 2000);
        if (slugInput && !slugInput.dataset.manuallyEdited) {
          slugInput.value = slugify(fallbackTitle);
        }
        var evt = new Event('input', { bubbles: true });
        titleInput.dispatchEvent(evt);
      });
  }

  // =========================================================================
  // AI-POWERED SEO SUITE MODULE (Yapay Zeka Destekli SEO & Meta Modülü)
  // =========================================================================
  function setupSeoModule(form, titleInput, slugInput, seoTitleInput, seoDescInput, descTextarea, context) {
    // Check if already placed in a suite container
    var existingSuite = form.querySelector('.ai-seo-module-card');
    if (existingSuite) return;

    var seoTitleLabel = seoTitleInput.closest('label');
    var seoDescLabel = seoDescInput.closest('label');

    // Create the outer luxury glass container
    var seoCard = document.createElement('div');
    seoCard.className = 'ai-seo-module-card glass-subcard';
    seoCard.innerHTML = `
      <div class="ai-seo-header">
        <div class="ai-seo-title-wrap">
          <span class="ai-seo-icon">🚀</span>
          <div>
            <h3>Yapay Zeka Destekli SEO & Meta Modülü</h3>
            <p>Google ve arama motorlarında 1. sıraya yükselmek için tasarlanmış canlı SERP önizlemesi ve meta optimizasyon motoru.</p>
          </div>
        </div>
        <span class="status-pill">Google SERP v2.4</span>
      </div>

      <div class="ai-seo-top-bar">
        <button type="button" class="btn-ai-magic-seo" id="btn-run-ai-seo">
          <span class="sparkle-anim">✨</span> Yapay Zeka ile SEO'yu Otomatik Oluştur (Başlık, Açıklama, Slug, Etiketler)
        </button>
      </div>

      <!-- LIVE GOOGLE SERP PREVIEW -->
      <div class="google-serp-preview">
        <div class="serp-top-row">
          <span class="serp-brand"><span style="color:#4285F4">G</span><span style="color:#EA4335">o</span><span style="color:#FBBC05">o</span><span style="color:#4285F4">g</span><span style="color:#34A853">l</span><span style="color:#EA4335">e</span> Canlı Arama Sonucu Önizlemesi</span>
          <div class="serp-device-toggle">
            <button type="button" class="serp-device-btn active" data-device="desktop">🖥️ Masaüstü</button>
            <button type="button" class="serp-device-btn" data-device="mobile">📱 Mobil</button>
          </div>
        </div>
        <div class="serp-card-body" id="serp-box">
          <div class="serp-url-line">
            <span class="serp-favicon">🌐</span>
            <span class="serp-domain">https://nexusagency.com</span>
            <span class="serp-slug" id="serp-slug-display">› bolgeler › antalya-kas</span>
          </div>
          <div class="serp-title-line" id="serp-title-display">Antalya Kaş Tatil Rehberi, Kiralık Villa & Butik Oteller | NEXUS</div>
          <div class="serp-desc-line" id="serp-desc-display">Antalya Kaş'ın en popüler koylarını, denize sıfır otellerini ve korunaklı kiralık villalarını keşfedin. En iyi fiyat garantisiyle online rezervasyon yapın.</div>
        </div>
      </div>

      <!-- SEO HEALTH METRICS & REAL-TIME CHECKLIST -->
      <div class="seo-metrics-dashboard">
        <div class="seo-score-gauge">
          <div class="seo-score-circle">
            <span class="seo-score-num" id="seo-score-number">98</span>
            <span class="seo-score-label">/ 100</span>
          </div>
          <div class="seo-score-text">
            <strong id="seo-grade-text">Mükemmel SEO Uyumu</strong>
            <p>Meta etiketleriniz arama motoru standartlarında kusursuz uzunluk ve tıklanma oranına (CTR) sahip.</p>
          </div>
        </div>

        <div class="seo-checklist-grid">
          <div class="seo-check-item" id="check-item-title"><span class="check-icon">✓</span> Başlık ideal uzunlukta (40-60 karakter)</div>
          <div class="seo-check-item" id="check-item-desc"><span class="check-icon">✓</span> Meta açıklaması eksiksiz (120-160 karakter)</div>
          <div class="seo-check-item" id="check-item-slug"><span class="check-icon">✓</span> Temiz ve anahtar kelimeli URL Slug</div>
          <div class="seo-check-item" id="check-item-kw"><span class="check-icon">✓</span> Odak anahtar kelimeler mevcut</div>
        </div>
      </div>

      <!-- INPUT MOUNT POINTS -->
      <div class="ai-seo-inputs-grid">
        <div class="ai-seo-field-wrap" id="mount-seo-title"></div>
        <div class="ai-seo-field-wrap" id="mount-seo-desc"></div>
      </div>

      <!-- FOCUS KEYWORDS -->
      <div class="seo-keywords-section">
        <div class="seo-kw-header">
          <span>🏷️ Odak Anahtar Kelimeler (Focus Keywords)</span>
          <small class="muted">Arama sorgularıyla eşleşecek önerilen etiketler</small>
        </div>
        <div class="seo-kw-chips" id="seo-keywords-chips">
          <span class="kw-tag">#tatil-rehberi</span>
          <span class="kw-tag">#kiralık-villa</span>
          <span class="kw-tag">#butik-otel</span>
          <span class="kw-tag">#online-rezervasyon</span>
        </div>
      </div>
    `;

    // Move existing labels into the module
    if (seoTitleLabel && seoDescLabel) {
      seoTitleLabel.parentNode.insertBefore(seoCard, seoTitleLabel);
      var mountTitle = seoCard.querySelector('#mount-seo-title');
      var mountDesc = seoCard.querySelector('#mount-seo-desc');

      mountTitle.appendChild(seoTitleLabel);
      mountDesc.appendChild(seoDescLabel);
    } else {
      // Fallback append before submit button
      var submitBtn = form.querySelector('button[type="submit"]');
      if (submitBtn) {
        submitBtn.parentNode.insertBefore(seoCard, submitBtn);
      } else {
        form.appendChild(seoCard);
      }
    }

    // Add character counter helpers
    var titleCounter = document.createElement('div');
    titleCounter.className = 'seo-char-counter';
    titleCounter.id = 'counter-seo-title';
    titleCounter.innerHTML = '<span class="char-num">0</span> / 60 karakter <span class="char-badge">İdeal: 40-60</span>';
    seoTitleInput.parentNode.appendChild(titleCounter);

    var descCounter = document.createElement('div');
    descCounter.className = 'seo-char-counter';
    descCounter.id = 'counter-seo-desc';
    descCounter.innerHTML = '<span class="char-num">0</span> / 160 karakter <span class="char-badge">İdeal: 120-160</span>';
    seoDescInput.parentNode.appendChild(descCounter);

    // Elements
    var serpSlug = seoCard.querySelector('#serp-slug-display');
    var serpTitle = seoCard.querySelector('#serp-title-display');
    var serpDesc = seoCard.querySelector('#serp-desc-display');
    var serpBox = seoCard.querySelector('#serp-box');
    var scoreNum = seoCard.querySelector('#seo-score-number');
    var gradeText = seoCard.querySelector('#seo-grade-text');
    var kwChipsContainer = seoCard.querySelector('#seo-keywords-chips');
    var btnRunAiSeo = seoCard.querySelector('#btn-run-ai-seo');

    // Device switch handler
    seoCard.querySelectorAll('.serp-device-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        seoCard.querySelectorAll('.serp-device-btn').forEach(function (b) { b.classList.remove('active'); });
        btn.classList.add('active');
        if (btn.dataset.device === 'mobile') {
          serpBox.classList.add('mobile-preview');
        } else {
          serpBox.classList.remove('mobile-preview');
        }
      });
    });

    // Real-time Update function
    function updateSerpAndAudit() {
      var currentTitle = seoTitleInput.value.trim() || (titleInput ? titleInput.value.trim() : '') || 'NEXUS Turizm & Seyahat';
      var currentDesc = seoDescInput.value.trim() || 'Türkiye\'nin en seçkin tatil destinasyonları, otelleri ve kiralık villaları. Güvenli online rezervasyon.';
      var currentSlug = slugInput ? slugInput.value.trim() : 'tatil';

      // Update SERP elements
      serpTitle.textContent = currentTitle;
      serpDesc.textContent = currentDesc;
      var pathContext = context === 'region' ? 'bolgeler' : context === 'hotel' ? 'oteller' : 'katalog';
      serpSlug.textContent = '› ' + pathContext + ' › ' + (currentSlug || 'detay');

      // Update Character Counters
      var tLen = currentTitle.length;
      var dLen = currentDesc.length;

      var tNumEl = titleCounter.querySelector('.char-num');
      var tBadge = titleCounter.querySelector('.char-badge');
      tNumEl.textContent = tLen;
      if (tLen >= 40 && tLen <= 65) {
        titleCounter.className = 'seo-char-counter status-good';
        tBadge.textContent = '✓ Mükemmel Uzunluk';
      } else if (tLen > 65) {
        titleCounter.className = 'seo-char-counter status-danger';
        tBadge.textContent = '⚠️ Google Arama Sonuçlarında Kesilebilir';
      } else {
        titleCounter.className = 'seo-char-counter status-warn';
        tBadge.textContent = 'Kısa (Önerilen: 40-60)';
      }

      var dNumEl = descCounter.querySelector('.char-num');
      var dBadge = descCounter.querySelector('.char-badge');
      dNumEl.textContent = dLen;
      if (dLen >= 110 && dLen <= 165) {
        descCounter.className = 'seo-char-counter status-good';
        dBadge.textContent = '✓ Mükemmel Uzunluk';
      } else if (dLen > 165) {
        descCounter.className = 'seo-char-counter status-danger';
        dBadge.textContent = '⚠️ 160 Karakterden Sonrası Görünmeyebilir';
      } else {
        descCounter.className = 'seo-char-counter status-warn';
        dBadge.textContent = 'Kısa (Önerilen: 120-160)';
      }

      // Calculate SEO Score
      var score = 60;
      var checkTitle = seoCard.querySelector('#check-item-title');
      var checkDesc = seoCard.querySelector('#check-item-desc');
      var checkSlug = seoCard.querySelector('#check-item-slug');
      var checkKw = seoCard.querySelector('#check-item-kw');

      if (tLen >= 40 && tLen <= 65) {
        score += 15;
        checkTitle.classList.add('active');
      } else {
        checkTitle.classList.remove('active');
      }

      if (dLen >= 110 && dLen <= 165) {
        score += 15;
        checkDesc.classList.add('active');
      } else {
        checkDesc.classList.remove('active');
      }

      if (currentSlug && currentSlug.indexOf(' ') === -1 && currentSlug.length >= 3) {
        score += 5;
        checkSlug.classList.add('active');
      } else {
        checkSlug.classList.remove('active');
      }

      if (kwChipsContainer && kwChipsContainer.children.length > 0) {
        score += 5;
        checkKw.classList.add('active');
      } else {
        checkKw.classList.remove('active');
      }

      scoreNum.textContent = score;
      if (score >= 90) {
        gradeText.textContent = 'Mükemmel SEO Uyumu!';
        gradeText.style.color = '#10b981';
      } else if (score >= 75) {
        gradeText.textContent = 'İyi SEO Seviyesi (Biraz Geliştirilebilir)';
        gradeText.style.color = '#38bdf8';
      } else {
        gradeText.textContent = 'Temel Düzey (AI ile Optimize Edin)';
        gradeText.style.color = '#f59e0b';
      }
    }

    // Attach listeners
    seoTitleInput.addEventListener('input', updateSerpAndAudit);
    seoDescInput.addEventListener('input', updateSerpAndAudit);
    if (slugInput) slugInput.addEventListener('input', updateSerpAndAudit);
    if (titleInput) titleInput.addEventListener('input', updateSerpAndAudit);

    // Initial update
    updateSerpAndAudit();

    // One-Click AI SEO Generation
    btnRunAiSeo.addEventListener('click', function () {
      btnRunAiSeo.classList.add('ai-loading-pulse');
      btnRunAiSeo.disabled = true;

      var rawTitle = titleInput ? titleInput.value.trim() : (seoTitleInput.value.trim() || 'Özel Destinasyon');
      var rawDesc = '';
      if (descTextarea) {
        rawDesc = descTextarea.value.trim();
      }

      var formData = new FormData();
      formData.append('mode', 'seo');
      formData.append('context', context);
      formData.append('title', rawTitle);
      formData.append('description', rawDesc);
      formData.append('action', 'seo');
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
          btnRunAiSeo.classList.remove('ai-loading-pulse');
          btnRunAiSeo.disabled = false;

          if (data.seo_title) {
            seoTitleInput.value = data.seo_title;
            seoTitleInput.classList.add('ai-highlight');
            setTimeout(function () { seoTitleInput.classList.remove('ai-highlight'); }, 2000);
          }

          if (data.seo_description) {
            seoDescInput.value = data.seo_description;
            seoDescInput.classList.add('ai-highlight');
            setTimeout(function () { seoDescInput.classList.remove('ai-highlight'); }, 2000);
          }

          if (data.slug && slugInput) {
            slugInput.value = data.slug;
            slugInput.classList.add('ai-highlight');
            setTimeout(function () { slugInput.classList.remove('ai-highlight'); }, 2000);
          }

          if (data.keywords && data.keywords.length) {
            kwChipsContainer.innerHTML = '';
            data.keywords.forEach(function (kw) {
              var chip = document.createElement('span');
              chip.className = 'kw-tag';
              chip.textContent = '#' + kw.replace(/\s+/g, '-');
              kwChipsContainer.appendChild(chip);
            });
          }

          updateSerpAndAudit();
        })
        .catch(function () {
          btnRunAiSeo.classList.remove('ai-loading-pulse');
          btnRunAiSeo.disabled = false;

          // Local Heuristic Fallback
          var base = rawTitle || 'Kaş';
          var autoSeoTitle = base + ' Tatil Rehberi, Kiralık Villa & Oteller | NEXUS';
          var autoSeoDesc = base + ' bölgesinin en gözde turkuaz koylarını, denize sıfır butik otellerini ve korunaklı villalarını keşfedin. En iyi fiyat garantisiyle rezervasyon yapın.';
          var autoSlug = slugify(base) + '-tatil-rehberi';

          seoTitleInput.value = autoSeoTitle;
          seoDescInput.value = autoSeoDesc;
          if (slugInput) slugInput.value = autoSlug;

          kwChipsContainer.innerHTML = `
            <span class="kw-tag">#${slugify(base)}-tatil</span>
            <span class="kw-tag">#${slugify(base)}-villa</span>
            <span class="kw-tag">#${slugify(base)}-otelleri</span>
            <span class="kw-tag">#online-rezervasyon</span>
          `;

          seoTitleInput.classList.add('ai-highlight');
          seoDescInput.classList.add('ai-highlight');
          setTimeout(function () {
            seoTitleInput.classList.remove('ai-highlight');
            seoDescInput.classList.remove('ai-highlight');
          }, 2000);

          updateSerpAndAudit();
        });
    });
  }

  // Auto-init on page load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAiSeoSuite);
  } else {
    initAiSeoSuite();
  }

  window.initNexusAiSeoSuite = initAiSeoSuite;
})();
