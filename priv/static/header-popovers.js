/* header-popovers.js — Chisfis şablonundaki header dropdown davranışının
   birebir portesi. Şablon main.js'deki openPanel/closePanel/markBtn/closeAll
   fonksiyonları ve `button[aria-expanded][aria-controls]` bağlama deseni
   aynen korunur; paneller JS tarafında şablonun NcPopover görünümüne uygun
   (rounded-3xl, shadow-xl, ring) oluşturulur. Chevron dönüşü şablon
   sınıflarıyla (group-data-open:rotate-180) çalışır. */
(function () {
  'use strict';

  var $ = function (sel, ctx) { return (ctx || document).querySelector(sel); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); };

  /* The exported demo still contains controls added by an older local theme
     experiment.  They are not part of the reference header and duplicate the
     language/currency popover.  Remove only those legacy controls on the
     canonical demo homepage, then present the combined selector like Chisfis. */
  if (document.body.hasAttribute('data-nexus-demo-home')) {
    try { localStorage.setItem('chisfis-theme', 'light'); } catch (e) {}
    try { localStorage.setItem('nexus_currency', 'EUR'); } catch (e) {}
    document.documentElement.classList.remove('dark', 'sahra');
    document.documentElement.classList.add('light');
    document.documentElement.style.colorScheme = 'light';
    var templatesTrigger = document.getElementById('popover-button-2');
    if (templatesTrigger && !document.getElementById('popover-button-1')) {
      var travelersWrap = document.createElement('div');
      travelersWrap.className = 'group hidden lg:block';
      travelersWrap.innerHTML =
        '<button class="-m-2.5 flex items-center p-2.5 text-sm font-medium text-neutral-700 group-hover:text-neutral-950 focus:outline-hidden dark:text-neutral-300 dark:group-hover:text-neutral-100" type="button" aria-expanded="false" id="popover-button-1">' +
        'Travelers<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" class="ms-1 size-4 group-data-open:rotate-180"><path fill-rule="evenodd" d="M12.53 16.28a.75.75 0 0 1-1.06 0l-7.5-7.5a.75.75 0 0 1 1.06-1.06L12 14.69l6.97-6.97a.75.75 0 1 1 1.06 1.06l-7.5 7.5Z" clip-rule="evenodd"></path></svg></button>';
      var headerBar = templatesTrigger.closest('.flex.h-20');
      var brandGroup = headerBar && headerBar.firstElementChild;
      if (brandGroup) brandGroup.appendChild(travelersWrap);
    }
    var legacyThemeToggle = document.getElementById('theme-toggle');
    if (legacyThemeToggle) legacyThemeToggle.remove();
    $$('[aria-label="Mağaza tema paleti"], [aria-label="Store theme palette"], [aria-label="Toggle language"]').forEach(function (node) {
      node.remove();
    });
    var localeTrigger = document.getElementById('popover-button-3');
    if (localeTrigger) {
      localeTrigger.setAttribute('aria-label', 'Language and currency');
    }
  }

  /* ===== Kapanış fade'i =====
     Şablon `closePanel` paneli anında `display: none` yapıyordu; artık kısa
     bir sönme oynatılıyor (chisfis-bridge.css: `.nx-closing` + `nx-panel-out`).
     `CLOSE_FADE_MS`, CSS'teki `.14s` süresiyle eşleşmek zorundadır.

     `data-state` yine ANINDA `closed` olur: düğme mantığı ("açık mı?") ve
     aria-expanded doğru kalır, hızlı aç/kapa yarışı oluşmaz.
     Hareket azaltma tercihinde sönme yok — panel anında kapanır. */
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
    // Sönme sürerken açılırsa bekleyen gizleme iptal edilir.
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
    // Sönmekte olan paneller `data-state="closed"` taşıdığı için burada
    // yeniden yakalanmaz; bekleyen gizlemeleri kendi zamanlayıcıları bitirir.
    $$('[data-state="open"]', root).forEach(closePanel);
    $$('[aria-expanded="true"]', root).forEach(function (b) {
      // Kendi durumunu yerel denetleyicisiyle tutan kontroller (filtre paneli)
      // bu genel süpürmenin dışındadır: bkz. main.js §0d NEXUS_STATE_OWNED.
      if (window.NEXUS_STATE_OWNED && window.NEXUS_STATE_OWNED(b)) return;
      markBtn(b, false);
    });
  }

  /* ===== Çeviri =====
   * Panel gövdeleri JS ile üretilir; sunucunun SSR çeviri geçişi bu HTML'e
   * dokunamaz, o yüzden etiketler `window.NEXUS_T` (chisfis/js/main.js)
   * üzerinden seçili dilden basılır. Anahtar her zaman İngilizce referanstır,
   * sözlükte karşılığı yoksa anahtarın kendisi (İngilizce) basılır — panel
   * boş ya da Türkçe kalmaz.
   * `%s` yer tutucusu kelime sırası diller arasında değiştiği için var:
   * TR "%s azalt" (Yetişkin azalt) ↔ RU "Уменьшить: %s".
   * Süslü parantez KULLANILMAZ: `test/dict_parity_test.gleam` sözlük
   * bloklarını dengeli parantez taramasıyla çıkarır, değerdeki `{}` taramayı
   * kaydırıp anahtar eşleşmesini bozar. */
  function T(key, arg) {
    var s = (window.NEXUS_T || function (k) { return k; })(key);
    return arg === undefined ? s : s.replace('%s', arg);
  }

  /* ===== Panel içerikleri — demo NcPopover görsel dili =====
   * Misafir sayacı durumu panelin DIŞINDA tutulur: dil değişiminde gövde
   * yeniden basılır ve kullanıcının seçtiği sayılar korunmalıdır. */
  /* Misafir sayacı bu dosyadan KALDIRILDI (`GUEST_ROWS`/`GUEST_STATE`/
   * `guestRow`/nc-stepper delege bağlaması). Seçim artık arama bölümünde:
   * hero formunun guests alanı (`main.js` §4) ve detay sayfasının rezervasyon
   * paneli (`public-guests.js`). Aynı sayıyı iki yerde tutmak iki sözleşme,
   * iki sınır kümesi ve iki hata yüzeyi demekti. */

  /* ===== Keşfet bağlantıları: aktif sayfa vurgusu =====
   *
   * Tespit TEK kaynaktan gelir: `window.NEXUS_NAV` (§0c,
   * `chisfis/js/main.js`). Burada ikinci bir kopya tutmak ayrışmaya yol
   * açıyordu: kopya yalnız `/urunler?kategori=[slug]` filtresini biliyordu,
   * mobil çekmecenin bildiği `/kategori/<slug>` yolunu kaçırıyordu —
   * `/kategori/hotel` sayfasında mobil menü vurgulu, masaüstü header menüsü
   * vurgusuz kalıyordu.
   *
   * `main.js` defer sırasında bu dosyadan önce yürür (sıra statik testle
   * sabit), bu yüzden NEXUS_NAV hazırdır. Yine de yoksa vurgu uygulanmaz ve
   * konsola bir kez uyarı düşülür: sessizce eski/yanlış bir kopya kullanmaktansa
   * görünür bir eksiklik yeğdir.
   */
  function isActiveCategory(slug) {
    var nav = window.NEXUS_NAV;
    if (!nav) {
      if (!window.__nexusNavWarned) {
        window.__nexusNavWarned = true;
        console.warn(
          '[nexus] NEXUS_NAV yok — menü vurgusu uygulanamıyor (main.js yüklenmeli).',
        );
      }
      return false;
    }
    return nav.isActiveCategory(slug);
  }
  function discoverLinks(items) {
    return items.map(function (item) {
      var slug = item[0];
      var icon = item[1];
      // Etiketler mobil çekmecedeki kategorilerle AYNI anahtarlardan gelir;
      // iki menü aynı kategoriyi farklı adla gösteremez.
      var label = T(item[2]);
      var on = isActiveCategory(slug);
      return '<a class="nc-pop__link' + (on ? ' nc-pop__link--active' : '') + '"' +
        ' href="/urunler?kategori=' + slug + '"' +
        (on ? ' aria-current="page"' : '') + '>' +
        '<i class="hgi-stroke ' + icon + ' size-5"></i>' + label + '</a>';
    }).join('');
  }

  /* Kanonik kategori listesi — masaüstü Keşfet kolonu ve mobil çekmece AYNI
   * slug kümesini kullanır (`mobile_menu_active_test` küme eşitliğini
   * doğrular). `discoverLinks` bu listeden `?kategori=[slug]` bağlantılarını
   * üretir ve aktif sayfayı İŞARETLER; statik `<a href>` listesinde vurgu
   * yoktu (masaüstü menü kategori sayfasında vurgusuz kalıyordu).
   * İkon adları hugeicons fontundan doğrulanmıştır. */
  var CATEGORY_ITEMS = [
    ['hotel', 'hgi-building-02', 'Hotels'],
    ['holiday_home', 'hgi-home-01', 'Holiday homes'],
    ['yacht', 'hgi-sailboat', 'Yacht rental'],
    ['tour', 'hgi-hot-air-balloon', 'Tours'],
    ['activity', 'hgi-ticket-01', 'Activities'],
  ];

  /* `render` her dil değişiminde yeniden çalışır (refreshPanels); bu yüzden
   * gövde bir dize değil bir FONKSİYONdur — statik dize dille birlikte
   * tazelenemezdi. */
  /* Panel bağlantıları GERÇEK mağaza rotalarına gider: şablonun demo
   * adresleri (`/car`, `/experiences`, `/flights`, `/real-estate`,
   * `/account`, `/blog`, `/authors`, `/register`) bu uygulamada 404 veriyordu —
   * header menüsünde tıklanabilir görünüp hiçbir yere gitmeyen düğmeler.
   * Karşılıkları:
   *   /car|/experiences|/flights|/real-estate → gerçek vitrin rotaları
   *   /account → /hesap · /register,/authors,/blog,/rezervasyon → en yakın
   *   gerçek sayfa (`header_link_contract_test` bu eşlemeyi statik doğrular).
   */
  var PANELS = {
    'popover-button-1': {
      align: 'start',
      render: function () {
        return '<div class="nc-travel">' +
          '<a class="nc-travel__item" href="/urunler?kategori=hotel"><i class="hgi-stroke hgi-building-02"></i><span><strong>Stays</strong><small>Find the perfect place to stay</small></span></a>' +
          '<a class="nc-travel__item" href="/urunler?kategori=holiday_home"><i class="hgi-stroke hgi-home-01"></i><span><strong>Holiday homes</strong><small>Villa, apart, bungalow and residence</small></span></a>' +
          '<a class="nc-travel__item" href="/arac"><i class="hgi-stroke hgi-car-01"></i><span><strong>Car rentals</strong><small>Find the perfect car to rent</small></span></a>' +
          '<a class="nc-travel__item" href="/urunler?kategori=tour"><i class="hgi-stroke hgi-hot-air-balloon"></i><span><strong>Experiences</strong><small>Find the perfect experience</small></span></a>' +
          '<a class="nc-travel__item" href="/ucus"><i class="hgi-stroke hgi-airplane-01"></i><span><strong>Flights</strong><small>Find the perfect flight</small></span></a>' +
          '<a class="nc-travel__journey" href="/urunler"><strong>Start your journey</strong><small>Find the perfect place to stay, car to rent, or experience to enjoy</small></a>' +
          '</div>';
      }
    },
    'popover-button-2': {
      align: 'start',
      render: function () {
        return '<div class="nc-mega">' +
          '<div><div class="nc-pop__head">Home Page</div><a class="nc-pop__link" href="/">Stays</a><a class="nc-pop__link" href="/urunler?kategori=holiday_home">Holiday homes</a><a class="nc-pop__link" href="/urunler?kategori=tour">Experiences</a><a class="nc-pop__link" href="/arac">Car rentals</a><a class="nc-pop__link" href="/ucus">Flights</a><a class="nc-pop__link" href="/otobus">Bus</a></div>' +
          '<div><div class="nc-pop__head">Categories</div>' + discoverLinks(CATEGORY_ITEMS) + '<a class="nc-pop__link" href="/urunler">Search with Map</a></div>' +
          '<div><div class="nc-pop__head">Listing Pages</div><a class="nc-pop__link" href="/urunler">Stay listing</a><a class="nc-pop__link" href="/arac">Car listing</a><a class="nc-pop__link" href="/urunler?kategori=tour">Experience listing</a><a class="nc-pop__link" href="/urunler?kategori=holiday_home">Holiday home listing</a></div>' +
          '<div><div class="nc-pop__head">Other Pages</div><a class="nc-pop__link" href="/iletisim">Host profile</a><a class="nc-pop__link" href="/iletisim">Blog</a><a class="nc-pop__link" href="/urunler">Checkout</a><a class="nc-pop__link" href="/iletisim">Contact</a><a class="nc-pop__link" href="/login">Login/Signup</a><a class="nc-pop__link" href="/hesap">Account</a><a class="nc-pop__link" href="/login">Add listing</a></div>' +
          '<div class="nc-mega__collection"><img src="/static/chisfis/images/pexels-photo-5764100.jpg" alt="Enjoy the great cold"><span>Collection</span><strong>Enjoy the great cold</strong><a href="/urunler">Show more</a></div>' +
          '</div>';
      }
    },
    'popover-button-3': { align: 'end', localeTabbed: true },
    'popover-button-4': {
      align: 'end',
      render: function () {
        return '<div class="nc-pop__head">' + T('Notifications') + '</div>' +
          '<div class="nc-pop__empty"><i class="hgi-stroke hgi-notification-01 size-6"></i><p>' + T('You have no new notifications.') + '</p></div>';
      }
    },
    'popover-button-5': {
      align: 'end',
      render: function () {
        return '<a class="nc-pop__link" href="/login"><i class="hgi-stroke hgi-user-edit size-5"></i>' + T('Become a host') + '</a>' +
          '<div class="nc-pop__divider"></div>' +
          '<a class="nc-pop__link" href="/login"><i class="hgi-stroke hgi-login-03 size-5"></i>' + T('Sign in') + '</a>' +
          '<a class="nc-pop__link" href="/login"><i class="hgi-stroke hgi-user-add-01 size-5"></i>' + T('Create account') + '</a>';
      }
    }
  };

  function buildPanel(btn, def) {
    var pop = document.createElement('div');
    pop.className = 'nc-pop nc-pop--' + def.align;
    pop.id = 'popover-panel-' + btn.id.replace('popover-button-', '');
    pop.setAttribute('role', 'menu');
    pop.innerHTML = def.render ? def.render() : (def.html || '');
    pop.hidden = true;
    pop.style.display = 'none';
    pop.setAttribute('data-state', 'closed');
    // Panel, butonun kapsayıcısına konur; şablondaki top-full + mt-3 yerleşimi
    btn.parentElement.appendChild(pop);
    btn.parentElement.style.position = 'relative';
    btn.setAttribute('aria-controls', pop.id);
    if (def.localeTabbed) buildLocaleTabs(pop);
    return pop;
  }

  /* ===== Globe popover: sekmeli Language/Currency (mobil mm-pop ile aynı) =====
   * Veri kaynağı: window.NEXUS_LOCALE (main.js tanımlar; main.js defer sırası
   * önce çalışır). Dil seçimi main.js applyLang zincirine 'nexus:lang' ile,
   * para birimi NEXUS_LOCALE.applyCurrency ('nexus:currency' olayı) ile iletilir. */
  function buildLocaleTabs(pop) {
    var L = window.NEXUS_LOCALE || {
      lang: localStorage.getItem('nexus_lang') || document.documentElement.lang || 'en',
      currency: localStorage.getItem('nexus_currency') || 'EUR',
      langs: [
        { code: 'tr', main: 'Türkçe', sub: 'Türkiye' },
        { code: 'en', main: 'English', sub: 'United State' },
        { code: 'de', main: 'Deutsch', sub: 'Deutschland' },
        { code: 'ru', main: 'Русский', sub: 'Россия' },
        { code: 'zh', main: '简体中文', sub: '中国' },
        { code: 'fr', main: 'Français', sub: 'France' }
      ],
      currencies: [
        { code: 'EUR', symbol: '€' },
        { code: 'USD', symbol: '$' },
        { code: 'GBF', symbol: '£' },
        { code: 'SAR', symbol: '﷼' },
        { code: 'QAR', symbol: '﷼' },
        { code: 'BAD', symbol: '﷼' }
      ],
      applyCurrency: function (code) {
        this.currency = code;
        localStorage.setItem('nexus_currency', code);
        document.cookie = 'nexus_currency=' + encodeURIComponent(code) + '; path=/; max-age=31536000; SameSite=Lax';
        document.dispatchEvent(new CustomEvent('nexus:currency', { detail: { currency: code } }));
      }
    };
    window.NEXUS_LOCALE = L;
    var cur = L.currency;
    // Sekme etiketleri mevcut dilde basılır (window.NEXUS_T, main.js'ten)
    var T = window.NEXUS_T || function (s) { return s; };
    pop.innerHTML =
      '<div class="mm-pop__tabs" role="tablist">' +
      '<button type="button" class="mm-pop__tab" role="tab" data-tab="lang" data-selected="" aria-selected="true">Language</button>' +
      '<button type="button" class="mm-pop__tab" role="tab" data-tab="cur" aria-selected="false">' + T('Currency') + '</button>' +
      '</div>' +
      '<div class="mm-pop__grid" data-pane="lang"></div>' +
      '<div class="mm-pop__grid" data-pane="cur" hidden></div>';

    function currencyIcon(code) {
      var paths = {
        EUR: '<path d="M15 14.4923C14.5216 15.3957 13.6512 16 12.6568 16C11.147 16 9.92308 14.6071 9.92308 12.8889V11.1111C9.92308 9.39289 11.147 8 12.6568 8C13.6512 8 14.5216 8.60426 15 9.50774M9 12H12.9231"/>',
        GBF: '<path d="M9 12H13.2M9 12V9.2963C9 8.82489 9 8.58919 9.14645 8.44274C9.29289 8.2963 9.5286 8.2963 10 8.2963H13.2C14.1941 8.2963 15 9.1254 15 10.1481C15 11.1709 14.1941 12 13.2 12M9 12V14.7037C9 15.1751 9 15.4108 9.14645 15.5572C9.29289 15.7037 9.5286 15.7037 10 15.7037H13.2C14.1941 15.7037 15 14.8746 15 13.8518C15 12.8291 14.1941 12 13.2 12M10.4938 8.2963V7M10.4938 17V15.7037M12.8982 8.2963V7M12.8982 17V15.7037"/>',
        QAR: '<path d="M9 7.5C9.2 8.41667 10.08 10.5 12 11.5M12 11.5C13.92 10.5 14.8 8.41667 15 7.5M12 11.5V16.5M14.5 13.5H9.5"/>',
        BAD: '<path d="M9 7.5C9.2 8.41667 10.08 10.5 12 11.5M12 11.5C13.92 10.5 14.8 8.41667 15 7.5M12 11.5V16.5M14.5 13.5H9.5"/>'
      };
      var mark = paths[code] || '<path d="M14.7102 10.0611C14.6111 9.29844 13.7354 8.06622 12.1608 8.06619C10.3312 8.06616 9.56136 9.07946 9.40515 9.58611C9.16145 10.2638 9.21019 11.6571 11.3547 11.809C14.0354 11.999 15.1093 12.3154 14.9727 13.956C14.836 15.5965 13.3417 15.951 12.1608 15.9129C10.9798 15.875 9.04764 15.3325 8.97266 13.8733M11.9734 6.99805V8.06982M11.9734 15.9031V16.998"/>';
      return '<svg class="mm-pop__currency-icon" viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><path d="M22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12Z"/>' + mark + '</svg>';
    }
    function optHTML(kind, val, main, sub) {
      var sel = (kind === 'lang' ? L.lang : cur) === val;
      return '<button type="button" class="mm-pop__opt" role="menuitemradio" aria-checked="' + sel + '" data-kind="' + kind + '" data-val="' + val + '">' +
        (kind === 'cur' ? currencyIcon(val) : '') +
        '<span class="mm-pop__opt-main">' + main + '</span>' +
        (sub ? '<span class="mm-pop__opt-sub">' + sub + '</span>' : '') +
        '</button>';
    }
    function renderPane(pane) {
      var kind = pane.getAttribute('data-pane');
      if (kind === 'lang') {
        pane.innerHTML = L.langs.map(function (l) { return optHTML('lang', l.code, l.main, l.sub); }).join('');
      } else {
        pane.innerHTML = L.currencies.map(function (c) { return optHTML('cur', c.code, c.code, ''); }).join('');
      }
    }
    function renderAll() { $$('.mm-pop__grid', pop).forEach(renderPane); }
    renderAll();
    // dil değişiminde işaretleri ve sekme etiketlerini tazele (applyLang NEXUS_LOCALE.lang günceller)
    document.addEventListener('nexus:lang', function () {
      var T2 = window.NEXUS_T || function (s) { return s; };
      $$('.mm-pop__tab', pop).forEach(function (tb) {
        tb.textContent = tb.getAttribute('data-tab') === 'lang' ? 'Language' : T2('Currency');
      });
      renderAll();
    });
    document.addEventListener('nexus:currency', function (e) {
      cur = e.detail && e.detail.currency ? e.detail.currency : cur;
      renderAll();
    });

    function setTab(name) {
      $$('.mm-pop__tab', pop).forEach(function (tb) {
        var sel = tb.getAttribute('data-tab') === name;
        if (sel) tb.setAttribute('data-selected', ''); else tb.removeAttribute('data-selected');
        tb.setAttribute('aria-selected', sel ? 'true' : 'false');
      });
      $$('.mm-pop__grid', pop).forEach(function (p) {
        p.hidden = p.getAttribute('data-pane') !== name;
      });
    }
    $$('.mm-pop__tab', pop).forEach(function (tb) {
      tb.addEventListener('click', function (e) { e.stopPropagation(); setTab(tb.getAttribute('data-tab')); });
    });

    pop.addEventListener('click', function (e) {
      var opt = e.target.closest('.mm-pop__opt');
      if (!opt) return;
      e.stopPropagation();
      var kind = opt.getAttribute('data-kind');
      var val = opt.getAttribute('data-val');
      if (kind === 'lang') {
        L.lang = val;
        document.documentElement.lang = val;
        localStorage.setItem('nexus_lang', val);
        document.cookie = 'nexus_lang=' + encodeURIComponent(val) + '; path=/; max-age=31536000; SameSite=Lax';
        document.dispatchEvent(new CustomEvent('nexus:lang', { detail: { lang: val } }));
      } else {
        cur = val;
        L.applyCurrency(val);
      }
      renderAll();
    });
  }

  /* Stepper tıklamaları panel üzerinde TEK delege dinleyiciyle yakalanır.
   * Eskiden her açılışta düğmelere yeniden bağlanılıyordu: düğümler aynı
   * kaldığı için dinleyiciler birikiyor ve paneli 3 kez açtıktan sonra bir
   * tıklama sayacı 3 artırıyordu. Delege ayrıca dil değişiminde gövde
   * yeniden basıldığında (yeni düğümler) bağlamayı geçersiz kılmaz. */

  /* ===== Dil değişiminde panelleri tazele =====
   * Paneller JS ile kurulur, dolayısıyla `applyLang`in data-i18n geçişi onları
   * kapsamaz: kullanıcı dil değiştirdiğinde (panel açıkken de) etiketler
   * mevcut dilde yeniden basılmalı. Tazeleme gövdeyi `render` ile yeniden
   * üretir; panelin açık/kapalı durumu ve misafir sayaçları korunur.
   * Sekmeli locale popover'ı (`popover-button-3`) kendi `nexus:lang` dinleyicisine
   * sahip — `render` taşımadığı için burada atlanır. */
  var REGISTRY = [];
  function refreshPanels() {
    REGISTRY.forEach(function (entry) {
      if (!entry.def.render) return;
      entry.panel.innerHTML = entry.def.render();
    });
  }
  document.addEventListener('nexus:lang', refreshPanels);

  /* ===== Bağlama: şablondaki genel desen (button[aria-expanded][aria-controls]) ===== */
  Object.keys(PANELS).forEach(function (btnId) {
    var btn = document.getElementById(btnId);
    if (!btn) return;
    var panel = buildPanel(btn, PANELS[btnId]);
    // Dil tazelemesi için kayıt: gövde `render` ile yeniden üretilebilsin
    REGISTRY.push({ btn: btn, panel: panel, def: PANELS[btnId] });
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      var isOpen = panel.getAttribute('data-state') === 'open';
      closeAll(document);
      if (isOpen) return; // aynı butona ikinci tık → kapalı kaldı
      openPanel(panel);
      markBtn(btn, true);
    });
  });

  /* Dışarı tık → hepsini kapat (şablon §12) */
  document.addEventListener('click', function () { closeAll(document); });

  /* ESC → kapat */
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') closeAll(document);
  });

  /* Home page parity with the upstream Chisfis demo.  The public storefront
     keeps its own URLs, while the visible first-screen structure and labels
     follow the reference demo. */
  function applyHomeDemoParity() {
    if (!document.body.classList.contains('chisfis-home')) return;

    var parityStyle = document.createElement('style');
    parityStyle.textContent =
      '.chisfis-home .chisfis-header-root .container,.chisfis-home main>.container{max-width:1280px}' +
      '.chisfis-home #theme-picker-wrap{display:flex;align-items:center}' +
      '.chisfis-home .hero-search-form form>div{min-width:0}';
    document.head.appendChild(parityStyle);

    var themeWrap = document.getElementById('theme-picker-wrap');
    if (themeWrap) {
      var accountWrap = themeWrap.lastElementChild;
      Array.prototype.slice.call(themeWrap.children).forEach(function (child) {
        if (child !== accountWrap) child.remove();
      });
    }

    var hero = document.querySelector('.chisfis-home main .container > div');
    if (!hero) return;
    var title = hero.querySelector('h1');
    var intro = title && title.parentElement;
    if (title) title.textContent = 'Hotel, car, experiences';
    if (intro) {
      var copy = intro.querySelector('p');
      var cta = intro.querySelector('a');
      if (copy) copy.textContent = 'With us, your trip is filled with amazing experiences.';
      if (cta) cta.textContent = 'Start your search';
    }

    var tabs = hero.querySelectorAll('[role="tablist"] [role="tab"]');
    var labels = ['Stays', 'Cars', 'Experiences', 'RealEstates', 'Flights'];
    Array.prototype.forEach.call(tabs, function (tab, index) {
      if (labels[index]) tab.textContent = labels[index];
    });

    /* Misafir alanı ARTIK SUNUCUDAN geliyor: export ana sayfasının hero
       formunda gerçek guests alanı (3 stepper + `input[name="guests"]`)
       var. Burada JS ile sahte bir alan enjekte etmek onu ikizlerdi —
       üstelik enjekte edilen alan sayaçsızdı ve hiçbir yere değer
       göndermiyordu. */
  }

  applyHomeDemoParity();
})();
