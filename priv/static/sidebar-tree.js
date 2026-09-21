// NEXUS Agency — Sidebar Category Tree & Topbar Language Selector

(function () {
  // 1. Language Picker Dropdown Toggle
  var langBtn = document.getElementById('topbar-lang-btn');
  var langMenu = document.getElementById('topbar-lang-menu');

  if (langBtn && langMenu) {
    var syncLangAria = function () {
      var open = langMenu.classList.contains('show');
      langBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
    };

    langBtn.addEventListener('click', function (e) {
      e.stopPropagation();
      langMenu.classList.toggle('show');
      syncLangAria();
    });

    document.addEventListener('click', function (e) {
      if (!langMenu.contains(e.target) && e.target !== langBtn) {
        langMenu.classList.remove('show');
        syncLangAria();
      }
    });

    // ESC ile menüyü kapat (klavye erişilebilirliği)
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && langMenu.classList.contains('show')) {
        langMenu.classList.remove('show');
        syncLangAria();
        langBtn.focus();
      }
    });

    syncLangAria();
  }

  // 2. Sidebar Catalog Tree Accordion
  var toggles = document.querySelectorAll('.tree-category-toggle');
  var urlParams = new URLSearchParams(window.location.search);
  var activeCat = urlParams.get('cat');

  toggles.forEach(function (btn) {
    var group = btn.closest('.tree-category-group');
    var catCode = btn.getAttribute('data-toggle-cat');

    // Auto-open if this category is in URL query
    if (activeCat && catCode === activeCat && group) {
      group.classList.add('open');
    }

    btn.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      var isAlreadyOpen = group.classList.contains('open');

      // Close other groups for a neat accordion experience
      document.querySelectorAll('.tree-category-group').forEach(function (g) {
        if (g !== group) g.classList.remove('open');
      });

      if (!isAlreadyOpen) {
        group.classList.add('open');
      } else {
        group.classList.remove('open');
      }
    });
  });

  // Mark the exact category sub-page (including hash targets) as active.
  var currentPath = window.location.pathname;
  var currentHash = window.location.hash;
  document.querySelectorAll('.tree-sublink').forEach(function (link) {
    var target = new URL(link.href, window.location.origin);
    var sameCategory = !target.searchParams.get('cat') || target.searchParams.get('cat') === activeCat;
    var hashMatches = target.hash ? target.hash === currentHash : !currentHash;
    if (target.pathname === currentPath && sameCategory && hashMatches) {
      link.classList.add('active');
      link.setAttribute('aria-current', 'page');
    }
  });
})();
