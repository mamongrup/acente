(function () {
  var sections = Array.prototype.slice.call(document.querySelectorAll('.builder-listing-collection'));
  var tenant = document.body.dataset.tenant || '';

  function savedIds() { try { return JSON.parse(localStorage.getItem('nexus_saved_listings') || '[]').map(String); } catch (_) { return []; } }
  function region(item) { return String(item.locality || '').split(',').pop().trim(); }
  function price(item) { return Number(item.priceMinor || 0) / 100; }
  function card(item) {
    var article = document.createElement('article'); article.className = 'category-content-card'; article.dataset.listingId = String(item.id);
    var media = document.createElement('div'); media.className = 'category-content-card-media';
    var link = document.createElement('a'); link.href = window.NEXUS_LISTING_URL ? window.NEXUS_LISTING_URL(item) : '/urunler/' + encodeURIComponent(item.id);
    var image = document.createElement('img'); image.loading = 'lazy'; image.alt = item.title || '';
    var photos = Array.isArray(item.images) ? item.images.filter(Boolean) : [];
    image.src = photos[0] || '/static/chisfis/images/pexels-photo-186077.home.webp';
    link.appendChild(image); media.appendChild(link);
    var favorite = document.createElement('button'); favorite.type = 'button'; favorite.className = 'category-card-favorite';
    function updateFavorite() { var on = savedIds().indexOf(String(item.id)) >= 0; favorite.textContent = on ? '♥' : '♡'; favorite.setAttribute('aria-pressed', String(on)); favorite.setAttribute('aria-label', on ? 'Favorilerden çıkar' : 'Favorilere ekle'); }
    updateFavorite();
    favorite.onclick = function () { var ids = savedIds(), id = String(item.id); ids = ids.indexOf(id) >= 0 ? ids.filter(function (value) { return value !== id; }) : ids.concat(id); localStorage.setItem('nexus_saved_listings', JSON.stringify(ids)); document.querySelectorAll('.category-content-card[data-listing-id="' + CSS.escape(id) + '"] .category-card-favorite').forEach(function (button) { button.textContent = ids.indexOf(id) >= 0 ? '♥' : '♡'; button.setAttribute('aria-pressed', String(ids.indexOf(id) >= 0)); }); };
    media.appendChild(favorite);
    if (photos.length > 1) {
      var photoIndex = 0;
      var dots = document.createElement('div'); dots.className = 'category-card-dots';
      photos.slice(0, 6).forEach(function (_, index) { var dot = document.createElement('i'); dot.classList.toggle('active', index === 0); dots.appendChild(dot); });
      function showPhoto(step) { photoIndex = (photoIndex + step + photos.length) % photos.length; image.src = photos[photoIndex]; dots.querySelectorAll('i').forEach(function (dot, index) { dot.classList.toggle('active', index === photoIndex); }); }
      [-1, 1].forEach(function (step) { var arrow = document.createElement('button'); arrow.type = 'button'; arrow.className = 'category-card-arrow ' + (step < 0 ? 'previous' : 'next'); arrow.setAttribute('aria-label', step < 0 ? 'Önceki fotoğraf' : 'Sonraki fotoğraf'); arrow.addEventListener('click', function (event) { event.preventDefault(); event.stopPropagation(); showPhoto(step); }); media.appendChild(arrow); });
      media.appendChild(dots);
    }
    article.appendChild(media);
    var copy = document.createElement('div'); copy.className = 'category-content-card-copy';
    var type = document.createElement('small'); type.className = 'category-content-card-type'; type.textContent = item.propertyType || item.categoryLabel || ''; copy.appendChild(type);
    var name = document.createElement('a'); name.className = 'category-card-name'; name.href = link.href; name.textContent = item.title || 'İlan'; copy.appendChild(name);
    var locationText = document.createElement('small'); locationText.className = 'category-content-card-location'; locationText.textContent = item.locality || ''; copy.appendChild(locationText);
    var isYacht = item.category === 'yacht';
    var cabins = item.cabinCount || item.bedroomCount;
    var facts = [item.guestCount && item.guestCount + ' misafir', cabins && cabins + (isYacht ? ' kabin' : ' oda'), item.bathroomCount && item.bathroomCount + ' banyo'].filter(Boolean);
    if (facts.length) { var details = document.createElement('small'); details.className = 'category-content-card-details'; details.textContent = facts.join(' · '); copy.appendChild(details); }
    var footer = document.createElement('div'); footer.className = 'category-content-card-footer';
    if (Number(item.priceMinor) > 0) { var amount = document.createElement('span'); amount.className = 'category-content-card-price'; amount.textContent = new Intl.NumberFormat('tr-TR', { style: 'currency', currency: item.currency || 'TRY', maximumFractionDigits: 0 }).format(price(item)); footer.appendChild(amount); }
    var reviewCount = Math.max(0, Number(item.reviewCount) || 0);
    var rating = document.createElement('span'); rating.className = 'category-content-card-rating';
    var star = document.createElement('span'); star.className = 'category-content-card-star'; star.setAttribute('aria-hidden', 'true'); star.textContent = '★';
    var score = document.createElement('strong'); score.textContent = reviewCount && item.ratingAverage != null ? Number(item.ratingAverage).toFixed(1) : '—';
    var count = document.createElement('span'); count.className = 'category-content-card-review-count'; count.textContent = '(' + reviewCount + ')';
    rating.setAttribute('aria-label', reviewCount ? 'Puan ' + score.textContent + ', ' + reviewCount + ' yorum' : 'Henüz yorum yok');
    rating.append(star, score, count); footer.appendChild(rating); copy.appendChild(footer);
    article.appendChild(copy); return article;
  }
  window.NEXUS_BUILDER_LISTING_CARD = card;
  if (!sections.length) return;
  var url = new URL('/api/public/listings', location.origin);
  if (tenant) url.searchParams.set('tenant', tenant);
  var listings = fetch(url.pathname + url.search, { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) { if (!response.ok) throw new Error('listings'); return response.json(); });
  var categories = Array.from(new Set(sections.map(function (section) { try { return JSON.parse(section.dataset.listingConfig || '{}').category || 'holiday_home'; } catch (_) { return 'holiday_home'; } })));
  var filters = Promise.all(categories.map(function (category) {
    return fetch('/api/public/category-filters?kategori=' + encodeURIComponent(category) + (tenant ? '&tenant=' + encodeURIComponent(tenant) : ''), { credentials: 'same-origin' })
      .then(function (response) { return response.ok ? response.json() : []; }).catch(function () { return []; });
  })).then(function (lists) { return lists.flat(); });
  var campaigns = fetch('/api/public/campaigns' + (tenant ? '?tenant=' + encodeURIComponent(tenant) : ''), { credentials: 'same-origin' })
    .then(function (response) { return response.ok ? response.json() : []; }).catch(function () { return []; });
  function matches(item, config, value) {
    if (config.mode === 'region') return region(item).toLocaleLowerCase('tr-TR') === value.toLocaleLowerCase('tr-TR');
    if (config.mode === 'type') return String(item.propertyType || '').toLocaleLowerCase('tr-TR') === value.toLocaleLowerCase('tr-TR');
    if (config.mode === 'theme') return Array.isArray(item.amenities) && item.amenities.some(function (amenity) { return String(amenity).toLocaleLowerCase('tr-TR') === value.toLocaleLowerCase('tr-TR'); });
    return true;
  }
  function render(section, allItems, groups, activeCampaigns) {
    var config; try { config = JSON.parse(section.dataset.listingConfig || '{}'); } catch (_) { config = {}; }
    var content = section.querySelector('.builder-listing-collection-content'); if (!content) return;
    var category = config.category || 'holiday_home';
    var items = allItems.filter(function (item) { return item.category === category; });
    var mode = config.mode || 'region';
    var choices = Array.isArray(config.values) ? config.values.filter(Boolean) : [];
    var limit = Math.min(24, Math.max(1, Number(config.limit) || 8));
    if (['region', 'theme', 'type'].indexOf(mode) >= 0 && !choices.length) items = [];
    if (mode === 'budget') items = items.filter(function (item) { return (!config.currency || item.currency === config.currency) && (!config.minPrice || price(item) >= Number(config.minPrice)) && (!config.maxPrice || price(item) <= Number(config.maxPrice)); });
    if (mode === 'campaign') { var ids = Array.isArray(config.listingIds) ? config.listingIds.map(String) : []; var active = activeCampaigns.some(function (campaign) { return campaign.id === config.campaignId; }); items = active ? items.filter(function (item) { return ids.indexOf(String(item.id)) >= 0; }) : []; }
    var tabLabels = {};
    if (mode === 'theme') groups.filter(function (group) { return group.key === 'theme' && group.category === category; }).forEach(function (group) { (group.items || []).forEach(function (option) { tabLabels[option.contractValue || option.key] = option.title; }); });
    var nav = document.createElement('div'); nav.className = 'category-region-nav';
    var tabs = document.createElement('div'); tabs.className = 'category-region-tabs'; tabs.setAttribute('role', 'tablist');
    var panel = document.createElement('div'); panel.className = 'builder-listing-collection-panel';
    function show(value) {
      var selected = choices.length && value ? items.filter(function (item) { return matches(item, config, value); }) : items;
      panel.replaceChildren();
      if (!selected.length) { var empty = document.createElement('p'); empty.className = 'category-theme-empty'; empty.textContent = 'Bu seçimde yayınlanmış ilan bulunmuyor.'; panel.appendChild(empty); return; }
      var grid = document.createElement('div'); grid.className = 'category-content-grid'; selected.slice(0, limit).forEach(function (item) { grid.appendChild(card(item)); }); panel.appendChild(grid);
    }
    if (['region', 'theme', 'type'].indexOf(mode) >= 0 && choices.length) {
      choices.forEach(function (value, index) { var button = document.createElement('button'); button.type = 'button'; button.textContent = tabLabels[value] || value; button.setAttribute('role', 'tab'); button.setAttribute('aria-selected', String(index === 0)); button.onclick = function () { tabs.querySelectorAll('button').forEach(function (tab) { tab.setAttribute('aria-selected', String(tab === button)); }); show(value); }; tabs.appendChild(button); });
      nav.appendChild(tabs); content.appendChild(nav); show(choices[0]);
    } else show('');
    content.appendChild(panel);
  }
  Promise.all([listings, filters, campaigns]).then(function (data) { sections.forEach(function (section) { render(section, Array.isArray(data[0]) ? data[0] : [], Array.isArray(data[1]) ? data[1] : [], Array.isArray(data[2]) ? data[2] : []); }); }).catch(function () { sections.forEach(function (section) { var content = section.querySelector('.builder-listing-collection-content'); if (content) content.textContent = 'İlanlar şu anda yüklenemiyor.'; }); });
})();
