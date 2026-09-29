(() => {
  const breadcrumb = document.querySelector('.product-detail .detail-breadcrumb');
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
    separator.textContent = '/';
    const current = document.createElement('span');
    current.textContent = detailTitle.textContent;
    current.setAttribute('aria-current', 'page');
    breadcrumb.append(separator, current);
  }
  const detailMain = document.querySelector('.product-detail .detail-main');
  const listingId = document.querySelector('#public-availability')?.dataset.listingId;
  if (detailMain && listingId) {
    fetch('/api/public/listings', { credentials: 'same-origin' })
      .then(response => response.ok ? response.json() : [])
      .then(items => {
        const listing = Array.isArray(items) && items.find(item => item.id === listingId);
        if (listing) renderListingInformation(detailMain, listing, items);
      }).catch(() => {});
  }
  function renderListingInformation(main, listing, allListings) {
    const intro = main.querySelector('.detail-intro');
    const about = intro?.nextElementSibling;
    const availability = main.querySelector('#public-availability')?.closest('.listingSection__wrap');
    const related = [...main.children].find(node => node.querySelector('a[href*="/urunler?kategori"]'));
    if (!intro || !about || !availability) return;
    const category = listing.category;
    let detailData = {};
    try {
      const encoded = document.querySelector('.product-detail')?.dataset.listingDetail;
      if (encoded) detailData = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(encoded), char => char.charCodeAt(0))));
    } catch (_) {}
    const metadata = detailData.metadata && typeof detailData.metadata === 'object' ? detailData.metadata : {};
    if (category === 'hotel') {
      const quality = [];
      const stars = parseInt(metadata.hotel_stars, 10);
      if (stars > 0 && stars <= 5) quality.push('☆'.repeat(stars) + ' ' + stars + ' yıldız');
      const board = { uai: 'Ultra Her Şey Dahil', ai: 'Her Şey Dahil', bb: 'Oda Kahvaltı', hb: 'Yarım Pansiyon', fb: 'Tam Pansiyon' }[metadata.board_type];
      if (board) quality.push(board);
      if (quality.length) {
        const line = document.createElement('p');
        line.className = 'reference-hotel-quality';
        line.textContent = quality.join(' · ');
        intro.querySelector('h1')?.after(line);
      }
      about.querySelector('h2')?.replaceChildren(document.createTextNode('Otel tanıtımı'));
    }
    const details = [
      [listing.guestCount, 'misafir'],
      [listing.bedroomCount, 'yatak odası'],
      [listing.bathroomCount, 'banyo']
    ].filter(([value]) => value && Number(value) > 0);
    if (details.length) {
      const facts = document.createElement('div');
      facts.className = 'reference-detail-facts';
      details.forEach(([value, label]) => {
        const fact = document.createElement('span');
        fact.textContent = value + ' ' + label;
        facts.appendChild(fact);
      });
      intro.appendChild(facts);
    }
    const rating = intro.querySelector('.detail-rating');
    if (rating) {
      if (listing.ratingAverage && Number(listing.reviewCount) > 0) rating.textContent = '★ ' + listing.ratingAverage + ' (' + listing.reviewCount + ')';
      else rating.remove();
    }
    if (related) related.remove();
    const money = new Intl.NumberFormat('tr-TR', { style: 'currency', currency: listing.currency || 'TRY', maximumFractionDigits: 0 }).format(Number(listing.priceMinor || 0) / 100);
    const rates = section('Oda ve fiyat bilgileri', 'Güncel başlangıç fiyatı; tarih ve müsaitliğe göre değişebilir.');
    const rateRow = document.createElement('div');
    rateRow.className = 'reference-detail-rate';
    const rateLabel = document.createElement('span');
    rateLabel.textContent = category === 'hotel' ? 'Gecelik başlangıç fiyatı' : 'Başlangıç fiyatı';
    const rateValue = document.createElement('strong');
    rateValue.textContent = money;
    rateRow.append(rateLabel, rateValue);
    rates.appendChild(rateRow);
    about.after(rates);
    const amenities = section('Olanaklar', 'İlanda belirtilen özellikler ve hizmetler');
    const amenityNames = { pool: 'Havuz', sea_view: 'Deniz manzarası', jacuzzi: 'Jakuzi', sheltered: 'Korunaklı alan', ac: 'Klima', wifi: 'Wi-Fi', bbq: 'Barbekü', parking: 'Otopark', beach: 'Plaj', spa: 'Spa', restaurant: 'Restoran' };
    const amenityValues = Array.isArray(listing.amenities) ? listing.amenities.filter(value => typeof value === 'string' && value) : [];
    if (amenityValues.length) {
      const list = document.createElement('div');
      list.className = 'reference-detail-amenities';
      amenityValues.forEach(value => {
        const item = document.createElement('span');
        item.textContent = amenityNames[value] || value.replace(/_/g, ' ');
        list.appendChild(item);
      });
      amenities.appendChild(list);
    } else amenities.appendChild(paragraph('Bu ilan için olanak bilgisi henüz eklenmemiş.'));
    rates.after(amenities);
    if (category === 'hotel') {
      const stars = parseInt(metadata.hotel_stars, 10);
      const rooms = Array.isArray(metadata.room_types) ? metadata.room_types.filter(room => room && room.title) : [];
      if (rooms.length) {
        const roomSection = section('Oda Seçenekleri', 'Oda tiplerini inceleyin ve tarih seçerek güncel fiyatı öğrenin.');
        roomSection.classList.add('reference-room-section');
        rooms.forEach(room => {
          const card = document.createElement('article');
          card.className = 'reference-room-card';
          const photo = Array.isArray(room.images) && room.images[0];
          if (photo) {
            const image = document.createElement('img');
            image.src = photo;
            image.alt = room.title;
            image.loading = 'lazy';
            card.appendChild(image);
          }
          const content = document.createElement('div');
          const name = document.createElement('h3');
          name.textContent = room.title;
          content.appendChild(name);
          const specs = document.createElement('p');
          specs.textContent = [room.adults && room.adults + ' yetişkin', room.children && room.children + ' çocuk', room.bed, room.size_m2 && room.size_m2 + ' m²', room.view_type].filter(Boolean).join(' · ');
          content.appendChild(specs);
          const note = document.createElement('small');
          note.textContent = 'Odaya özel fiyat için tarih seçin.';
          content.appendChild(note);
          const button = document.createElement('button');
          button.type = 'button';
          button.textContent = 'Tarih Seç';
          button.addEventListener('click', () => {
            document.querySelector('.detail-sidebar .chisfis-date-trigger')?.click();
            document.querySelector('.detail-sidebar')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
          });
          content.appendChild(button);
          card.appendChild(content);
          roomSection.appendChild(card);
        });
        amenities.after(roomSection);
      }
      const ruleItems = [
        metadata.check_in_time && ['Giriş', metadata.check_in_time],
        metadata.check_out_time && ['Çıkış', metadata.check_out_time],
        stars && ['Sınıf', stars + ' yıldız'],
        detailData.policy?.policy && ['İptal ve iade', detailData.policy.policy]
      ].filter(Boolean);
      if (ruleItems.length) {
        const rules = section('Kurallar', 'Konaklama koşulları ve tesis bilgileri');
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
        (main.querySelector('.reference-room-section') || amenities).after(rules);
      }
    }
    const availabilityTitle = availability.querySelector('h2');
    if (availabilityTitle) availabilityTitle.textContent = 'Müsaitlik';
    availability.appendChild(paragraph('Tarih seçerek güncel müsaitlik ve fiyat teklifini öğrenebilirsiniz.'));
    const reviews = section('Yorumlar' + (Number(listing.reviewCount) > 0 ? ' (' + listing.reviewCount + ')' : ''));
    reviews.appendChild(paragraph(Number(listing.reviewCount) > 0 ? 'Bu ilan için ' + listing.reviewCount + ' onaylı değerlendirme bulunuyor.' : 'Bu ilan için henüz yayımlanmış yorum yok.'));
    availability.after(reviews);
    const location = section('Konum', listing.locality || 'Konum bilgisi');
    const lat = Number(listing.latitude), lon = Number(listing.longitude);
    if (Number.isFinite(lat) && Number.isFinite(lon) && lat && lon) {
      const map = document.createElement('iframe');
      map.className = 'reference-detail-map';
      map.title = 'İlan konumu';
      map.loading = 'lazy';
      map.referrerPolicy = 'no-referrer';
      map.src = 'https://www.openstreetmap.org/export/embed.html?bbox=' + [lon - .015, lat - .015, lon + .015, lat + .015].join('%2C') + '&layer=mapnik&marker=' + lat + '%2C' + lon;
      location.appendChild(map);
    } else location.appendChild(paragraph('Harita konumu henüz paylaşılmamış.'));
    reviews.after(location);
    const columns = main.closest('.detail-columns');
    if (columns) {
      columns.after(location);
      const similar = allListings.filter(item => item.id !== listing.id && item.category === listing.category).slice(0, 4);
      if (similar.length) {
        const relatedSection = section('Benzer ilanlar');
        relatedSection.classList.add('reference-similar');
        const grid = document.createElement('div');
        grid.className = 'reference-similar-grid';
        similar.forEach(item => {
          const link = document.createElement('a');
          link.href = window.NEXUS_LISTING_URL ? window.NEXUS_LISTING_URL(item) : '/urunler/' + encodeURIComponent(item.id);
          const image = document.createElement('img');
          image.src = Array.isArray(item.images) && item.images[0] || '/static/chisfis/images/pexels-photo-6129967.home.webp';
          image.alt = item.title || '';
          image.loading = 'lazy';
          const type = document.createElement('small');
          type.textContent = item.categoryLabel || '';
          const title = document.createElement('strong');
          title.textContent = item.title || 'İlan';
          const place = document.createElement('span');
          place.textContent = item.locality || '';
          link.append(image, type, title, place);
          grid.appendChild(link);
        });
        relatedSection.appendChild(grid);
        location.after(relatedSection);
      }
      if (detailData.ownerName) {
        const owner = section('İlan sahibi');
        owner.classList.add('reference-owner');
        const name = document.createElement('strong');
        name.textContent = detailData.ownerName;
        owner.appendChild(name);
        (document.querySelector('.reference-similar') || location).after(owner);
        owner.after(reviews);
      } else (document.querySelector('.reference-similar') || location).after(reviews);
    }
  }
  function section(title, subtitle) {
    const node = document.createElement('section');
    node.className = 'listingSection__wrap reference-detail-section';
    const heading = document.createElement('h2');
    heading.textContent = title;
    node.appendChild(heading);
    if (subtitle) node.appendChild(paragraph(subtitle));
    return node;
  }
  function paragraph(text) {
    const p = document.createElement('p');
    p.textContent = text;
    return p;
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
    images = images.filter(value => typeof value === 'string' && /^https?:\/\//i.test(value));
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
      img.loading = 'lazy';
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
    // Keep the reference's five-cell mosaic when a listing has only 3–4 photos.
    // Reuse a real listing photo rather than substituting unrelated imagery.
    if (images.length >= 3) while (shown.length < 5) shown.push(images[shown.length % images.length]);
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
      // Büyük görüntüyü ayarla
      zoomResult.style.backgroundImage = 'url(' + img.src + ')';
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
