(function () {
  var isHome = document.body.classList.contains('chisfis-home') && !document.body.classList.contains('category-page');

  // English source, then Turkish, German, Russian, French and Chinese.
  var copy = {
    '-20% OFF': ['%20 İndirim', '20 % Rabatt', 'Скидка 20 %', '20 % de réduction', '八折优惠'],
    'Start your search': ['Aramaya başla', 'Suche starten', 'Начать поиск', 'Lancer la recherche', '开始搜索'],
    'Show me more': ['Daha fazla göster', 'Mehr anzeigen', 'Показать больше', 'Afficher plus', '查看更多'],
    'Become a host': ['Ev sahibi olun', 'Gastgeber werden', 'Стать хозяином', 'Devenir hôte', '成为房东'],
    'Become an author': ['İlanınızı yayınlayın', 'Inserat veröffentlichen', 'Опубликовать объявление', 'Publier une annonce', '发布房源'],
    'Enter your email': ['E-posta adresinizi girin', 'E-Mail-Adresse eingeben', 'Введите адрес электронной почты', 'Saisissez votre adresse e-mail', '请输入电子邮箱'],
    'Bangkok, Thailand': ['Bangkok, Tayland', 'Bangkok, Thailand', 'Бангкок, Таиланд', 'Bangkok, Thaïlande', '曼谷，泰国'],
    'New York, USA': ['New York, ABD', 'New York, USA', 'Нью-Йорк, США', 'New York, États-Unis', '纽约，美国'],
    'Singapore': ['Singapur', 'Singapur', 'Сингапур', 'Singapour', '新加坡'],
    'Paris, France': ['Paris, Fransa', 'Paris, Frankreich', 'Париж, Франция', 'Paris, France', '巴黎，法国'],
    'London, UK': ['Londra, Birleşik Krallık', 'London, Vereinigtes Königreich', 'Лондон, Великобритания', 'Londres, Royaume-Uni', '伦敦，英国'],
    'Tokyo, Japan': ['Tokyo, Japonya', 'Tokio, Japan', 'Токио, Япония', 'Tokyo, Japon', '东京，日本'],
    'Maldives': ['Maldivler', 'Malediven', 'Мальдивы', 'Maldives', '马尔代夫'],
    'Roma, Italy': ['Roma, İtalya', 'Rom, Italien', 'Рим, Италия', 'Rome, Italie', '罗马，意大利'],
    'Sydney, Australia': ['Sidney, Avustralya', 'Sydney, Australien', 'Сидней, Австралия', 'Sydney, Australie', '悉尼，澳大利亚'],
    'Berlin, Germany': ['Berlin, Almanya', 'Berlin, Deutschland', 'Берлин, Германия', 'Berlin, Allemagne', '柏林，德国'],
    'Toronto, Canada': ['Toronto, Kanada', 'Toronto, Kanada', 'Торонто, Канада', 'Toronto, Canada', '多伦多，加拿大'],
    'Check in - Check out': ['Giriş - Çıkış', 'Anreise - Abreise', 'Заезд — выезд', 'Arrivée - départ', '入住 - 退房'],
    'Sep 16 - Sep 19': ['16 Eyl - 19 Eyl', '16. Sep. - 19. Sep.', '16 сент. - 19 сент.', '16 sept. - 19 sept.', '9月16日 - 9月19日'],
    'With a free listing, you can advertise your rental with no upfront costs': ['Ücretsiz ilanla kiralık yerinizi ön ödeme yapmadan tanıtabilirsiniz', 'Mit einem kostenlosen Inserat bewerben Sie Ihre Unterkunft ohne Vorabkosten', 'Размещайте своё жильё бесплатно и без предварительных расходов', 'Publiez votre logement gratuitement, sans frais initiaux', '免费发布房源，无需预付费用'],
    '🎬 The Videos': ['🎬 Videolar', '🎬 Videos', '🎬 Видео', '🎬 Vidéos', '🎬 视频'],
    'Check out our hottest videos. View more and share more new perspectives on just about any topic. Everyone\'s welcome.': ['En yeni videolarımızı izleyin; farklı bakış açılarını keşfedin ve paylaşın.', 'Entdecken Sie unsere neuesten Videos und teilen Sie neue Perspektiven.', 'Смотрите наши новые видео, открывайте и делитесь свежими взглядами.', 'Découvrez nos dernières vidéos et partagez de nouvelles perspectives.', '观看最新视频，发现并分享不同视角。'],
    'Good news from far away 🥇': ['Uzaklardan güzel haberler 🥇', 'Gute Nachrichten aus aller Welt 🥇', 'Хорошие новости издалека 🥇', 'De bonnes nouvelles d’ailleurs 🥇', '远方传来好消息 🥇'],
    'Let\'s see what people think of Chisfis': ['Misafirlerimizin Chisfis hakkındaki görüşleri', 'Was Gäste über Chisfis sagen', 'Что гости думают о Chisfis', 'Ce que les voyageurs pensent de Chisfis', '看看旅客如何评价 Chisfis'],
    'Great quality products, affordable prices, fast and friendly delivery. I very recommend.': ['Kaliteli seçenekler, uygun fiyatlar ve hızlı, güler yüzlü hizmet. Tavsiye ederim.', 'Tolle Qualität, faire Preise und schneller, freundlicher Service. Sehr empfehlenswert.', 'Отличное качество, доступные цены и быстрое, дружелюбное обслуживание. Рекомендую.', 'Excellent choix, prix accessibles et service rapide et agréable. Je recommande.', '选择优质、价格合理，服务快捷友好。非常推荐。'],
    'Join our newsletter 🎉': ['Bültenimize katılın 🎉', 'Newsletter abonnieren 🎉', 'Подпишитесь на рассылку 🎉', 'Abonnez-vous à notre newsletter 🎉', '订阅我们的资讯 🎉'],
    'Selected based on user reviews. Updated weekly': ['Misafir yorumlarına göre seçildi. Her hafta güncellenir.', 'Basierend auf Gästebewertungen. Wöchentlich aktualisiert.', 'На основе отзывов гостей. Обновляется еженедельно.', 'Sélectionnés selon les avis des voyageurs. Mis à jour chaque semaine.', '根据旅客评价精选，每周更新。'],
    'View all': ['Tümünü gör', 'Alle ansehen', 'Смотреть все', 'Tout voir', '查看全部'],
    'Book & relax': ['Rezervasyon yapın, rahatlayın', 'Buchen und entspannen', 'Бронируйте и отдыхайте', 'Réservez et détendez-vous', '预订并放松'],
    'Smart checklist': ['Akıllı kontrol listesi', 'Smarte Checkliste', 'Умный список', 'Liste intelligente', '智能清单'],
    'Save more': ['Daha çok tasarruf edin', 'Mehr sparen', 'Экономьте больше', 'Économisez davantage', '节省更多'],
    'Get more discount': ['Daha fazla indirim kazanın', 'Mehr Rabatte erhalten', 'Получайте больше скидок', 'Profitez de plus de réductions', '享受更多优惠'],
    'Get premium deals': ['Özel fırsatları yakalayın', 'Exklusive Angebote sichern', 'Получайте лучшие предложения', 'Profitez d’offres exclusives', '获取精选优惠'],
    'Endless inspiration': ['Sınırsız ilham', 'Endlose Inspiration', 'Бесконечное вдохновение', 'Une inspiration sans fin', '无限灵感'],
    'Enjoy the great cold': ['Kışın tadını çıkarın', 'Genießen Sie den Winter', 'Насладитесь зимой', 'Profitez de l’hiver', '享受冬日时光'],
    'Sleep in a floating way': ['Suyun üzerinde konaklayın', 'Über dem Wasser übernachten', 'Отдых на воде', 'Dormez sur l’eau', '体验水上住宿'],
    "In the billionaire's house": ['Lüks bir evde konaklayın', 'In einem luxuriösen Haus wohnen', 'Отдых в роскошном доме', 'Séjournez dans une maison de luxe', '入住豪华住宅'],
    'Cool in the deep forest': ['Ormanın serinliğini keşfedin', 'Die Kühle des Waldes genießen', 'Прохлада леса', 'La fraîcheur de la forêt', '感受森林的清凉'],
    'Sunset in the desert': ['Çölde gün batımı', 'Sonnenuntergang in der Wüste', 'Закат в пустыне', 'Coucher de soleil dans le désert', '沙漠日落'],
    'Advertising': ['Tanıtım', 'Werbung', 'Реклама', 'Publicité', '推广'],
    'Cost-effective advertising': ['Uygun maliyetli tanıtım', 'Kostengünstige Werbung', 'Выгодная реклама', 'Publicité économique', '低成本推广'],
    'Exposure': ['Görünürlük', 'Reichweite', 'Охват', 'Visibilité', '曝光度'],
    'Reach millions with Chisfis': ['Chisfis ile milyonlara ulaşın', 'Mit Chisfis Millionen erreichen', 'Охватите миллионы с Chisfis', 'Touchez des millions de voyageurs avec Chisfis', '通过 Chisfis 触达数百万旅客'],
    'Millions of people are searching for unique places to stay around the world': ['Dünya çapında milyonlarca kişi benzersiz konaklama yerleri arıyor', 'Millionen Menschen suchen weltweit nach besonderen Unterkünften', 'Миллионы людей ищут необычное жильё по всему миру', 'Des millions de personnes recherchent des hébergements uniques dans le monde', '全球数百万人都在寻找独特的住宿'],
    'Secure': ['Güvenli', 'Sicher', 'Надёжно', 'Sécurisé', '安全'],
    'Secure and simple': ['Güvenli ve kolay', 'Sicher und einfach', 'Безопасно и просто', 'Sûr et simple', '安全又简单'],
    'A Chisfis listing gives you a secure and easy way to take bookings and payments online': ['Chisfis ilanlarıyla çevrimiçi rezervasyon ve ödemeleri güvenle alın', 'Mit Chisfis nehmen Sie Buchungen und Zahlungen sicher und einfach online entgegen', 'С Chisfis удобно и безопасно принимать бронирования и платежи онлайн', 'Avec Chisfis, recevez réservations et paiements en ligne facilement et en sécurité', '通过 Chisfis 安全便捷地在线接受预订与付款'],
    'Let each trip be an inspirational journey, each room a peaceful space': ['Her yolculuk ilham versin, her oda huzur sunsun', 'Jede Reise inspiriert, jedes Zimmer bietet Ruhe', 'Пусть каждое путешествие вдохновляет, а каждый номер дарит покой', 'Que chaque voyage inspire et que chaque chambre apaise', '让每次旅行充满灵感，让每间客房带来宁静'],
    'Get exclusive deals and inspiration delivered straight to your inbox.': ['Özel fırsatlar ve seyahat fikirleri gelen kutunuza gelsin.', 'Exklusive Angebote und Reiseideen direkt in Ihr Postfach.', 'Эксклюзивные предложения и идеи для путешествий прямо в вашей почте.', 'Recevez des offres exclusives et des idées de voyage dans votre boîte mail.', '将专属优惠与旅行灵感发送到您的邮箱。'],
    'With Chisfis, booking resorts, villas, hotels, private homes, and apartments becomes quick, convenient, and easy.': ['Chisfis ile tatil köyü, villa, otel ve ev rezervasyonu hızlı ve kolay.', 'Mit Chisfis buchen Sie Resorts, Villen, Hotels und Wohnungen schnell und einfach.', 'С Chisfis бронировать курорты, виллы, отели и апартаменты быстро и удобно.', 'Avec Chisfis, réservez rapidement et facilement hôtels, villas et appartements.', '通过 Chisfis，快捷方便地预订度假村、别墅、酒店和公寓。'],
    'Explore houses based on 10 types of stays': ['10 konaklama türünü keşfedin', 'Entdecken Sie 10 Unterkunftsarten', 'Откройте 10 типов жилья', 'Découvrez 10 types d’hébergement', '探索 10 种住宿类型'],
    'Suggested locations': ['Önerilen konumlar', 'Vorgeschlagene Orte', 'Рекомендуемые места', 'Destinations suggérées', '推荐地点'],
    'Where are you going?': ['Nereye gidiyorsunuz?', 'Wohin möchten Sie reisen?', 'Куда вы хотите поехать?', 'Où allez-vous ?', '您想去哪里？'],
    'Where do you want to go?': ['Nereye gitmek istiyorsunuz?', 'Wohin möchten Sie reisen?', 'Куда вы хотите поехать?', 'Où souhaitez-vous aller ?', '您想去哪里？']
  };
  // Shared storefront chrome uses Turkish source keys in its server markup.
  var shellCopy = {
    'Tarih, kişi': ['Tarih, kişi', 'Dates, guests', 'Datum, Gäste', 'Даты, гости', 'Dates, voyageurs', '日期、人数'],
    'Anasayfa': ['Anasayfa', 'Home', 'Startseite', 'Главная', 'Accueil', '首页'],
    'Arama': ['Arama', 'Search', 'Suche', 'Поиск', 'Recherche', '搜索'],
    'Destek': ['Destek', 'Support', 'Hilfe', 'Поддержка', 'Assistance', '客服'],
    'Menüyü aç': ['Menüyü aç', 'Open menu', 'Menü öffnen', 'Открыть меню', 'Ouvrir le menu', '打开菜单'],
    'Güven ve ödeme bilgileri': ['Güven ve ödeme bilgileri', 'Security and payment information', 'Sicherheits- und Zahlungsinformationen', 'Информация о безопасности и оплате', 'Sécurité et moyens de paiement', '安全与支付信息'],
    '256 bit SSL sertifikası': ['256 bit SSL sertifikası', '256-bit SSL certificate', '256-Bit-SSL-Zertifikat', '256-битный SSL-сертификат', 'Certificat SSL 256 bits', '256 位 SSL 证书'],
    'Güvenli bağlantı': ['Güvenli bağlantı', 'Secure connection', 'Sichere Verbindung', 'Безопасное соединение', 'Connexion sécurisée', '安全连接'],
    'Kredi kartına 12 taksit': ['Kredi kartına 12 taksit', '12 credit card installments', '12 Kreditkartenraten', '12 платежей по кредитной карте', 'Paiement par carte en 12 fois', '信用卡分 12 期付款'],
    'Esnek ödeme seçeneği': ['Esnek ödeme seçeneği', 'Flexible payment option', 'Flexible Zahlungsoption', 'Гибкий способ оплаты', 'Option de paiement flexible', '灵活支付选项'],
    'TÜRSAB belgesi: 13127': ['TÜRSAB belgesi: 13127', 'TÜRSAB license: 13127', 'TÜRSAB-Lizenz: 13127', 'Лицензия TÜRSAB: 13127', 'Licence TÜRSAB : 13127', 'TÜRSAB 许可证：13127'],
    'Belge numarası': ['Belge numarası', 'License number', 'Lizenznummer', 'Номер лицензии', 'Numéro de licence', '许可证编号'],
    'NEXUS İÇERİK': ['NEXUS İÇERİK', 'NEXUS GUIDE', 'NEXUS RATGEBER', 'ГИД NEXUS', 'GUIDE NEXUS', 'NEXUS 指南'],
    'Seyahat planlaması nasıl çalışır?': ['Seyahat planlaması nasıl çalışır?', 'How does travel planning work?', 'Wie funktioniert die Reiseplanung?', 'Как работает планирование поездки?', 'Comment organiser votre voyage ?', '如何规划旅行？'],
    'Seyahat seçeneklerini keşfetme, karşılaştırma ve rezervasyon adımlarını öğrenin.': ['Seyahat seçeneklerini keşfetme, karşılaştırma ve rezervasyon adımlarını öğrenin.', 'Learn how to discover, compare and book travel options.', 'Erfahren Sie, wie Sie Reiseangebote entdecken, vergleichen und buchen.', 'Узнайте, как искать, сравнивать и бронировать варианты поездок.', 'Découvrez comment rechercher, comparer et réserver vos voyages.', '了解如何发现、比较和预订旅行产品。'],
    'Tedarikçiler için': ['Tedarikçiler için', 'For suppliers', 'Für Anbieter', 'Для поставщиков', 'Pour les prestataires', '面向供应商'],
    'Kendi ilanlarınızı, fiyatlarınızı ve müsaitliğinizi acente panelinde yönetin.': ['Kendi ilanlarınızı, fiyatlarınızı ve müsaitliğinizi acente panelinde yönetin.', 'Manage your own listings, prices and availability in the agency panel.', 'Verwalten Sie eigene Angebote, Preise und Verfügbarkeiten im Agenturportal.', 'Управляйте своими объявлениями, ценами и доступностью в панели агентства.', 'Gérez vos annonces, vos prix et vos disponibilités dans le portail agence.', '在旅行社后台管理您的房源、价格和可订状态。'],
    'Acenteler için': ['Acenteler için', 'For agencies', 'Für Reiseagenturen', 'Для агентств', 'Pour les agences', '面向旅行社'],
    'Kendi markanız ve ilanlarınızla bağımsız çalışın; isterseniz tedarikçi ağına bağlanın.': ['Kendi markanız ve ilanlarınızla bağımsız çalışın; isterseniz tedarikçi ağına bağlanın.', 'Work independently with your own brand and listings; connect to the supplier network if you wish.', 'Arbeiten Sie unabhängig mit Ihrer Marke und Ihren Angeboten; verbinden Sie sich bei Bedarf mit dem Anbieternetzwerk.', 'Работайте независимо под своим брендом и со своими объявлениями; при желании подключайтесь к сети поставщиков.', 'Travaillez librement avec votre marque et vos annonces ; connectez-vous au réseau de prestataires si vous le souhaitez.', '使用自己的品牌和产品独立运营，也可选择连接供应商网络。'],
    'Müşteriler için': ['Müşteriler için', 'For travelers', 'Für Reisende', 'Для путешественников', 'Pour les voyageurs', '面向旅行者'],
    'Size uygun seyahat seçeneklerini bulun, bilgileri karşılaştırın ve rezervasyonunuzu takip edin.': ['Size uygun seyahat seçeneklerini bulun, bilgileri karşılaştırın ve rezervasyonunuzu takip edin.', 'Find suitable travel options, compare details and track your booking.', 'Finden Sie passende Reisen, vergleichen Sie Details und verfolgen Sie Ihre Buchung.', 'Найдите подходящие поездки, сравните условия и отслеживайте бронирование.', 'Trouvez le voyage qui vous convient, comparez les détails et suivez votre réservation.', '寻找合适的旅行产品，比较详情并查看预订。'],
    'Arayın ve keşfedin': ['Arayın ve keşfedin', 'Search and explore', 'Suchen und entdecken', 'Ищите и открывайте', 'Recherchez et explorez', '搜索与探索'],
    'Konaklama, tur, yat ve diğer seyahat seçeneklerini kategoriye veya konuma göre inceleyin.': ['Konaklama, tur, yat ve diğer seyahat seçeneklerini kategoriye veya konuma göre inceleyin.', 'Browse stays, tours, yachts and other travel options by category or location.', 'Entdecken Sie Unterkünfte, Touren, Yachten und weitere Reisen nach Kategorie oder Ort.', 'Просматривайте жильё, туры, яхты и другие предложения по категории или месту.', 'Parcourez les hébergements, circuits, yachts et autres voyages par catégorie ou destination.', '按类别或地点浏览住宿、旅游、游艇及其他旅行产品。'],
    'Bilgileri karşılaştırın': ['Bilgileri karşılaştırın', 'Compare details', 'Details vergleichen', 'Сравнивайте детали', 'Comparez les détails', '比较详情'],
    'İlan açıklamalarını, fiyatları ve mevcut seçenekleri bir arada değerlendirerek size uygun olanı seçin.': ['İlan açıklamalarını, fiyatları ve mevcut seçenekleri bir arada değerlendirerek size uygun olanı seçin.', 'Review listing descriptions, prices and available options together to choose what suits you.', 'Vergleichen Sie Beschreibungen, Preise und verfügbare Optionen für Ihre Entscheidung.', 'Сравните описания, цены и доступные варианты, чтобы выбрать подходящее.', 'Consultez les descriptions, les prix et les disponibilités pour faire votre choix.', '结合房源描述、价格及可用选项，选择适合您的产品。'],
    'Rezervasyon adımına geçin': ['Rezervasyon adımına geçin', 'Continue to booking', 'Zur Buchung', 'Перейти к бронированию', 'Passez à la réservation', '继续预订'],
    'Seçtiğiniz ilandan talep oluşturun veya sunulan rezervasyon adımlarını izleyin; hesabınızdan süreci takip edin.': ['Seçtiğiniz ilandan talep oluşturun veya sunulan rezervasyon adımlarını izleyin; hesabınızdan süreci takip edin.', 'Send an inquiry for your chosen listing or follow its booking steps; track progress in your account.', 'Senden Sie eine Anfrage oder folgen Sie den Buchungsschritten; verfolgen Sie den Vorgang in Ihrem Konto.', 'Отправьте запрос или пройдите шаги бронирования; отслеживайте процесс в личном кабинете.', 'Envoyez une demande ou suivez les étapes de réservation ; retrouvez le suivi dans votre compte.', '针对所选产品提交咨询或按步骤预订，并在账户中查看进度。'],
    'İlanlarınız sizin kontrolünüzde': ['İlanlarınız sizin kontrolünüzde', 'Your listings, your control', 'Ihre Angebote in Ihrer Hand', 'Ваши объявления под вашим контролем', 'Gardez le contrôle de vos annonces', '自主掌控您的产品'],
    'Otel, tatil evi, yat, tur ve diğer kategorilerdeki kendi ürünlerinizi doğrudan acente panelinden oluşturup düzenleyebilirsiniz.': ['Otel, tatil evi, yat, tur ve diğer kategorilerdeki kendi ürünlerinizi doğrudan acente panelinden oluşturup düzenleyebilirsiniz.', 'Create and edit your own hotels, holiday homes, yachts, tours and other products directly in the agency panel.', 'Erstellen und bearbeiten Sie Hotels, Ferienhäuser, Yachten, Touren und weitere Angebote direkt im Agenturportal.', 'Создавайте и редактируйте собственные отели, дома отдыха, яхты, туры и другие продукты в панели агентства.', 'Créez et modifiez vos hôtels, maisons de vacances, yachts, circuits et autres offres dans le portail agence.', '直接在旅行社后台创建和编辑酒店、度假屋、游艇、旅游等产品。'],
    'Fiyat ve müsaitliği yönetin': ['Fiyat ve müsaitliği yönetin', 'Manage price and availability', 'Preise und Verfügbarkeit verwalten', 'Управляйте ценой и доступностью', 'Gérez prix et disponibilités', '管理价格和可订状态'],
    'Yayın durumunu, fiyat bilgilerini ve müsaitliği kendi operasyonunuza göre güncel tutun.': ['Yayın durumunu, fiyat bilgilerini ve müsaitliği kendi operasyonunuza göre güncel tutun.', 'Keep publication status, prices and availability aligned with your operation.', 'Halten Sie Veröffentlichungsstatus, Preise und Verfügbarkeiten aktuell.', 'Поддерживайте статус публикации, цены и доступность в актуальном состоянии.', 'Maintenez à jour la publication, les prix et les disponibilités selon votre activité.', '根据运营情况更新发布状态、价格和可订状态。'],
    'İş birliğini seçin': ['İş birliğini seçin', 'Choose how to collaborate', 'Zusammenarbeit gestalten', 'Выберите формат сотрудничества', 'Choisissez votre collaboration', '选择合作方式'],
    'Acenteyle yerel olarak çalışabilir veya uygun olduğunda merkezi tedarikçi bağlantısından yararlanabilirsiniz.': ['Acenteyle yerel olarak çalışabilir veya uygun olduğunda merkezi tedarikçi bağlantısından yararlanabilirsiniz.', 'Work locally with an agency or use the central supplier connection when appropriate.', 'Arbeiten Sie lokal mit einer Agentur oder nutzen Sie bei Bedarf die zentrale Anbindung.', 'Работайте с агентством напрямую или используйте центральное подключение при необходимости.', 'Travaillez directement avec une agence ou utilisez la connexion centrale si elle vous convient.', '可直接与旅行社合作，也可按需使用中央供应商连接。'],
    'Kendi markanızla yayın yapın': ['Kendi markanızla yayın yapın', 'Publish under your brand', 'Unter Ihrer Marke veröffentlichen', 'Публикуйте под своим брендом', 'Publiez sous votre marque', '以您的品牌发布'],
    'Acente sitenizi ve vitrininizi kendi markanızla yönetin; temel işlevler merkezi bağlantı olmadan da çalışır.': ['Acente sitenizi ve vitrininizi kendi markanızla yönetin; temel işlevler merkezi bağlantı olmadan da çalışır.', 'Run your agency site under your own brand; core features work without a central connection.', 'Betreiben Sie Ihre Agenturwebsite unter eigener Marke; Kernfunktionen laufen auch ohne zentrale Verbindung.', 'Ведите сайт агентства под своим брендом; основные функции работают без центрального подключения.', 'Gérez votre site à votre marque ; les fonctions essentielles restent disponibles sans connexion centrale.', '以自有品牌运营旅行社网站；核心功能无需中央连接即可运行。'],
    'Yerel ilanlarınızı yönetin': ['Yerel ilanlarınızı yönetin', 'Manage local listings', 'Eigene Angebote verwalten', 'Управляйте своими объявлениями', 'Gérez vos annonces locales', '管理自有产品'],
    'Kendi otel, tatil evi, tur, araç ve diğer ilanlarınızı panelden oluşturun, düzenleyin ve yayınlayın.': ['Kendi otel, tatil evi, tur, araç ve diğer ilanlarınızı panelden oluşturun, düzenleyin ve yayınlayın.', 'Create, edit and publish your own hotels, holiday homes, tours, cars and other listings from the panel.', 'Erstellen, bearbeiten und veröffentlichen Sie Hotels, Ferienhäuser, Touren, Autos und weitere Angebote im Portal.', 'Создавайте, редактируйте и публикуйте свои отели, дома отдыха, туры, автомобили и другие предложения.', 'Créez, modifiez et publiez vos hôtels, maisons de vacances, circuits, voitures et autres annonces.', '在后台创建、编辑和发布酒店、度假屋、旅游、车辆等自有产品。'],
    'Tedarikçi ağına isteğe bağlı bağlanın': ['Tedarikçi ağına isteğe bağlı bağlanın', 'Connect to suppliers when you choose', 'Optional mit Anbietern verbinden', 'Подключайтесь к поставщикам по желанию', 'Connectez-vous aux prestataires à votre rythme', '按需连接供应商'],
    'Dilerseniz harici tedarikçi ilanlarını sitenizde yayınlamak için merkezi ağla bağlantı kurun.': ['Dilerseniz harici tedarikçi ilanlarını sitenizde yayınlamak için merkezi ağla bağlantı kurun.', 'Connect to the central network if you want to publish external supplier listings on your site.', 'Verbinden Sie sich bei Bedarf mit dem zentralen Netzwerk, um externe Angebote auf Ihrer Website zu veröffentlichen.', 'Подключайтесь к центральной сети, если хотите публиковать предложения внешних поставщиков.', 'Connectez-vous au réseau central si vous souhaitez publier des offres externes sur votre site.', '若希望在网站上发布外部供应商产品，可连接中央网络。'],
    'Size uygun seyahati bulun': ['Size uygun seyahati bulun', 'Find your trip', 'Finden Sie Ihre Reise', 'Найдите свою поездку', 'Trouvez votre voyage', '寻找适合您的旅行'],
    'Farklı kategorilerdeki ilanları ve konumları keşfederek seyahatinize uygun seçenekleri bulun.': ['Farklı kategorilerdeki ilanları ve konumları keşfederek seyahatinize uygun seçenekleri bulun.', 'Explore listings and locations across categories to find an option for your trip.', 'Entdecken Sie Angebote und Orte in verschiedenen Kategorien für Ihre Reise.', 'Изучайте объявления и направления в разных категориях, чтобы найти подходящий вариант.', 'Explorez les annonces et destinations de différentes catégories pour trouver votre voyage.', '探索不同类别和目的地的产品，找到适合您的旅行。'],
    'Kararınızı bilgiyle verin': ['Kararınızı bilgiyle verin', 'Choose with confidence', 'Informiert entscheiden', 'Принимайте взвешенное решение', 'Choisissez en connaissance de cause', '充分了解后再选择'],
    'İlanın açıklamasını, fiyatını, kapasitesini ve sunulan koşulları birlikte inceleyin.': ['İlanın açıklamasını, fiyatını, kapasitesini ve sunulan koşulları birlikte inceleyin.', 'Review the listing description, price, capacity and terms before choosing.', 'Prüfen Sie Beschreibung, Preis, Kapazität und Bedingungen vor Ihrer Wahl.', 'Проверьте описание, цену, вместимость и условия перед выбором.', 'Consultez la description, le prix, la capacité et les conditions avant de choisir.', '选择前查看产品描述、价格、容量和条款。'],
    'Süreci takip edin': ['Süreci takip edin', 'Track your request', 'Vorgang verfolgen', 'Следите за запросом', 'Suivez votre demande', '查看进度'],
    'Rezervasyon ve talepleriniz için hesabınızı kullanın; yardıma ihtiyaç duyduğunuzda bizimle iletişime geçin.': ['Rezervasyon ve talepleriniz için hesabınızı kullanın; yardıma ihtiyaç duyduğunuzda bizimle iletişime geçin.', 'Use your account for bookings and inquiries, and contact us whenever you need help.', 'Verwalten Sie Buchungen und Anfragen in Ihrem Konto und kontaktieren Sie uns bei Fragen.', 'Используйте личный кабинет для бронирований и запросов; при необходимости свяжитесь с нами.', 'Retrouvez réservations et demandes dans votre compte et contactez-nous si besoin.', '在账户中查看预订和咨询，需要帮助时请联系我们。'],
    'Nasıl çalışır?': ['Nasıl çalışır?', 'How it works', 'So funktioniert es', 'Как это работает', 'Comment ça marche', '如何运作'],
    'Müşteri rehberi': ['Müşteri rehberi', 'Traveler guide', 'Reiseführer', 'Путеводитель', 'Guide du voyageur', '旅行者指南'],
    'Seyahati keşfet': ['Seyahati keşfet', 'Explore travel', 'Reisen entdecken', 'Открыть путешествия', 'Explorer les voyages', '探索旅行'],
    'Bizimle çalışın': ['Bizimle çalışın', 'Work with us', 'Mit uns arbeiten', 'Сотрудничать с нами', 'Travailler avec nous', '与我们合作'],
    'Bağımsız acente yönetimi': ['Bağımsız acente yönetimi', 'Independent agency management', 'Unabhängige Agenturverwaltung', 'Независимое управление агентством', 'Gestion autonome des agences', '独立运营旅行社'],
    'İsteğe bağlı tedarikçi ağı': ['İsteğe bağlı tedarikçi ağı', 'Optional supplier network', 'Optionales Anbieternetzwerk', 'Подключаемая сеть поставщиков', 'Réseau de prestataires facultatif', '可选供应商网络'],
    'Tek yerden seyahat planı': ['Tek yerden seyahat planı', 'Travel planning in one place', 'Reiseplanung an einem Ort', 'Планирование поездки в одном месте', 'Voyage organisé au même endroit', '一站式旅行规划'],
    'Bir sorunuz mu var?': ['Bir sorunuz mu var?', 'Have a question?', 'Haben Sie eine Frage?', 'Есть вопрос?', 'Une question ?', '有疑问吗？'],
    'Seyahatiniz veya iş ortaklığı için bize ulaşın.': ['Seyahatiniz veya iş ortaklığı için bize ulaşın.', 'Contact us about your trip or a partnership.', 'Kontaktieren Sie uns zu Ihrer Reise oder einer Partnerschaft.', 'Свяжитесь с нами по поводу поездки или сотрудничества.', 'Contactez-nous pour votre voyage ou un partenariat.', '有关旅行或合作事宜，请联系我们。'],
    'İletişime geçin': ['İletişime geçin', 'Contact us', 'Kontakt aufnehmen', 'Связаться с нами', 'Nous contacter', '联系我们'],
    'Seyahati planlayanları, acenteleri ve tedarikçileri bir araya getiriyoruz.': ['Seyahati planlayanları, acenteleri ve tedarikçileri bir araya getiriyoruz.', 'Bringing travelers, agencies and suppliers together.', 'Wir bringen Reisende, Agenturen und Anbieter zusammen.', 'Мы объединяем путешественников, агентства и поставщиков.', 'Nous réunissons voyageurs, agences et prestataires.', '连接旅行者、旅行社和供应商。'],
    'Site Kullanımı': ['Site Kullanımı', 'Explore the site', 'Website nutzen', 'Сайт', 'Utiliser le site', '使用网站'],
    'Seyahat seçeneklerini keşfedin ve karşılaştırın.': ['Seyahat seçeneklerini keşfedin ve karşılaştırın.', 'Discover and compare travel options.', 'Entdecken und vergleichen Sie Reiseangebote.', 'Изучайте и сравнивайте варианты путешествий.', 'Découvrez et comparez les options de voyage.', '发现并比较旅行选择。'],
    'Tüm ilanları keşfet': ['Tüm ilanları keşfet', 'Explore all listings', 'Alle Angebote entdecken', 'Смотреть все предложения', 'Voir toutes les annonces', '查看全部房源'],
    'Tatil evleri': ['Tatil evleri', 'Holiday homes', 'Ferienhäuser', 'Дома для отдыха', 'Maisons de vacances', '度假屋'],
    'Yatlar': ['Yatlar', 'Yachts', 'Yachten', 'Яхты', 'Yachts', '游艇'],
    'Turlar ve deneyimler': ['Turlar ve deneyimler', 'Tours and experiences', 'Touren und Erlebnisse', 'Туры и впечатления', 'Circuits et expériences', '旅游与体验'],
    'Tedarikçiler İçin': ['Tedarikçiler İçin', 'For suppliers', 'Für Anbieter', 'Для поставщиков', 'Pour les prestataires', '面向供应商'],
    'Kendi ilanlarınızı, fiyatlarınızı ve müsaitliğinizi yönetin.': ['Kendi ilanlarınızı, fiyatlarınızı ve müsaitliğinizi yönetin.', 'Manage your listings, prices and availability.', 'Verwalten Sie Ihre Angebote, Preise und Verfügbarkeiten.', 'Управляйте объявлениями, ценами и доступностью.', 'Gérez vos annonces, vos prix et vos disponibilités.', '管理您的房源、价格和可订状态。'],
    'Tedarikçi paneline giriş': ['Tedarikçi paneline giriş', 'Supplier sign in', 'Anbieter-Anmeldung', 'Вход для поставщиков', 'Connexion prestataire', '供应商登录'],
    'İlanlarınızı yönetin': ['İlanlarınızı yönetin', 'Manage your listings', 'Angebote verwalten', 'Управлять объявлениями', 'Gérer vos annonces', '管理房源'],
    'Tedarikçi olarak başlayın': ['Tedarikçi olarak başlayın', 'Become a supplier', 'Anbieter werden', 'Стать поставщиком', 'Devenir prestataire', '成为供应商'],
    'Acenteler İçin': ['Acenteler İçin', 'For agencies', 'Für Reiseagenturen', 'Для агентств', 'Pour les agences', '面向旅行社'],
    'Kendi sitenizi bağımsız yönetin; dilerseniz tedarikçi ağına bağlanın.': ['Kendi sitenizi bağımsız yönetin; dilerseniz tedarikçi ağına bağlanın.', 'Run your own site independently and connect to the supplier network when you choose.', 'Betreiben Sie Ihre Website unabhängig und verbinden Sie sich bei Bedarf mit dem Anbieternetzwerk.', 'Управляйте своим сайтом независимо и подключайтесь к сети поставщиков по желанию.', 'Gérez votre site en toute autonomie et connectez-vous au réseau de prestataires si vous le souhaitez.', '独立运营您的网站，并可按需连接供应商网络。'],
    'Acente paneline giriş': ['Acente paneline giriş', 'Agency sign in', 'Agentur-Anmeldung', 'Вход для агентств', 'Connexion agence', '旅行社登录'],
    'Acente olarak başlayın': ['Acente olarak başlayın', 'Become an agency', 'Agentur werden', 'Стать агентством', 'Devenir agence', '成为旅行社'],
    'İş birliği hakkında bilgi alın': ['İş birliği hakkında bilgi alın', 'Ask about partnership', 'Partnerschaft anfragen', 'Узнать о сотрудничестве', 'En savoir plus sur le partenariat', '了解合作机会'],
    'Müşteriler İçin': ['Müşteriler İçin', 'For travelers', 'Für Reisende', 'Для путешественников', 'Pour les voyageurs', '面向旅行者'],
    'Size uygun seyahati bulun, rezervasyonunuzu takip edin.': ['Size uygun seyahati bulun, rezervasyonunuzu takip edin.', 'Find the right trip and track your bookings.', 'Finden Sie Ihre Reise und verfolgen Sie Ihre Buchungen.', 'Найдите подходящую поездку и отслеживайте бронирования.', 'Trouvez le voyage idéal et suivez vos réservations.', '找到合适的旅行并查看预订。'],
    'Seyahat seçenekleri': ['Seyahat seçenekleri', 'Travel options', 'Reiseangebote', 'Варианты поездок', 'Options de voyage', '旅行选择'],
    'Hesabım ve rezervasyonlarım': ['Hesabım ve rezervasyonlarım', 'My account and bookings', 'Mein Konto und Buchungen', 'Мой аккаунт и бронирования', 'Mon compte et mes réservations', '我的账户与预订'],
    'Yardım ve iletişim': ['Yardım ve iletişim', 'Help and contact', 'Hilfe und Kontakt', 'Помощь и контакты', 'Aide et contact', '帮助与联系'],
    'Tüm hakları saklıdır.': ['Tüm hakları saklıdır.', 'All rights reserved.', 'Alle Rechte vorbehalten.', 'Все права защищены.', 'Tous droits réservés.', '版权所有。'],
    'Katalog': ['Katalog', 'Catalog', 'Katalog', 'Каталог', 'Catalogue', '目录'],
    'Kategoriler': ['Kategoriler', 'Categories', 'Kategorien', 'Категории', 'Catégories', '分类'],
    'Bildirimler': ['Bildirimler', 'Notifications', 'Benachrichtigungen', 'Уведомления', 'Notifications', '通知'],
    'Hesap menüsünü aç': ['Hesap menüsünü aç', 'Open account menu', 'Kontomenü öffnen', 'Открыть меню аккаунта', 'Ouvrir le menu du compte', '打开账户菜单'],
    'Nereye?': ['Nereye?', 'Where to?', 'Wohin?', 'Куда?', 'Où aller ?', '去哪里？'],
    'Herhangi bir hafta': ['Herhangi bir hafta', 'Any week', 'Beliebige Woche', 'Любая неделя', 'N’importe quelle semaine', '任意一周'],
    'Misafir ekle': ['Misafir ekle', 'Add guests', 'Gäste hinzufügen', 'Добавить гостей', 'Ajouter des voyageurs', '添加房客'],
    'Zarif hiyerarşiler inşa ederek dünyayı daha iyi bir yer yapıyoruz.': ['Zarif hiyerarşiler inşa ederek dünyayı daha iyi bir yer yapıyoruz.', 'We make the world a better place by building elegant hierarchies.', 'Wir machen die Welt zu einem besseren Ort, indem wir elegante Hierarchien aufbauen.', 'Мы делаем мир лучше, создавая элегантные иерархии.', 'Nous rendons le monde meilleur en créant des liens harmonieux.', '我们通过构建优雅的层次结构，让世界更美好。'],
    'Rezervasyon': ['Rezervasyon', 'Booking', 'Buchung', 'Бронирование', 'Réservation', '预订'],
    'Konaklamalar': ['Konaklamalar', 'Stays', 'Unterkünfte', 'Проживание', 'Hébergements', '住宿'],
    'Deneyimler': ['Deneyimler', 'Experiences', 'Erlebnisse', 'Впечатления', 'Expériences', '体验'],
    'Araç kiralama': ['Araç kiralama', 'Car rental', 'Autovermietung', 'Аренда автомобилей', 'Location de voitures', '租车'],
    'Uçuşlar': ['Uçuşlar', 'Flights', 'Flüge', 'Перелёты', 'Vols', '航班'],
    'Keşfedin': ['Keşfedin', 'Discover', 'Entdecken', 'Откройте', 'Découvrir', '探索'],
    'Yardım merkezi': ['Yardım merkezi', 'Help center', 'Hilfezentrum', 'Справочный центр', 'Centre d’aide', '帮助中心'],
    'Haritada ara': ['Haritada ara', 'Search on map', 'Auf der Karte suchen', 'Поиск на карте', 'Rechercher sur la carte', '在地图上搜索'],
    'Ev sahiplerimizle tanışın': ['Ev sahiplerimizle tanışın', 'Meet our hosts', 'Lernen Sie unsere Gastgeber kennen', 'Познакомьтесь с нашими хозяевами', 'Rencontrez nos hôtes', '认识我们的房东'],
    'Şirket': ['Şirket', 'Company', 'Unternehmen', 'Компания', 'Entreprise', '公司'],
    'Hakkımızda': ['Hakkımızda', 'About us', 'Über uns', 'О нас', 'À propos', '关于我们'],
    'Günlük': ['Günlük', 'Journal', 'Journal', 'Журнал', 'Journal', '旅行日志'],
    'İletişim': ['İletişim', 'Contact', 'Kontakt', 'Контакты', 'Contact', '联系我们'],
    'Gayrimenkul': ['Gayrimenkul', 'Real estate', 'Immobilien', 'Недвижимость', 'Immobilier', '房地产'],
    'Yasal': ['Yasal', 'Legal', 'Rechtliches', 'Правовая информация', 'Mentions légales', '法律信息'],
    'Kullanım şartları': ['Kullanım şartları', 'Terms of use', 'Nutzungsbedingungen', 'Условия использования', 'Conditions d’utilisation', '使用条款'],
    'Gizlilik politikası': ['Gizlilik politikası', 'Privacy policy', 'Datenschutzerklärung', 'Политика конфиденциальности', 'Politique de confidentialité', '隐私政策'],
    'Çerez politikası': ['Çerez politikası', 'Cookie policy', 'Cookie-Richtlinie', 'Политика использования файлов cookie', 'Politique des cookies', 'Cookie 政策'],
    'Keşfet': ['Keşfet', 'Explore', 'Entdecken', 'Обзор', 'Explorer', '探索'],
    'Favoriler': ['Favoriler', 'Favorites', 'Favoriten', 'Избранное', 'Favoris', '收藏'],
    'Hesap': ['Hesap', 'Account', 'Konto', 'Аккаунт', 'Compte', '账户'],
    'Menü': ['Menü', 'Menu', 'Menü', 'Меню', 'Menu', '菜单']
  };
  var shellLanguages = { tr: 0, en: 1, de: 2, ru: 3, fr: 4, zh: 5 };
  var languages = { tr: 0, de: 1, ru: 2, fr: 3, zh: 4 };
  var localeTags = { tr: 'tr-TR', en: 'en-US', de: 'de-DE', ru: 'ru-RU', fr: 'fr-FR', zh: 'zh-CN' };
  var monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  var weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  var weekdayShort = {
    tr: ['Pz', 'Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct'], de: ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'],
    ru: ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'], fr: ['Di', 'Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa'], zh: ['日', '一', '二', '三', '四', '五', '六']
  };
  var listingTypes = {
    'Entire cabin': ['Tüm kır evi', 'Ganze Hütte', 'Домик целиком', 'Cabane entière', '整栋小屋'],
    'Holiday home': ['Tatil evi', 'Ferienhaus', 'Дом для отдыха', 'Maison de vacances', '度假屋'],
    'Home stay': ['Ev konaklaması', 'Privatunterkunft', 'Проживание в доме', 'Chambre chez l’habitant', '民宿'],
    'Hotel room': ['Otel odası', 'Hotelzimmer', 'Номер в отеле', 'Chambre d’hôtel', '酒店客房']
  };
  function language() { return (window.NEXUS_LOCALE && window.NEXUS_LOCALE.lang) || (document.cookie.match(/(?:^|;\s*)nexus_lang=([^;]+)/) || [])[1] || 'tr'; }
  var turkishSource = {};
  Object.keys(copy).forEach(function (key) { if (copy[key] && copy[key][0]) turkishSource[copy[key][0]] = key; });
  function sourceKey(key) { return turkishSource[key] || (window.NEXUS_SOURCE_KEY && window.NEXUS_SOURCE_KEY(key)) || key; }
  function value(key, lang) {
    key = sourceKey(key);
    if (lang === 'en') return key;
    var row = copy[key];
    if (row) return row[languages[lang]] || key;
    return window.NEXUS_T ? window.NEXUS_T(key) : key;
  }
  window.NEXUS_HOME_T = function (key, lang) {
    if (shellCopy[key] && shellLanguages[lang] !== undefined) return shellCopy[key][shellLanguages[lang]];
    return copy[key] && languages[lang] !== undefined ? copy[key][languages[lang]] : null;
  };
  function dynamicValue(key, lang) {
    if (/^[\d,.]+\+ ilan$/.test(key)) key = key.replace(/ ilan$/, ' properties');
    if (/^\d+ misafir$/.test(key)) key = key.replace(/ misafir$/, ' Guests');
    if (/^\d+ dakika sürüş$/.test(key)) key = key.replace(/ dakika sürüş$/, ' minutes drive');
    if (key === 'gece') key = 'night';
    var turkishTypes = { 'Tüm kır evi':'Entire cabin', 'Tatil evi':'Holiday home', 'Ev konaklaması':'Home stay', 'Otel odası':'Hotel room' };
    key = key.replace(/^(Tüm kır evi|Tatil evi|Ev konaklaması|Otel odası) · (\d+) yatak$/, function (_, type, beds) { return turkishTypes[type] + ' · ' + beds + ' beds'; });
    var trMonths = { Ocak:'January', Şubat:'February', Mart:'March', Nisan:'April', Mayıs:'May', Haziran:'June', Temmuz:'July', Ağustos:'August', Eylül:'September', Ekim:'October', Kasım:'November', Aralık:'December' };
    key = key.replace(/^([^ ]+) (\d{4})$/, function (whole, month, year) { return trMonths[month] ? trMonths[month] + ' ' + year : whole; });
    var trDays = { Pazar:'Sunday', Pazartesi:'Monday', Salı:'Tuesday', Çarşamba:'Wednesday', Perşembe:'Thursday', Cuma:'Friday', Cumartesi:'Saturday' };
    key = trDays[key] || key;
    if (lang === 'en') return key;
    var listing = key.match(/^(Entire cabin|Holiday home|Home stay|Hotel room) · (\d+) beds$/);
    if (listing) {
      var type = listingTypes[listing[1]][languages[lang]];
      var beds = { tr:'yatak', de:'Betten', ru:'кроватей', fr:'lits', zh:'张床' }[lang];
      return lang === 'zh' ? type + ' · ' + listing[2] + beds : type + ' · ' + listing[2] + ' ' + beds;
    }
    if (key === 'night') return { tr:'gece', de:'Nacht', ru:'ночь', fr:'nuit', zh:'晚' }[lang];
    var drive = key.match(/^(\d+) minutes drive$/);
    if (drive) return { tr:drive[1]+' dakika sürüş', de:drive[1]+' Minuten Fahrt', ru:drive[1]+' минут езды', fr:drive[1]+' minutes en voiture', zh:drive[1]+' 分钟车程' }[lang];
    var month = key.match(/^([A-Za-z]+) (\d{4})$/);
    if (month && monthNames.indexOf(month[1]) >= 0) {
      return new Intl.DateTimeFormat(localeTags[lang], { month:'long', year:'numeric' }).format(new Date(Number(month[2]), monthNames.indexOf(month[1]), 1));
    }
    var weekday = weekdays.indexOf(key);
    if (weekday >= 0) return new Intl.DateTimeFormat(localeTags[lang], { weekday:'long' }).format(new Date(2026, 8, 20 + weekday));
    var short = ['Su','Mo','Tu','We','Th','Fr','Sa'].indexOf(key);
    if (short >= 0) return weekdayShort[lang][short];
    return null;
  }
  function applyShell(lang) {
    document.querySelectorAll('header [data-i18n-aria-label], footer [data-i18n-aria-label], .bnav [data-i18n-aria-label]').forEach(function (element) {
      var key = element.getAttribute('data-i18n-aria-label');
      if (shellCopy[key] && shellLanguages[lang] !== undefined) element.setAttribute('aria-label', shellCopy[key][shellLanguages[lang]]);
    });
    document.querySelectorAll('header [data-i18n], footer [data-i18n], .bnav [data-i18n]').forEach(function (element) {
      var key = element.getAttribute('data-i18n');
      if (!shellCopy[key]) return;
      var translated = shellCopy[key][shellLanguages[lang]];
      var directText = Array.prototype.filter.call(element.childNodes, function (node) { return node.nodeType === 3 && node.textContent.trim(); });
      if (directText.length) {
        var node = directText[0];
        var updated = node.textContent.replace(/^(\s*)\S[\s\S]*?\S(\s*)$/, function (_, before, after) { return before + translated + after; });
        if (node.textContent !== updated) node.textContent = updated;
      } else if (!element.children.length && element.textContent !== translated) element.textContent = translated;
    });
    document.querySelectorAll('footer p').forEach(function (element) {
      var original = element.dataset.homeCopyright || element.textContent.trim();
      if (!/^© \d{4} NEXUS Agency · /.test(original)) return;
      element.dataset.homeCopyright = original;
      var suffix = { tr: 'Tüm hakları saklıdır.', en: 'All rights reserved.', de: 'Alle Rechte vorbehalten.', ru: 'Все права защищены.', fr: 'Tous droits réservés.', zh: '版权所有。' }[lang];
      var translated = original.replace(/ · .+$/, ' · ' + suffix);
      if (element.textContent !== translated) element.textContent = translated;
    });
  }
  function apply() {
    var lang = language();
    document.documentElement.lang = lang;
    applyShell(lang);
    var infoPage = document.querySelector('.cms-public-page');
    if (infoPage && /\/(nasil-calisir|tedarikciler-icin|acenteler-icin|musteriler-icin)\/?$/.test(location.pathname)) {
      infoPage.classList.add('nx-info-page');
      infoPage.querySelectorAll('h1, h2, p, .eyebrow, a').forEach(function (element) {
        if (element.children.length || !element.textContent.trim()) return;
        var key = element.dataset.infoI18n || element.textContent.trim();
        if (!shellCopy[key]) return;
        element.dataset.infoI18n = key;
        var translated = shellCopy[key][shellLanguages[lang]];
        if (element.textContent !== translated) element.textContent = translated;
      });
      var heading = infoPage.querySelector('h1');
      var summary = infoPage.querySelector(':scope > p');
      if (heading) document.title = heading.textContent + ' | NEXUS Agency';
      if (summary) {
        document.querySelectorAll('meta[name="description"], meta[property="og:description"]').forEach(function (meta) { meta.content = summary.textContent; });
      }
    }
    document.querySelectorAll('main *').forEach(function (node) {
      if (node.children.length || !node.textContent) return;
      var badgeKey = node.dataset.discountI18n || node.textContent.trim();
      if (badgeKey !== '-20% OFF') return;
      node.dataset.discountI18n = badgeKey;
      node.textContent = value(badgeKey, lang);
    });
    if (!isHome) return;
    document.querySelectorAll('main *').forEach(function (node) {
      if (node.children.length || !node.textContent || !node.textContent.trim()) return;
      if (/^(SCRIPT|STYLE|OPTION|SVG|TEXTAREA)$/.test(node.tagName)) return;
      var key = node.dataset.homeI18n || node.getAttribute('data-i18n') || node.textContent.trim();
      if (!Object.prototype.hasOwnProperty.call(copy, key) && !(window.NEXUS_T && window.NEXUS_T(key) !== key)) return;
      node.dataset.homeI18n = key;
      var translated = value(key, lang);
      if (node.textContent.trim() !== translated) node.textContent = translated;
    });
    document.querySelectorAll('main [placeholder]').forEach(function (node) {
      var key = node.dataset.homePlaceholder || node.getAttribute('data-i18n-placeholder') || node.getAttribute('placeholder');
      if (!key || (!copy[key] && !(window.NEXUS_T && window.NEXUS_T(key) !== key))) return;
      node.dataset.homePlaceholder = key;
      node.placeholder = value(key, lang);
    });
    document.querySelectorAll('main a, main button').forEach(function (element) {
      Array.prototype.forEach.call(element.childNodes, function (node) {
        if (node.nodeType !== 3 || !node.textContent.trim()) return;
        var key = node.__homeI18nKey || node.textContent.trim();
        if (!copy[key]) return;
        node.__homeI18nKey = key;
        var translated = value(key, lang);
        var updated = node.textContent.replace(/^(\s*)\S[\s\S]*?\S(\s*)$/, function (_, before, after) { return before + translated + after; });
        if (node.textContent !== updated) node.textContent = updated;
      });
    });
    document.querySelectorAll('main [data-home-i18n], main [data-i18n]').forEach(function (node) {
      var key = node.dataset.homeI18n || node.getAttribute('data-i18n');
      if (key && copy[key]) { var translated = value(key, lang); if (node.textContent !== translated) node.textContent = translated; }
    });
    document.querySelectorAll('main *').forEach(function (node) {
      if (node.children.length || !node.textContent) return;
      var key = node.dataset.homeCountKey || node.textContent.trim();
      var match = key.match(/^([\d,.]+)\+ properties$/);
      if (match) { node.dataset.homeCountKey = key; var countText = lang === 'tr' ? match[1] + '+ ilan' : lang === 'de' ? match[1] + '+ Unterkünfte' : lang === 'ru' ? match[1] + '+ вариантов жилья' : lang === 'fr' ? match[1] + '+ hébergements' : lang === 'zh' ? match[1] + '+ 处住宿' : key; if (node.textContent !== countText) node.textContent = countText; }
      var dynamicKey = node.dataset.homeDynamicKey || node.textContent.trim();
      var dynamicText = dynamicValue(dynamicKey, lang);
      if (dynamicText !== null) { node.dataset.homeDynamicKey = dynamicKey; if (node.textContent !== dynamicText) node.textContent = dynamicText; }
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', apply, { once: true });
  else apply();
  document.addEventListener('nexus:lang', function () { setTimeout(apply, 0); });
  document.addEventListener('nexus:category-sections-rendered', apply);
  var shellRefreshTimer;
  function watchShell() {
    var observer = new MutationObserver(function () {
      clearTimeout(shellRefreshTimer);
      shellRefreshTimer = setTimeout(function () { applyShell(language()); }, 0);
    });
    document.querySelectorAll('header, footer, .bnav').forEach(function (element) {
      observer.observe(element, { subtree: true, childList: true, characterData: true });
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', watchShell, { once: true });
  else watchShell();
  setTimeout(apply, 500);
  setTimeout(apply, 1400);
  setTimeout(apply, 3000);
})();
