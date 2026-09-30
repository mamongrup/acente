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
        'Travelers<i class="hgi-stroke hgi-arrow-down-01 ms-1 size-4 group-data-open:rotate-180" aria-hidden="true"></i></button>';
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

  // The current travel/mega menus replaced the demo guest and explore menus.
  // Their copy is client-rendered, so SSR translation cannot reach it.
  var MENU_COPY = {
    tr: ['Konaklama', 'Mükemmel konaklama yerini bulun', 'Tatil evleri', 'Villa, apart, bungalov ve rezidans', 'Araç kiralama', 'Size uygun aracı bulun', 'Deneyimler', 'Size uygun deneyimi bulun', 'Uçuşlar', 'Size uygun uçuşu bulun', 'Yolculuğa başlayın', 'Konaklama, araç veya deneyim keşfedin', 'Ana sayfa', 'Kategoriler', 'Haritada ara', 'İlan sayfaları', 'Konaklama ilanları', 'Araç ilanları', 'Deneyim ilanları', 'Tatil evi ilanları', 'Diğer sayfalar', 'Ev sahibi profili', 'Blog', 'Ödeme', 'İletişim', 'Giriş/Kayıt', 'Hesap', 'İlan ekle', 'Koleksiyon', 'Soğuğun tadını çıkarın', 'Daha fazlası', 'Otobüs'],
    de: ['Unterkünfte', 'Finden Sie die passende Unterkunft', 'Ferienhäuser', 'Villa, Apartment, Bungalow und Residenz', 'Mietwagen', 'Finden Sie das passende Auto', 'Erlebnisse', 'Finden Sie das passende Erlebnis', 'Flüge', 'Finden Sie den passenden Flug', 'Reise beginnen', 'Unterkunft, Auto oder Erlebnis entdecken', 'Startseite', 'Kategorien', 'Auf Karte suchen', 'Angebotsseiten', 'Unterkünfte', 'Mietwagen', 'Erlebnisse', 'Ferienhäuser', 'Weitere Seiten', 'Gastgeberprofil', 'Blog', 'Buchung', 'Kontakt', 'Anmelden/Registrieren', 'Konto', 'Inserat erstellen', 'Kollektion', 'Genießen Sie die Kälte', 'Mehr anzeigen', 'Bus'],
    ru: ['Проживание', 'Найдите идеальное жильё', 'Дома для отдыха', 'Вилла, апартаменты, бунгало и резиденция', 'Аренда авто', 'Найдите подходящий автомобиль', 'Впечатления', 'Найдите подходящее впечатление', 'Авиабилеты', 'Найдите подходящий рейс', 'Начните путешествие', 'Найдите жильё, автомобиль или впечатление', 'Главная', 'Категории', 'Поиск на карте', 'Страницы объявлений', 'Жильё', 'Автомобили', 'Впечатления', 'Дома для отдыха', 'Другие страницы', 'Профиль хозяина', 'Блог', 'Бронирование', 'Контакты', 'Вход/Регистрация', 'Аккаунт', 'Добавить объявление', 'Коллекция', 'Насладитесь холодом', 'Подробнее', 'Автобус'],
    fr: ['Séjours', 'Trouvez le séjour idéal', 'Locations de vacances', 'Villa, appartement, bungalow et résidence', 'Location de voitures', 'Trouvez la voiture idéale', 'Expériences', 'Trouvez une expérience', 'Vols', 'Trouvez le vol idéal', 'Commencez votre voyage', 'Découvrez un séjour, une voiture ou une expérience', 'Accueil', 'Catégories', 'Rechercher sur la carte', 'Pages des annonces', 'Hébergements', 'Voitures', 'Expériences', 'Locations de vacances', 'Autres pages', 'Profil hôte', 'Blog', 'Réservation', 'Contact', 'Connexion/Inscription', 'Compte', 'Ajouter une annonce', 'Collection', 'Profitez du grand froid', 'Voir plus', 'Bus'],
    zh: ['住宿', '寻找理想住宿', '度假屋', '别墅、公寓、平房及住宅', '租车', '寻找合适的车辆', '体验', '寻找精彩体验', '航班', '寻找合适航班', '开启旅程', '探索住宿、租车或体验', '首页', '分类', '地图搜索', '房源页面', '住宿房源', '租车房源', '体验项目', '度假屋房源', '其他页面', '房东资料', '博客', '预订', '联系', '登录/注册', '账户', '发布房源', '精选', '享受冬日之美', '查看更多', '巴士']
  };
  function menuText(index) {
    var english = ['Stays', 'Find the perfect place to stay', 'Holiday homes', 'Villa, apart, bungalow and residence', 'Car rentals', 'Find the perfect car to rent', 'Experiences', 'Find the perfect experience', 'Flights', 'Find the perfect flight', 'Start your journey', 'Find a place to stay, car to rent, or experience to enjoy', 'Home Page', 'Categories', 'Search with Map', 'Listing Pages', 'Stay listing', 'Car listing', 'Experience listing', 'Holiday home listing', 'Other Pages', 'Host profile', 'Blog', 'Checkout', 'Contact', 'Login/Signup', 'Account', 'Add listing', 'Collection', 'Enjoy the great cold', 'Show more', 'Bus'];
    var lang = (window.NEXUS_LOCALE && window.NEXUS_LOCALE.lang) || document.documentElement.lang || 'en';
    return (MENU_COPY[lang] || english)[index];
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
        ' href="' + window.NEXUS_CATEGORY_URL(slug) + '"' +
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
    ['yacht', 'hgi-sailboat-coastal', 'Yacht rental'],
    ['tour', 'hgi-hot-air-balloon', 'Tours'],
    ['activity', 'hgi-ticket-01', 'Activities'],
  ];

  var CATALOG_ITEMS = [
    ['hotel', 'hgi-building-03'], ['holiday_home', 'hgi-home-01'],
    ['yacht', 'hgi-anchor'], ['car', 'hgi-car-01'],
    ['tour', 'hgi-hot-air-balloon'], ['activity', 'hgi-compass'],
    ['cruise', 'hgi-cargo-ship'], ['ferry', 'hgi-ferry-boat'],
    ['transfer', 'hgi-bus-01'], ['flight', 'hgi-airplane-01'],
    ['visa', 'hgi-passport'], ['pilgrimage', 'hgi-mosque-01']
  ];
  var CATALOG_COPY = {
    tr: [
      ['Oteller','Butik otelden 5 yıldızlı tesislere'], ['Tatil evleri','Villa, dağ evi ve günlük kiralıklar'],
      ['Yat kiralama','Gulet, katamaran ve motor yat'], ['Araç kiralama','Yolculuğunuza uygun aracı bulun'],
      ['Turlar','Günübirlik ve rehberli şehir turları'], ['Aktiviteler','Dalış, su sporları ve deneyimler'],
      ['Kruvaziyer','Akdeniz ve Ege rotaları'], ['Feribot','Türkiye, Yunanistan, Kıbrıs seferleri'],
      ['Transfer','Havalimanı ve özel transfer'], ['Uçuşlar','Uçuş ara ve karşılaştır'],
      ['Vize hizmetleri','180+ ülke için başvuru desteği'], ['Hac ve Umre','Kutsal şehirlere yönelik paketler']
    ],
    en: [
      ['Hotels','From boutique to five-star stays'], ['Holiday homes','Villas, cabins and daily rentals'],
      ['Yacht rental','Gulets, catamarans and motor yachts'], ['Car rental','Find the right car for your trip'],
      ['Tours','Day trips and guided city tours'], ['Activities','Diving, water sports and experiences'],
      ['Cruises','Mediterranean and Aegean routes'], ['Ferries','Türkiye, Greece and Cyprus routes'],
      ['Transfers','Airport and private transfers'], ['Flights','Search and compare flights'],
      ['Visa services','Application help for 180+ countries'], ['Hajj and Umrah','Packages for the holy cities']
    ],
    de: [
      ['Hotels','Vom Boutique- bis zum Fünf-Sterne-Hotel'], ['Ferienhäuser','Villen, Hütten und Tagesmieten'],
      ['Yachtcharter','Gulets, Katamarane und Motoryachten'], ['Mietwagen','Das passende Auto für Ihre Reise'],
      ['Touren','Tagesausflüge und Stadtführungen'], ['Aktivitäten','Tauchen, Wassersport und Erlebnisse'],
      ['Kreuzfahrten','Routen im Mittelmeer und in der Ägäis'], ['Fähren','Türkei, Griechenland und Zypern'],
      ['Transfers','Flughafen- und Privattransfers'], ['Flüge','Flüge suchen und vergleichen'],
      ['Visadienste','Antragshilfe für über 180 Länder'], ['Hadsch und Umra','Pakete für die heiligen Städte']
    ],
    ru: [
      ['Отели','От бутик-отелей до пяти звёзд'], ['Дома для отдыха','Виллы, домики и посуточная аренда'],
      ['Аренда яхт','Гулеты, катамараны и моторные яхты'], ['Аренда авто','Найдите автомобиль для поездки'],
      ['Туры','Однодневные и городские экскурсии'], ['Развлечения','Дайвинг, водный спорт и отдых'],
      ['Круизы','Маршруты по Средиземному и Эгейскому морям'], ['Паромы','Турция, Греция и Кипр'],
      ['Трансферы','Аэропортовые и частные трансферы'], ['Авиабилеты','Поиск и сравнение рейсов'],
      ['Визы','Помощь с заявками в 180+ стран'], ['Хадж и умра','Пакеты в священные города']
    ],
    fr: [
      ['Hôtels','Du boutique-hôtel au cinq étoiles'], ['Maisons de vacances','Villas, chalets et locations courtes'],
      ['Location de yachts','Goélettes, catamarans et yachts'], ['Location de voiture','La voiture adaptée à votre voyage'],
      ['Circuits','Excursions et visites guidées'], ['Activités','Plongée, sports nautiques et loisirs'],
      ['Croisières','Routes méditerranéennes et égéennes'], ['Ferries','Turquie, Grèce et Chypre'],
      ['Transferts','Aéroport et transferts privés'], ['Vols','Rechercher et comparer les vols'],
      ['Services de visa','Aide pour plus de 180 pays'], ['Hajj et Omra','Séjours vers les villes saintes']
    ],
    zh: [
      ['酒店','从精品酒店到五星级住宿'], ['度假屋','别墅、木屋及短租'],
      ['游艇租赁','古莱特、双体船及机动游艇'], ['租车','寻找适合旅程的车辆'],
      ['旅游线路','一日游与城市导览'], ['活动','潜水、水上运动与体验'],
      ['邮轮','地中海及爱琴海航线'], ['渡轮','土耳其、希腊及塞浦路斯航线'],
      ['接送服务','机场及私人接送'], ['航班','搜索并比较航班'],
      ['签证服务','180多个国家申请协助'], ['朝觐与副朝','圣城旅行套餐']
    ]
  };
  function catalogMarkup() {
    var lang = (window.NEXUS_LOCALE && window.NEXUS_LOCALE.lang) || document.documentElement.lang || 'tr';
    var copy = CATALOG_COPY[lang] || CATALOG_COPY.en;
    return '<div class="nc-travel"><div class="nc-travel__grid">' + CATALOG_ITEMS.map(function (item, index) {
      var active = isActiveCategory(item[0]);
      return '<a class="nc-travel__item' + (active ? ' nc-travel__item--active' : '') + '" href="' + window.NEXUS_CATEGORY_URL(item[0]) + '"' + (active ? ' aria-current="page"' : '') + '>' +
        '<span class="nc-travel__icon"><i class="hgi-stroke ' + item[1] + '" aria-hidden="true"></i></span><span class="nc-travel__copy"><strong>' + copy[index][0] + '</strong><small>' + copy[index][1] + '</small></span></a>';
    }).join('') + '</div><a class="nc-travel__journey" href="/urunler"><strong>' + menuText(10) + '</strong><small>' + menuText(11) + '</small></a></div>';
  }

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
        return catalogMarkup();
      }
    },
    'popover-button-2': {
      align: 'start',
      render: function () {
        return '<div class="nc-mega">' +
          '<div><div class="nc-pop__head">' + menuText(12) + '</div><a class="nc-pop__link" href="/">' + menuText(0) + '</a><a class="nc-pop__link" href="' + window.NEXUS_CATEGORY_URL('holiday_home') + '">' + menuText(2) + '</a><a class="nc-pop__link" href="' + window.NEXUS_CATEGORY_URL('tour') + '">' + menuText(6) + '</a><a class="nc-pop__link" href="' + window.NEXUS_CATEGORY_URL('car') + '">' + menuText(4) + '</a><a class="nc-pop__link" href="' + window.NEXUS_CATEGORY_URL('flight') + '">' + menuText(8) + '</a><a class="nc-pop__link" href="' + window.NEXUS_CATEGORY_URL('bus') + '">' + menuText(31) + '</a></div>' +
          '<div><div class="nc-pop__head">' + menuText(13) + '</div>' + discoverLinks(CATEGORY_ITEMS) + '<a class="nc-pop__link" href="/urunler">' + menuText(14) + '</a></div>' +
          '<div><div class="nc-pop__head">' + menuText(15) + '</div><a class="nc-pop__link" href="/urunler">' + menuText(16) + '</a><a class="nc-pop__link" href="' + window.NEXUS_CATEGORY_URL('car') + '">' + menuText(17) + '</a><a class="nc-pop__link" href="' + window.NEXUS_CATEGORY_URL('tour') + '">' + menuText(18) + '</a><a class="nc-pop__link" href="' + window.NEXUS_CATEGORY_URL('holiday_home') + '">' + menuText(19) + '</a></div>' +
          '<div><div class="nc-pop__head">' + menuText(20) + '</div><a class="nc-pop__link" href="/iletisim">' + menuText(21) + '</a><a class="nc-pop__link" href="/iletisim">' + menuText(22) + '</a><a class="nc-pop__link" href="/urunler">' + menuText(23) + '</a><a class="nc-pop__link" href="/iletisim">' + menuText(24) + '</a><a class="nc-pop__link" href="/login">' + menuText(25) + '</a><a class="nc-pop__link" href="/hesap">' + menuText(26) + '</a><a class="nc-pop__link" href="/login">' + menuText(27) + '</a></div>' +
          '<div class="nc-mega__collection"><img src="/static/chisfis/images/pexels-photo-5764100.jpg" alt=""><span>' + menuText(28) + '</span><strong>' + menuText(29) + '</strong><a href="/urunler">' + menuText(30) + '</a></div>' +
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
        { code: 'TRY', symbol: '₺' },
        { code: 'EUR', symbol: '€' },
        { code: 'USD', symbol: '$' },
        { code: 'GBP', symbol: '£' },
        { code: 'RUB', symbol: '₽' },
        { code: 'CNY', symbol: '¥' }
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
      var symbol = { TRY: '₺', EUR: '€', USD: '$', GBP: '£', RUB: '₽', CNY: '¥' }[code] || '';
      return '<span class="mm-pop__currency-icon" aria-hidden="true">' + symbol + '</span>';
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
        pane.innerHTML = L.langs.map(function (l) { return optHTML('lang', l.code, l.main, ''); }).join('');
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

    /* Hero text and category tabs are rendered by the page and the category
       rail. Rewriting them here after localization caused visible text flips. */
  }

  applyHomeDemoParity();
})();


