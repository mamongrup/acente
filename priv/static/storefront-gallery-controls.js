(function () {
  'use strict';
  var photoSets = [
    ['6129967', '261394', '2861361', '2677398'],
    ['261394', '6129967', '2677398', '2861361'],
    ['2861361', '2677398', '6129967', '261394'],
    ['2677398', '2861361', '261394', '6129967'],
    ['1320686', '7163619', '6527036', '6969831'],
    ['7163619', '1320686', '6969831', '6527036'],
    ['6527036', '6969831', '1320686', '7163619'],
    ['6969831', '6527036', '7163619', '1320686']
  ];
  function initDestinations() {
    document.querySelectorAll('section .mySnapItem').forEach(function (item) {
      var section = item.closest('section');
      if (!section || section.dataset.destinationCarousel) return;
      var rail = item.parentElement;
      var buttons = Array.from(section.querySelectorAll('button')).filter(function (button) { return button.querySelector('.hgi-arrow-left-01,.hgi-arrow-right-01'); });
      if (buttons.length < 2) return;
      section.dataset.destinationCarousel = 'true';
      section.classList.add('nx-destination-carousel');
      function syncArrows() {
        var atStart = rail.scrollLeft < 4;
        var atEnd = rail.scrollLeft >= rail.scrollWidth - rail.clientWidth - 4;
        buttons.forEach(function (button) {
          var previous = !!button.querySelector('.hgi-arrow-left-01');
          var inactive = previous ? atStart : atEnd;
          button.disabled = inactive;
          button.toggleAttribute('data-disabled', inactive);
          button.setAttribute('aria-disabled', String(inactive));
        });
      }
      buttons.forEach(function (button) {
        var previous = !!button.querySelector('.hgi-arrow-left-01');
        button.classList.remove('cursor-default');
        button.classList.add('nx-destination-arrow');
        button.setAttribute('aria-label', previous ? 'Önceki yerler' : 'Sonraki yerler');
        button.addEventListener('click', function (event) {
          event.preventDefault();
          event.stopPropagation();
          var width = item.getBoundingClientRect().width;
          var end = rail.scrollWidth - rail.clientWidth;
          var target = Math.max(0, Math.min(end, rail.scrollLeft + (previous ? -width : width)));
          rail.scrollTo({ left: target, behavior: 'smooth' });
        });
      });
      rail.addEventListener('scroll', syncArrows, { passive: true });
      syncArrows();
    });
  }
  function initGalleries() {
    document.querySelectorAll('div[class*="group/cardGallerySlider"]').forEach(function (gallery, index) {
      if (gallery.dataset.galleryControls) return;
      var image = gallery.querySelector('a > div > img');
      var layer = Array.from(gallery.children).find(function (node) { return node.className && String(node.className).includes('opacity-0'); });
      if (!image || !layer || !photoSets[index]) return;
      var wraps = [image.parentElement];
      photoSets[index].slice(1).forEach(function (id) {
        var wrap = wraps[0].cloneNode(true);
        wrap.style.opacity = '0';
        wrap.querySelector('img').src = '/static/chisfis/images/pexels-photo-' + id + '.home.webp';
        wraps[0].parentElement.appendChild(wrap);
        wraps.push(wrap);
      });
      var nextWrap = layer.querySelector('[class*="end-"]');
      if (!nextWrap) return;
      var previousWrap = layer.querySelector('[class*="start-"]');
      if (!previousWrap) {
        previousWrap = nextWrap.cloneNode(true);
        previousWrap.className = 'absolute start-3 top-[calc(50%-1rem)]';
        previousWrap.querySelector('i').className = 'hgi-stroke hgi-arrow-left-01 size-4!';
        layer.insertBefore(previousWrap, nextWrap);
      }
      var buttons = [previousWrap.querySelector('button'), nextWrap.querySelector('button')];
      var dots = Array.from(gallery.querySelectorAll('.absolute.bottom-2 button'));
      var current = 0;
      function show(index) {
        current = (index + wraps.length) % wraps.length;
        wraps.forEach(function (wrap, position) { wrap.style.opacity = String(position === current ? 1 : 0); });
        dots.forEach(function (dot, position) { dot.style.opacity = position === current ? '1' : '.55'; });
      }
      buttons.forEach(function (button, position) {
        button.classList.add('nx-demo-gallery-arrow', position === 0 ? 'nx-arrow-previous' : 'nx-arrow-next');
        button.setAttribute('aria-label', position === 0 ? 'Önceki fotoğraf' : 'Sonraki fotoğraf');
        button.addEventListener('click', function (event) { event.preventDefault(); event.stopPropagation(); show(current + (position === 0 ? -1 : 1)); });
      });
      dots.forEach(function (dot, position) { dot.addEventListener('click', function (event) { event.preventDefault(); event.stopPropagation(); show(position); }); });
      gallery.dataset.galleryControls = 'true';
      show(0);
    });
  }
  var scheduled = false;
  function init() { scheduled = false; initDestinations(); initGalleries(); }
  function schedule() { if (scheduled) return; scheduled = true; requestAnimationFrame(init); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', schedule, { once: true }); else schedule();
  new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });

  function renderLiveGallery(gallery, photos) {
    var link = gallery.querySelector('a');
    var layer = Array.from(gallery.children).find(function (node) { return node.classList.contains('opacity-0'); });
    var dots = gallery.querySelector('.absolute.bottom-2');
    if (!link || !layer || !dots) return;
    var images = photos.filter(function (photo) { return typeof photo === 'string' && photo.length > 0; }).slice(0, 8);
    if (!images.length) images = ['/static/chisfis/images/pexels-photo-6129967.home.webp'];
    var wraps = images.map(function (src, position) {
      var wrap = document.createElement('div');
      wrap.className = 'absolute inset-0';
      var image = document.createElement('img');
      image.className = 'rounded-xl object-cover';
      image.alt = 'İlan görseli';
      image.loading = 'lazy';
      image.style.cssText = 'position:absolute;height:100%;width:100%;inset:0';
      image.onerror = function () {
        image.onerror = function () { image.onerror = null; image.src = '/static/chisfis/images/pexels-photo-6129967.home.webp'; };
        image.src = images[(position + 1) % images.length] || '/static/chisfis/images/pexels-photo-6129967.home.webp';
      };
      image.src = src;
      wrap.appendChild(image);
      return wrap;
    });
    link.replaceChildren.apply(link, wraps);
    layer.replaceChildren();
    dots.replaceChildren();
    var current = 0;
    var dotButtons = images.map(function (_, index) {
      var dot = document.createElement('button');
      dot.type = 'button';
      dot.className = 'h-1.5 w-1.5 rounded-full bg-white';
      dot.setAttribute('aria-label', (index + 1) + '. fotoğraf');
      dot.addEventListener('click', function (event) { event.preventDefault(); event.stopPropagation(); show(index); });
      dots.appendChild(dot);
      return dot;
    });
    function show(index) {
      current = (index + images.length) % images.length;
      wraps.forEach(function (wrap, position) { wrap.style.opacity = position === current ? '1' : '0'; });
      dotButtons.forEach(function (dot, position) { dot.style.opacity = position === current ? '1' : '.55'; });
    }
    if (images.length > 1) {
      [-1, 1].forEach(function (step) {
        var wrapper = document.createElement('div');
        wrapper.className = 'absolute ' + (step < 0 ? 'start-3' : 'end-3') + ' top-[calc(50%-1rem)]';
        var button = document.createElement('button');
        button.type = 'button';
        button.className = 'nx-demo-gallery-arrow ' + (step < 0 ? 'nx-arrow-previous' : 'nx-arrow-next');
        button.setAttribute('aria-label', step < 0 ? 'Önceki fotoğraf' : 'Sonraki fotoğraf');
        button.addEventListener('click', function (event) { event.preventDefault(); event.stopPropagation(); show(current + step); });
        wrapper.appendChild(button);
        layer.appendChild(wrapper);
      });
    } else {
      dots.hidden = true;
    }
    show(0);
  }

  function hydrateHomeListings() {
    var galleries = Array.from(document.querySelectorAll('body.chisfis-home div[class*="group/cardGallerySlider"]'));
    if (!galleries.length) return;
    var grid = galleries[0].parentElement.parentElement.parentElement;
    var section = grid.parentElement;
    var cards = Array.from(grid.children);
    fetch('/api/public/listings', { credentials: 'same-origin' }).then(function (response) {
      if (!response.ok) throw new Error('İlanlar yüklenemedi');
      return response.json();
    }).then(function (listings) {
      if (!Array.isArray(listings) || !listings.length) { section.hidden = true; return; }
      listings.slice(0, cards.length).forEach(function (listing, index) {
        var card = cards[index];
        var gallery = card.querySelector('div[class*="group/cardGallerySlider"]');
        var links = card.querySelectorAll('a[href]');
        var detail = window.NEXUS_LISTING_URL ? window.NEXUS_LISTING_URL(listing) : '/urunler/' + encodeURIComponent(listing.id);
        links.forEach(function (link) { link.href = detail; });
        renderLiveGallery(gallery, Array.isArray(listing.images) ? listing.images : []);
        var copy = links[links.length - 1];
        var title = copy.querySelector('h2 span');
        if (title) title.textContent = listing.title || 'İlan';
        var type = copy.querySelector('[data-home-dynamic-key]');
        if (type) {
          type.textContent = listing.categoryLabel || listing.category || '';
          type.removeAttribute('data-home-dynamic-key');
          type.removeAttribute('data-i18n');
        }
        var locationIcon = copy.querySelector('.hgi-location-01');
        var location = locationIcon && locationIcon.parentElement.querySelector('span');
        if (location) location.textContent = listing.locality || '';
        var price = copy.querySelector('.items-center.justify-between .font-semibold');
        if (price) {
          var amount = Number(listing.priceMinor || 0) / 100;
          price.textContent = new Intl.NumberFormat('tr-TR', { style: 'currency', currency: listing.currency || 'TRY', maximumFractionDigits: 0 }).format(amount);
        }
        if (listing.category !== 'hotel' && listing.category !== 'holiday_home') {
          var period = copy.querySelector('[data-home-dynamic-key="gece"]');
          if (period) {
            var separator = period.previousElementSibling;
            if (separator) separator.hidden = true;
            period.hidden = true;
          }
        }
        var ratingIcon = copy.querySelector('.hgi-star');
        var rating = ratingIcon && ratingIcon.closest('.flex.items-center.gap-x-1');
        if (rating) {
          if (listing.ratingAverage) {
            var parts = rating.querySelectorAll('span');
            if (parts[0]) parts[0].textContent = listing.ratingAverage;
            if (parts[1]) parts[1].textContent = '(' + (listing.reviewCount || 0) + ')';
          } else rating.remove();
        }
        var discount = card.querySelector('.border-red-100');
        if (discount) discount.remove();
        card.removeAttribute('data-city');
      });
      cards.slice(Math.min(listings.length, cards.length)).forEach(function (card) { card.hidden = true; });
      var header = section.firstElementChild;
      var heading = header && header.querySelector('h2');
      var subtitle = header && header.querySelector('h2 + p');
      var cityTabs = header && header.querySelector('[role="tablist"]');
      if (heading) { heading.textContent = 'Öne çıkan ilanlar'; heading.removeAttribute('data-i18n'); heading.removeAttribute('data-home-i18n'); }
      if (subtitle) { subtitle.textContent = 'Yayındaki konaklama ve deneyimleri keşfedin.'; subtitle.removeAttribute('data-i18n'); subtitle.removeAttribute('data-home-i18n'); }
      if (cityTabs) cityTabs.hidden = true;
      if (section.lastElementChild !== grid) section.lastElementChild.hidden = true;
      section.dataset.liveReady = 'true';
    }).catch(function () { section.hidden = true; });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', hydrateHomeListings, { once: true });
  else hydrateHomeListings();
})();
