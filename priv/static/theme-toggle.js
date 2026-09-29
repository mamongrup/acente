// Panel tema: dark ↔ light toggle + auto (time-based) default
// Secim yoksa zaman dilimine gore otomatik secim yapar.
// Header'daki tek toggle butonu (theme-toggle-btn) ile calisir.
(function () {
  'use strict';

  var STORAGE_KEY = 'nexus-theme-pref';

  function getTimeTheme() {
    var h = new Date().getHours();
    // 07–19 arasi aydinlik, diger saatler koyu
    return h >= 7 && h < 19 ? 'light' : 'dark';
  }

  function resolve() {
    var stored = localStorage.getItem(STORAGE_KEY);
    if (stored === 'dark' || stored === 'light') return stored;
    return getTimeTheme(); // auto
  }

  function apply(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    updateIcons(theme);
  }

  function updateIcons(theme) {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;
    var darkIcon = btn.querySelector('.theme-icon-dark, .hgi-moon-02');
    var lightIcon = btn.querySelector('.theme-icon-light, .hgi-sun-01');
    if (darkIcon) darkIcon.style.display = theme === 'dark' ? '' : 'none';
    if (lightIcon) lightIcon.style.display = theme === 'light' ? '' : 'none';
  }

  function setup() {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;
    btn.addEventListener('click', function () {
      var current = document.documentElement.getAttribute('data-theme') || 'dark';
      var next = current === 'dark' ? 'light' : 'dark';
      localStorage.setItem(STORAGE_KEY, next);
      apply(next);
    });
  }

  // Apply immediately
  apply(resolve());

  // Auto watch: her 60 sn'de kontrol et, kullanici secmediyse zamanla degistir
  setInterval(function () {
    if (!localStorage.getItem(STORAGE_KEY)) {
      apply(getTimeTheme());
    }
  }, 60000);

  // Also support footer theme-pick cards
  document.addEventListener('click', function (e) {
    var pick = e.target.closest('[data-theme-pick]');
    if (!pick) return;
    var theme = pick.getAttribute('data-theme-pick');
    if (theme === 'dark' || theme === 'light') {
      localStorage.setItem(STORAGE_KEY, theme);
      apply(theme);
    }
  });

  /* ---- Dil tercihi (Ayarlar > Görünüm & Tema > Arayüz Dili) ----
   * .language-choice kartı → POST /admin/preferences/language (CSRF çerezi
   * csrf-guard tarafından form'lara enjekte edilir; burada çerezden okunur).
   * Mağaza tarafı nexus_lang çerezinden okur; panelde seçilen dil mağazaya
   * da yansır.
   */
  function paintLangUI(lang) {
    document.querySelectorAll('.language-choice').forEach(function (card) {
      var on = card.getAttribute('data-language-choice') === lang;
      card.classList.toggle('active', on);
      card.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
  }
  function readNexusLang() {
    var m = document.cookie.match(/(?:^|;\s*)nexus_lang=([^;]*)/);
    return m ? decodeURIComponent(m[1]) : null;
  }
  paintLangUI(readNexusLang() || 'tr');
  document.addEventListener('click', function (e) {
    var card = e.target.closest('.language-choice');
    if (!card) return;
    var lang = card.getAttribute('data-language-choice');
    if (!lang) return;
    paintLangUI(lang);
    document.cookie = 'nexus_lang=' + encodeURIComponent(lang) + ';path=/;max-age=31536000;samesite=lax';
    document.cookie = 'agency_lang=' + btoa(lang).replace(/=+$/, '') + ';path=/;max-age=31536000;samesite=lax';
    var csrf = readCookieCsrf();
    if (!csrf) return; // oturum yoksa sessizce çık
    fetch('/admin/preferences/language?lang=' + encodeURIComponent(lang), {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'csrf=' + encodeURIComponent(csrf),
    }).catch(function () {});
  });
  function readCookieCsrf() {
    var m = document.cookie.match(/(?:^|;\s*)nexus_csrf=([^;]*)/);
    return m ? decodeURIComponent(m[1]) : null;
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setup);
  } else {
    setup();
  }
})();
