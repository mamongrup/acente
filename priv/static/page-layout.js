(function () {
  var main = document.querySelector('main');
  if (!main) return;
  if (document.body.classList.contains('home-layout-pending')) {
    var revealHome = function () {
      var show = function () { window.requestAnimationFrame(function () { document.body.classList.remove('home-layout-pending'); }); };
      if (!document.fonts || !document.fonts.load) { show(); return; }
      Promise.race([
        Promise.all([document.fonts.load('500 72px Poppins'), document.fonts.load('400 20px Poppins')]),
        new Promise(function (resolve) { window.setTimeout(resolve, 1500); })
      ]).then(show, show);
    };
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', revealHome, { once: true });
    else revealHome();
  }
  var isCategory = document.body.classList.contains('category-page');
  var root = main.querySelector('.published-builder-modules');
  if (!root || !root.children.length) return;
  var hasSourceSections = !!root.querySelector('.builder-source-section');

  var homeKeys = ['hero','adventure','why_host','featured','divider_one','how_it_works','become_host','newsletter','divider_two','explore_nearby','host_cta','stay_types','videos','news'];
  var homeContainer = !isCategory && main.querySelector(':scope > .relative.container');
  var homeNodes = {};
  if (homeContainer) homeKeys.forEach(function (key, index) { homeNodes[key] = homeContainer.children[index]; });

  function categoryNodes() {
    return {
      hero: main.querySelector(':scope > .relative.container'),
      results_heading: main.querySelector('.category-results-head'),
      filters: main.querySelector('.category-demo-filter'),
      listings: main.querySelector('.category-listing-preview'),
      region: main.querySelector('.category-region-explore'),
      theme: main.querySelector('.category-theme-explore'),
      benefits: main.querySelector('.category-benefits')
    };
  }
  function updateCopy(node, config) {
    if (config.title) { var heading = node.querySelector('h1,h2'); if (heading) { heading.textContent = config.title; heading.removeAttribute('data-i18n'); } }
    if (config.description) { var description = node.querySelector('.home-section-heading p, h1 + p, h2 + p'); if (description) description.textContent = config.description; }
  }
  function updateHeroMosaic(node, config) {
    var sources = Array.isArray(config.images) ? config.images : [];
    var pictures = node.querySelectorAll('.home-hero-mosaic-slot img, .category-hero-mosaic img');
    pictures.forEach(function (picture, index) {
      var source = String(sources[index] || '').trim();
      if (!/^(https?:\/\/|\/(?!\/))/i.test(source)) return;
      picture.src = source;
      picture.removeAttribute('data-composite');
    });
  }
  function updateBenefits(node, config) {
    if (!Array.isArray(config.items)) return;
    var grid = node.querySelector('.category-benefits-grid');
    if (!grid) return;
    var iconKeys = ['secure','price','support','confirm','cancel','choice'];
    if (!node.benefitIconTemplates) {
      node.benefitIconTemplates = {};
      Array.prototype.slice.call(grid.querySelectorAll('.category-benefit-icon')).forEach(function (icon, index) {
        node.benefitIconTemplates[iconKeys[index]] = icon.cloneNode(true);
      });
    }
    grid.textContent = '';
    config.items.forEach(function (item) {
      if (!item || typeof item !== 'object') return;
      var card = document.createElement('div');
      card.className = 'category-benefit-card';
      var icon = (node.benefitIconTemplates[item.icon] || node.benefitIconTemplates.secure).cloneNode(true);
      var copy = document.createElement('span');
      copy.className = 'category-benefit-copy';
      var title = document.createElement('strong');
      title.textContent = item.title || '';
      var description = document.createElement('small');
      description.textContent = item.description || '';
      copy.append(title, description);
      card.append(icon, copy);
      grid.appendChild(card);
    });
  }
  function apply() {
    if (isCategory && document.body.classList.contains('category-map-view')) return;
    var nodes = isCategory ? categoryNodes() : homeNodes;
    var target = isCategory ? main : homeContainer;
    if (!target) return;
    var used = {};
    Array.prototype.slice.call(root.children).forEach(function (block) {
      if (block.classList.contains('builder-source-section')) {
        var config; try { config = JSON.parse(block.dataset.sectionConfig || '{}'); } catch (_) { config = {}; }
        var key = config.sectionKey;
        var node = nodes[key];
        if (!node || used[key]) return;
        used[key] = true;
        if (config.enabled === false) { node.remove(); return; }
        updateCopy(node, config);
        if (key === 'hero') updateHeroMosaic(node, config);
        if (isCategory && key === 'benefits') updateBenefits(node, config);
        if (isCategory) target.insertBefore(node, root);
        else target.appendChild(node);
      } else if (!isCategory) {
        target.appendChild(block);
      } else {
        target.insertBefore(block, root);
      }
    });
    if (hasSourceSections) Object.keys(nodes).forEach(function (key) { if (!used[key] && nodes[key]) nodes[key].remove(); });
    if (isCategory) {
      var tourCategories = main.querySelector('.category-tour-subcategories');
      if (tourCategories && nodes.hero && nodes.hero.isConnected) nodes.hero.after(tourCategories);
    }
  }
  if (isCategory) document.addEventListener('nexus:category-sections-rendered', apply);
  apply();
})();
