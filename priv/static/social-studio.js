// NEXUS Agency — Sosyal Medya & Yapay Zeka Stüdyosu (Social Studio & AI)
(function () {
  'use strict';

  function readCookie(name) {
    var match = document.cookie.match(new RegExp('(?:^|;\\s*)' + name + '=([^;]*)'));
    return match ? decodeURIComponent(match[1]) : '';
  }

  function getCsrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    if (meta && meta.content) return meta.content;
    return readCookie('nexus_csrf') || readCookie('agency_csrf');
  }

  function initSocialStudio() {
    var generateBtn = document.getElementById('btn-generate-social-ai');
    var listingInput = document.getElementById('input-social-listing-id');
    var networkSelect = document.getElementById('select-social-network');
    var langSelect = document.getElementById('select-social-lang');
    var toneSelect = document.getElementById('select-social-tone');
    var contentArea = document.getElementById('textarea-social-content');
    var mediaInput = document.getElementById('input-social-media-url');
    var aiGeneratedHidden = document.getElementById('input-ai-generated');

    // Preview elements
    var previewBadge = document.getElementById('preview-network-badge');
    var mockupAuthorName = document.getElementById('mockup-author-name');
    var mockupImg = document.getElementById('mockup-img');
    var mockupImageBox = document.getElementById('mockup-image-box');
    var mockupText = document.getElementById('mockup-text-display');
    var mockupCard = document.getElementById('social-mockup-card');

    if (!generateBtn && !contentArea) return;

    function updatePreview() {
      if (!mockupCard) return;
      var network = networkSelect ? networkSelect.value : 'instagram';
      var text = contentArea && contentArea.value.trim() ? contentArea.value : 'Yapay zeka ile büyüleyici bir sosyal medya gönderisi üretmek için yukarıdaki butona tıklayın...';
      var mediaUrl = mediaInput ? mediaInput.value.trim() : '';
      var lang = langSelect ? langSelect.value : 'tr';

      // Update badge
      var networkLabels = {
        instagram: '📸 Instagram Gönderisi',
        facebook: '📘 Facebook Gönderisi',
        threads: '🧵 Threads Paylaşımı',
        pinterest: '📌 Pinterest Pini'
      };
      if (previewBadge) previewBadge.textContent = networkLabels[network] || 'Sosyal Medya Önizlemesi';

      // Update author
      var authorNames = {
        tr: 'rezervasyonyap',
        en: 'reservationinturkey',
        de: 'tuerkeiurlaub',
        ru: 'otdyhvturtsii'
      };
      if (mockupAuthorName) mockupAuthorName.textContent = authorNames[lang] || 'rezervasyonyap';

      // Update image
      if (mockupImg) {
        if (mockupImageBox) mockupImageBox.hidden = !mediaUrl;
        mockupImg.onerror = null;
        mockupImg.onerror = function () {
          if (mockupImageBox) mockupImageBox.hidden = true;
        };
        if (mediaUrl) mockupImg.src = mediaUrl;
      }

      // Update text
      if (mockupText) {
        mockupText.textContent = text;
      }

      // Layout specific class
      mockupCard.className = 'social-mockup-card mode-' + network;
    }

    // Attach listeners for live preview
    if (contentArea) contentArea.addEventListener('input', updatePreview);
    if (contentArea) contentArea.addEventListener('input', function () {
      if (aiGeneratedHidden) aiGeneratedHidden.value = 'false';
    });
    if (mediaInput) mediaInput.addEventListener('input', updatePreview);
    if (networkSelect) networkSelect.addEventListener('change', updatePreview);
    if (langSelect) langSelect.addEventListener('change', updatePreview);

    // Copy button
    var copyBtn = document.getElementById('btn-copy-social-text');
    if (copyBtn) {
      copyBtn.addEventListener('click', function () {
        if (contentArea && contentArea.value) {
          navigator.clipboard.writeText(contentArea.value).then(function () {
            var orig = copyBtn.textContent;
            copyBtn.textContent = '✅ Kopyalandı!';
            setTimeout(function () { copyBtn.textContent = orig; }, 1800);
          }).catch(function () {
            contentArea.select();
            document.execCommand('copy');
          });
        }
      });
    }

    // Check for listing_id in URL query params (e.g. from Catalog / Admin listings)
    try {
      var urlParams = new URLSearchParams(window.location.search);
      var queryListingId = urlParams.get('listing_id');
      if (queryListingId && listingInput && !listingInput.value) {
        listingInput.value = queryListingId;
        setTimeout(function () {
          if (generateBtn) generateBtn.click();
        }, 150);
      }
    } catch (_) {}

    // Initial sync
    updatePreview();

    // AI Generation Click Handler
    if (generateBtn) {
      generateBtn.addEventListener('click', function () {
        var csrf = getCsrfToken();
        var listingId = listingInput ? listingInput.value.trim() : '';
        var network = networkSelect ? networkSelect.value : 'instagram';
        var lang = langSelect ? langSelect.value : 'tr';
        var tone = toneSelect ? toneSelect.value : 'luxury';

        var originalBtnText = generateBtn.innerHTML;
        generateBtn.disabled = true;
        generateBtn.classList.add('ai-loading-pulse');
        generateBtn.innerHTML = '<span class="sparkle-anim">⏳</span> Gönderi hazırlanıyor...';

        var bodyParams = new URLSearchParams();
        bodyParams.append('csrf', csrf);
        bodyParams.append('csrf_token', csrf);
        bodyParams.append('listing_id', listingId);
        bodyParams.append('network', network);
        bodyParams.append('language_code', lang);
        bodyParams.append('tone', tone);

        fetch('/admin/ai/social-generate', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json'
          },
          body: bodyParams.toString(),
          credentials: 'same-origin'
        })
          .then(function (res) {
            if (!res.ok) throw new Error('Yapay zeka servisi yanıt vermedi (' + res.status + ')');
            return res.json();
          })
          .then(function (data) {
            if (data.ok && data.content) {
              if (data.listing_id && listingInput) listingInput.value = data.listing_id;
              if (contentArea) {
                contentArea.value = data.content;
                contentArea.classList.add('ai-highlight');
                setTimeout(function () { contentArea.classList.remove('ai-highlight'); }, 2000);
              }
              if (data.media_url && mediaInput) {
                mediaInput.value = data.media_url;
              }
              if (aiGeneratedHidden) {
                aiGeneratedHidden.value = 'true';
              }
              updatePreview();
            } else {
              throw new Error(data.error || 'İçerik üretilemedi');
            }
          })
          .catch(function (err) {
            alert('Yapay zeka gönderi üretimi: ' + err.message);
          })
          .finally(function () {
            generateBtn.disabled = false;
            generateBtn.classList.remove('ai-loading-pulse');
            generateBtn.innerHTML = originalBtnText;
          });
      });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initSocialStudio);
  } else {
    initSocialStudio();
  }
})();
