/* Detail UI translations follow the site's locale event. Editorial content
 * uses stored translations and retains its Turkish source when unavailable. */
(() => {
  const languages = ['tr','en','de','ru','fr','zh'];
  const rows = [
    ['Tahmini toplam','Estimated total','Geschätzter Gesamtbetrag','Предварительная сумма','Total estimé','预计总额'],
    ['Tarihleri temizle','Clear dates','Daten löschen','Очистить даты','Effacer les dates','清除日期'],
    ['Favorilere ekle','Add to favourites','Zu Favoriten hinzufügen','Добавить в избранное','Ajouter aux favoris','加入收藏'],
    ['Paylaş','Share','Teilen','Поделиться','Partager','分享'],
    ['Görseller yakında eklenecek','Photos coming soon','Fotos folgen bald','Фото появятся скоро','Photos à venir','照片即将添加'],
    ['Seçilen aralıkta uygun olmayan gün var. Başka bir tarih seçin.','The selected range includes a booked day. Choose another date.','Der Zeitraum enthält einen belegten Tag. Wählen Sie ein anderes Datum.','В выбранном периоде есть занятый день. Выберите другую дату.','La période comprend un jour réservé. Choisissez une autre date.','所选时段包含已订日期，请选择其他日期。'],
    ['Demo müsaitlik takvimi: gri günler doludur; diğer tarihler için müsaitlik teyidi gerekir.','Demo calendar: grey days are booked; other dates require confirmation.','Demokalender: Graue Tage sind belegt; andere Termine benötigen Bestätigung.','Демо-календарь: серые дни заняты; остальные требуют подтверждения.','Calendrier démo : les jours gris sont réservés ; les autres doivent être confirmés.','演示日历：灰色日期已订，其他日期需确认。'],
    ['Yardım','Help','Hilfe','Помощь','Aide','帮助'],['Haritada arayın','Search on map','Auf der Karte suchen','Поиск на карте','Rechercher sur la carte','地图搜索'],['İş ortakları','Partners','Partner','Партнёры','Partenaires','合作伙伴'],['İlanınızı ekleyin','Add your listing','Inserat hinzufügen','Добавить объявление','Ajouter une annonce','添加房源'],['Tedarikçi paneli','Supplier dashboard','Anbieterbereich','Панель поставщика','Espace prestataire','供应商面板'],['Hesabınız','Your account','Ihr Konto','Ваш аккаунт','Votre compte','您的账户'],
    ['Ça','Wed','Mi','Ср','mer.','周三'],
    ['Bodrum Yalıkavak koyuna hakim panoramik manzarası, özel sonsuzluk havuzu, jakuzisi ve 4 lüks yatak odasıyla unutulmaz bir tatil deneyimi sunar.','Enjoy panoramic views over Bodrum’s Yalıkavak bay, a private infinity pool, a jacuzzi and four luxury bedrooms for an unforgettable holiday.','Panoramablick auf die Bucht von Yalıkavak, privater Infinitypool, Whirlpool und vier luxuriöse Schlafzimmer für einen unvergesslichen Urlaub.','Панорамный вид на бухту Ялыкавак, частный инфинити-бассейн, джакузи и четыре роскошные спальни для незабываемого отдыха.','Vue panoramique sur la baie de Yalıkavak, piscine à débordement privée, jacuzzi et quatre chambres luxueuses pour un séjour inoubliable.','俯瞰亚勒卡瓦克海湾全景，配备私人无边泳池、按摩浴缸和四间豪华卧室，带来难忘假期。'],
    ['Boşluk doldurma: Açıkken, iki dolu aralık arasındaki kısa müsait günleri dolduran konaklamalarda minimum gece kuralı uygulanmaz.','Gap filling: when enabled, the minimum stay does not apply to short stays filling a gap between two booked periods.','Lückenfüllung: Falls aktiviert, entfällt der Mindestaufenthalt für kurze Buchungslücken zwischen zwei belegten Zeiträumen.','Заполнение промежутков: если включено, минимальный срок не применяется к коротким промежуткам между бронированиями.','Comblement des disponibilités : si activé, le séjour minimum ne s’applique pas aux courts intervalles entre deux réservations.','填补空档：启用后，填补两个已订时段之间短暂空档的住宿不受最少晚数限制。'],
    ['Bodrum için gezi önerileri','Trip ideas for Bodrum','Ausflugstipps für Bodrum','Идеи поездок в Бодруме','Idées de visites à Bodrum','博德鲁姆游览建议'],
    ['Torba ve Bodrum çevresini keşfedin • Demo gezi planları','Explore Torba and Bodrum • Sample itineraries','Torba und Bodrum entdecken • Beispielrouten','Откройте Торбу и Бодрум • Примеры маршрутов','Découvrez Torba et Bodrum • Exemples de visites','探索托尔巴与博德鲁姆 • 示例行程'],
    ['Bodrum’un tarihini keşfedin','Discover Bodrum’s history','Bodrums Geschichte entdecken','Откройте историю Бодрума','Découvrez l’histoire de Bodrum','探索博德鲁姆历史'],
    ['Bodrum Kalesi, Sualtı Arkeoloji Müzesi ve antik tiyatro ile kültür dolu bir gün.','A cultural day at Bodrum Castle, the Museum of Underwater Archaeology and the ancient theatre.','Ein Kulturtag mit Burg, Unterwasserarchäologiemuseum und antikem Theater.','День культуры: замок Бодрума, музей подводной археологии и античный театр.','Une journée culturelle au château, au musée d’archéologie sous-marine et au théâtre antique.','参观城堡、水下考古博物馆和古剧场，体验文化之旅。'],
    ['Koylarda deniz molası','A seaside break in the bays','Badepause in den Buchten','Отдых у моря в бухтах','Pause en bord de mer dans les baies','海湾休闲时光'],
    ['Torba sahilinde yürüyüş ve çevredeki koylarda yüzme molası.','Walk along Torba’s shore and swim in nearby bays.','Spaziergang am Torba-Strand und Schwimmen in nahen Buchten.','Прогулка по берегу Торбы и купание в соседних бухтах.','Promenade à Torba et baignade dans les baies voisines.','沿托尔巴海岸散步，在附近海湾游泳。'],
    ['Çarşı ve gün batımı','Market and sunset','Basar und Sonnenuntergang','Базар и закат','Marché et coucher de soleil','集市与日落'],
    ['Bodrum çarşısını gezin, marinada mola verin ve gün batımını izleyin.','Explore Bodrum’s market, relax at the marina and watch the sunset.','Bodrums Basar erkunden, am Hafen entspannen und den Sonnenuntergang genießen.','Посетите базар Бодрума, отдохните в марине и полюбуйтесь закатом.','Visitez le marché, faites une pause à la marina et admirez le coucher du soleil.','逛博德鲁姆集市，在码头休息并欣赏日落。'],
    ['♧ Öne çıkan sağlayıcı  |  ♙ 2+ yıl','♧ Featured provider  |  ♙ 2+ years','♧ Empfohlener Anbieter  |  ♙ 2+ Jahre','♧ Рекомендуемый поставщик  |  ♙ 2+ года','♧ Prestataire recommandé  |  ♙ 2+ ans','♧ 推荐供应商  |  ♙ 2年以上'],
    ['Özel havuz, konforlu yaşam alanları ve doğayla iç içe bir konumda misafirlerimizi ağırlıyoruz.','We welcome guests with a private pool, comfortable living spaces and natural surroundings.','Privater Pool, komfortable Wohnräume und eine naturnahe Umgebung erwarten Sie.','Частный бассейн, уютные помещения и окружение природы ждут гостей.','Piscine privée, espaces confortables et cadre naturel vous accueillent.','私人泳池、舒适空间与自然环境欢迎您的到来。'],
    ['Mart 2024’ten beri üye','Member since March 2024','Mitglied seit März 2024','Участник с марта 2024','Membre depuis mars 2024','2024年3月起加入'],
    ['WhatsApp\'ta paylaş','Share on WhatsApp','Auf WhatsApp teilen','Поделиться в WhatsApp','Partager sur WhatsApp','分享到WhatsApp'],
    ['Yorumunuz','Your review','Ihre Bewertung','Ваш отзыв','Votre avis','您的评价'],
    ['Önceki ay','Previous month','Vorheriger Monat','Предыдущий месяц','Mois précédent','上个月'],
    ['Sonraki ay','Next month','Nächster Monat','Следующий месяц','Mois suivant','下个月'],
    ['Demo önizleme: yorumunuz kaydedilmedi.','Demo preview: your review was not saved.','Demovorschau: Ihre Bewertung wurde nicht gespeichert.','Демо: отзыв не сохранён.','Démo : votre avis n’a pas été enregistré.','演示预览：评价未保存。'],
    ['Rezervasyon özeti','Booking summary','Buchungsübersicht','Сводка бронирования','Résumé de réservation','预订摘要'],
    ['Ödemeye geç','Proceed to payment','Zur Zahlung','Перейти к оплате','Passer au paiement','前往付款'],
    ['Daha fazla yorum göster','View more reviews','Weitere Bewertungen anzeigen','Показать больше отзывов','Afficher plus d’avis','查看更多评价'],
    ['Gösterilecek başka yorum bulunmuyor.','There are no more reviews to display.','Es gibt keine weiteren Bewertungen.','Больше отзывов нет.','Il n’y a pas d’autres avis à afficher.','没有更多评价。'],
    ['Konaklamak istediğiniz tarihleri seçerek müsaitliği kontrol edin.','Select your stay dates to check availability.','Wählen Sie Ihre Reisedaten, um die Verfügbarkeit zu prüfen.','Выберите даты проживания, чтобы проверить доступность.','Sélectionnez vos dates de séjour pour vérifier la disponibilité.','选择入住日期以查看空房情况。'],
    ['Olanaklar','Amenities','Ausstattung','Удобства','Équipements','设施'],
    ['İlanda belirtilen özellikler ve hizmetler','Property amenities and services','Ausstattung und Dienstleistungen','Удобства и услуги объекта','Équipements et services du logement','房源设施与服务'],
    ['Kampanyalar','Offers','Angebote','Предложения','Offres','优惠'],
    ['Konaklamanıza özel fırsatlar ve avantajlar.','Special offers for your stay.','Besondere Angebote für Ihren Aufenthalt.','Специальные предложения для проживания.','Offres spéciales pour votre séjour.','住宿专属优惠。'],
    ['Otel tanıtımı','About the hotel','Über das Hotel','Об отеле','À propos de l’hôtel','酒店介绍'],
    ['Tatil evi hakkında','About the holiday home','Über das Ferienhaus','О доме для отдыха','À propos de la maison','度假屋介绍'],
    ['Tesisi ve konaklama deneyimini yakından tanıyın.','Discover the property and your stay.','Entdecken Sie die Unterkunft.','Узнайте больше об объекте.','Découvrez le logement et votre séjour.','了解房源与住宿体验。'],
    ['Tesis Bilgileri','Property information','Informationen zur Unterkunft','Информация об объекте','Informations sur l’établissement','住宿信息'],
    ['Tesisin sunduğu hizmetler ve olanaklar.','Services and amenities at the property.','Dienstleistungen und Ausstattung.','Услуги и удобства объекта.','Services et équipements de l’établissement.','住宿提供的服务与设施。'],
    ['Konsept','Board basis','Verpflegungskonzept','Концепция питания','Formule de séjour','餐饮方案'],
    ['Oda Seçenekleri','Room options','Zimmeroptionen','Варианты номеров','Options de chambres','房型选择'],
    ['Oda özellikleri','Room amenities','Zimmerausstattung','Удобства номера','Équipements de la chambre','客房设施'],
    ['Tarih Seç','Select dates','Daten wählen','Выбрать даты','Choisir les dates','选择日期'],
    ['Tarih seçin','Select dates','Daten wählen','Выберите даты','Choisir les dates','选择日期'],
    ['Giriş – Çıkış','Check-in – Check-out','Anreise – Abreise','Заезд – Выезд','Arrivée – Départ','入住 – 退房'],
    ['Misafirler','Guests','Gäste','Гости','Voyageurs','客人'],
    ['Rezervasyon yap','Reserve','Reservieren','Забронировать','Réserver','预订'],
    ['Kurallar','House rules','Hausregeln','Правила проживания','Règlement intérieur','入住规则'],
    ['Giriş','Check-in','Anreise','Заезд','Arrivée','入住'],
    ['Çıkış','Check-out','Abreise','Выезд','Départ','退房'],
    ['Konum','Location','Lage','Расположение','Emplacement','位置'],
    ['Yakındaki mekanlar','Nearby places','Orte in der Nähe','Места поблизости','Lieux à proximité','附近地点'],
    ['Tesise göre mesafe (kuş uçuşu)','Distance from the property (straight line)','Entfernung zur Unterkunft (Luftlinie)','Расстояние от объекта (по прямой)','Distance depuis le logement (à vol d’oiseau)','距住宿距离（直线）'],
    ['Gezilecek Yerler','Places to visit','Sehenswürdigkeiten','Достопримечательности','Lieux à visiter','景点'],
    ['Temel İhtiyaçlar','Essentials','Grundbedarf','Необходимые услуги','Services essentiels','生活设施'],
    ['Ulaşım','Transport','Verkehr','Транспорт','Transports','交通'],
    ['Benzer ilanlar','Similar properties','Ähnliche Unterkünfte','Похожие объекты','Logements similaires','相似房源'],
    ['Yakındaki ilanlar','Nearby properties','Unterkünfte in der Nähe','Объекты поблизости','Logements à proximité','附近房源'],
    ['İlginizi çekebilecek diğer konaklama seçenekleri.','Other stays you may like.','Weitere Unterkünfte für Sie.','Другие варианты проживания.','D’autres séjours qui pourraient vous plaire.','您可能喜欢的其他住宿。'],
    ['Bu bölgenin yakınındaki konaklama seçenekleri.','Stays near this area.','Unterkünfte in dieser Gegend.','Жильё в этом районе.','Séjours près de cette région.','此地区附近的住宿。'],
    ['Yorumlar','Reviews','Bewertungen','Отзывы','Avis','评价'],
    ['Konaklayan misafirlerin değerlendirmeleri.','Reviews from guests.','Bewertungen von Gästen.','Отзывы гостей.','Avis des voyageurs.','住客评价。'],
    ['Deneyiminizi paylaşın…','Share your experience…','Teilen Sie Ihre Erfahrung…','Поделитесь впечатлениями…','Partagez votre expérience…','分享您的体验…'],
    ['Yorumu gönder','Submit review','Bewertung senden','Отправить отзыв','Envoyer l’avis','提交评价'],
    ['Profili gör','View profile','Profil ansehen','Посмотреть профиль','Voir le profil','查看资料'],
    ['Kapat','Close','Schließen','Закрыть','Fermer','关闭'],
    ['Paylaş ↗','Share ↗','Teilen ↗','Поделиться ↗','Partager ↗','分享 ↗'],
    ['Fiyat bilgileri','Pricing','Preise','Цены','Tarifs','价格'],
    ['Başlangıç fiyatı','Starting price','Ab-Preis','Цена от','À partir de','起价'],
    ['Havuz bilgisi','Pool information','Poolinformationen','Информация о бассейне','Informations sur la piscine','泳池信息'],
    ['Havuz özellikleri ve ölçüleri.','Pool features and dimensions.','Poolausstattung und Abmessungen.','Характеристики и размеры бассейна.','Caractéristiques et dimensions de la piscine.','泳池特点与尺寸。'],
    ['Ücretlendirme','Seasonal prices','Saisonpreise','Сезонные цены','Tarifs saisonniers','季节价格'],
    ['Dönem','Period','Zeitraum','Период','Période','时段'],
    ['Gecelik','Per night','Pro Nacht','За ночь','Par nuit','每晚'],
    ['Haftalık','Per week','Pro Woche','За неделю','Par semaine','每周'],
    ['Ek ücretler','Additional fees','Zusätzliche Gebühren','Дополнительные сборы','Frais supplémentaires','额外费用'],
    ['Hasar depozitosu','Damage deposit','Kaution','Залог','Dépôt de garantie','损坏押金'],
    ['Kısa konaklama ücreti','Short-stay fee','Kurzaufenthaltsgebühr','Сбор за короткое проживание','Frais de court séjour','短住费用'],
    ['Fiyata dahil / hariç','Included / excluded','Inklusive / exklusive','Включено / не включено','Inclus / non inclus','包含 / 不包含'],
    ['Dahil','Included','Inklusive','Включено','Inclus','包含'],
    ['Hariç','Excluded','Exklusive','Не включено','Non inclus','不包含'],
    ['Ek bilgi','Additional information','Weitere Informationen','Дополнительная информация','Informations complémentaires','附加信息'],
    ['Sıkça sorulan sorular','Frequently asked questions','Häufige Fragen','Частые вопросы','Questions fréquentes','常见问题'],
    ['Müsaitlik','Availability','Verfügbarkeit','Доступность','Disponibilités','可订日期'],
    ['Çocuklara uygun','Suitable for children','Für Kinder geeignet','Подходит для детей','Adapté aux enfants','适合儿童'],
    ['Evcil hayvan kabul edilmez','Pets are not allowed','Haustiere nicht erlaubt','Животные не допускаются','Animaux non admis','不允许宠物'],
    ['Etkinliklere uygun','Events allowed','Veranstaltungen erlaubt','Мероприятия разрешены','Événements autorisés','允许活动'],
    ['İç mekanda sigara içilmez','No indoor smoking','Rauchen innen verboten','Курение внутри запрещено','Non-fumeur à l’intérieur','室内禁烟'],
    ['Tümünü gör','View all','Alle ansehen','Показать все','Tout voir','查看全部'],
    ['Daha az göster','Show less','Weniger anzeigen','Показать меньше','Voir moins','收起'],
    ['Özel Havuz','Private pool','Privater Pool','Частный бассейн','Piscine privée','私人泳池'],
    ['Tatil Evi','Holiday home','Ferienhaus','Дом для отдыха','Maison de vacances','度假屋'],
    ['Tesis','Property','Unterkunft','Объект','Établissement','住宿'],
    ['gece','night','Nacht','ночь','nuit','晚'],
    ['misafir','guests','Gäste','гостей','voyageurs','位客人'],
    ['oda','rooms','Zimmer','комнат','chambres','间卧室'],
    ['banyo','bathrooms','Badezimmer','ванных','salles de bain','间浴室'],
    ['Demo','Demo','Demo','Демо','Démo','演示']
  ];
  rows.push(
    ['Döneme göre gecelik ve haftalık konaklama ücretleri.','Nightly and weekly rates by period.','Übernachtungs- und Wochenpreise nach Zeitraum.','Цены за ночь и неделю по периодам.','Tarifs par nuit et par semaine selon la période.','各时段每晚及每周住宿价格。'],
    ['Rezervasyon öncesinde ek ücretleri inceleyin.','Check additional fees before booking.','Prüfen Sie zusätzliche Gebühren vor der Buchung.','Уточните дополнительные сборы до бронирования.','Vérifiez les frais supplémentaires avant de réserver.','预订前查看额外费用。'],
    ['Rezervasyon öncesi dahil olan hizmetleri inceleyin.','Check included services before booking.','Prüfen Sie enthaltene Leistungen vor der Buchung.','Уточните включённые услуги до бронирования.','Vérifiez les services inclus avant de réserver.','预订前查看包含的服务。'],
    ['Konaklamadan önce giriş, çıkış ve rezervasyon koşullarını inceleyin.','Check arrival, departure and booking conditions before your stay.','Prüfen Sie Anreise-, Abreise- und Buchungsbedingungen.','Ознакомьтесь с условиями заезда, выезда и бронирования.','Consultez les conditions d’arrivée, de départ et de réservation.','入住前查看入住、退房及预订条件。'],
    ['Ödeme ve rezervasyon bilgileri.','Payment and booking information.','Zahlungs- und Buchungsinformationen.','Информация об оплате и бронировании.','Informations sur le paiement et la réservation.','付款及预订信息。'],
    ['Konaklamanız hakkında merak ettikleriniz.','Answers to questions about your stay.','Antworten zu Ihrem Aufenthalt.','Ответы на вопросы о проживании.','Réponses aux questions sur votre séjour.','住宿相关问题解答。'],
    ['Temizlik ücreti','Cleaning fee','Reinigungsgebühr','Плата за уборку','Frais de ménage','清洁费'],
    ['Elektrik Kullanımı','Electricity','Strom','Электричество','Électricité','电费'],
    ['Havuz Bakımı','Pool maintenance','Poolpflege','Уход за бассейном','Entretien de la piscine','泳池维护'],
    ['İlk Temizlik','Initial cleaning','Erstreinigung','Первичная уборка','Ménage initial','入住前清洁'],
    ['Su Kullanımı','Water','Wasser','Вода','Eau','水费'],
    ['Tüp Kullanımı','Cooking gas','Kochgas','Газ для приготовления пищи','Gaz de cuisine','烹饪燃气'],
    ['Ek Temizlik','Extra cleaning','Zusätzliche Reinigung','Дополнительная уборка','Ménage supplémentaire','额外清洁'],
    ['Ek Yatak','Extra bed','Zusatzbett','Дополнительная кровать','Lit supplémentaire','加床'],
    ['Ulaşım Hizmeti','Transport service','Transportservice','Транспортные услуги','Service de transport','交通服务'],
    ['Giriş ve çıkış saatleri nedir?','What are the check-in and check-out times?','Wann sind Anreise und Abreise?','Какое время заезда и выезда?','Quels sont les horaires d’arrivée et de départ ?','入住和退房时间是什么？'],
    ['Minimum kaç gece konaklamam gerekir?','What is the minimum stay?','Wie lange ist der Mindestaufenthalt?','Какова минимальная длительность проживания?','Quelle est la durée minimale du séjour ?','最少入住几晚？'],
    ['Hasar depozitosu nasıl iade edilir?','How is the damage deposit refunded?','Wie wird die Kaution erstattet?','Как возвращается залог?','Comment le dépôt de garantie est-il remboursé ?','损坏押金如何退还？'],
    ['Temizlik fiyata dahil mi?','Is cleaning included?','Ist die Reinigung inklusive?','Включена ли уборка?','Le ménage est-il inclus ?','清洁包含在价格内吗？'],
    ['Ön ödeme nasıl yapılır?','How is the advance payment made?','Wie erfolgt die Anzahlung?','Как внести предоплату?','Comment régler l’acompte ?','如何支付预付款？'],
    ['Giriş 16:00, çıkış 10:00.','Check-in 16:00, check-out 10:00.','Anreise 16:00, Abreise 10:00.','Заезд 16:00, выезд 10:00.','Arrivée 16:00, départ 10:00.','入住16:00，退房10:00。'],
    ['Minimum konaklama 3 gecedir.','The minimum stay is 3 nights.','Der Mindestaufenthalt beträgt 3 Nächte.','Минимальное проживание — 3 ночи.','Le séjour minimum est de 3 nuits.','最少入住3晚。'],
    ['Çıkışta tesis kontrolünden sonra hasar yoksa iade edilir.','Refunded after checkout inspection if there is no damage.','Nach der Kontrolle bei Abreise ohne Schäden erstattet.','Возвращается после проверки при выезде, если нет ущерба.','Remboursé après inspection au départ si aucun dommage n’est constaté.','退房检查无损坏后退还。'],
    ['İlk temizlik dahildir. Ek temizlik ayrıca ücretlendirilir.','Initial cleaning is included. Extra cleaning is charged separately.','Erstreinigung inklusive. Zusätzliche Reinigung wird separat berechnet.','Первичная уборка включена. Дополнительная оплачивается отдельно.','Le ménage initial est inclus. Le ménage supplémentaire est facturé séparément.','入住前清洁已包含，额外清洁另收费。'],
    ['Rezervasyon sırasında %30 ön ödeme veya tutarın tamamı ödenebilir.','Pay a 30% advance or the full amount when booking.','Bei Buchung können 30 % oder der Gesamtbetrag gezahlt werden.','При бронировании можно оплатить 30% или полную сумму.','Payez un acompte de 30 % ou la totalité lors de la réservation.','预订时可支付30%预付款或全款。']
  );
  rows.push(
    ['Havuz','Pool','Pool','Бассейн','Piscine','泳池'],['Deniz manzarası','Sea view','Meerblick','Вид на море','Vue sur la mer','海景'],['Korunaklı alan','Private area','Geschützter Bereich','Уединённая зона','Espace privé','私密区域'],['Klima','Air conditioning','Klimaanlage','Кондиционер','Climatisation','空调'],['Barbekü','Barbecue','Grill','Барбекю','Barbecue','烧烤'],['Otopark','Parking','Parkplatz','Парковка','Parking','停车场'],['Plaj','Beach','Strand','Пляж','Plage','海滩'],['Restoran','Restaurant','Restaurant','Ресторан','Restaurant','餐厅'],['Özel plaj','Private beach','Privatstrand','Частный пляж','Plage privée','私人海滩'],['Açık havuz','Outdoor pool','Außenpool','Открытый бассейн','Piscine extérieure','室外泳池'],['Isıtmalı kapalı havuz','Heated indoor pool','Beheizter Innenpool','Крытый бассейн с подогревом','Piscine intérieure chauffée','室内温水泳池'],['Spa ve hamam','Spa and hammam','Spa und Hamam','Спа и хаммам','Spa et hammam','水疗与土耳其浴'],['Alakart restoran','À la carte restaurant','À-la-carte-Restaurant','Ресторан à la carte','Restaurant à la carte','单点餐厅'],['Çocuk kulübü','Kids club','Kinderclub','Детский клуб','Club enfants','儿童俱乐部'],['Fitness merkezi','Fitness centre','Fitnesscenter','Фитнес-центр','Salle de sport','健身中心'],['Vale otopark','Valet parking','Parkservice','Парковка с обслуживанием','Service de voiturier','代客泊车'],['Otel Olanakları','Hotel amenities','Hotelausstattung','Удобства отеля','Équipements de l’hôtel','酒店设施'],['Yeme & İçme','Food & drink','Essen & Trinken','Еда и напитки','Restauration','餐饮'],['Spor & Eğlence','Sports & entertainment','Sport & Unterhaltung','Спорт и развлечения','Sports et loisirs','运动与娱乐'],['Çocuk & Bebek','Children & babies','Kinder & Babys','Дети и младенцы','Enfants et bébés','儿童与婴儿'],['Balayı','Honeymoon','Flitterwochen','Медовый месяц','Lune de miel','蜜月'],['Konaklama sözleşmesi ve iptal koşulları','Stay agreement and cancellation terms','Aufenthaltsvertrag und Stornobedingungen','Договор проживания и условия отмены','Contrat de séjour et conditions d’annulation','住宿协议及取消条款']
  );
  rows.push(
    ['Yat kiralama hakkında','About the yacht','Über die Yacht','О яхте','À propos du yacht','游艇介绍'],['Tur hakkında','About the tour','Über die Tour','О туре','À propos du circuit','旅游介绍'],['Aktivite hakkında','About the activity','Über die Aktivität','Об активности','À propos de l’activité','活动介绍'],
    ['Teknik özellikler','Technical specifications','Technische Daten','Технические характеристики','Caractéristiques techniques','技术参数'],['Yat tipi, kapasite ve charter koşulları.','Yacht type, capacity and charter terms.','Yachttyp, Kapazität und Charterbedingungen.','Тип яхты, вместимость и условия аренды.','Type de yacht, capacité et conditions de location.','游艇类型、容量与包船条件。'],
    ['Yat tipi','Yacht type','Yachttyp','Тип яхты','Type de yacht','游艇类型'],['Liman','Port','Hafen','Порт','Port','港口'],['Boy','Length','Länge','Длина','Longueur','长度'],['Kabin','Cabins','Kabinen','Каюты','Cabines','客舱'],['Misafir kapasitesi','Guest capacity','Gästekapazität','Вместимость','Capacité','载客量'],['Kaptan','Captain','Kapitän','Капитан','Capitaine','船长'],['Yakıt politikası','Fuel policy','Kraftstoffregelung','Топливная политика','Politique de carburant','燃油政策'],
    ['Biniş ve iniş bilgileri','Embarkation and disembarkation','Ein- und Ausschiffung','Посадка и высадка','Embarquement et débarquement','登船与下船'],['Biniş limanı','Embarkation port','Einschiffungshafen','Порт посадки','Port d’embarquement','登船港口'],['Biniş / iniş saati','Embarkation / disembarkation time','Ein- / Ausschiffungszeit','Время посадки / высадки','Heure d’embarquement / débarquement','登船 / 下船时间'],
    ['Tur bilgileri','Tour information','Tourinformationen','Информация о туре','Informations sur le circuit','旅游信息'],['Aktivite bilgileri','Activity information','Aktivitätsinformationen','Информация об активности','Informations sur l’activité','活动信息'],['Süre','Duration','Dauer','Продолжительность','Durée','时长'],['Grup kapasitesi','Group capacity','Gruppengröße','Размер группы','Taille du groupe','团队人数'],['Rehberlik dilleri','Guide languages','Sprachen der Reiseleitung','Языки гида','Langues du guide','导游语言'],['Zorluk','Difficulty','Schwierigkeit','Сложность','Difficulté','难度'],['Yaş sınırı','Age restriction','Altersgrenze','Возрастное ограничение','Limite d’âge','年龄限制'],
    ['Tur programı','Tour itinerary','Reiseprogramm','Программа тура','Programme du circuit','旅游行程'],['Gün gün gezi akışı ve önemli duraklar.','Daily itinerary and key stops.','Tagesprogramm und wichtige Stationen.','Ежедневная программа и основные остановки.','Programme quotidien et étapes principales.','每日行程与主要停靠点。'],['Kalkış ve dönüş','Departure and return','Abfahrt und Rückkehr','Отправление и возвращение','Départ et retour','出发与返回'],['Buluşma noktası ve transfer','Meeting point and transfer','Treffpunkt und Transfer','Место встречи и трансфер','Point de rencontre et transfert','集合地点与接送'],['Buluşma noktası','Meeting point','Treffpunkt','Место встречи','Point de rencontre','集合地点'],['Dönüş noktası','Return point','Rückkehrort','Место возвращения','Point de retour','返回地点'],['Tur kuralları','Tour rules','Tourregeln','Правила тура','Règles du circuit','旅游规则'],['Aktivite kuralları','Activity rules','Aktivitätsregeln','Правила активности','Règles de l’activité','活动规则'],['İptal ve iade','Cancellation and refunds','Stornierung und Erstattung','Отмена и возврат','Annulation et remboursement','取消与退款'],['kişi','person','Person','человек','personne','人'],['Kolay','Easy','Einfach','Легко','Facile','简单']
  );
  rows.push(
    ['Rezervasyon öncesi merak ettikleriniz.','Questions before booking.','Fragen vor der Buchung.','Вопросы перед бронированием.','Questions avant de réserver.','预订前常见问题。'],
    ['Paket kapsamını rezervasyon öncesinde inceleyin.','Check the package inclusions before booking.','Prüfen Sie den Paketumfang vor der Buchung.','Уточните состав пакета до бронирования.','Vérifiez les prestations avant de réserver.','预订前查看套餐内容。'],
    ['Liman ve saat bilgilerini seyahat öncesinde teyit edin.','Confirm ports and times before travelling.','Bestätigen Sie Häfen und Zeiten vor der Reise.','Уточните порты и время до поездки.','Confirmez les ports et horaires avant le voyage.','出行前确认港口及时间。'],
    ['Süre, kapasite ve katılım bilgileri.','Duration, capacity and participation details.','Dauer, Kapazität und Teilnahmeinformationen.','Продолжительность, вместимость и участие.','Durée, capacité et participation.','时长、容量及参与信息。'],
    ['Buluşma ve ulaşım detayları.','Meeting and transport details.','Treffpunkt und Transportdetails.','Место встречи и транспорт.','Rendez-vous et transport.','集合与交通详情。'],
    ['Katılım öncesi bilmeniz gereken koşullar.','Conditions to know before participating.','Bedingungen vor der Teilnahme.','Условия участия.','Conditions à connaître avant de participer.','参加前须知。'],
    ['Rezervasyonun iptal ve iade koşulları.','Booking cancellation and refund terms.','Storno- und Erstattungsbedingungen.','Условия отмены и возврата.','Conditions d’annulation et de remboursement.','预订取消及退款条件。']
  );
  rows.push(
    ['Tüm fotoğrafları göster','Show all photos','Alle Fotos ansehen','Все фотографии','Voir toutes les photos','查看所有照片'],
    ['Sıcak su havuzu','Heated pool','Beheizter Pool','Бассейн с подогревом','Piscine chauffée','温水泳池'],
    ['Çocuk havuzu','Children’s pool','Kinderpool','Детский бассейн','Piscine pour enfants','儿童泳池'],
    ['Muhafazakar / korunaklı havuz','Secluded pool','Abgeschirmter Pool','Уединённый бассейн','Piscine à l’abri des regards','私密泳池'],
    ['Muhafazakar olmayan havuz','Non-secluded pool','Nicht abgeschirmter Pool','Неуединённый бассейн','Piscine non isolée','非私密泳池'],
    ['Muhafazakarlık durumu belirtilmemiş','Privacy not specified','Privatsphäre nicht angegeben','Приватность не указана','Intimité non précisée','未说明私密性'],
    ['Ölçü bilgisi eklenmemiş','Dimensions not provided','Maße nicht angegeben','Размеры не указаны','Dimensions non précisées','未提供尺寸'],
    ['Günlük ısıtma ücreti belirtilmemiş','Daily heating fee not specified','Tägliche Heizgebühr nicht angegeben','Стоимость подогрева не указана','Frais de chauffage non précisés','未说明每日加热费'],
    ['Hasar depozitosu, tatil evine girişte nakit olarak ödenir.','The damage deposit is paid in cash on arrival.','Die Kaution wird bei Anreise bar bezahlt.','Залог оплачивается наличными при заезде.','Le dépôt de garantie est payé en espèces à l’arrivée.','损坏押金在入住时以现金支付。'],
    ['Yakın tarihlerde uygun kapasite görünmüyor. Tarih seçerek müsaitliği teyit edin.','No availability is shown for nearby dates. Select dates to confirm.','Für nahe Termine wird keine Verfügbarkeit angezeigt. Wählen Sie Daten zur Bestätigung.','На ближайшие даты нет доступных мест. Выберите даты для уточнения.','Aucune disponibilité affichée prochainement. Sélectionnez des dates pour confirmer.','近期未显示可订房源，请选择日期确认。'],
    ['Demo önizleme • Fiyatlar, hizmetler ve içerikler örnektir.','Demo preview • Prices, services and content are examples.','Demovorschau • Preise, Leistungen und Inhalte sind Beispiele.','Демо • Цены, услуги и материалы приведены для примера.','Aperçu démo • Prix, services et contenus sont des exemples.','演示预览 • 价格、服务与内容仅为示例。'],
    ['12 TAKSİT','12 INSTALMENTS','12 RATEN','12 ПЛАТЕЖЕЙ','12 MENSUALITÉS','12期分期'],
    ['Tüm kredi kartlarına 12 taksit','12 instalments with all credit cards','12 Raten mit allen Kreditkarten','12 платежей по всем кредитным картам','12 mensualités avec toutes les cartes','所有信用卡可分12期'],
    ['Vade farksız 12 taksit ile tatilinizi şimdi planlayın.','Plan your holiday with 12 interest-free instalments.','Planen Sie Ihren Urlaub mit 12 zinsfreien Raten.','Планируйте отпуск с 12 беспроцентными платежами.','Planifiez vos vacances en 12 mensualités sans frais.','以12期免息分期规划假期。'],
    ['Erken rezervasyona özel indirim','Early booking discount','Frühbucherrabatt','Скидка за раннее бронирование','Réduction réservation anticipée','早鸟预订优惠'],
    ['Seçili tarihlerde konaklamanıza özel fırsatlar.','Special offers for selected dates.','Sonderangebote für ausgewählte Termine.','Предложения на выбранные даты.','Offres pour certaines dates.','指定日期住宿优惠。'],
    ['UZUN KONAKLAMA','LONG STAY','LANGZEITAUFENTHALT','ДЛИТЕЛЬНОЕ ПРОЖИВАНИЕ','LONG SÉJOUR','长住优惠'],
    ['Uzun konaklamaya özel avantaj','Long-stay benefits','Vorteile für längere Aufenthalte','Преимущества длительного проживания','Avantages des longs séjours','长住专属福利'],
    ['7 gece ve üzeri konaklamalarda özel ayrıcalıklar.','Special benefits for stays of 7 nights or more.','Vorteile ab 7 Übernachtungen.','Преимущества при проживании от 7 ночей.','Avantages pour les séjours de 7 nuits ou plus.','入住7晚及以上享专属福利。'],
    ['Yetişkin','Adult','Erwachsener','Взрослый','Adulte','成人'],['Çocuk','Child','Kind','Ребёнок','Enfant','儿童'],['Bebek','Infant','Baby','Младенец','Bébé','婴儿'],
    ['13 yaş ve üzeri','Ages 13 and above','Ab 13 Jahren','От 13 лет','13 ans et plus','13岁及以上'],['2–12 yaş','Ages 2–12','2–12 Jahre','2–12 лет','2–12 ans','2至12岁'],['0–2 yaş','Ages 0–2','0–2 Jahre','0–2 года','0–2 ans','0至2岁'],
    ['Tahmini tutar; kesin fiyat sonraki adımda teyit edilir.','Estimated amount; the final price is confirmed in the next step.','Geschätzter Betrag; der Endpreis wird im nächsten Schritt bestätigt.','Предварительная сумма; окончательная цена уточняется далее.','Montant estimé ; le prix final sera confirmé à l’étape suivante.','预计金额，最终价格将在下一步确认。'],
    ['Belirtilen uzaklıklar kuş uçuşudur; yol mesafesi farklı olabilir. Mekan verileri OpenStreetMap kaynaklıdır.','Distances are straight-line estimates; road distances may differ. Place data comes from OpenStreetMap.','Entfernungen sind Luftlinien; Straßenwege können abweichen. Ortsdaten stammen von OpenStreetMap.','Расстояния указаны по прямой; по дороге они могут отличаться. Данные OpenStreetMap.','Distances à vol d’oiseau ; les trajets peuvent différer. Données OpenStreetMap.','距离为直线估算，实际路程可能不同。地点数据来自OpenStreetMap。'],
    ['Yarım gün','Half day','Halber Tag','Полдня','Demi-journée','半天'],['Tam gün','Full day','Ganzer Tag','Полный день','Journée entière','全天'],['Akşam','Evening','Abend','Вечер','Soirée','傍晚'],
    ['Kültür & Tarih','Culture & history','Kultur & Geschichte','Культура и история','Culture et histoire','文化与历史'],['Deniz & Doğa','Sea & nature','Meer & Natur','Море и природа','Mer et nature','海洋与自然'],['Yerel Yaşam','Local life','Lokales Leben','Местная жизнь','Vie locale','当地生活'],
    ['Sağlayıcı bilgileri demo amaçlıdır.','Provider information is for demo purposes.','Anbieterinformationen dienen der Demo.','Информация поставщика для демонстрации.','Informations du prestataire pour la démo.','供应商信息仅用于演示。'],
    ['Yanıt süresi: bir saat içinde','Response time: within an hour','Antwortzeit: innerhalb einer Stunde','Ответ: в течение часа','Réponse : sous une heure','回复时间：一小时内'],
    ['Geniş odalar ve sakin bir koy. Aile tatili için keyifli bir deneyim.','Spacious rooms and a peaceful bay. A lovely family holiday.','Geräumige Zimmer und eine ruhige Bucht. Ein schöner Familienurlaub.','Просторные комнаты и тихая бухта. Прекрасный семейный отдых.','Chambres spacieuses et baie paisible. Un agréable séjour en famille.','宽敞的房间和宁静的海湾，适合家庭度假。'],
    ['Plaj ve restoran hizmetinden memnun kaldık.','We enjoyed the beach and restaurant service.','Wir waren mit Strand und Restaurantservice zufrieden.','Нам понравились пляж и ресторан.','Nous avons apprécié la plage et le service du restaurant.','我们对海滩和餐厅服务很满意。'],
    ['Oda temizliği ve personelin ilgisi çok iyiydi.','Room cleanliness and staff service were excellent.','Sauberkeit und Service waren ausgezeichnet.','Чистота и внимание персонала были отличными.','La propreté et l’attention du personnel étaient excellentes.','房间清洁和员工服务非常好。']
  );
  const dictionary = new Map(rows.map(row => [row[0],row]));
  const sources = new WeakMap();
  const attrSources = new WeakMap();
  const lang = () => (window.NEXUS_LOCALE?.lang || document.documentElement.lang || 'tr').split('-')[0];
  function translate(source) {
    const index = languages.indexOf(lang());
    if (index <= 0) return source;
    const custom=editorialData?.metadata?.extra_metadata?.translations?.[lang()]?.texts?.[source];
    if(typeof custom==='string' && custom.trim())return custom;
    if (dictionary.has(source)) return dictionary.get(source)[index];
    if(/^\d+ (kişi|misafir) · \d+ kabin · \d+ banyo$/.test(source))return source.split(' · ').map(part=>translate(part)).join(' · ');
    const yachtFact=source.match(/^(\d+) (kişi|kabin)$/);
    if(yachtFact)return yachtFact[1]+' '+(yachtFact[2]==='kişi'?dictionary.get('kişi')[index]:['','cabins','Kabinen','кают','cabines','间客舱'][index]);
    const priceNights=source.match(/^(.*?) × (\d+) gece$/);
    if(priceNights)return priceNights[1]+' × '+priceNights[2]+' '+dictionary.get('gece')[index];
    const cancellation=source.match(/^Giriş tarihinden (\d+) gün öncesine kadar %100 kesintisiz iade hakkı\.$/);
    if(cancellation)return ['',`Full refund until ${cancellation[1]} days before arrival.`,`Volle Erstattung bis ${cancellation[1]} Tage vor Anreise.`,`Полный возврат до ${cancellation[1]} дней перед заездом.`,`Remboursement intégral jusqu’à ${cancellation[1]} jours avant l’arrivée.`,`入住前${cancellation[1]}天可全额退款。`][index];
    const shortStay=source.match(/^(\d+) geceden kısa konaklamalarda ek ücret uygulanır\.$/);
    if(shortStay)return ['',`An additional fee applies to stays shorter than ${shortStay[1]} nights.`,`Bei Aufenthalten unter ${shortStay[1]} Nächten fällt eine Zusatzgebühr an.`,`При проживании менее ${shortStay[1]} ночей взимается дополнительная плата.`,`Un supplément s’applique aux séjours de moins de ${shortStay[1]} nuits.`,`少于${shortStay[1]}晚的住宿需支付额外费用。`][index];
    const prefixes=[
      ['T.C. Kültür ve Turizm Bakanlığı Belge No : ','Ministry of Culture and Tourism Certificate No: ','Zertifikatnummer des Kultur- und Tourismusministeriums: ','Номер документа Министерства культуры и туризма: ','N° de certificat du ministère de la Culture et du Tourisme : ','文化和旅游部证书编号：'],
      ['Ölçüler (en × boy × derinlik): ','Dimensions (width × length × depth): ','Maße (Breite × Länge × Tiefe): ','Размеры (ширина × длина × глубина): ','Dimensions (largeur × longueur × profondeur) : ','尺寸（宽 × 长 × 深）：'],
      ['Günlük ısıtma ücreti: ','Daily heating fee: ','Tägliche Heizgebühr: ','Стоимость подогрева в день: ','Chauffage par jour : ','每日加热费：'],
      ['Yanıt oranı: %','Response rate: %','Antwortrate: %','Доля ответов: %','Taux de réponse : %','回复率：%']
    ];
    for(const row of prefixes) if(source.startsWith(row[0])) return row[index]+source.slice(row[0].length);
    const months=['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
    const dated=source.match(/^(\d+(?:[––-]\d+)?\s+)?(Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık) (\d{4})$/);
    if(dated) return (dated[1]||'')+new Intl.DateTimeFormat(lang(),{month:'long'}).format(new Date(Number(dated[3]),months.indexOf(dated[2]),1))+' '+dated[3];
    const discount=source.match(/^%(\d+) İNDİRİM$/);
    if(discount) return discount[1]+'% '+['','OFF','RABATT','СКИДКА','DE RÉDUCTION','折扣'][index];
    const count = source.match(/^(Yorumlar|Devamını göster)\s*\(([^)]+)\)$/);
    if (count) return (count[1] === 'Yorumlar' ? dictionary.get('Yorumlar')[index] : ['','Show more','Mehr anzeigen','Показать ещё','Voir plus','查看更多'][index]) + ' (' + count[2].replace('özellik',['','amenities','Ausstattungen','удобств','équipements','项设施'][index]) + ')';
    const minimum = source.match(/^Minimum konaklama: (\d+) gece$/);
    if(minimum) return ['','Minimum stay','Mindestaufenthalt','Минимальное проживание','Séjour minimum','最少入住'][index] + ': ' + minimum[1] + ' ' + dictionary.get('gece')[index];
    if(source.startsWith('Ön ödeme: %')) return ['','Advance payment','Anzahlung','Предоплата','Acompte','预付款'][index] + ': ' + source.slice(10);
    const advance=source.match(/^Rezervasyon sırasında toplam tutarın %(\d+(?:\.\d+)?) oranı ön ödeme olarak alınır\.$/);
    if(advance) return ['',`An advance payment of ${advance[1]}% of the total is collected at booking.`,`Bei der Buchung wird eine Anzahlung von ${advance[1]}% des Gesamtbetrags erhoben.`,`При бронировании взимается предоплата в размере ${advance[1]}% от общей суммы.`,`Un acompte de ${advance[1]}% du montant total est demandé à la réservation.`,`预订时收取总金额的${advance[1]}%作为预付款。`][index];
    const dynamic = source.match(/^(\d+) (misafir|oda|banyo)$/);
    if (dynamic) return dynamic[1] + ' ' + dictionary.get(dynamic[2])[index];
    if (source === '/ kişi') return '/ ' + dictionary.get('kişi')[index];
    if (source === '/ gece') return '/ ' + dictionary.get('gece')[index];
    const key = window.NEXUS_SOURCE_KEY?.(source);
    if (key && key !== source) { const translated = window.NEXUS_T?.(key); if (translated && translated !== key) return translated; if (lang() === 'en') return key; }
    return source;
  }
  let editorialData;
  function apply() {
    try {editorialData=JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(document.querySelector('main.product-detail')?.dataset.listingDetail || ''),c=>c.charCodeAt(0))));}catch(_){editorialData=null;}
    const roots = document.querySelectorAll('main.product-detail, .reference-amenity-modal, .review-host-dialog, .reservation-summary-dialog');
    roots.forEach(root => {
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      let node;
      while ((node = walker.nextNode())) {
        if (node.parentElement.closest('script,style,h1,.prose')) continue;
        const current = node.textContent.trim(); if (!current) continue;
        let saved = sources.get(node);
        if (!saved || (node.textContent !== saved.rendered && node.textContent !== saved.source)) saved = {source:node.textContent};
        const next = saved.source.replace(saved.source.trim(),translate(saved.source.trim()));
        saved.rendered = next; sources.set(node,saved); if (node.textContent !== next) node.textContent = next;
      }
      root.querySelectorAll('[placeholder],[aria-label],[title]').forEach(element => {
        let saved = attrSources.get(element); if (!saved) { saved = {}; attrSources.set(element,saved); }
        ['placeholder','aria-label','title'].forEach(attr => { if(!element.hasAttribute(attr)) return; const value = element.getAttribute(attr); if(!saved[attr]) saved[attr]=value; const next=translate(saved[attr]); if(value!==next) element.setAttribute(attr,next); });
      });
    });
    let data; try {data=JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(document.querySelector('main.product-detail')?.dataset.listingDetail || ''),c=>c.charCodeAt(0))));} catch(_) {return;}
    const translation=data.metadata?.extra_metadata?.translations?.[lang()];
    const title=document.querySelector('main.product-detail h1');
    if(title) { if(!title.dataset.detailSourceTitle) title.dataset.detailSourceTitle=title.textContent; const value=translation?.title || title.dataset.detailSourceTitle; if(title.textContent!==value) title.textContent=value; }
    // Only publisher-provided translations replace listing descriptions.
    const description=document.querySelector('.detail-main section .prose, .detail-main .reference-about-content');
    if(description){
      if(!description.dataset.detailSourceDescription) description.dataset.detailSourceDescription=description.textContent;
      const value=translation?.description || translate(description.dataset.detailSourceDescription);
      if(description.textContent!==value) description.textContent=value;
    }
  }
  let pending=false;
  function schedule(){if(pending)return;pending=true;requestAnimationFrame(()=>{pending=false;apply();});}
  document.addEventListener('nexus:lang',schedule);
  new MutationObserver(schedule).observe(document.body,{childList:true,subtree:true});
  schedule();
  window.NEXUS_DETAIL_T = translate;
})();
