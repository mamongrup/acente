// Public site tema: dark ↔ light toggle + auto (time-based) default
// Yukledigi HTML: html[data-theme="dark"|"light"]
// Varsayilan: kullanici hicbir sey secmediyse auto (zaman dilimine gore)
(function () {
  'use strict';

  var STORAGE_KEY = 'chisfis-theme-pref';
  var LEGACY_KEY = 'nexus-theme-pref';

  function getTimeTheme() {
    var h = new Date().getHours();
    // 07-19 arasi aydinlik, diger saatler koyu
    return h >= 7 && h < 19 ? 'light' : 'dark';
  }

  function resolve() {
    var stored = localStorage.getItem(STORAGE_KEY) || localStorage.getItem(LEGACY_KEY);
    if (stored === 'dark' || stored === 'light') return stored;
    return getTimeTheme(); // auto
  }

  function apply(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    updateToggleIcons(theme);
  }

  function updateToggleIcons(theme) {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;
    var moon = btn.querySelector('.hgi-moon-02, .icon-moon');
    var sun = btn.querySelector('.hgi-sun-01, .icon-sun');
    if (moon) moon.style.display = theme === 'dark' ? '' : 'none';
    if (sun) sun.style.display = theme === 'light' ? '' : 'none';
  }

  // Apply immediately
  apply(resolve());

  // Watch auto changes every 60s
  var autoInterval = null;
  function startAutoWatch() {
    if (autoInterval) clearInterval(autoInterval);
    autoInterval = setInterval(function () {
      if (!localStorage.getItem(STORAGE_KEY)) {
        apply(getTimeTheme());
      }
    }, 60000);
  }
  startAutoWatch();

  // Toggle handler - dark ↔ light
  function setupToggle() {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;
    btn.addEventListener('click', function () {
      var current = document.documentElement.getAttribute('data-theme') || 'dark';
      var next = current === 'dark' ? 'light' : 'dark';
      localStorage.setItem(STORAGE_KEY, next);
      apply(next);
    });
  }

  // Also support theme-pick dropdown (footer cards, etc)
  function setupPickButtons() {
    document.addEventListener('click', function (e) {
      var pick = e.target.closest('[data-theme-pick]');
      if (!pick) return;
      var theme = pick.getAttribute('data-theme-pick');
      if (theme === 'dark' || theme === 'light') {
        localStorage.setItem(STORAGE_KEY, theme);
        apply(theme);
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      setupToggle();
      setupPickButtons();
    });
  } else {
    setupToggle();
    setupPickButtons();
  }
})();