/* Category landings use the shared hero and a single results/filter surface. */
(function renderCategoryResults() {
  if (!document.body.classList.contains('category-page')) return;
  var revealCategory = function () { document.body.classList.remove('category-results-pending'); };
  var revealTimeout = window.setTimeout(revealCategory, 8000);
  var main = document.querySelector('.category-page main');
  var resultsRoot = main && main.querySelector('.category-results-root');
  if (!resultsRoot || main.dataset.categoryResultsReady) { window.clearTimeout(revealTimeout); revealCategory(); return; }
  main.dataset.categoryResultsReady = 'true';
  var category = window.NEXUS_CATEGORY_CODE(location.pathname);
  if (!category) { window.clearTimeout(revealTimeout); revealCategory(); return; }
  var categoryContent = window.NEXUS_CATEGORY_CONTENT && window.NEXUS_CATEGORY_CONTENT[category];
  var hero = main.querySelector('.relative.container > div');
  var heroMosaic;
  var mosaicFallback = {
    hotel: ['pexels-photo-6129967.home.webp', 'pexels-photo-261394.home.webp', 'pexels-photo-2861361.home.webp', 'pexels-photo-2677398.home.webp'],
    holiday_home: ['pexels-photo-6129967.home.webp', 'pexels-photo-1320686.home.webp', 'pexels-photo-7163619.home.webp', 'pexels-photo-6527036.home.webp'],
    yacht: ['pexels-photo-131423.home.webp', 'pexels-photo-186077.home.webp', 'pexels-photo-1660995.home.webp', 'pexels-photo-2549018.home.webp'],
    tour: ['pexels-photo-739407.home.webp', 'pexels-photo-7740160.home.webp', 'pexels-photo-460672.home.webp', 'pexels-photo-7031413.home.webp'],
    activity: ['pexels-photo-247532.home.webp', 'pexels-photo-2869499.home.webp', 'pexels-photo-7031413.home.webp', 'pexels-photo-32223288.home.webp']
  };
  var defaultMosaic = mosaicFallback[category] || mosaicFallback.tour;
  function mosaicImages() {
    if (!heroMosaic) return;
    var heroConfig = {};
    document.querySelectorAll('.builder-source-section').forEach(function (block) {
      try {
        var config = JSON.parse(block.dataset.sectionConfig || '{}');
        if (config.sectionKey === 'hero') heroConfig = config;
      } catch (_) {}
    });
    heroMosaic.querySelectorAll('img').forEach(function (image, index) {
      var fallbackUrl = '/static/chisfis/images/' + defaultMosaic[index];
      image.onerror = function () { if (image.src !== new URL(fallbackUrl, location.origin).href) image.src = fallbackUrl; };
      var configured = Array.isArray(heroConfig.images) ? String(heroConfig.images[index] || '').trim() : '';
      var source = /^(https?:\/\/|\/(?!\/))/i.test(configured) ? configured : (image.getAttribute('src') || fallbackUrl);
      if (image.src !== new URL(source, location.origin).href) image.src = source;
    });
  }
  if (hero && categoryContent) {
    var heroTitle = hero.querySelector('h1');
    var heroCopy = hero.querySelector('h1 + p');
    var heroImage = hero.querySelector('img');
    if (heroTitle) { heroTitle.removeAttribute('data-i18n'); heroTitle.textContent = categoryContent.heroTitle || categoryContent.title; }
    if (heroCopy) heroCopy.textContent = categoryContent.description;
    heroMosaic = hero.querySelector('.category-hero-mosaic');
    if (heroImage && !heroMosaic) {
      heroMosaic = document.createElement('div');
      heroMosaic.className = 'category-hero-mosaic';
      heroMosaic.setAttribute('aria-label', categoryContent.title + ' görselleri');
      for (var imageIndex = 0; imageIndex < 3; imageIndex++) {
        var tile = document.createElement('img');
        tile.alt = '';
        tile.decoding = 'async';
        if (imageIndex > 0) tile.loading = 'lazy';
        heroMosaic.appendChild(tile);
      }
      heroImage.replaceWith(heroMosaic);
    }
    if (heroMosaic) mosaicImages();
  }
  var titles = {
    hotel: 'Konaklama seçenekleri', holiday_home: 'Tatil seçenekleri',
    yacht: 'Deniz deneyimleri', tour: 'Deneyim rotaları',
    activity: 'Deneyim seçenekleri', flight: 'Ulaşım seçenekleri',
    car: 'Araç seçenekleri', cruise: 'Deniz rotaları',
    pilgrimage: 'Seyahat seçenekleri', visa: 'Seyahat hizmetleri',
    ferry: 'Sefer seçenekleri', transfer: 'Transfer hizmetleri',
    beach: 'Plaj seçenekleri', cinema: 'Film seçenekleri',
    event: 'Etkinlik seçenekleri', restaurant: 'Yeme içme seçenekleri',
    bus: 'Ulaşım seçenekleri'
  };
  var listUrl = new URL('/urunler', location.origin);
  listUrl.searchParams.set('kategori', category);
  listUrl.searchParams.set('view', 'list');
  var categoryMapUrl = new URL(location.href);
  categoryMapUrl.searchParams.set('view', 'map');
  var categoryListUrl = new URL(location.href);
  categoryListUrl.searchParams.delete('view');
  var head = document.createElement('div');
  head.className = 'category-results-head';
  head.style.visibility = 'hidden';
  head.setAttribute('aria-busy', 'true');
  var copy = document.createElement('div');
  var heading = document.createElement('h1');
  heading.textContent = titles[category] || 'Seçenekler';
  var description = document.createElement('p');
  description.textContent = 'Fiyatları ve seçenekleri karşılaştırın.';
  copy.appendChild(heading);
  copy.appendChild(description);
  head.appendChild(copy);
  var listLink = document.createElement('a');
  listLink.href = categoryMapUrl.pathname + categoryMapUrl.search;
  listLink.textContent = 'Haritada Gör ↗';
  head.appendChild(listLink);
  var filter = document.createElement('div');
  filter.className = 'category-demo-filter';
  var allFilters = document.createElement('button');
  allFilters.className = 'filter-all';
  allFilters.type = 'button';
  allFilters.setAttribute('aria-haspopup', 'dialog');
  allFilters.setAttribute('aria-expanded', 'false');
  allFilters.textContent = '⚙  Tüm filtreler';
  filter.appendChild(allFilters);
  var divider = document.createElement('span');
  divider.className = 'filter-divider';
  filter.appendChild(divider);
  filter.addEventListener('toggle', function (event) {
    var opened = event.target;
    if (!opened.matches || !opened.matches('.category-filter-dropdown') || !opened.open) return;
    filter.querySelectorAll('.category-filter-dropdown[open]').forEach(function (dropdown) {
      if (dropdown !== opened) dropdown.open = false;
    });
  }, true);
  document.addEventListener('pointerdown', function (event) {
    if (event.target.closest && event.target.closest('.category-filter-dropdown')) return;
    filter.querySelectorAll('.category-filter-dropdown[open]').forEach(function (dropdown) {
      dropdown.open = false;
    });
  });
  main.insertBefore(head, resultsRoot);
  main.insertBefore(filter, resultsRoot);
  resultsRoot.remove();
  var builder = main.querySelector('.published-builder-modules');
  if (builder) main.appendChild(builder);
  var allItems = [];
  var filterGroups = [];
  var visibleItems = [];
  var mapShell = null, mapList = null, mapCanvas = null, mapInstance = null, mapMarkers = null;
  var mapLibraryPromise = null;
  function loadMapLibrary() {
    if (window.maplibregl) return Promise.resolve(window.maplibregl);
    if (mapLibraryPromise) return mapLibraryPromise;
    if (!document.querySelector('link[data-category-map-css]')) {
      var mapCss = document.createElement('link');
      mapCss.rel = 'stylesheet'; mapCss.href = '/static/vendor/maplibre/maplibre-gl.css';
      mapCss.dataset.categoryMapCss = 'true'; document.head.appendChild(mapCss);
    }
    mapLibraryPromise = new Promise(function (resolve, reject) {
      var script = document.createElement('script');
      script.src = '/static/vendor/maplibre/maplibre-gl.js';
      script.onload = function () { window.maplibregl ? resolve(window.maplibregl) : reject(new Error('map-library')); };
      script.onerror = function () { reject(new Error('map-library')); };
      document.head.appendChild(script);
    });
    return mapLibraryPromise;
  }
  function mapPosition(item) {
    var lat = Number(item.latitude), lon = Number(item.longitude);
    if (item.latitude !== '' && item.longitude !== '' && Number.isFinite(lat) && Number.isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180) return { lat: lat, lon: lon, approximate: false };
    var place = String(item.locality || '').toLocaleLowerCase('tr-TR');
    if (place.indexOf('yalıkavak') >= 0 || place.indexOf('yalikavak') >= 0) return { lat: 37.105, lon: 27.293, approximate: true };
    if (place.indexOf('bodrum') >= 0) return { lat: 37.034, lon: 27.430, approximate: true };
    return null;
  }
  function updateMapMarkers(items) {
    if (!mapInstance || !mapMarkers) return;
    mapMarkers.forEach(function (marker) { marker.remove(); });
    mapMarkers = [];
    var bounds = [];
    var missing = 0;
    items.forEach(function (item) {
      var position = mapPosition(item);
      if (!position) { missing++; return; }
      var amount = Number(item.priceMinor) / 100;
      var label = Number.isFinite(amount) ? new Intl.NumberFormat('tr-TR', { style:'currency', currency:item.currency || 'TRY', maximumFractionDigits:0 }).format(amount) : 'İlan';
      var icon = document.createElement('div'); icon.className = 'category-map-price-icon';
      var price = document.createElement('span'); price.textContent = label; icon.appendChild(price);
      var marker = new window.maplibregl.Marker({ element:icon }).setLngLat([position.lon, position.lat]).addTo(mapInstance);
      mapMarkers.push(marker);
      var popup = document.createElement('div');
      var title = document.createElement('strong'); title.textContent = item.title || 'İlan'; popup.appendChild(title);
      var locationText = document.createElement('small'); locationText.textContent = (position.approximate ? 'Yaklaşık konum · ' : '') + (item.locality || ''); popup.appendChild(locationText);
      var details = document.createElement('a'); details.href = window.NEXUS_LISTING_URL ? window.NEXUS_LISTING_URL(item) : '/urunler/' + encodeURIComponent(item.id); details.textContent = 'İlanı gör →'; popup.appendChild(details);
      marker.setPopup(new window.maplibregl.Popup({ offset:20 }).setDOMContent(popup));
      icon.addEventListener('click', function () {
        var cardNode = mapList && mapList.querySelector('[data-listing-id="' + CSS.escape(String(item.id)) + '"]');
        if (cardNode) { cardNode.classList.add('category-map-card-active'); cardNode.scrollIntoView({ block:'nearest', behavior:'smooth' }); window.setTimeout(function () { cardNode.classList.remove('category-map-card-active'); }, 1800); }
      });
      bounds.push([position.lon, position.lat]);
    });
    var notice = mapShell && mapShell.querySelector('.category-map-notice');
    if (notice) { notice.textContent = missing ? missing + ' ilanın harita konumu henüz tanımlı değil.' : ''; notice.hidden = !missing; }
    if (bounds.length === 1) mapInstance.jumpTo({ center:bounds[0], zoom:12 });
    else if (bounds.length > 1) mapInstance.fitBounds(bounds.reduce(function (box, point) { return box.extend(point); }, new window.maplibregl.LngLatBounds(bounds[0], bounds[0])), { padding:60, maxZoom:13, duration:0 });
    else mapInstance.jumpTo({ center:[35.0, 39.0], zoom:6 });
  }
  function setMapView(enabled) {
    if (!enabled) {
      if (mapShell) {
        main.insertBefore(head, mapShell);
        main.insertBefore(filter, mapShell);
        var preview = mapList.querySelector('.category-listing-preview, .category-empty-state');
        if (preview) main.insertBefore(preview, mapShell);
        if (mapInstance) { mapInstance.remove(); mapInstance = null; mapMarkers = null; }
        mapShell.remove(); mapShell = null; mapList = null; mapCanvas = null;
      }
      document.body.classList.remove('category-map-view');
      listLink.textContent = 'Haritada Gör ↗'; listLink.href = categoryMapUrl.pathname + categoryMapUrl.search;
      return Promise.resolve();
    }
    if (mapShell) { updateMapMarkers(visibleItems); return Promise.resolve(); }
    mapShell = document.createElement('div'); mapShell.className = 'category-map-layout';
    mapList = document.createElement('div'); mapList.className = 'category-map-list';
    var mapPanel = document.createElement('aside'); mapPanel.className = 'category-map-panel'; mapPanel.setAttribute('aria-label', 'İlan haritası');
    mapCanvas = document.createElement('div'); mapCanvas.className = 'category-map-canvas'; mapPanel.appendChild(mapCanvas);
    var mapClose = document.createElement('button'); mapClose.type = 'button'; mapClose.className = 'category-map-close'; mapClose.setAttribute('aria-label', 'Haritayı kapat'); mapClose.textContent = '×'; mapPanel.appendChild(mapClose);
    mapClose.addEventListener('click', function () { history.pushState({ categoryMap:false }, '', categoryListUrl.pathname + categoryListUrl.search); setMapView(false); });
    var notice = document.createElement('p'); notice.className = 'category-map-notice'; notice.hidden = true; mapPanel.appendChild(notice);
    main.insertBefore(mapShell, head);
    mapShell.appendChild(mapList); mapShell.appendChild(mapPanel);
    mapList.appendChild(head); mapList.appendChild(filter);
    var preview = main.querySelector('.category-listing-preview');
    if (preview) mapList.appendChild(preview);
    document.body.classList.add('category-map-view');
    listLink.textContent = 'Listeyi Gör ←'; listLink.href = categoryListUrl.pathname + categoryListUrl.search;
    return loadMapLibrary().then(function () {
      if (!mapCanvas) return;
      window.maplibregl.setWorkerUrl('/static/vendor/maplibre/maplibre-gl-csp-worker.js');
      mapInstance = new window.maplibregl.Map({ container:mapCanvas, style:'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json', center:[35,39], zoom:6 });
      mapInstance.addControl(new window.maplibregl.NavigationControl({ showCompass:false }), 'bottom-right');
      mapMarkers = [];
      mapInstance.on('load', function () { updateMapMarkers(visibleItems); mapInstance.resize(); });
    }).catch(function () { if (mapCanvas) mapCanvas.textContent = 'Harita yüklenemedi. Lütfen yeniden deneyin.'; });
  }
  listLink.addEventListener('click', function (event) {
    event.preventDefault();
    var enabled = !document.body.classList.contains('category-map-view');
    history.pushState({ categoryMap:enabled }, '', enabled ? categoryMapUrl.pathname + categoryMapUrl.search : categoryListUrl.pathname + categoryListUrl.search);
    setMapView(enabled);
    window.scrollTo({ top:0, behavior:'instant' });
  });
  window.addEventListener('popstate', function () { setMapView(new URL(location.href).searchParams.get('view') === 'map'); });
  var filterDialog = document.createElement('div');
  filterDialog.className = 'category-filter-modal';
  filterDialog.hidden = true;
  filterDialog.innerHTML = '<div class="category-filter-panel" role="dialog" aria-modal="true" aria-labelledby="category-filter-title"><header><h2 id="category-filter-title">Filtreler</h2><button class="category-filter-close" type="button" aria-label="Filtreleri kapat">×</button></header><div class="category-filter-modal-body"><p>Filtreler yükleniyor…</p></div><footer><button class="category-filter-reset" type="button">Tümünü temizle</button><button class="category-filter-apply" type="button">Uygula</button></footer></div>';
  document.body.appendChild(filterDialog);
  var dialogBody = filterDialog.querySelector('.category-filter-modal-body');
  var applyButton = filterDialog.querySelector('.category-filter-apply');
  var previousFocus = null;
  var previousOverflow = '';
  function closeFilters() {
    filterDialog.hidden = true;
    document.body.style.overflow = previousOverflow;
    allFilters.setAttribute('aria-expanded', 'false');
    if (previousFocus) previousFocus.focus();
  }
  allFilters.addEventListener('click', function () {
    filter.querySelectorAll('.category-filter-dropdown[open]').forEach(function (dropdown) { dropdown.open = false; });
    previousFocus = document.activeElement;
    previousOverflow = document.body.style.overflow;
    filterDialog.hidden = false;
    document.body.style.overflow = 'hidden';
    allFilters.setAttribute('aria-expanded', 'true');
    filterDialog.querySelector('.category-filter-close').focus();
  });
  filterDialog.querySelector('.category-filter-close').addEventListener('click', closeFilters);
  filterDialog.addEventListener('click', function (event) { if (event.target === filterDialog) closeFilters(); });
  filterDialog.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') { event.preventDefault(); closeFilters(); }
    if (event.key !== 'Tab') return;
    var focusable = Array.prototype.slice.call(filterDialog.querySelectorAll('button, input:not(:disabled)'));
    var first = focusable[0], last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  });
  var priceMin = null, priceMax = null, sortOrder = 'default';
  function renderFilterGroups(groups) {
    dialogBody.replaceChildren();
    if (!groups.length) {
      var empty = document.createElement('p');
      empty.textContent = 'Bu kategori için henüz filtre tanımlanmamış.';
      dialogBody.appendChild(empty);
    }
    groups.forEach(function (group) {
      if (!group || !Array.isArray(group.items) || !group.items.length) return;
      var fieldset = document.createElement('fieldset');
      var legend = document.createElement('legend');
      legend.textContent = group.title || group.key;
      fieldset.appendChild(legend);
      if (group.helpText) {
        var help = document.createElement('p');
        help.textContent = group.helpText;
        fieldset.appendChild(help);
      }
      var choices = document.createElement('div');
      choices.className = 'category-filter-modal-choices';
      group.items.forEach(function (item) {
        var label = document.createElement('label');
        var input = document.createElement('input');
        input.type = group.multiple ? 'checkbox' : 'radio';
        input.name = 'category-filter-' + group.key;
        input.value = item.contractValue || item.key;
        input.dataset.group = group.key;
        input.dataset.fieldKey = item.contractFieldKey || group.key;
        var text = document.createElement('span');
        text.textContent = item.title || item.key;
        label.appendChild(input);
        label.appendChild(text);
        choices.appendChild(label);
      });
      fieldset.appendChild(choices);
      dialogBody.appendChild(fieldset);
    });
    var priceSet = document.createElement('fieldset');
    priceSet.className = 'category-filter-price-set';
    priceSet.innerHTML = '<legend>Fiyat</legend><p>Gecelik veya ilan fiyatı</p><div class="category-price-inputs"><label>En düşük<input type="number" min="0" inputmode="numeric" class="category-price-min" placeholder="₺ Min"></label><label>En yüksek<input type="number" min="0" inputmode="numeric" class="category-price-max" placeholder="₺ Max"></label></div>';
    dialogBody.appendChild(priceSet);
    priceSet.querySelector('.category-price-min').value = priceMin == null ? '' : priceMin;
    priceSet.querySelector('.category-price-max').value = priceMax == null ? '' : priceMax;
  }
  function selectedFilters() {
    return Array.prototype.slice.call(dialogBody.querySelectorAll('input:checked')).map(function (input) {
      return { group: input.dataset.group, key: input.dataset.fieldKey, value: input.value };
    });
  }
  function fetchFilteredItem(selection) {
    var url = new URL('/api/public/listings', location.origin);
    url.searchParams.set('kategori', category);
    url.searchParams.set('filter_key', selection.key);
    url.searchParams.set('filter_value', selection.value);
    if (document.body.dataset.tenant) url.searchParams.set('tenant', document.body.dataset.tenant);
    return fetch(url.pathname + url.search, { credentials: 'same-origin', cache: 'no-store' })
      .then(function (response) { if (!response.ok) throw new Error('listings'); return response.json(); });
  }
  function applyFilters() {
    var selections = selectedFilters();
    applyButton.disabled = true;
    applyButton.textContent = 'Yükleniyor…';
    var groups = {};
    selections.forEach(function (selection) { (groups[selection.group] || (groups[selection.group] = [])).push(selection); });
    var requests = Object.keys(groups).map(function (key) {
      return Promise.all(groups[key].map(fetchFilteredItem)).then(function (lists) {
        var seen = {};
        return lists.reduce(function (merged, list) {
          list.forEach(function (item) { if (!seen[item.id]) { seen[item.id] = true; merged.push(item); } });
          return merged;
        }, []);
      });
    });
    Promise.all(requests).then(function (lists) {
      var items = lists.length ? lists[0].filter(function (item) {
        return lists.slice(1).every(function (other) { return other.some(function (candidate) { return candidate.id === item.id; }); });
      }) : allItems;
      var minInput = dialogBody.querySelector('.category-price-min');
      var maxInput = dialogBody.querySelector('.category-price-max');
      priceMin = minInput && minInput.value !== '' ? Number(minInput.value) : null;
      priceMax = maxInput && maxInput.value !== '' ? Number(maxInput.value) : null;
      if (priceMin != null) items = items.filter(function (item) { return Number(item.priceMinor) / 100 >= priceMin; });
      if (priceMax != null) items = items.filter(function (item) { return Number(item.priceMinor) / 100 <= priceMax; });
      items = items.slice();
      if (sortOrder === 'price-asc') items.sort(function (a, b) { return Number(a.priceMinor) - Number(b.priceMinor); });
      if (sortOrder === 'price-desc') items.sort(function (a, b) { return Number(b.priceMinor) - Number(a.priceMinor); });
      renderResults(items);
      allFilters.textContent = '⚙  Tüm filtreler';
      if (selections.length) {
        var badge = document.createElement('b');
        badge.textContent = selections.length;
        allFilters.appendChild(badge);
      }
      filter.querySelectorAll('.category-filter-dropdown input[data-group]').forEach(function (quickInput) {
        quickInput.checked = selections.some(function (selection) {
          return selection.group === quickInput.dataset.group && selection.value === quickInput.value;
        });
      });
      closeFilters();
    }).catch(function () {
      var error = dialogBody.querySelector('.category-filter-error');
      if (!error) { error = document.createElement('p'); error.className = 'category-filter-error'; dialogBody.prepend(error); }
      error.textContent = 'Filtreler uygulanamadı. Lütfen yeniden deneyin.';
    }).finally(function () { applyButton.disabled = false; applyButton.textContent = 'Uygula'; });
  }
  applyButton.addEventListener('click', applyFilters);
  filterDialog.querySelector('.category-filter-reset').addEventListener('click', function () {
    dialogBody.querySelectorAll('input:checked').forEach(function (input) { input.checked = false; });
    dialogBody.querySelectorAll('.category-price-inputs input').forEach(function (input) { input.value = ''; });
    priceMin = null; priceMax = null; sortOrder = 'default';
    applyFilters();
  });
  var filtersUrl = new URL('/api/public/category-filters', location.origin);
  filtersUrl.searchParams.set('category', category);
  filtersUrl.searchParams.set('lang', (window.NEXUS_LOCALE && window.NEXUS_LOCALE.lang) || document.documentElement.lang || 'tr');
  filtersUrl.searchParams.set('tenant', document.body.dataset.tenant || '');
  var filtersPromise = fetch(filtersUrl.pathname + filtersUrl.search, { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) { if (!response.ok) throw new Error('filters'); return response.json(); })
    .then(function (groups) {
      if (!Array.isArray(groups)) return;
      filterGroups = groups;
      renderFilterGroups(filterGroups);
      if (category === 'tour') {
        var tourGroup = groups.find(function (group) { return group.key === 'tour_subcategory'; });
        var tourKeys = ['tour_abroad', 'tour_culture', 'tour_cruise', 'tour_religious'];
        var tourIcons = { tour_abroad:'hgi-airplane-01', tour_culture:'hgi-building-03', tour_cruise:'hgi-cargo-ship', tour_religious:'hgi-kaaba-01' };
        if (tourGroup && Array.isArray(tourGroup.items)) {
          var tourSection = document.createElement('section');
          tourSection.className = 'category-tour-subcategories';
          tourSection.setAttribute('aria-label', tourGroup.title || 'Tur alt kategorileri');
          var tourHeading = document.createElement('div'); tourHeading.className = 'category-tour-subcategories-heading';
          var tourTitle = document.createElement('h2'); tourTitle.textContent = tourGroup.title || 'Tur alt kategorileri';
          tourHeading.appendChild(tourTitle); tourSection.appendChild(tourHeading);
          var tourGrid = document.createElement('div'); tourGrid.className = 'category-tour-subcategories-grid';
          tourKeys.forEach(function (key) {
            var item = tourGroup.items.find(function (candidate) { return candidate.key === key; });
            if (!item) return;
            var card = document.createElement('button'); card.type = 'button'; card.className = 'category-tour-subcategory';
            card.dataset.tourSubcategory = key; card.setAttribute('aria-pressed', 'false');
            var icon = document.createElement('i'); icon.className = 'hgi-stroke ' + tourIcons[key]; icon.setAttribute('aria-hidden', 'true');
            var label = document.createElement('strong'); label.textContent = item.title || key;
            var arrow = document.createElement('span'); arrow.className = 'category-tour-subcategory-arrow'; arrow.textContent = '↗'; arrow.setAttribute('aria-hidden', 'true');
            card.append(icon, label, arrow);
            card.addEventListener('click', function () {
              var value = item.contractValue || item.key;
              var input = Array.prototype.slice.call(dialogBody.querySelectorAll('input[data-group="tour_subcategory"]')).find(function (candidate) { return candidate.value === value; });
              if (!input) return;
              var wasActive = card.getAttribute('aria-pressed') === 'true';
              dialogBody.querySelectorAll('input[data-group="tour_subcategory"]').forEach(function (candidate) { candidate.checked = false; });
              tourGrid.querySelectorAll('button').forEach(function (button) { button.setAttribute('aria-pressed', 'false'); });
              if (!wasActive) { input.checked = true; card.setAttribute('aria-pressed', 'true'); }
              applyFilters();
              head.scrollIntoView({ behavior: 'smooth', block: 'start' });
            });
            tourGrid.appendChild(card);
          });
          tourSection.appendChild(tourGrid);
          main.insertBefore(tourSection, head);
          document.addEventListener('nexus:lang', function () {
            var localizedUrl = new URL(filtersUrl.href);
            localizedUrl.searchParams.set('lang', (window.NEXUS_LOCALE && window.NEXUS_LOCALE.lang) || document.documentElement.lang || 'tr');
            fetch(localizedUrl.pathname + localizedUrl.search, { credentials:'same-origin', cache:'no-store' }).then(function (response) { return response.ok ? response.json() : []; }).then(function (localizedGroups) {
              var localized = localizedGroups.find(function (group) { return group.key === 'tour_subcategory'; });
              if (!localized) return;
              tourTitle.textContent = localized.title || tourTitle.textContent;
              tourSection.setAttribute('aria-label', tourTitle.textContent);
              tourGrid.querySelectorAll('[data-tour-subcategory]').forEach(function (card) {
                var translated = localized.items.find(function (item) { return item.key === card.dataset.tourSubcategory; });
                if (translated) card.querySelector('strong').textContent = translated.title || translated.key;
              });
            }).catch(function () {});
          });
        }
      }
      groups.forEach(function (group) {
        if (!group || !Array.isArray(group.items) || !group.items.length) return;
        var dropdown = document.createElement('details');
        dropdown.className = 'category-filter-dropdown';
        var label = document.createElement('summary');
        label.textContent = group.title || group.key;
        dropdown.appendChild(label);
        var choices = document.createElement('div');
        choices.className = 'category-filter-choices';
        group.items.forEach(function (item) {
          var option = document.createElement('label');
          var check = document.createElement('input');
          check.type = group.multiple ? 'checkbox' : 'radio';
          check.name = 'quick-' + group.key;
          check.dataset.group = group.key;
          check.value = item.contractValue || item.key;
          var optionText = document.createElement('span');
          optionText.textContent = item.title || item.key;
          option.appendChild(check); option.appendChild(optionText);
          check.addEventListener('change', function () {
            var input = Array.prototype.slice.call(dialogBody.querySelectorAll('input')).find(function (candidate) {
              return candidate.dataset.group === group.key && candidate.value === (item.contractValue || item.key);
            });
            if (input) { input.checked = check.checked; applyFilters(); }
          });
          choices.appendChild(option);
        });
        dropdown.appendChild(choices);
        filter.appendChild(dropdown);
      });
      var priceDropdown = document.createElement('details');
      priceDropdown.className = 'category-filter-dropdown';
      priceDropdown.innerHTML = '<summary>Fiyat</summary><div class="category-filter-choices category-quick-price"><label>En düşük<input type="number" min="0" inputmode="numeric" placeholder="₺ Min"></label><label>En yüksek<input type="number" min="0" inputmode="numeric" placeholder="₺ Max"></label><button type="button">Uygula</button></div>';
      filter.appendChild(priceDropdown);
      priceDropdown.querySelector('button').addEventListener('click', function () {
        var values = priceDropdown.querySelectorAll('input');
        dialogBody.querySelector('.category-price-min').value = values[0].value;
        dialogBody.querySelector('.category-price-max').value = values[1].value;
        priceDropdown.open = false;
        applyFilters();
      });
      var sortDropdown = document.createElement('details');
      sortDropdown.className = 'category-filter-dropdown';
      sortDropdown.innerHTML = '<summary>Sırala</summary><div class="category-filter-choices"><button type="button" data-sort="default">Önerilen</button><button type="button" data-sort="price-asc">En düşük fiyat</button><button type="button" data-sort="price-desc">En yüksek fiyat</button></div>';
      filter.appendChild(sortDropdown);
      sortDropdown.querySelectorAll('button').forEach(function (button) { button.addEventListener('click', function () { sortOrder = button.dataset.sort; sortDropdown.open = false; applyFilters(); }); });
    })
    .catch(function () {
      filter.dataset.loadError = 'true';
      dialogBody.textContent = 'Filtreler şu anda yüklenemiyor. Lütfen yeniden deneyin.';
    });

  function section(title, note, className) {
    var block = document.createElement('section');
    block.className = 'category-content-section ' + className;
    var heading = document.createElement('div');
    heading.className = 'home-section-heading';
    var label = document.createElement('h2');
    label.textContent = title;
    heading.appendChild(label);
    if (note) {
      var description = document.createElement('p');
      description.textContent = note;
      heading.appendChild(description);
    }
    block.appendChild(heading);
    return block;
  }
  function card(item) {
    var link = document.createElement('article');
    link.className = 'category-content-card';
    link.dataset.listingId = String(item.id);
    var itemUrl = window.NEXUS_LISTING_URL ? window.NEXUS_LISTING_URL(item) : '/urunler/' + encodeURIComponent(item.id);
    var photos = Array.isArray(item.images) && item.images.length ? item.images.filter(Boolean) : ['/static/chisfis/images/' + defaultMosaic[0]];
    var photoIndex = 0;
    var image = document.createElement('img');
    image.src = photos[0];
    image.onerror = function () { image.onerror = null; image.src = '/static/chisfis/images/' + defaultMosaic[0]; };
    image.alt = item.title || '';
    image.loading = 'lazy';
    var media = document.createElement('div');
    media.className = 'category-content-card-media';
    var mediaLink = document.createElement('a');
    mediaLink.href = itemUrl;
    mediaLink.setAttribute('aria-label', item.title || 'İlanı gör');
    mediaLink.appendChild(image);
    media.appendChild(mediaLink);
    var saved = document.createElement('button');
    saved.type = 'button'; saved.className = 'category-card-favorite';
    saved.setAttribute('aria-label', 'Favorilere ekle');
    saved.textContent = '♡';
    function savedIds() { try { return JSON.parse(localStorage.getItem('nexus_saved_listings') || '[]'); } catch (_) { return []; } }
    var reviewCount = Math.max(0, Number(item.reviewCount) || 0);
    function updateSaved() {
      var on = savedIds().map(String).indexOf(String(item.id)) >= 0;
      saved.textContent = on ? '♥' : '♡';
      saved.setAttribute('aria-pressed', String(on));
      saved.setAttribute('aria-label', on ? 'Favorilerden çıkar' : 'Favorilere ekle');
    }
    updateSaved();
    saved.addEventListener('click', function () {
      var ids = savedIds().map(String);
      var id = String(item.id);
      ids = ids.indexOf(id) >= 0 ? ids.filter(function (value) { return value !== id; }) : ids.concat(id);
      localStorage.setItem('nexus_saved_listings', JSON.stringify(ids));
      document.querySelectorAll('.category-content-card').forEach(function (other) {
        if (other.dataset.listingId !== id) return;
        var button = other.querySelector('.category-card-favorite');
        if (button) {
          button.textContent = ids.indexOf(id) >= 0 ? '♥' : '♡';
          button.setAttribute('aria-pressed', String(ids.indexOf(id) >= 0));
          button.setAttribute('aria-label', ids.indexOf(id) >= 0 ? 'Favorilerden çıkar' : 'Favorilere ekle');
        }
      });
    });
    media.appendChild(saved);
    if (photos.length > 1) {
      var dots = document.createElement('div'); dots.className = 'category-card-dots';
      function showPhoto(index) {
        photoIndex = (index + photos.length) % photos.length;
        image.src = photos[photoIndex];
        dots.querySelectorAll('i').forEach(function (dot, dotIndex) { dot.classList.toggle('active', dotIndex === photoIndex); });
      }
      photos.slice(0, 6).forEach(function () { dots.appendChild(document.createElement('i')); });
      media.appendChild(dots);
      [-1, 1].forEach(function (step) { var arrow = document.createElement('button'); arrow.type = 'button'; arrow.className = 'category-card-arrow ' + (step < 0 ? 'previous' : 'next'); arrow.setAttribute('aria-label', step < 0 ? 'Önceki fotoğraf' : 'Sonraki fotoğraf'); arrow.textContent = step < 0 ? '‹' : '›'; arrow.addEventListener('click', function () { showPhoto(photoIndex + step); }); media.appendChild(arrow); });
      showPhoto(0);
    }
    link.appendChild(media);
    var body = document.createElement('div');
    body.className = 'category-content-card-copy';
    var type = document.createElement('small');
    type.className = 'category-content-card-type';
    type.textContent = item.propertyType || (categoryContent ? categoryContent.title : 'Seyahat');
    body.appendChild(type);
    var name = document.createElement('a');
    name.className = 'category-card-name'; name.href = itemUrl;
    name.textContent = item.title || 'İlan';
    body.appendChild(name);
    var place = document.createElement('small');
    place.className = 'category-content-card-location';
    place.textContent = item.locality || '';
    body.appendChild(place);
    var facts = [item.guestCount && item.guestCount + ' misafir', item.bedroomCount && item.bedroomCount + ' oda', item.bathroomCount && item.bathroomCount + ' banyo'].filter(Boolean);
    if (facts.length) { var details = document.createElement('small'); details.className = 'category-content-card-details'; details.textContent = facts.join(' · '); body.appendChild(details); }
    var footer = document.createElement('div');
    footer.className = 'category-content-card-footer';
    if (item.priceMinor && item.currency) {
      var price = document.createElement('span');
      var amount = Number(item.priceMinor) / 100;
      if (Number.isFinite(amount)) {
        price.className = 'category-content-card-price';
        price.textContent = new Intl.NumberFormat('tr-TR', { style: 'currency', currency: item.currency, maximumFractionDigits: 0 }).format(amount);
        if (categoryContent && categoryContent.unit) {
          var unit = document.createElement('small');
          unit.textContent = ' / ' + categoryContent.unit;
          price.appendChild(unit);
        }
        footer.appendChild(price);
      }
    }
    var rating = document.createElement('span');
    rating.className = 'category-content-card-rating';
    var star = document.createElement('span');
    star.className = 'category-content-card-star';
    star.setAttribute('aria-hidden', 'true');
    star.textContent = '★';
    var score = document.createElement('strong');
    score.textContent = reviewCount && item.ratingAverage != null ? Number(item.ratingAverage).toFixed(1) : '—';
    var count = document.createElement('span');
    count.className = 'category-content-card-review-count';
    count.textContent = '(' + reviewCount + ')';
    rating.setAttribute('aria-label', reviewCount ? 'Puan ' + score.textContent + ', ' + reviewCount + ' yorum' : 'Henüz yorum yok');
    rating.append(star, score, count);
    footer.appendChild(rating);
    body.appendChild(footer);
    link.appendChild(body);
    return link;
  }
  function cardGrid(items) {
    var grid = document.createElement('div');
    grid.className = 'category-content-grid';
    items.forEach(function (item) { grid.appendChild(card(item)); });
    return grid;
  }
  function themeMatches(item, option) {
    var field = option.contractFieldKey || 'amenities';
    var value = String(option.contractValue || option.key || '').toLocaleLowerCase('tr-TR');
    if (field === 'amenities') {
      var amenities = Array.isArray(item.amenities) ? item.amenities : [];
      return amenities.some(function (amenity) { return String(amenity).toLocaleLowerCase('tr-TR') === value; });
    }
    if (field === 'property_type') return String(item.propertyType || '').toLocaleLowerCase('tr-TR') === value;
    return false;
  }
  function themeDiscovery(items) {
    var group = filterGroups.find(function (candidate) { return candidate.key === 'theme' && Array.isArray(candidate.items) && candidate.items.length; });
    if (!group) return null;
    var themes = group.items.map(function (option) {
      return { option: option, title: option.title || option.key, items: items.filter(function (item) { return themeMatches(item, option); }) };
    });
    var block = section('Temaya Göre Keşfet', 'Tatil seçeneklerini temalarına göre keşfedin', 'category-theme-explore');
    var nav = document.createElement('div'); nav.className = 'category-region-nav';
    var tabsWrap = document.createElement('div'); tabsWrap.className = 'category-region-tabs';
    tabsWrap.setAttribute('role', 'tablist'); tabsWrap.setAttribute('aria-label', 'Tema seçin');
    var viewAll = document.createElement('a'); viewAll.className = 'category-region-view-all'; viewAll.textContent = 'Tümünü gör →';
    var panel = document.createElement('div'); panel.className = 'category-region-panel category-theme-panel';
    panel.id = 'category-theme-panel'; panel.setAttribute('role', 'tabpanel');
    var tabs = [];
    function selectTheme(theme, selectedTab) {
      tabs.forEach(function (tab) {
        var selected = tab === selectedTab;
        tab.setAttribute('aria-selected', String(selected));
        tab.tabIndex = selected ? 0 : -1;
      });
      panel.setAttribute('aria-labelledby', selectedTab.id);
      panel.replaceChildren();
      if (theme.items.length) panel.appendChild(cardGrid(theme.items.slice(0, 8)));
      else { var empty = document.createElement('p'); empty.className = 'category-theme-empty'; empty.textContent = 'Bu temada henüz yayınlanmış ilan bulunmuyor.'; panel.appendChild(empty); }
      var url = new URL(listUrl.href);
      url.searchParams.set('filter_key', theme.option.contractFieldKey || 'amenities');
      url.searchParams.set('filter_value', theme.option.contractValue || theme.option.key);
      viewAll.href = url.pathname + url.search;
      viewAll.setAttribute('aria-label', theme.title + ' temasındaki tüm ilanları gör');
    }
    themes.forEach(function (theme, index) {
      var tab = document.createElement('button'); tab.type = 'button';
      tab.id = 'category-theme-tab-' + index;
      tab.setAttribute('role', 'tab'); tab.setAttribute('aria-controls', panel.id);
      tab.textContent = theme.title;
      tab.addEventListener('click', function () { selectTheme(theme, tab); });
      tabs.push(tab); tabsWrap.appendChild(tab);
    });
    tabsWrap.addEventListener('keydown', function (event) {
      if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft') return;
      event.preventDefault();
      var index = tabs.indexOf(document.activeElement);
      var next = tabs[(index + (event.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length];
      next.focus(); next.click();
    });
    nav.appendChild(tabsWrap); nav.appendChild(viewAll);
    block.appendChild(nav); block.appendChild(panel);
    var firstWithListing = themes.find(function (theme) { return theme.items.length; }) || themes[0];
    selectTheme(firstWithListing, tabs[themes.indexOf(firstWithListing)]);
    return block;
  }
  function renderResults(items) {
      if (!Array.isArray(items)) return;
      visibleItems = items;
      main.querySelectorAll('.category-content-section, .category-empty-state').forEach(function (node) { node.remove(); });
      heading.textContent = items.length + ' ' + (categoryContent ? categoryContent.title : 'Seyahat') + ' ilanı';
      description.textContent = 'Fiyatları ve seçenekleri karşılaştırın.';
      head.style.visibility = '';
      head.removeAttribute('aria-busy');
      var anchor = builder || null;
      function insert(block) { main.insertBefore(block, anchor); }
      var regions = {};
      items.forEach(function (item) {
        var parts = String(item.locality || '').split(',');
        var region = parts[parts.length - 1].trim();
        if (!region) return;
        if (!regions[region]) regions[region] = { name: region, items: [] };
        regions[region].items.push(item);
      });
      var regionList = Object.keys(regions).map(function (key) { return regions[key]; })
        .sort(function (a, b) { return b.items.length - a.items.length; });
      var discoveryFirst = ['car', 'flight', 'ferry', 'transfer', 'visa', 'bus'].indexOf(category) >= 0;
      if (regionList.length || category === 'yacht') {
        var explore = section('Bölgeye Göre Keşfet', 'Bölgelerdeki yayınlanmış ilanları inceleyin', 'category-region-explore');
        var regionNav = document.createElement('div');
        regionNav.className = 'category-region-nav';
        var regionTabs = document.createElement('div');
        regionTabs.className = 'category-region-tabs';
        regionTabs.setAttribute('role', 'tablist');
        regionTabs.setAttribute('aria-label', 'Bölge seçin');
        var viewAll = document.createElement('a');
        viewAll.className = 'category-region-view-all';
        viewAll.textContent = 'Tümünü gör →';
        var regionPanel = document.createElement('div');
        regionPanel.className = 'category-region-panel';
        regionPanel.id = 'category-region-panel';
        regionPanel.setAttribute('role', 'tabpanel');
        var tabs = [];
        function selectRegion(region, selectedTab) {
          tabs.forEach(function (tab) {
            var selected = tab === selectedTab;
            tab.setAttribute('aria-selected', String(selected));
            tab.tabIndex = selected ? 0 : -1;
          });
          regionPanel.setAttribute('aria-labelledby', selectedTab.id);
          regionPanel.replaceChildren(cardGrid(region.items.slice(0, 8)));
          var url = new URL(listUrl.href);
          url.searchParams.set('konum', region.name);
          viewAll.href = url.pathname + url.search;
          viewAll.setAttribute('aria-label', region.name + ' bölgesindeki tüm ilanları gör');
        }
        regionList.slice(0, 8).forEach(function (region, index) {
          var tab = document.createElement('button');
          tab.type = 'button';
          tab.id = 'category-region-tab-' + index;
          tab.setAttribute('role', 'tab');
          tab.setAttribute('aria-controls', regionPanel.id);
          tab.textContent = region.name;
          tab.addEventListener('click', function () { selectRegion(region, tab); });
          tabs.push(tab);
          regionTabs.appendChild(tab);
        });
        regionTabs.addEventListener('keydown', function (event) {
          if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft') return;
          event.preventDefault();
          var index = tabs.indexOf(document.activeElement);
          var next = tabs[(index + (event.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length];
          next.focus(); next.click();
        });
        regionNav.appendChild(regionTabs);
        regionNav.appendChild(viewAll);
        explore.appendChild(regionNav);
        explore.appendChild(regionPanel);
        if (regionList.length) selectRegion(regionList[0], tabs[0]);
        else {
          var regionEmpty = document.createElement('p');
          regionEmpty.className = 'category-theme-empty';
          regionEmpty.textContent = 'Bu bölgede henüz yayınlanmış ilan bulunmuyor.';
          regionPanel.appendChild(regionEmpty);
          viewAll.href = listUrl.pathname + listUrl.search;
        }
        if (discoveryFirst) main.insertBefore(explore, head);
        else insert(explore);
      }
      var themeExplore = themeDiscovery(items);
      if (themeExplore) insert(themeExplore);
      if (items.length) {
        var results = section('', '', 'category-listing-preview');
        results.appendChild(cardGrid(items.slice(0, 12)));
        filter.after(results);
        if (items.length > 4) { var newest = section('Yeni İlanlar', 'Son eklenen seçenekler', 'category-new-listings'); newest.appendChild(cardGrid(items.slice(0, 8))); insert(newest); }
      }
      if (categoryContent) {
        var reasons = section('Neden Bizi Seçin?', '', 'category-benefits');
        var benefitGrid = document.createElement('div');
        benefitGrid.className = 'category-benefits-grid';
        var benefits = [
          { title: 'Güvenli Rezervasyon', description: 'SSL şifreleme ve 3D Secure ödeme altyapısıyla güvenle rezervasyon yapın.', icon: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/>', tone: 'blue' },
          { title: 'Fiyatları Karşılaştırın', description: 'İlanların fiyat ve koşullarını rezervasyon öncesinde inceleyin.', icon: '<path d="M12 3 9.8 5.2 6.7 5 6 8l-3 1 .6 3L3 15l3 1 .7 3 3.1-.2L12 21l2.2-2.2 3.1.2.7-3 3-1-.6-3L21 9l-3-1-.7-3-3.1.2L12 3Z"/><path d="M10 14l4-4M10 10h.01M14 14h.01"/>', tone: 'green' },
          { title: 'Seyahat Desteği', description: 'Sorularınız ve talepleriniz için destek kanallarımızı kullanın.', icon: '<path d="M4 13v-2a8 8 0 0 1 16 0v2"/><path d="M4 12h2a2 2 0 0 1 2 2v4H6a2 2 0 0 1-2-2v-4Zm16 0h-2a2 2 0 0 0-2 2v4h2a2 2 0 0 0 2-2v-4Z"/>', tone: 'purple' },
          { title: 'Rezervasyon Takibi', description: 'Rezervasyonunuzun durumunu hesabınızdan takip edin.', icon: '<path d="m13 2-9 11h7l-1 9 10-12h-7l1-8Z"/>', tone: 'yellow' },
          { title: 'Açık İptal Koşulları', description: 'İptal ve değişiklik koşullarını ilan sayfasında inceleyin.', icon: '<path d="M20 11a8 8 0 0 0-14-5L4 8"/><path d="M4 4v4h4M4 13a8 8 0 0 0 14 5l2-2"/><path d="M20 20v-4h-4"/>', tone: 'teal' },
          { title: 'Geniş Seçenek', description: 'Türkiye geneli ve dünyaya açılan kapsamlı ürün portföyümüz.', icon: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a15 15 0 0 1 0 18M12 3a15 15 0 0 0 0 18"/>', tone: 'sky' }
        ];
        benefits.forEach(function (entry) {
          var benefit = document.createElement('div');
          benefit.className = 'category-benefit-card';
          var icon = document.createElement('span');
          icon.className = 'category-benefit-icon category-benefit-icon-' + entry.tone;
          icon.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + entry.icon + '</svg>';
          var copy = document.createElement('span');
          copy.className = 'category-benefit-copy';
          var title = document.createElement('strong');
          title.textContent = entry.title;
          var description = document.createElement('small');
          description.textContent = entry.description;
          copy.append(title, description);
          benefit.append(icon, copy);
          benefitGrid.appendChild(benefit);
        });
        reasons.appendChild(benefitGrid);
        insert(reasons);
      }
      updateMapMarkers(items);
      document.dispatchEvent(new CustomEvent('nexus:category-sections-rendered'));
  }
  var initialUrl = new URL('/api/public/listings', location.origin);
  initialUrl.searchParams.set('kategori', category);
  if (document.body.dataset.tenant) initialUrl.searchParams.set('tenant', document.body.dataset.tenant);
  var listingsPromise = fetch(initialUrl.pathname + initialUrl.search, { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) { if (!response.ok) throw new Error('listings'); return response.json(); })
    .then(function (items) { allItems = items; })
    .catch(function () { head.dataset.loadError = 'true'; });
  Promise.all([filtersPromise, listingsPromise]).then(function () {
    renderResults(allItems);
    return new URL(location.href).searchParams.get('view') === 'map' ? setMapView(true) : undefined;
  }).then(function () {
    window.clearTimeout(revealTimeout);
    revealCategory();
  });
})();

// Theme palette is an admin concern; keep it out of the public footer.
(function removeFooterThemeControls() {
  function remove() {
    document.querySelectorAll('.store-theme-swatches, #footer-theme-cards').forEach(function (el) {
      var section = el.closest('.mt-12');
      if (section) section.remove(); else el.remove();
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', remove);
  else remove();
})();

// Normalize public SEO signals for home, category and listing routes.
(function ensureSeoSignals() {
  var canonical = document.querySelector('link[rel="canonical"]');
  if (!canonical) { canonical = document.createElement('link'); canonical.rel = 'canonical'; document.head.appendChild(canonical); }
  canonical.href = window.location.origin + window.location.pathname;
  var og = document.querySelector('meta[property="og:url"]');
  if (!og) { og = document.createElement('meta'); og.setAttribute('property','og:url'); document.head.appendChild(og); }
  og.content = canonical.href;
  var robots = document.querySelector('meta[name="robots"]');
  if (!robots) { robots = document.createElement('meta'); robots.name='robots'; document.head.appendChild(robots); }
  robots.content = 'index,follow,max-image-preview:large';
  var heading = document.querySelector('main h1, main h2, h1');
  var title = (document.title || '').trim();
  if (!title || title === 'NEXUS Agency') {
    title = heading ? heading.textContent.trim() + ' | NEXUS Agency' : 'NEXUS Agency | Seyahat ve rezervasyon';
    document.title = title;
  }
  var desc = document.querySelector('meta[name="description"]');
  var summary = document.querySelector('main p, .hero-subtitle, .category-hero p');
  var description = desc && desc.content ? desc.content.trim() : (summary ? summary.textContent.trim() : 'Otel, tatil evi, yat, tur ve seyahat deneyimlerini güvenle keşfedin ve rezervasyon yapın.');
  if (!desc) { desc = document.createElement('meta'); desc.name = 'description'; document.head.appendChild(desc); }
  if (!desc.content) desc.content = description.slice(0, 160);
  var keywords = document.querySelector('meta[name="keywords"]');
  if (!keywords) { keywords = document.createElement('meta'); keywords.name = 'keywords'; document.head.appendChild(keywords); }
  if (!keywords.content) keywords.content = [heading && heading.textContent.trim(), 'seyahat', 'rezervasyon', 'otel', 'tatil', 'tur'].filter(Boolean).join(', ');
  var ld = document.getElementById('nexus-seo-jsonld');
  if (!ld) { ld = document.createElement('script'); ld.id = 'nexus-seo-jsonld'; ld.type = 'application/ld+json'; document.head.appendChild(ld); }
  ld.textContent = JSON.stringify({
    '@context': 'https://schema.org', '@type': 'WebSite', name: 'NEXUS Agency', url: canonical.href,
    inLanguage: document.documentElement.lang || 'tr', description: desc.content,
    potentialAction: {'@type':'SearchAction', target: window.location.origin + '/urunler?konum={search_term_string}', 'query-input':'required name=search_term_string'}
  });
  // Dil kodu URL'ye eklenmez; aynı temiz slug için hreflang alternatifleri verilir.
  ['tr','en','de','ru','zh','fr'].forEach(function (code) {
    var alt = document.querySelector('link[rel="alternate"][hreflang="' + code + '"]');
    if (!alt) { alt = document.createElement('link'); alt.rel = 'alternate'; alt.hreflang = code; document.head.appendChild(alt); }
    alt.href = canonical.href;
  });
  var xdefault = document.querySelector('link[rel="alternate"][hreflang="x-default"]');
  if (!xdefault) { xdefault = document.createElement('link'); xdefault.rel = 'alternate'; xdefault.hreflang = 'x-default'; document.head.appendChild(xdefault); }
  xdefault.href = canonical.href;
  var path = window.location.pathname.toLowerCase();
  var type = document.body.classList.contains('product-detail') || /\/urunler\/[^/]+$/.test(path) ? 'Product' :
    (document.body.classList.contains('category-page') || /\/kategori\//.test(path) ? 'ItemList' :
    (/\/blog(\/|$)/.test(path) ? 'Article' :
    (/\/bolge(\/|$)|\/region(\/|$)/.test(path) ? 'Place' :
    (document.body.classList.contains('chisfis-home') || path === '/' ? 'WebSite' : 'WebPage'))));
  var pageLd = document.getElementById('nexus-page-jsonld');
  if (!pageLd) { pageLd = document.createElement('script'); pageLd.id = 'nexus-page-jsonld'; pageLd.type = 'application/ld+json'; document.head.appendChild(pageLd); }
  var pageData = {'@context':'https://schema.org','@type':type,'name':title,'description':desc.content,'url':canonical.href,'inLanguage':document.documentElement.lang || 'tr'};
  if (type === 'Article') {
    pageData.headline = title;
    pageData.mainEntityOfPage = canonical.href;
    pageData.author = {'@type':'Organization','name':'NEXUS Agency'};
  }
  if (type === 'Place') pageData.address = {'@type':'PostalAddress','addressCountry':'TR'};
  pageLd.textContent = JSON.stringify(pageData);
})();


// Tenant seçimi sunucu tarafında body[data-tenant] ile korunur; UUID'yi SEO URL'sine taşımıyoruz.
(function cleanTenantUrls() {
  var params = new URL(window.location.href).searchParams;
  if (!params.has('tenant')) return;
  // Keep local multi-tenant navigation bound to the selected agency after
  // removing the UUID from visible links. The server reads this selector only
  // when the URL and host do not identify a tenant explicitly.
  var selectedTenant = params.get('tenant');
  if (selectedTenant && /^[0-9a-f-]{36}$/i.test(selectedTenant)) {
    document.cookie = 'nexus_public_tenant=' + encodeURIComponent(selectedTenant) + '; Path=/; SameSite=Lax';
  }
  params.delete('tenant');
  var clean = location.pathname + (params.toString() ? '?' + params.toString() : '') + location.hash;
  if (window.history && history.replaceState) history.replaceState({}, document.title, clean);
  document.querySelectorAll('a[href*="tenant="]').forEach(function (link) {
    try {
      var u = new URL(link.href, location.origin);
      u.searchParams.delete('tenant');
      link.href = u.pathname + (u.searchParams.toString() ? '?' + u.searchParams.toString() : '') + u.hash;
    } catch (_) {}
  });
  var observer = new MutationObserver(function () {
    document.querySelectorAll('a[href*="tenant="]').forEach(function (link) {
      try {
        var u = new URL(link.href, location.origin);
        u.searchParams.delete('tenant');
        link.href = u.pathname + (u.searchParams.toString() ? '?' + u.searchParams.toString() : '') + u.hash;
      } catch (_) {}
    });
  });
  observer.observe(document.body, { childList: true, subtree: true });
})();
