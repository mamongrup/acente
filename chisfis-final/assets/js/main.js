/* Chisfis static — vanilla JS interactivity */
(function () {
  'use strict';

  /* ============ 0a. iletişim ayarları ============ */
  // WhatsApp numarası (uluslararası format, + olmadan) — buradan değiştirin
  var WHATSAPP_NUMBER = '905323977957';
  var WHATSAPP_MESSAGE = 'Merhaba, bilgi almak istiyorum.'; // sohbeti açan ön mesaj

  /* ============ 0. dark mode (localStorage kalıcı) ============ */
  var THEME_KEY = 'chisfis-theme';
  function applyTheme(dark) {
    document.documentElement.classList.toggle('dark', dark);
    document.documentElement.style.colorScheme = dark ? 'dark' : 'light';
    document.querySelectorAll('#theme-toggle').forEach(function (b) {
      b.setAttribute('aria-pressed', dark ? 'true' : 'false');
      b.title = dark ? 'Switch to light mode' : 'Switch to dark mode';
      var label = b.querySelector('span');
      if (label) label.textContent = dark ? 'Light mode' : 'Dark mode';
      var icon = b.childNodes[0];
      if (icon && icon.nodeType === 3) icon.nodeValue = dark ? '☀️ ' : '🌗 ';
    });
  }
  // başlangıç: localStorage > sistem tercihi
  var saved = null;
  try { saved = localStorage.getItem(THEME_KEY); } catch (e) {}
  var prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  applyTheme(saved ? saved === 'dark' : prefersDark);

  document.addEventListener('click', function (e) {
    var btn = e.target.closest('#theme-toggle');
    if (!btn) return;
    var dark = !document.documentElement.classList.contains('dark');
    applyTheme(dark);
    try { localStorage.setItem(THEME_KEY, dark ? 'dark' : 'light'); } catch (err) {}
  });

  /* ============ 0b. i18n — TR/EN dil değiştirici ============ */
  var $ = function (sel, ctx) { return (ctx || document).querySelector(sel); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); };

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
    // nav
    'Stays': 'Konaklama',
    'Cars': 'Arabalar',
    'Experiences': 'Deneyimler',
    'Flights': 'Uçuşlar',
    'RealEstates': 'Emlak',
    'Templates': 'Şablonlar',
    'Travelers': 'Yolcular',
    'List your property': 'Mülkünüzü listele',
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
    'Cart': 'Sepet',
    'Dark mode': 'Karanlık mod',
    'Light mode': 'Aydınlık mod',
    'Toggle dark mode': 'Karanlık modu aç/kapat',
    'CATEGORIES': 'KATEGORİLER',
    'Hotels': 'Oteller',
    'Holiday homes & villas': 'Tatil evleri ve villalar',
    'Yacht rental': 'Yat kiralama',
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
  };
  var currentLang = 'en';
  try { currentLang = localStorage.getItem(LANG_KEY) || 'en'; } catch (e) {}
  function t(enText) {
    if (currentLang === 'tr' && TR[enText]) return TR[enText];
    return enText;
  }
  function applyLang(lang) {
    currentLang = lang;
    try { localStorage.setItem(LANG_KEY, lang); } catch (e) {}
    // update toggle labels
    $$('.lang-toggle').forEach(function (btn) {
      btn.textContent = lang === 'tr' ? 'EN' : 'TR';
      btn.title = lang === 'tr' ? 'Switch to English' : 'Türkçe\'ye geç';
    });
    // translate data-i18n elements
    $$('[data-i18n]').forEach(function (el) {
      var key = el.getAttribute('data-i18n');
      if (key && TR[key]) el.textContent = lang === 'tr' ? TR[key] : key;
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
  var langToggleHTML = '<button type="button" class="lang-toggle -m-2.5 flex cursor-pointer items-center justify-center rounded-full px-2.5 py-1.5 text-xs font-bold hover:bg-neutral-100 focus-visible:outline-hidden dark:hover:bg-neutral-800" aria-label="Toggle language" title="Türkçe\'ye geç">' + (currentLang === 'tr' ? 'EN' : 'TR') + '</button>';
  // insert after theme toggle in desktop header
  $$('.relative.z-20.hidden .flex.flex-1').forEach(function (rightGroup) {
    if (!rightGroup.querySelector('.lang-toggle')) {
      var themeBtn = rightGroup.querySelector('#theme-toggle');
      if (themeBtn) themeBtn.insertAdjacentHTML('afterend', langToggleHTML);
    }
  });
  // also inject into mobile menu panel if it exists
  var menuPanel = $('.mobile-menu__panel');
  if (menuPanel && !menuPanel.querySelector('.lang-toggle')) {
    var themeBtn2 = menuPanel.querySelector('#theme-toggle');
    if (themeBtn2) themeBtn2.insertAdjacentHTML('afterend', langToggleHTML);
  }
  // NOTE: mobil alt barda (footer) dil değiştirici gösterilmez.
  // Dil değiştirme masaüstü header ve mobil menü panelinden yapılabilir.
  // click handler for lang toggles
  document.addEventListener('click', function (e) {
    var btn = e.target.closest('.lang-toggle');
    if (!btn) return;
    applyLang(currentLang === 'en' ? 'tr' : 'en');
  });
  // apply saved language on load
  applyLang(currentLang);

  function openPanel(panel) {
    if (!panel) return;
    panel.hidden = false;
    panel.style.display = '';
    panel.setAttribute('data-state', 'open');
  }
  function closePanel(panel) {
    if (!panel) return;
    panel.hidden = true;
    panel.style.display = 'none';
    panel.setAttribute('data-state', 'closed');
  }
  function markBtn(btn, open) {
    btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    var g = btn.closest('.group');
    if (g) { if (open) g.setAttribute('data-open', ''); else g.removeAttribute('data-open'); }
  }
  function closeAll(root) {
    $$('[data-state="open"]', root).forEach(closePanel);
    $$('[aria-expanded="true"]', root).forEach(function (b) { markBtn(b, false); });
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

  /* ============ 2. search-form popovers (location / dates / guests) ============ */
  $$('button[aria-expanded][aria-controls]').forEach(function (btn) {
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

  /* ============ 4. guests steppers (Adults / Children / Infants) ============ */
  $$('.flex.min-w-28').forEach(function (row) {
    var btns = $$(':scope > button', row);
    if (btns.length < 2) return;
    var minus = btns[0], plus = btns[1];
    var valueEl = $(':scope > span', row);
    var hidden = $(':scope > input[type="hidden"]', row);
    var count = parseInt(valueEl && valueEl.textContent, 10) || 0;
    var panel = row.closest('[id*="popover-panel"]');
    var group = panel ? (panel.closest('.group') || panel) : null;
    function summary() {
      if (!group) return;
      var label = $('.grow .block.font-semibold', group) || $('.grow span', group);
      if (!label) return;
      var total = 0;
      $$('.flex.min-w-28', group).forEach(function (r) {
        var v = $(':scope > span', r);
        total += parseInt(v && v.textContent, 10) || 0;
      });
      label.textContent = total + (total === 1 ? ' Guest' : ' Guests');
    }
    minus.addEventListener('click', function () {
      if (count > 0) { count--; if (valueEl) valueEl.textContent = count; if (hidden) hidden.value = count; summary(); }
    });
    plus.addEventListener('click', function () {
      if (count < 16) { count++; if (valueEl) valueEl.textContent = count; if (hidden) hidden.value = count; summary(); }
    });
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
  (function () {
    var burger = null;
    $$('button .sr-only').some(function (sp) {
      if (/open main menu/i.test(sp.textContent)) { burger = sp.closest('button'); return true; }
      return false;
    });
    if (!burger) return;
    var menu = document.createElement('div');
    menu.className = 'mobile-menu';
    menu.setAttribute('data-state', 'closed');

    // logo: masaüstü header'dan klonla (açık/koyu varyant korunur)
    var logoHTML = '';
    var dhEl = document.querySelector('.relative.z-20.hidden');
    var logoLink = dhEl ? dhEl.querySelector('a[href="index.html"]') : null;
    if (logoLink) {
      var lg = logoLink.cloneNode(true);
      lg.classList.add('mm-logo');
      lg.classList.remove('w-22', 'sm:w-24');
      logoHTML = lg.outerHTML;
    } else {
      logoHTML = '<a class="mobile-menu__brand" href="index.html">chisfis</a>';
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

    var accHTML = function (iconKey, labelKey, open, items) {
      var body = items.map(function (it) {
        return '<a href="' + it[0] + '"><span data-i18n="' + it[1] + '">' + it[1] + '</span>' + svg(P.arrow) + '</a>';
      }).join('');
      return '<div class="mm-acc"' + (open ? ' data-open="1"' : '') + '>' +
        '<button type="button" class="mm-acc-head">' +
        '<span class="mm-acc-ico">' + svg(P[iconKey]) + '</span>' +
        '<span data-i18n="' + labelKey + '">' + labelKey + '</span>' +
        '<span class="mm-acc-chev">' + svg(P.chev) + '</span>' +
        '</button>' +
        '<div class="mm-acc-body"><div class="mm-acc-inner">' + body + '</div></div>' +
        '</div>';
    };
    var directHTML = function (iconKey, labelKey, href) {
      return '<a class="mm-direct" href="' + href + '">' +
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
      '<a class="mm-ico" href="account.html" aria-label="Account">' + svg(P.user) + '</a>' +
      '</div>' +
      '<form class="mm-search" action="stay-categories.html" method="get">' + svg(P.search) +
      '<input type="search" name="q" data-i18n-placeholder="Search city, hotel or region..." placeholder="Search city, hotel or region..." aria-label="Search" />' +
      '</form>' +
      '<p class="mm-cats-label" data-i18n="CATEGORIES">CATEGORIES</p>' +
      accHTML('building', 'Stays', true, [
        ['stay-categories.html', 'Hotels'],
        ['stay-categories.html', 'Holiday homes & villas'],
        ['stay-categories.html', 'Yacht rental'],
      ]) +
      accHTML('bulb', 'Experiences', false, [
        ['experiences.html', 'All experiences'],
        ['authors.html', 'Authors'],
      ]) +
      directHTML('car', 'Cars', 'car.html') +
      directHTML('plane', 'Flights', 'flights.html') +
      '<div class="mm-foot">' +
      '<button type="button" id="theme-toggle" class="mm-foot-btn" aria-label="Toggle dark mode">🌗 <span>Dark mode</span></button>' +
      '<button type="button" class="lang-toggle mm-foot-btn" aria-label="Toggle language">' + (currentLang === 'tr' ? 'EN' : 'TR') + '</button>' +
      '</div>' +
      '</nav>';
    document.body.appendChild(menu);
    function set(open) {
      menu.setAttribute('data-state', open ? 'open' : 'closed');
      document.documentElement.classList.toggle('overflow-hidden', open);
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
    // tema etiketini mevcut durumla senkronize et
    applyTheme(document.documentElement.classList.contains('dark'));
  })();

  /* ============ 11. sticky header shadow ============ */
  var desktopHeader = $('.relative.z-20.hidden');
  window.addEventListener('scroll', function () {
    if (!desktopHeader) return;
    desktopHeader.classList.toggle('shadow-sm', window.scrollY > 8);
  }, { passive: true });

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
    var cartFab = document.createElement('div');
    cartFab.id = 'cart-fab-wrap';
    cartFab.style.cssText = 'position:fixed;bottom:160px;right:16px;z-index:44;display:flex;align-items:center;';
    cartFab.innerHTML = '<button id="cart-fab-btn" class="rounded-full border border-neutral-200 bg-white p-3 shadow-xl hover:bg-neutral-100 focus:outline-hidden dark:border-neutral-600 dark:bg-neutral-800 dark:hover:bg-neutral-700 relative" type="button" title="' + t('Cart') + '">' +
      '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6" aria-hidden="true"><path d="M10.5 20.25C10.5 20.6642 10.1642 21 9.75 21C9.33579 21 9 20.6642 9 20.25C9 19.8358 9.33579 19.5 9.75 19.5C10.1642 19.5 10.5 19.8358 10.5 20.25Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M19 20.25C19 20.6642 18.6642 21 18.25 21C17.8358 21 17.5 20.6642 17.5 20.25C17.5 19.8358 17.8358 19.5 18.25 19.5C18.6642 19.5 19 19.8358 19 20.25Z" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M2 3H2.20664C3.53124 3 4.19354 3 4.6255 3.40221C5.05746 3.80441 5.10464 4.46503 5.19902 5.78626L5.45035 9.30496C5.5924 11.2936 5.66342 12.2879 5.96476 13.0961C6.62531 14.8677 8.08229 16.2244 9.89648 16.757C10.7241 17 11.7267 17 13.7317 17C15.8373 17 16.89 17 17.7417 16.7416C19.6593 16.1599 21.1599 14.6593 21.7416 12.7417C22 11.89 22 10.8433 22 8.75C22 8.05222 22 7.70333 21.9139 7.41943C21.72 6.78023 21.2198 6.28002 20.5806 6.08612C20.2967 6 19.9478 6 19.25 6H5.5" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/><path d="M16 10V13M11 10V13" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/></svg>' +
      '<span id="cart-badge" class="absolute -top-1 -right-1 hidden flex items-center justify-center size-5 rounded-full bg-red-500 text-xs font-bold text-white">0</span>' +
      '</button>';
    document.body.appendChild(cartFab);

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

    // Sepet modal aç/kapat
    function openCartModal() {
      cartModal.classList.remove('hidden');
      cartModal.classList.add('flex');
    }
    function closeCartModal() {
      cartModal.classList.add('hidden');
      cartModal.classList.remove('flex');
    }
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
        '<input type="text" id="site-search" class="w-full bg-transparent text-lg font-medium placeholder-neutral-400 focus:outline-none dark:text-neutral-100 dark:placeholder-neutral-500" placeholder="' + t('Search listings...') + '" />' +
        '<button type="button" id="search-modal-close" class="rounded-full p-1 text-neutral-400 hover:bg-neutral-100 hover:text-neutral-600 dark:hover:bg-neutral-700 dark:hover:text-neutral-300">' +
          '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="size-5" aria-hidden="true"><path d="M18 6L6.00081 17.9992M17.9992 18L6 6.00085" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5"/></svg>' +
        '</button>' +
      '</div>' +
      '<div id="search-modal-results" class="max-h-60 overflow-y-auto"></div>' +
    '</div>';
    document.body.appendChild(searchModal);

    // Modal aç/kapat
    function openSearchModal() {
      searchModal.classList.remove('hidden');
      searchModal.classList.add('flex');
      var inp = searchModal.querySelector('#site-search');
      if (inp) setTimeout(function() { inp.focus(); }, 100);
    }
    function closeSearchModal() {
      searchModal.classList.add('hidden');
      searchModal.classList.remove('flex');
      var inp = searchModal.querySelector('#site-search');
      if (inp) { inp.value = ''; inp.dispatchEvent(new Event('input')); }
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
          '<p class="text-base font-medium">' + t('No results found') + '</p>' +
          '<p class="mt-1 text-sm">' + t('Try a different search term') + '</p></div>';
      } else {
        var showCount = Math.min(matches.length, 12);
        var html = '<div class="mb-2 flex items-center justify-between px-1">' +
          '<span class="text-xs font-medium text-neutral-500 dark:text-neutral-400">' +
          matches.length + ' ' + t('results') + '</span></div>';
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
            t('Show all') + ' ' + matches.length + ' ' + t('results') + '</p>';
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

    // Çeviri anahtarları
    function t(en) {
      if (currentLang === 'tr') {
        var tr = {
          'Search listings...': 'İlan ara...',
          'Search': 'Ara',
          'No results found': 'Sonuç bulunamadı',
          'Try a different search term': 'Farklı bir arama terimi deneyin',
          'results': 'sonuç',
          'Show all': 'Tüm',
          'Cart': 'Sepet',
          'Your Cart': 'Sepetiniz',
          'Your cart is empty': 'Sepetiniz boş',
          'Start exploring and add items': 'Keşfetmeye başlayın ve ürün ekleyin',
          'Explore Stays': 'Konaklama Keşfet',
        };
        return tr[en] || en;
      }
      return en;
    }
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
      m.hidden = false;
      m.style.display = '';
      m.setAttribute('data-state', 'open');
      document.documentElement.classList.add('overflow-hidden');
    }
    function openCart() {
      var b = document.getElementById('cart-fab-btn');
      if (b) { b.click(); return; }
      var m = document.getElementById('cart-modal');
      if (m) { m.classList.remove('hidden'); m.classList.add('flex'); }
    }

    var isTR = currentLang === 'tr';
    var L = function (en) { return (isTR && TR[en]) ? TR[en] : en; };

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
        var page = (window.location.pathname.split('/').pop() || 'index.html').toLowerCase();
        var active = (page === '' || page === 'index.html') ? 'home' : (page === 'account.html' ? 'account' : '');
        function itemHTML(act, href, i18n, label, icon) {
          var base = 'bnav-item ' + (act === active ? 'text-red-600 dark:text-red-500' : 'text-neutral-500 dark:text-neutral-300');
          var body = icon + '<p class="text-xs/6" data-i18n="' + i18n + '">' + label + '</p>';
          if (href) return '<a class="' + base + '" href="' + href + '" role="menuitem" aria-label="' + i18n + '">' + body + '</a>';
          return '<button type="button" class="' + base + '" data-act="' + act + '" aria-label="' + i18n + '">' + body + '</button>';
        }
        var html = '';
        html += itemHTML('home', 'index.html', 'Home', L('Home'), IC.home);
        html += itemHTML('search', null, 'Search', L('Search'), IC.search);
        html += '<button type="button" class="bnav-fab" data-act="cart" aria-label="' + L('Cart') + '">' + IC.cart + '</button>';
        html += itemHTML('account', 'account.html', 'Account', L('Account'), IC.user);
        html += itemHTML('menu', null, 'Menu', L('Menu'), IC.menu);
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
