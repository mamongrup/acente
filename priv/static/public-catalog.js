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

  var DIRECTORY = [
    ['hotel', 'Oteller'], ['holiday_home', 'Tatil evleri'], ['yacht', 'Yat ve tekneler'],
    ['tour', 'Turlar'], ['activity', 'Aktiviteler'], ['flight', 'Uçuş'],
    ['car', 'Araç kiralama'], ['cruise', 'Kruvaziyer'], ['pilgrimage', 'Hac ve Umre'],
    ['visa', 'Vize'], ['ferry', 'Feribot'], ['transfer', 'Transfer'],
    ['beach', 'Plaj ve şezlong'], ['cinema', 'Sinema'], ['event', 'Etkinlikler'],
    ['restaurant', 'Restoranlar'], ['bus', 'Otobüs']
  ];

  function canonicalCategory(slug) {
    var value = String(slug || '').toLowerCase().trim();
    if (value === 'villa') return 'holiday_home';
    if (value === 'flight_bus') return 'flight';
    if (value === 'hajj') return 'pilgrimage';
    if (value === 'sunbed') return 'beach';
    return value;
  }

  function categoryFromPath() {
    var match = location.pathname.match(/\/kategori\/([^/]+)/i);
    if (match) return canonicalCategory(decodeURIComponent(match[1]));
    var pathAliases = {
      '/konaklama-kategoriler': 'hotel',
      '/deneyimler': 'tour',
      '/emlak': 'holiday_home',
      '/arac': 'car',
      '/ucus': 'flight',
      '/otobus': 'bus'
    };
    if (pathAliases[location.pathname]) return pathAliases[location.pathname];
    var main = document.querySelector('main[class*="category-"]');
    if (main) {
      var found = Array.prototype.slice.call(main.classList).find(function (c) { return c.indexOf('category-') === 0 && c !== 'category-page'; });
      if (found) return canonicalCategory(found.slice('category-'.length));
    }
    var aliases = { 'stay-categories-page': 'hotel', 'experiences-page': 'tour', 'car-page': 'car', 'flights-page': 'flight' };
    return Object.keys(aliases).find(function (key) { return document.body.classList.contains(key); }) ? aliases[Object.keys(aliases).find(function (key) { return document.body.classList.contains(key); })] : '';
  }

  function hrefFor(slug) {
    var query = new URLSearchParams(location.search).get('tenant');
    return '/kategori/' + encodeURIComponent(slug) + (query ? '?tenant=' + encodeURIComponent(query) : '');
  }

  function createDirectory(current) {
    var section = document.createElement('section');
    section.className = 'category-directory';
    section.innerHTML = '<div class="home-section-heading centered"><span class="eyebrow">KEŞFET</span><h2>Kategoriye göre keşfedin</h2><p class="muted">Seyahatinizin her adımını tek bir yerden planlayın.</p></div><div class="category-directory-grid"></div>';
    var grid = section.querySelector('.category-directory-grid');
    DIRECTORY.forEach(function (item) {
      var a = document.createElement('a');
      a.className = 'category-directory-card' + (item[0] === current ? ' is-active' : '');
      a.href = hrefFor(item[0]);
      a.innerHTML = '<span class="category-directory-icon" aria-hidden="true">' + (item[0] === current ? '●' : '○') + '</span><span><strong>' + item[1] + '</strong><small>' + (CATEGORIES[item[0]] ? CATEGORIES[item[0]].eyebrow : 'SEYAHAT') + '</small></span><span aria-hidden="true">→</span>';
      grid.appendChild(a);
    });
    return section;
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
    var cfg = CATEGORIES[slug] || CATEGORIES.hotel;
    body.dataset.category = slug || 'hotel';
    body.classList.add('category-' + (slug || 'hotel'));
    var hero = document.querySelector('.category-hero');
    if (!hero) return;
    var eyebrow = hero.querySelector('.eyebrow');
    var heading = hero.querySelector('h1');
    var description = hero.querySelector('p');
    var image = hero.querySelector('.category-hero-image');
    var cta = hero.querySelector('.primary');
    if (eyebrow) eyebrow.textContent = cfg.eyebrow;
    if (heading) heading.textContent = cfg.title;
    if (description) description.textContent = cfg.description;
    if (image) { image.src = IMAGE_ROOT + cfg.image; image.alt = cfg.title; }
    if (cta) { cta.textContent = cfg.cta; cta.href = '/urunler?kategori=' + encodeURIComponent(slug) + (new URLSearchParams(location.search).get('tenant') ? '&tenant=' + encodeURIComponent(new URLSearchParams(location.search).get('tenant')) : ''); }
    if (!hero.querySelector('.category-search')) {
      var search = document.createElement('form');
      search.className = 'category-search';
      search.action = '/urunler';
      search.method = 'get';
      var tenant = new URLSearchParams(location.search).get('tenant');
      search.innerHTML = '<input type="hidden" name="kategori"><label><span>⌖ &nbsp; Konum</span><input name="konum" type="search" placeholder="Nereye gidiyorsunuz?"></label><label><span>▢ &nbsp; Giriş – Çıkış</span><input name="tarih" type="text" placeholder="Tarih seçin" onfocus="this.type=\'date\'"></label><label><span>♙ &nbsp; Misafirler</span><input name="misafir" type="number" min="1" placeholder="Misafir ekleyin"></label><button type="submit" aria-label="İlanları ara"><span aria-hidden="true">⌕</span></button>';
      search.querySelector('[name="kategori"]').value = slug;
      if (tenant) {
        var tenantInput = document.createElement('input');
        tenantInput.type = 'hidden';
        tenantInput.name = 'tenant';
        tenantInput.value = tenant;
        search.appendChild(tenantInput);
      }
      hero.appendChild(search);
    }
    if (!hero.querySelector('.category-quick-nav')) {
      var quick = document.createElement('nav');
      quick.className = 'category-quick-nav';
      quick.setAttribute('aria-label', 'Hızlı kategoriler');
      [['hotel', 'hgi-building-03', 'Otel'], ['holiday_home', 'hgi-home-03', 'Tatil Evi'], ['yacht', 'hgi-sailboat-coastal', 'Yat'], ['tour', 'hgi-hot-air-balloon', 'Tur'], ['activity', 'hgi-adventure', 'Aktivite'], ['flight', 'hgi-airplane-03', 'Uçuş'], ['car', 'hgi-car-03', 'Araç'], ['bus', 'hgi-bus-01', 'Otobüs']].forEach(function (item) {
        var link = document.createElement('a');
        link.href = '/kategori/' + item[0] + (tenant ? '?tenant=' + encodeURIComponent(tenant) : '');
        link.className = item[0] === slug ? 'is-active' : '';
        link.innerHTML = '<span><i class="hgi-stroke ' + item[1] + '"></i></span><small>' + item[2] + '</small>';
        quick.appendChild(link);
      });
      hero.appendChild(quick);
    }
    if (!document.querySelector('.category-directory')) {
      var listings = document.querySelector('.category-listings');
      (listings || hero).insertAdjacentElement('afterend', createDirectory(slug));
    }
    if (!document.querySelector('.category-managed-filters')) {
      var directory = document.querySelector('.category-directory');
      (directory || hero).insertAdjacentElement('afterend', createManagedFilters(slug));
    }
  }

  function initDetail() {
    var main = document.querySelector('main.product-detail');
    if (!main) return;
    var classes = Array.prototype.slice.call(main.classList);
    var categoryClass = classes.find(function (c) { return c.indexOf('category-') === 0 && c !== 'product-detail'; });
    var slug = categoryClass ? canonicalCategory(categoryClass.slice('category-'.length)) : 'hotel';
    var cfg = CATEGORIES[slug] || CATEGORIES.hotel;
    document.body.dataset.category = slug;
    document.body.classList.add('category-detail-page', 'category-' + slug);
    main.dataset.category = slug;

    var sections = Array.prototype.slice.call(main.querySelectorAll(':scope > .listingSection__wrap'));
    var sidebar = main.querySelector(':scope > .grow');
    if (sections.length && sidebar && !main.querySelector('.detail-columns')) {
      var columns = document.createElement('div');
      columns.className = 'detail-columns';
      var detailMain = document.createElement('div');
      detailMain.className = 'detail-main';
      sections.forEach(function (section) { detailMain.appendChild(section); });
      columns.appendChild(detailMain);
      sidebar.classList.add('detail-sidebar');
      columns.appendChild(sidebar);
      var gallery = main.querySelector(':scope > .detail-gallery');
      if (gallery) gallery.insertAdjacentElement('afterend', columns);
      else main.insertBefore(columns, main.firstChild);
    }

    var detailMain = main.querySelector('.detail-main');
    if (detailMain && !detailMain.querySelector('.category-feature-strip')) {
      var feature = document.createElement('div');
      feature.className = 'category-feature-strip';
      feature.innerHTML = cfg.features.map(function (value) { return '<span><b aria-hidden="true">✓</b>' + value + '</span>'; }).join('');
      var description = detailMain.querySelector('.product-description');
      var descriptionSection = description && description.closest('.listingSection__wrap');
      if (descriptionSection) {
        var infoHeading = document.createElement('h2');
        infoHeading.textContent = slug === 'hotel' || slug === 'holiday_home' ? 'Konaklama hakkında' : 'İlan hakkında';
        descriptionSection.insertBefore(infoHeading, description);
        var amenities = document.createElement('section');
        amenities.className = 'listingSection__wrap detail-amenities';
        amenities.innerHTML = '<h2>Öne çıkan özellikler</h2><p>Bu ilanın sunduğu deneyim ve rezervasyon avantajları</p>';
        amenities.appendChild(feature);
        descriptionSection.insertAdjacentElement('afterend', amenities);
      } else detailMain.insertBefore(feature, detailMain.children[1] || null);
    }
    var price = main.querySelector('.detail-sidebar [data-price-minor]');
    if (detailMain && price && !detailMain.querySelector('.detail-rates')) {
      var rates = document.createElement('section');
      rates.className = 'listingSection__wrap detail-rates';
      rates.innerHTML = '<h2>Fiyatlandırma</h2><p>Fiyat, seçtiğiniz tarihlere ve misafir sayısına göre hesaplanır.</p>';
      var rateValue = document.createElement('strong');
      rateValue.textContent = price.textContent.trim();
      rates.appendChild(rateValue);
      var rateDetails = document.createElement('dl');
      rateDetails.className = 'detail-rate-rows';
      rateDetails.innerHTML = '<div><dt>Tarihler</dt><dd>Tarih seçin</dd></div><div><dt>Misafir sayısı</dt><dd>Rezervasyonda seçilir</dd></div><div><dt>Toplam tutar</dt><dd>Tarihler seçilince hesaplanır</dd></div>';
      rates.appendChild(rateDetails);
      var amenitiesSection = detailMain.querySelector('.detail-amenities');
      if (amenitiesSection) amenitiesSection.insertAdjacentElement('afterend', rates);
    }
    var availability = detailMain && detailMain.querySelector('#public-availability');
    if (availability) {
      var availabilityHeading = availability.parentElement.querySelector('h2');
      if (availabilityHeading) availabilityHeading.textContent = 'Müsaitlik';
    }
    var booking = main.querySelector('#booking-form');
    if (booking) {
      var button = booking.querySelector('button[type="submit"]');
      if (button) button.textContent = cfg.booking;
      var dateValue = booking.querySelector('.chisfis-date-value');
      if (dateValue) dateValue.textContent = cfg.booking;
      var form = booking.closest('.listingSection__wrap');
      if (form) form.setAttribute('data-category', slug);
    }
    var similar = detailMain && detailMain.querySelector('a[href*="/urunler?kategori"]');
    if (similar) similar.textContent = cfg.title + ' seçeneklerini keşfet →';
    decorateDetail(main, detailMain, slug);
  }

  function detailIcon(name) {
    var paths = {
      heart: '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z"/>',
      share: '<path d="M12 16V3m0 0L7.5 7.5M12 3l4.5 4.5"/><path d="M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7"/>',
      calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4m10-4v4M3 10h18"/>',
      guests: '<circle cx="9" cy="8" r="3"/><path d="M3 20v-2a6 6 0 0 1 12 0v2M18 8v8m-4-4h8"/>',
      location: '<path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>',
      wifi: '<path d="M2 9a15 15 0 0 1 20 0M5 12a10 10 0 0 1 14 0M8.5 15.5a5 5 0 0 1 7 0"/><circle cx="12" cy="19" r="1"/>',
      home: '<path d="m3 10 9-7 9 7v10H3z"/><path d="M9 20v-7h6v7"/>',
      shield: '<path d="m12 2 9 4v6c0 5-3.5 8-9 10-5.5-2-9-5-9-10V6z"/><path d="m8 12 3 3 5-6"/>',
      pool: '<path d="M2 18c2 0 2 2 4 2s2-2 4-2 2 2 4 2 2-2 4-2 2 2 4 2M2 13c2 0 2 2 4 2s2-2 4-2 2 2 4 2 2-2 4-2 2 2 4 2M7 12V4h10v8"/>',
      bath: '<path d="M3 12h18v3a5 5 0 0 1-5 5H8a5 5 0 0 1-5-5v-3Zm2 8-1 2m15-2 1 2M7 12V6a3 3 0 0 1 6 0"/>',
      bed: '<path d="M3 18V7m18 11V7M3 14h18v4H3zm3-4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v4H6z"/>',
      view: '<circle cx="12" cy="12" r="9"/><path d="m4 16 5-5 3 3 3-4 5 6"/>'
    };
    return '<svg class="detail-line-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (paths[name] || paths.shield) + '</svg>';
  }

  function decorateDetail(main, detailMain, slug) {
    if (!detailMain || main.dataset.demoDetailReady) return;
    main.dataset.demoDetailReady = 'true';
    var favorite = detailMain.querySelector('.detail-favorite');
    if (favorite) {
      favorite.innerHTML = detailIcon('heart');
      var favoriteKey = 'nexus_saved_listings';
      var listingId = location.pathname.split('/').pop();
      var saved = [];
      try { saved = JSON.parse(localStorage.getItem(favoriteKey) || '[]'); } catch (_) {}
      if (!Array.isArray(saved)) saved = [];
      function updateFavorite() {
        var selected = saved.indexOf(listingId) !== -1;
        favorite.classList.toggle('is-active', selected);
        favorite.setAttribute('aria-pressed', selected ? 'true' : 'false');
        favorite.setAttribute('aria-label', selected ? 'Favorilerden çıkar' : 'Favorilere ekle');
      }
      updateFavorite();
      favorite.addEventListener('click', function () {
        saved = saved.indexOf(listingId) === -1 ? saved.concat(listingId) : saved.filter(function (id) { return id !== listingId; });
        try { localStorage.setItem(favoriteKey, JSON.stringify(saved)); } catch (_) {}
        updateFavorite();
      });
    }
    var meta = detailMain.querySelector('.detail-location');
    if (meta) meta.insertAdjacentHTML('afterbegin', detailIcon('location'));
    var copy = detailMain.querySelector('.share-actions button');
    if (copy) {
      copy.innerHTML = detailIcon('share');
      copy.setAttribute('aria-label', 'Bağlantıyı kopyala');
      copy.setAttribute('title', 'Bağlantıyı kopyala');
    }
    var intro = detailMain.querySelector(':scope > .listingSection__wrap:first-child');
    if (intro) {
      var introContent = intro.querySelector('.flex.flex-col');
      var introDescription = (detailMain.querySelector('.product-description') || {}).textContent || '';
      if (introContent && !intro.querySelector('.detail-facts')) {
        var facts = document.createElement('div');
        facts.className = 'detail-facts';
        var bedroomMatch = introDescription.match(/\b(\d+)\s+(?:lüks\s+)?yatak odas/i);
        var factItems = [];
        if (bedroomMatch) factItems.push(['bed', bedroomMatch[1] + ' yatak odası']);
        if (/havuz/i.test(introDescription)) factItems.push(['pool', 'Özel havuz']);
        if (/jakuzi/i.test(introDescription)) factItems.push(['bath', 'Jakuzi']);
        if (/manzar/i.test(introDescription)) factItems.push(['view', 'Manzara']);
        factItems.forEach(function (item) { var fact = document.createElement('span'); fact.innerHTML = detailIcon(item[0]); fact.appendChild(document.createTextNode(item[1])); facts.appendChild(fact); });
        introContent.appendChild(facts);
      }
      var share = intro.querySelector('.share-actions');
      if (share) share.classList.add('detail-top-actions');
      if (!detailMain.querySelector('.detail-promotions')) {
        var promotions = document.createElement('section');
        promotions.className = 'detail-promotions';
        promotions.innerHTML = '<h2>Kampanyalar</h2><div><article><span>' + detailIcon('shield') + '</span><p><strong>Güvenli rezervasyon</strong><small>Rezervasyon koşulları ödeme öncesinde açıkça gösterilir.</small></p></article><article><span>' + detailIcon('calendar') + '</span><p><strong>Yakın tarihleri kontrol edin</strong><small>Takvimden uygun günleri seçerek güncel teklif alın.</small></p></article></div>';
        intro.insertAdjacentElement('afterend', promotions);
      }
    }
    var dateIcon = main.querySelector('.chisfis-date-icon');
    if (dateIcon) dateIcon.innerHTML = detailIcon('calendar');
    var guestIcon = main.querySelector('.chisfis-guest-icon');
    if (guestIcon) guestIcon.innerHTML = detailIcon('guests');
    detailMain.querySelectorAll('.category-feature-strip span').forEach(function (item, index) {
      var old = item.querySelector('b');
      if (old) old.remove();
      item.insertAdjacentHTML('afterbegin', detailIcon(['home', 'guests', 'shield'][index % 3]));
    });
    var featureStrip = detailMain.querySelector('.category-feature-strip');
    var descriptionText = (detailMain.querySelector('.product-description') || {}).textContent || '';
    if (featureStrip) {
      var extracted = [
        [/havuz/i, 'Havuz', 'pool'],
        [/jakuzi/i, 'Jakuzi', 'bath'],
        [/deniz.{0,35}manzar/i, 'Deniz manzarası', 'view'],
        [/\b(\d+)\s+(?:lüks\s+)?yatak odas/i, null, 'bed'],
        [/wifi|wi-fi/i, 'Wi-Fi', 'wifi'],
        [/bahçe/i, 'Bahçe', 'home'],
        [/teras/i, 'Teras', 'home'],
        [/spa/i, 'Spa', 'bath']
      ];
      extracted.forEach(function (entry) {
        var match = descriptionText.match(entry[0]);
        if (!match) return;
        var value = entry[1] || (match[1] + ' yatak odası');
        var feature = document.createElement('span');
        feature.innerHTML = detailIcon(entry[2]);
        feature.appendChild(document.createTextNode(value));
        featureStrip.appendChild(feature);
      });
    }
    var description = detailMain.querySelector('.product-description');
    var info = description && description.closest('.listingSection__wrap');
    var rates = detailMain.querySelector('.detail-rates');
    if (info && rates) {
      rates.classList.remove('listingSection__wrap');
      info.appendChild(rates);
      info.classList.add('detail-info-card');
    }
    var amenities = detailMain.querySelector('.detail-amenities');
    if (amenities) amenities.classList.add('detail-panel');
    var availability = detailMain.querySelector('#public-availability');
    if (availability) {
      var panel = availability.closest('.listingSection__wrap');
      panel.classList.add('detail-panel', 'detail-availability-card');
      var hint = document.createElement('p');
      hint.textContent = 'Uygun tarihler ve güncel fiyatlar rezervasyon takviminde gösterilir.';
      panel.insertBefore(hint, availability);
      addDetailCalendar(panel, main);
      panel.insertBefore(availability, panel.querySelector('.detail-calendar-preview'));
    }
    var locationEl = detailMain.querySelector('.detail-location');
    if (locationEl && locationEl.textContent.trim()) {
      var place = locationEl.textContent.trim();
      var locationPanel = document.createElement('section');
      locationPanel.className = 'detail-location-panel detail-panel';
      var title = document.createElement('h2');
      title.textContent = 'Konum';
      var address = document.createElement('p');
      address.textContent = place;
      var map = document.createElement('iframe');
      map.title = place + ' harita';
      map.loading = 'lazy';
      map.referrerPolicy = 'no-referrer-when-downgrade';
      map.src = 'https://maps.google.com/maps?q=' + encodeURIComponent(place) + '&output=embed';
      locationPanel.append(title, address, map);
      main.querySelector('.detail-columns').insertAdjacentElement('afterend', locationPanel);
    }
    var sidebar = main.querySelector('.detail-sidebar');
    if (sidebar) {
      sidebar.classList.add('detail-demo-booking');
      var bookingForm = sidebar.querySelector('#booking-form');
      var priceNode = sidebar.querySelector('[data-price-minor]');
      if (bookingForm && priceNode && !sidebar.querySelector('.detail-booking-total')) {
        var summary = document.createElement('div');
        summary.className = 'detail-booking-total';
        var submitWrap = bookingForm.querySelector('button[type="submit"]');
        submitWrap = submitWrap && submitWrap.parentElement;
        if (submitWrap) submitWrap.insertAdjacentElement('beforebegin', summary);
        else bookingForm.appendChild(summary);
        var money = new Intl.NumberFormat('tr-TR', { style: 'currency', currency: priceNode.dataset.priceCur || 'TRY' });
        function updateTotal() {
          var arrival = bookingForm.querySelector('[name="check_in"]');
          var departure = bookingForm.querySelector('[name="check_out"]');
          var nights = arrival && departure && arrival.value && departure.value ? Math.round((new Date(departure.value) - new Date(arrival.value)) / 86400000) : 0;
          var unit = Number(priceNode.dataset.priceMinor || 0) / 100;
          summary.textContent = '';
          if (nights > 0 && unit > 0) {
            var line = document.createElement('div');
            line.innerHTML = '<span>' + money.format(unit) + ' × ' + nights + ' gece</span><span>' + money.format(unit * nights) + '</span>';
            var total = document.createElement('div');
            total.className = 'detail-booking-total-final';
            total.innerHTML = '<strong>Toplam</strong><strong>' + money.format(unit * nights) + '</strong>';
            summary.append(line, total);
          } else summary.textContent = 'Toplam tutar tarih seçildikten sonra gösterilir.';
        }
        bookingForm.addEventListener('change', updateTotal);
        bookingForm.addEventListener('click', function () { setTimeout(updateTotal, 0); });
        updateTotal();
      }
    }
    var columns = main.querySelector('.detail-columns');
    if (columns && !main.querySelector('.detail-community')) {
      var community = document.createElement('section');
      community.className = 'detail-community';
      var hostCard = document.createElement('article');
      hostCard.className = 'detail-host-card';
      hostCard.innerHTML = '<div class="detail-host-avatar" aria-hidden="true">' + detailIcon('home') + '</div><h2>İlan sağlayıcısı</h2><p>Sağlayıcı bilgileri rezervasyon sırasında paylaşılır.</p>';
      var contact = document.createElement('a');
      contact.className = 'secondary';
      contact.href = '/iletisim' + (new URLSearchParams(location.search).get('tenant') ? '?tenant=' + encodeURIComponent(new URLSearchParams(location.search).get('tenant')) : '');
      contact.textContent = 'İletişime geç';
      hostCard.appendChild(contact);
      var reviewCard = document.createElement('article');
      reviewCard.className = 'detail-reviews-card';
      reviewCard.innerHTML = '<h2>Değerlendirmeler</h2><div class="detail-empty-reviews">Bu ilan için henüz değerlendirme paylaşılmadı.</div>';
      community.append(hostCard, reviewCard);
      columns.insertAdjacentElement('afterend', community);
      var locationPanel = main.querySelector('.detail-location-panel');
      if (locationPanel) community.insertAdjacentElement('afterend', locationPanel);
      var benefits = document.createElement('section');
      benefits.className = 'detail-benefits';
      benefits.innerHTML = '<div class="detail-benefits-copy"><span>AVANTAJLAR</span><h2>Neden bizimle rezervasyon?</h2><ul><li><strong>Güvenli rezervasyon</strong><small>Seçtiğiniz tarih ve misafir bilgilerini tek akışta kontrol edin.</small></li><li><strong>Şeffaf fiyat</strong><small>Gecelik fiyatı ve tarih seçiminize göre toplam tutarı görün.</small></li><li><strong>Destek alın</strong><small>İlan ve rezervasyon sorularınız için ekibimize ulaşın.</small></li></ul></div><img src="/static/chisfis/images/our-features-2.webp" alt="Tatil ve rezervasyon deneyimi" loading="lazy">';
      (locationPanel || community).insertAdjacentElement('afterend', benefits);
      var similar = detailMain.querySelector('a[href*="/urunler?kategori"]');
      if (similar) {
        var wrapper = similar.closest('.listingSection__wrap');
        if (wrapper) {
          wrapper.classList.add('detail-similar');
          benefits.querySelector('.detail-benefits-copy').appendChild(wrapper);
        }
      }
    }
  }

  function addDetailCalendar(panel, main) {
    var calendar = document.createElement('div');
    calendar.className = 'detail-calendar-preview';
    var today = new Date();
    for (var offset = 0; offset < 2; offset++) {
      var month = new Date(today.getFullYear(), today.getMonth() + offset, 1);
      var table = document.createElement('div');
      table.className = 'detail-calendar-month';
      var heading = document.createElement('strong');
      heading.textContent = month.toLocaleDateString('tr-TR', { month: 'long', year: 'numeric' });
      table.appendChild(heading);
      var grid = document.createElement('div');
      grid.className = 'detail-calendar-grid';
      ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'].forEach(function (day) { var cell = document.createElement('span'); cell.textContent = day; grid.appendChild(cell); });
      var start = (month.getDay() + 6) % 7;
      for (var blank = 0; blank < start; blank++) grid.appendChild(document.createElement('span'));
      var days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
      for (var number = 1; number <= days; number++) {
        var dayButton = document.createElement('button');
        dayButton.type = 'button';
        dayButton.textContent = number;
        dayButton.setAttribute('aria-label', number + ' ' + heading.textContent + ' için tarih seç');
        dayButton.addEventListener('click', function () { var trigger = main.querySelector('.chisfis-date-trigger'); if (trigger) { trigger.scrollIntoView({ behavior: 'smooth', block: 'center' }); setTimeout(function () { trigger.click(); }, 0); } });
        grid.appendChild(dayButton);
      }
      table.appendChild(grid);
      calendar.appendChild(table);
    }
    panel.insertBefore(calendar, panel.querySelector('#public-availability'));
  }

  function init() {
    initCategoryLanding();
    initDetail();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
