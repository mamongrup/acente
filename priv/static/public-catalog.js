/*
 * Public catalogue surfaces
 * --------------------------
 * The control panel exposes one catalogue with several service categories.
 * This small client layer gives every category the same Chisfis-inspired
 * landing/detail shell while keeping listing data and booking endpoints on
 * the server. It is intentionally progressive: pages still render useful
 * content when JavaScript is unavailable.
 */
(function () {
  'use strict';

  // The home route renders the shared desktop header in a wrapper div while
  // inner pages use a semantic header element. Give both the same hook so
  // spacing, width and reveal behavior stay identical everywhere.
  (function normalizeSharedHeader() {
    var first = document.body && document.body.firstElementChild;
    if (!first) return;
    var desktop = first.firstElementChild && /\brelative\b/.test(desktopClass(first.firstElementChild));
    if (desktop && !first.classList.contains('chisfis-header-root')) first.classList.add('chisfis-header-root');
  }());

  function desktopClass(node) { return typeof node.className === 'string' ? node.className : ''; }

  var IMAGE_ROOT = '/static/chisfis/images/';
  var CATEGORIES = {
    hotel: {
      title: 'Oteller',
      heroTitle: 'Hayalinizdeki Otel',
      eyebrow: 'KONAKLAMA',
      description: 'Şehir otellerinden sahil resortlarına kadar doğrulanmış konaklama seçeneklerini karşılaştırın.',
      image: 'hero-right.webp',
      cta: 'Otel ara',
      unit: 'gece',
      booking: 'Oda müsaitliğini kontrol et',
      features: ['24/7 destek', 'Güvenli rezervasyon', 'Esnek iptal seçenekleri']
    },
    holiday_home: {
      title: 'Tatil evleri',
      eyebrow: 'KONAKLAMA',
      description: 'Aileniz ve arkadaşlarınız için villa, apart, bungalov, daire ve residence tatil evlerini keşfedin.',
      image: '5.0-cyep_wbo5i3.webp',
      cta: 'Tatil evi ara',
      unit: 'gece',
      booking: 'Tarih ve misafirleri seç',
      features: ['Özel alan', 'Yerel ev sahipleri', 'Uzun konaklama fırsatları']
    },
    yacht: {
      title: 'Yat ve tekne deneyimleri',
      eyebrow: 'DENİZ',
      description: 'Kaptanlı yat turları, günlük tekne gezileri ve özel deniz kaçamaklarını tek yerde bulun.',
      image: 'HIW2.webp',
      cta: 'Tekne ara',
      unit: 'gün',
      booking: 'Tekne tarihini seç',
      features: ['Kaptanlı seçenekler', 'Rota önerileri', 'Liman desteği']
    },
    tour: {
      title: 'Turlar',
      eyebrow: 'KEŞFET',
      description: 'Şehir turları, kültür rotaları ve rehberli günlük gezilerle bulunduğunuz yeri yakından tanıyın.',
      image: '6.15d7hd4mb~4yd.webp',
      cta: 'Tur keşfet',
      unit: 'kişi',
      booking: 'Tur tarihini seç',
      features: ['Yerel rehberler', 'Küçük gruplar', 'Kolay rezervasyon']
    },
    activity: {
      title: 'Aktiviteler',
      eyebrow: 'DENEYİM',
      description: 'Spor, doğa ve şehir aktiviteleriyle seyahatinizi size özel bir deneyime dönüştürün.',
      image: 'HIW3.10ja0mcrcg_7_.webp',
      cta: 'Aktivite ara',
      unit: 'kişi',
      booking: 'Aktivite tarihini seç',
      features: ['Anında talep', 'Doğrulanmış sağlayıcılar', 'Güvenli ödeme']
    },
    flight: {
      title: 'Uçuş',
      eyebrow: 'ULAŞIM',
      description: 'Uçuş seçeneklerini karşılaştırın, rotanızı kolayca planlayın.',
      image: 'hero-right.webp',
      cta: 'Uçuş ara',
      unit: 'kişi',
      booking: 'Yolculuk tarihini seç',
      features: ['Geniş rota ağı', 'Şeffaf fiyatlar', 'Destek ekibi']
    },
    bus: {
      title: 'Otobüs',
      eyebrow: 'ULAŞIM',
      description: 'Şehirler arası otobüs seçeneklerini karşılaştırın, rotanızı kolayca planlayın.',
      image: 'hero-right.webp',
      cta: 'Otobüs ara',
      unit: 'kişi',
      booking: 'Yolculuk tarihini seç',
      features: ['Geniş rota ağı', 'Şeffaf fiyatlar', 'Destek ekibi']
    },
    transfer: {
      title: 'Transfer',
      eyebrow: 'ULAŞIM',
      description: 'Havalimanı, otel ve şehir içi transferlerinizi güvenilir sürücülerle önceden planlayın.',
      image: '4.0w6tqzlhplq.q.webp',
      cta: 'Transfer ara',
      unit: 'transfer',
      booking: 'Transfer tarihini seç',
      features: ['Karşılama hizmeti', 'Sabit fiyat', 'Dakik sürücüler']
    },
    ferry: {
      title: 'Feribot',
      eyebrow: 'ULAŞIM',
      description: 'Ada ve kıyı rotaları için feribot seferlerini, saatleri ve bilet seçeneklerini bulun.',
      image: 'HIW2.webp',
      cta: 'Feribot ara',
      unit: 'kişi',
      booking: 'Feribot tarihini seç',
      features: ['Kıyı rotaları', 'Esnek seferler', 'Kolay biletleme']
    },
    car: {
      title: 'Araç kiralama',
      eyebrow: 'ULAŞIM',
      description: 'İhtiyacınıza uygun otomobil, SUV ve minibüs seçeneklerini güvenli biçimde kiralayın.',
      image: '4.0w6tqzlhplq.q.webp',
      cta: 'Araç ara',
      unit: 'gün',
      booking: 'Kiralama tarihini seç',
      features: ['Teslim alma noktaları', 'Şeffaf teminat', '7/24 yol desteği']
    },
    cruise: {
      title: 'Kruvaziyer',
      eyebrow: 'DENİZ',
      description: 'Birden fazla limanı tek seyahatte keşfedeceğiniz kruvaziyer rotalarını karşılaştırın.',
      image: '5.0-cyep_wbo5i3.webp',
      cta: 'Kruvaziyer ara',
      unit: 'kişi',
      booking: 'Kruvaziyer tarihini seç',
      features: ['Çoklu liman rotaları', 'Konforlu kabinler', 'Uzman danışmanlık']
    },
    pilgrimage: {
      title: 'Hac ve Umre',
      eyebrow: 'İNANÇ TURİZMİ',
      description: 'Hac ve Umre yolculuğunuzu konaklama, ulaşım ve rehberlik hizmetleriyle birlikte planlayın.',
      image: '6.15d7hd4mb~4yd.webp',
      cta: 'Paketleri incele',
      unit: 'kişi',
      booking: 'Paket tarihini seç',
      features: ['Yetkili acenteler', 'Kapsamlı paketler', 'Seyahat danışmanlığı']
    },
    visa: {
      title: 'Vize hizmetleri',
      eyebrow: 'SEYAHAT HİZMETİ',
      description: 'Belgeleriniz, randevunuz ve başvuru takibiniz için güvenilir vize danışmanlığı alın.',
      image: 'HIW1.0pyy~70or-44f.webp',
      cta: 'Vize hizmeti ara',
      unit: 'başvuru',
      booking: 'Danışmanlık talep et',
      features: ['Belge kontrolü', 'Başvuru takibi', 'Ülkeye özel rehberlik']
    },
    beach: {
      title: 'Plaj ve şezlong',
      eyebrow: 'DENİZ',
      description: 'Popüler plajlarda şezlong, loca ve günübirlik sahil deneyimlerini önceden ayırtın.',
      image: 'hero-right.webp',
      cta: 'Plaj ara',
      unit: 'gün',
      booking: 'Plaj tarihini seç',
      features: ['Popüler sahiller', 'Günübirlik kullanım', 'Kolay iptal']
    },
    cinema: {
      title: 'Sinema',
      eyebrow: 'EĞLENCE',
      description: 'Vizyondaki filmler için salon, seans ve bilet seçeneklerini tek ekranda keşfedin.',
      image: 'HIW3.10ja0mcrcg_7_.webp',
      cta: 'Seans ara',
      unit: 'bilet',
      booking: 'Seans seç',
      features: ['Güncel seanslar', 'Salon karşılaştırma', 'Hızlı biletleme']
    },
    event: {
      title: 'Etkinlikler',
      eyebrow: 'EĞLENCE',
      description: 'Konser, festival, gösteri ve şehir etkinlikleri için biletinizi erkenden ayırtın.',
      image: 'HIW2.webp',
      cta: 'Etkinlik ara',
      unit: 'bilet',
      booking: 'Etkinlik tarihini seç',
      features: ['Şehir etkinlikleri', 'Doğrulanmış bilet', 'Takvim hatırlatıcıları']
    },
    restaurant: {
      title: 'Restoranlar',
      eyebrow: 'LEZZET',
      description: 'Yerel mutfakları, seçkin restoranları ve özel menüleri kolayca keşfedin.',
      image: '5.0-cyep_wbo5i3.webp',
      cta: 'Masa ara',
      unit: 'masa',
      booking: 'Masa tarihini seç',
      features: ['Yerel lezzetler', 'Özel menüler', 'Masa garantisi']
    }
  };

  window.NEXUS_CATEGORY_CONTENT = CATEGORIES;

  function canonicalCategory(slug) {
    var value = String(slug || '').toLowerCase().trim();
    if (value === 'villa') return 'holiday_home';
    if (value === 'flight_bus') return 'flight';
    if (value === 'hajj') return 'pilgrimage';
    if (value === 'sunbed') return 'beach';
    return value;
  }

  function categoryFromPath() {
    var categoryCode = window.NEXUS_CATEGORY_CODE && window.NEXUS_CATEGORY_CODE(location.pathname);
    if (categoryCode) return canonicalCategory(categoryCode);
    var main = document.querySelector('main[class*="category-"]');
    if (main) {
      var found = Array.prototype.slice.call(main.classList).find(function (c) { return c.indexOf('category-') === 0 && c !== 'category-page'; });
      if (found) return canonicalCategory(found.slice('category-'.length));
    }
    var aliases = { 'stay-categories-page': 'hotel', 'experiences-page': 'tour', 'car-page': 'car', 'flights-page': 'flight' };
    return Object.keys(aliases).find(function (key) { return document.body.classList.contains(key); }) ? aliases[Object.keys(aliases).find(function (key) { return document.body.classList.contains(key); })] : '';
  }

  function currentLang() {
    var match = document.cookie.match(/(?:^|;\s*)nexus_lang=([^;]*)/);
    return match ? decodeURIComponent(match[1]) : 'tr';
  }

  function createManagedFilters(slug) {
    var section = document.createElement('section');
    section.className = 'category-managed-filters';
    section.setAttribute('aria-live', 'polite');
    var tenant = new URLSearchParams(location.search).get('tenant') || document.body.dataset.tenant || '';
    var params = new URLSearchParams();
    params.set('category', slug);
    params.set('lang', currentLang());
    if (tenant) params.set('tenant', tenant);
    fetch('/api/public/category-filters?' + params.toString(), { credentials: 'same-origin', cache: 'no-store' })
      .then(function (response) {
        if (!response.ok) throw new Error('filters');
        return response.json();
      })
      .then(function (groups) {
        if (!Array.isArray(groups) || !groups.length) return;
        section.innerHTML = '<div class="home-section-heading"><span class="eyebrow">FİLTRELER</span><h2>Seçenekleri daraltın</h2><p class="muted">Bu kategoriye ait alt tip ve filtreler admin panelinden yönetilir.</p></div><div class="category-filter-groups"></div>';
        var wrap = section.querySelector('.category-filter-groups');
        groups.forEach(function (group) {
          var card = document.createElement('article');
          card.className = 'category-filter-group';
          var title = document.createElement('h3');
          title.textContent = group.title || group.key;
          card.appendChild(title);
          if (group.helpText) {
            var help = document.createElement('p');
            help.textContent = group.helpText;
            card.appendChild(help);
          }
          var chips = document.createElement('div');
          chips.className = 'category-filter-chips';
          (group.items || []).forEach(function (item) {
            var link = document.createElement('a');
            var href = new URL('/urunler', location.origin);
            href.searchParams.set('kategori', canonicalCategory(slug));
            href.searchParams.set('filter_key', item.contractFieldKey || group.key);
            href.searchParams.set('filter_value', item.contractValue || item.key);
            if (tenant) href.searchParams.set('tenant', tenant);
            link.href = href.pathname + href.search;
            link.textContent = item.title || item.key;
            chips.appendChild(link);
          });
          card.appendChild(chips);
          wrap.appendChild(card);
        });
      })
      .catch(function () {
        section.remove();
      });
    return section;
  }

  function initCategoryLanding() {
    var body = document.body;
    if (!body.classList.contains('category-page')) return;
    var slug = categoryFromPath();
    body.dataset.category = slug || 'hotel';
    body.classList.add('category-' + (slug || 'hotel'));
    var listings = document.querySelector('.category-listings');
    if (listings && !document.querySelector('.category-managed-filters')) {
      var heading = listings && listings.querySelector('.home-section-heading');
      var filters = createManagedFilters(slug);
      if (heading) heading.insertAdjacentElement('afterend', filters);
      else if (listings) listings.appendChild(filters);
    }
    // Server-rendered category cards carry their gallery in data-images.
    // Paint the first image immediately so the landing page never shows a
    // blank placeholder while the listing enhancement script is idle.
    document.querySelectorAll('.category-listings .product-card-media[data-images]').forEach(function (media) {
      if (media.style.backgroundImage) return;
      try {
        var images = JSON.parse(media.getAttribute('data-images') || '[]');
        var first = Array.isArray(images) ? images[0] : '';
        // Yalnızca güvenli şemalar; url() içine gömmeden önce `)` ve tırnak
        // karakterleri silinir (CSS injection'a kapalı arka plan ataması).
        var url = String(first || '').trim();
        var safe = (/^https?:\/\//i.test(url) || /^\/(?!\/)/.test(url)) &&
          !/[()"']/.test(url);
        if (Array.isArray(images) && images[0] && safe) {
          media.style.backgroundImage = 'url("' + url + '")';
        }
      } catch (_) {}
    });
  }

  function detailIcon(name) {
    var icon = { heart: 'favourite', share: 'share-08', location: 'location-01' }[name] || 'location-01';
    return '<i class="hgi-stroke hgi-' + icon + ' detail-line-icon" aria-hidden="true"></i>';
  }

  function initDetail() {
    var main = document.querySelector('main.product-detail');
    if (!main || main.dataset.detailLayoutReady) return;
    main.dataset.detailLayoutReady = 'true';
    var categoryClass = Array.prototype.slice.call(main.classList).find(function (c) { return c.indexOf('category-') === 0 && c !== 'product-detail'; });
    var slug = categoryClass ? canonicalCategory(categoryClass.slice(9)) : 'hotel';
    var cfg = CATEGORIES[slug] || CATEGORIES.hotel;
    document.body.dataset.category = slug;
    document.body.classList.add('category-detail-page', 'category-' + slug);
    main.dataset.category = slug;

    var gallery = main.querySelector(':scope > .detail-gallery');
    var breadcrumb = main.querySelector(':scope > nav, :scope > .breadcrumb, :scope > [aria-label="Breadcrumb"]');
    if (gallery && breadcrumb && gallery.nextElementSibling !== breadcrumb) gallery.insertAdjacentElement('afterend', breadcrumb);

    var sections = Array.prototype.slice.call(main.querySelectorAll(':scope > .listingSection__wrap'));
    var sidebar = main.querySelector(':scope > .grow');
    if ((sections.length || sidebar) && !main.querySelector(':scope > .detail-columns')) {
      var columns = document.createElement('div');
      columns.className = 'detail-columns';
      var detailMain = document.createElement('div');
      detailMain.className = 'detail-main';
      sections.forEach(function (section) { detailMain.appendChild(section); });
      columns.appendChild(detailMain);
      if (sidebar) { sidebar.classList.add('detail-sidebar'); columns.appendChild(sidebar); }
      var anchor = breadcrumb && breadcrumb.parentElement === main ? breadcrumb : gallery;
      if (anchor) anchor.insertAdjacentElement('afterend', columns);
      else main.appendChild(columns);
    }

    var detailMain = main.querySelector('.detail-main');
    var intro = detailMain && detailMain.querySelector(':scope > .listingSection__wrap:first-child');
    var description = detailMain && detailMain.querySelector('.product-description');
    if (intro) intro.classList.add('detail-intro');
    var descriptionSection = description && description.closest('.listingSection__wrap');
    if (descriptionSection && !descriptionSection.querySelector('h2')) {
      var heading = document.createElement('h2');
      heading.textContent = slug === 'hotel' || slug === 'holiday_home' ? 'Konaklama hakkında' : 'İlan hakkında';
      descriptionSection.insertBefore(heading, description);
    }
    var availability = detailMain && detailMain.querySelector('#public-availability');
    var availabilityHeading = availability && availability.closest('.listingSection__wrap').querySelector('h2');
    if (availabilityHeading) availabilityHeading.textContent = 'Müsaitlik';

    var favorite = intro && intro.querySelector('.detail-favorite');
    if (favorite) {
      favorite.innerHTML = detailIcon('heart');
      favorite.setAttribute('aria-label', 'Favorilere ekle');
      favorite.setAttribute('aria-pressed', 'false');
      favorite.addEventListener('click', function () {
        var ids = [];
        try { ids = JSON.parse(localStorage.getItem('nexus_saved_listings') || '[]'); } catch (_) {}
        if (!Array.isArray(ids)) ids = [];
        var id = location.pathname.split('/').pop();
        ids = ids.indexOf(id) < 0 ? ids.concat(id) : ids.filter(function (item) { return item !== id; });
        try { localStorage.setItem('nexus_saved_listings', JSON.stringify(ids)); } catch (_) {}
        var saved = ids.indexOf(id) >= 0;
        favorite.classList.toggle('is-active', saved);
        favorite.setAttribute('aria-pressed', String(saved));
        favorite.setAttribute('aria-label', saved ? 'Favorilerden çıkar' : 'Favorilere ekle');
      });
    }
    var locationNode = intro && intro.querySelector('.detail-location');
    if (locationNode && !locationNode.querySelector('.detail-line-icon')) locationNode.insertAdjacentHTML('afterbegin', detailIcon('location'));
    var share = intro && intro.querySelector('.share-actions button');
    if (share) { share.innerHTML = detailIcon('share'); share.setAttribute('aria-label', 'Bağlantıyı kopyala'); share.setAttribute('title', 'Bağlantıyı kopyala'); }

    var booking = main.querySelector('#booking-form');
    if (booking) {
      var submit = booking.querySelector('button[type="submit"]');
      if (submit) submit.textContent = cfg.booking;
      var formSection = booking.closest('.listingSection__wrap');
      if (formSection) formSection.dataset.category = slug;
    }
    var similar = detailMain && detailMain.querySelector('a[href*="/urunler?kategori"]');
    if (similar) similar.textContent = cfg.title + ' seçeneklerini keşfet →';
  }

  function init() {
    initCategoryLanding();
    initDetail();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
