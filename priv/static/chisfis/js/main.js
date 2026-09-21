/* Chisfis static — vanilla JS interactivity */
(function () {
  'use strict';

  /* ============ shared storefront header ============ */
  // Home wraps the header with the rest of the exported page, while dynamic
  // routes render a semantic <header>. Normalize both without cloning markup,
  // so every route keeps the same controls and behavior.
  function normalizeStorefrontHeader() {
    var semantic = document.querySelector('header.chisfis-header-root');
    var homeRoot = document.body && document.body.firstElementChild;
    var root = semantic || (homeRoot && homeRoot.firstElementChild && homeRoot.firstElementChild.classList.contains('relative') ? homeRoot : null);
    if (!root) return;
    root.classList.add('chisfis-header-root');
    var catalog = root.querySelector('#popover-button-1');
    if (catalog) { catalog.setAttribute('data-i18n', 'Katalog'); catalog.childNodes[0].nodeValue = 'Katalog '; }
    var categories = root.querySelector('#popover-button-2');
    if (categories) { categories.setAttribute('data-i18n', 'Kategoriler'); categories.childNodes[0].nodeValue = 'Kategoriler '; }
    var locale = root.querySelector('#popover-button-3');
    if (locale && !locale.dataset.sharedIconsReady) {
      // The exported demo uses inline SVGs here. Keep the shared header
      // independent of the optional Hugeicons font on every public route.
      locale.dataset.sharedIconsReady = 'true';
      locale.setAttribute('aria-label', 'Dil ve para birimi');
      locale.innerHTML =
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true" class="size-5"><path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 0 0 8.716-6.747M12 21a9.004 9.004 0 0 1-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 0 1 7.843 4.582M12 3a8.997 8.997 0 0 0-7.843 4.582m15.686 0A11.953 11.953 0 0 1 12 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0 1 21 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0 1 12 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 0 1 3 12c0-1.605.42-3.113 1.157-4.418"/></svg>' +
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true" class="size-5 opacity-60"><path stroke-linecap="round" stroke-linejoin="round" d="m9 20.247 6-16.5"/></svg>' +
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true" class="size-5"><path stroke-linecap="round" stroke-linejoin="round" d="M2.25 18.75a60.07 60.07 0 0 1 15.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 0 1 3 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 0 0-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 0 1-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 0 0 3 15h-.75M15 10.5a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm3 0h.008v.008H18V10.5Zm-12 0h.008v.008H6V10.5Z"/></svg>' +
        '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" class="ms-1 size-4 group-data-open:rotate-180"><path fill-rule="evenodd" d="M12.53 16.28a.75.75 0 0 1-1.06 0l-7.5-7.5a.75.75 0 0 1 1.06-1.06L12 14.69l6.97-6.97a.75.75 0 1 1 1.06 1.06l-7.5 7.5Z" clip-rule="evenodd"/></svg>';
    }
    var notification = root.querySelector('#popover-button-4');
    if (notification && !notification.dataset.sharedIconReady) {
      notification.dataset.sharedIconReady = 'true';
      var notificationIcon = notification.querySelector('i.hgi-notification-01');
      if (notificationIcon) notificationIcon.outerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9Z"/><path d="M10 21h4"/></svg>';
    }
    root.querySelectorAll('a[data-i18n="Tesisinizi listeleyin"], a[data-i18n="List your property"], .storefront-property-link').forEach(function (link) {
      link.remove();
    });
    var actions = root.querySelector('.flex.flex-1.items-center.justify-end');
    var desktopRow = root.querySelector('.flex.h-20');
    var themeWrap = root.querySelector('#theme-picker-wrap');
    if (actions && themeWrap) {
      var accountButton = themeWrap.querySelector('#popover-button-5');
      var accountWrap = accountButton;
      while (accountWrap && accountWrap.parentElement !== themeWrap) accountWrap = accountWrap.parentElement;
      if (accountWrap) actions.appendChild(accountWrap);
      themeWrap.remove();
    }
    if (desktopRow && actions && !root.querySelector('#nexus-header-search')) {
      var search = document.createElement('div');
      search.id = 'nexus-header-search';
      search.innerHTML = '<form action="/urunler" method="get" role="search"><input name="q" type="search" aria-label="Ara" placeholder="Şehir, bölge veya ilan ara"><button type="submit" aria-label="Ara"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m20 20-4.2-4.2m1.2-5.3a6.5 6.5 0 1 1-13 0 6.5 6.5 0 0 1 13 0Z" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg></button></form><button type="button" id="nexus-header-mic" aria-label="Sesli arama" aria-pressed="false" title="Sesli arama"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Z" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/><path d="M5.5 11.5a6.5 6.5 0 0 0 13 0M12 18v3m-3 0h6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg></button>';
      desktopRow.insertBefore(search, actions);
    }
    var headerMic = root.querySelector('#nexus-header-mic');
    if (headerMic && !headerMic.dataset.voiceReady) {
      headerMic.dataset.voiceReady = 'true';
      headerMic.addEventListener('click', function () {
        var SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        if (!SpeechRecognition) {
          headerMic.title = 'Sesli arama bu tarayıcıda desteklenmiyor';
          return;
        }
        var recognition = new SpeechRecognition();
        recognition.lang = document.documentElement.lang === 'en' ? 'en-US' : 'tr-TR';
        recognition.interimResults = false;
        recognition.maxAlternatives = 1;
        recognition.onstart = function () {
          headerMic.classList.add('is-listening');
          headerMic.setAttribute('aria-pressed', 'true');
          headerMic.title = 'Dinleniyor...';
        };
        recognition.onend = function () {
          headerMic.classList.remove('is-listening');
          headerMic.setAttribute('aria-pressed', 'false');
          headerMic.title = 'Sesli arama';
        };
        recognition.onerror = function () {
          headerMic.classList.remove('is-listening');
          headerMic.setAttribute('aria-pressed', 'false');
          headerMic.title = 'Sesli arama';
        };
        recognition.onresult = function (event) {
          var value = event.results && event.results[0] && event.results[0][0] ? event.results[0][0].transcript.trim() : '';
          var input = root.querySelector('#nexus-header-search input');
          if (input && value) { input.value = value; input.focus(); }
        };
        recognition.start();
      });
    }
    if (actions && !root.querySelector('#cart-fab-wrap')) {
      var cart = document.createElement('div');
      cart.id = 'cart-fab-wrap';
      cart.className = 'nexus-header-action';
      cart.innerHTML = '<button id="cart-fab-btn" type="button" aria-label="Sepet"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M3 3h1.1c.7 0 1.3.5 1.4 1.2L6.8 14c.1.8.8 1.4 1.6 1.4h8.8c.8 0 1.5-.6 1.6-1.4L20 7H6" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/><circle cx="9" cy="20" r="1.25" fill="currentColor"/><circle cx="17" cy="20" r="1.25" fill="currentColor"/></svg><span id="cart-badge" class="hidden">0</span></button>';
      var account = root.querySelector('#popover-button-5');
      var accountSlot = account;
      while (accountSlot && accountSlot.parentElement !== actions) accountSlot = accountSlot.parentElement;
      actions.insertBefore(cart, accountSlot || null);
    }
  }
  normalizeStorefrontHeader();
  setTimeout(normalizeStorefrontHeader, 250);
  setTimeout(normalizeStorefrontHeader, 900);

  /* ============ 0a. iletişim ayarları ============ */
  // WhatsApp numarası (uluslararası format, + olmadan) — buradan değiştirin
  var WHATSAPP_NUMBER = '905323977957';
  var WHATSAPP_MESSAGE = 'Merhaba, bilgi almak istiyorum.'; // sohbeti açan ön mesaj

  /* ============ 0. tema (localStorage kalıcı; dark/light/sahra/auto) ============ */
  var THEME_KEY = 'chisfis-theme';
  // Sahra: panel Aurora paletindeki sıcak amber varyantının mağaza karşılığı.
  // html.sahra sınıfı chisfis/css/sahra.css'teki değişken ezilmesini açar.
  // Auto: yerel saate göre palet — 06–17 aydınlık, 17–21 sahra, gece karanlık.
  var AUTO_SLOTS = [
    [6, 17, 'light'],
    [17, 21, 'sahra'],
    [21, 24, 'dark'],
    [0, 6, 'dark'],
  ];
  function autoStoreTheme(hour) {
    for (var i = 0; i < AUTO_SLOTS.length; i++) {
      if (hour >= AUTO_SLOTS[i][0] && hour < AUTO_SLOTS[i][1]) return AUTO_SLOTS[i][2];
    }
    return 'dark';
  }
  // Çözümlenmiş MEVCUT modu string olarak döndürür.
  //
  // Neden gerekli: `applyTheme` bir MOD string bekler (`dark` | `light` |
  // `sahra`), boolean değil. Bir boolean geçilirse `dark = mode !== 'light'`
  // daima `true` olur ve sayfa zorla karanlığa döner — bu yüzden aydınlık
  // palet hiç ulaşılamaz hale geliyordu. Aşağıdaki iki senkron çağrısı
  // (swatch işareti ve mm-foot etiketi) yalnızca etiketi tazeler; modu
  // sınıflardan okuyup string olarak geçmek zorundadırlar.
  function currentMode() {
    if (document.documentElement.classList.contains('sahra')) return 'sahra';
    return document.documentElement.classList.contains('dark') ? 'dark' : 'light';
  }
  function applyTheme(mode) {
    var sahra = mode === 'sahra';
    var dark = mode !== 'light';
    document.documentElement.classList.toggle('dark', dark);
    document.documentElement.classList.toggle('sahra', sahra);
    document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
    // Header toggle: moon/sun Hugeicons görünürlüğü (koyu/aydınlık işareti)
    document.querySelectorAll('#theme-toggle').forEach(function (b) {
      b.setAttribute('aria-pressed', dark ? 'true' : 'false');
      b.title = dark ? 'Switch to light mode' : 'Switch to dark mode';
      var moon = b.querySelector('.theme-icon-dark, .hgi-moon-02');
      var sun = b.querySelector('.theme-icon-light, .hgi-sun-01');
      if (moon) moon.style.display = dark ? '' : 'none';
      if (sun) sun.style.display = dark ? 'none' : '';
    });
    // mm-foot etiketi: yalnızca dark/light ikili etiketi (sahra geçici çözüm)
    document.querySelectorAll('.mm-foot-btn[data-role="theme"]').forEach(function (b) {
      var lbl = b.querySelector('span:not(.mm-foot-ico)');
      if (lbl) lbl.textContent = dark ? 'Dark mode' : 'Light mode';
      var ico = b.querySelector('.mm-foot-ico');
      if (ico) ico.textContent = dark ? '🌙' : '☀️';
    });
    document.querySelectorAll('.store-theme-swatch').forEach(function (s) {
      var on = s.getAttribute('data-store-theme') === mode;
      s.classList.toggle('active', on);
      s.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
  }
  function resolveApply(mode) {
    // auto: çözümlenmiş paleti uygula ama anahtar olarak 'auto' sakla;
    // dakikalık denetim saat dilimi kayınca kendiliğinden geçsin.
    if (mode === 'auto') {
      applyTheme(autoStoreTheme(new Date().getHours()));
      document.querySelectorAll('.store-theme-swatch').forEach(function (s) {
        var on = s.getAttribute('data-store-theme') === 'auto';
        s.classList.toggle('active', on);
        s.setAttribute('aria-pressed', on ? 'true' : 'false');
      });
      var tBtn = document.getElementById('theme-toggle');
      if (tBtn) tBtn.title = 'Auto theme — saate göre';
    } else {
      applyTheme(mode);
    }
  }
  // başlangıç: localStorage > sistem tercihi
  var saved = null;
  try { saved = localStorage.getItem(THEME_KEY); } catch (e) {}
  var prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  resolveApply(saved === 'sahra' || saved === 'light' || saved === 'dark' || saved === 'auto' ? saved : 'auto');
  setInterval(function () {
    try { if (localStorage.getItem(THEME_KEY) === 'auto') resolveApply('auto'); } catch (e) {}
  }, 60000);

  document.addEventListener('click', function (e) {
    var swatch = e.target.closest('.store-theme-swatch');
    if (swatch) {
      var mode = swatch.getAttribute('data-store-theme');
      if (mode === 'dark' || mode === 'light' || mode === 'sahra' || mode === 'auto') {
        resolveApply(mode);
        try { localStorage.setItem(THEME_KEY, mode); } catch (err) {}
      }
      return;
    }
    var btn = e.target.closest('#theme-toggle');
    if (!btn) return;
    // İkili toggle: dark ↔ light. Tercih yoksa auto çözümlemeden devam et.
    var next = document.documentElement.classList.contains('dark') ? 'light' : 'dark';
    resolveApply(next);
    try { localStorage.setItem(THEME_KEY, next); } catch (err) {}
    // mm-foot etiketini de senkronla
    document.querySelectorAll('.mm-foot-btn[data-role="theme"]').forEach(function (b) {
      var lbl = b.querySelector('span:not(.mm-foot-ico)');
      if (lbl) lbl.textContent = next === 'dark' ? 'Dark mode' : 'Light mode';
      var ico = b.querySelector('.mm-foot-ico');
      if (ico) ico.textContent = next === 'dark' ? '🌙' : '☀️';
    });
  });

  /* ============ 0b. i18n — TR/EN dil değiştirici ============ */
  var $ = function (sel, ctx) { return (ctx || document).querySelector(sel); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); };

  /* ============ 0d. Kendi durumunu yöneten kontroller — TEK KAYNAK =====
   *
   * `aria-expanded` bir noktada "bu düğme bir açılır paneli yönetiyor"
   * işareti olarak kullanıldı ve dış-tıklama geçişleri belgedeki TÜM
   * `[aria-expanded="true"]` düğmeleri sıfırladı (bu dosyada §12, ayrıca
   * `header-popovers.js`). Ama bazı kontroller durumlarını yerel bir
   * denetleyiciyle tutar ve o süpürmeden haberdar değildir:
   *   • ilan listesi filtre paneli (`public-listings.js`) açık/kapalıyı
   *     gövdenin `is-open` sınıfıyla ve yükseklik animasyonuyla yönetir.
   * Sonuç: panel AÇIK kalırken etiketi dış tıklamada SIFIRLANIYORDU —
   * ekran okuyucu "kapalı" duyuruyor, `[aria-expanded="true"]` ile dönen
   * ok simgesi ise hiç dönmüyordu.
   *
   * Bu yüzden genel süpürmeler sahiplik kontrolünden geçer; burada TEK
   * yerde tanımlanıp `window.NEXUS_STATE_OWNED` olarak paylaşılır
   * (`main.js` defer sırasında `header-popovers.js`'ten ÖNCE çalışır).
   */
  window.NEXUS_STATE_OWNED = function (btn) {
    if (!btn || !btn.closest) return false;
    return !!btn.closest('[data-filter-panel]');
  };

  /* ============ 0c. Aktif kategori/menü tespiti — TEK KAYNAK ============
   *
   * Aynı soru iki yerde soruluyordu ve iki AYRI kopya olarak yanıtlanıyordu:
   * masaüstü header menüsü (`header-popovers.js`, Keşfet/Şablonlar açılır
   * listesi) ve mobil çekmece (aşağıda §10). Kopyalar ayrıştı:
   *   • çekmece hem `/kategori/<slug>` yolunu hem `/urunler?kategori=<slug>`
   *     filtresini biliyordu,
   *   • masaüstü YALNIZ sorgu filtresini biliyordu.
   * Sonuç: `/kategori/hotel` sayfasında mobil menü vurguluyor, masaüstü
   * header menüsü vurgulamıyordu — kullanıcı aynı sayfada iki farklı menü
   * davranışı görüyordu.
   *
   * Bu predicate tek yerde tanımlanır ve `window.NEXUS_NAV` üzerinden
   * paylaşılır (`main.js` defer sırasında `header-popovers.js`'ten ÖNCE
   * yürür; sıra statik testle sabitlenir).
   */
  window.NEXUS_NAV = (function () {
    // Sondaki eğik çizgi atılır: `/urunler/` ile `/urunler` aynı sayfadır.
    var path = window.location.pathname.replace(/\/$/, '');
    var LISTING_PATHS = ['/urunler', '/products'];
    // Liste sayfasının kategori filtresi: `?kategori=<slug>`
    var queryCategory = (function () {
      var m = /[?&]kategori=([^&]*)/.exec(window.location.search);
      return m ? decodeURIComponent(m[1].replace(/\+/g, ' ')) : null;
    })();
    // Kategori sayfasının yolu: `/kategori/<slug>`
    var pathCategory = (function () {
      var m = /^\/kategori\/(.+)$/.exec(path);
      return m ? m[1] : null;
    })();
    // Kategori OLMAYAN rotaların liste filtresindeki slug karşılığı:
    // `/arac` sayfası ile `/urunler?kategori=car` aynı vitrini gösterir.
    var DIRECT_SLUGS = { '/arac': 'car', '/ucus': 'flight', '/otobus': 'bus' };

    function categorySlug(href) {
      var m = /^\/kategori\/(.+)$/.exec(String(href || ''));
      return m ? m[1] : null;
    }
    function isListing() {
      return LISTING_PATHS.indexOf(path) !== -1;
    }
    /** Bulunulan sayfa bu kategori slug'ına mı ait? (yol VEYA filtre) */
    function isActiveCategory(slug) {
      if (!slug) return false;
      if (pathCategory === slug) return true;
      return isListing() && queryCategory === slug;
    }
    /** Verilen bağlantı bulunulan sayfayı mı gösteriyor? */
    function isActiveHref(href) {
      if (!href) return false;
      if (path === href) return true;
      var slug = categorySlug(href);
      if (slug) return isActiveCategory(slug);
      return isListing() && !!queryCategory && DIRECT_SLUGS[href] === queryCategory;
    }
    return {
      path: path,
      queryCategory: queryCategory,
      pathCategory: pathCategory,
      isListing: isListing,
      categorySlug: categorySlug,
      isActiveCategory: isActiveCategory,
      isActiveHref: isActiveHref,
    };
  })();

  var LANG_KEY = 'chisfis-lang';
  var TR = {
    // hero
    'Hotel, car, experiences': 'Otel, araba, deneyimler',
    'With us, your trip is filled with amazing experiences.': 'Bizimle yolculuğunuz harika deneyimlerle dolu.',
    'Start your search': 'Aramaya başla',
    'Where to?': 'Nereye?',
    'Any week': 'Herhangi bir hafta',
    'Add guests': 'Misafir ekle',
    'Location': 'Konum',
    'Where are you going?': 'Nereye gidiyorsunuz?',
    'Check in': 'Giriş',
    'Check out': 'Çıkış',
    'Add date': 'Tarih ekle',
    'Guests': 'Misafirler',
    // Sayaç özeti: `%s` yer tutucusu sayıyı taşır (t() tek parametre alır,
    // sayı çağrı yerinde yerleştirilir).
    '%s Guests': '%s misafir',
    // nav
    'Stays': 'Konaklama',
    'Cars': 'Arabalar',
    'Experiences': 'Deneyimler',
    'Flights': 'Uçuşlar',
    'RealEstates': 'Emlak',
    'Templates': 'Şablonlar',
    'Travelers': 'Yolcular',
    'List your property': 'Mülkünüzü listele',
    // masaüstü header popover içerikleri (header-popovers.js)
    'Adults': 'Yetişkin',
    'Ages 13+': '13+ yaş',
    'Children': 'Çocuk',
    'Infants': 'Bebek',
    'Notifications': 'Bildirimler',
    'You have no new notifications.': 'Yeni bildiriminiz yok.',
    'Sign in': 'Giriş yap',
    'Create account': 'Hesap oluştur',
    'Decrease %s': '%s azalt',
    'Increase %s': '%s artır',
    // sections
    'Explore the best places to stay in the world.': 'Dünyanın en iyi konaklama yerlerini keşfedin.',
    'Let\'s go on an adventure': 'Bir maceraya çıkalım',
    'Benefits': 'Avantajlar',
    'Why host with us?': 'Neden bizimle ev sahipliği yapmalısınız?',
    'Advertising': 'Reklam',
    'Cost-effective advertising': 'Maliyet etkin reklam',
    'A free listing, you can advertise your rental with no upfront costs': 'Ücretsiz ilanla kiranızı ön maliyet olmadan tanıtabilirsiniz',
    'Exposure': 'Görünürlük',
    'Reach millions with Chisfis': 'Chisfis ile milyonlara ulaşın',
    'Millions of people are searching for unique places to stay around the world': 'Milyonlarca kişi dünyanın dört bir benzersiz konaklama yeri arıyor',
    'Secure': 'Güvenli',
    'Secure and simple': 'Güvenli ve basit',
    'A Chisfis listing gives you a secure and easy way to take bookings and payments online': 'Chisfis ilanı, çevrimiçi rezervasyon ve ödeme almanın güvenli ve kolay bir yolunu sunar',
    'Featured places to stay': 'Öne çıkan konaklama yerleri',
    'Selected based on user reviews. Updated weekly': 'Kullanıcı yorumlarına göre seçildi. Haftalık güncellenir',
    'View all': 'Tümünü gör',
    'Show me more': 'Daha fazla göster',
    'Become a host': 'Ev sahibi olun',
    'How it work': 'Nasıl çalışır',
    'Keep calm & travel on': 'Sakin olun ve seyahat edin',
    'Book & relax': 'Rezervasyon yapın ve rahatlayın',
    'Let each trip be an inspirational journey, each room a peaceful space': 'Her yolculuk ilham verici bir macera, her oda huzurlu bir alan olsun',
    'Smart checklist': 'Akıllı kontrol listesi',
    'Save more': 'Daha fazla tasarruf edin',
    'Top 10 authors of the month': 'Ayın en iyi 10 yazarı',
    'Meet the hosts behind the best-rated stays.': 'En yüksek puanlı konaklamaların arkasındaki ev sahipleriyle tanışın.',
    'Join our newsletter': 'Bültenimize katılın',
    'Get exclusive deals and inspiration delivered straight to your inbox.': 'Özel fırsatlar ve ilham doğrudan gelen kutunuza gelsin.',
    'Get more discount': 'Daha fazla indirim alın',
    'Get premium deals': 'Premium fırsatları yakalayın',
    'Endless inspiration': 'Sonsuz ilham',
    'Explore nearby': 'Yakın çevreyi keşfedin',
    'Great places near where you live': 'Yaşadığınız yere yakın harika yerler',
    'Explore by types of stays': 'Konaklama türlerine göre keşfedin',
    'Explore houses based on 10 types of stays': '10 konaklama türüne göre evleri keşfedin',
    'Enjoy the great cold': 'Büyük soğun tadını çıkarın',
    'Sleep in a floating way': 'Yüzen bir şekilde uyuyun',
    "In the billionaire's house": 'Milyarderin evinde',
    'Cool in the deep forest': 'Derin ormanda serin',
    'Sunset in the desert': 'Çölde gün batımı',
    'Become a host with us.': 'Bizimle ev sahibi olun.',
    'With Chisfis, booking resorts, villas, hotels, private homes, and apartments becomes quick, convenient, and easy.': 'Chisfis ile tatil köyü, villa, otel, özel ev ve daire rezervasyonları hızlı, kullanışlı ve kolay.',
    // stay-categories
    'Explore stays': 'Konaklamaları keşfedin',
    'Worldwide': 'Dünya geneli',
    'stays': 'konaklama',
    'Over': 'Toplam',
    'places': 'yer',
    // flight-categories
    'Book Flights': 'Uçuş Rezervasyonu',
    'Explore the world with us.': 'Dünyayı bizimle keşfedin.',
    // car
    'Find rides.': 'Araç bulun.',
    'Find your perfect cars': 'Mükemmel aracınızı bulun',
    // experiences
    'Discover Adventures': 'Maceraları Keşfedin',
    'Experience listings': 'Deneyim ilanları',
    // listing
    'Stay information': 'Konaklama bilgisi',
    'Room Rates': 'Oda fiyatlarını',
    'Amenities': 'Olanaklar',
    'Availability': 'Müsaitlik',
    'Reviews': 'Yorumlar',
    'reviews': 'yorum',
    // footer
    'Making the world a better place through constructing elegant hierarchies.': 'Şık hiyerarşiler oluşturarak dünyayı daha iyi bir yer haline getiriyoruz.',
    'Solutions': 'Çözümler',
    'Marketing': 'Pazarlama',
    'Analytics': 'Analitik',
    'Automation': 'Otomasyon',
    'Commerce': 'Ticaret',
    'Support': 'Destek',
    'Submit ticket': 'Talep gönder',
    'Documentation': 'Dokümantasyon',
    'Guides': 'Rehberler',
    'Company': 'Şirket',
    'About': 'Hakkımızda',
    'Blog': 'Blog',
    'Jobs': 'Kariyer',
    'Press': 'Basın',
    'Legal': 'Yasal',
    'Terms of service': 'Hizmet şartları',
    'Privacy policy': 'Gizlilik politikası',
    'License': 'Lisans',
    'Insights': 'İçgörüler',
    'All rights reserved.': 'Tüm hakları saklıdır.',
    // mobile menu / bottom bar
    'Explore': 'Keşfet',
    'Wishlists': 'Favoriler',
    'Account': 'Hesap',
    'Menu': 'Menü',
    'Home': 'Anasayfa',
    'Search': 'Ara',
    'Voice search': 'Sesli arama',
    'Listening...': 'Dinleniyor...',
    'Voice search is not supported in this browser': 'Bu tarayıcı sesli aramayı desteklemiyor',
    'Cart': 'Sepet',
    'Dark mode': 'Karanlık mod',
    'Light mode': 'Aydınlık mod',
    'Sahra mode': 'Sahra modu',
    'Toggle dark mode': 'Karanlık modu aç/kapat',
    'CATEGORIES': 'KATEGORİLER',
    'Language': 'Dil',
    'Currency': 'Para birimi',
    'Hotels': 'Oteller',
    'Holiday homes & villas': 'Tatil evleri ve villalar',
    'Yacht rental': 'Yat kiralama',
    'Tours': 'Turlar',
    'Activities': 'Aktiviteler',
    'All experiences': 'Tüm deneyimler',
    'Authors': 'Yazarlar',
    'Search city, hotel or region...': 'Şehir, otel veya bölge ara...',
    // stay map
    'places in': 'yer —',
    'Interactive map is unavailable offline': 'Etkileşimli harita çevrimdışı kullanılamaz',
    'Open in Google Maps': 'Google Maps\'ta aç',
    // authors
    'Top 10 author of the month': 'Ayın en iyi 10 yazarı',
    'What guests are saying about': 'Misafirlerin hakkında söyledikleri',
    'Supperhost': 'Süper ev sahibi',
    'years': 'yıl',
    'Providing': 'Sunuyor',
    'Joined on': 'Katıldı',
    // search form labels
    'Suggested locations': 'Önerilen konumlar',
    'Ages 13 or above': '13 yaş ve üzeri',
    'Ages 2–12': '2–12 yaş',
    'Ages 0–2': '0–2 yaş',
    'Under 2': '2 yaş altı',
    'per night': 'gecelik',
    'beds': 'yatak',
    'Entire cabin': 'Tam dağ evi',
    'Hotel room': 'Oda',
    'Holiday home': 'Tatil evi',
    'Home stay': 'Ev konaklama',
    'Private room': 'Özel oda',
    'Entire place': 'Tam yer',
    'Have a place to yourself': 'Kendinize ait bir yer',
    'Have your own room and share some common spaces': 'Kendi odanız olsun ve bazı ortak alanları paylaşın',
    'Have a private or shared room in a boutique hotel': 'Butik otelde özel veya paylaşımlı oda',
    // dil değişimi bildirimi (geri al) — anahtarlar EN metnidir
    'Language changed': 'Dil değiştirildi',
    'Back': 'Geri',
  };

  // ---- Almanca sözlük — TR ile aynı anahtar kapsamı ----
  var DE = {
    'Hotel, car, experiences': 'Hotel, Auto, Erlebnisse',
    'With us, your trip is filled with amazing experiences.': 'Mit uns wird Ihre Reise zu einem Erlebnis voller Highlights.',
    'Start your search': 'Suche starten',
    'Where to?': 'Wohin?',
    'Any week': 'Beliebige Woche',
    'Add guests': 'Gäste hinzufügen',
    'Location': 'Standort',
    'Where are you going?': 'Wohin reisen Sie?',
    'Check in': 'Anreise',
    'Check out': 'Abreise',
    'Add date': 'Datum hinzufügen',
    'Guests': 'Gäste',
    '%s Guests': '%s Gäste',
    'Stays': 'Unterkünfte',
    'Cars': 'Autos',
    'Experiences': 'Erlebnisse',
    'Flights': 'Flüge',
    'RealEstates': 'Immobilien',
    'Templates': 'Vorlagen',
    'Travelers': 'Reisende',
    'List your property': 'Immobilie einstellen',
    'Adults': 'Erwachsene',
    'Ages 13+': 'Ab 13 Jahren',
    'Children': 'Kinder',
    'Infants': 'Kleinkinder',
    'Notifications': 'Benachrichtigungen',
    'You have no new notifications.': 'Sie haben keine neuen Benachrichtigungen.',
    'Sign in': 'Anmelden',
    'Create account': 'Konto erstellen',
    'Decrease %s': '%s verringern',
    'Increase %s': '%s erhöhen',
    'Explore the best places to stay in the world.': 'Entdecken Sie die besten Unterkünfte der Welt.',
    'Let\'s go on an adventure': 'Auf ins Abenteuer',
    'Benefits': 'Vorteile',
    'Why host with us?': 'Warum bei uns vermieten?',
    'Advertising': 'Werbung',
    'Cost-effective advertising': 'Kosteneffektive Werbung',
    'A free listing, you can advertise your rental with no upfront costs': 'Mit einem kostenlosen Inserat bewerben Sie Ihre Unterkunft ohne Anfangskosten',
    'Exposure': 'Reichweite',
    'Reach millions with Chisfis': 'Millionen erreichen mit Chisfis',
    'Millions of people are searching for unique places to stay around the world': 'Millionen Menschen suchen weltweit nach einzigartigen Unterkünften',
    'Secure': 'Sicher',
    'Secure and simple': 'Sicher und einfach',
    'A Chisfis listing gives you a secure and easy way to take bookings and payments online': 'Ein Chisfis-Inserat bietet einen sicheren und einfachen Weg, Buchungen und Zahlungen online entgegenzunehmen',
    'Featured places to stay': 'Ausgewählte Unterkünfte',
    'Selected based on user reviews. Updated weekly': 'Basierend auf Gästebewertungen. Wöchentlich aktualisiert',
    'View all': 'Alle anzeigen',
    'Show me more': 'Mehr anzeigen',
    'Become a host': 'Gastgeber werden',
    'How it work': 'So funktioniert es',
    'Keep calm & travel on': 'Bleiben Sie ruhig & reisen Sie weiter',
    'Book & relax': 'Buchen & entspannen',
    'Let each trip be an inspirational journey, each room a peaceful space': 'Jede Reise soll eine inspirierende Fahrt sein, jedes Zimmer ein Ort der Ruhe',
    'Smart checklist': 'Smarte Checkliste',
    'Save more': 'Mehr sparen',
    'Top 10 authors of the month': 'Top-10-Gastgeber des Monats',
    'Meet the hosts behind the best-rated stays.': 'Lernen Sie die Gastgeber der bestbewerteten Unterkünfte kennen.',
    'Join our newsletter': 'Newsletter abonnieren',
    'Get exclusive deals and inspiration delivered straight to your inbox.': 'Exklusive Angebote und Inspiration direkt in Ihr Postfach.',
    'Get more discount': 'Mehr Rabatt erhalten',
    'Get premium deals': 'Premium-Angebote sichern',
    'Endless inspiration': 'Endlose Inspiration',
    'Explore nearby': 'Umgebung entdecken',
    'Great places near where you live': 'Tolle Orte in Ihrer Nähe',
    'Explore by types of stays': 'Nach Unterkunftsarten entdecken',
    'Explore houses based on 10 types of stays': 'Häuser nach 10 Unterkunftsarten entdecken',
    'Enjoy the great cold': 'Genießen Sie die große Kälte',
    'Sleep in a floating way': 'Schlafen Sie schwebend',
    "In the billionaire's house": 'Im Haus des Milliardärs',
    'Cool in the deep forest': 'Kühl im tiefen Wald',
    'Sunset in the desert': 'Sonnenuntergang in der Wüste',
    'Become a host with us.': 'Werden Sie Gastgeber bei uns.',
    'With Chisfis, booking resorts, villas, hotels, private homes, and apartments becomes quick, convenient, and easy.': 'Mit Chisfis werden Resorts, Villen, Hotels, Privathäuser und Apartments schnell, bequem und einfach gebucht.',
    'Explore stays': 'Unterkünfte entdecken',
    'Worldwide': 'Weltweit',
    'stays': 'Unterkünfte',
    'Over': 'Über',
    'places': 'Orte',
    'Book Flights': 'Flüge buchen',
    'Explore the world with us.': 'Entdecken Sie die Welt mit uns.',
    'Find rides.': 'Fahrzeuge finden.',
    'Find your perfect cars': 'Finden Sie Ihr perfektes Auto',
    'Discover Adventures': 'Abenteuer entdecken',
    'Experience listings': 'Erlebnis-Angebote',
    'Stay information': 'Unterkunftsinformationen',
    'Room Rates': 'Zimmerpreise',
    'Amenities': 'Ausstattung',
    'Availability': 'Verfügbarkeit',
    'Reviews': 'Bewertungen',
    'reviews': 'Bewertungen',
    'Making the world a better place through constructing elegant hierarchies.': 'Wir machen die Welt zu einem besseren Ort, indem wir elegante Hierarchien schaffen.',
    'Solutions': 'Lösungen',
    'Marketing': 'Marketing',
    'Analytics': 'Analysen',
    'Automation': 'Automatisierung',
    'Commerce': 'Handel',
    'Support': 'Support',
    'Submit ticket': 'Ticket senden',
    'Documentation': 'Dokumentation',
    'Guides': 'Anleitungen',
    'Company': 'Unternehmen',
    'About': 'Über uns',
    'Blog': 'Blog',
    'Jobs': 'Karriere',
    'Press': 'Presse',
    'Legal': 'Rechtliches',
    'Terms of service': 'Nutzungsbedingungen',
    'Privacy policy': 'Datenschutzrichtlinie',
    'License': 'Lizenz',
    'Insights': 'Einblicke',
    'All rights reserved.': 'Alle Rechte vorbehalten.',
    'Explore': 'Entdecken',
    'Wishlists': 'Favoriten',
    'Account': 'Konto',
    'Menu': 'Menü',
    'Home': 'Startseite',
    'Search': 'Suchen',
    'Voice search': 'Sprachsuche',
    'Listening...': 'Wird zugehört...',
    'Voice search is not supported in this browser': 'Dieser Browser unterstützt keine Sprachsuche',
    'Cart': 'Warenkorb',
    'Dark mode': 'Dunkelmodus',
    'Light mode': 'Hellmodus',
    'Sahra mode': 'Sahra-Modus',
    'Toggle dark mode': 'Dunkelmodus umschalten',
    'CATEGORIES': 'KATEGORIEN',
    'Language': 'Sprache',
    'Currency': 'Währung',
    'Hotels': 'Hotels',
    'Holiday homes & villas': 'Ferienhäuser & Villen',
    'Yacht rental': 'Yachtcharter',
    'Tours': 'Touren',
    'Activities': 'Aktivitäten',
    'All experiences': 'Alle Erlebnisse',
    'Authors': 'Autoren',
    'Search city, hotel or region...': 'Stadt, Hotel oder Region suchen...',
    'places in': 'Orte in',
    'Interactive map is unavailable offline': 'Interaktive Karte offline nicht verfügbar',
    'Open in Google Maps': 'In Google Maps öffnen',
    'Top 10 author of the month': 'Top-10-Autor des Monats',
    'What guests are saying about': 'Was Gäste über uns sagen',
    'Supperhost': 'Super-Gastgeber',
    'years': 'Jahre',
    'Providing': 'Bietet',
    'Joined on': 'Beigetreten am',
    'Suggested locations': 'Vorgeschlagene Orte',
    'Ages 13 or above': 'Ab 13 Jahren',
    'Ages 2–12': '2–12 Jahre',
    'Ages 0–2': '0–2 Jahre',
    'Under 2': 'Unter 2',
    'per night': 'pro Nacht',
    'beds': 'Betten',
    'Entire cabin': 'Ganze Hütte',
    'Hotel room': 'Hotelzimmer',
    'Holiday home': 'Ferienhaus',
    'Home stay': 'Privatunterkunft',
    'Private room': 'Privatzimmer',
    'Entire place': 'Gesamte Unterkunft',
    'Have a place to yourself': 'Haben Sie einen Ort für sich',
    'Have your own room and share some common spaces': 'Ihr eigenes Zimmer und geteilte Gemeinschaftsbereiche',
    'Have a private or shared room in a boutique hotel': 'Privates oder geteiltes Zimmer in einem Boutique-Hotel',
    'Language changed': 'Sprache geändert',
    'Back': 'Zurück',
  };

  // ---- Rusça sözlük — TR ile aynı anahtar kapsamı ----
  var RU = {
    'Hotel, car, experiences': 'Отели, авто, впечатления',
    'With us, your trip is filled with amazing experiences.': 'С нами ваше путешествие наполнится потрясающими впечатлениями.',
    'Start your search': 'Начать поиск',
    'Where to?': 'Куда?',
    'Any week': 'Любая неделя',
    'Add guests': 'Добавить гостей',
    'Location': 'Локация',
    'Where are you going?': 'Куда вы направляетесь?',
    'Check in': 'Заезд',
    'Check out': 'Выезд',
    'Add date': 'Добавить дату',
    'Guests': 'Гости',
    '%s Guests': '%s гостей',
    'Stays': 'Жильё',
    'Cars': 'Автомобили',
    'Experiences': 'Впечатления',
    'Flights': 'Авиабилеты',
    'RealEstates': 'Недвижимость',
    'Templates': 'Шаблоны',
    'Travelers': 'Путешественники',
    'List your property': 'Разместить объявление',
    'Adults': 'Взрослые',
    'Ages 13+': 'От 13 лет',
    'Children': 'Дети',
    'Infants': 'Младенцы',
    'Notifications': 'Уведомления',
    'You have no new notifications.': 'У вас нет новых уведомлений.',
    'Sign in': 'Войти',
    'Create account': 'Создать аккаунт',
    'Decrease %s': 'Уменьшить: %s',
    'Increase %s': 'Увеличить: %s',
    'Explore the best places to stay in the world.': 'Откройте лучшие места для проживания в мире.',
    'Let\'s go on an adventure': 'Отправимся в приключение',
    'Benefits': 'Преимущества',
    'Why host with us?': 'Почему стоит сдавать у нас?',
    'Advertising': 'Реклама',
    'Cost-effective advertising': 'Эффективная реклама',
    'A free listing, you can advertise your rental with no upfront costs': 'С бесплатным объявлением вы рекламируете своё жильё без первоначальных затрат',
    'Exposure': 'Охват',
    'Reach millions with Chisfis': 'Достигайте миллионов с Chisfis',
    'Millions of people are searching for unique places to stay around the world': 'Миллионы людей ищут уникальное жильё по всему миру',
    'Secure': 'Безопасно',
    'Secure and simple': 'Безопасно и просто',
    'A Chisfis listing gives you a secure and easy way to take bookings and payments online': 'Объявление Chisfis — безопасный и простой способ принимать бронирования и онлайн-платежи',
    'Featured places to stay': 'Избранные места',
    'Selected based on user reviews. Updated weekly': 'На основе отзывов гостей. Обновляется еженедельно',
    'View all': 'Показать все',
    'Show me more': 'Показать больше',
    'Become a host': 'Стать хозяином',
    'How it work': 'Как это работает',
    'Keep calm & travel on': 'Сохраняйте спокойствие и путешествуйте',
    'Book & relax': 'Бронируйте и отдыхайте',
    'Let each trip be an inspirational journey, each room a peaceful space': 'Пусть каждая поездка будет вдохновляющим путешествием, а каждый номер — пространством покоя',
    'Smart checklist': 'Умный чек-лист',
    'Save more': 'Экономьте больше',
    'Top 10 authors of the month': 'Топ-10 хозяев месяца',
    'Meet the hosts behind the best-rated stays.': 'Познакомьтесь с хозяевами лучших мест.',
    'Join our newsletter': 'Подпишитесь на рассылку',
    'Get exclusive deals and inspiration delivered straight to your inbox.': 'Эксклюзивные предложения и вдохновение прямо на вашу почту.',
    'Get more discount': 'Получите скидку больше',
    'Get premium deals': 'Получите премиум-предложения',
    'Endless inspiration': 'Бесконечное вдохновение',
    'Explore nearby': 'Исследуйте окрестности',
    'Great places near where you live': 'Отличные места рядом с вами',
    'Explore by types of stays': 'По типам жилья',
    'Explore houses based on 10 types of stays': 'Дома по 10 типам проживания',
    'Enjoy the great cold': 'Наслаждайтесь великим холодом',
    'Sleep in a floating way': 'Спите на воде',
    "In the billionaire's house": 'В доме миллиардера',
    'Cool in the deep forest': 'Прохлада в глубоком лесу',
    'Sunset in the desert': 'Закат в пустыне',
    'Become a host with us.': 'Станьте хозяином вместе с нами.',
    'With Chisfis, booking resorts, villas, hotels, private homes, and apartments becomes quick, convenient, and easy.': 'С Chisfis бронирование курортов, вилл, отелей, частных домов и квартир становится быстрым и удобным.',
    'Explore stays': 'Обзор жилья',
    'Worldwide': 'По всему миру',
    'stays': 'жилья',
    'Over': 'Более',
    'places': 'мест',
    'Book Flights': 'Бронирование авиабилетов',
    'Explore the world with us.': 'Откройте мир вместе с нами.',
    'Find rides.': 'Найдите поездку.',
    'Find your perfect cars': 'Найдите свой идеальный автомобиль',
    'Discover Adventures': 'Откройте приключения',
    'Experience listings': 'Впечатления',
    'Stay information': 'Информация о жилье',
    'Room Rates': 'Цены на номера',
    'Amenities': 'Удобства',
    'Availability': 'Доступность',
    'Reviews': 'Отзывы',
    'reviews': 'отзывов',
    'Making the world a better place through constructing elegant hierarchies.': 'Делаем мир лучше, создавая элегантные иерархии.',
    'Solutions': 'Решения',
    'Marketing': 'Маркетинг',
    'Analytics': 'Аналитика',
    'Automation': 'Автоматизация',
    'Commerce': 'Торговля',
    'Support': 'Поддержка',
    'Submit ticket': 'Отправить обращение',
    'Documentation': 'Документация',
    'Guides': 'Руководства',
    'Company': 'Компания',
    'About': 'О нас',
    'Blog': 'Блог',
    'Jobs': 'Вакансии',
    'Press': 'Пресса',
    'Legal': 'Юридическое',
    'Terms of service': 'Условия обслуживания',
    'Privacy policy': 'Политика конфиденциальности',
    'License': 'Лицензия',
    'Insights': 'Обзоры',
    'All rights reserved.': 'Все права защищены.',
    'Explore': 'Обзор',
    'Wishlists': 'Избранное',
    'Account': 'Аккаунт',
    'Menu': 'Меню',
    'Home': 'Главная',
    'Search': 'Поиск',
    'Voice search': 'Голосовой поиск',
    'Listening...': 'Слушаю...',
    'Voice search is not supported in this browser': 'Этот браузер не поддерживает голосовой поиск',
    'Cart': 'Корзина',
    'Dark mode': 'Тёмная тема',
    'Light mode': 'Светлая тема',
    'Sahra mode': 'Тема Сахра',
    'Toggle dark mode': 'Переключить тёмную тему',
    'CATEGORIES': 'КАТЕГОРИИ',
    'Language': 'Язык',
    'Currency': 'Валюта',
    'Hotels': 'Отели',
    'Holiday homes & villas': 'Дома и виллы для отпуска',
    'Yacht rental': 'Аренда яхты',
    'Tours': 'Туры',
    'Activities': 'Активности',
    'All experiences': 'Все впечатления',
    'Authors': 'Авторы',
    'Search city, hotel or region...': 'Поиск города, отеля или региона...',
    'places in': 'мест в',
    'Interactive map is unavailable offline': 'Интерактивная карта недоступна офлайн',
    'Open in Google Maps': 'Открыть в Google Maps',
    'Top 10 author of the month': 'Автор топ-10 месяца',
    'What guests are saying about': 'Что говорят гости',
    'Supperhost': 'Суперхозяин',
    'years': 'лет',
    'Providing': 'Предлагает',
    'Joined on': 'С нами с',
    'Suggested locations': 'Предлагаемые места',
    'Ages 13 or above': '13 лет и старше',
    'Ages 2–12': '2–12 лет',
    'Ages 0–2': '0–2 лет',
    'Under 2': 'До 2 лет',
    'per night': 'за ночь',
    'beds': 'кровати',
    'Entire cabin': 'Целый домик',
    'Hotel room': 'Номер в отеле',
    'Holiday home': 'Дом для отпуска',
    'Home stay': 'Гостевой дом',
    'Private room': 'Отдельная комната',
    'Entire place': 'Целое жильё',
    'Have a place to yourself': 'Жильё в полном вашем распоряжении',
    'Have your own room and share some common spaces': 'Своя комната и общий доступ к некоторым зонам',
    'Have a private or shared room in a boutique hotel': 'Отдельная или общая комната в бутик-отеле',
    'Language changed': 'Язык изменён',
    'Back': 'Назад',
  };

  // Dil döngüsü ve çeviri tablosu: i18n.gleam içindeki kanonik altı dil
  // (TR, EN, DE, RU, ZH ve FR).
  // Ana sayfadaki Chisfis sözlüğü bu listeyle aynı döngüyü kullanır.
  var FR = {
    'Hotel, car, experiences': 'Hôtel, voiture, expériences',
    'With us, your trip is filled with amazing experiences.': 'Avec nous, votre voyage est rempli d’expériences inoubliables.',
    'Start your search': 'Commencer votre recherche',
    'Guests': 'Voyageurs',
    'Adults': 'Adultes',
    'Children': 'Enfants',
    'Infants': 'Bébés',
    'Search': 'Rechercher',
    'Search listings...': 'Rechercher des annonces...',
    'Voice search': 'Recherche vocale',
    'Listening...': 'Écoute en cours...',
    'Voice search is not supported in this browser': 'La recherche vocale n’est pas prise en charge par ce navigateur',
    'Language': 'Langue',
    'Currency': 'Devise',
    'Templates': 'Modèles',
    'Travelers': 'Voyageurs',
    'List your property': 'Publier votre logement',
    'Hotel': 'Hôtels',
    'Stays': 'Hébergements',
    'Cars': 'Voitures',
    'Experiences': 'Expériences',
    'Flights': 'Vols',
    'Let\'s go on an adventure': 'Partons à l’aventure',
    'Explore the best places to stay in the world.': 'Découvrez les meilleurs hébergements du monde.',
    'Benefits': 'Avantages',
    'Why host with us?': 'Pourquoi devenir hôte chez nous ?',
    'Featured places to stay': 'Hébergements à la une',
    'How it work': 'Comment ça marche',
    'Keep calm & travel on': 'Restez serein et voyagez',
    'Become a host': 'Devenir hôte',
    'Join our newsletter': 'Rejoindre notre newsletter',
    'Explore nearby': 'Explorer les environs',
    'Great places near where you live': 'De beaux endroits près de chez vous',
    'Explore by types of stays': 'Explorer par type d’hébergement',
    'Explore': 'Explorer',
    'Wishlists': 'Favoris',
    'Account': 'Compte',
    'Cart': 'Panier',
    'Notifications': 'Notifications',
    'Language changed': 'Langue modifiée',
    'Back': 'Retour'
  };
  var ZH = {
    'Hotel, car, experiences': '酒店、租车与体验',
    'With us, your trip is filled with amazing experiences.': '与我们一起，开启精彩旅程。',
    'Start your search': '开始搜索',
    'Guests': '住客',
    'Adults': '成人',
    'Children': '儿童',
    'Infants': '婴儿',
    'Search': '搜索',
    'Search listings...': '搜索房源...',
    'Voice search': '语音搜索',
    'Listening...': '正在聆听...',
    'Voice search is not supported in this browser': '此浏览器不支持语音搜索',
    'Language': '语言',
    'Currency': '货币',
    'Templates': '模板',
    'Travelers': '旅行者',
    'List your property': '发布您的房源',
    'Hotel': '酒店',
    'Stays': '住宿',
    'Cars': '租车',
    'Experiences': '体验',
    'Flights': '航班',
    'Let\'s go on an adventure': '开始冒险吧',
    'Explore the best places to stay in the world.': '探索世界上最棒的住宿地点。',
    'Benefits': '优势',
    'Why host with us?': '为什么选择与我们合作？',
    'Featured places to stay': '精选住宿',
    'How it work': '使用方式',
    'Keep calm & travel on': '安心出行，尽情旅行',
    'Become a host': '成为房东',
    'Join our newsletter': '订阅我们的资讯',
    'Explore nearby': '探索附近',
    'Great places near where you live': '发现您身边的好去处',
    'Explore by types of stays': '按住宿类型探索',
    'Explore': '探索',
    'Wishlists': '收藏夹',
    'Account': '账户',
    'Cart': '购物车',
    'Notifications': '通知',
    'Language changed': '语言已更改',
    'Back': '返回'
  };
  var NEXT_LANG = { tr: 'en', en: 'de', de: 'ru', ru: 'zh', zh: 'fr', fr: 'tr' };
  var DICTS = { tr: TR, en: {}, de: DE, ru: RU, zh: ZH, fr: FR };
  var TOGGLE_LABEL = { tr: 'EN', en: 'DE', de: 'RU', ru: 'ZH', zh: 'FR', fr: 'TR' };
  var TOGGLE_TITLE = {
    tr: "Switch to English",
    en: 'Auf Deutsch wechseln',
    de: 'Переключить на русский',
    ru: '切换到中文',
    zh: 'Passer au français',
    fr: "Passer au turc",
  };
  var currentLang = 'en';
  try { currentLang = localStorage.getItem(LANG_KEY) || 'en'; } catch (e) {}

  /* ---- Sunucu tarafı dil tercihi (girişli kullanıcılar) ----
   * Zincir: cookie(nexus_lang) → localStorage → varsayılan 'en'.
   * Kullanıcı hesabına kaydedilen tercih; her sayfada cookie ile başlar,
   * oturumlar/cihazlar arası kalıcıdır. localStorage fallback cookie'siz
   * (misafir) ziyaretler için kalır.
   */
  function readLangCookie() {
    var parts = document.cookie.split(/;\s*/);
    for (var i = 0; i < parts.length; i++) {
      var eq = parts[i].indexOf('=');
      if (eq > 0 && parts[i].slice(0, eq) === 'nexus_lang') {
        var v = decodeURIComponent(parts[i].slice(eq + 1));
        return ['tr', 'en', 'de', 'ru', 'zh', 'fr'].indexOf(v) !== -1 ? v : null;
      }
    }
    return null;
  }
  var serverLang = readLangCookie();
  if (serverLang) {
    currentLang = serverLang;
    try { localStorage.setItem(LANG_KEY, serverLang); } catch (e) {}
  }

  /* ---- Sunucu tarafı para birimi tercihi (girişli kullanıcılar) ----
   * Dil tercihiyle birebir aynı desen. Zincir:
   * cookie(nexus_currency) → localStorage('chisfis-currency') → 'TRY'.
   * Sunucu, girişte kayıtlı tercihi nexus_currency çerezine damgalar;
   * her sayfa cookie'den başlar, oturumlar/cihazlar arası kalıcıdır.
   */
  function readCurrencyCookie() {
    var parts = document.cookie.split(/;\s*/);
    for (var i = 0; i < parts.length; i++) {
      var eq = parts[i].indexOf('=');
      if (eq > 0 && parts[i].slice(0, eq) === 'nexus_currency') {
        var v = decodeURIComponent(parts[i].slice(eq + 1));
        return ['TRY', 'USD', 'EUR', 'GBP', 'SAR'].indexOf(v) !== -1 ? v : null;
      }
    }
    return null;
  }
  var serverCurrency = readCurrencyCookie();
  if (serverCurrency) {
    try { localStorage.setItem('chisfis-currency', serverCurrency); } catch (e) {}
  }
  // Girişli kullanıcıda para birimi değişimini hesaba yaz (en iyi çaba; 401 → misafir)
  function saveCurrencyPref(code) {
    try {
      var csrf = (document.cookie.match(/(?:^|;\s*)nexus_csrf=([^;]*)/) || [])[1];
      if (!csrf) return; // misafir oturum: sunucuda hesap yok
      var body = 'csrf=' + encodeURIComponent(decodeURIComponent(csrf));
      fetch('/admin/preferences/currency?currency=' + encodeURIComponent(code), {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body,
      }).catch(function () {});
    } catch (e) {}
  }
  // Girişli kullanıcıda dil değişimini hesaba yaz (en iyi çaba; 401 → misafir)
  function saveLangPref(lang) {
    try {
      var csrf = (document.cookie.match(/(?:^|;\s*)nexus_csrf=([^;]*)/) || [])[1];
      if (!csrf) return; // misafir oturum: sunucuda hesap yok
      var body = 'csrf=' + encodeURIComponent(decodeURIComponent(csrf));
      fetch('/admin/preferences/language?lang=' + encodeURIComponent(lang), {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: body,
      }).catch(function () {});
    } catch (e) {}
  }
  function t(enText) {
    var dict = DICTS[currentLang];
    return (dict && dict[enText]) || enText;
  }
  /* ---- Dil değişimi bildirimi (geri al) ----
   * Kalıcı dil seçimi geri bildirim ister: kullanıcı yanlışlıkla dil
   * değiştirdiyse tek dokunuşla eski dile dönebilmeli. Tüm seçim yolları
   * (masaüstü globe popover'ı, mobil mm-pill popover'ı, eski .lang-toggle
   * döngüsü) `nexus:lang` olayından geçer; bildirim oradan tek yerde
   * üretilir, böylece üç yol da aynı geri-alma deneyimini alır.
   * Erken açılış (boot applyLang) olay yaymaz → açılışta bildirim çıkmaz.
   * Geri düğmesi `revert: true` ile yayar; bu bildirim tekrar tetiklenmez. */
  var LANG_TOAST_MS = 7000;
  function dispatchLang(lang, revert) {
    document.dispatchEvent(
      new CustomEvent('nexus:lang', { detail: { lang: lang, revert: !!revert } }),
    );
  }
  function dismissLangToast() {
    var host = document.getElementById('store-toast-host');
    if (!host) return;
    var toast = host.querySelector('.store-toast');
    if (!toast) return;
    if (toast._timer) { clearTimeout(toast._timer); toast._timer = null; }
    toast.classList.remove('store-toast--in');
    var removed = toast;
    setTimeout(function () { if (removed.parentNode) removed.parentNode.removeChild(removed); }, 200);
  }
  function showLangToast(prevLang, newLang) {
    if (typeof document === 'undefined' || !document.body) return;
    var host = document.getElementById('store-toast-host');
    if (!host) {
      host = document.createElement('div');
      host.id = 'store-toast-host';
      host.className = 'store-toast-host';
      // Ekran okuyucu duyurusu: bildirim statü olarak ilan edilir
      host.setAttribute('aria-live', 'polite');
      host.setAttribute('aria-atomic', 'true');
      document.body.appendChild(host);
    }
    dismissLangToast();

    // Hedef dilde etiket: applyLang çoktan çalıştı, t() yeni dili çözer
    var name = (function () {
      var langs = (window.NEXUS_LOCALE && window.NEXUS_LOCALE.langs) || [];
      for (var i = 0; i < langs.length; i++) {
        if (langs[i].code === newLang) return langs[i].main;
      }
      return newLang.toUpperCase();
    })();

    var toast = document.createElement('div');
    toast.className = 'store-toast';
    toast.setAttribute('role', 'status');

    var msg = document.createElement('span');
    msg.className = 'store-toast__msg';
    msg.textContent = t('Language changed') + ': ' + name;

    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'store-toast__action';
    btn.textContent = t('Back');
    btn.setAttribute('aria-label', t('Back') + ': ' + name);
    btn.addEventListener('click', function () {
      dismissLangToast();
      dispatchLang(prevLang, true);
    });

    toast.appendChild(msg);
    toast.appendChild(btn);
    host.appendChild(toast);
    // giriş animasyonu (bir sonraki karede sınıf eklenir)
    requestAnimationFrame(function () { toast.classList.add('store-toast--in'); });
    toast._timer = setTimeout(dismissLangToast, LANG_TOAST_MS);
  }
  function applyLang(lang) {
    currentLang = lang;
    // ortak yerel ayar kaynağını senkronla (desktop + mobile popover'lar)
    if (window.NEXUS_LOCALE) window.NEXUS_LOCALE.lang = lang;
    try { localStorage.setItem(LANG_KEY, lang); } catch (e) {}
    // sunucu tarafı tercih (girişli kullanıcı): hem kalıcı kayıt hem
    // sayfalar arası tutarlılık için çerezi de yazar
    saveLangPref(lang);
    document.cookie = 'nexus_lang=' + encodeURIComponent(lang) + ';path=/;max-age=31536000;samesite=lax';
    // update toggle labels (4 dil: tr → de → ru → en → tr döngüsü)
    var cycleLabel = TOGGLE_LABEL[lang] || 'TR';
    var cycleTitle = TOGGLE_TITLE[lang] || "Türkçe'ye geç";
    $$('.lang-toggle').forEach(function (btn) {
      btn.textContent = cycleLabel;
      btn.title = cycleTitle;
    });
    // translate data-i18n elements
    $$('[data-i18n]').forEach(function (el) {
      var key = el.getAttribute('data-i18n');
      if (!key) return;
      // Anahtar (data-i18n attr) her zaman İngilizce referanstır — sunucu
      // öğeyi Türkçe basmış olsa bile key üzerinden çevrilir: tr→TR sözlüğü,
      // de→DE, ru→RU, en→anahtarın kendisi (fallback).
      el.textContent = t(key);
    });
    // translate data-i18n-placeholder
    $$('[data-i18n-placeholder]').forEach(function (el) {
      var key = el.getAttribute('data-i18n-placeholder');
      if (key) el.placeholder = t(key);
    });
    // translate data-i18n-html (for mixed content)
    $$('[data-i18n-html]').forEach(function (el) {
      var key = el.getAttribute('data-i18n-html');
      if (key) el.innerHTML = t(key);
    });
  }
  // inject lang toggle into desktop header
  var langToggleHTML = '<button type="button" class="lang-toggle -m-2.5 flex cursor-pointer items-center justify-center rounded-full px-2.5 py-1.5 text-xs font-bold hover:bg-neutral-100 focus-visible:outline-hidden dark:hover:bg-neutral-800" aria-label="Toggle language" title="' + (TOGGLE_TITLE[currentLang] || "Türkçe'ye geç") + '">' + (TOGGLE_LABEL[currentLang] || 'TR') + '</button>';
  // insert after theme toggle in desktop header
  $$('.relative.z-20.hidden .flex.flex-1').forEach(function (rightGroup) {
    if (!rightGroup.querySelector('.lang-toggle')) {
      var themeBtn = rightGroup.querySelector('#theme-toggle');
      if (themeBtn) themeBtn.insertAdjacentHTML('afterend', langToggleHTML);
    }
  });
  // Palet swatch grubu: dark / light / sahra doğrudan seçimi. Header ve
  // mobil menüdeki tema düğmesinin yanına bir kez enjekte edilir.
  var swatchHTML = '<div class="store-theme-swatches" role="group" aria-label="Mağaza tema paleti">'
    + '<button type="button" class="store-theme-swatch" data-store-theme="dark" aria-label="Karanlık palet" title="Karanlık" style="--sw-bg:#111827;--sw-acc:#38bdf8"></button>'
    + '<button type="button" class="store-theme-swatch" data-store-theme="light" aria-label="Aydınlık palet" title="Aydınlık" style="--sw-bg:#f3f4f6;--sw-acc:#6366f1"></button>'
    + '<button type="button" class="store-theme-swatch" data-store-theme="sahra" aria-label="Sahra — sıcak amber palet" title="Sahra — sıcak amber" style="--sw-bg:#170f08;--sw-acc:#f59e0b"></button>'
    + '<button type="button" class="store-theme-swatch store-theme-swatch-auto" data-store-theme="auto" aria-label="Otomatik — saate göre palet" title="Otomatik: gündüz aydınlık, akşam sahra, gece karanlık" style="--sw-bg:#0f172a;--sw-acc:#94a3b8">🕒</button>'
    + '</div>';
  $$('.relative.z-20.hidden .flex.flex-1').forEach(function (rightGroup) {
    if (!rightGroup.querySelector('.store-theme-swatches')) {
      var tBtn = rightGroup.querySelector('#theme-toggle');
      if (tBtn) tBtn.insertAdjacentHTML('afterend', swatchHTML);
    }
  });
  var menuPanel2 = $('.mobile-menu__panel');
  if (menuPanel2 && !menuPanel2.querySelector('.store-theme-swatches')) {
    var tBtn2 = menuPanel2.querySelector('#theme-toggle');
    if (tBtn2) tBtn2.insertAdjacentHTML('afterend', swatchHTML);
  }
  // Enjeksiyon sonrası aktif swatch işaretini senkronla (ilk applyTheme
  // swatch'lar DOM'a girmeden çalıştı)
  var cur = null;
  try { cur = localStorage.getItem(THEME_KEY); } catch (e) {}
  if (cur === 'auto') {
    document.querySelectorAll('.store-theme-swatch').forEach(function (s) {
      var on = s.getAttribute('data-store-theme') === 'auto';
      s.classList.toggle('active', on);
      s.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
  } else {
    applyTheme(currentMode());
  }
  // also inject into mobile menu panel if it exists
  var menuPanel = $('.mobile-menu__panel');
  if (menuPanel && !menuPanel.querySelector('.lang-toggle')) {
    var themeBtn2 = menuPanel.querySelector('#theme-toggle');
    if (themeBtn2) themeBtn2.insertAdjacentHTML('afterend', langToggleHTML);
  }
  // NOTE: mobil alt barda (footer) dil değiştirici gösterilmez.
  // Dil değiştirme masaüstü header ve mobil menü panelinden yapılabilir.
  // click handler for lang toggles — döngü de tek kanaldan yayar ki
  // geri-al bildirimi tüm seçim yollarında aynı olsun
  document.addEventListener('click', function (e) {
    var btn = e.target.closest('.lang-toggle');
    if (!btn) return;
    dispatchLang(NEXT_LANG[currentLang] || 'en');
  });
  // Dil seçimi (header-popovers.js globe popover'ı, mobil mm-pill popover'ı,
  // eski .lang-toggle döngüsü) tek kanaldan akar. Bildirim yalnızca dil
  // gerçekten değiştiğinde ve geri-alma tıklamasında DEĞİL çıkar.
  document.addEventListener('nexus:lang', function (e) {
    var lang = e.detail && e.detail.lang;
    if (!lang || lang === currentLang) return;
    var prev = currentLang;
    applyLang(lang);
    if (!(e.detail && e.detail.revert)) showLangToast(prev, lang);
  });
  /* ---- Ortak yerel ayar kaynağı: NEXUS_LOCALE ----
   * Desktop globe popover'ı (header-popovers.js) ve mobil mm-pill
   * popover'ı AYNI veri ve davranışı kullanır: diller, para birimleri,
   * aktif seçimler ve applyCurrency akışı tek yerde tanımlıdır.
   * Dil: çerez → localStorage → 'en' (applyLang zinciri). Para:
   * localStorage 'chisfis-currency' → 'TRY'; seçim 'nexus:currency'
   * olayı yayınlar (dinleyen sayfalar anında dönüştürebilir).
   */
  var NEXUS_LOCALE = {
    langs: [
      { code: 'tr', main: '🇹🇷 Türkçe', sub: 'Türkiye' },
      { code: 'en', main: '🇬🇧 English', sub: 'United States' },
      { code: 'de', main: '🇩🇪 Deutsch', sub: 'Deutschland' },
      { code: 'ru', main: '🇷🇺 Русский', sub: 'Россия' },
      { code: 'zh', main: '🇨🇳 简体中文', sub: '中国' },
      { code: 'fr', main: '🇫🇷 Français', sub: 'France' },
    ],
    currencies: [
      { code: 'TRY', symbol: '₺' },
      { code: 'USD', symbol: '$' },
      { code: 'EUR', symbol: '€' },
      { code: 'GBP', symbol: '£' },
      { code: 'SAR', symbol: '﷼' },
    ],
    lang: currentLang,
    currency: (function () { try { return localStorage.getItem('chisfis-currency') || 'TRY'; } catch (e) { return 'TRY'; } })(),
    applyCurrency: function (code) {
      NEXUS_LOCALE.currency = code;
      try { localStorage.setItem('chisfis-currency', code); } catch (e) {}
      // sunucu tarafı tercih (girişli kullanıcı): kalıcı kayıt + çerez —
      // sonraki sayfa açılışları cookie'den doğru para birimiyle başlar
      saveCurrencyPref(code);
      document.cookie = 'nexus_currency=' + encodeURIComponent(code) + ';path=/;max-age=31536000;samesite=lax';
      document.dispatchEvent(new CustomEvent('nexus:currency', { detail: { currency: code } }));
    },
  };
  window.NEXUS_LOCALE = NEXUS_LOCALE;
  // Çeviri fonksiyonunu global'e aç: header-popovers.js gibi diğer modüller
  // de mevcut dilde etiket basabilsin (t('Language') → Sprache/Язык/Dil).
  window.NEXUS_T = t;

  /* ---- İstemci tarafı para birimi dönüşüm katmanı ----
   * Fiyatlar sunucuda zaten `nexus_currency` çerezine göre render edilir
   * (Gleam `ssr_currency` geçişi); bu katman seçim değişimini sayfa
   * yenilemeden anında uygular:
   *   • Kanonik kaynak: fiyat düğümlerinin taşıdığı `data-price-minor`
   *     (ilanın TRY tutarı, kuruş) — sunucu çevirdiği için metinden okumak
   *     çift dönüşüme yol açardı. Öznitelik yoksa metin ayrıştırılır.
   *   • `data-price-cur` TRY dışıysa ilan o para biriminde fiyatlanmıştır;
   *     dönüşüm uygulanmaz (sunucu da uygulamaz).
   *   • Kur: GET /api/public/rates (agency.currencies; rate = 1 birim
   *     yabancı para kaç TRY) — sessionStorage'da 1 saat cache'lenir.
   *   • Hedefler: kart fiyatlari (.card-price strong), detay/checkout
   *     büyük fiyatı, rezervasyon kartı tutarı (strong içleri) ve ana sayfa
   *     vitrin/demo kartları (.featured-card-price, şablonun sıkı biçimi:
   *     simge tutara bitişik).
   *   • nexus:currency dinleyicisi seçim değişimini anında uygular.
   */
  var FX = {
    rates: null,       // { USD: {rate, symbol}, ... }
    fetchedAt: 0,
    TTL: 3600 * 1000,
    symbols: { TRY: '₺', USD: '$', EUR: '€', GBP: '£', SAR: '﷼' },
    load: function (force) {
      // cache: sessionStorage 1 saat
      try {
        var cached = JSON.parse(sessionStorage.getItem('nexus-fx') || 'null');
        if (cached && Date.now() - cached.at < FX.TTL) {
          FX.rates = cached.rates;
          if (!force) { FX.apply(); return Promise.resolve(); }
        }
      } catch (e) {}
      if (!force && FX.rates) { FX.apply(); return Promise.resolve(); }
      return fetch('/api/public/rates', { cache: 'no-store' })
        .then(function (r) { if (!r.ok) throw new Error('rates'); return r.json(); })
        .then(function (data) {
          if (data && data.rates) {
            FX.rates = data.rates;
            try { sessionStorage.setItem('nexus-fx', JSON.stringify({ at: Date.now(), rates: data.rates })); } catch (e) {}
          }
          FX.apply();
        })
        .catch(function () { /* kur alınamazsa TRY kalır */ });
    },
    parseTry: function (text) {
      // "₺ 25000.00" / "₺25000,00" → 25000.00
      var m = text.replace(/\s/g, '').replace(/[^0-9.,]/g, '').replace(/,(\d{2})$/, '.$1').replace(/,/g, '');
      var v = parseFloat(m);
      return isNaN(v) ? null : v;
    },
    format: function (value, code) {
      var dbSym = FX.rates && FX.rates[code] && FX.rates[code].symbol;
      // Veritabanı simgesi boş/yer tutucu olabilir (canlı veride SAR '?'
      // gelmişti): o durumda derleme içi tabloya düşülür. Sunucu tarafı
      // (ssr_currency.display_symbol) aynı yedeği kullanır.
      var sym = (dbSym && dbSym !== '?') ? dbSym : (FX.symbols[code] || code);
      var n = value >= 1000 ? Math.round(value) : Math.round(value * 100) / 100;
      var str = n.toLocaleString('en-US', { minimumFractionDigits: n >= 1000 ? 0 : 2, maximumFractionDigits: n >= 1000 ? 0 : 2 });
      return sym + ' ' + str;
    },
    // Şablon vitrin kartı biçimi: simge tutara BİTİŞİK ("$59.20"), araya
    // boşluk girmez. Sunucu tarafı (ssr_currency.format_featured) ile
    // birebir aynı sayı kuralını kullanır — yalnızca boşluk yoktur, bu
    // yüzden JS boot fiyatı değiştirmez.
    formatCompact: function (value, code) {
      var dbSym = FX.rates && FX.rates[code] && FX.rates[code].symbol;
      var sym = (dbSym && dbSym !== '?') ? dbSym : (FX.symbols[code] || code);
      var n = value >= 1000 ? Math.round(value) : Math.round(value * 100) / 100;
      var str = n.toLocaleString('en-US', { minimumFractionDigits: n >= 1000 ? 0 : 2, maximumFractionDigits: n >= 1000 ? 0 : 2 });
      return sym + str;
    },
    // Vitrin kartının TRY biçimi (sunucunun bastığı şablon biçimi): simge
    // bitişik ve Türkçe gruplama (`.` binlik) — "₺2.800". `toLocaleString`
    // tr-TR ile aynı sonucu verir, bu yüzden TRY'ye dönüş sunucu metnini
    // birebir geri getirir.
    formatTryCompact: function (value) {
      return '₺' + value.toLocaleString('tr-TR', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
    },
    // Sunucunun TRY biçimi (amount_minor_display): "₺ 25000.00". TRY'ye
    // dönüşte SSR öncesi görünümü birebir geri getirir.
    formatTry: function (value) {
      return '₺ ' + value.toFixed(2);
    },
    /* TRY tutarını hedef para birimine çevirir. Kur sözleşmesi sunucu
       tarafıyla (ssr_currency.convert_amount) aynıdır:
       `rates[code].rate` = 1 birim yabancı para kaç TRY → tutar / rate.
       Kur yok/geçersizse (0, negatif, sayı değil) tutar değişmeden döner,
       böylece kur alınamadığında fiyat TRY kalır (NaN basılmaz). */
    convert: function (amount, code) {
      var rate = FX.rates && FX.rates[code] && Number(FX.rates[code].rate);
      if (!rate || !isFinite(rate) || rate <= 0) return amount;
      return amount / rate;
    },
    /* Fiyat kaynağını çözer: kanonik kuruş tutarı (`data-price-minor`) veya
       gövdedeki metin. `data-price-cur` TRY dışıysa dokunulmaz. */
    source: function (el, text) {
      var cur = (el.getAttribute('data-price-cur') || '').toUpperCase();
      if (cur && cur !== 'TRY') return { skip: true };
      var minor = el.getAttribute('data-price-minor');
      if (minor != null && minor !== '') {
        var m = parseInt(minor, 10);
        if (!isNaN(m)) return { amount: m / 100, minor: true };
      }
      var v = FX.parseTry(text);
      return v == null ? { skip: true } : { amount: v, minor: false };
    },
    apply: function () {
      var code = NEXUS_LOCALE.currency;
      // Vitrin/demo kartı (`featured-card-price`) şablonun sıkı biçimini
      // kullanır (simge bitişik); diğer tüm fiyatlar kanonik boşluklu biçimi.
      var nodes = document.querySelectorAll('.card-price strong, .booking-card-price strong, .featured-card-price, .flex.items-end.text-2xl.font-semibold, .flex.items-end.sm\\:text-3xl');
      // Fiyat metnini seçilen biçimde yazar (birim spanı varsa ona dokunmaz)
      function render(el, amount, minor, orig, compact) {
        if (code === 'TRY') {
          if (minor) return compact ? FX.formatTryCompact(amount) : FX.formatTry(amount);
          return orig;
        }
        var converted = FX.convert(amount, code);
        return compact ? FX.formatCompact(converted, code) : FX.format(converted, code);
      }
      nodes.forEach(function (el) {
        var compact = el.classList.contains('featured-card-price');
        if (el.children.length > 0) {
          // detay sayfası: text düğümleri fiyat + span birim; yalnız text düğümü çevir
          var tn = null;
          for (var i = 0; i < el.childNodes.length; i++) { if (el.childNodes[i].nodeType === 3 && el.childNodes[i].textContent.trim()) { tn = el.childNodes[i]; break; } }
          if (!tn) return;
          var orig = el.getAttribute('data-try-orig') || tn.textContent;
          var src = FX.source(el, orig);
          if (src.skip) return;
          if (!src.minor && !el.getAttribute('data-try-orig')) el.setAttribute('data-try-orig', orig);
          tn.textContent = render(el, src.amount, src.minor, orig, compact);
          return;
        }
        var origText = el.getAttribute('data-try-orig') || el.textContent;
        var src2 = FX.source(el, origText);
        if (src2.skip) return;
        if (!src2.minor && !el.getAttribute('data-try-orig')) el.setAttribute('data-try-orig', origText);
        el.textContent = render(el, src2.amount, src2.minor, origText, compact);
      });
    },
  };
  window.NEXUS_FX = FX;
  // Seçim değişiminde anında dönüşüm; kurlar henüz yoksa önce çek
  document.addEventListener('nexus:currency', function (e) {
    var code = e.detail && e.detail.currency;
    if (!code) return;
    if (code === 'TRY') { FX.apply(); return; }
    FX.load(false).then(function () { FX.apply(); });
  });
  // Boot: seçili para birimi TRY değilse kurları getir ve sayfayı çevir
  if (NEXUS_LOCALE.currency && NEXUS_LOCALE.currency !== 'TRY') {
    FX.load(false);
  }

  // apply saved language on load
  applyLang(currentLang);
  // Dinamik bölümler (mobil menü, §18 üst/alt bar) boot applyLang'tan SONRA
  // kurulur ve İngilizce kelimelerle basılır; kayıtlı dil tr/de/ru ise
  // kısa gecikmeyle bir çeviri geçişi daha çalıştırarak onları da yakala.
  if (currentLang !== 'en') {
    setTimeout(applyLang, 0, currentLang);
    setTimeout(applyLang, 400, currentLang);
    setTimeout(applyLang, 1200, currentLang);
  }

  /* ---- Kapanış fade'i (header-popovers.js ile aynı sözleşme) ----
     Panel anında `display: none` olmak yerine 140 ms söner
     (chisfis-bridge.css: `.nx-closing` + `nx-panel-out`). `CLOSE_FADE_MS`
     CSS'teki `.14s` ile eşleşmelidir. `data-state` anında `closed` olur.
     Hareket azaltma tercihinde sönme yok. */
  var CLOSE_FADE_MS = 140;

  function reducedMotion() {
    return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
  }

  function hidePanel(panel) {
    if (panel.__nxHideTimer) { clearTimeout(panel.__nxHideTimer); panel.__nxHideTimer = null; }
    panel.classList.remove('nx-closing');
    panel.hidden = true;
    panel.style.display = 'none';
  }

  function openPanel(panel) {
    if (!panel) return;
    if (panel.__nxHideTimer) { clearTimeout(panel.__nxHideTimer); panel.__nxHideTimer = null; }
    panel.classList.remove('nx-closing');
    panel.hidden = false;
    panel.style.display = '';
    panel.setAttribute('data-state', 'open');
  }

  function closePanel(panel) {
    if (!panel) return;
    panel.setAttribute('data-state', 'closed');
    if (reducedMotion()) { hidePanel(panel); return; }
    panel.classList.add('nx-closing');
    if (panel.__nxHideTimer) clearTimeout(panel.__nxHideTimer);
    panel.__nxHideTimer = setTimeout(function () { hidePanel(panel); }, CLOSE_FADE_MS);
  }
  function markBtn(btn, open) {
    btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    var g = btn.closest('.group');
    if (g) { if (open) g.setAttribute('data-open', ''); else g.removeAttribute('data-open'); }
  }
  function closeAll(root) {
    $$('[data-state="open"]', root).forEach(closePanel);
    $$('[aria-expanded="true"]', root).forEach(function (b) {
      // Kendi durumunu yerel denetleyicisiyle tutan kontroller (filtre paneli)
      // bu genel süpürmenin dışındadır: bkz. NEXUS_STATE_OWNED §0d.
      if (window.NEXUS_STATE_OWNED(b)) return;
      markBtn(b, false);
    });
  }

  /* Mobil alt bar (bnav) "Menü" düğmesinin açık/kapalı göstergesi.
     Çekmece hem bu kapsamdan (kapatma yolları) hem de iç IIFE'deki
     openMenu()'den yönetildiği için senkron burada tek yerde tutulur. */
  function syncBnavMenu(open) {
    var btn = document.querySelector('.bnav-item[data-act="menu"]');
    if (!btn) return;
    btn.classList.toggle('is-active', open);
    if (open) btn.setAttribute('aria-current', 'page');
    else btn.removeAttribute('aria-current');
  }

  /* ============ 1. city tabs in "Featured places" — filter cards ============ */
  $$('button[role="tab"]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var list = btn.closest('[role="tablist"]');
      if (!list) return;
      $$('button[role="tab"]', list).forEach(function (b) {
        var sel = b === btn;
        b.setAttribute('aria-selected', sel ? 'true' : 'false');
        b.tabIndex = sel ? 0 : -1;
        b.setAttribute('data-state', sel ? 'selected' : '');
        if (sel) b.setAttribute('data-selected', ''); else b.removeAttribute('data-selected');
      });
      var section = btn.closest('section');
      if (!section) {
        // hero form'daki şehir sekmeleri section dışında: üst bölüm bazlı fallback
        var anyCards = document.querySelectorAll('div.grid > div[data-city]');
        if (anyCards.length) section = document.body;
      }
      if (!section) return;
      var city = btn.textContent.trim().toLowerCase().replace(/\s+/g, '-');
      var cards = $$('div.grid > div[data-city]', section);
      if (!cards.length) return;
      cards.forEach(function (card) {
        var show = !city || city === 'all' || (card.getAttribute('data-city') || '').indexOf(city) !== -1;
        card.style.display = show ? '' : 'none';
      });
    });
  });

  /* ============ 1b. tablist ok tuşu gezinmesi (roving tabindex) ============
   * Hero sekme listesi (Oteller / Araçlar / Deneyimler …) şablonda
   * `<a role="tab">` öğeleridir ve roving tabindex zaten BASILI gelir:
   * seçili sekme `tabindex="0"`, diğerleri `tabindex="-1"`.
   *
   * Eksik olan klavye yolu buydu: `-1` olan sekmelere Tab ile girilemediği
   * ve ok tuşları bağlı olmadığı için **sekmelerin çoğuna klavyeyle hiç
   * odaklanamıyordu**. APG "tabs" deseni: ok tuşları odağı VE `tabindex`i
   * taşır (roving), Home/End uçlara atlar, listeden Tab ile çıkılır.
   *
   * İki sekme türü ayrı ele alınır:
   *   • `<a role="tab">` (hero/nav sekmeleri): ok tuşu yalnız odak taşır —
   *     seçim Enter/click'e (yani gerçek gezinmeye) bırakılır, aksi hâlde ok
   *     tuşuyla sayfa değişirdi.
   *   • `<button role="tab">` (şehir sekmeleri, dil/para sekmeleri): odakla
   *     birlikte seçilir (otomatik aktivasyon) ve tıklama davranışı tek
   *     sahiplidir — seçim mantığını kopyalamak yerine `click()` çağrılır.
   *
   * Dikey listelerde (`aria-orientation="vertical"`) ok yönleri de dikeydir;
   * RTL belgede ileri yön sol oktur (`getComputedStyle().direction`).
   */
  function tablistTabs(list) {
    return $$('[role="tab"]', list).filter(function (tab) {
      return tab.closest('[role="tablist"]') === list;
    });
  }
  function setRovingTabindex(tabs, active) {
    tabs.forEach(function (tab) { tab.tabIndex = tab === active ? 0 : -1; });
  }
  function activeTabIndex(tabs) {
    var focused = tabs.indexOf(document.activeElement);
    if (focused !== -1) return focused;
    var selected = tabs.findIndex(function (t) { return t.tabIndex === 0; });
    return selected === -1 ? 0 : selected;
  }
  $$('[role="tablist"]').forEach(function (list) {
    // Tek bağlama: dil değişiminde paneller yeniden basılsa da dinleyici
    // liste düğümünde kaldığı için çoğalmaz.
    if (list.__nxRovingBound) return;
    list.__nxRovingBound = true;

    // Başlangıçta liste içinde TEK tabbable sekme kalsın (markup eksik
    // bırakmışsa -ör. hepsi tabindex="0"- ilk sekmeye düşülür).
    var tabs = tablistTabs(list);
    if (tabs.length) {
      var selected = tabs.find(function (t) {
        return t.getAttribute('aria-selected') === 'true';
      });
      setRovingTabindex(tabs, selected || tabs[0]);
    }

    list.addEventListener('keydown', function (e) {
      var tabs = tablistTabs(list);
      if (tabs.length < 2) return;
      var vertical = list.getAttribute('aria-orientation') === 'vertical';
      var rtl = false;
      try { rtl = getComputedStyle(list).direction === 'rtl'; } catch (err) { rtl = false; }
      var forward = vertical ? 'ArrowDown' : (rtl ? 'ArrowLeft' : 'ArrowRight');
      var backward = vertical ? 'ArrowUp' : (rtl ? 'ArrowRight' : 'ArrowLeft');
      var i = activeTabIndex(tabs);
      var next = null;
      if (e.key === forward) next = tabs[(i + 1) % tabs.length];
      else if (e.key === backward) next = tabs[(i - 1 + tabs.length) % tabs.length];
      else if (e.key === 'Home') next = tabs[0];
      else if (e.key === 'End') next = tabs[tabs.length - 1];
      if (!next) return;
      e.preventDefault();
      setRovingTabindex(tabs, next);
      next.focus();
      // Düğme sekmeleri odakla birlikte seçilir; bağlantı sekmeleri Enter'ı
      // bekler (ok tuşuyla sayfa değişmemeli).
      if (next.tagName === 'BUTTON') next.click();
    });
  });

  /* ============ 2. search-form popovers (location / dates / guests) ============ */
  $$('button[aria-expanded][aria-controls]').forEach(function (btn) {
    /* Filtre panelinin KENDİ denetleyicisi var (public-listings.js: `is-open`
       sınıfı + maxHeight animasyonu). Burada da bağlanırsa aynı düğmeyi iki
       denetleyici yönetir ve sıra şu ölü sonucu verir: bu bağlayıcı önce
       aria-expanded'ı 'true' yapar, hemen ardından filtre denetleyicisi
       düğmeyi "açık" okuyup kapatır → düğme hiçbir şey yapmaz. Tek sahip
       kalsın diye filtre paneli bu bağlayıcıdan dışlanır. */      if (window.NEXUS_STATE_OWNED(btn)) return;
    var panel = document.getElementById(btn.getAttribute('aria-controls'));
    if (!panel) return;
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      var isOpen = btn.getAttribute('aria-expanded') === 'true';
      var form = btn.closest('form');
      if (form) closeAll(form);
      if (!isOpen) { openPanel(panel); markBtn(btn, true); }
    });
    panel.addEventListener('click', function (e) { e.stopPropagation(); });
  });

  /* ============ 3. location dropdown — pick a city ============ */
  // konum paneli aria-controls ile bağlı değil: paneli bul, formun ilk .group alanındaki
  // butona (form > div.group > div > button) bağla
  $$('.hidden-scrollbar.max-h-96').forEach(function (panel) {
    var form = panel.closest('form');
    if (!form) return;
    var field = form.querySelector(':scope > div.group');
    var trigger = field ? (field.querySelector('button') || field.firstElementChild) : null;
    if (!trigger) return;
    trigger.addEventListener('click', function (e) {
      e.stopPropagation();
      var isOpen = panel.getAttribute('data-state') === 'open';
      closeAll(form);
      if (!isOpen) { openPanel(panel); markBtn(trigger, true); }
    });
  });
  $$('.hidden-scrollbar [class*="items-center gap-3"]').forEach(function (row) {
    row.addEventListener('click', function () {
      var nameEl = $('.block.font-semibold', row) || $('span.font-medium', row) || $('span', row);
      if (!nameEl) return;
      var field = row.closest('.group');
      if (!field) return;
      var input = $('input', field);
      var label = $('.block.font-semibold', field.firstElementChild) || $('.block.font-semibold', field);
      if (input) input.value = nameEl.textContent.trim();
      if (label) label.textContent = nameEl.textContent.trim();
      var form = row.closest('form');
      if (form) closeAll(form);
    });
  });

  /* ============ 3b. date pickers — pick days, update field label ============ */
  $$('.datepicker').forEach(function (picker) {
    var ctrl = picker.closest('[id*="popover-panel"]');
    var trigger = null;
    if (ctrl) {
      var opener = document.querySelector('[aria-controls="' + ctrl.id + '"]');
      if (opener) trigger = opener;
    }
    if (!trigger) return;
    var label = trigger.querySelector('.block.font-semibold');
    var start = null, end = null;
    function fmt(d) {
      return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }
    function updateLabel() {
      if (!label || !start) return;
      var txt = fmt(start);
      if (end) txt += ' - ' + fmt(end);
      label.textContent = txt;
    }
    var MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    function parseDay(dayEl) {
      var al = dayEl.getAttribute('aria-label') || '';
      var m = al.match(/(?:Choose|Not available)\s+\w+,\s+([A-Za-z]+)\s+(\d{1,2})\w{2},\s*(\d{4})/);
      if (!m) return null;
      var mi = MONTHS.indexOf(m[1]);
      if (mi === -1) return null;
      return new Date(+m[3], mi, +m[2]);
    }
    function sameDay(a, b) { return a && b && a.getTime() === b.getTime(); }
    function paint() {
      $$('.datepicker__day', picker).forEach(function (el) {
        var d = parseDay(el);
        if (!d) return;
        el.classList.remove('datepicker__day--selected', 'datepicker__day--in-range', 'datepicker__day--range-start', 'datepicker__day--range-end');
        if (sameDay(d, start)) el.classList.add('datepicker__day--selected', 'datepicker__day--range-start');
        else if (sameDay(d, end)) el.classList.add('datepicker__day--selected', 'datepicker__day--range-end');
        else if (start && end && d > start && d < end) el.classList.add('datepicker__day--in-range');
      });
    }
    picker.addEventListener('click', function (e) {
      var day = e.target.closest('.datepicker__day');
      if (!day || day.classList.contains('datepicker__day--disabled') || day.classList.contains('datepicker__day--outside-month')) return;
      var d = parseDay(day);
      if (!d) return;
      if (!start || (start && end)) { start = d; end = null; }
      else if (d < start) { start = d; }
      else { end = d; }
      paint(); updateLabel();
    });
  });

  /* ============ 4. guests steppers (Adults / Children / Infants) ============
   * Misafir sayacı ARAMA BÖLÜMÜNDE yaşar: hero arama formundaki guests alanı
   * (buton + panel) ve detay sayfasının rezervasyon paneli (orası
   * `public-guests.js` ile bağlanır). Header popover'ı kaldırıldı — aynı
   * sayı iki yerde tutulamaz.
   *
   * Özet etiketi (`4 Guests`) dil sözlüğünden basılır; ayrıca toplam,
   * arama formunun `input[name="guests"]` alanına yazılır (native GET ve
   * §13 URL kurucusu bunu okur → seçim arama URL'sine `guests=` olarak gider).
   */
  var guestRefreshers = [];
  function guestCountLabel(n) {
    return t('%s Guests').replace('%s', String(n));
  }
  // Sözlük şablonu + çevrilmiş satır etiketi: "Azalt: Yetişkin" /
  // "Decrease Adults". Satır etiketi `data-i18n` anahtarı İngilizce
  // referanstır (applyLang gövdeyi çevirir), aria adı da aynı kaynaktan
  // basılır — aksi hâlde düğmelerin erişilebilir adı hiç olmazdı.
  function guestNamed(template, labelKey) {
    return t(template).replace('%s', t(labelKey));
  }
  var GUEST_MAX = 16;
  $$('.flex.min-w-28').forEach(function (row) {
    var btns = $$(':scope > button', row);
    if (btns.length < 2) return;
    var minus = btns[0], plus = btns[1];
    var valueEl = $(':scope > span', row);
    var hidden = $(':scope > input[type="hidden"]', row);
    var count = parseInt(valueEl && valueEl.textContent, 10) || 0;
    // Satır kimliği gizli alan adından gelir (`guestAdults` …). Yetişkin
    // alt sınırı 1: 0 misafirle arama anlamsız (detay panelindeki
    // `public-guests.js` de aynı sınırı uygular).
    var key = hidden && hidden.name ? hidden.name.replace(/^guest/, '').toLowerCase() : '';
    var min = key === 'adults' ? 1 : 0;
    var panel = row.closest('[id*="popover-panel"]');
    var group = panel ? (panel.closest('.group') || panel) : null;
    var labelEl = $('label', row);
    var labelKey = labelEl ? (labelEl.getAttribute('data-i18n') || labelEl.textContent.trim()) : '';
    function summary() {
      if (!group) return;
      var label = $('.grow .block.font-semibold', group) || $('.grow span', group);
      if (!label) return;
      var total = 0;
      $$('.flex.min-w-28', group).forEach(function (r) {
        var v = $(':scope > span', r);
        total += parseInt(v && v.textContent, 10) || 0;
      });
      label.textContent = guestCountLabel(total);
      var form = row.closest('form');
      var totalInput = form && form.querySelector('input[name="guests"]');
      if (totalInput) totalInput.value = String(total);
    }
    // Sınıra gelince düğme hem davranışsal (`disabled`) hem görsel
    // (`data-disabled` → şablonun `data-disabled:opacity-50` kuralı) kapanır;
    // sessiz no-op yerine bakılabilir bir sınır gösterilir.
    function bound(btn, atBound) {
      btn.disabled = atBound;
      if (atBound) btn.setAttribute('data-disabled', '');
      else btn.setAttribute('data-disabled', 'false');
    }
    function sync() {
      if (valueEl) valueEl.textContent = String(count);
      if (hidden) hidden.value = String(count);
      bound(minus, count <= min);
      bound(plus, count >= GUEST_MAX);
      if (labelKey) {
        minus.setAttribute('aria-label', guestNamed('Decrease %s', labelKey));
        plus.setAttribute('aria-label', guestNamed('Increase %s', labelKey));
      }
      summary();
    }
    minus.addEventListener('click', function () {
      if (count <= min) return;
      count--;
      sync();
    });
    plus.addEventListener('click', function () {
      if (count >= GUEST_MAX) return;
      count++;
      sync();
    });
    sync();
    guestRefreshers.push(sync);
  });
  // Dil değişiminde özet etiketi ve aria adları eski dilde kalmasın (JS ile
  // basılırlar, `data-i18n` geçişi onları göremez).
  document.addEventListener('nexus:lang', function () {
    guestRefreshers.forEach(function (sync) { sync(); });
  });

  /* ============ 5. card gallery sliders (dots + arrows) ============ */
  $$('div[class*="group/cardGallerySlider"]').forEach(function (slider) {
    var host = $('a > div', slider) || slider;
    var slides = $$(':scope > div > img', host);
    var dots = $$('.absolute.bottom-2 button', slider).length
      ? $$('.absolute.bottom-2 button', slider)
      : $$('button.h-1\\.5', slider);
    var arrows = $$(':scope > div[class*="opacity-0"] button', slider);
    if (slides.length < 2) return;
    var idx = 0;
    function show(i) {
      idx = (i + slides.length) % slides.length;
      slides.forEach(function (img, k) {
        var wrap = img.parentElement;
        if (wrap) wrap.style.opacity = k === idx ? '1' : '0';
      });
      dots.forEach(function (d, k) {
        d.className = k === idx ? 'h-1.5 w-1.5 rounded-full bg-white' : 'h-1.5 w-1.5 rounded-full bg-white/60';
      });
    }
    dots.forEach(function (d, k) { d.addEventListener('click', function () { show(k); }); });
    arrows.forEach(function (a) {
      a.addEventListener('click', function () {
        var isPrev = (a.closest('[class*="start-"]') && !a.closest('[class*="end-"]'));
        show(isPrev ? idx - 1 : idx + 1);
      });
    });
  });

  /* ============ 6. wishlist hearts ============ */
  $$('div.flex.cursor-pointer.items-center.justify-center.rounded-full').forEach(function (el) {
    if (!$('svg', el) || el.querySelector('input')) return;
    if (!/bg-black\/30|hover:bg-black\/50/.test(el.className)) return;
    el.addEventListener('click', function (e) {
      e.preventDefault();
      var svg = $('svg', el);
      var filled = svg.getAttribute('fill') === 'currentColor';
      svg.setAttribute('fill', filled ? 'none' : 'currentColor');
      svg.classList.toggle('text-red-500', !filled);
      el.classList.toggle('bg-white/90', !filled);
    });
  });

  /* ============ 7. flight / stay details disclosure ============ */
  $$('[id^="disclosure-button"]').forEach(function (btn) {
    var panelId = btn.id.replace('disclosure-button', 'disclosure-panel');
    var panel = document.getElementById(panelId);
    if (!panel) return;
    btn.addEventListener('click', function () {
      var open = btn.getAttribute('aria-expanded') === 'true';
      if (open) { closePanel(panel); } else { openPanel(panel); }
      btn.setAttribute('aria-expanded', open ? 'false' : 'true');
    });
  });

  /* ============ 8. filter "Clear" buttons ============ */
  $$('button').forEach(function (b) {
    if (b.textContent.trim() !== 'Clear') return;
    var form = b.closest('form');
    if (!form) return;
    b.addEventListener('click', function () {
      $$('input[type="checkbox"]', form).forEach(function (c) { c.checked = false; });
      $$('input[type="radio"]', form).forEach(function (r, i) { r.checked = i === 0; });
    });
  });

  /* ============ 9. demo submit handlers (search / newsletter / reserve) ============ */
  $$('form').forEach(function (f) {
    // NEXUS: gerçek backend hedefi olan formları (action=...) kesme
    var action = (f.getAttribute('action') || '').trim();
    if (action && action !== '#') return;
    f.addEventListener('submit', function (e) {
      e.preventDefault();
      var btn = $('button[type="submit"]', f);
      if (btn && !btn.dataset.done) {
        btn.dataset.done = '1';
        var old = btn.textContent;
        btn.textContent = '✓';
        setTimeout(function () { btn.textContent = old; delete btn.dataset.done; }, 1200);
      }
    });
  });

  /* ============ 10. mobile menu (hamburger) ============ */
  /*
   * Tetikleyici seçimi ÜÇ yedekli ve metne bağımlılığı kaldırılmıştır.
   *
   * Eski sürüm yalnız `button .sr-only` içindeki İngilizce "Open main menu"
   * yazısına bakıyordu. Sunucudan basılan başlık hamburgeri ise etiketini
   * SAYFA DİLİNDE taşır (TR "Ana menüyü aç", DE "Hauptmenü öffnen", …),
   * yani İngilizce dışındaki her dilde eşleşme kaçıyor ve çekmece hiç
   * KURULMUYORDU: basılabilir görünen düğme hiçbir şey açmıyordu.
   *
   * Sıra: (1) şablonun İngilizce etiketli hamburgeri (uyumluluk),
   * (2) SUNUCUDAN basılan hamburger — etiket yerine YAPISAL iz (menü ikonu),
   * (3) alt barın "Menü" düğmesi. Hepsi aynı çekmeceyi açar (`set(true)`).
   */
  (function () {
    var burger = null;
    $$('button .sr-only').some(function (sp) {
      if (/open main menu/i.test(sp.textContent)) { burger = sp.closest('button'); return true; }
      return false;
    });
    if (!burger) {
      // Yapısal iz: `hgi-menu-01` ikonunu taşıyan başlık düğmesi. Etiket
      // diline bakılmaz (sunucu onu çevirir).
      var menuIcon = $('header .hgi-menu-01') || $('.hgi-menu-01');
      if (menuIcon) burger = menuIcon.closest('button');
    }
    if (!burger) burger = $('.bnav-item[data-act="menu"]');
    if (!burger) burger = $('button[aria-label="Open menu"]');
    if (!burger) return;
    var menu = document.createElement('div');
    menu.className = 'mobile-menu';
    menu.setAttribute('data-state', 'closed');

    // logo: masaüstü header'dan klonla (açık/koyu varyant korunur)
    var logoHTML = '';
    var dhEl = document.querySelector('.relative.z-20.hidden');
    // NEXUS: sunucu tarafından render edilen sayfalarda href farklıdır —
    // data-mm-logo taşıyan ilk linki (veya header'daki ilk linki) kullan
    var logoLink = dhEl ? (dhEl.querySelector('a[data-mm-logo]') || dhEl.querySelector('a[href="index.html"]') || dhEl.querySelector('a')) : null;
    if (logoLink) {
      var lg = logoLink.cloneNode(true);
      lg.classList.add('mm-logo');
      lg.classList.remove('w-22', 'sm:w-24');
      logoHTML = lg.outerHTML;
    } else {
      // Yedek logo bağlantısı da gerçek rotaya gitmeli (şablon kalıntısı
      // "index.html" bu uygulamada 404 verir).
      logoHTML = '<a class="mobile-menu__brand" href="/">chisfis</a>';
    }

    var svg = function (paths, cls) {
      return '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"' + (cls ? ' class="' + cls + '"' : '') + ' aria-hidden="true">' + paths + '</svg>';
    };
    var P = {
      close: '<path d="M18 6L6.00081 17.9992M17.9992 18L6 6.00085" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
      phone: '<path d="M4.91186 10.5413L7.55229 7.90088C8.09091 7.36227 8.27728 6.56642 8.05944 5.83652C7.8891 5.26577 7.69718 4.57964 7.56961 3.99292C7.45162 3.45027 6.97545 3 6.42012 3H4.91186C3.8012 3 2.88911 3.90384 3.01094 5.0078C3.93709 13.3996 10.6004 20.0629 18.9922 20.9891C20.0962 21.1109 21 20.1988 21 19.0881V17.5799C21 17.0246 20.5479 16.569 20.0015 16.4696C19.3988 16.36 18.7611 16.1804 18.2276 16.0103C17.4611 15.7659 16.6091 15.9377 16.0403 16.5065L13.4587 19.0881" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
      wa: '<path d="M12 22C17.5228 22 22 17.5228 22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 13.3789 2.27907 14.6926 2.78382 15.8877C3.06278 16.5481 3.20226 16.8784 3.21953 17.128C3.2368 17.3776 3.16334 17.6521 3.01642 18.2012L2 22L5.79877 20.9836C6.34788 20.8367 6.62244 20.7632 6.87202 20.7805C7.12161 20.7977 7.45185 20.9372 8.11235 21.2162C9.30745 21.7209 10.6211 22 12 22Z" stroke="currentColor" stroke-linejoin="round" stroke-width="1.5"/><path d="M8.58815 12.3773L9.45909 11.2956C9.82616 10.8397 10.2799 10.4153 10.3155 9.80826C10.3244 9.65494 10.2166 8.96657 10.0008 7.58986C9.91601 7.04881 9.41086 7 8.97332 7C8.40314 7 8.11805 7 7.83495 7.12931C7.47714 7.29275 7.10979 7.75231 7.02917 8.13733C6.96539 8.44196 7.01279 8.65187 7.10759 9.07169C7.51023 10.8548 8.45481 12.6158 9.91948 14.0805C11.3842 15.5452 13.1452 16.4898 14.9283 16.8924C15.3481 16.9872 15.558 17.0346 15.8627 16.9708C16.2477 16.8902 16.7072 16.5229 16.8707 16.165C17 15.8819 17 15.5969 17 15.0267C17 14.5891 16.9512 14.084 16.4101 13.9992C15.0334 13.7834 14.3451 13.6756 14.1917 13.6845C13.5847 13.7201 13.1603 14.1738 12.7044 14.5409L11.6227 15.4118" stroke="currentColor" stroke-width="1.5"/>',
      globe: '<path d="M22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22C17.5228 22 22 17.5228 22 12Z" stroke="currentColor" stroke-width="1.5"/><path d="M20 5.69899C19.0653 5.76636 17.8681 6.12824 17.0379 7.20277C15.5385 9.14361 14.039 9.30556 13.0394 8.65861C11.5399 7.6882 12.8 6.11636 11.0401 5.26215C9.89313 4.70542 9.73321 3.19045 10.3716 2" stroke="currentColor" stroke-linejoin="round" stroke-width="1.5"/><path d="M2 11C2.7625 11.6621 3.83046 12.2682 5.08874 12.2682C7.68843 12.2682 8.20837 12.7649 8.20837 14.7518C8.20837 16.7387 8.20837 16.7387 8.72831 18.2288C9.06651 19.1981 9.18472 20.1674 8.5106 21" stroke="currentColor" stroke-linejoin="round" stroke-width="1.5"/><path d="M22 13.4523C21.1129 12.9411 20 12.7308 18.8734 13.5405C16.7177 15.0898 15.2314 13.806 14.5619 15.0889C13.5765 16.9775 17.0957 17.5711 14 22" stroke="currentColor" stroke-linejoin="round" stroke-width="1.5"/>',
      code: '<path d="M17 8L18.8398 9.85008C19.6133 10.6279 20 11.0168 20 11.5C20 11.9832 19.6133 12.3721 18.8398 13.1499L17 15" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M7 8L5.16019 9.85008C4.38673 10.6279 4 11.0168 4 11.5C4 11.9832 4.38673 12.3721 5.16019 13.1499L7 15" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M14.5 4L9.5 20" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
      chev: '<path d="M18 9.00005C18 9.00005 13.5811 15 12 15C10.4188 15 6 9 6 9" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
      bell: '<path d="M15.5 18C15.5 19.933 13.933 21.5 12 21.5C10.067 21.5 8.5 19.933 8.5 18" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M19.2311 18H4.76887C3.79195 18 3 17.208 3 16.2311C3 15.762 3.18636 15.3121 3.51809 14.9803L4.12132 14.3771C4.68393 13.8145 5 13.0514 5 12.2558V9.5C5 5.63401 8.13401 2.5 12 2.5C15.866 2.5 19 5.634 19 9.5V12.2558C19 13.0514 19.3161 13.8145 19.8787 14.3771L20.4819 14.9803C20.8136 15.3121 21 15.762 21 16.2311C21 17.208 20.208 18 19.2311 18Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
      user: '<path d="M20 21.0001C19.713 17.269 16.7289 14.3151 12.995 14.0662L12 13.9999C11.6446 14.0096 11.3134 14.0225 11.0008 14.0378C7.3 14.2192 4.28417 17.3057 4 21.0001" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><circle cx="12" cy="6.99988" r="4" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
      search: '<path d="M17 17L21 21" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M19 11C19 6.58172 15.4183 3 11 3C6.58172 3 3 6.58172 3 11C3 15.4183 6.58172 19 11 19C15.4183 19 19 15.4183 19 11Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
      building: '<path d="M11 2V14C11 17.3093 10.3093 18 7 18H3" stroke="currentColor" stroke-linejoin="round" stroke-width="1.5"/><path d="M5 12L11 12" stroke="currentColor" stroke-linejoin="round" stroke-width="1.5"/><path d="M17.5 16L18.5 16M17.5 19L18.5 19" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M14 5V22H4.279C3.03789 22 2.41734 22 2.13134 21.5746C1.84534 21.1492 2.05611 20.5397 2.47764 19.3207L7.78212 3.98107C8.11324 3.0235 8.27881 2.54472 8.65029 2.27236C9.02177 2 9.50923 2 10.4842 2H11.1272C12.4814 2 13.1586 2 13.5793 2.43934C14 2.87868 14 3.58579 14 5Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M14 10L17.7897 11.1843C19.8193 11.8185 20.8341 12.1357 21.4171 12.9286C22 13.7215 22 14.7847 22 16.9111V20C22 20.9428 22 21.4142 21.7071 21.7071C21.4142 22 20.9428 22 20 22H14" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
      bulb: '<path d="M8 16.4998C6.7725 15.4011 6 13.7768 6 11.9998C6 8.68605 8.68629 5.99976 12 5.99976C15.3137 5.99976 18 8.68605 18 11.9998C18 13.7768 17.2275 15.4011 16 16.4998" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"/><path d="M12 11.9998V16.4998" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M9.5 18.9998H14.5" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M10.5 21.4998H13.5" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M3.5 11.9998H2.5M5.98438 5.97632L5.23438 5.23022M18.0195 5.97632L18.7695 5.23022M21.5 11.9998H20.5M12 2.49976V3.49976" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
      car: '<path d="M2.5 12L4.5 13" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M21.5 12.5L19.5 13" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M8 17.5L8.24567 16.8858C8.61101 15.9725 8.79368 15.5158 9.17461 15.2579C9.55553 15 10.0474 15 11.0311 15H12.9689C13.9526 15 14.4445 15 14.8254 15.2579C15.2063 15.5158 15.389 15.9725 15.7543 16.8858L16 17.5" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M2 17V19.882C2 20.2607 2.24075 20.607 2.62188 20.7764C2.86918 20.8863 3.10538 21 3.39058 21H5.10942C5.39462 21 5.63082 20.8863 5.87812 20.7764C6.25925 20.607 6.5 20.2607 6.5 19.882V18" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M17.5 18V19.882C17.5 20.2607 17.7408 20.607 18.1219 20.7764C18.3692 20.8863 18.6054 21 18.8906 21H20.6094C20.8946 21 21.1308 20.8863 21.3781 20.7764C21.7592 20.607 22 20.2607 22 19.882V17" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M20 8.5L21 8" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M4 8.5L3 8" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M4.5 9L5.5883 5.73509C6.02832 4.41505 6.24832 3.75503 6.7721 3.37752C7.29587 3 7.99159 3 9.38304 3H14.617C16.0084 3 16.7041 3 17.2279 3.37752C17.7517 3.75503 17.9717 4.41505 18.4117 5.73509L19.5 9" stroke="currentColor" stroke-linejoin="round" stroke-width="1.5"/><path d="M4.5 9H19.5C20.4572 10.0135 22 11.4249 22 12.9996V16.4702C22 17.0407 21.6205 17.5208 21.1168 17.5875L18 18H6L2.88316 17.5875C2.37955 17.5208 2 17.0407 2 16.4702V12.9996C2 11.4249 3.54279 10.0135 4.5 9Z" stroke="currentColor" stroke-linejoin="round" stroke-width="1.5"/>',
      plane: '<path d="M4.41712 11.9183L7.73859 9.89656C8.29597 9.55783 8.57467 9.38846 8.76705 9.15616C9.59962 8.15082 8.86644 6.66595 8.99059 5.49686C9.1191 4.28671 10.2731 2.63158 11.4364 2.11845C11.7944 1.96052 12.2051 1.96052 12.5631 2.11845C13.7264 2.63158 14.8804 4.28671 15.0089 5.49686C15.1331 6.66595 14.3999 8.15082 15.2325 9.15616C15.4248 9.38846 15.7035 9.55783 16.2609 9.89656L19.5827 11.9182C20.5993 12.5369 20.9998 13.1973 20.9998 14.4395C20.9998 15.1156 20.7006 15.2968 20.0973 15.1588L14.2725 13.8261L14.0109 16.1149C13.9161 16.9448 13.8687 17.3598 14.0058 17.7398C14.327 18.63 15.4173 19.3591 16.0832 20.0066C16.4513 20.3644 16.8529 21.3934 16.4333 21.8613C16.1742 22.1503 15.7533 21.9157 15.4637 21.803L12.675 20.7184C12.3416 20.5887 12.1748 20.5239 11.9998 20.5239C11.8247 20.5239 11.6579 20.5887 11.3245 20.7184L8.53584 21.803C8.24619 21.9157 7.82534 22.1503 7.56625 21.8613C7.1466 21.3934 7.54825 20.3644 7.91628 20.0066C8.5822 19.3591 9.67255 18.63 9.9937 17.7398C10.1308 17.3598 10.0834 16.9448 9.98857 16.1149L9.72703 13.8261L3.90259 15.1587C3.29902 15.2968 2.99982 15.1155 3.00001 14.4391C3.00034 13.1971 3.4007 12.537 4.41712 11.9183Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>',
      arrow: '<path d="M9.00005 6C9.00005 6 15 10.4189 15 12C15 13.5812 9 18 9 18" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/>'
    };;

    // Aktif kategori tespiti §0c'deki ortak predicate'ten gelir.
    //
    // Çekmece linkleri `/kategori/<slug>` yolunu kullanır; liste sayfası ise
    // `?kategori=<slug>` filtresini taşır — ikisi de aynı slug'dır, bu yüzden
    // eşleşme hem yolu hem sorguyu kapsar ve liste sayfasındayken ilgili
    // kategori vurgulanıp accordion varsayılan olarak açık başlar. Masaüstü
    // header menüsü (§ header-popovers.js) AYNI fonksiyonu çağırır.
    var hrefActive = window.NEXUS_NAV.isActiveHref;
    var accHTML = function (iconKey, labelKey, open, items) {
      var anyActive = items.some(function (it) { return hrefActive(it[0]); });
      var body = items.map(function (it) {
        var active = hrefActive(it[0]);
        return '<a href="' + it[0] + '"' + (active ? ' aria-current="page" class="mm-acc-link-active"' : '') + '><span data-i18n="' + it[1] + '">' + it[1] + '</span>' + svg(P.arrow) + '</a>';
      }).join('');
      var isOpen = open || anyActive;
      return '<div class="mm-acc"' + (isOpen ? ' data-open="1"' : '') + '>' +
        '<button type="button" class="mm-acc-head">' +
        '<span class="mm-acc-ico">' + svg(P[iconKey]) + '</span>' +
        '<span data-i18n="' + labelKey + '">' + labelKey + '</span>' +
        '<span class="mm-acc-chev">' + svg(P.chev) + '</span>' +
        '</button>' +
        '<div class="mm-acc-body"><div class="mm-acc-inner">' + body + '</div></div>' +
        '</div>';
    };
    var directHTML = function (iconKey, labelKey, href) {
      // Doğrudan link de liste filtresindeki slug'ıyla eşleşirse vurgulanır
      // (örn. /urunler?kategori=car → Araçlar); bu da ortak predicate'te.
      var active = hrefActive(href);
      return '<a class="mm-direct' + (active ? ' mm-acc-link-active' : '') + '" href="' + href + '"' +
        (active ? ' aria-current="page"' : '') + '>' +
        '<span class="mm-acc-ico">' + svg(P[iconKey]) + '</span>' +
        '<span data-i18n="' + labelKey + '">' + labelKey + '</span>' +
        svg(P.arrow, 'mm-dir-arrow') + '</a>';
    };

    menu.innerHTML =
      '<div class="mobile-menu__backdrop"></div>' +
      '<nav class="mobile-menu__panel">' +
      '<div class="mm-top">' + logoHTML +
      '<button type="button" class="mobile-menu__close" aria-label="Close menu">' + svg(P.close) + '</button>' +
      '</div>' +
      '<div class="mm-actions">' +
      '<a class="mm-ico mm-ico--wa" href="https://wa.me/' + WHATSAPP_NUMBER + '?text=' + encodeURIComponent(WHATSAPP_MESSAGE) + '" target="_blank" rel="noopener noreferrer" aria-label="WhatsApp">' + svg(P.wa) + '</a>' +
      '<span class="mm-flex"></span>' +
      '<button type="button" class="mm-pill" aria-label="Site settings">' + svg(P.globe) + '<span class="mm-sep"></span>' + svg(P.code) + svg(P.chev) + '</button>' +
      '<button type="button" class="mm-ico" aria-label="Notifications">' + svg(P.bell) + '<i class="mm-dot"></i></button>' +
      '<a class="mm-ico" href="/hesap" aria-label="Account">' + svg(P.user) + '</a>' +
      '</div>' +
      '<form class="mm-search" action="/urunler" method="get">' + svg(P.search) +
      '<input type="search" name="q" data-i18n-placeholder="Search city, hotel or region..." placeholder="Search city, hotel or region..." aria-label="Search" />' +
      '</form>' +
      '<p class="mm-cats-label" data-i18n="CATEGORIES">CATEGORIES</p>' +
      accHTML('building', 'Stays', true, [
        ['/kategori/hotel', 'Hotels'],
        ['/kategori/holiday_home', 'Holiday homes & villas'],
        ['/kategori/yacht', 'Yacht rental'],
      ]) +
      accHTML('bulb', 'Experiences', false, [
        ['/kategori/tour', 'Tours'],
        ['/kategori/activity', 'Activities'],
        ['/deneyimler', 'All experiences'],
        ['/yazarlar', 'Authors'],
      ]) +
      directHTML('car', 'Cars', '/arac') +
      directHTML('plane', 'Flights', '/ucus') +
      directHTML('bus', 'Bus', '/otobus') +
      '<div class="mm-foot">' +
      '<button type="button" id="theme-toggle" data-role="theme" class="mm-foot-btn" aria-label="Toggle dark mode"><span class="mm-foot-ico">🌙</span> <span>Dark mode</span></button>' +
      '<button type="button" class="lang-toggle mm-foot-btn" aria-label="Toggle language">' + (TOGGLE_LABEL[currentLang] || 'TR') + '</button>' +
      '</div>' +
      '</nav>';
    document.body.appendChild(menu);

    /* --- Kapanış animasyonu (slide-out + fade) --------------------------
       Şablon çekmeceyi kapanışta anında `display: none` yapıyordu; artık
       `mm-closing` sınıfıyla MM_CLOSE_MS boyunca görünür kalır ve sağa
       kayarak söner (custom.css). `data-state` ANINDA `closed` olur: bnav
       göstergesi ve "açık mı?" mantığı beklemez, hızlı aç/kapa yarışı
       oluşmaz. MM_CLOSE_MS, CSS'teki `.28s` süresiyle eşleşmek zorundadır.
       Hareket azaltma tercihinde animasyon yok — çekmece anında kapanır. */
    var MM_CLOSE_MS = 280;
    function mmReducedMotion() {
      return !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
    }
    function mmFinishClose() {
      if (menu.__mmCloseTimer) { clearTimeout(menu.__mmCloseTimer); menu.__mmCloseTimer = null; }
      menu.classList.remove('mm-closing');
      menu.setAttribute('data-state', 'closed');
      // Sayfa kaydırması sönme bitene kadar kilitli kalır; aksi halde arkadaki
      // sayfa panel kayarken oynardı.
      document.documentElement.classList.remove('overflow-hidden');
    }
    function set(open) {
      // Sönme sürerken yeniden açılırsa bekleyen gizleme iptal edilir.
      if (menu.__mmCloseTimer) { clearTimeout(menu.__mmCloseTimer); menu.__mmCloseTimer = null; }
      menu.classList.remove('mm-closing');
      if (open) {
        menu.setAttribute('data-state', 'open');
      } else if (menu.getAttribute('data-state') !== 'open') {
        return; // zaten kapalı — tekrar tetiklemeye gerek yok
      } else if (mmReducedMotion()) {
        mmFinishClose();
      } else {
        menu.setAttribute('data-state', 'closed');
        menu.classList.add('mm-closing');
        menu.__mmCloseTimer = setTimeout(mmFinishClose, MM_CLOSE_MS);
      }
      if (open) document.documentElement.classList.add('overflow-hidden');
      // Mobil alt bardaki Menü düğmesi çekmece açıkken aktif görünür.
      syncBnavMenu(open);
    }
    burger.addEventListener('click', function (e) { e.stopPropagation(); set(true); });
    // Also bind the mobile bottom-bar 'Menu' button
    var bottomMenuBtn = document.querySelector('[aria-label="Open menu"]');
    if (bottomMenuBtn && bottomMenuBtn !== burger) {
      bottomMenuBtn.addEventListener('click', function (e) { e.stopPropagation(); set(true); });
    }
    $('.mobile-menu__close', menu).addEventListener('click', function () { set(false); });
    $('.mobile-menu__backdrop', menu).addEventListener('click', function () { set(false); });
    $$('a', menu).forEach(function (a) { a.addEventListener('click', function () { set(false); }); });
    // accordion aç/kapa
    $$('.mm-acc-head', menu).forEach(function (h) {
      h.addEventListener('click', function () {
        var acc = h.parentNode;
        acc.setAttribute('data-open', acc.getAttribute('data-open') === '1' ? '0' : '1');
      });
    });

    /* ---- mm-pill alt popover: Dil / Para birimi ----
     * Veri kaynağı: window.NEXUS_LOCALE (desktop globe popover ile aynı).
     * Görünüm: sekmeli Language/Currency (mm-pop). */
    (function () {
      var pill = $('.mm-pill', menu);
      if (!pill) return;
      var L = window.NEXUS_LOCALE;
      var cur = L.currency;

      var pop = document.createElement('div');
      pop.className = 'mm-pop';
      pop.hidden = true;
      pop.setAttribute('role', 'menu');
      // Sekme etiketleri t() ile basılır; applyLang sonrası renderAll() tazeler.
      pop.innerHTML =
        '<div class="mm-pop__tabs" role="tablist">' +
        '<button type="button" class="mm-pop__tab" role="tab" data-tab="lang" data-selected="" aria-selected="true"><span>' + t('Language') + '</span></button>' +
        '<button type="button" class="mm-pop__tab" role="tab" data-tab="cur" aria-selected="false"><span>' + t('Currency') + '</span></button>' +
        '</div>' +
        '<div class="mm-pop__grid" data-pane="lang"></div>' +
        '<div class="mm-pop__grid" data-pane="cur" hidden></div>';
      pill.parentElement.appendChild(pop);

      function optHTML(kind, val, main, sub) {
        var sel = (kind === 'lang' ? L.lang : cur) === val;
        return '<button type="button" class="mm-pop__opt" role="menuitemradio" aria-checked="' + sel + '" data-kind="' + kind + '" data-val="' + val + '">' +
          '<span class="mm-pop__opt-main">' + main + '</span>' +
          (sub ? '<span class="mm-pop__opt-sub">' + sub + '</span>' : '') +
          '<i class="hgi-stroke hgi-tick-02 mm-pop__tick"></i>' +
          '</button>';
      }

      function renderPane(pane) {
        var kind = pane.getAttribute('data-pane');
        if (kind === 'lang') {
          pane.innerHTML = L.langs.map(function (l) { return optHTML('lang', l.code, l.main, l.sub); }).join('');
        } else {
          pane.innerHTML = L.currencies.map(function (c) { return optHTML('cur', c.code, c.symbol + ' ' + c.code, ''); }).join('');
        }
      }
      function renderAll() {
        $$('[data-pane]', pop).forEach(renderPane);
        // Sekme etiketlerini de mevcut dile göre tazele
        $$('.mm-pop__tab', pop).forEach(function (tb) {
          var span = tb.querySelector('span');
          var key = tb.getAttribute('data-tab') === 'lang' ? 'Language' : 'Currency';
          if (span) span.textContent = t(key);
        });
      }
      renderAll();

      function setTab(name) {
        $$('.mm-pop__tab', pop).forEach(function (tb) {
          var sel = tb.getAttribute('data-tab') === name;
          if (sel) tb.setAttribute('data-selected', ''); else tb.removeAttribute('data-selected');
          tb.setAttribute('aria-selected', sel ? 'true' : 'false');
        });
        $$('[data-pane]', pop).forEach(function (p) {
          p.hidden = p.getAttribute('data-pane') !== name;
        });
      }
      $$('.mm-pop__tab', pop).forEach(function (tb) {
        tb.addEventListener('click', function (e) { e.stopPropagation(); setTab(tb.getAttribute('data-tab')); });
      });

      // Seçim işareti tazele (dil değişince)
      function refreshChecks() { renderAll(); }
      document.addEventListener('click', function (e) {
        if (e.target.closest('.lang-toggle')) setTimeout(refreshChecks, 0);
      });
      // applyLang'tan gelen dil değişiminde sekme etiketlerini de tazele
      document.addEventListener('nexus:lang', function () { setTimeout(refreshChecks, 0); });

      // Açık mı? Sönmekte olan panel "kapalı" sayılır, böylece hızlı
      // tıklamada yeniden açılır (bekleyen gizleme iptal edilir).
      function isMmPopOpen() { return !pop.hidden && !pop.classList.contains('nx-closing'); }

      pill.addEventListener('click', function (e) {
        e.stopPropagation();
        var nowOpen = isMmPopOpen();
        if (nowOpen) { closePanel(pop); } else { openPanel(pop); }
        pill.setAttribute('aria-expanded', nowOpen ? 'false' : 'true');
      });

      pop.addEventListener('click', function (e) {
        var opt = e.target.closest('.mm-pop__opt');
        if (!opt) return;
        e.stopPropagation();
        var kind = opt.getAttribute('data-kind');
        var val = opt.getAttribute('data-val');
        // Dil de masaüstüyle aynı kanaldan: nexus:lang → applyLang + geri-al
        // bildirimi; refreshChecks nexus:lang dinleyicisiyle tazelenir
        if (kind === 'lang') { dispatchLang(val); refreshChecks(); }
        else { cur = val; L.applyCurrency(val); renderAll(); }
      });

      // Dış tık / menü kapanınca popover'ı kapat (aynı sönme ile)
      $('.mobile-menu__backdrop', menu).addEventListener('click', function () { closePanel(pop); });
      $('.mobile-menu__close', menu).addEventListener('click', function () { closePanel(pop); });
      document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape' && isMmPopOpen()) {
          closePanel(pop);
          pill.setAttribute('aria-expanded', 'false');
        }
      });
    })();

    // tema etiketini mevcut durumla senkronize et
    applyTheme(currentMode());
  })();

  /* ============ 11. sticky header shadow ============ */
  var desktopHeader = $('.relative.z-20.hidden');
  window.addEventListener('scroll', function () {
    if (!desktopHeader) return;
    desktopHeader.classList.toggle('shadow-sm', window.scrollY > 8);
  }, { passive: true });

  /* ============ 11b. scroll-reveal: kademeli giriş animasyonu ============
     Header (yapışkan satırlarıyla), hero (arama formu dahil) ve tüm ana sayfa
     bölümleri ilk boyamada / görünür olduklarında kademeli belirir.

     Tasarım notları:
       * Gizli durum yalnızca `html.has-reveal` varken uygulanır; bu sınıfı
         reveal-boot.js ilk boyamadan önce ekler. Sınıf yoksa bu blok hiç
         çalışmaz ve hiçbir şey gizlenmez (progressive enhancement).
       * İşaretleme CSS'te değil burada yapılır: bölüm sınıfları sayfa
         derleyicisinden (builder) geldiği için hedefler tek yerden seçilir.
       * Geçiş bittiğinde `data-reveal` kaldırılır; böylece kartların kendi
         hover geçişleri (lift/zoom) devralınan bir transition tarafından
         geciktirilmez ve eleman üzerinde kalıcı transform kalmaz. */
  (function () {
    var html = document.documentElement;
    var mq = window.matchMedia ? window.matchMedia('(prefers-reduced-motion: reduce)') : null;

    // Azaltılmış hareket: hiç gizleme. Boot script'i de sınıfı eklemez.
    if (mq && mq.matches) { html.classList.remove('has-reveal'); return; }
    // Boot script'i yoksa (ör. dosya yüklenemedi): gizleme de yok.
    if (!html.classList.contains('has-reveal')) return;

    var STEP = 0.06;      // kademe adımı (sn)
    var MAX_DELAY = 0.42; // bir bölümdeki en geç gecikme
    var targets = [];

    function mark(el, delay) {
      if (!el || el.nodeType !== 1 || el.hasAttribute('data-reveal')) return;
      // O an gizli dal (display:none): işaretleme yok. Aksi halde görünür
      // olduğunda animasyonsuz “asılı” kalma riski doğar.
      if (!el.getClientRects().length) return;
      // Kendi opaklığı 0 olan eleman (hover'da açılan katman/mercek) hiç
      // işaretlenmez: reveal onu bir an görünür yapardı.
      var own = parseFloat(getComputedStyle(el).opacity);
      if (!(own > 0)) return;
      el.setAttribute('data-reveal', '');
      // Yarı saydam hedef kendi değerine animasyonla ulaşır (CSS
      // `opacity: var(--reveal-op, 1)`); aksi halde animasyon sonunda parlaklık
      // sıçraması olurdu.
      if (own < 1) el.style.setProperty('--reveal-op', String(own));
      el.style.setProperty('--reveal-delay', Math.min(Math.max(delay, 0), MAX_DELAY).toFixed(2) + 's');
      targets.push(el);
    }

    // Izgara kabuğu mu? `*-grid` (adventure-grid, featured-grid…) — Tailwind'in
    // `inline-grid` / `grid` yardımcı sınıfları hariç.
    function isGrid(el) {
      return String(el.className || '').split(/\s+/).some(function (c) {
        return /-grid$/.test(c) && c !== 'inline-grid';
      });
    }

    // (a) Header: yapışkan satırlarıyla birlikte tepeden iner (kademenin başı).
    //     Rol, `--reveal-rise: -12px` ile diğerlerinden ayrılır (bridge CSS).
    mark($('header.chisfis-header-root'), 0);

    // (b) Hero: görsel katmanı → başlık/CTA bloğu → sekmeler → alanlar → buton
    mark($('main > div.absolute'), 0.06);
    mark($('main > div.container > div'), 0.12);
    var heroForm = $('.hero-search-form');
    if (heroForm) {
      mark($('[role="tablist"]', heroForm), 0.20);
      var fieldDelay = 0.26;
      $$('form > *', heroForm).forEach(function (el) {
        mark(el, fieldDelay);
        fieldDelay += STEP;
      });
    }

    // (c0) Sayfa başlık bloğu — mağaza sayfaları (`main`in doğrudan çocukları):
    //      eyebrow → kırıntı → h1 → lede sırayla belirir. Liste (`/urunler`,
    //      `/kategori/<slug>`) ve detay sayfalarında bu elemanlar `div`/`section`
    //      DEĞİL (`span.eyebrow`, `nav.listing-breadcrumb`, `h1`, `p`), bu yüzden
    //      (c) taraması onları hiç görmezdi: sayfa başlığı animasyonsuz açılırken
    //      altındaki filtre/araç çubuğu/ızgaralar kademeli giriyordu.
    //      `div`/`section` çocukları ATLANIR — onlar (c) kapsamında ve burada
    //      ayrıca işaretlenirse sarmalayıcı ile çocukları iç içe iki kez
    //      animasyon oynatırdı (sarmalayıcının transform'u alt ağacı taşır).
    var headingDelay = 0;
    $$('main > *').forEach(function (el) {
      if (el.tagName === 'DIV' || el.tagName === 'SECTION') return;
      if (el.tagName === 'SCRIPT' || el.tagName === 'STYLE' || el.tagName === 'TEMPLATE' || el.tagName === 'LINK') return;
      if (!el.getClientRects().length) return;
      mark(el, headingDelay);
      headingDelay += STEP;
    });

    // (c) Bölümler ve sayfa sonu blokları: başlık önce, kartlar kademeli.
    //     Izgara (`*-grid`) çocukları tek tek, diğer bloklar bütün olarak girer.
    // Bölümler bu düzende `body > section` (builder çıktısı), bazı düzenlerde
    // `main > section` olabilir; ikisi de kapsanır. Hero blokları (.container /
    // .absolute) ve çekmece (.mobile-menu) dışarıda bırakılır — çekmece
    // gizlenirse açıldığında görünmez kalırdı.
    var blocks = $$('body > section, main > section, main > div, body > div').filter(function (el) {
      if (el.classList.contains('container') || el.classList.contains('absolute')) return false;
      if (el.classList.contains('mobile-menu')) return false;
      if (el.getAttribute('aria-hidden') === 'true') return false;
      return true;
    });
    blocks.forEach(function (block) {
      var kids = $$(':scope > *', block).filter(function (el) {
        return el.getClientRects().length > 0; // display:none alt ağaçlar atlanır
      });
      if (!kids.length) { mark(block, 0); return; }
      var delay = 0;
      kids.forEach(function (el) {
        if (isGrid(el)) {
          $$(':scope > *', el).forEach(function (card) {
            mark(card, delay);
            delay += STEP;
          });
        } else {
          mark(el, delay);
          delay += STEP;
        }
      });
    });

    // (d) Gözlemci: her hedef görünür olduğunda bir kez oynar.
    if (!targets.length) {
      html.classList.remove('has-reveal');
      html.setAttribute('data-reveal-ready', '');
      return;
    }

    var pending = targets.slice();

    function settle(el) {
      el.classList.remove('is-revealed');
      el.removeAttribute('data-reveal');
      el.style.removeProperty('--reveal-delay');
      // Kendi opaklığı (varsa) yeniden geçerli olsun: eleman tasarım değerine döner
      el.style.removeProperty('--reveal-op');
    }

    function reveal(el) {
      var idx = pending.indexOf(el);
      if (idx !== -1) pending.splice(idx, 1);
      var done = false;
      function finish() {
        if (done) return;
        done = true;
        settle(el);
      }
      el.classList.add('is-revealed');
      el.addEventListener('transitionend', function (e) {
        if (e.target === el && e.propertyName === 'opacity') finish();
      });
      // Güvenlik: transitionend kaçarsa (ör. sekme arka planda) yine bitir.
      window.setTimeout(finish, 1600);
    }

    // Görüş alanına girmiş (veya üstüne geçilmiş) hedefleri açar. IO birincil
    // tetikleyicidir; bu tarama, IO geri çağrısı atlanırsa içeriğin gizli
    // kalmasını engelleyen ikinci kapıdır. `display:none` dallar atlanır
    // (görünür olduklarında IO zaten yakalar).
    function sweep() {
      if (!pending.length) return;
      var cutoff = (window.innerHeight || html.clientHeight) * 0.94;
      pending.slice().forEach(function (el) {
        if (!el.getClientRects().length) return; // gizli dal: animasyonsuz açılmasın
        if (el.getBoundingClientRect().top < cutoff) reveal(el);
      });
    }

    var rafId = 0;
    function scheduleSweep() {
      if (rafId) return;
      rafId = window.requestAnimationFrame(function () {
        rafId = 0;
        sweep();
      });
    }

    var io = ('IntersectionObserver' in window)
      ? new IntersectionObserver(function (entries, obs) {
          entries.forEach(function (entry) {
            if (!entry.isIntersecting) return;
            obs.unobserve(entry.target);
            reveal(entry.target);
          });
        }, { rootMargin: '0px 0px -6% 0px', threshold: 0.01 })
      : null;

    // KAPI: gizli başlangıç durumu gerçekten hesaplanmadan açarsak geçiş
    // (transition) oynamaz — eleman anında görünür. İlk hedefte opacity 0
    // görünene kadar (en fazla 60 kare) bekle, bir kare daha ver, sonra başla.
    function whenHidden(cb) {
      var probe = targets[0];
      var tries = 0;
      (function check() {
        var hidden = parseFloat(getComputedStyle(probe).opacity) === 0;
        if (hidden || ++tries > 60) { window.requestAnimationFrame(cb); return; }
        window.requestAnimationFrame(check);
      })();
    }

    whenHidden(function () {
      targets.forEach(function (el) {
        if (io) io.observe(el);
        else reveal(el); // IntersectionObserver yok: hemen göster
      });

      // Kaydırma boyunca ikinci kapı (capture: gövde kaydırıcı olsa da yakalar).
      window.addEventListener('scroll', scheduleSweep, { passive: true, capture: true });
      window.addEventListener('resize', scheduleSweep, { passive: true });
      window.addEventListener('load', scheduleSweep);
      document.addEventListener('visibilitychange', scheduleSweep);
      scheduleSweep();

      // Denetleyici devraldı: boot script'inin güvenlik ağı artık gereksiz.
      html.setAttribute('data-reveal-ready', '');
    });

    // Kullanıcı hareket azaltmayı açarsa gizlemeyi bırak.
    if (mq && mq.addEventListener) {
      mq.addEventListener('change', function () {
        if (mq.matches) html.classList.remove('has-reveal');
      });
    }
  })();

  /* ============ 12. outside click closes popovers ============ */
  document.addEventListener('click', function () {
    closeAll(document);
  });

  /* ============ 13. search form -> query string -> listing page ============ */
  // Hero form'daki arama butonuna tıklayınca query string oluştur ve listing'e yönlendir
  $$('form').forEach(function (form) {
    var submitBtn = form.querySelector('button[type="submit"]');
    if (!submitBtn) return;
    // Only handle search forms (forms with location/checkin inputs)
    var locationInput = form.querySelector('input[name="location"]');
    if (!locationInput) return;
    // NEXUS: form gerçek action'a POST/GET yapar — demo yönlendirme yok
    if ((form.getAttribute('action') || '').trim() && form.getAttribute('action') !== '#') return;
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      /* Mağaza URL'si kurulur (`/urunler`). Eski hedef `listing.html`
         şablonun demo sayfasıydı ve mağazada 404 veriyordu; parametre
         adları da şablonun İngilizce alanlarıydı (`location`, `checkin`),
         oysa liste sayfası mağaza adlarını okur (`konum`, `check_in`,
         `check_out`, `guests`). Mevcut sorgu (ör. `tenant`) korunur. */
      var params = new URLSearchParams(window.location.search);
      var loc = locationInput.value.trim();
      if (loc) params.set('konum', loc);
      var checkin = form.querySelector('input[name="checkin"]');
      var checkout = form.querySelector('input[name="checkout"]');
      if (checkin && checkin.value) params.set('check_in', checkin.value);
      if (checkout && checkout.value) params.set('check_out', checkout.value);
      // Toplamı sayaç zaten `input[name="guests"]` alanında tutuyor (§4).
      var totalInput = form.querySelector('input[name="guests"]');
      var totalGuests = totalInput ? parseInt(totalInput.value, 10) || 0 : 0;
      if (!totalGuests) {
        ['guestAdults', 'guestChildren', 'guestInfants'].forEach(function (name) {
          var el = form.querySelector('input[name="' + name + '"]');
          if (el) totalGuests += parseInt(el.value, 10) || 0;
        });
      }
      if (totalGuests > 0) params.set('guests', totalGuests);
      var qs = params.toString();
      window.location.href = '/urunler' + (qs ? '?' + qs : '');
    });
  });

  /* ============ 14. mobile search bar -> go to index search ============ */
  $$('.sticky.top-0 button.relative').forEach(function (btn) {
    if (btn.closest('form')) return; // skip if inside a form
    btn.addEventListener('click', function () {
      window.location.href = 'index.html#search';
    });
  });

  /* ============ 15. listing page: read URL params & show search summary ============ */
  if (document.querySelector('h1') && window.location.pathname.indexOf('listing') !== -1) {
    var params = new URLSearchParams(window.location.search);
    var loc = params.get('location') || '';
    var checkin = params.get('checkin') || '';
    var checkout = params.get('checkout') || '';
    var guests = params.get('guests') || '';
    if (loc || checkin || guests) {
      var fmtDate = function (d) {
        if (!d) return '';
        try {
          var dt = new Date(d + 'T00:00:00');
          return dt.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
        } catch(e) { return d; }
      };
      var summaryParts = [];
      if (loc) summaryParts.push('<span class="font-semibold">' + escHtml(loc) + '</span>');
      if (checkin || checkout) {
        var dateStr = fmtDate(checkin);
        if (checkout) dateStr += ' – ' + fmtDate(checkout);
        summaryParts.push(dateStr);
      }
      if (guests) summaryParts.push(guests + (parseInt(guests,10) === 1 ? ' Guest' : ' Guests'));
      var banner = document.createElement('div');
      banner.className = 'bg-primary-50 border-b border-primary-200 dark:bg-primary-900/20 dark:border-primary-800';
      banner.innerHTML = '<div class="container flex items-center gap-3 py-3 text-sm text-primary-800 dark:text-primary-200">' +
        '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-5 shrink-0" aria-hidden="true"><path d="M17 17L21 21" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M19 11C19 6.58172 15.4183 3 11 3C6.58172 3 3 6.58172 3 11C3 15.4183 6.58172 19 11 19C15.4183 19 19 15.4183 19 11Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/></svg>' +
        '<span>Showing results for: ' + summaryParts.join(' <span class="mx-1 text-primary-400">\u00b7</span> ') + '</span>' +
        '<a href="index.html" class="ml-auto text-xs font-medium text-primary-600 hover:underline dark:text-primary-400">Modify search</a>' +
        '</div>';
      var main = document.querySelector('main');
      if (main) main.insertBefore(banner, main.firstChild);
      // Also update the hero search fields on listing page if they exist
      var listingForm = document.querySelector('form');
      if (listingForm) {
        var li = listingForm.querySelector('input[name="location"]');
        if (li && loc) li.value = loc;
        var ci = listingForm.querySelector('input[name="checkin"]');
        if (ci && checkin) ci.value = checkin;
        var co = listingForm.querySelector('input[name="checkout"]');
        if (co && checkout) co.value = checkout;
      }
    }
  }

  function escHtml(s) {
    var d = document.createElement('div');
    d.textContent = s;
    return d.innerHTML;
  }

  /* ============ 16. stay-categories / flight-categories: search form handler ============ */
  if (window.location.pathname.indexOf('stay-categories') !== -1 || window.location.pathname.indexOf('flight-categories') !== -1) {
    $$('form').forEach(function (form) {
      var locationInput = form.querySelector('input[name="location"]');
      if (!locationInput) return;
      form.addEventListener('submit', function (e) {
        e.preventDefault();
        var params = new URLSearchParams();
        var loc = locationInput.value.trim();
        if (loc) params.set('location', loc);
        var checkin = form.querySelector('input[name="checkin"]');
        var checkout = form.querySelector('input[name="checkout"]');
        if (checkin && checkin.value) params.set('checkin', checkin.value);
        if (checkout && checkout.value) params.set('checkout', checkout.value);
        var adults = form.querySelector('input[name="guestAdults"]');
        var children = form.querySelector('input[name="guestChildren"]');
        var infants = form.querySelector('input[name="guestInfants"]');
        var totalGuests = 0;
        if (adults) totalGuests += parseInt(adults.value, 10) || 0;
        if (children) totalGuests += parseInt(children.value, 10) || 0;
        if (infants) totalGuests += parseInt(infants.value, 10) || 0;
        if (totalGuests > 0) params.set('guests', totalGuests);
        var qs = params.toString();
        window.location.href = 'listing.html' + (qs ? '?' + qs : '');
      });
    });
  }

  /* ============ 17. evrensel arama/filtreleme ============ */
  // Sayfadaki kartları metin aramasıyla filtrele
  (function initSearch() {
    // Filtrelenebilir kartları bul: grid'in doğrudan çocukları
    var filterableCards = [];
    var cardIndex = []; // { el, text, href, imgSrc, title, loc } pre-built cache
    $$('.grid').forEach(function (grid) {
      Array.prototype.forEach.call(grid.children, function (child) {
        if (child.querySelector('[class*="cardGallerySlider"]') || child.classList.contains('card-author-box') || child.querySelector('a[href*=".html"]')) {
          filterableCards.push(child);
          var link = child.querySelector('a[href*=".html"]');
          var img = child.querySelector('img');
          var titleEl = child.querySelector('span.block, h2, h3, .font-semibold');
          var title = titleEl ? titleEl.textContent.trim() : '';
          if (!title) {
            var texts = child.textContent.trim().split('\n').map(function(s){return s.trim();}).filter(Boolean);
            title = texts[0] || '';
          }
          var locEl = child.querySelector('svg + span, [class*="text-neutral-500"]');
          var loc = locEl ? locEl.textContent.trim() : '';
          cardIndex.push({
            el: child,
            text: (child.textContent || '').toLowerCase(),
            href: link ? link.getAttribute('href') : '#',
            imgSrc: img ? img.getAttribute('src') : '',
            title: title.substring(0, 80),
            loc: loc.substring(0, 50)
          });
        }
      });
    });
    if (filterableCards.length < 3) return;

    // Sağda yüzen arama butonu oluştur
    var searchFab = document.createElement('div');
    searchFab.id = 'search-fab-wrap';
    searchFab.style.cssText = 'position:fixed;bottom:100px;right:16px;z-index:44;display:flex;align-items:center;';
    searchFab.innerHTML = '<button id="search-fab-btn" class="rounded-full border border-neutral-200 bg-white p-3 shadow-xl hover:bg-neutral-100 focus:outline-hidden dark:border-neutral-600 dark:bg-neutral-800 dark:hover:bg-neutral-700" type="button" title="' + t('Search') + '">' +
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6" aria-hidden="true"><path d="M17 17L21 21" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M19 11C19 6.58172 15.4183 3 11 3C6.58172 3 3 6.58172 3 11C3 15.4183 6.58172 19 11 19C15.4183 19 19 15.4183 19 11Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/></svg>' +
      '</button>';
    document.body.appendChild(searchFab);

    // Sepet ikonu (sağda, arama butonunun üstünde)
    var cartFab = document.getElementById('cart-fab-wrap');
    if (!cartFab) {
      cartFab = document.createElement('div');
      cartFab.id = 'cart-fab-wrap';
      cartFab.style.cssText = 'position:fixed;bottom:160px;right:16px;z-index:44;display:flex;align-items:center;';
      cartFab.innerHTML = '<button id="cart-fab-btn" class="rounded-full border border-neutral-200 bg-white p-3 shadow-xl hover:bg-neutral-100 focus:outline-hidden dark:border-neutral-600 dark:bg-neutral-800 dark:hover:bg-neutral-700 relative" type="button" title="' + t('Cart') + '">' +
        '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6" aria-hidden="true"><path d="M10.5 20.25C10.5 20.6642 10.1642 21 9.75 21C9.33579 21 9 20.6642 9 20.25C9 19.8358 9.33579 19.5 9.75 19.5C10.1642 19.5 10.5 19.8358 10.5 20.25Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M19 20.25C19 20.6642 18.6642 21 18.25 21C17.8358 21 17.5 20.6642 17.5 20.25C17.5 19.8358 17.8358 19.5 18.25 19.5C18.6642 19.5 19 19.8358 19 20.25Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M2 3H2.20664C3.53124 3 4.19354 3 4.6255 3.40221C5.05746 3.80441 5.10464 4.46503 5.19902 5.78626L5.45035 9.30496C5.5924 11.2936 5.66342 12.2879 5.96476 13.0961C6.62531 14.8677 8.08229 16.2244 9.89648 16.757C10.7241 17 11.7267 17 13.7317 17C15.8373 17 16.89 17 17.7417 16.7416C19.6593 16.1599 21.1599 14.6593 21.7416 12.7417C22 11.89 22 10.8433 22 8.75C22 8.05222 22 7.70333 21.9139 7.41943C21.72 6.78023 21.2198 6.28002 20.5806 6.08612C20.2967 6 19.9478 6 19.25 6H5.5" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M16 10V13M11 10V13" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/></svg>' +
        '<span id="cart-badge" class="absolute -top-1 -right-1 hidden flex items-center justify-center size-5 rounded-full bg-red-500 text-xs font-bold text-white">0</span>' +
        '</button>';
      document.body.appendChild(cartFab);
    }

    // Ana sayfanın masaüstü başlığında ilan verme CTA'sı kaldırılır;
    // arama header'ın ortasında, sepet ise bildirim ikonunun yanında kalır.
    if (document.body.hasAttribute('data-nexus-demo-home')) {
      var desktopHeader = document.querySelector('.relative.z-20.hidden.lg\\:block .flex.h-20');
      var headerRight = desktopHeader && desktopHeader.lastElementChild;
      if (desktopHeader && !document.getElementById('nexus-header-search')) {
        // Chisfis demosundaki gibi, masaüstü header'ın ortasında birleşik arama alanı.
        var headerSearch = document.createElement('div');
        headerSearch.id = 'nexus-header-search';
        headerSearch.innerHTML = '<form role="search" aria-label="Search" autocomplete="off">' +
        '<input type="search" aria-label="Search" placeholder="' + t('Search') + '" />' +
          '<button type="submit" aria-label="Search" title="' + t('Search') + '">' +
            '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.8" stroke="currentColor" aria-hidden="true"><path d="m20 20-4.2-4.2m1.2-5.3a6.5 6.5 0 1 1-13 0 6.5 6.5 0 0 1 13 0Z" stroke-linecap="round" stroke-linejoin="round"/></svg>' +
          '</button>' +
        '</form>' +
        '<button type="button" id="nexus-header-mic" aria-label="' + t('Voice search') + '" title="' + t('Voice search') + '">' +
          '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.8" stroke="currentColor" aria-hidden="true"><path d="M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Z" stroke-linecap="round" stroke-linejoin="round"/><path d="M5.5 11.5a6.5 6.5 0 0 0 13 0M12 18v3m-3 0h6" stroke-linecap="round" stroke-linejoin="round"/></svg>' +
        '</button>';
        if (headerRight) desktopHeader.insertBefore(headerSearch, headerRight);
        else desktopHeader.appendChild(headerSearch);

        var headerSearchForm = headerSearch.querySelector('form');
        var headerSearchInput = headerSearch.querySelector('input');
        headerSearchForm.addEventListener('submit', function(e) {
          e.preventDefault();
          var query = headerSearchInput.value.trim();
          openSearchModal();
          var modalInput = document.getElementById('site-search');
          if (modalInput && query) {
            modalInput.value = query;
            modalInput.dispatchEvent(new Event('input', { bubbles: true }));
          }
        });
        var headerMic = headerSearch.querySelector('#nexus-header-mic');
        var voiceRecognition = null;
        headerMic.addEventListener('click', function() {
          openSearchModal();
          var SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
          if (!SpeechRecognition) {
            headerMic.title = t('Voice search is not supported in this browser');
            return;
          }
          if (voiceRecognition) {
            voiceRecognition.stop();
            return;
          }

          voiceRecognition = new SpeechRecognition();
          var voiceLocales = {
            tr: 'tr-TR',
            en: 'en-US',
            de: 'de-DE',
            ru: 'ru-RU',
            fr: 'fr-FR',
            es: 'es-ES',
            zh: 'zh-CN',
            it: 'it-IT',
            ar: 'ar-SA',
            vi: 'vi-VN',
            'fr-be': 'fr-FR',
            'fr-ca': 'fr-CA',
            'fr-be-2': 'fr-FR',
            'fr-ca-2': 'fr-CA'
          };
          var voiceBaseLang = String(currentLang || '').split('-')[0];
          voiceRecognition.lang = voiceLocales[currentLang] || voiceLocales[voiceBaseLang] || document.documentElement.lang || 'en-US';
          voiceRecognition.interimResults = false;
          voiceRecognition.maxAlternatives = 1;
          voiceRecognition.onstart = function() {
            headerMic.classList.add('is-listening');
            headerMic.setAttribute('aria-pressed', 'true');
            headerMic.title = t('Listening...');
          };
          voiceRecognition.onresult = function(event) {
            var transcript = event.results && event.results[0] && event.results[0][0]
              ? event.results[0][0].transcript.trim()
              : '';
            if (!transcript) return;
            headerSearchInput.value = transcript;
            var modalInput = document.getElementById('site-search');
            if (modalInput) {
              modalInput.value = transcript;
              modalInput.dispatchEvent(new Event('input', { bubbles: true }));
            }
          };
          voiceRecognition.onerror = function() {
            headerMic.title = t('Voice search');
          };
          voiceRecognition.onend = function() {
            headerMic.classList.remove('is-listening');
            headerMic.setAttribute('aria-pressed', 'false');
            headerMic.title = t('Voice search');
            voiceRecognition = null;
          };
          try {
            voiceRecognition.start();
          } catch (error) {
            voiceRecognition = null;
          }
        });
      }
      var propertyLink = desktopHeader && Array.prototype.find.call(desktopHeader.querySelectorAll('a'), function (link) {
        return (link.textContent || '').trim() === 'List your property';
      });
      if (propertyLink) {
        cartFab.style.cssText = '';
        cartFab.className = 'nexus-header-action';
        propertyLink.remove();
        searchFab.remove();
        var notificationButton = document.getElementById('popover-button-4');
        var notificationWrap = notificationButton && notificationButton.parentElement;
        if (notificationWrap) notificationWrap.after(cartFab);
        else if (headerRight) headerRight.appendChild(cartFab);
      }
    }

    // Sepet modalı oluştur
    var cartModal = document.createElement('div');
    cartModal.id = 'cart-modal';
    cartModal.className = 'fixed inset-0 z-50 hidden items-center justify-center bg-black/50 backdrop-blur-sm';
    cartModal.innerHTML = '<div class="w-full max-w-md mx-4 rounded-2xl bg-white p-6 shadow-2xl dark:bg-neutral-800">' +
      '<div class="flex items-center justify-between mb-4">' +
        '<h3 class="text-lg font-semibold dark:text-neutral-100">' + t('Your Cart') + '</h3>' +
        '<button type="button" id="cart-modal-close" class="rounded-full p-1 text-neutral-400 hover:bg-neutral-100 hover:text-neutral-600 dark:hover:bg-neutral-700 dark:hover:text-neutral-300">' +
          '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="size-5" aria-hidden="true"><path d="M18 6L6.00081 17.9992M17.9992 18L6 6.00085" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/></svg>' +
        '</button>' +
      '</div>' +
      '<div id="cart-modal-content" class="text-center py-8">' +
        '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1" stroke="currentColor" class="mx-auto size-16 text-neutral-300 dark:text-neutral-600 mb-4" aria-hidden="true"><path d="M10.5 20.25C10.5 20.6642 10.1642 21 9.75 21C9.33579 21 9 20.6642 9 20.25C9 19.8358 9.33579 19.5 9.75 19.5C10.1642 19.5 10.5 19.8358 10.5 20.25Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M19 20.25C19 20.6642 18.6642 21 18.25 21C17.8358 21 17.5 20.6642 17.5 20.25C17.5 19.8358 17.8358 19.5 18.25 19.5C18.6642 19.5 19 19.8358 19 20.25Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M2 3H2.20664C3.53124 3 4.19354 3 4.6255 3.40221C5.05746 3.80441 5.10464 4.46503 5.19902 5.78626L5.45035 9.30496C5.5924 11.2936 5.66342 12.2879 5.96476 13.0961C6.62531 14.8677 8.08229 16.2244 9.89648 16.757C10.7241 17 11.7267 17 13.7317 17C15.8373 17 16.89 17 17.7417 16.7416C19.6593 16.1599 21.1599 14.6593 21.7416 12.7417C22 11.89 22 10.8433 22 8.75C22 8.05222 22 7.70333 21.9139 7.41943C21.72 6.78023 21.2198 6.28002 20.5806 6.08612C20.2967 6 19.9478 6 19.25 6H5.5" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M16 10V13M11 10V13" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/></svg>' +
        '<p class="text-neutral-500 dark:text-neutral-400 font-medium">' + t('Your cart is empty') + '</p>' +
        '<p class="text-sm text-neutral-400 dark:text-neutral-500 mt-1">' + t('Start exploring and add items') + '</p>' +
        '<a href="stay-categories.html" class="inline-block mt-4 px-6 py-2.5 bg-primary-500 text-white rounded-xl font-medium hover:bg-primary-600 transition">' + t('Explore Stays') + '</a>' +
      '</div>' +
    '</div>';
    document.body.appendChild(cartModal);

    /* ---- FAB modalları (sepet + site arama): kapanışta kısa fade + kayma ----
       Önceden kapanış `hidden` sınıfını ANINDA ekliyordu; `display: none`
       geçişi kestiği için hiçbir kapanış animasyonu görünmüyordu. Artık
       `nx-modal-closing` sınıfıyla MODAL_CLOSE_MS boyunca sönüp aşağı kayıyor
       (chisfis-bridge.css). Açılış aynı yolu tersine kullanır; aksi hâlde
       sönerek kapanan modal anında açılıp tutarsız görünürdü.

       Süre CSS'teki `.2s` ile eşleşmelidir. Neden `transitionend` değil de
       zamanlayıcı: süre yalnız kök elemanın değil çocukların geçişlerinde de
       tetiklenir ve olaylar kabarcıklanır, tek olayla "kapanış bitti"
       ayırt edilemez (header-popovers.js `closePanel` de bu yüzden zamanlar). */
    var MODAL_CLOSE_MS = 200;

    function showModal(el) {
      if (!el) return;
      // Kapanış sürerken yeniden açılırsa bekleyen gizleme iptal edilir;
      // aksi hâlde zamanlayıcı ateşlenip AÇIK modalı gizlerdi.
      if (el.__nxModalTimer) { clearTimeout(el.__nxModalTimer); el.__nxModalTimer = null; }
      el.__nxModalOpen = true;
      el.classList.remove('nx-modal-closing', 'hidden');
      el.classList.add('flex');
      if (reducedMotion()) return;
      el.classList.add('nx-modal-opening');
      // Başlangıç durumunu hesaplattırıp geçişi başlat: `requestAnimationFrame`
      // arka plandaki sekmede hiç çalışmaz, modal görünmez kalırdı.
      void el.offsetHeight;
      if (el.__nxModalOpen) el.classList.remove('nx-modal-opening');
    }

    function hideModal(el, done) {
      // Yinelenen çağrı (Escape + backdrop aynı karede) ikinci bir zamanlayıcı
      // kurmasın; kapanış sürerken de erken döner.
      if (!el || !el.__nxModalOpen) return;
      el.__nxModalOpen = false;
      el.classList.remove('nx-modal-opening');
      function finish() {
        if (el.__nxModalTimer) { clearTimeout(el.__nxModalTimer); el.__nxModalTimer = null; }
        if (el.__nxModalOpen) return; // bu sırada yeniden açıldıysa gizleme
        el.classList.remove('nx-modal-closing', 'flex');
        el.classList.add('hidden');
        if (done) done();
      }
      if (reducedMotion()) { finish(); return; }
      el.classList.add('nx-modal-closing');
      el.__nxModalTimer = setTimeout(finish, MODAL_CLOSE_MS);
    }

    // Alt bardaki "Sepet" düğmesi ayrı bir IIFE'de yaşıyor; aynı animasyon
    // yolunu kullanması için dar bir köprü açılır (aşağıda `openCart`).
    window.NEXUS_MODALS = {
      showCart: function () { showModal(cartModal); },
      hideCart: function () { hideModal(cartModal); },
    };

    // Sepet modal aç/kapat
    function openCartModal() { showModal(cartModal); }
    function closeCartModal() { hideModal(cartModal); }
    cartFab.querySelector('#cart-fab-btn').addEventListener('click', openCartModal);
    cartModal.querySelector('#cart-modal-close').addEventListener('click', closeCartModal);
    cartModal.addEventListener('click', function(e) { if (e.target === cartModal) closeCartModal(); });
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && !cartModal.classList.contains('hidden')) {
        closeCartModal();
      }
    });

    // Arama modalı oluştur
    var searchModal = document.createElement('div');
    searchModal.id = 'search-modal';
    searchModal.className = 'fixed inset-0 z-50 hidden items-center justify-center bg-black/50 backdrop-blur-sm';
    searchModal.innerHTML = '<div class="w-full max-w-lg mx-4 rounded-2xl bg-white p-6 shadow-2xl dark:bg-neutral-800">' +
      '<div class="flex items-center gap-3 mb-4">' +
        '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-5 text-neutral-400" aria-hidden="true"><path d="M17 17L21 21" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M19 11C19 6.58172 15.4183 3 11 3C6.58172 3 3 6.58172 3 11C3 15.4183 6.58172 19 11 19C15.4183 19 19 15.4183 19 11Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/></svg>' +
        '<input type="text" id="site-search" class="w-full bg-transparent text-lg font-medium placeholder-neutral-400 focus:outline-none dark:text-neutral-100 dark:placeholder-neutral-500" placeholder="' + searchT('Search listings...') + '" />' +
        '<button type="button" id="search-modal-close" class="rounded-full p-1 text-neutral-400 hover:bg-neutral-100 hover:text-neutral-600 dark:hover:bg-neutral-700 dark:hover:text-neutral-300">' +
          '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="size-5" aria-hidden="true"><path d="M18 6L6.00081 17.9992M17.9992 18L6 6.00085" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/></svg>' +
        '</button>' +
      '</div>' +
      '<div id="search-modal-results" class="max-h-60 overflow-y-auto"></div>' +
    '</div>';
    document.body.appendChild(searchModal);

    // Modal aç/kapat
    function openSearchModal() {
      showModal(searchModal);
      var inp = searchModal.querySelector('#site-search');
      if (inp) setTimeout(function() { inp.focus(); }, 100);
    }
    function closeSearchModal() {
      // Girdi temizliği sönme BİTİNCE yapılır: animasyon sürerken sonuçlar bir
      // anda kaybolmasın. Bu arada yeniden açılırsa temizlik hiç çalışmaz ve
      // kullanıcı sorgusunu kaybetmez.
      hideModal(searchModal, function () {
        var inp = searchModal.querySelector('#site-search');
        if (inp) { inp.value = ''; inp.dispatchEvent(new Event('input')); }
      });
    }
    searchFab.querySelector('#search-fab-btn').addEventListener('click', openSearchModal);
    searchModal.querySelector('#search-modal-close').addEventListener('click', closeSearchModal);
    searchModal.addEventListener('click', function(e) { if (e.target === searchModal) closeSearchModal(); });

    var input = searchModal.querySelector('#site-search');
    var clearBtn = null; // modal içinde clear但onu Results içinden hallediyoruz
    var noResults = null;

    function getCardText(card) {
      return (card.textContent || '').toLowerCase();
    }

    function highlightMatch(text, q) {
      if (!q || !text) return text;
      var idx = text.toLowerCase().indexOf(q);
      if (idx === -1) return text;
      return text.substring(0, idx) + '<mark class="bg-yellow-200 dark:bg-yellow-800 rounded px-0.5">' + text.substring(idx, idx + q.length) + '</mark>' + text.substring(idx + q.length);
    }

    function doFilter() {
      var q = input.value.trim().toLowerCase();
      var resultsContainer = searchModal.querySelector('#search-modal-results');
      if (!resultsContainer) return;

      if (!q) { resultsContainer.innerHTML = ''; return; }

      // Use pre-built index for speed — no DOM queries per card
      var matches = [];
      for (var i = 0; i < cardIndex.length; i++) {
        if (cardIndex[i].text.indexOf(q) !== -1) {
          matches.push(cardIndex[i]);
        }
      }

      // Sort: title matches first, then location, then text
      matches.sort(function(a, b) {
        var aTitle = a.title.toLowerCase().indexOf(q) !== -1 ? 0 : 1;
        var bTitle = b.title.toLowerCase().indexOf(q) !== -1 ? 0 : 1;
        return aTitle - bTitle;
      });

      if (matches.length === 0) {
        resultsContainer.innerHTML = '<div class="py-8 text-center text-neutral-500 dark:text-neutral-400">' +
          '<p class="text-base font-medium">' + searchT('No results found') + '</p>' +
          '<p class="mt-1 text-sm">' + searchT('Try a different search term') + '</p></div>';
      } else {
        var showCount = Math.min(matches.length, 12);
        var html = '<div class="mb-2 flex items-center justify-between px-1">' +
          '<span class="text-xs font-medium text-neutral-500 dark:text-neutral-400">' +
          matches.length + ' ' + searchT('results') + '</span></div>';
        for (var j = 0; j < showCount; j++) {
          var m = matches[j];
          var hlTitle = highlightMatch(m.title, q);
          var hlLoc = highlightMatch(m.loc, q);
          html += '<a href="' + m.href + '" class="flex items-center gap-3 rounded-xl p-2 hover:bg-neutral-100 dark:hover:bg-neutral-700 transition">' +
            (m.imgSrc ? '<img src="' + m.imgSrc + '" class="size-12 rounded-lg object-cover flex-shrink-0" alt="" loading="lazy" />' : '') +
            '<div class="min-w-0 flex-1"><p class="truncate text-sm font-medium dark:text-neutral-100">' + hlTitle + '</p>' +
            (m.loc ? '<p class="truncate text-xs text-neutral-500 dark:text-neutral-400">' + hlLoc + '</p>' : '') +
            '</div></a>';
        }
        if (matches.length > 12) {
          html += '<p class="py-2 text-center text-xs text-neutral-400 dark:text-neutral-500">' +
            searchT('Show all') + ' ' + matches.length + ' ' + searchT('results') + '</p>';
        }
        resultsContainer.innerHTML = html;
      }
    }

    // Debounced search (120ms for snappy feel)
    var searchTimer = null;
    input.addEventListener('input', function () {
      clearTimeout(searchTimer);
      searchTimer = setTimeout(doFilter, 120);
    });

    // Clear button
    if (clearBtn) {
      clearBtn.addEventListener('click', function () {
        input.value = '';
        doFilter();
        input.focus();
      });
    }

    // Enter tuşu ile arama
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') {
        input.value = '';
        doFilter();
        input.blur();
      }
    });

    // Escape ile modalı kapat
    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && !searchModal.classList.contains('hidden')) {
        closeSearchModal();
      }
    });

    // Tab değişikliklerini dinle (city filtresi ile uyumlu)
    $$('[role="tab"]').forEach(function (tab) {
      tab.addEventListener('click', function () {
        // Tab değiştiğinde aramayı tekrar uygula
        setTimeout(doFilter, 50);
      });
    });

    // Arama ve sepet metinleri, ana i18n sözlüğüyle aynı seçili dili kullanır.
    function searchT(en) {
      var searchDicts = {
        tr: {
        'Search listings...': 'İlan ara...',
        'No results found': 'Sonuç bulunamadı',
        'Try a different search term': 'Farklı bir arama terimi deneyin',
        'results': 'sonuç',
        'Show all': 'Tüm',
        'Your Cart': 'Sepetiniz',
        'Your cart is empty': 'Sepetiniz boş',
        'Start exploring and add items': 'Keşfetmeye başlayın ve ürün ekleyin',
        'Explore Stays': 'Konaklama Keşfet',
        },
        de: {
          'Search listings...': 'Unterkünfte suchen...',
          'No results found': 'Keine Ergebnisse gefunden',
          'Try a different search term': 'Versuchen Sie einen anderen Suchbegriff',
          'results': 'Ergebnisse', 'Show all': 'Alle anzeigen',
          'Your Cart': 'Ihr Warenkorb', 'Your cart is empty': 'Ihr Warenkorb ist leer',
          'Start exploring and add items': 'Entdecken Sie Unterkünfte und fügen Sie sie hinzu',
          'Explore Stays': 'Unterkünfte entdecken'
        },
        ru: {
          'Search listings...': 'Поиск объявлений...',
          'No results found': 'Результаты не найдены',
          'Try a different search term': 'Попробуйте другой поисковый запрос',
          'results': 'результатов', 'Show all': 'Показать все',
          'Your Cart': 'Ваша корзина', 'Your cart is empty': 'Корзина пуста',
          'Start exploring and add items': 'Начните поиск и добавьте варианты',
          'Explore Stays': 'Открыть жильё'
        },
        zh: {
          'Search listings...': '搜索房源...', 'No results found': '未找到结果',
          'Try a different search term': '请尝试其他搜索词', 'results': '个结果',
          'Show all': '显示全部', 'Your Cart': '您的购物车',
          'Your cart is empty': '购物车为空',
          'Start exploring and add items': '开始探索并添加房源', 'Explore Stays': '探索住宿'
        },
        fr: {
          'Search listings...': 'Rechercher des annonces...', 'No results found': 'Aucun résultat',
          'Try a different search term': 'Essayez un autre terme', 'results': 'résultats',
          'Show all': 'Tout afficher', 'Your Cart': 'Votre panier',
          'Your cart is empty': 'Votre panier est vide',
          'Start exploring and add items': 'Commencez à explorer et ajoutez des hébergements',
          'Explore Stays': 'Explorer les hébergements'
        }
      };
      var dict = searchDicts[currentLang];
      return (dict && dict[en]) || (window.NEXUS_T && window.NEXUS_T(en)) || en;
    }

    // Dil popover'ından yapılan seçim arama alanlarını anında günceller.
    document.addEventListener('nexus:lang', function () {
      if (headerSearchInput) {
        headerSearchInput.placeholder = t('Search');
        headerSearchInput.setAttribute('aria-label', t('Search'));
      }
      var mic = document.getElementById('nexus-header-mic');
      if (mic) {
        mic.setAttribute('aria-label', t('Voice search'));
        if (!mic.classList.contains('is-listening')) mic.title = t('Voice search');
      }
      var modalInput = document.getElementById('site-search');
      if (modalInput && !modalInput.value) modalInput.placeholder = searchT('Search listings...');
    });
  })();

  /* ============ 18. mobil üst bar + alt bar (yeniden tasarım) ============ */
  (function () {
    function cls(el) { return (typeof el.className === 'string') ? el.className : ''; }
    function pick(pred) {
      var found = null;
      Array.prototype.some.call(document.querySelectorAll('div'), function (el) {
        if (pred(cls(el))) { found = el; return true; }
        return false;
      });
      return found;
    }
    function openMenu() {
      var m = document.querySelector('.mobile-menu');
      if (!m) return;
      // Kapanış sönmesi sürerken açılırsa bekleyen gizleme iptal edilir;
      // aksi halde zamanlayıcı ateşlenip açık çekmeceyi kapatırdı.
      if (m.__mmCloseTimer) { clearTimeout(m.__mmCloseTimer); m.__mmCloseTimer = null; }
      m.classList.remove('mm-closing');
      m.hidden = false;
      m.style.display = '';
      m.setAttribute('data-state', 'open');
      document.documentElement.classList.add('overflow-hidden');
      // Çekmece iki ayrı yoldan açılabilir (üst bar hamburger'ı ve alt bar
      // Menü düğmesi); ikisi de alt bardaki göstergeyi senkronlamalı.
      syncBnavMenu(true);
    }
    function openCart() {
      var b = document.getElementById('cart-fab-btn');
      if (b) { b.click(); return; }
      // Aynı animasyon yolu: kapanış sönmesi sürerken açılırsa iptal edilir.
      var api = window.NEXUS_MODALS;
      if (api) { api.showCart(); return; }
      var m = document.getElementById('cart-modal');
      if (m) { m.classList.remove('hidden'); m.classList.add('flex'); }
    }

    // Mobil üst bar/alt bar yeniden tasarımı yüklenme anındaki dile göre
    // basılır; DICTS üzerinden tüm dillerde çeviri alır.
    var L = function (en) { return t(en); };

    /* ---- A) mobil üst bar: logo + arama + hamburger ---- */
    var mobileHeader = pick(function (c) {
      return c.indexOf('sticky') !== -1 && c.indexOf('lg:hidden') !== -1 && c.indexOf('z-20') !== -1;
    });
    if (mobileHeader) {
      var mhBox = mobileHeader.querySelector('.container');
      var searchWrap = mhBox ? mhBox.querySelector('.relative') : null;
      if (mhBox && searchWrap) {
        mhBox.classList.remove('justify-center');
        if (!mhBox.querySelector('.mh-logo')) {
          var desktopHeader = pick(function (c) {
            return c.indexOf('z-20') !== -1 && c.indexOf('lg:block') !== -1 && c.indexOf('hidden') !== -1;
          });
          var logoLink = desktopHeader ? desktopHeader.querySelector('a[href="index.html"]') : null;
          if (logoLink) {
            var logo = logoLink.cloneNode(true);
            logo.classList.add('mh-logo');
            logo.classList.remove('w-22', 'sm:w-24');
            mhBox.insertBefore(logo, searchWrap);
          }
        }
        searchWrap.classList.remove('w-full', 'max-w-lg');
        searchWrap.classList.add('mh-search');
        if (!mhBox.querySelector('.mh-menu-btn')) {
          var burger = document.createElement('button');
          burger.type = 'button';
          burger.className = 'mh-menu-btn';
          burger.setAttribute('aria-label', 'Open menu');
          burger.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6" aria-hidden="true"><path d="M4 5L20 5" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M4 12L20 12" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M4 19L20 19" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/></svg>';
          burger.addEventListener('click', function (e) { e.stopPropagation(); openMenu(); });
          mhBox.appendChild(burger);
        }
      }
    }

    /* ---- B) mobil alt bar: Anasayfa · Arama · [sepet] · Hesap · Menü ---- */
    var bottomBar = pick(function (c) {
      return c.indexOf('inset-x-0') !== -1 && c.indexOf('bottom-0') !== -1 && c.indexOf('lg:hidden') !== -1;
    });
    if (bottomBar && !bottomBar.querySelector('.bnav-item, .bnav-fab')) {
      var inner = bottomBar.querySelector('.mx-auto');
      if (inner) {
        var IC = {
          home: "<svg xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewBox=\"0 0 24 24\" stroke-width=\"1.5\" stroke=\"currentColor\" class=\"size-6\" aria-hidden=\"true\"><path d=\"M3 11.9896V14.5C3 17.7998 3 19.4497 4.02513 20.4749C5.05025 21.5 6.70017 21.5 10 21.5H14C17.2998 21.5 18.9497 21.5 19.9749 20.4749C21 19.4497 21 17.7998 21 14.5V11.9896C21 10.3083 21 9.46773 20.6441 8.74005C20.2882 8.01237 19.6247 7.49628 18.2976 6.46411L16.2976 4.90855C14.2331 3.30285 13.2009 2.5 12 2.5C10.7991 2.5 9.76689 3.30285 7.70242 4.90855L5.70241 6.46411C4.37533 7.49628 3.71179 8.01237 3.3559 8.74005C3 9.46773 3 10.3083 3 11.9896Z\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/></svg>",
          search: "<svg xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewBox=\"0 0 24 24\" stroke-width=\"1.5\" stroke=\"currentColor\" class=\"size-6\" aria-hidden=\"true\"><path d=\"M17 17L21 21\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/><path d=\"M19 11C19 6.58172 15.4183 3 11 3C6.58172 3 3 6.58172 3 11C3 15.4183 6.58172 19 11 19C15.4183 19 19 15.4183 19 11Z\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/></svg>",
          cart: "<svg xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewBox=\"0 0 24 24\" stroke-width=\"1.5\" stroke=\"currentColor\" class=\"size-7\" aria-hidden=\"true\"><path d=\"M10.5 20.25C10.5 20.6642 10.1642 21 9.75 21C9.33579 21 9 20.6642 9 20.25C9 19.8358 9.33579 19.5 9.75 19.5C10.1642 19.5 10.5 19.8358 10.5 20.25Z\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/><path d=\"M19 20.25C19 20.6642 18.6642 21 18.25 21C17.8358 21 17.5 20.6642 17.5 20.25C17.5 19.8358 17.8358 19.5 18.25 19.5C18.6642 19.5 19 19.8358 19 20.25Z\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/><path d=\"M2 3H2.20664C3.53124 3 4.19354 3 4.6255 3.40221C5.05746 3.80441 5.10464 4.46503 5.19902 5.78626L5.45035 9.30496C5.5924 11.2936 5.66342 12.2879 5.96476 13.0961C6.62531 14.8677 8.08229 16.2244 9.89648 16.757C10.7241 17 11.7267 17 13.7317 17C15.8373 17 16.89 17 17.7417 16.7416C19.6593 16.1599 21.1599 14.6593 21.7416 12.7417C22 11.89 22 10.8433 22 8.75C22 8.05222 22 7.70333 21.9139 7.41943C21.72 6.78023 21.2198 6.28002 20.5806 6.08612C20.2967 6 19.9478 6 19.25 6H5.5\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/><path d=\"M16 10V13M11 10V13\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/></svg>",
          user: "<svg xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewBox=\"0 0 24 24\" stroke-width=\"1.5\" stroke=\"currentColor\" class=\"size-6\" aria-hidden=\"true\"><path d=\"M20 21.0001C19.713 17.269 16.7289 14.3151 12.995 14.0662L12 13.9999C11.6446 14.0096 11.3134 14.0225 11.0008 14.0378C7.3 14.2192 4.28417 17.3057 4 21.0001\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/><circle cx=\"12\" cy=\"6.99988\" r=\"4\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/></svg>",
          menu: "<svg xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewBox=\"0 0 24 24\" stroke-width=\"1.5\" stroke=\"currentColor\" class=\"size-6\" aria-hidden=\"true\"><path d=\"M4 5L20 5\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/><path d=\"M4 12L20 12\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/><path d=\"M4 19L20 19\" stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1.5\"/></svg>"
        };;
        /* Aktif sayfa göstergesi.
         * Öğeler uygulamanın GERÇEK rotalarına bağlanır — şablon kalıntısı
         * index.html / account.html bu uygulamada 404 veriyordu. Vurgu,
         * çekmecedeki kategori vurgusuyla aynı dili kullanır: primary renk +
         * ikon üstünde nokta işareti (bkz. custom.css .bnav-item.is-active). */
        var here = window.location.pathname.replace(/\/$/, '');
        var NAV_HREFS = { home: '/', search: null, account: '/hesap', menu: null };
        function routeActive(act) {
          if (act === 'home') return here === '' || here === '/';
          if (act === 'account') return here === '/hesap' || here.indexOf('/hesap/') === 0;
          return false;
        }
        function itemHTML(act, i18n, label, icon) {
          var href = NAV_HREFS[act];
          var on = routeActive(act);
          var base = 'bnav-item' + (on ? ' is-active' : '');
          var current = on ? ' aria-current="page"' : '';
          var body = icon + '<p class="text-xs/6" data-i18n="' + i18n + '">' + label + '</p>';
          if (href) return '<a class="' + base + '" href="' + href + '" role="menuitem"' + current + ' aria-label="' + i18n + '">' + body + '</a>';
          return '<button type="button" class="' + base + '" data-act="' + act + '"' + current + ' aria-label="' + i18n + '">' + body + '</button>';
        }
        var html = '';
        html += itemHTML('home', 'Home', L('Home'), IC.home);
        html += itemHTML('search', 'Search', L('Search'), IC.search);
        html += '<button type="button" class="bnav-fab" data-act="cart" aria-label="' + L('Cart') + '">' + IC.cart + '</button>';
        html += itemHTML('account', 'Account', L('Account'), IC.user);
        html += itemHTML('menu', 'Menu', L('Menu'), IC.menu);
        inner.className = 'bnav-inner';
        inner.innerHTML = html;

        var searchBtn = inner.querySelector('[data-act="search"]');
        if (searchBtn) searchBtn.addEventListener('click', function (e) {
          e.stopPropagation();
          var b = document.getElementById('search-fab-btn');
          if (b) b.click();
        });
        var menuBtn = inner.querySelector('[data-act="menu"]');
        if (menuBtn) menuBtn.addEventListener('click', function (e) { e.stopPropagation(); openMenu(); });
        var cartBtn = inner.querySelector('[data-act="cart"]');
        if (cartBtn) cartBtn.addEventListener('click', function (e) { e.stopPropagation(); openCart(); });
      }
      bottomBar.classList.remove('items-center');
      bottomBar.classList.add('bnav-bar');
    }
  })();
})();
