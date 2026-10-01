(() => {
  const demoYachtPath='/yat/gocek-koylari-26m-luks-gulet-murettebatli-mavi-yolculuk';
  const demoPreview = ['127.0.0.1', 'localhost'].includes(location.hostname) && (new URLSearchParams(location.search).has('preview') || location.pathname === '/otel/torba-grand-azure-resort-spa-ultra-her-sey-dahil' || location.pathname===demoYachtPath || location.pathname==='/tatil-evi/bodrum-yalikavak-panoramik-deniz-manzarali-luks-balayi-villasi');
  const scrollKey = 'nexus-detail-scroll:' + location.pathname + location.search;
  let restoredScroll = 0;
  try {
    const navigation = performance.getEntriesByType('navigation')[0]?.type;
    if (['reload','back_forward'].includes(navigation)) restoredScroll = Number(sessionStorage.getItem(scrollKey) || 0);
    history.scrollRestoration = 'manual';
  } catch (_) {}
  const rememberScroll = () => { try { sessionStorage.setItem(scrollKey,String(window.scrollY)); } catch (_) {} };
  window.addEventListener('pagehide',rememberScroll);
  window.addEventListener('beforeunload',rememberScroll);
  let leafletReady;
  const localeScript = document.createElement('script'); localeScript.src = '/static/detail-i18n.js'; document.head.appendChild(localeScript);
  const breadcrumb = document.querySelector('.product-detail .detail-breadcrumb');
  // İlan verilerinden gelen görsel URL'leri yalnızca güvenli şemalarda kabul
  // edilir (http/https mutlak veya kökten göreceli); data:, javascript: ve
  // protokol-göreceli (//) URL'ler reddedilir.
  const safeImageSrc = value => {
    const url = String(value || '').trim().replace('photo-1569263979104-865ab7cd8d17','photo-1567899378494-47b22a2ae96a');
    return /^https?:\/\//i.test(url) || /^\/(?!\/)/.test(url) ? url : '';
  };
  const detailTitle = document.querySelector('.product-detail h1');
  if (breadcrumb && detailTitle) {
    const category = (document.querySelector('.product-detail')?.className.match(/category-([a-z_]+)/) || [])[1];
    const home = breadcrumb.querySelector('a');
    const categoryLabel = breadcrumb.querySelector('span:last-child');
    if (home) { home.href = '/'; home.textContent = 'Ana Sayfa'; }
    if (categoryLabel && category) {
      const categoryLink = document.createElement('a');
      categoryLink.href = window.NEXUS_CATEGORY_URL ? window.NEXUS_CATEGORY_URL(category, 'tr') : '/' + category;
      categoryLink.textContent = categoryLabel.textContent;
      categoryLabel.replaceWith(categoryLink);
    }
    const separator = document.createElement('span');
    separator.textContent = '→';
    const current = document.createElement('span');
    current.textContent = detailTitle.textContent;
    current.setAttribute('aria-current', 'page');
    breadcrumb.append(separator, current);
    breadcrumb.setAttribute('aria-label', 'Sayfa yolu');
    breadcrumb.querySelectorAll('span:not([aria-current])').forEach(node => { node.textContent = '→'; node.setAttribute('aria-hidden', 'true'); });
  }
  const detailMain = document.querySelector('.product-detail .detail-main');
  document.querySelector('.product-detail')?.classList.add('reference-listing-detail');
  const detailStyles = document.createElement('link');
  detailStyles.rel = 'stylesheet';
  detailStyles.href = '/static/listing-detail.css?v=20261001-detail-unified2';
  const detailStylesReady = detailMain ? new Promise(resolve => {
    let finished = false;
    const finish = () => { if (!finished) { finished = true; resolve(); } };
    detailStyles.addEventListener('load', finish, { once: true });
    detailStyles.addEventListener('error', finish, { once: true });
    window.setTimeout(finish, 1200);
    document.head.appendChild(detailStyles);
  }) : Promise.resolve();
  const listingId = document.querySelector('#public-availability')?.dataset.listingId;
  if (detailMain && listingId) {
    // SSR is sufficient for the common layout, even when the catalogue request fails.
    const price = document.querySelector('.detail-sidebar [data-price-minor]');
    const fallback = {
      id: listingId,
      category: document.querySelector('.product-detail').dataset.category,
      locality: detailMain.querySelector('.detail-location')?.textContent.trim(),
      priceMinor: price?.dataset.priceMinor,
      currency: price?.dataset.priceCur,
    };
    renderListingInformation(detailMain, fallback, []);
    const tenant = document.querySelector('#public-availability').dataset.tenant;
    const controller = new AbortController();
    const requestTimeout = window.setTimeout(() => controller.abort(), 1500);
    const detailRequest = fetch('/api/public/listings' + (tenant ? '?tenant=' + encodeURIComponent(tenant) : ''), { credentials: 'same-origin', signal: controller.signal })
      .then(response => response.ok ? response.json() : [])
      .then(items => {
        const listing = Array.isArray(items) && items.find(item => item.id === listingId);
        if (listing) renderListingInformation(detailMain, listing, items);
      }).catch(() => {}).finally(() => window.clearTimeout(requestTimeout));
    Promise.all([detailStylesReady, detailRequest]).finally(async () => {
      document.body.classList.add('detail-template-ready');
      await Promise.race([document.fonts.ready,new Promise(resolve=>setTimeout(resolve,800))]);
      requestAnimationFrame(()=>requestAnimationFrame(()=>{
        window.scrollTo({top:restoredScroll,behavior:'instant'});
        document.body.classList.add('detail-layout-ready');
      }));
    });
  } else {
    document.body.classList.add('detail-template-ready','detail-layout-ready');
  }
  // Expanding the final accordion changes the sticky container's lower bound.
  // Preserve the booking card's current viewport position until the user scrolls.
  let bookingOffset = 0;
  const bookingPositions = new WeakMap();
  function rememberBookingPosition(event) {
    const summary = event.target.closest?.('.detail-main details > summary');
    const sidebar = document.querySelector('.detail-sidebar');
    if (!summary || !sidebar || innerWidth <= 900) return;
    bookingPositions.set(summary.parentElement, sidebar.getBoundingClientRect().top);
  }
  document.addEventListener('click', rememberBookingPosition, true);
  document.addEventListener('keydown', event => { if (event.key === 'Enter' || event.key === ' ') rememberBookingPosition(event); }, true);
  document.addEventListener('toggle', event => {
    const details = event.target;
    if (!bookingPositions.has(details)) return;
    const before = bookingPositions.get(details); bookingPositions.delete(details);
    const sidebar = document.querySelector('.detail-sidebar');
    if (!sidebar || innerWidth <= 900) return;
    const change = before - sidebar.getBoundingClientRect().top;
    bookingOffset += change;
    sidebar.style.translate = '0 ' + bookingOffset + 'px';
  }, true);
  function releaseBookingPosition() {
    bookingOffset = 0;
    document.querySelector('.detail-sidebar')?.style.removeProperty('translate');
  }
  document.addEventListener('wheel', releaseBookingPosition, {passive:true});
  document.addEventListener('touchmove', releaseBookingPosition, {passive:true});
  document.addEventListener('keydown', event => { if (['PageDown','PageUp','Home','End','ArrowDown','ArrowUp'].includes(event.key)) releaseBookingPosition(); });
  window.addEventListener('resize', releaseBookingPosition);
  function renderListingInformation(main, listing, allListings) {
    document.querySelectorAll('.reference-detail-section, .reference-detail-facts, .reference-hotel-quality, .reference-host-line, .reference-community, .reference-review-community, .summary-divider, .reference-license').forEach(node => node.remove());
    const intro = main.querySelector('.detail-intro');
    const about = intro?.nextElementSibling;
    const availability = main.querySelector('#public-availability')?.closest('.listingSection__wrap');
    const related = [...main.children].find(node => node.querySelector('a[href*="/urunler?kategori"]'));
    if (!intro || !about || !availability) return;
    const category = listing.category;
    availability.hidden = !['holiday_home','yacht'].includes(category);
    let detailData = {};
    try {
      const encoded = document.querySelector('.product-detail')?.dataset.listingDetail;
      if (encoded) detailData = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(encoded), char => char.charCodeAt(0))));
    } catch (_) {}
    const metadata = detailData.metadata && typeof detailData.metadata === 'object' ? detailData.metadata : {};
    if(demoPreview && category==='yacht'){
      listing={...listing,latitude:36.754,longitude:28.943,guestCount:10,bedroomCount:5,bathroomCount:5,reviewCount:3,ratingAverage:4.8,amenities:['wifi','ac','sound_system','food','water']};
      Object.assign(metadata,{yacht_type:'Gulet',min_stay_days:7,capacity:10,cabin_count:5,captain_included:'true',departure_port:'Göcek Marina',fuel_policy:'Göcek koyları standart rotasında yakıt dahil',extra_metadata:{...metadata.extra_metadata,boat_length:26,crew_status:'Kaptan, aşçı ve gemici',boat_times:'15:00 / 10:00',deposit_percent:35}});
    }
    if (demoPreview && category === 'holiday_home' && !(Number(listing.latitude) && Number(listing.longitude))) {
      listing = {...listing, latitude: 37.105, longitude: 27.293};
    }
    if (demoPreview && category === 'hotel') {
      listing = {...listing, latitude: 37.078, longitude: 27.457, reviewCount: 3, ratingAverage: 4.8, amenities: ['private_beach','open_pool','aquapark','heated_indoor_pool','spa_hamam','alacarte','kids_club','wifi','fitness','valet_parking','all_inclusive_bar','reception_24h','room_service','airport_shuttle','conference_room','live_music','tennis_court','wheelchair_access']};
      metadata.extra_metadata = {
        hotel_sections: [
          ['Konsept', 'Ultra Her Şey Dahil konseptiyle gün boyunca yemek ve içecek hizmetlerinden yararlanabilirsiniz.\nAçık büfe kahvaltı, öğle ve akşam yemeği\nGün içi atıştırmalıklar ve pastane ikramları\nKonsept kapsamındaki yerli alkollü ve alkolsüz içecekler\nHavuz ve sahil barı hizmeti\nMini barın günlük yenilenmesi'],
          ['Otel Olanakları', 'Denize sıfır konum, açık ve kapalı havuzlar, ücretsiz Wi-Fi, 24 saat resepsiyon ve otopark.'],
          ['Yeme & İçme', 'Kahvaltı, öğle ve akşam açık büfe. Alakart restoranlar ön rezervasyonla hizmet verir. Havuz ve sahil barlarında gün boyu içecek servisi sunulur.'],
          ['Spor & Eğlence', 'Fitness merkezi, tenis, su sporları ve akşam canlı müzik programları.'],
          ['Plaj', 'Özel plajda şezlong, şemsiye ve plaj havlusu hizmeti.'],
          ['Çocuk & Bebek', 'Çocuk havuzu, mini kulüp, oyun alanı ve talep üzerine bebek yatağı.'],
          ['Spa & Wellness', 'Türk hamamı, sauna ve dinlenme alanı. Masaj uygulamaları randevuyla sunulur.'],
          ['Balayı', 'Odaya özel karşılama, meyve ikramı ve müsaitliğe bağlı oda yükseltme.']
        ].map(([title,content]) => ({title,content})),
        hotel_house_rules: {children:'yes',pets:'no',events:'yes',smoking:'no'},
        hotel_contract: 'Örnek konaklama sözleşmesi (demo)\nRezervasyon, tesisin müsaitlik onayıyla kesinleşir. Girişte kimlik ibrazı gerekir. Konaklama kapsamı rezervasyon belgesinde belirtilir. İptal, iade ve ödeme koşulları rezervasyon sırasında teyit edilir.'
      };
      metadata.room_types = (metadata.room_types || []).map(room => ({...room, images: ['/static/chisfis/images/pexels-photo-6129967.home.webp','/static/chisfis/images/pexels-photo-7740160.home.webp'], amenities:['wifi','ac','sound_system','room_service']}));
      if (!intro.querySelector('.reference-demo-note')) { const badge = document.createElement('small'); badge.className = 'reference-demo-note'; badge.textContent = 'Demo önizleme • Fotoğraflar, konum, mesafeler ve içerikler örnektir.'; intro.appendChild(badge); }
    }
    if (category === 'hotel') {
      about.querySelector('h2')?.replaceChildren(document.createTextNode('Otel tanıtımı'));
    }
    if (!about.querySelector('.reference-section-subtitle')) {
      const subtitle = paragraph('Tesisi ve konaklama deneyimini yakından tanıyın.');
      subtitle.className = 'reference-section-subtitle';
      about.querySelector('h2')?.after(subtitle);
    }
    if (related) related.remove();
    const money = new Intl.NumberFormat('tr-TR', { style: 'currency', currency: listing.currency || 'TRY', maximumFractionDigits: 0 }).format(Number(listing.priceMinor || 0) / 100);
    const hasPricing = category !== 'hotel';
    let rates = null;
    if (hasPricing) {
      rates = section('Fiyat bilgileri', 'Güncel başlangıç fiyatı; tarih ve müsaitliğe göre değişebilir.');
      const rateRow = document.createElement('div');
      rateRow.className = 'reference-detail-rate';
      const rateLabel = document.createElement('span');
      rateLabel.textContent = 'Başlangıç fiyatı';
      const rateValue = document.createElement('strong');
      rateValue.textContent = money;
      rateRow.append(rateLabel, rateValue);
      rates.appendChild(rateRow);
      about.after(rates);
    }
    const amenities = section('Olanaklar', 'İlanda belirtilen özellikler ve hizmetler');
    const amenityNames = { pool: 'Havuz', sea_view: 'Deniz manzarası', jacuzzi: 'Jakuzi', sheltered: 'Korunaklı alan', ac: 'Klima', wifi: 'Wi-Fi', bbq: 'Barbekü', parking: 'Otopark', beach: 'Plaj', spa: 'Spa', restaurant: 'Restoran', private_beach: 'Özel plaj', open_pool: 'Açık havuz', aquapark: 'Aquapark', heated_indoor_pool: 'Isıtmalı kapalı havuz', spa_hamam: 'Spa ve hamam', alacarte: 'Alakart restoran', kids_club: 'Çocuk kulübü', fitness: 'Fitness merkezi', valet_parking: 'Vale otopark', skipper: 'Kaptan', generator: 'Jeneratör', sound_system: 'Ses sistemi', guide: 'Rehber', lunch: 'Öğle yemeği', transfer: 'Transfer', insurance: 'Sigorta', tickets: 'Giriş biletleri' };
    const amenityValues = Array.isArray(listing.amenities) ? listing.amenities.filter(value => typeof value === 'string' && value) : [];
    if (amenityValues.length) {
      const list = document.createElement('div');
      list.className = 'reference-detail-amenities';
      const extraNames = { all_inclusive_bar: 'Havuz ve sahil bar', reception_24h: '24 saat resepsiyon', room_service: 'Oda servisi', airport_shuttle: 'Havalimanı transferi', conference_room: 'Toplantı salonu', live_music: 'Canlı müzik', tennis_court: 'Tenis kortu', wheelchair_access: 'Engelsiz erişim' };
      const feature = value => {
        const item = document.createElement('div'); item.className = 'reference-amenity-item';
        const label = document.createElement('span'); label.textContent = amenityNames[value] || extraNames[value] || value.replace(/_/g, ' ');
        item.append(amenityIcon(value), label); return item;
      };
      amenityValues.slice(0, 12).forEach(value => list.appendChild(feature(value)));
      amenities.appendChild(list);
      if (amenityValues.length > 12) {
        const more = document.createElement('button'); more.type = 'button'; more.className = 'reference-amenities-more';
        more.textContent = 'Devamını göster (' + amenityValues.length + ' özellik)';
        amenities.appendChild(more);
        more.addEventListener('click', () => {
          const overlay = document.createElement('div'); overlay.className = 'reference-amenity-modal';
          overlay.setAttribute('role', 'dialog'); overlay.setAttribute('aria-modal', 'true'); overlay.setAttribute('aria-label', 'Tüm özellikler');
          const dialog = document.createElement('div'); dialog.className = 'reference-amenity-dialog';
          const close = document.createElement('button'); close.type = 'button'; close.className = 'reference-amenity-close'; close.textContent = '×'; close.setAttribute('aria-label', 'Kapat');
          const title = document.createElement('h2'); title.textContent = 'Tüm özellikler';
          const fullList = document.createElement('div'); fullList.className = 'reference-amenity-modal-list';
          amenityValues.forEach(value => fullList.appendChild(feature(value)));
          dialog.append(close, title, fullList); overlay.appendChild(dialog); document.body.appendChild(overlay);
          const previousOverflow = document.body.style.overflow; document.body.style.overflow = 'hidden';
          const dismiss = () => { overlay.remove(); document.body.style.overflow = previousOverflow; document.removeEventListener('keydown', keyboard); more.focus(); };
          const keyboard = event => { if (event.key === 'Escape') dismiss(); if (event.key === 'Tab') { event.preventDefault(); close.focus(); } };
          close.addEventListener('click', dismiss); overlay.addEventListener('click', event => { if (event.target === overlay) dismiss(); });
          document.addEventListener('keydown', keyboard); close.focus();
        });
      }
    } else amenities.appendChild(paragraph('Bu ilan için olanak bilgisi henüz eklenmemiş.'));
    (rates || about).after(amenities);
    if (['yacht','tour','activity'].includes(category)) renderExperienceDetails(main, listing, metadata, amenities, rates, availability, about, detailData);
    if (category === 'holiday_home') renderHolidayHome(main, listing, metadata, amenities, rates, availability, about, detailData);
    if (category === 'hotel') {
      const stars = parseInt(metadata.hotel_stars, 10);
      const rooms = Array.isArray(metadata.room_types) ? metadata.room_types.filter(room => room && room.title) : [];
      if (rooms.length) {
        const roomSection = section('Oda Seçenekleri', 'Oda tiplerini inceleyin ve tarih seçerek güncel fiyatı öğrenin.');
        roomSection.classList.add('reference-room-section');
        rooms.forEach(room => {
          const card = document.createElement('article');
          card.className = 'reference-room-card';
          const photos = (Array.isArray(room.images) ? room.images : []).map(safeImageSrc).filter(Boolean);
          const gallery = document.createElement('div'); gallery.className = 'reference-room-gallery';
          if (photos.length) {
            const image = document.createElement('img');
            image.src = photos[0];
            image.alt = room.title;
            image.loading = 'lazy';
            const enlarge = document.createElement('button'); enlarge.type = 'button'; enlarge.className = 'reference-room-photo'; enlarge.setAttribute('aria-label', room.title + ' fotoğraflarını göster'); enlarge.appendChild(image);
            let index = 0;
            enlarge.addEventListener('click', () => openLightbox(photos, index)); gallery.appendChild(enlarge);
            if (photos.length > 1) {
              const count = document.createElement('span'); count.className = 'reference-room-photo-count';
              const update = () => { image.src = photos[index]; count.textContent = (index + 1) + ' / ' + photos.length; };
              [-1, 1].forEach(step => {
                const arrow = document.createElement('button'); arrow.type = 'button'; arrow.className = 'reference-room-arrow ' + (step < 0 ? 'is-prev' : 'is-next'); arrow.textContent = step < 0 ? '‹' : '›'; arrow.setAttribute('aria-label', step < 0 ? 'Önceki oda fotoğrafı' : 'Sonraki oda fotoğrafı');
                arrow.addEventListener('click', () => { index = (index + step + photos.length) % photos.length; update(); }); gallery.appendChild(arrow);
              }); gallery.appendChild(count); update();
            }
          } else { gallery.classList.add('is-empty'); gallery.textContent = 'Oda fotoğrafı henüz eklenmemiş'; }
          card.appendChild(gallery);
          const content = document.createElement('div');
          content.className = 'reference-room-content';
          const name = document.createElement('h3');
          name.textContent = room.title;
          content.appendChild(name);
          const specs = document.createElement('div'); specs.className = 'reference-room-specs';
          [
            ['guests', [Number(room.adults) > 0 && room.adults + ' yetişkin', Number(room.children) > 0 && room.children + ' çocuk'].filter(Boolean).join(', ')],
            ['bed', room.bed],
            ['area', Number(room.size_m2) > 0 && room.size_m2 + ' m²'],
            ['view', room.view_type]
          ].forEach(([icon, value]) => {
            if (!value) return;
            const spec = document.createElement('span');
            const label = document.createElement('span'); label.textContent = value;
            spec.append(summaryIcon(icon), label); specs.appendChild(spec);
          });
          content.appendChild(specs);
          const note = document.createElement('small');
          note.textContent = 'Odaya uygun tarih ve müsaitliği kontrol edin.';
          content.appendChild(note);
          const button = document.createElement('button');
          button.type = 'button';
          button.textContent = 'Tarih Seç';
          button.addEventListener('click', () => {
            document.querySelector('.detail-sidebar .chisfis-date-trigger')?.click();
            document.querySelector('.detail-sidebar')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
          });
          const actions = document.createElement('div'); actions.className = 'reference-room-actions';
          const featuresButton = document.createElement('button'); featuresButton.type = 'button'; featuresButton.className = 'reference-room-features'; featuresButton.textContent = 'Oda özellikleri';
          featuresButton.addEventListener('click', () => {
            const overlay = document.createElement('div'); overlay.className = 'reference-amenity-modal'; overlay.setAttribute('role', 'dialog'); overlay.setAttribute('aria-modal', 'true'); overlay.setAttribute('aria-label', room.title + ' özellikleri');
            const dialog = document.createElement('div'); dialog.className = 'reference-amenity-dialog';
            const close = document.createElement('button'); close.type = 'button'; close.className = 'reference-amenity-close'; close.textContent = '×'; close.setAttribute('aria-label', 'Kapat');
            const title = document.createElement('h2'); title.textContent = room.title + ' — Oda özellikleri';
            const list = document.createElement('div'); list.className = 'reference-amenity-modal-list';
            specs.querySelectorAll(':scope > span').forEach(item => list.appendChild(item.cloneNode(true)));
            list.classList.add('reference-room-specs-modal');
            const attributes = Array.isArray(room.amenities) ? room.amenities : Array.isArray(room.attributes) ? room.attributes : [];
            attributes.forEach(value => {
              const key = typeof value === 'string' ? value : value?.code || value?.field_key;
              if (!key) return;
              const row = document.createElement('span'); const label = document.createElement('span'); label.textContent = (typeof value === 'object' && (value.label || value.title)) || amenityNames[key] || key.replace(/_/g, ' ');
              row.append(amenityIcon(key), label); list.appendChild(row);
            });
            dialog.append(close, title, list); overlay.appendChild(dialog); document.body.appendChild(overlay);
            const previousOverflow = document.body.style.overflow; document.body.style.overflow = 'hidden';
            const dismiss = () => { overlay.remove(); document.body.style.overflow = previousOverflow; document.removeEventListener('keydown', keyboard); featuresButton.focus(); };
            const keyboard = event => { if (event.key === 'Escape') dismiss(); if (event.key === 'Tab') { event.preventDefault(); close.focus(); } };
            close.addEventListener('click', dismiss); overlay.addEventListener('click', event => { if (event.target === overlay) dismiss(); }); document.addEventListener('keydown', keyboard); close.focus();
          });
          actions.append(featuresButton, button); content.appendChild(actions);
          card.appendChild(content);
          roomSection.appendChild(card);
        });
        amenities.after(roomSection);
      }
      const configuredSections = metadata.extra_metadata?.hotel_sections;
      const hotelSections = Array.isArray(configuredSections) ? configuredSections : ['Konsept', 'Otel Olanakları', 'Yeme & İçme', 'Spor & Eğlence', 'Plaj', 'Çocuk & Bebek', 'Spa & Wellness', 'Balayı'].map(title => ({ title, content: '' }));
      const facility = section('Tesis Bilgileri'); facility.classList.add('reference-facility-section');
      const orderedSections = [...hotelSections.filter(entry => entry?.title?.trim().toLocaleLowerCase('tr-TR') === 'konsept'), ...hotelSections.filter(entry => entry?.title?.trim().toLocaleLowerCase('tr-TR') !== 'konsept')];
      orderedSections.forEach(entry => {
        if (!entry || typeof entry.title !== 'string' || !entry.title.trim() || typeof entry.content !== 'string' || !entry.content.trim()) return;
        const accordion = document.createElement('details');
        const heading = document.createElement('summary'); heading.append(amenityIcon(entry.title.includes('Plaj') ? 'beach' : entry.title.includes('İçme') ? 'restaurant' : entry.title.includes('Spor') ? 'fitness' : 'generic'), document.createTextNode(entry.title));
        accordion.appendChild(heading);
        if (entry.title.trim().toLocaleLowerCase('tr-TR') === 'konsept') {
          accordion.open = true;
          const lines = entry.content.split(/\r?\n/).map(line => line.trim()).filter(Boolean);
          accordion.appendChild(paragraph(lines.shift()));
          if (lines.length) { const list = document.createElement('ul'); list.className = 'reference-concept-inclusions'; lines.forEach(line => { const item = document.createElement('li'); item.textContent = line.replace(/^[-•]\s*/, ''); list.appendChild(item); }); accordion.appendChild(list); }
        } else { const content = paragraph(entry.content); content.style.whiteSpace = 'pre-wrap'; accordion.appendChild(content); }
        facility.appendChild(accordion);
      });
      if (facility.querySelector('details')) (main.querySelector('.reference-room-section') || amenities).after(facility);
      const ruleItems = [
        metadata.check_in_time && ['Giriş', metadata.check_in_time],
        metadata.check_out_time && ['Çıkış', metadata.check_out_time],
      ].filter(Boolean);
      {
        const rules = section('Kurallar', 'Giriş ve çıkış saatleri ile otele ait sözleşme');
        rules.classList.add('reference-rules-section');
        const grid = document.createElement('div');
        grid.className = 'reference-rules-grid';
        ruleItems.forEach(([label, value]) => {
          const item = document.createElement('div');
          const small = document.createElement('small');
          small.textContent = label;
          const strong = document.createElement('strong');
          strong.textContent = value;
          item.append(small, strong);
          grid.appendChild(item);
        });
        rules.appendChild(grid);
        const contract = document.createElement('div'); contract.className = 'reference-hotel-contract';
        const contractTitle = document.createElement('h3'); contractTitle.textContent = 'Otele ait sözleşme';
        const contractText = paragraph(metadata.extra_metadata?.hotel_contract || 'Bu otelin sözleşmesi henüz eklenmemiş.');
        contract.append(contractTitle, contractText); rules.appendChild(contract);
        const houseRules = metadata.extra_metadata?.hotel_house_rules || {};
        const ruleList = document.createElement('ul'); ruleList.className = 'reference-hotel-house-rules';
        [['children', 'Çocuklara uygun', 'Çocuklara uygun değil'], ['pets', 'Evcil hayvan kabul edilir', 'Evcil hayvan kabul edilmez'], ['events', 'Etkinliklere uygun', 'Etkinliklere uygun değil'], ['smoking', 'İç mekanda sigara içilir', 'İç mekanda sigara içilmez']].forEach(([key, yes, no]) => {
          const item = document.createElement('li');
          const state = houseRules[key]; item.className = state === 'yes' ? 'is-allowed' : state === 'no' ? 'is-restricted' : 'is-unspecified';
          const icon = summaryIcon('guests'); icon.querySelector('path').setAttribute('d', state === 'yes' ? 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0ZM8 12l3 3 5-6' : 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0ZM12 7v6M12 17h.01');
          const label = document.createElement('span'); label.textContent = state === 'yes' ? yes : state === 'no' ? no : yes + ': belirtilmedi'; item.append(icon, label);
          ruleList.appendChild(item);
        }); rules.appendChild(ruleList);
        (facility.isConnected ? facility : main.querySelector('.reference-room-section') || amenities).after(rules);
      }
    }
    const availabilityTitle = availability.querySelector('h2');
    if (availabilityTitle) availabilityTitle.textContent = 'Müsaitlik';
    if (availabilityTitle && !availability.querySelector('.reference-section-subtitle')) {
      const subtitle=paragraph('Konaklamak istediğiniz tarihleri seçerek müsaitliği kontrol edin.');
      subtitle.className='reference-section-subtitle';
      availabilityTitle.after(subtitle);
    }
    const reviews = section('Yorumlar' + (Number(listing.reviewCount) > 0 ? ' (' + listing.reviewCount + ')' : ''));
    reviews.appendChild(paragraph(Number(listing.reviewCount) > 0 ? 'Bu ilan için ' + listing.reviewCount + ' onaylı değerlendirme bulunuyor.' : 'Bu ilan için henüz yayımlanmış yorum yok.'));
    reviews.classList.add('reference-reviews');
    if (demoPreview) {
      reviews.replaceChildren(reviews.firstElementChild);
      const stars = (value) => {
        const node = document.createElement('span'); node.className = 'reference-review-stars';
        node.setAttribute('aria-label', value + ' / 5 yıldız');
        for (let i = 1; i <= 5; i++) { const star = document.createElement('span'); star.textContent = '★'; if (i > value) star.className = 'inactive'; node.appendChild(star); }
        return node;
      };
      const summary = document.createElement('div'); summary.className = 'reference-review-summary'; summary.append(stars(5));
      const score = document.createElement('span'); score.textContent = '4,8 / 5'; summary.append(score); reviews.append(summary);
      const divider = document.createElement('div'); divider.className = 'reference-review-divider'; reviews.append(divider);
      const form = document.createElement('form'); form.className = 'reference-review-form';
      const input = document.createElement('input'); input.placeholder = 'Deneyiminizi paylaşın…'; input.setAttribute('aria-label', 'Yorumunuz'); input.required = true;
      const send = document.createElement('button'); send.type = 'submit'; send.setAttribute('aria-label', 'Yorumu gönder');
      const arrow=document.createElementNS('http://www.w3.org/2000/svg','svg');
      arrow.setAttribute('viewBox','0 0 24 24');arrow.setAttribute('fill','none');arrow.setAttribute('stroke','currentColor');arrow.setAttribute('stroke-width','1.5');arrow.setAttribute('stroke-linecap','round');arrow.setAttribute('stroke-linejoin','round');arrow.setAttribute('aria-hidden','true');
      const path=document.createElementNS('http://www.w3.org/2000/svg','path');path.setAttribute('d','M5 12h14m-7-7 7 7-7 7');arrow.append(path);send.append(arrow);
      const notice = paragraph(''); notice.className = 'reference-review-notice'; notice.setAttribute('role', 'status');
      form.append(input,send); form.addEventListener('submit', event => { event.preventDefault(); notice.textContent = 'Demo önizleme: yorumunuz kaydedilmedi.'; }); reviews.append(form,notice);
      [['Ayşe K.', 'Geniş odalar ve sakin bir koy. Aile tatili için keyifli bir deneyim.',5,'18 Eylül 2026','avatar-fones-mimi.jpg'], ['Mehmet D.', 'Plaj ve restoran hizmetinden memnun kaldık.',4,'12 Eylül 2026','avatar-birrell-chariot.jpg'], ['Selin A.', 'Oda temizliği ve personelin ilgisi çok iyiydi.',5,'5 Eylül 2026','avatar-falconar-agnes.jpg']].forEach(([name,text,rating,date,photo]) => {
        const review = document.createElement('article'); review.className = 'reference-review-item';
        const avatar = document.createElement('img'); avatar.src = '/static/chisfis/images/' + photo; avatar.alt = ''; avatar.width = 40; avatar.height = 40;
        const body = document.createElement('div'); const heading = document.createElement('strong'); heading.textContent = name;
        const time = document.createElement('time'); time.textContent = date;
        body.append(stars(rating),heading,time,paragraph(text)); review.append(avatar,body); reviews.append(review);
      });
      const moreReviews=document.createElement('button');
      moreReviews.type='button';moreReviews.className='reference-more-reviews';
      moreReviews.textContent='Daha fazla yorum göster';
      const moreNotice=paragraph('');moreNotice.className='reference-review-notice';moreNotice.setAttribute('role','status');
      moreReviews.addEventListener('click',()=>{moreNotice.textContent='Gösterilecek başka yorum bulunmuyor.';});
      reviews.append(moreReviews,moreNotice);
    }
    availability.after(reviews);
    const location = section('Konum', listing.locality || 'Konum bilgisi');
    location.classList.add('reference-location-section');
    const lat = Number(listing.latitude), lon = Number(listing.longitude);
    if (listing.latitude !== undefined && listing.latitude !== '' && listing.longitude !== undefined && listing.longitude !== '' && Number.isFinite(lat) && Number.isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180) {
      const map = document.createElement('div');
      map.className = 'reference-detail-map';
      map.title = 'İlan konumu';
      location.appendChild(map);
      initLocationMap(map, lat, lon);
      const nearby = section('Yakındaki mekanlar', 'Tesise göre mesafe (kuş uçuşu)'); nearby.classList.add('reference-nearby'); location.appendChild(nearby);
      loadNearbyPlaces(nearby, lat, lon);
    } else {
      location.appendChild(paragraph('Harita konumu henüz paylaşılmamış.'));
      const nearby = section('Yakındaki mekanlar'); nearby.classList.add('reference-nearby'); nearby.appendChild(paragraph('Yakındaki mekanları ve mesafeleri göstermek için tesisin harita konumu eklenmelidir.')); location.appendChild(nearby);
    }
    reviews.after(location);
    if (demoPreview && category!=='yacht') {
      const trips = section('Bodrum için gezi önerileri', 'Torba ve Bodrum çevresini keşfedin • Demo gezi planları'); trips.classList.add('reference-trip-section');
      const grid = document.createElement('div'); grid.className = 'reference-trip-grid';
      queueMicrotask(() => {
        grid.querySelectorAll('article').forEach((card, index) => {
          const label = document.createElement('small'); label.className = 'reference-trip-label'; label.textContent = ['Kültür & Tarih', 'Deniz & Doğa', 'Yerel Yaşam'][index]; card.prepend(label);
        });
        const regionDocument = new DOMParser().parseFromString(listing.regionDescription || '', 'text/html');
        const regionPhotos = [...regionDocument.querySelectorAll('img')].map(image => safeImageSrc(image.getAttribute('src'))).filter(Boolean);
        const photo = location.querySelector('.reference-trip-visual img');
        if (photo && regionPhotos.length) { photo.src = regionPhotos[0]; photo.alt = (listing.locality || 'Bölge') + ' bölge fotoğrafı'; }
      });
      [['Bodrum’un tarihini keşfedin','Bodrum Kalesi, Sualtı Arkeoloji Müzesi ve antik tiyatro ile kültür dolu bir gün.','Yarım gün'],['Koylarda deniz molası','Torba sahilinde yürüyüş ve çevredeki koylarda yüzme molası.','Tam gün'],['Çarşı ve gün batımı','Bodrum çarşısını gezin, marinada mola verin ve gün batımını izleyin.','Akşam']].forEach(([title,text,duration]) => { const card = document.createElement('article'); const heading = document.createElement('h3'); heading.append(summaryIcon('location'), document.createTextNode(title)); card.append(heading,paragraph(text),paragraph(duration)); grid.appendChild(card); }); const layout = document.createElement('div'); layout.className = 'reference-trip-layout'; const visual = document.createElement('div'); visual.className = 'reference-trip-visual'; const photo = document.createElement('img'); photo.src = document.querySelector('.detail-gallery img')?.src || '/static/chisfis/images/pexels-photo-6129967.home.webp'; photo.alt = 'Gezi önerileri için örnek tatil görseli'; visual.appendChild(photo); layout.append(grid,visual); trips.appendChild(layout); location.appendChild(trips);
    }
    const columns = main.closest('.detail-columns');
    if (columns) {
      const community = document.createElement('div');
      community.className = 'reference-community';
      columns.after(community);
      community.after(location);
      const candidates = allListings.filter(item => item.id !== listing.id);
      const similar = candidates.filter(item => item.category === listing.category).slice(0, 4);
      const nearby = candidates.filter(item => {
        const a = Number(item.latitude), b = Number(item.longitude);
        if (!item.latitude || !item.longitude || !Number.isFinite(a) || !Number.isFinite(b)) return false;
        return Math.hypot((a-lat)*111, (b-lon)*111*Math.cos(lat*Math.PI/180)) <= 50;
      }).sort((a,b) => Math.hypot(Number(a.latitude)-lat,Number(a.longitude)-lon)-Math.hypot(Number(b.latitude)-lat,Number(b.longitude)-lon)).slice(0,4);
      let lastSection = location;
      [['Benzer ilanlar', similar], ['Yakındaki ilanlar', nearby]].forEach(([heading, entries]) => {
        if (demoPreview) while (entries.length < 4) entries.push({title: (heading === 'Benzer ilanlar' ? ['Torba Sahil Resort','Bodrum Deniz Hotel','Ege Garden Resort','Torba Boutique Hotel'] : ['Torba Koyu Konaklama','Bodrum Marina Suites','Güvercinlik Sahil Oteli','Bodrum Merkez Hotel'])[entries.length], categoryLabel:({holiday_home:'Villa • Demo',yacht:'Yat • Demo',tour:'Tur • Demo',activity:'Aktivite • Demo'}[category] || 'Otel • Demo'), locality:'Bodrum, Muğla', priceMinor: [650000,720000,580000,490000][entries.length], currency:'TRY', ratingAverage:[4.8,4.6,4.7,4.5][entries.length], reviewCount:[28,42,16,34][entries.length], images:listing.images || []});
        const relatedSection = section(heading);
        relatedSection.classList.add('reference-similar');
        if(category==='yacht')relatedSection.querySelector('.reference-section-subtitle').textContent=heading==='Benzer ilanlar'?'İlginizi çekebilecek diğer yat kiralama seçenekleri.':'Göcek ve çevresindeki yat kiralama seçenekleri.';
        const grid = document.createElement('div');
        grid.className = 'reference-similar-grid category-content-grid';
        if (demoPreview && category === 'holiday_home') entries.forEach((item,index) => { if(!item.id) { item.title=(heading === 'Benzer ilanlar' ? ['Yalıkavak Deniz Villa','Bodrum Garden Villa','Ege Panorama Villa','Bodrum Sunset Villa'] : ['Yalıkavak Sahil Villa','Gümüşlük Bahçe Villa','Gündoğan Deniz Villa','Bodrum Marina Villa'])[index]; item.guestCount=6;item.bedroomCount=3;item.bathroomCount=3; } });
        if(demoPreview && category==='yacht')entries.forEach((item,index)=>{if(!item.id){item.title=(heading==='Benzer ilanlar'?['Göcek 24 m Lüks Gulet','Fethiye 28 m Mürettebatlı Gulet','Göcek 20 m Motoryat','Ege 22 m Yelkenli']:['Göcek Marina Gulet','İnlice Koyları Motoryat','Fethiye Mavi Yolculuk Guleti','Dalaman Koyları Katamaran'])[index];item.category='yacht';item.locality='Göcek, Fethiye, Muğla';item.priceMinor=[3800000,4600000,5200000,3400000][index];item.images=['https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=800&q=80','https://images.unsplash.com/photo-1540946485063-a40da27545f8?auto=format&fit=crop&w=800&q=80'];}});
        entries.forEach(item => {
          if(category==='yacht' && demoPreview && !item.id){const index=entries.indexOf(item);item.guestCount=[10,12,8,6][index];item.cabinCount=[5,6,4,3][index];item.bathroomCount=[5,6,4,3][index];}
          if (window.NEXUS_BUILDER_LISTING_CARD) {
            const card = window.NEXUS_BUILDER_LISTING_CARD({...item, images: (item.images || []).map(safeImageSrc).filter(Boolean)});
            const place = card.querySelector('.category-content-card-location');
            if (place) { place.prepend(summaryIcon('location')); }
            const price = card.querySelector('.category-content-card-price');
            if (price) { const unit = document.createElement('small'); unit.textContent = ['tour','activity'].includes(item.category || category) ? ' / kişi' : ' / gece'; price.appendChild(unit); }
            if (!item.id) {
              card.removeAttribute('data-listing-id');
              card.querySelectorAll('a').forEach(link => link.removeAttribute('href'));
              const favorite = card.querySelector('.category-card-favorite');
              if (favorite) { favorite.onclick = () => { const on = favorite.getAttribute('aria-pressed') !== 'true'; favorite.setAttribute('aria-pressed',String(on)); favorite.textContent = on ? '♥' : '♡'; }; }
            }
            grid.appendChild(card);
          }
        });
        relatedSection.appendChild(grid);
        if (!entries.length) relatedSection.appendChild(paragraph(heading === 'Benzer ilanlar' ? 'Henüz benzer ilan bulunmuyor.' : 'Yakında konumu kayıtlı ilan bulunmuyor.'));
        lastSection.after(relatedSection); lastSection = relatedSection;
      });
      const reviewCommunity = document.createElement('div'); reviewCommunity.className = 'reference-review-community';
      const host = document.createElement('aside'); host.className = 'reference-review-host';
      const identity = document.createElement('div'); identity.className = 'review-host-identity';
      const avatar = document.createElement('img'); avatar.src = '/static/chisfis/images/avatar-birrell-chariot.jpg'; avatar.alt = ''; avatar.width = 56; avatar.height = 56;
      const identityText = document.createElement('div'); const hostName = document.createElement('h2'); hostName.textContent = listing.title || detailTitle?.textContent || 'Tesis';
      const rating = paragraph(demoPreview ? '★ 4,8 (120) · 5 ilan' : 'Bu ilanın hizmet sağlayıcısı'); rating.className = 'review-host-rating'; identityText.append(hostName,rating); identity.append(avatar,identityText); host.append(identity);
      if (demoPreview) {
        const badges = document.createElement('div'); badges.className = 'review-host-badges'; badges.textContent = '♧ Öne çıkan sağlayıcı  |  ♙ 2+ yıl'; host.append(badges);
        host.append(paragraph(category === 'holiday_home' ? 'Özel havuz, konforlu yaşam alanları ve doğayla iç içe bir konumda misafirlerimizi ağırlıyoruz.' : 'Torba koyunda konforlu odalar, özel plaj ve ailelere uygun olanaklarla misafirlerimizi ağırlıyoruz.'));
        const facts = document.createElement('ul'); facts.className = 'review-host-facts';
        [['calendar','Mart 2024’ten beri üye'],['guests','Yanıt oranı: %95'],['calendar','Yanıt süresi: bir saat içinde']].forEach(([icon,text]) => { const item = document.createElement('li'); item.append(summaryIcon(icon),document.createTextNode(text)); facts.append(item); }); host.append(facts);
      }
      const actions = document.createElement('div'); actions.className = 'review-host-actions';
      const profile = document.createElement('button'); profile.type = 'button'; profile.textContent = 'Profili gör';
      profile.addEventListener('click', () => { const dialog = document.createElement('dialog'); dialog.className = 'review-host-dialog'; const heading = document.createElement('h2'); heading.textContent = hostName.textContent; const close = document.createElement('button'); close.textContent = 'Kapat'; close.addEventListener('click',()=>dialog.close()); dialog.append(heading,paragraph(demoPreview ? 'Demo sağlayıcı profili: Torba ve Bodrum bölgesinde konaklama hizmetleri.' : 'Bu ilanın hizmet sağlayıcısı'),close); dialog.addEventListener('close',()=>dialog.remove()); document.body.append(dialog); dialog.showModal(); });
      const share = document.createElement('button'); share.type = 'button'; share.textContent = 'Paylaş ↗';
      share.addEventListener('click', async () => { const url = new URL(location.href); url.search = ''; try { if(navigator.share) await navigator.share({title:listing.title,url:url.href}); else { await navigator.clipboard.writeText(url.href); share.textContent = 'Bağlantı kopyalandı'; } } catch (_) {} });
      actions.append(profile,share); host.append(actions);
      if (demoPreview) { const note = paragraph('Sağlayıcı bilgileri demo amaçlıdır.'); note.className = 'review-host-demo'; host.append(note); }
      reviewCommunity.append(host,reviews); lastSection.after(reviewCommunity);
    }
    const priceNode = document.querySelector('.detail-sidebar [data-price-minor]');
    if (priceNode && hasPricing) {
      const unit = priceNode.querySelector('span');
      priceNode.replaceChildren(document.createTextNode(money), ...(unit ? [unit] : []));
    }
    renderSummary(intro, listing, detailData);
  }
  function renderHolidayHome(main, listing, metadata, amenities, rates, availability, about, detailData) {
    about.querySelector('h2')?.replaceChildren(document.createTextNode('Tatil evi hakkında'));
    const extra = metadata.extra_metadata || {};
    const currency = listing.currency || 'TRY';
    const money = value => new Intl.NumberFormat((window.NEXUS_LOCALE?.lang || 'tr') + (window.NEXUS_LOCALE?.lang === 'tr' ? '-TR' : ''), {style:'currency',currency,maximumFractionDigits:0}).format(Number(value));
    let anchor = amenities;
    const add = node => {anchor.after(node); anchor=node;};
    const poolDimensions = metadata.pool_dimensions || (demoPreview ? '4 m × 14 m × 1,60 m' : '');
    const poolCards=[];
    const privacy=metadata.sheltered_pool;
    if(poolDimensions) poolCards.push({title:'Açık havuz',dimensions:poolDimensions,detail:privacy==='true'||privacy==='yes'?'Muhafazakar / korunaklı havuz':privacy==='false'||privacy==='no'?'Muhafazakar olmayan havuz':'Muhafazakarlık durumu belirtilmemiş'});
    if(demoPreview || extra.pool_heating_status && !['false','no','none'].includes(extra.pool_heating_status)) poolCards.push({title:'Sıcak su havuzu',dimensions:demoPreview?'3 m × 5 m × 1,20 m':'Ölçü bilgisi eklenmemiş',detail:extra.pool_heating_fee ? 'Günlük ısıtma ücreti: '+money(extra.pool_heating_fee) : demoPreview?'Günlük ısıtma ücreti: '+money(1500):'Günlük ısıtma ücreti belirtilmemiş'});
    if(demoPreview) poolCards.push({title:'Çocuk havuzu',dimensions:'2 m × 3 m × 0,40 m'});
    if(poolCards.length){const pool=document.createElement('div');pool.className='reference-pool-information';const heading=document.createElement('h3');heading.textContent='Havuz bilgisi';pool.append(heading);poolCards.forEach(data=>{const card=document.createElement('article');card.className='reference-pool-card';const title=document.createElement('h4');title.textContent=data.title;card.append(title,paragraph('Ölçüler (en × boy × derinlik): '+data.dimensions));if(data.detail)card.append(paragraph(data.detail));pool.append(card);});amenities.append(pool);}
    if (demoPreview && rates) {
      rates.querySelector('h2').textContent='Ücretlendirme';
      rates.querySelector('.reference-section-subtitle').textContent='Döneme göre gecelik ve haftalık konaklama ücretleri.';
      rates.querySelector('.reference-detail-rate')?.remove();
      const table=document.createElement('table'); table.className='reference-villa-prices';
      const header=document.createElement('tr'); ['Dönem','Gecelik','Haftalık'].forEach(text=>{const cell=document.createElement('th');cell.scope='col';cell.textContent=text;header.append(cell);}); const head=document.createElement('thead');head.append(header);table.append(head);
      const body=document.createElement('tbody'); [['1–31 Ekim 2026',5500],['1–30 Kasım 2026',6000],['1–31 Aralık 2026',5000]].forEach(([period,price])=>{const row=document.createElement('tr');[period,money(price),money(price*7)].forEach(text=>{const cell=document.createElement('td');cell.textContent=text;row.append(cell);});body.append(row);});table.append(body);rates.append(table);add(rates);
    }
    const deposit = extra.damage_deposit || (demoPreview ? 10000 : '');
    const shortFee = extra.short_stay_fee || (demoPreview ? 5000 : '');
    const cleaning = metadata.cleaning_fee;
    if(deposit || shortFee || cleaning) { const fees=document.createElement('div'); fees.className='reference-villa-extra-fees'; const heading=document.createElement('h3');heading.textContent='Ek ücretler';fees.append(heading); [[ 'Kısa konaklama ücreti',shortFee],['Hasar depozitosu',deposit],['Temizlik ücreti',cleaning]].forEach(([label,value])=>{if(!value)return;const row=document.createElement('div');row.className='reference-villa-fee';row.append(paragraph(label),paragraph(money(value)));fees.append(row);}); if(deposit){const note=paragraph('Hasar depozitosu, tatil evine girişte nakit olarak ödenir.');note.className='reference-fee-note';fees.append(note);} if(rates){rates.querySelector('h2').textContent='Ücretlendirme';rates.append(fees);if(anchor!==rates)add(rates);} else {const pricing=section('Ücretlendirme');pricing.append(fees);add(pricing);} }
    const percent=Number(metadata.deposit_percent || (demoPreview?30:0));
    if(percent>0){
      const pricing=rates || (anchor!==amenities?anchor:section('Ücretlendirme'));
      pricing.querySelector('h2').textContent='Ücretlendirme';
      const note=paragraph('Rezervasyon sırasında toplam tutarın %'+percent+' oranı ön ödeme olarak alınır.');
      note.className='reference-fee-note reference-advance-payment';
      pricing.append(note);
      if(anchor!==pricing)add(pricing);
    }
    anchor.after(availability); anchor=availability;
    if(!availability.querySelector('.reference-calendar-rules')){
      const notes=document.createElement('ul');notes.className='reference-calendar-rules';
      const minimum=Number(metadata.min_stay_days || extra.short_stay_min_nights || 3);
      ['Minimum konaklama: '+minimum+' gece',minimum+' geceden kısa konaklamalarda ek ücret uygulanır.'].forEach(text=>{const li=document.createElement('li');li.textContent=text;notes.append(li);});
      if(demoPreview){const li=document.createElement('li');li.textContent='Boşluk doldurma: Açıkken, iki dolu aralık arasındaki kısa müsait günleri dolduran konaklamalarda minimum gece kuralı uygulanmaz.';notes.append(li);}
      availability.querySelector('#public-availability')?.before(notes);
    }
    if(demoPreview) { const inclusions=section('Fiyata dahil / hariç','Rezervasyon öncesi dahil olan hizmetleri inceleyin.');const grid=document.createElement('div');grid.className='reference-villa-inclusions';[['Dahil',['Elektrik Kullanımı','Havuz Bakımı','İlk Temizlik','Su Kullanımı','Tüp Kullanımı']],['Hariç',['Ek Temizlik','Ek Yatak','Ulaşım Hizmeti']]].forEach(([title,items])=>{const group=document.createElement('div');const h=document.createElement('h3');h.textContent=title;group.append(h);const list=document.createElement('ul');items.forEach(text=>{const item=document.createElement('li');item.textContent=text;list.append(item);});group.append(list);grid.append(group);});inclusions.append(grid);add(inclusions); }
    const rules=section('Kurallar','Konaklamadan önce giriş, çıkış ve rezervasyon koşullarını inceleyin.');rules.classList.add('reference-villa-rules');const times=document.createElement('div');times.className='reference-rules-grid';[['Giriş',metadata.check_in_time || (demoPreview?'16:00':'')],['Çıkış',metadata.check_out_time || (demoPreview?'10:00':'')]].forEach(([label,value])=>{if(!value)return;const cell=document.createElement('div');const name=document.createElement('small');name.textContent=label;const val=document.createElement('strong');val.textContent=value;cell.append(name,val);times.append(cell);});rules.append(times);
    const minimum=metadata.min_stay_days || extra.short_stay_min_nights || (demoPreview?3:'');
    if(minimum){const minimumNote=paragraph('Minimum konaklama: '+minimum+' gece');minimumNote.className='reference-minimum-stay';rules.append(minimumNote);}
    if(demoPreview){ const list=document.createElement('ul');list.className='reference-hotel-house-rules';['Çocuklara uygun','Evcil hayvan kabul edilmez','Etkinliklere uygun','İç mekanda sigara içilmez'].forEach(text=>{const li=document.createElement('li');li.className=text.includes('edilmez') || text.includes('içilmez')?'rule-restricted':'rule-allowed';const icon=document.createElement('span');icon.className='villa-rule-status';icon.setAttribute('aria-hidden','true');icon.textContent=li.className==='rule-allowed'?'✓':'!';li.append(icon,document.createTextNode(text));list.append(li);});rules.append(list); }
    const policy = detailData.policy?.policy;
    if(policy || demoPreview) { const contract=document.createElement('div'); contract.className='reference-hotel-contract'; const title=document.createElement('h3');title.textContent='Konaklama sözleşmesi ve iptal koşulları';contract.append(title,paragraph(policy || 'Demo sözleşme: ödeme, iptal ve iade koşulları rezervasyon onayında belirtilir.'));rules.append(contract); }
    if(metadata.check_in_time || metadata.check_out_time || minimum || policy || demoPreview)add(rules);
    if(demoPreview){const faq=section('Sıkça sorulan sorular','Konaklamanız hakkında merak ettikleriniz.');[['Giriş ve çıkış saatleri nedir?','Giriş 16:00, çıkış 10:00.'],['Minimum kaç gece konaklamam gerekir?','Minimum konaklama 3 gecedir.'],['Hasar depozitosu nasıl iade edilir?','Çıkışta tesis kontrolünden sonra hasar yoksa iade edilir.'],['Temizlik fiyata dahil mi?','İlk temizlik dahildir. Ek temizlik ayrıca ücretlendirilir.'],['Ön ödeme nasıl yapılır?','Rezervasyon sırasında %30 ön ödeme veya tutarın tamamı ödenebilir.']].forEach(([q,a])=>{const details=document.createElement('details');const summary=document.createElement('summary');summary.textContent=q;details.append(summary,paragraph(a));faq.append(details);});add(faq);}
    if(demoPreview && !main.querySelector('.reference-demo-note')) { const note=document.createElement('small');note.className='reference-demo-note';note.textContent='Demo önizleme • Fiyatlar, hizmetler ve içerikler örnektir.';main.querySelector('.detail-intro')?.append(note); }
  }
  function renderExperienceDetails(main, listing, metadata, amenities, rates, availability, about, detailData) {
    const category=listing.category, extra=metadata.extra_metadata || {};
    const labels={yacht:'Yat kiralama hakkında',tour:'Tur hakkında',activity:'Aktivite hakkında'};
    about.querySelector('h2')?.replaceChildren(document.createTextNode(labels[category]));
    let anchor=amenities;
    const add=node=>{anchor.after(node);anchor=node;};
    const specs=(title,subtitle,items)=>{const node=section(title,subtitle);const grid=document.createElement('div');grid.className='reference-category-specs';items.forEach(([label,value,icon])=>{if(value===undefined || value===null || value==='')return;const item=document.createElement('div');item.className='reference-category-spec';item.append(summaryIcon(icon || 'calendar'));const copy=document.createElement('div');const name=document.createElement('small');name.textContent=label;const content=document.createElement('strong');content.textContent=String(value);copy.append(name,content);item.append(copy);grid.append(item);});node.append(grid);return grid.children.length?node:null;};
    const faq=(entries)=>{const node=section('Sıkça sorulan sorular','Rezervasyon öncesi merak ettikleriniz.');entries.forEach(([q,a])=>{const item=document.createElement('details');const heading=document.createElement('summary');heading.textContent=q;item.append(heading,paragraph(a));node.append(item);});add(node);};
    const inclusions=(yes,no)=>{const node=section('Fiyata dahil / hariç','Paket kapsamını rezervasyon öncesinde inceleyin.');const grid=document.createElement('div');grid.className='reference-villa-inclusions';[['Dahil',yes],['Hariç',no]].forEach(([label,items])=>{const col=document.createElement('div');const title=document.createElement('h3');title.textContent=label;const list=document.createElement('ul');items.forEach(text=>{const item=document.createElement('li');item.textContent=text;list.append(item);});col.append(title,list);grid.append(col);});node.append(grid);add(node);};
    if(category==='yacht') {
      const technical=specs('Teknik özellikler','Yat tipi, kapasite ve charter koşulları.',[
        ['Yat tipi',metadata.yacht_type || extra.boat_type || (demoPreview?'Gulet':''),'bed'],['Liman',metadata.departure_port || extra.port_name || (demoPreview?'Göcek':''),'location'],['Boy',extra.boat_length ? extra.boat_length+' m' : demoPreview?'22 m':'','expand'],['Kabin',metadata.cabin_count || extra.cabin_count || (demoPreview?4:''),'bed'],['Misafir kapasitesi',metadata.capacity || extra.berth_count || (demoPreview?8:''),'guests'],['Kaptan',metadata.captain_included==='true'?'Dahil':metadata.captain_included==='false'?'Hariç':extra.crew_status || (demoPreview?'Dahil':''),'guests'],['Yakıt politikası',metadata.fuel_policy || extra.fuel_policy || (demoPreview?'Planlanan rotada dahil':'')]
      ]);if(technical){technical.classList.add('reference-yacht-technical');technical.querySelector('.reference-category-spec:last-child')?.classList.add('reference-technical-wide');about.after(technical);}
      if(rates){add(rates);let season;try{season=JSON.parse(metadata.season_rules || '{}');}catch(_){season={};}
        const periods=demoPreview ? [['1–31 Ekim 2026',Number(listing.priceMinor || 7500000)/100],['1–30 Kasım 2026',Number(listing.priceMinor || 7500000)/100*.9]] : season.season_start && season.season_end && Number(season.season_price)>0 ? [[season.season_start+' – '+season.season_end,Number(season.season_price)]] : [];
        if(periods.length){rates.querySelector('h2').textContent='Ücretlendirme';rates.querySelector('.reference-detail-rate')?.remove();const table=document.createElement('table');table.className='reference-villa-prices';const head=document.createElement('thead');const row=document.createElement('tr');['Dönem','Gecelik','Haftalık'].forEach(text=>{const cell=document.createElement('th');cell.scope='col';cell.textContent=text;row.append(cell);});head.append(row);table.append(head);const body=document.createElement('tbody');const money=value=>new Intl.NumberFormat('tr-TR',{style:'currency',currency:listing.currency||'TRY',maximumFractionDigits:0}).format(value);periods.forEach(([period,value])=>{const row=document.createElement('tr');[period,money(value),money(value*7)].forEach(text=>{const cell=document.createElement('td');cell.textContent=text;row.append(cell);});body.append(row);});table.append(body);rates.append(table);}
      }
      if(demoPreview){
        const itinerary=section('Seyir rotası','Göcek koylarında örnek 7 gecelik mavi yolculuk programı.');
        [['1. Gün · Göcek','Marinada karşılama, tekneye yerleşme ve güvenlik bilgilendirmesi.'],['2. Gün · Yassıca Adaları','Yüzme molaları ve sakin koylarda dinlenme.'],['3. Gün · Tersane Adası','Tarihi koy ziyareti ve şnorkel molası.'],['4. Gün · Bedri Rahmi Koyu','Doğa yürüyüşü ve koyda geceleme.'],['5. Gün · Sarsala Koyu','Yüzme, paddleboard ve gün batımı.'],['6. Gün · Kleopatra Hamamı Koyu','Antik kalıntılar çevresinde yüzme ve dinlenme.'],['7. Gün · Göcek Adası','Son yüzme molası ve marinaya dönüş.']].forEach(([title,text])=>{const item=document.createElement('details');const summary=document.createElement('summary');summary.textContent=title;item.append(summary,paragraph(text));itinerary.append(item);});add(itinerary);
        const terms=section('Kiralama koşulları','Rezervasyon öncesi süre, ödeme ve güvenlik bilgilerini inceleyin.');
        ['Minimum kiralama: 7 gece.','Rezervasyon sırasında toplam tutarın %35 oranı ön ödeme olarak alınır.','Kalan ödeme ve menü tercihleri hareket öncesinde teyit edilir.','Evcil hayvan kabul edilmez. Kabinlerde sigara içilmez.','Çocuklar yetişkin gözetiminde seyahat eder; can yeleği kullanımı zorunludur.','Rota hava ve deniz koşullarına göre kaptan tarafından değiştirilebilir.'].forEach(text=>terms.append(paragraph(text)));add(terms);
      }
      if(rates){
        const percent=Number(metadata.deposit_percent || extra.deposit_percent || (demoPreview?35:0));
        if(percent>0){const note=paragraph('Rezervasyon sırasında toplam tutarın %'+percent+' oranı ön ödeme olarak alınır.');note.className='reference-fee-note reference-advance-payment';rates.append(note);}
      }
      anchor.after(availability);anchor=availability;
      if(!availability.querySelector('.reference-calendar-rules')){const notes=document.createElement('ul');notes.className='reference-calendar-rules';const item=document.createElement('li');item.textContent='Minimum konaklama: '+(metadata.min_stay_days || (demoPreview?7:1))+' gece';notes.append(item);availability.querySelector('#public-availability')?.before(notes);}
      if(demoPreview)inclusions(['Kaptan ve mürettebat','Standart rota yakıtı','Tekne ekipmanları'],['Özel rota yakıtı','Yiyecek ve içecekler','Özel marina ücretleri']);
      const yachtRules=section('Kurallar','Liman ve saat bilgilerini seyahat öncesinde teyit edin.');yachtRules.classList.add('reference-villa-rules');
      const times=document.createElement('div');times.className='reference-rules-grid';
      const boatTimes=String(extra.boat_times || '').split('/').map(value=>value.trim());
      [['Biniş',metadata.check_in_time || boatTimes[0]],['İniş',metadata.check_out_time || boatTimes[1]]].forEach(([label,value])=>{if(!value)return;const cell=document.createElement('div');const name=document.createElement('small');name.textContent=label;const time=document.createElement('strong');time.textContent=value;cell.append(name,time);times.append(cell);});yachtRules.append(times);
      const minimum=metadata.min_stay_days;if(minimum){const note=paragraph('Minimum konaklama: '+minimum+' gece');note.className='reference-minimum-stay';yachtRules.append(note);}
      if(metadata.departure_port || extra.port_name)yachtRules.append(paragraph('Biniş limanı: '+(metadata.departure_port || extra.port_name)));
      if(demoPreview){const list=document.createElement('ul');list.className='reference-hotel-house-rules';[['Çocuklara uygun',true],['Evcil hayvan kabul edilmez',false],['Kaptan ve mürettebat dahil',true],['Kabinlerde sigara içilmez',false]].forEach(([text,allowed])=>{const item=document.createElement('li');item.className=allowed?'rule-allowed':'rule-restricted';const icon=document.createElement('span');icon.className='villa-rule-status';icon.setAttribute('aria-hidden','true');icon.textContent=allowed?'✓':'!';item.append(icon,document.createTextNode(text));list.append(item);});yachtRules.append(list);}
      if(detailData.policy?.policy){const contract=document.createElement('div');contract.className='reference-hotel-contract';const title=document.createElement('h3');title.textContent='Kiralama sözleşmesi ve iptal koşulları';contract.append(title,paragraph(detailData.policy.policy));yachtRules.append(contract);}add(yachtRules);
      if(demoPreview)faq([['Kaptan ve mürettebat dahil mi?','Bu demo pakette kaptan ve mürettebat dahildir.'],['Yakıt ve liman masrafları kime ait?','Standart rotanın yakıtı dahildir; özel marina ücretleri ayrıca hesaplanır.'],['Hava koşulları programı etkiler mi?','Güvenlik için rota ve hareket saatleri kaptan tarafından güncellenebilir.']]);
    } else {
      const overview=specs(category==='tour'?'Tur bilgileri':'Aktivite bilgileri','Süre, kapasite ve katılım bilgileri.',[
        ['Süre',metadata.duration || extra.duration_hours && extra.duration_hours+' saat' || (demoPreview?category==='tour'?'4 gün / 3 gece':'8 saat':'')],['Grup kapasitesi',metadata.group_size_max || extra.group_size || (demoPreview?16:''),'guests'],['Rehberlik dilleri',metadata.guide_languages || extra.guide_languages || (demoPreview?'TR, EN':'')],['Zorluk',metadata.difficulty || extra.difficulty_level || (demoPreview && category==='activity'?'Kolay':'')],['Yaş sınırı',metadata.age_limit || (demoPreview && category==='activity'?'6+':'')]
      ]);if(overview)about.after(overview);
      if(category==='tour' && (metadata.route || demoPreview)) {const program=section('Tur programı','Gün gün gezi akışı ve önemli duraklar.');const steps=demoPreview?[['1. Gün · Karşılama','Buluşma, transfer ve rehber eşliğinde şehir gezisi.'],['2. Gün · Kültür rotası','Tarihi merkez, müze ziyaretleri ve serbest zaman.'],['3. Gün · Doğa ve keşif','Bölgenin doğal güzellikleri ve yerel deneyimler.'],['4. Gün · Dönüş','Kahvaltı, çıkış işlemleri ve dönüş transferi.']]:[['Rota',metadata.route]];steps.forEach(([title,text],index)=>{const item=document.createElement('details');item.className='reference-program-day';item.open=index===0;const heading=document.createElement('summary');heading.textContent=title;item.append(heading,paragraph(text));program.append(item);});add(program);}
      const meeting=specs(category==='tour'?'Kalkış ve dönüş':'Buluşma noktası ve transfer','Buluşma ve ulaşım detayları.',[['Buluşma noktası',metadata.meeting_point || extra.meeting_point || metadata.start_point || (demoPreview?listing.locality || 'Merkez buluşma noktası':''),'location'],['Dönüş noktası',metadata.end_point || '','location']]);if(meeting)add(meeting);
      if(demoPreview)inclusions(['Rehberlik hizmeti','Programdaki ulaşım',category==='tour'?'Programdaki konaklama':'Belirtilen ekipmanlar'],['Kişisel harcamalar','Ekstra etkinlikler','Bahşişler']);
      if(rates){add(rates);const value=rates.querySelector('.reference-detail-rate strong');if(value){value.append(document.createTextNode(' / kişi'));}}
      if(demoPreview){const rules=section(category==='tour'?'Tur kuralları':'Aktivite kuralları','Katılım öncesi bilmeniz gereken koşullar.');const list=document.createElement('ul');list.className='reference-participation-rules';['Buluşma saatinden en az 15 dakika önce hazır olun.','Rehber veya eğitmenin güvenlik talimatlarına uyun.','Programa uygun kıyafet ve ekipman kullanın.','Hava koşullarına göre program değişebilir.'].forEach(text=>{const item=document.createElement('li');item.textContent=text;list.append(item);});rules.append(list);add(rules);faq([['Rezervasyon nasıl kesinleşir?','Tarih ve katılımcı sayısı seçilerek müsaitlik teyidi alınır.'],['Yanımda ne getirmeliyim?','Rahat kıyafet, uygun ayakkabı ve gerekli kişisel eşyalarınızı getirin.']]);}
    }
    if(category!=='yacht' && detailData.policy?.policy){const rules=section('İptal ve iade','Rezervasyonun iptal ve iade koşulları.');rules.append(paragraph(detailData.policy.policy));add(rules);}
    if(demoPreview && !main.querySelector('.reference-demo-note')){const note=document.createElement('small');note.className='reference-demo-note';note.textContent='Demo önizleme • Program, hizmetler ve koşullar örnektir.';main.querySelector('.detail-intro')?.append(note);}
  }
  function initLocationMap(node, lat, lon) {
    if (!leafletReady) leafletReady = new Promise((resolve, reject) => {
      if (window.L) { resolve(); return; }
      const css = document.createElement('link'); css.rel = 'stylesheet'; css.href = '/static/vendor/leaflet/leaflet.css'; document.head.appendChild(css);
      const script = document.createElement('script'); script.src = '/static/vendor/leaflet/leaflet.js'; script.onload = resolve; script.onerror = reject; document.head.appendChild(script);
    });
    leafletReady.then(() => {
      if (!node.isConnected) return;
      const map = L.map(node, {scrollWheelZoom: false, zoomControl: false}).setView([lat, lon], 13);
      L.tileLayer('https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}', {attribution: 'Tiles &copy; Esri — Esri, HERE, Garmin, OpenStreetMap contributors', maxZoom: 16}).addTo(map);
      L.tileLayer('https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}', {maxZoom: 16}).addTo(map);
      L.control.zoom({position: 'bottomright'}).addTo(map);
      L.circleMarker([lat, lon], {radius: 16, stroke: false, fillColor: '#6366f1', fillOpacity: .2}).addTo(map);
      L.circleMarker([lat, lon], {radius: 7, color: '#fff', weight: 3, fillColor: '#6366f1', fillOpacity: 1}).addTo(map);
      const full = document.createElement('button'); full.type = 'button'; full.className = 'reference-map-fullscreen'; full.textContent = '⛶'; full.setAttribute('aria-label', 'Haritayı tam ekran göster'); node.appendChild(full); full.onclick = () => { if (document.fullscreenElement) document.exitFullscreen(); else node.requestFullscreen?.(); };
      new ResizeObserver(() => map.invalidateSize()).observe(node);
    }).catch(() => { node.textContent = 'Harita şu anda yüklenemiyor.'; });
  }
  function loadNearbyPlaces(section, lat, lon) {
    const status = paragraph('Yakındaki mekanlar yükleniyor…'); section.appendChild(status);
    const controller = new AbortController(); const timeout = setTimeout(() => controller.abort(), 10000);
    const query = '[out:json][timeout:8];(nwr(around:10000,' + lat + ',' + lon + ')[tourism~"attraction|museum"];nwr(around:10000,' + lat + ',' + lon + ')[historic];nwr(around:10000,' + lat + ',' + lon + ')[natural=beach];nwr(around:5000,' + lat + ',' + lon + ')[amenity~"restaurant|pharmacy"];nwr(around:5000,' + lat + ',' + lon + ')[shop=supermarket];nwr(around:50000,' + lat + ',' + lon + ')[aeroway=aerodrome];nwr(around:10000,' + lat + ',' + lon + ')[amenity~"bus_station|ferry_terminal"];);out center tags;';
    const demoPlaces = lat < 37 && lon > 28 ? [
      ['Yassıca Adaları',36.718,28.925,{tourism:'attraction'}],['Göcek Adası',36.725,28.951,{tourism:'attraction'}],['İnlice Plajı',36.730,28.971,{natural:'beach'}],['Göcek Market',36.755,28.944,{shop:'supermarket'}],['Marina Restoranı',36.751,28.944,{amenity:'restaurant'}],['Göcek Eczanesi',36.756,28.947,{amenity:'pharmacy'}],['Dalaman Havalimanı',36.713,28.792,{aeroway:'aerodrome'}],['Göcek Otogarı',36.761,28.947,{amenity:'bus_station'}]
    ] : lon < 27.35 ? [
      ['Yalıkavak Plajı',37.110,27.292,{natural:'beach'}],['Yalıkavak Marina',37.102,27.286,{tourism:'attraction'}],['Yalıkavak Yel Değirmenleri',37.091,27.309,{historic:'monument'}],['Yalıkavak Market',37.106,27.294,{shop:'supermarket'}],['Marina Restoranı',37.102,27.287,{amenity:'restaurant'}],['Yalıkavak Eczanesi',37.107,27.295,{amenity:'pharmacy'}],['Milas-Bodrum Havalimanı',37.250,27.664,{aeroway:'aerodrome'}],['Yalıkavak Otogarı',37.106,27.298,{amenity:'bus_station'}],['Bodrum Feribot İskelesi',37.033,27.431,{amenity:'ferry_terminal'}]
    ] : [
      ['Bodrum Kalesi',37.031,27.430,{historic:'castle'}],['Bodrum Antik Tiyatro',37.042,27.421,{historic:'ruins'}],['Torba Plajı',37.083,27.454,{natural:'beach'}],['Torba Market',37.079,27.459,{shop:'supermarket'}],['Sahil Restoranı',37.080,27.453,{amenity:'restaurant'}],['Torba Eczanesi',37.076,27.452,{amenity:'pharmacy'}],['Milas-Bodrum Havalimanı',37.250,27.664,{aeroway:'aerodrome'}],['Bodrum Otogarı',37.055,27.462,{amenity:'bus_station'}],['Bodrum Feribot İskelesi',37.033,27.431,{amenity:'ferry_terminal'}]
    ];
    const nearbyRequest = demoPreview ? Promise.resolve({elements: demoPlaces.map(([name,lat,lon,tags]) => ({lat,lon,tags:{...tags,name}}))}) : fetch('https://overpass-api.de/api/interpreter', {method: 'POST', body: new URLSearchParams({data: query}), signal: controller.signal}).then(r => { if (!r.ok) throw new Error(); return r.json(); });
    nearbyRequest.then(data => {
      if (!section.isConnected) return;
      const distance = (a, b) => { const rad = x => x * Math.PI / 180; const d = Math.sin(rad(a-lat)/2)**2 + Math.cos(rad(lat))*Math.cos(rad(a))*Math.sin(rad(b-lon)/2)**2; return 6371*2*Math.atan2(Math.sqrt(d),Math.sqrt(1-d)); };
      const groups = [[], [], []]; const seen = new Set();
      (data.elements || []).forEach(place => {
        const name = place.tags?.['name:tr'] || place.tags?.name; const a = place.lat ?? place.center?.lat, b = place.lon ?? place.center?.lon;
        if (!name || !Number.isFinite(a) || !Number.isFinite(b) || seen.has(name)) return; seen.add(name);
        const tags = place.tags; const group = tags.aeroway || ['bus_station', 'ferry_terminal'].includes(tags.amenity) ? 2 : tags.shop || ['restaurant', 'pharmacy'].includes(tags.amenity) ? 1 : 0;
        groups[group].push({name, distance: distance(a,b)});
      });
      status.remove(); const grid = document.createElement('div'); grid.className = 'reference-nearby-grid';
      ['Gezilecek Yerler', 'Temel İhtiyaçlar', 'Ulaşım'].forEach((title, index) => {
        const card = document.createElement('div'); card.className = 'reference-nearby-card'; const heading = document.createElement('h3'); heading.append(summaryIcon(index === 2 ? 'location' : 'view'), document.createTextNode(title)); card.appendChild(heading);
        const places = groups[index].sort((a,b) => a.distance-b.distance); const list = document.createElement('div');
        const render = count => { list.replaceChildren(); places.slice(0,count).forEach(place => { const row = document.createElement('div'); const name = document.createElement('span'); name.textContent = place.name; const km = document.createElement('strong'); km.textContent = place.distance.toLocaleString('tr-TR',{maximumFractionDigits:1,minimumFractionDigits:1}) + ' km'; row.append(name,km); list.appendChild(row); }); }; render(3); card.appendChild(list);
        if (!places.length) card.appendChild(paragraph('Yakında kayıtlı mekan bulunamadı.'));
        if (places.length > 3) { const more = document.createElement('button'); more.type = 'button'; more.textContent = 'Tümünü gör'; let expanded = false; more.onclick = () => { expanded = !expanded; render(expanded ? places.length : 3); more.textContent = expanded ? 'Daha az göster' : 'Tümünü gör'; }; card.appendChild(more); } grid.appendChild(card);
      }); section.append(grid, paragraph('Belirtilen uzaklıklar kuş uçuşudur; yol mesafesi farklı olabilir. Mekan verileri OpenStreetMap kaynaklıdır.'));
    }).catch(() => { status.textContent = 'Yakındaki mekan bilgileri şu anda yüklenemiyor.'; }).finally(() => clearTimeout(timeout));
  }
  function amenityIcon(value) {
    const icons = {
      wifi: 'M3 8a15 15 0 0 1 18 0M6 12a10 10 0 0 1 12 0M9 16a5 5 0 0 1 6 0M12 20h.01',
      water: 'M3 18q3-3 6 0t6 0t6 0M3 22q3-3 6 0t6 0t6 0M8 14V5a2 2 0 0 1 4 0M8 8h8M16 14V5a2 2 0 0 1 4 0',
      beach: 'M3 12a9 9 0 0 1 18 0H3ZM12 3v16a2 2 0 0 0 4 0M3 22h18',
      food: 'M4 3v6a3 3 0 0 0 6 0V3M7 3v19M18 3c-3 3-3 7 0 9h2V3h-2ZM20 12v10',
      fitness: 'M2 9v6M5 6v12M5 12h14M19 6v12M22 9v6',
      parking: 'M4 14l2-7h12l2 7M3 14h18v6H3v-6ZM6 20v2M18 20v2M6 17h2M16 17h2',
      music: 'M9 18V5l11-2v13M9 18a3 3 0 1 1-3-3h3M20 16a3 3 0 1 1-3-3h3',
      ac: 'M12 2v20M3 7l18 10M3 17L21 7M9 4l3 3 3-3M9 20l3-3 3 3',
      generic: 'M9 3h6l1 3h4v15H4V6h4l1-3ZM8 11l2 2 5-5M8 17h8'
    };
    let kind = /pool|aquapark|jacuzzi|water/.test(value) ? 'water' : /beach|sea_view/.test(value) ? 'beach' : /restaurant|alacarte|lunch|bar|bbq/.test(value) ? 'food' : /fitness|tennis/.test(value) ? 'fitness' : /parking|transfer|shuttle/.test(value) ? 'parking' : /music|sound/.test(value) ? 'music' : value;
    const svg = summaryIcon('guests'); svg.classList.add('reference-amenity-icon');
    svg.querySelector('path').setAttribute('d', icons[kind] || icons.generic); return svg;
  }
  function summaryIcon(name) {
    const paths = {
      heart: 'M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z',
      share: 'M8 7l4-4 4 4M12 3v12M8 11H6a2 2 0 0 0-2 2v5a3 3 0 0 0 3 3h10a3 3 0 0 0 3-3v-5a2 2 0 0 0-2-2h-2',
      facebook: 'M14 21v-8h3l.5-4H14V7c0-1 .5-1.5 1.5-1.5H18V2h-3c-3 0-5 2-5 5v2H7v4h3v8M6 2H4a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2h-2',
      email: 'M3 6l9 7 9-7M5 3h14a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3Z',
      twitter: 'M3 3h5l13 18h-5L3 3ZM21 3L3 21',
      instagram: 'M7 2h10a5 5 0 0 1 5 5v10a5 5 0 0 1-5 5H7a5 5 0 0 1-5-5V7a5 5 0 0 1 5-5ZM16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0ZM17.5 6.5h.01',
      whatsapp: 'M21 11.5a9 9 0 0 1-13.4 7.9L3 21l1.6-4.6A9 9 0 1 1 21 11.5ZM8 7l2 3-1 1c1 2 2 3 4 4l1-1 3 2c-1 3-3 2-5 1-3-2-5-4-6-7 0-2 1-3 2-3Z',
      location: 'M15.5 11a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0ZM12 2a9 9 0 0 1 9 9c0 5-6 9-9 11-3-2-9-6-9-11a9 9 0 0 1 9-9Z',
      guests: 'M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0ZM20.25 8.625a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0ZM2.25 19.125a6.375 6.375 0 0 1 12.75 0v.1A12.3 12.3 0 0 1 8.625 21a12.3 12.3 0 0 1-6.375-1.775ZM15 19.125a9.3 9.3 0 0 0 6.75-.6 4.125 4.125 0 0 0-7.5-2.5',
      bed: 'M2 17.5h20M2 21v-5a4 4 0 0 1 4-4h12a4 4 0 0 1 4 4v5M4 12V7a12 12 0 0 1 16 0v5M8 12v-2a10 10 0 0 1 8 0v2',
      bath: 'M2 9h7l6 3h7M3 9v4a6 6 0 0 0 6 6h8a4 4 0 0 0 4-4v-3M5 19v2M19 19v2M4 9V5a3 3 0 0 1 6 0M8 5h4',
      bedroom: 'M5 3h11a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2ZM18 6h3v12h-3M13 10v4',
      calendar: 'M8 2v4M16 2v4M3 9h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z',
      area: 'M3 9V3h6M15 3h6v6M21 15v6h-6M9 21H3v-6M3 3l6 6M21 3l-6 6M21 21l-6-6M3 21l6-6',
      expand: 'M3 7h18v10H3V7ZM7 7v4M11 7v3M15 7v4M19 7v3',
      view: 'M3 3h18v18H3V3ZM3 15l5-5 5 5 3-3 5 5M16 7h.01',
      guest: 'M14 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0ZM3 21v-2a7 7 0 0 1 14 0v2ZM19 7v6M16 10h6',
      star: 'M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.006 5.404.434c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.434 2.082-5.005Z',
    };
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24'); svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor'); svg.setAttribute('stroke-width', '1.5');
    svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('data-keep-symbols', '');
    if (name === 'star') { svg.setAttribute('fill', 'currentColor'); svg.setAttribute('stroke', 'none'); }
    const path = document.createElementNS(svg.namespaceURI, 'path');
    path.setAttribute('d', paths[name]); path.setAttribute('stroke-linecap', 'round'); path.setAttribute('stroke-linejoin', 'round');
    svg.appendChild(path); return svg;
  }
  function renderSummary(intro, listing, detailData) {
    intro.classList.add('reference-summary');
    const heading = intro.querySelector('h1');
    if (heading && listing.category === 'hotel') {
      const fullTitle = listing.title || heading.dataset.fullTitle || heading.textContent.trim();
      heading.dataset.fullTitle = fullTitle;
      const boardNames = { uai: 'Ultra Her Şey Dahil', ai: 'Her Şey Dahil', bb: 'Oda Kahvaltı', hb: 'Yarım Pansiyon', fb: 'Tam Pansiyon', ro: 'Sadece Oda' };
      const suffix = fullTitle.match(/\s*\((Ultra Her Şey Dahil|Her Şey Dahil|Oda Kahvaltı|Yarım Pansiyon|Tam Pansiyon|Sadece Oda)\)\s*$/i);
      const rawBoard = detailData.metadata?.board_type;
      const board = boardNames[rawBoard] || rawBoard || suffix?.[1];
      heading.textContent = suffix ? fullTitle.slice(0, suffix.index).trim() : fullTitle;
      if (board) {
        const group = heading.closest('.summary-title-group') || document.createElement('div');
        if (!group.className) { group.className = 'summary-title-group'; heading.before(group); group.appendChild(heading); }
        const subtitle = document.createElement('p'); subtitle.className = 'reference-hotel-quality'; subtitle.textContent = board;
        group.appendChild(subtitle);
      }
      document.querySelector('.detail-breadcrumb [aria-current=page]')?.replaceChildren(document.createTextNode(heading.textContent));
    }
    intro.querySelector('.detail-favorite')?.replaceChildren(summaryIcon('heart'));
    intro.querySelector('.share-actions button')?.replaceChildren(summaryIcon('share'));
    initSummaryActions(intro);
    const badge = intro.querySelector('.detail-badge');
    if (badge && listing.categoryLabel) badge.textContent = listing.categoryLabel;
    const meta = intro.querySelector('.detail-meta-row');
    if (meta) {
      const rating = document.createElement('span'); rating.className = 'detail-rating';
      const star = summaryIcon('star'); star.classList.add('summary-star');
      rating.appendChild(star);
      rating.appendChild(document.createTextNode(Number(listing.reviewCount) > 0 && listing.ratingAverage ? listing.ratingAverage + ' ' : '— '));
      if (!(Number(listing.reviewCount) > 0 && listing.ratingAverage)) rating.title = 'Henüz değerlendirme bulunmuyor';
      const count = document.createElement('span'); count.className = 'summary-review-count'; count.textContent = '(' + (Number(listing.reviewCount) || 0) + ')'; rating.appendChild(count);
      const dot = document.createElement('span'); dot.className = 'detail-meta-dot'; dot.textContent = '·';
      const place = document.createElement('span'); place.className = 'detail-location';
      place.append(summaryIcon('location'), document.createTextNode(listing.locality || 'Konum eklenmemiş'));
      meta.replaceChildren(rating, dot, place);
      const licenseNo = detailData.metadata?.ministry_license_no || (demoPreview && listing.category === 'holiday_home' ? '48-23' : '');
      if (listing.category === 'hotel' && typeof licenseNo === 'string' && licenseNo.trim()) {
        const license = document.createElement('p'); license.className = 'reference-license';
        license.textContent = 'Kültür ve Turizm Bakanlığı - Basit Konaklama Belgesi: ' + licenseNo.trim();
        meta.after(license);
      }
      if (['holiday_home','yacht'].includes(listing.category)) {
        if (listing.category === 'holiday_home' && licenseNo) { const license=document.createElement('p');license.className='reference-license';license.textContent='T.C. Kültür ve Turizm Bakanlığı Belge No : '+String(licenseNo);meta.before(license); }
        const divider=document.createElement('hr');divider.className='summary-divider';meta.before(divider);
      }
      if (!['hotel','holiday_home','yacht'].includes(listing.category)) {
        const host = document.createElement('div'); host.className = 'reference-host-line';
        const avatar = document.createElement('span'); avatar.className = 'summary-host-avatar';
        avatar.textContent = detailData.ownerName ? detailData.ownerName.trim().slice(0, 1).toLocaleUpperCase('tr-TR') : '—';
        const label = document.createElement('span'); label.appendChild(document.createTextNode('İlan sahibi '));
        const name = document.createElement('strong'); name.textContent = detailData.ownerName || 'Belirtilmemiş'; label.appendChild(name);
        host.append(avatar, label); meta.after(host);
      }
    }
    if (!['holiday_home', 'yacht'].includes(listing.category)) return;
    const facts = document.createElement('div'); facts.className = 'reference-detail-facts';
    // Missing values remain explicit; room capacities are not listing totals.
    (listing.category === 'holiday_home' ? [[listing.guestCount || detailData.metadata?.guests, 'misafir', 'guests'], [listing.bedroomCount || detailData.metadata?.bedrooms, 'oda', 'bedroom'], [listing.bathroomCount || detailData.metadata?.bathrooms, 'banyo', 'bath']] : [[listing.guestCount || detailData.metadata?.capacity || detailData.metadata?.extra_metadata?.berth_count, 'misafir', 'guests'], [detailData.metadata?.cabin_count || listing.bedroomCount, 'kabin', 'bedroom'], [listing.bathroomCount || detailData.metadata?.bathrooms, 'banyo', 'bath']]).forEach(([value, label, icon]) => {
      const fact = document.createElement('span');
      const known = Number(value) > 0;
      if (!known) fact.title = 'Bu bilgi ilana henüz eklenmemiş';
      fact.append(summaryIcon(icon), document.createTextNode((known ? value : '—') + ' ' + label)); facts.appendChild(fact);
    });
    const divider = document.createElement('hr'); divider.className = 'summary-divider'; divider.setAttribute('role', 'presentation');
    intro.append(divider, facts);
  }
  function initSummaryActions(intro) {
    const favorite = intro.querySelector('.detail-favorite');
    if (favorite && !favorite.dataset.restored) {
      favorite.dataset.restored = 'true';
      let saved = [];
      try { saved = JSON.parse(localStorage.getItem('nexus_saved_listings') || '[]'); } catch (_) {}
      const active = Array.isArray(saved) && saved.includes(location.pathname.split('/').pop());
      favorite.classList.toggle('is-active', active);
      favorite.setAttribute('aria-pressed', String(active));
      favorite.setAttribute('aria-label', active ? 'Favorilerden çıkar' : 'Favorilere ekle');
    }
    const original = intro.querySelector('.share-actions button');
    if (!original || original.dataset.shareMenu) return;
    const button = original.cloneNode(true);
    button.removeAttribute('onclick'); original.replaceWith(button);
    button.dataset.shareMenu = 'true'; button.title = 'Paylaş';
    button.setAttribute('aria-label', 'Paylaş'); button.setAttribute('aria-expanded', 'false');
    const menu = document.createElement('div'); menu.className = 'reference-share-menu'; menu.hidden = true;
    menu.id = 'listing-share-menu'; button.setAttribute('aria-controls', menu.id);
    // Preview parameters are local UI state, not part of the public listing address.
    const url = new URL(location.href); url.searchParams.delete('preview'); url.hash = '';
    const address = url.href;
    const title = intro.querySelector('h1')?.textContent || document.title;
    [['Facebook', 'facebook', 'https://www.facebook.com/sharer/sharer.php?u=' + encodeURIComponent(address)],
     ['Email', 'email', 'mailto:?subject=' + encodeURIComponent(title) + '&body=' + encodeURIComponent(address)],
     ['Twitter', 'twitter', 'https://twitter.com/intent/tweet?url=' + encodeURIComponent(address) + '&text=' + encodeURIComponent(title)],
     ['Instagram', 'instagram', 'https://www.instagram.com/'],
     ['WhatsApp', 'whatsapp', 'https://wa.me/?text=' + encodeURIComponent(title + '\n' + address)]].forEach(([label, icon, href]) => {
      const link = document.createElement('a'); link.href = href;
      if (icon !== 'email') { link.target = '_blank'; link.rel = 'noopener noreferrer'; }
      if (icon === 'instagram') {
        link.title = 'Bağlantıyı kopyala ve Instagram’ı aç';
        link.addEventListener('click', async () => {
          let status = intro.querySelector('.reference-share-status');
          if (!status) { status = document.createElement('p'); status.className = 'reference-share-status'; status.setAttribute('role', 'status'); intro.appendChild(status); }
          try {
            await navigator.clipboard.writeText(address);
            status.textContent = 'Bağlantı kopyalandı. Instagram mesajına yapıştırabilirsiniz.';
          } catch (_) {
            status.textContent = 'Instagram’da paylaşmak için ilan bağlantısını kopyalayın.';
            window.prompt('İlan bağlantısı', address);
          }
        });
      }
      link.append(summaryIcon(icon), document.createTextNode(label)); menu.appendChild(link);
    });
    intro.appendChild(menu);
    const close = () => { menu.hidden = true; button.setAttribute('aria-expanded', 'false'); };
    button.addEventListener('click', () => { menu.hidden = !menu.hidden; button.setAttribute('aria-expanded', String(!menu.hidden)); });
    document.addEventListener('click', event => { if (!menu.contains(event.target) && !button.contains(event.target)) close(); });
    document.addEventListener('keydown', event => { if (event.key === 'Escape' && !menu.hidden) { close(); button.focus(); } });
    menu.addEventListener('click', event => { if (event.target.closest('a')) close(); });
  }
  function section(title, subtitle) {
    const node = document.createElement('section');
    node.className = 'listingSection__wrap reference-detail-section';
    const heading = document.createElement('h2');
    heading.textContent = title;
    node.appendChild(heading);
    const descriptions = {
      'Kampanyalar': 'Konaklamanıza özel fırsatlar ve avantajlar.',
      'Tesis Bilgileri': 'Tesisin sunduğu hizmetler ve olanaklar.',
      'Benzer ilanlar': 'İlginizi çekebilecek diğer konaklama seçenekleri.',
      'Yakındaki ilanlar': 'Bu bölgenin yakınındaki konaklama seçenekleri.',
      'İlan sahibi': 'İlanı sunan kişi veya kuruluş hakkında bilgi.',
      'Yakındaki mekanlar': 'Tesis çevresinde keşfedebileceğiniz yerler.'
    };
    const description = paragraph(subtitle || descriptions[title] || (title.startsWith('Yorumlar') ? 'Konaklayan misafirlerin değerlendirmeleri.' : 'İlana ilişkin bilgiler ve detaylar.'));
    description.className = 'reference-section-subtitle';
    node.appendChild(description);
    return node;
  }
  function paragraph(text) {
    const p = document.createElement('p');
    p.textContent = text;
    return p;
  }
  // Insert after the detail template has finished rendering so its description
  // anchor remains stable across the SSR and catalogue render passes.
  const campaignReady = new MutationObserver(() => {
    if (!document.body.classList.contains('detail-template-ready')) return;
    campaignReady.disconnect();
    const intro = document.querySelector('.detail-main .detail-intro');
    const about = intro?.nextElementSibling;
    if (!about) return;
    const campaigns = section('Kampanyalar'); campaigns.classList.add('reference-campaign-section'); campaigns.hidden = true;
    const content = document.createElement('div'); content.className = 'reference-campaign-list'; campaigns.appendChild(content); about.before(campaigns);
    const tenant = document.querySelector('#public-availability')?.dataset.tenant;
    if (demoPreview) { campaigns.hidden = false; [['payment','Tüm kredi kartlarına 12 taksit','Vade farksız 12 taksit ile tatilinizi şimdi planlayın.','12 TAKSİT'],['discount','Erken rezervasyona özel indirim','Seçili tarihlerde konaklamanıza özel fırsatlar.','%15 İNDİRİM'],['calendar','Uzun konaklamaya özel avantaj','7 gece ve üzeri konaklamalarda özel ayrıcalıklar.','UZUN KONAKLAMA']].forEach(([kind,title,description,badge]) => { const card = document.createElement('div'); card.className = 'reference-campaign-card campaign-' + kind; const icon = document.createElement('span'); icon.className = 'campaign-icon'; icon.appendChild(summaryIcon('calendar')); const body = document.createElement('div'); const label = document.createElement('small'); label.className = 'campaign-badge'; label.textContent = badge; const heading = document.createElement('h3'); heading.textContent = title; body.append(label,heading,paragraph(description)); card.append(icon,body); content.appendChild(card); }); return; }
    fetch('/api/public/campaigns' + (tenant ? '?tenant=' + encodeURIComponent(tenant) : ''), {credentials: 'same-origin'})
      .then(response => { if (!response.ok) throw new Error(); return response.json(); })
      .then(items => {
        if (!Array.isArray(items) || !items.length) { campaigns.remove(); return; }
        campaigns.hidden = false;
        items.forEach(item => { const card = document.createElement('div'); card.className = 'reference-campaign-card'; card.append(amenityIcon('tickets'), document.createTextNode(item.name || 'Kampanya')); content.appendChild(card); });
      }).catch(() => campaigns.remove());
  });
  campaignReady.observe(document.body, {attributes: true, attributeFilter: ['class']});
  initReferenceBooking();
  function initReferenceBooking() {
    const form = document.getElementById('booking-form');
    if (!form || form.dataset.referenceBooking) return;
    form.dataset.referenceBooking = 'true';
    const dates = form.querySelector('.chisfis-date-range'), guests = form.querySelector('.chisfis-guest-range');
    if (!dates || !guests) return;
    const fields = document.createElement('div'); fields.className = 'reference-booking-fields';
    dates.before(fields); fields.append(dates, guests);
    dates.querySelector('.chisfis-date-icon')?.replaceChildren(summaryIcon('calendar'));
    guests.querySelector('.chisfis-guest-icon')?.replaceChildren(summaryIcon('guest'));
    const trigger = dates.querySelector('.chisfis-date-trigger'), panel = dates.querySelector('.chisfis-date-panel');
    const label = dates.querySelector('.chisfis-date-value');
    const text = document.createElement('span'); text.className = 'reference-date-text'; label.before(text); text.appendChild(label);
    const sub = document.createElement('span'); sub.className = 'reference-date-sub'; sub.textContent = 'Giriş – Çıkış'; text.appendChild(sub);
    const clear = document.createElement('button'); clear.type = 'button'; clear.className = 'reference-date-clear'; clear.textContent = '×'; clear.setAttribute('aria-label', 'Tarihleri temizle'); dates.appendChild(clear);
    const start = form.querySelector('[name=check_in]'), end = form.querySelector('[name=check_out]');
    const picker = dates.querySelector('.datepicker'); picker.classList.add('reference-booking-calendar'); picker.setAttribute('role', 'dialog');
    const now = new Date(); now.setHours(0, 0, 0, 0);
    let month = new Date(now.getFullYear(), now.getMonth(), 1);
    if (start?.value) {
      const selectedMonth = new Date(start.value + 'T00:00:00');
      if (!Number.isNaN(selectedMonth.getTime())) month = new Date(selectedMonth.getFullYear(), selectedMonth.getMonth(), 1);
    }
    const iso = d => [d.getFullYear(), String(d.getMonth() + 1).padStart(2, '0'), String(d.getDate()).padStart(2, '0')].join('-');
    const summary = document.createElement('div'); summary.className = 'reference-booking-summary'; summary.setAttribute('aria-live', 'polite');
    const pricingEnabled = document.querySelector('.product-detail')?.dataset.category !== 'hotel';
    if (!pricingEnabled) {
      form.classList.add('reference-booking-no-pricing');
      summary.hidden = true;
    }
    const submitWrap = form.querySelector('button[type=submit]').parentElement; submitWrap.before(summary);
    form.querySelector('button[type=submit]').textContent = 'Rezervasyon yap';
    const note = form.closest('.listingSection__wrap').querySelector('small');
    if (note) {
      note.classList.add('reference-booking-note');
      note.textContent = pricingEnabled ? 'Tahmini tutar; kesin fiyat sonraki adımda teyit edilir.' : 'Müsaitlik ve rezervasyon bilgileri sonraki adımda teyit edilir.';
    }
    function close() { panel.removeAttribute('data-open'); trigger.setAttribute('aria-expanded', 'false'); }
    function positionCalendar() {
      if (!panel.hasAttribute('data-open')) return;
      panel.style.removeProperty('top');
      const margin = 12;
      const viewportHeight = window.visualViewport?.height || innerHeight;
      panel.style.maxHeight = Math.max(120, viewportHeight - margin * 2) + 'px';
      const rect = panel.getBoundingClientRect();
      const height = panel.offsetHeight;
      const top = Math.max(margin, Math.min(rect.top, viewportHeight - height - margin));
      panel.style.setProperty('top', 'calc(100% + 10px + ' + (top - rect.top) + 'px)', 'important');
    }
    window.addEventListener('resize', positionCalendar);
    window.addEventListener('scroll', positionCalendar, { passive: true });
    function sync() {
      const short = value => new Date(value + 'T00:00:00').toLocaleDateString(window.NEXUS_LOCALE?.lang || 'tr', { day: 'numeric', month: 'short' });
      label.textContent = start.value ? short(start.value) + ' – ' + (end.value ? short(end.value) : '…') : 'Tarih seçin';
      clear.hidden = !start.value;
      summary.hidden = !pricingEnabled || !start.value || !end.value || end.value <= start.value;
      if (summary.hidden) { summary.replaceChildren(); render(); return; }
      const price = form.closest('.listingSection__wrap').querySelector('[data-price-minor]');
      const minor = Number(price?.dataset.priceMinor || 0), currency = price?.dataset.priceCur || 'TRY';
      const money = n => new Intl.NumberFormat('tr-TR', { style: 'currency', currency, minimumFractionDigits: 2 }).format(n / 100);
      const nights = start.value && end.value ? Math.round((Date.parse(end.value) - Date.parse(start.value)) / 86400000) : 0;
      const nightly = /gece/.test(price?.textContent || '');
      summary.replaceChildren();
      [[nightly && nights > 0 ? money(minor) + ' × ' + nights + ' gece' : 'Başlangıç fiyatı', nightly && nights > 0 ? money(minor * nights) : money(minor)], ['Tahmini toplam', nights > 0 ? money(minor * (nightly ? nights : 1)) : '—']].forEach(([key, value], index) => {
        const row = document.createElement('div'); row.className = index ? 'reference-booking-total' : 'reference-booking-subtotal';
        const name = document.createElement('span'), amount = document.createElement('span'); name.textContent = key; amount.textContent = value; row.append(name, amount); summary.appendChild(row);
      });
      render();
    }
    function choose(value) {
      if (!start.value || end.value || value <= start.value) { start.value = value; end.value = ''; }
      else { end.value = value; close(); trigger.focus(); }
      start.dispatchEvent(new Event('change', { bubbles: true }));
    }
    picker.addEventListener('keydown', event => {
      const day = event.target.closest('button[data-date]');
      const step = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 }[event.key];
      if (!day || !step) return;
      event.preventDefault();
      const date = new Date(day.dataset.date + 'T00:00:00'); date.setDate(date.getDate() + step);
      if (date < now) return;
      if (date < month || date >= new Date(month.getFullYear(), month.getMonth() + 2, 1)) { month = new Date(date.getFullYear(), date.getMonth(), 1); render(); }
      picker.querySelector('button[data-date="' + iso(date) + '"]:not([disabled])')?.focus();
    });
    function render() {
      picker.replaceChildren();
      const nav = document.createElement('div'); nav.className = 'reference-calendar-nav';
      [-1, 1].forEach(step => {
        const button = document.createElement('button'); button.type = 'button'; button.textContent = step < 0 ? '‹' : '›'; button.setAttribute('aria-label', step < 0 ? 'Önceki ay' : 'Sonraki ay');
        button.disabled = step < 0 && month <= new Date(now.getFullYear(), now.getMonth(), 1);
        button.onclick = () => { month = new Date(month.getFullYear(), month.getMonth() + step, 1); render(); }; nav.appendChild(button);
      }); picker.appendChild(nav);
      const months = document.createElement('div'); months.className = 'reference-calendar-months';
      for (let offset = 0; offset < 2; offset++) {
        const first = new Date(month.getFullYear(), month.getMonth() + offset, 1);
        const section = document.createElement('section'); section.className = 'reference-calendar-month';
        const heading = document.createElement('h3'); heading.textContent = first.toLocaleDateString(window.NEXUS_LOCALE?.lang || 'tr', { month: 'long', year: 'numeric' }); section.appendChild(heading);
        const grid = document.createElement('div'); grid.className = 'reference-calendar-grid';
        Array.from({length:7},(_,i)=>new Date(2026,0,4+i).toLocaleDateString(window.NEXUS_LOCALE?.lang || 'tr',{weekday:'short'})).forEach(day => { const label = document.createElement('span'); label.textContent = day; grid.appendChild(label); });
        // Keep the previous month's trailing dates visible, as in the reference calendar.
        const leading = first.getDay();
        const previousCount = new Date(first.getFullYear(), first.getMonth(), 0).getDate();
        for (let i = leading - 1; i >= 0; i--) {
          const date = new Date(first.getFullYear(), first.getMonth() - 1, previousCount - i);
          const day = document.createElement('button'); day.type = 'button'; day.textContent = date.getDate(); day.dataset.date = iso(date); day.disabled = true; day.className = 'is-other-month';
          day.setAttribute('aria-label', date.toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', year: 'numeric' }));
          grid.appendChild(day);
        }
        const count = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
        for (let i = 1; i <= count; i++) {
          const date = new Date(first.getFullYear(), first.getMonth(), i), value = iso(date);
          const day = document.createElement('button'); day.type = 'button'; day.textContent = i; day.dataset.date = value; day.disabled = date < now;
          day.setAttribute('aria-label', date.toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', year: 'numeric' }));
          const selected = value === start.value || value === end.value;
          day.setAttribute('aria-pressed', String(selected)); day.classList.toggle('is-selected', selected); day.classList.toggle('in-range', !!(end.value && value > start.value && value < end.value));
          day.onclick = () => choose(value); grid.appendChild(day);
        }
        section.appendChild(grid); months.appendChild(section);
      } picker.appendChild(months);
      requestAnimationFrame(positionCalendar);
    }
    trigger.addEventListener('click', event => {
      event.stopPropagation();
      if (panel.hasAttribute('data-open')) close();
      else { guests.querySelector('.chisfis-guest-panel').removeAttribute('data-open'); guests.querySelector('.chisfis-guest-trigger').setAttribute('aria-expanded', 'false'); render(); panel.setAttribute('data-open', ''); trigger.setAttribute('aria-expanded', 'true'); positionCalendar(); }
    });
    clear.onclick = event => { event.stopPropagation(); start.value = ''; end.value = ''; start.dispatchEvent(new Event('change', { bubbles: true })); close(); };
    document.addEventListener('nexus:lang',sync);
    guests.querySelector('.chisfis-guest-trigger').addEventListener('click', close);
    panel.addEventListener('click', event => event.stopPropagation());
    document.addEventListener('click', event => { if (!dates.contains(event.target)) close(); });
    document.addEventListener('keydown', event => { if (event.key === 'Escape') { close(); } });
    start.addEventListener('change', sync);
    form.addEventListener('submit', event => { if (!start.value || !end.value || end.value <= start.value) { event.preventDefault(); render(); panel.setAttribute('data-open', ''); trigger.setAttribute('aria-expanded', 'true'); trigger.focus(); positionCalendar(); } });
    sync(); close();
  }
  const today = new Date().toISOString().slice(0, 10);
  document.querySelectorAll('.booking-quick-form').forEach(form => {
    const dates = form.querySelectorAll('input[type="date"]');
    if (dates.length > 1) {
      dates[0].min = today;
      dates[1].min = today;
      dates[0].addEventListener('change', () => { dates[1].min = dates[0].value || today; });
      form.addEventListener('submit', event => {
        if (!dates[0].value || !dates[1].value || dates[1].value <= dates[0].value) {
          event.preventDefault();
          dates[1].setCustomValidity('Çıkış tarihi giriş tarihinden sonra olmalıdır.');
          dates[1].reportValidity();
        } else dates[1].setCustomValidity('');
      });
    }
  });
  // ---- Galeri: chisfis-final listing.html düzeni ----
  // Solda büyük ana görsel (2 satır) + sağda 2x2 ızgara; 5+ görselde 4.
  // karede "+N" rozeti; alt solda "Show all photos"; tümü lightbox açar.
  document.querySelectorAll('.detail-gallery[data-images]').forEach(gallery => {
    let images = [];
    try { images = JSON.parse(gallery.dataset.images || '[]'); } catch (_) {}
    // Repair the retired yacht image used by legacy seeded listings.
    images = images.map(value => typeof value === 'string' ? value.replace('photo-1569263979104-865ab7cd8d17','photo-1567899378494-47b22a2ae96a') : value);
    images = images.filter(value => typeof value === 'string' && (/^https?:\/\//i.test(value) || /^\/(?!\/)/.test(value)));
    if (!images.length) { gallery.classList.add('detail-gallery-empty'); gallery.textContent = 'Görseller yakında eklenecek'; return; }
    // Izgara düzeni görüntü sayısına göre: 1 → tam genişlik, 2 → tek satır ikili,
    // 3+ → solda büyük (2 satır) + sağda 2x2.
    gallery.classList.add(images.length === 1 ? 'g1' : images.length === 2 ? 'g2' : 'g3plus');
    gallery.setAttribute('role', 'group');
    gallery.setAttribute('aria-label', 'Ürün görselleri');
    const build = (src, cls, label, extraText) => {
      const cell = document.createElement('button');
      cell.type = 'button';
      cell.className = cls;
      cell.setAttribute('aria-label', label);
      const img = document.createElement('img');
      img.src = src;
      img.alt = '';
      img.loading = cls === 'gallery-main' ? 'eager' : 'lazy';
      cell.appendChild(img);
      if (extraText) {
        const more = document.createElement('span');
        more.className = 'gallery-more';
        more.textContent = extraText;
        cell.appendChild(more);
      }
      return cell;
    };
    const shown = images.slice(0, 5);
    gallery.dataset.photoCount=String(images.length);
    shown.forEach((src, index) => {
      const isMain = index === 0;
      const isLastVisible = index === 4 && images.length > 5;
      const extra = isLastVisible ? '+' + (images.length - 5) : null;
      const cell = build(
        src,
        isMain ? 'gallery-main' : 'gallery-sub',
        'Görseli büyüt: ' + (index + 1),
        extra,
      );
      const open = () => openLightbox(images, index % images.length);
      cell.addEventListener('click', open);
      gallery.appendChild(cell);
    });
    if (images.length > 1) {
      const showAll = document.createElement('button');
      showAll.type = 'button';
      showAll.className = 'gallery-showall';
      showAll.textContent = 'Tüm fotoğrafları göster';
      showAll.addEventListener('click', () => openLightbox(images, 0));
      gallery.appendChild(showAll);
    }
  });

  // ---- Ana görsel hover zoom lens -------------------------------------------
  document.querySelectorAll('.detail-gallery').forEach(gallery => {
    const mainImg = gallery.querySelector('.gallery-main');
    if (!mainImg) return;
    const img = mainImg.querySelector('img');
    if (!img) return;

    // Lens konteyneri oluştur
    const lens = document.createElement('div');
    lens.className = 'zoom-lens';
    lens.setAttribute('aria-hidden', 'true');
    mainImg.style.position = 'relative';
    mainImg.style.overflow = 'hidden';
    mainImg.appendChild(lens);

    // Büyük görüntü konteyneri
    const zoomResult = document.createElement('div');
    zoomResult.className = 'zoom-result';
    zoomResult.setAttribute('aria-hidden', 'true');
    mainImg.appendChild(zoomResult);

    const ZOOM = 2.5; // yakınlaştırma oranı
    let active = false;

    function activate() {
      if (!img.naturalWidth) return;
      active = true;
      lens.classList.add('active');
      zoomResult.classList.add('active');
      // Büyük görüntüyü ayarla — img.src zaten safeImageSrc ile doğrulandı;
      // url() içinde tırnak/parantez enjeksiyonuna karşı güvenli tırnaklama.
      zoomResult.style.backgroundImage = 'url("' + img.src.replace(/[()"'\\]/g, encodeURIComponent) + '")';
      zoomResult.style.backgroundSize = (img.naturalWidth * ZOOM) + 'px ' + (img.naturalHeight * ZOOM) + 'px';
    }

    function deactivate() {
      active = false;
      lens.classList.remove('active');
      zoomResult.classList.remove('active');
    }

    function moveLens(e) {
      if (!active) return;
      const rect = mainImg.getBoundingClientRect();
      let x = e.clientX - rect.left;
      let y = e.clientY - rect.top;
      // Lens sınırları
      const lensW = lens.offsetWidth;
      const lensH = lens.offsetHeight;
      x = Math.max(lensW / 2, Math.min(x, rect.width - lensW / 2));
      y = Math.max(lensH / 2, Math.min(y, rect.height - lensH / 2));
      lens.style.left = (x - lensW / 2) + 'px';
      lens.style.top = (y - lensH / 2) + 'px';
      // Büyük görüntü konumu (ters orantılı)
      const bgX = -(x * ZOOM - zoomResult.offsetWidth / 2);
      const bgY = -(y * ZOOM - zoomResult.offsetHeight / 2);
      zoomResult.style.backgroundPosition = bgX + 'px ' + bgY + 'px';
    }

    mainImg.addEventListener('mouseenter', activate);
    mainImg.addEventListener('mouseleave', deactivate);
    mainImg.addEventListener('mousemove', moveLens);
  });

  // ---- Lightbox: escape/overlay kapatma, ok tuşları + düğmeler, odak yönetimi ----
  let lightboxState = null; // {images, index, lastFocus}
  function openLightbox(images, index) {
    closeLightbox();
    const overlay = document.createElement('div');
    overlay.className = 'chisfis-lightbox';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Görsel görüntüleyici');
    overlay.innerHTML =
      '<button type="button" class="chisfis-lightbox__close" aria-label="Kapat (Esc)">×</button>' +
      '<button type="button" class="chisfis-lightbox__nav chisfis-lightbox__nav--prev" aria-label="Önceki görsel">‹</button>' +
      '<figure class="chisfis-lightbox__stage"><img alt="" /><figcaption></figcaption></figure>' +
      '<button type="button" class="chisfis-lightbox__nav chisfis-lightbox__nav--next" aria-label="Sonraki görsel">›</button>' +
      // Klavye kısayol göstergeleri + miniatür şeridi (tek görselde gizlenir)
      '<div class="chisfis-lightbox__keys" aria-hidden="true">' +
      '<span class="chisfis-lightbox__key">←</span><span class="chisfis-lightbox__key">→</span>' +
      '<span class="chisfis-lightbox__keys-label">gez</span>' +
      '<span class="chisfis-lightbox__key">Esc</span>' +
      '<span class="chisfis-lightbox__keys-label">kapat</span>' +
      '</div>' +
      '<div class="chisfis-lightbox__thumbs" role="tablist" aria-label="Görseller"></div>';
    const img = overlay.querySelector('img');
    const caption = overlay.querySelector('figcaption');
    const state = { images, index, lastFocus: document.activeElement, overlay };
    lightboxState = state;
    // Miniatür şeridi: her görsel için küçük kare; aktif işaretli, tıklanabilir.
    const thumbsWrap = overlay.querySelector('.chisfis-lightbox__thumbs');
    const keyHints = overlay.querySelector('.chisfis-lightbox__keys');
    const many = state.images.length > 1;
    if (many) {
      state.images.forEach((src, i) => {
        const t = document.createElement('button');
        t.type = 'button';
        t.className = 'chisfis-lightbox__thumb';
        t.setAttribute('role', 'tab');
        t.setAttribute('aria-label', (i + 1) + '. görsel');
        t.setAttribute('aria-selected', 'false');
        const im = document.createElement('img');
        im.src = src;
        im.alt = '';
        im.loading = 'lazy';
        t.appendChild(im);
        t.addEventListener('click', () => { state.index = i; render(); });
        thumbsWrap.appendChild(t);
      });
    } else {
      thumbsWrap.style.display = 'none';
      keyHints.style.display = 'none';
    }
    // Preload havuzu: önceden yüklenmiş görseller
    const preloaded = new Map();
    function preloadImage(src) {
      if (preloaded.has(src)) return preloaded.get(src);
      const p = new Image();
      p.src = src;
      preloaded.set(src, p);
      return p;
    }
    // Komşu görselleri önceden yükle
    function preloadAdjacent() {
      if (!many) return;
      const len = state.images.length;
      preloadImage(state.images[(state.index + 1) % len]);
      preloadImage(state.images[(state.index - 1 + len) % len]);
    }

    // Fade animasyonu ile render
    let transitioning = false;
    function render() {
      if (transitioning) return; // animasyon sırasında binme engeli
      const newSrc = state.images[state.index];
      const sameSrc = img.src === newSrc || img.getAttribute('src') === newSrc;
      if (sameSrc) {
        // Sadece thumb/caption güncelle (aynı görsel)
        updateUI();
        return;
      }
      // Fade-out → src değiştir → fade-in
      transitioning = true;
      img.classList.add('chisfis-lightbox__img--fading');
      setTimeout(function () {
        img.src = newSrc;
        img.onload = function () {
          img.classList.remove('chisfis-lightbox__img--fading');
          img.classList.add('chisfis-lightbox__img--visible');
          transitioning = false;
          preloadAdjacent();
        };
        img.onerror = function () {
          img.classList.remove('chisfis-lightbox__img--fading');
          transitioning = false;
        };
      }, 180); // fade-out süresi
      updateUI();
    }
    function updateUI() {
      caption.textContent = (state.index + 1) + ' / ' + state.images.length;
      overlay.querySelector('.chisfis-lightbox__nav--prev').style.display = many ? '' : 'none';
      overlay.querySelector('.chisfis-lightbox__nav--next').style.display = many ? '' : 'none';
      if (many) {
        thumbsWrap.querySelectorAll('.chisfis-lightbox__thumb').forEach((t, i) => {
          const on = i === state.index;
          t.classList.toggle('active', on);
          t.setAttribute('aria-selected', on ? 'true' : 'false');
        });
        const active = thumbsWrap.querySelector('.chisfis-lightbox__thumb.active');
        if (active) active.scrollIntoView({ block: 'nearest', inline: 'center', behavior: 'smooth' });
      }
    }
    function step(delta) {
      if (transitioning) return;
      state.index = (state.index + delta + state.images.length) % state.images.length;
      render();
    }
    state.step = step; state.render = render;
    render();
    // İlk görsel yüklendikten sonra komşuları preload et
    img.addEventListener('load', function onLoad() {
      img.removeEventListener('load', onLoad);
      preloadAdjacent();
    });
    overlay.addEventListener('click', e => { if (e.target === overlay) closeLightbox(); });
    overlay.querySelector('.chisfis-lightbox__close').addEventListener('click', closeLightbox);
    overlay.querySelector('.chisfis-lightbox__nav--prev').addEventListener('click', () => step(-1));
    overlay.querySelector('.chisfis-lightbox__nav--next').addEventListener('click', () => step(1));
    state.onKey = e => {
      if (e.key === 'Escape') closeLightbox();
      else if (e.key === 'ArrowLeft') step(-1);
      else if (e.key === 'ArrowRight') step(1);
      else if (e.key === 'Tab') {
        // odak lightbox içinde dönsün
        const focusables = overlay.querySelectorAll('button');
        const first = focusables[0], last = focusables[focusables.length - 1];
        if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
        else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
      }
    };
    document.addEventListener('keydown', state.onKey);
    // ---- Touch swipe: mobilde sola/sağa kaydırma ile görsel geçişi ----
    let touchStartX = 0, touchStartY = 0, touchDeltaX = 0, swiping = false;
    const SWIPE_THRESHOLD = 50; // minimum px
    const imgEl = overlay.querySelector('img');

    overlay.addEventListener('touchstart', e => {
      if (e.touches.length !== 1) return;
      touchStartX = e.touches[0].clientX;
      touchStartY = e.touches[0].clientY;
      touchDeltaX = 0;
      swiping = true;
      imgEl.style.transition = 'none';
    }, { passive: true });

    overlay.addEventListener('touchmove', e => {
      if (!swiping || e.touches.length !== 1) return;
      const dx = e.touches[0].clientX - touchStartX;
      const dy = e.touches[0].clientY - touchStartY;
      // Yatay hareket dikeyden büyükse swipe olarak kabul et
      if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 10) {
        e.preventDefault();
        touchDeltaX = dx;
        // Görseli parmakla sürükleme feedback
        const clamp = Math.max(-120, Math.min(120, dx));
        imgEl.style.transform = 'translateX(' + clamp + 'px) scale(' + (1 - Math.abs(clamp) * 0.0005) + ')';
        imgEl.style.opacity = String(1 - Math.abs(clamp) * 0.003);
      }
    }, { passive: false });

    overlay.addEventListener('touchend', () => {
      if (!swiping) return;
      swiping = false;
      imgEl.style.transition = '';
      imgEl.style.transform = '';
      imgEl.style.opacity = '';
      if (Math.abs(touchDeltaX) >= SWIPE_THRESHOLD) {
        // Sola kaydır → sonraki, sağa kaydır → önceki
        step(touchDeltaX < 0 ? 1 : -1);
      }
    }, { passive: true });

    document.body.style.overflow = 'hidden';
    document.body.appendChild(overlay);
    overlay.querySelector('.chisfis-lightbox__close').focus();
  }
  function closeLightbox() {
    if (!lightboxState) return;
    document.removeEventListener('keydown', lightboxState.onKey);
    document.body.style.overflow = '';
    lightboxState.overlay.remove();
    if (lightboxState.lastFocus && lightboxState.lastFocus.isConnected) lightboxState.lastFocus.focus();
    lightboxState = null;
  }

  // ---- Tarih seçici: şablon datepicker dili (input[type=date] yerine takvim paneli) ----
  // Markup: <div class="datepicker">… yıl/ay başlığı, gün adları, gün ızgarası …
  // Özellikler: hızlı preset butonları, klavye gezintisi, yıl/ay hızlı atlama.
  const MONTHS_TR = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
  const DAYS_TR = ['Pt','Sa','Ça','Pe','Cu','Ct','Pz'];
  function sameDay(a, b) { return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
  function isoDate(d) { const p = n => String(n).padStart(2, '0'); return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate()); }
  function fmtShort(d) { return d.getDate() + ' ' + MONTHS_TR[d.getMonth()].slice(0, 3).toLocaleLowerCase('tr'); }

  // Hızlı preset hesaplayıcıları
  function presetToday() { var d = new Date(); d.setHours(0,0,0,0); return d; }
  function presetTomorrow() { var d = new Date(); d.setDate(d.getDate()+1); d.setHours(0,0,0,0); return d; }
  function presetThisWeekEnd() { var d = new Date(); d.setDate(d.getDate() + (6 - ((d.getDay()+6)%7))); d.setHours(0,0,0,0); return d; }
  function presetNextWeek() { var d = new Date(); d.setDate(d.getDate() + 7); d.setHours(0,0,0,0); return d; }
  function presetNextWeekEnd() { var d = new Date(); d.setDate(d.getDate() + (7 + 6 - ((d.getDay()+6)%7))); d.setHours(0,0,0,0); return d; }
  function presetThisMonthEnd() { var d = new Date(); d.setMonth(d.getMonth()+1, 0); d.setHours(0,0,0,0); return d; }

  document.querySelectorAll('.chisfis-date-range').forEach(container => {
    if (container.closest('#booking-form')) return;
    const nativeIn = container.querySelector('input[name="check_in"]');
    const nativeOut = container.querySelector('input[name="check_out"]');
    if (!nativeIn || !nativeOut) return;
    const trigger = container.querySelector('.chisfis-date-trigger');
    const panel = container.querySelector('.chisfis-date-panel');
    const picker = container.querySelector('.datepicker');
    const valueLabel = trigger.querySelector('.chisfis-date-value');
    if (!trigger || !panel || !picker) return;
    // native inputlar form için doldurulur; görsel olarak gizli
    nativeIn.tabIndex = -1;
    nativeOut.tabIndex = -1;
    let viewYear, viewMonth, focusedDay = null;
    const today = new Date(); today.setHours(0, 0, 0, 0);
    let start = nativeIn.value ? new Date(nativeIn.value + 'T00:00:00') : null;
    let end = nativeOut.value ? new Date(nativeOut.value + 'T00:00:00') : null;
    function updateLabel() {
      valueLabel.textContent = start && end ? fmtShort(start) + ' – ' + fmtShort(end)
        : start ? fmtShort(start) + ' – …'
        : 'Tarih seçin';
      trigger.classList.toggle('chisfis-date-trigger--filled', !!(start && end));
    }
    function setNative() {
      nativeIn.value = start ? isoDate(start) : '';
      nativeOut.value = end ? isoDate(end) : '';
      nativeIn.dispatchEvent(new Event('change', { bubbles: true }));
    }
    nativeIn.addEventListener('change', () => {
      start = nativeIn.value ? new Date(nativeIn.value + 'T00:00:00') : null;
      end = nativeOut.value ? new Date(nativeOut.value + 'T00:00:00') : null;
      updateLabel(); paint();
    });
    function close() { panel.removeAttribute('data-open'); trigger.setAttribute('aria-expanded', 'false'); focusedDay = null; }
    function open() {
      panel.setAttribute('data-open', '');
      trigger.setAttribute('aria-expanded', 'true');
      if (!start) { viewYear = today.getFullYear(); viewMonth = today.getMonth(); }
      focusedDay = today.getDate();
      render();
      // Klavye gezintisi: açılışta bugüne odaklan
      requestAnimationFrame(function() {
        var firstBtn = picker.querySelector('button.datepicker__day:not(.datepicker__day--disabled):not(.datepicker__day--outside-month)');
        if (firstBtn) firstBtn.focus();
      });
    }
    trigger.addEventListener('click', e => {
      e.stopPropagation();
      if (panel.hasAttribute('data-open')) close(); else open();
    });
    panel.addEventListener('click', e => e.stopPropagation());
    document.addEventListener('click', e => { if (panel.hasAttribute('data-open') && !container.contains(e.target)) close(); });
    document.addEventListener('keydown', e => { if (e.key === 'Escape' && panel.hasAttribute('data-open')) { close(); trigger.focus(); } });

    // ---- Klavye gezintisi: ok tuşları, Enter/Space seçimi ----
    panel.addEventListener('keydown', e => {
      if (!panel.hasAttribute('data-open')) return;
      var active = document.activeElement;
      if (!active || !active.classList.contains('datepicker__day')) return;
      var dayNum = parseInt(active.textContent, 10);
      if (isNaN(dayNum)) return;
      var dim = new Date(viewYear, viewMonth + 1, 0).getDate();
      var handled = false;
      if (e.key === 'ArrowRight') { dayNum = Math.min(dayNum + 1, dim); handled = true; }
      else if (e.key === 'ArrowLeft') { dayNum = Math.max(dayNum - 1, 1); handled = true; }
      else if (e.key === 'ArrowDown') { dayNum = Math.min(dayNum + 7, dim); handled = true; }
      else if (e.key === 'ArrowUp') { dayNum = Math.max(dayNum - 7, 1); handled = true; }
      else if (e.key === 'Home') { dayNum = 1; handled = true; }
      else if (e.key === 'End') { dayNum = dim; handled = true; }
      else if (e.key === 'PageDown') { viewMonth++; if (viewMonth > 11) { viewMonth = 0; viewYear++; } render(); focusDay(Math.min(dayNum, new Date(viewYear, viewMonth+1, 0).getDate())); handled = true; }
      else if (e.key === 'PageUp') { viewMonth--; if (viewMonth < 0) { viewMonth = 11; viewYear--; } render(); focusDay(Math.min(dayNum, new Date(viewYear, viewMonth+1, 0).getDate())); handled = true; }
      else if (e.key === 'Enter' || e.key === ' ') {
        var d = new Date(viewYear, viewMonth, dayNum);
        if (d < today) return;
        if (!start || (start && end)) { start = d; end = null; }
        else if (d <= start) { start = d; }
        else { end = d; close(); trigger.focus(); }
        paint(); updateLabel(); setNative();
        handled = true;
      }
      if (handled) { e.preventDefault(); focusDay(dayNum); }
    });

    function focusDay(day) {
      focusedDay = day;
      requestAnimationFrame(function() {
        var btns = picker.querySelectorAll('button.datepicker__day:not(.datepicker__day--outside-month)');
        btns.forEach(function(b) {
          if (parseInt(b.textContent, 10) === day) b.focus();
        });
      });
    }

    // ---- Yıl/ay hızlı atlama dropdown'ları ----
    function buildMonthYearHeader() {
      var header = document.createElement('div');
      header.className = 'datepicker__header';

      // Yıl dropdown
      var yearSel = document.createElement('select');
      yearSel.className = 'datepicker__year-select';
      yearSel.setAttribute('aria-label', 'Yıl seç');
      var curYear = today.getFullYear();
      for (var y = curYear; y <= curYear + 5; y++) {
        var opt = document.createElement('option');
        opt.value = y; opt.textContent = y;
        if (y === viewYear) opt.selected = true;
        yearSel.appendChild(opt);
      }
      yearSel.addEventListener('change', function() {
        viewYear = parseInt(this.value, 10);
        focusedDay = 1;
        render();
      });

      // Ay dropdown
      var monthSel = document.createElement('select');
      monthSel.className = 'datepicker__month-select';
      monthSel.setAttribute('aria-label', 'Ay seç');
      MONTHS_TR.forEach(function(name, i) {
        var opt = document.createElement('option');
        opt.value = i; opt.textContent = name;
        if (i === viewMonth) opt.selected = true;
        monthSel.appendChild(opt);
      });
      monthSel.addEventListener('change', function() {
        viewMonth = parseInt(this.value, 10);
        focusedDay = 1;
        render();
      });

      var prev = document.createElement('button');
      prev.type = 'button';
      prev.className = 'datepicker__nav datepicker__nav--prev';
      prev.setAttribute('aria-label', 'Önceki ay');
      prev.textContent = '‹';

      var next = document.createElement('button');
      next.type = 'button';
      next.className = 'datepicker__nav datepicker__nav--next';
      next.setAttribute('aria-label', 'Sonraki ay');
      next.textContent = '›';

      var titleWrap = document.createElement('span');
      titleWrap.className = 'datepicker__title-wrap';
      titleWrap.appendChild(monthSel);
      titleWrap.appendChild(yearSel);

      header.appendChild(prev);
      header.appendChild(titleWrap);
      header.appendChild(next);
      return header;
    }

    function render() {
      picker.querySelectorAll('.datepicker__month-container').forEach(el => el.remove());
      const month = document.createElement('div');
      month.className = 'datepicker__month-container';

      // Hızlı preset butonları (sadece başlangıç henüz seçilmediyse)
      var presets = [
        { label: 'Bugün', fn: presetToday },
        { label: 'Yarın', fn: presetTomorrow },
        { label: 'Bu hafta sonu', fn: presetThisWeekEnd },
        { label: 'Gelecek hafta', fn: presetNextWeek },
        { label: 'Bu ay sonu', fn: presetThisMonthEnd }
      ];
      var presetBar = document.createElement('div');
      presetBar.className = 'datepicker__presets';
      presets.forEach(function(p) {
        var btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'datepicker__preset-btn';
        btn.textContent = p.label;
        btn.addEventListener('click', function(e) {
          e.stopPropagation();
          var d = p.fn();
          if (!start || (start && end)) {
            start = d; end = null;
          } else if (d <= start) {
            start = d;
          } else {
            end = d;
          }
          viewYear = start.getFullYear();
          viewMonth = start.getMonth();
          focusedDay = start.getDate();
          paint(); updateLabel(); setNative();
          if (start && end) close();
        });
        presetBar.appendChild(btn);
      });
      month.appendChild(presetBar);

      const first = new Date(viewYear, viewMonth, 1);

      // Yıl/ay dropdown header
      const header = buildMonthYearHeader();
      month.appendChild(header);
      const daysRow = document.createElement('div');
      daysRow.className = 'datepicker__days-of-week';
      DAYS_TR.forEach(d => { const s = document.createElement('span'); s.className = 'datepicker__day-name'; s.textContent = d; daysRow.appendChild(s); });
      month.appendChild(daysRow);
      const grid = document.createElement('div');
      grid.className = 'datepicker__days';
      grid.setAttribute('role', 'grid');
      grid.setAttribute('aria-label', MONTHS_TR[viewMonth] + ' ' + viewYear);
      const lead = (first.getDay() + 6) % 7;
      for (let i = 0; i < lead; i++) { const pad = document.createElement('span'); pad.className = 'datepicker__day datepicker__day--outside-month'; grid.appendChild(pad); }
      const dim = new Date(viewYear, viewMonth + 1, 0).getDate();
      for (let day = 1; day <= dim; day++) {
        const d = new Date(viewYear, viewMonth, day);
        const cell = document.createElement('button');
        cell.type = 'button';
        cell.className = 'datepicker__day';
        cell.textContent = String(day);
        cell.setAttribute('role', 'gridcell');
        if (d < today) { cell.classList.add('datepicker__day--disabled'); cell.disabled = true; }
        cell.setAttribute('aria-label', d.toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', year: 'numeric' }));
        if (focusedDay === day && !cell.disabled) cell.setAttribute('tabindex', '0');
        else cell.setAttribute('tabindex', '-1');
        grid.appendChild(cell);
      }
      month.appendChild(grid);
      picker.appendChild(month);
      paint();

      // Nav button handlers
      header.querySelector('.datepicker__nav--prev').addEventListener('click', () => { viewMonth--; if (viewMonth < 0) { viewMonth = 11; viewYear--; } render(); });
      header.querySelector('.datepicker__nav--next').addEventListener('click', () => { viewMonth++; if (viewMonth > 11) { viewMonth = 0; viewYear++; } render(); });
      grid.addEventListener('click', e => {
        const dayEl = e.target.closest('button.datepicker__day');
        if (!dayEl || dayEl.disabled) return;
        const day = Number(dayEl.textContent);
        const d = new Date(viewYear, viewMonth, day);
        if (!start || (start && end)) { start = d; end = null; }
        else if (d <= start) { start = d; }
        else { end = d; close(); }
        paint(); updateLabel(); setNative();
      });
    }
    function paint() {
      picker.querySelectorAll('button.datepicker__day').forEach(el => {
        const day = Number(el.textContent);
        const d = new Date(viewYear, viewMonth, day);
        el.classList.remove('datepicker__day--selected', 'datepicker__day--in-range', 'datepicker__day--range-start', 'datepicker__day--range-end');
        if (sameDay(d, start)) el.classList.add('datepicker__day--selected', 'datepicker__day--range-start');
        else if (sameDay(d, end)) el.classList.add('datepicker__day--selected', 'datepicker__day--range-end');
        else if (start && end && d > start && d < end) el.classList.add('datepicker__day--in-range');
      });
    }
    viewYear = today.getFullYear(); viewMonth = today.getMonth();
    updateLabel();
    render();
    close();
  });

  /* Misafir seçici artık `public-guests.js` içinde: bileşen sunucuda iki
     yerde basılıyor (detay sayfasının rezervasyon paneli + ana sayfanın hero
     arama formu) ve davranış sözleşmesi İKİ kopyaya ayrılamaz. Bu dosya
     yalnız galeri/tarih aralığı/lightbox davranışlarını taşır. */
})();
