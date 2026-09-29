(function () {
  'use strict';
  if (!document.body.classList.contains('category-page')) return;
  var code = window.NEXUS_CATEGORY_CODE && window.NEXUS_CATEGORY_CODE(location.pathname);
  if (!code) return;
  var names = {
    hotel:['Hotels','Hotels','Отели','Hôtels','酒店'], holiday_home:['Holiday homes','Ferienhäuser','Дома для отдыха','Maisons de vacances','度假屋'],
    yacht:['Yachts and boats','Yachten und Boote','Яхты и лодки','Yachts et bateaux','游艇与船只'], tour:['Tours','Touren','Туры','Circuits','旅游线路'],
    activity:['Activities','Aktivitäten','Развлечения','Activités','活动'], flight:['Flights','Flüge','Авиабилеты','Vols','航班'],
    car:['Car rentals','Mietwagen','Аренда авто','Location de voiture','租车'], cruise:['Cruises','Kreuzfahrten','Круизы','Croisières','邮轮'],
    pilgrimage:['Hajj and Umrah','Hadsch und Umra','Хадж и умра','Hajj et Omra','朝觐与副朝'], visa:['Visa services','Visadienste','Визовые услуги','Services de visa','签证服务'],
    ferry:['Ferries','Fähren','Паромы','Ferries','渡轮'], transfer:['Transfers','Transfers','Трансферы','Transferts','接送服务'],
    beach:['Beaches and sun loungers','Strände und Liegen','Пляжи и шезлонги','Plages et transats','海滩与躺椅'],
    cinema:['Cinema','Kino','Кино','Cinéma','电影院'], event:['Events','Veranstaltungen','Мероприятия','Événements','活动票务'],
    restaurant:['Restaurants','Restaurants','Рестораны','Restaurants','餐厅'], bus:['Buses','Busse','Автобусы','Autocars','巴士']
  };
  var descriptions = {
    hotel:['Compare verified stays from city hotels to beach resorts.','Vergleichen Sie geprüfte Unterkünfte von Stadthotels bis zu Strandresorts.','Сравните проверенные варианты размещения от городских отелей до пляжных курортов.','Comparez des hébergements vérifiés, des hôtels urbains aux stations balnéaires.','比较从城市酒店到海滨度假村的可靠住宿选择。'],
    holiday_home:['Discover villas, apartments, bungalows and holiday homes for family and friends.','Entdecken Sie Villen, Apartments, Bungalows und Ferienhäuser für Familie und Freunde.','Найдите виллы, апартаменты, бунгало и дома для отдыха с семьёй и друзьями.','Découvrez villas, appartements, bungalows et maisons pour vos proches.','为家人和朋友探索别墅、公寓、木屋和度假屋。'],
    yacht:['Find skippered yachts, day cruises and private sea escapes in one place.','Finden Sie Yachten mit Skipper, Tagesfahrten und private Ausflüge auf See.','Найдите яхты с капитаном, дневные круизы и частные морские прогулки.','Trouvez des yachts avec skipper, des sorties en mer et des croisières privées.','一站式寻找船长驾驶的游艇、一日航游和私人海上之旅。'],
    tour:['Explore cities, cultural routes and guided day trips.','Entdecken Sie Städte, Kulturrouten und geführte Tagesausflüge.','Откройте для себя города, культурные маршруты и экскурсии с гидом.','Découvrez les villes, les itinéraires culturels et les excursions guidées.','探索城市、文化路线和导览一日游。'],
    activity:['Make your trip personal with sports, nature and city activities.','Gestalten Sie Ihre Reise mit Sport, Natur und Stadtaktivitäten.','Дополните поездку спортом, природой и городскими развлечениями.','Personnalisez votre voyage avec des activités sportives, nature et urbaines.','通过运动、自然和城市活动打造专属旅程。'],
    flight:['Compare flights and plan your route with ease.','Vergleichen Sie Flüge und planen Sie Ihre Route ganz einfach.','Сравните авиарейсы и легко спланируйте маршрут.','Comparez les vols et planifiez facilement votre itinéraire.','比较航班，轻松规划路线。'],
    car:['Rent the right car, SUV or minibus with confidence.','Mieten Sie passende Autos, SUVs und Kleinbusse mit gutem Gefühl.','Арендуйте подходящий автомобиль, внедорожник или микроавтобус.','Louez sereinement la voiture, le SUV ou le minibus adapté.','安心租赁适合您的汽车、SUV 或小巴。'],
    cruise:['Compare cruise routes and discover several ports on one journey.','Vergleichen Sie Kreuzfahrten und entdecken Sie mehrere Häfen auf einer Reise.','Сравните круизы и посетите несколько портов за одну поездку.','Comparez les croisières et découvrez plusieurs ports en un voyage.','比较邮轮航线，在一次旅程中探索多个港口。'],
    pilgrimage:['Plan Hajj and Umrah with accommodation, transport and guidance.','Planen Sie Hadsch und Umra mit Unterkunft, Transport und Betreuung.','Спланируйте хадж и умру с проживанием, транспортом и сопровождением.','Planifiez Hajj et Omra avec hébergement, transport et accompagnement.','规划包含住宿、交通和向导服务的朝觐与副朝。'],
    visa:['Get reliable help with documents, appointments and visa applications.','Erhalten Sie Hilfe bei Unterlagen, Terminen und Visumanträgen.','Получите помощь с документами, записью и подачей заявления на визу.','Obtenez de l’aide pour vos documents, rendez-vous et demandes de visa.','获取文件、预约和签证申请方面的可靠协助。'],
    ferry:['Find ferry schedules and tickets for island and coastal routes.','Finden Sie Fähren, Fahrpläne und Tickets für Insel- und Küstenrouten.','Найдите расписание и билеты на паромы для островных и прибрежных маршрутов.','Trouvez horaires et billets de ferry pour les îles et le littoral.','查找岛屿及海岸航线的渡轮时刻和船票。'],
    transfer:['Book airport, hotel and city transfers with trusted drivers.','Buchen Sie Flughafen-, Hotel- und Stadttransfers mit zuverlässigen Fahrern.','Забронируйте трансфер из аэропорта, отеля или по городу с надёжным водителем.','Réservez vos transferts aéroport, hôtel et ville avec des chauffeurs fiables.','预订可靠司机提供的机场、酒店和市内接送服务。'],
    beach:['Reserve sun loungers, cabanas and beach experiences in advance.','Reservieren Sie Liegen, Strandkabinen und Erlebnisse am Meer im Voraus.','Заранее бронируйте шезлонги, кабаны и отдых на пляже.','Réservez à l’avance transats, cabanes et expériences en bord de mer.','提前预订海滩躺椅、凉亭和海滨体验。'],
    cinema:['Find cinemas, showtimes and tickets for current films.','Entdecken Sie Kinos, Spielzeiten und Tickets für aktuelle Filme.','Найдите кинотеатры, сеансы и билеты на фильмы в прокате.','Trouvez cinémas, séances et billets pour les films à l’affiche.','查找热映电影的影院、场次和影票。'],
    event:['Book tickets early for concerts, festivals and city events.','Sichern Sie sich früh Tickets für Konzerte, Festivals und Veranstaltungen.','Заранее бронируйте билеты на концерты, фестивали и события.','Réservez tôt vos billets pour concerts, festivals et événements.','提前预订音乐会、节庆和城市活动门票。'],
    restaurant:['Discover local cuisine, selected restaurants and special menus.','Entdecken Sie lokale Küche, ausgewählte Restaurants und besondere Menüs.','Откройте для себя местную кухню, рестораны и специальные меню.','Découvrez la cuisine locale, des restaurants choisis et des menus spéciaux.','探索当地美食、精选餐厅和特色菜单。'],
    bus:['Compare intercity buses and plan your route easily.','Vergleichen Sie Fernbusse und planen Sie Ihre Route ganz einfach.','Сравните междугородние автобусы и легко спланируйте маршрут.','Comparez les autocars interurbains et planifiez facilement votre trajet.','比较城际巴士，轻松规划路线。']
  };
  var locales = ['en','de','ru','fr','zh'];
  var ui = {
    compare:['Compare prices and options.','Vergleichen Sie Preise und Angebote.','Сравните цены и варианты.','Comparez les prix et les options.','比较价格和选项。'],
    listed:['listings','Angebote','объявлений','annonces','个产品'],
    map:['Show on map ↗','Auf Karte anzeigen ↗','Показать на карте ↗','Voir sur la carte ↗','在地图上查看 ↗'],
    filters:['⚙ All filters','⚙ Alle Filter','⚙ Все фильтры','⚙ Tous les filtres','⚙ 所有筛选'],
    search:['Start your search','Suche starten','Начать поиск','Lancer la recherche','开始搜索'],
    why:['Why choose us?','Warum uns wählen?','Почему выбирают нас?','Pourquoi nous choisir ?','为什么选择我们？'],
    newListings:['New listings','Neue Angebote','Новые объявления','Nouvelles annonces','最新产品']
  };
  var trUi = {
    compare:'Fiyatları ve seçenekleri karşılaştırın.', listed:'ilanı', map:'Haritada Gör ↗',
    filters:'⚙  Tüm filtreler', search:'Aramaya başla', why:'Neden Bizi Seçin?', newListings:'Yeni İlanlar'
  };
  var fieldText = {
    'Fiyatlar ilan başı ve seçilen tarihler için geçerlidir.':['Prices are per listing for the selected dates.','Preise gelten pro Angebot für die gewählten Daten.','Цены указаны за предложение на выбранные даты.','Les prix s’appliquent par annonce aux dates choisies.','价格按所选日期的每个产品计算。'],
    'Bölgeye Göre Keşfet':['Explore by region','Nach Region entdecken','Поиск по регионам','Explorer par région','按地区探索'],
    'Bölgelerdeki yayınlanmış ilanları inceleyin':['Browse available listings by region.','Entdecken Sie Angebote nach Region.','Изучите объявления по регионам.','Découvrez les annonces par région.','按地区浏览已发布的产品。'],
    'Tümünü gör →':['View all →','Alle anzeigen →','Смотреть все →','Tout voir →','查看全部 →'],
    'Son eklenen seçenekler':['Recently added options','Neu hinzugefügte Angebote','Недавно добавленные варианты','Options récemment ajoutées','最近添加的选项'],
    'Bu kategoride henüz yayınlanmış ilan bulunmuyor. Yeni seçenekler eklendiğinde burada görünecek.':['No listings are published in this category yet. New options will appear here.','In dieser Kategorie gibt es noch keine Angebote. Neue Optionen erscheinen hier.','В этой категории пока нет объявлений. Новые варианты появятся здесь.','Aucune annonce n’est encore publiée dans cette catégorie. Les nouveautés apparaîtront ici.','此类别暂无已发布产品。新增选项将在此显示。'],
    'Bu kategoride henüz yayınlanmış ilan bulunmuyor.':['No listings are published in this category yet.','In dieser Kategorie gibt es noch keine Angebote.','В этой категории пока нет объявлений.','Aucune annonce n’est encore publiée dans cette catégorie.','此类别暂无已发布产品。'],
    'Güvenli Rezervasyon':['Secure booking','Sichere Buchung','Безопасное бронирование','Réservation sécurisée','安全预订'],
    'Fiyatları Karşılaştırın':['Compare prices','Preise vergleichen','Сравните цены','Comparez les prix','比较价格'],
    'Seyahat Desteği':['Travel support','Reiseunterstützung','Поддержка в поездке','Assistance voyage','旅行支持'],
    'Rezervasyon Takibi':['Booking tracking','Buchung verfolgen','Отслеживание бронирования','Suivi de réservation','预订跟踪'],
    'Açık İptal Koşulları':['Clear cancellation terms','Klare Stornobedingungen','Понятные условия отмены','Conditions d’annulation claires','明确的取消条款'],
    'Geniş Seçenek':['Wide selection','Große Auswahl','Широкий выбор','Large choix','丰富选择'],
    'SSL şifreleme ve 3D Secure ödeme altyapısıyla güvenle rezervasyon yapın.':['Book safely with SSL encryption and 3D Secure payments.','Buchen Sie sicher mit SSL-Verschlüsselung und 3D Secure.','Бронируйте безопасно с SSL и 3D Secure.','Réservez en sécurité avec SSL et 3D Secure.','通过 SSL 加密和 3D Secure 安全预订。'],
    'İlanların fiyat ve koşullarını rezervasyon öncesinde inceleyin.':['Review listing prices and terms before booking.','Prüfen Sie Preise und Bedingungen vor der Buchung.','Изучите цены и условия до бронирования.','Consultez les prix et conditions avant de réserver.','预订前查看产品价格和条款。'],
    'Sorularınız ve talepleriniz için destek kanallarımızı kullanın.':['Use our support channels for questions and requests.','Nutzen Sie unsere Supportkanäle für Fragen und Anliegen.','Обращайтесь в наши каналы поддержки с вопросами и запросами.','Utilisez nos canaux d’assistance pour vos questions et demandes.','如有疑问或需求，请使用我们的支持渠道。'],
    'Rezervasyonunuzun durumunu hesabınızdan takip edin.':['Track your booking status in your account.','Verfolgen Sie Ihren Buchungsstatus in Ihrem Konto.','Отслеживайте статус бронирования в личном кабинете.','Suivez votre réservation depuis votre compte.','在账户中跟踪预订状态。'],
    'İptal ve değişiklik koşullarını ilan sayfasında inceleyin.':['Review cancellation and change terms on the listing page.','Prüfen Sie Storno- und Änderungsbedingungen auf der Angebotsseite.','Изучите условия отмены и изменения на странице предложения.','Consultez les conditions d’annulation et de modification sur la page de l’annonce.','请在产品页面查看取消和更改条款。'],
    'Türkiye geneli ve dünyaya açılan kapsamlı ürün portföyümüz.':['A broad selection across Türkiye and the world.','Eine große Auswahl in der Türkei und weltweit.','Широкий выбор по Турции и всему миру.','Un large choix en Turquie et dans le monde.','提供覆盖土耳其及全球的丰富产品。']
  };
  var sourceText = new WeakMap();
  var legacyMixedText = {
    'Book Takibi':'Rezervasyon Takibi',
    'Güvenli Book':'Güvenli Rezervasyon'
  };
  function translateNode(node, language) {
    if (!node) return;
    if (!sourceText.has(node)) {
      var original = node.textContent.trim();
      sourceText.set(node, legacyMixedText[original] || original);
    }
    var source = sourceText.get(node);
    if (!fieldText[source]) return;
    node.textContent = language === 'tr' ? source : fieldText[source][locales.indexOf(language)];
  }
  function lang() { var value = (window.NEXUS_LOCALE && window.NEXUS_LOCALE.lang) || document.documentElement.lang || 'tr'; return locales.includes(value) ? value : 'tr'; }
  function local(key, language) { return language === 'tr' ? trUi[key] : ui[key][locales.indexOf(language)]; }
  function categoryName(language) {
    var content = window.NEXUS_CATEGORY_CONTENT && window.NEXUS_CATEGORY_CONTENT[code];
    return language === 'tr' ? (content && content.title || code) : (names[code] && names[code][locales.indexOf(language)] || code);
  }
  function builderCopy(key) {
    var blocks = document.querySelectorAll('.category-page .builder-source-section');
    for (var i = 0; i < blocks.length; i++) {
      try {
        var config = JSON.parse(blocks[i].dataset.sectionConfig || '{}');
        if (config.sectionKey === key && config.enabled !== false) return config;
      } catch (_) {}
    }
    return {};
  }
  function apply() {
    var main = document.querySelector('.category-page main'); if (!main) return;
    var language = lang();
    var content = window.NEXUS_CATEGORY_CONTENT && window.NEXUS_CATEGORY_CONTENT[code];
    if (!content) return;
    var heroCopy = builderCopy('hero');
    var resultsCopy = builderCopy('results_heading');
    var benefitsCopy = builderCopy('benefits');
    var hero = main.querySelector('.relative.container');
    var heading = hero && hero.querySelector('h1');
    var description = hero && hero.querySelector('h1 + p');
    if (heading) { heading.removeAttribute('data-i18n'); heading.textContent = heroCopy.title || (language === 'tr' ? (content.heroTitle || content.title) : categoryName(language)); }
    if (description) description.textContent = heroCopy.description || (language === 'tr' ? content.description : descriptions[code][locales.indexOf(language)]);
    var start = hero && hero.querySelector('a[href^="/urunler"]');
    if (start) { var textNode = Array.from(start.childNodes).find(function (node) { return node.nodeType === 3 && node.textContent.trim(); }); if (textNode) textNode.textContent = local('search', language); }
    var results = main.querySelector('.category-results-head');
    if (results) {
      var count = (results.querySelector('h1')?.textContent || '').match(/^\d+/);
      if (count && !resultsCopy.title) results.querySelector('h1').textContent = count[0] + ' ' + categoryName(language) + ' ' + local('listed', language);
      var summary = results.querySelector('p'); if (summary) summary.textContent = resultsCopy.description || local('compare', language);
      var map = results.querySelector('a'); if (map) map.textContent = local('map', language);
    }
    var filter = main.querySelector('.category-demo-filter .filter-all');
    if (filter) { var badge = filter.querySelector('b'); filter.textContent = local('filters', language); if (badge) filter.appendChild(badge); }
    main.querySelectorAll('.category-benefits h2').forEach(function (node) { node.textContent = benefitsCopy.title || local('why', language); });
    main.querySelectorAll('.category-new-listings h2').forEach(function (node) { node.textContent = local('newListings', language); });
    main.querySelectorAll('.category-results-head p, .category-region-explore h2, .category-region-explore .section-description, .category-region-view-all, .category-new-listings p, .category-empty-state, .category-theme-empty, .category-benefit-copy strong, .category-benefit-copy small').forEach(function (node) { translateNode(node, language); });
  }
  window.NEXUS_APPLY_CATEGORY_LANGUAGE = apply;
  document.addEventListener('nexus:lang', function () { requestAnimationFrame(apply); });
  document.addEventListener('nexus:category-sections-rendered', function () { requestAnimationFrame(apply); });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function () { setTimeout(apply, 0); }); else setTimeout(apply, 0);
})();
