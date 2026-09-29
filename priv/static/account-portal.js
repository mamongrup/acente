(function () {
  'use strict';
  function e(v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function icon(name) { return '<i class="hgi-stroke hgi-' + name + '" aria-hidden="true"></i>'; }
  function arr(v) { return Array.isArray(v) ? v : []; }
  function empty(title, detail) { return '<div class="acct-portal-empty"><strong>' + title + '</strong><p>' + detail + '</p></div>'; }
  function head(kicker, title, text) { return '<div class="acct-section-heading"><div><span>' + kicker + '</span><h2>' + title + '</h2><p>' + text + '</p></div></div>'; }
  function form(resource, body, button) { return '<form class="acct-portal-form" data-resource="' + resource + '"><div class="acct-form-grid">' + body + '</div><div class="acct-form-foot"><span class="acct-form-message" role="status"></span><button class="acct-action" type="submit">' + button + ' ' + icon('arrow-right-02') + '</button></div></form>'; }
  function field(label, name, type, attrs) { return '<label><span>' + label + '</span><input name="' + name + '" type="' + type + '" ' + (attrs || '') + '></label>'; }
  function select(label, name, options) { return '<label><span>' + label + '</span><select name="' + name + '">' + options.map(function (x) { return '<option value="' + e(x[0]) + '">' + e(x[1]) + '</option>'; }).join('') + '</select></label>'; }
  function textarea(label, name, placeholder) { return '<label class="acct-full"><span>' + label + '</span><textarea name="' + name + '" rows="3" placeholder="' + e(placeholder || '') + '" required></textarea></label>'; }
  function del(resource, id) { return '<button class="acct-delete" type="button" data-delete="' + resource + '" data-id="' + e(id) + '" aria-label="Kaydı sil">' + icon('delete-02') + '</button>'; }
  function row(title, detail, right) { return '<div class="acct-portal-row"><div><strong>' + title + '</strong><small>' + detail + '</small></div>' + (right || '') + '</div>'; }
  function pane(tab, content) { return '<section class="acct-pane" data-pane="' + tab + '" hidden>' + content + '</section>'; }
  function tab(name, label, iconName, count) { return '<button type="button" data-tab="' + name + '">' + icon(iconName) + ' ' + label + (count == null ? '' : ' <em>' + count + '</em>') + '</button>'; }
  function money(minor, currency) { return new Intl.NumberFormat('tr-TR', { style: 'currency', currency: currency || 'TRY' }).format(Number(minor || 0) / 100); }
  window.renderCustomerPortal = function (root, portal, account, recommendations) {
    var travelers = arr(portal.travelers), docs = arr(portal.documents), billing = arr(portal.billing), requests = arr(portal.requests), notes = arr(portal.notifications), alerts = arr(portal.alerts), tickets = arr(portal.tickets), bookings = arr(account.reservations), reservationMessages = arr(portal.reservationMessages), trips = arr(portal.tripTimeline), prefs = portal.preferences || {};
    var chatSuggestions = arr((recommendations || {}).chat), sentSuggestions = arr((recommendations || {}).sent), journey = arr((recommendations || {}).journey);
    var intent = (recommendations || {}).intent || {};
    root.querySelector('.acct-nav-divider').insertAdjacentHTML('beforebegin',
      '<div class="acct-nav-title acct-nav-subtitle">Seyahat ve hesap</div>' +
      tab('travelers', 'Yolcu profilleri', 'user-multiple', travelers.length) +
      tab('documents', 'Seyahat dosyası', 'folder-01', docs.length) +
      tab('trip-timeline', 'Seyahat akışım', 'calendar-03', trips.length) +
      tab('billing', 'Fatura bilgileri', 'invoice-01', billing.length) +
      tab('requests', 'Rezervasyon işlemleri', 'calendar-03', requests.length) +
      tab('reservation-messages', 'Rezervasyon mesajları', 'message-01', reservationMessages.reduce(function (n, item) { return n + arr(item.messages).length; }, 0)) +
      tab('notifications', 'Bildirimler', 'notification-01', notes.filter(function (n) { return !n.read; }).length) +
      tab('alerts', 'Fiyat takibi', 'chart-decrease', alerts.length) +
      tab('recommendations', 'Size özel öneriler', 'sparkles', chatSuggestions.length + sentSuggestions.length + journey.length) +
      tab('support', 'Destek geçmişi', 'customer-support', tickets.length));

    var travelerForm = form('travelers', field('Ad soyad', 'full_name', 'text', 'maxlength="120" required placeholder="Yolcunun adı ve soyadı"') + field('Doğum tarihi', 'birth_date', 'date', '') + field('Uyruk (ülke kodu)', 'nationality', 'text', 'maxlength="2" value="TR" required placeholder="TR"'), 'Yolcu ekle');
    var travelerList = travelers.length ? travelers.map(function (t) { return row(e(t.name), (t.birthDate ? e(t.birthDate) + ' · ' : '') + e(t.nationality), del('travelers', t.id)); }).join('') : empty('Henüz yolcu profili yok', 'Birlikte seyahat ettiğiniz kişileri buraya ekleyebilirsiniz.');
    var documentForm = form('documents', select('Belge türü', 'kind', [['ticket', 'Bilet'], ['voucher', 'Voucher'], ['insurance', 'Sigorta'], ['other', 'Diğer']]) + field('Belge adı', 'title', 'text', 'maxlength="160" required placeholder="Örn. İstanbul uçuş bileti"') + field('Güvenli belge bağlantısı', 'url', 'url', 'class="acct-full" maxlength="2000" pattern="https://.*" required placeholder="https://…"'), 'Bağlantı ekle');
    var documentList = docs.length ? docs.map(function (d) { return row('<a href="' + e(d.url) + '" target="_blank" rel="noopener noreferrer">' + e(d.title) + ' ' + icon('arrow-up-right-01') + '</a>', e(({ ticket: 'Bilet', voucher: 'Voucher', insurance: 'Sigorta', other: 'Belge' })[d.kind] || 'Belge') + ' · ' + e(d.createdAt), del('documents', d.id)); }).join('') : empty('Seyahat dosyanız boş', 'Bilet, voucher ve sigorta bağlantılarınızı ekleyebilirsiniz.');
    var billingForm = form('billing', field('Kayıt adı', 'label', 'text', 'maxlength="80" required placeholder="Örn. Kişisel"') + field('Ad soyad / unvan', 'legal_name', 'text', 'maxlength="160" required') + field('Vergi / kimlik numarası', 'tax_number', 'text', 'maxlength="32"') + field('Vergi dairesi', 'tax_office', 'text', 'maxlength="120"') + field('Ülke kodu', 'country_code', 'text', 'maxlength="2" value="TR" required') + '<label class="acct-full"><span>Fatura adresi</span><textarea name="address" rows="3" maxlength="500" required></textarea></label>', 'Fatura bilgisi kaydet');
    var billingList = billing.length ? billing.map(function (b) { return row(e(b.label) + ' · ' + e(b.legalName), e(b.address) + (b.taxNumber ? ' · VKN/TCKN: ' + e(b.taxNumber) : ''), del('billing', b.id)); }).join('') : empty('Kayıtlı fatura bilgisi yok', 'Bireysel veya kurumsal fatura bilgilerinizi ekleyebilirsiniz.');
    var requestOptions = bookings.filter(function (b) { return b.id && b.status !== 'cancelled' && b.status !== 'completed'; }).map(function (b) { return [b.id, b.reference + ' · ' + b.title]; });
    var requestForm = requestOptions.length ? form('requests', select('Rezervasyon', 'reservation_id', requestOptions) + select('Talep türü', 'kind', [['change', 'Tarih / bilgi değişikliği'], ['cancel', 'İptal talebi'], ['refund', 'İade talebi']]) + textarea('Talebiniz', 'message', 'Ne yapılmasını istediğinizi açıklayın (en az 10 karakter).'), 'Talep gönder') : '<div class="acct-security-note">' + icon('information-circle') + '<span>İşlem talebi açmak için aktif bir rezervasyonunuz olmalı.</span></div>';
    var requestList = requests.length ? requests.map(function (r) { return row(e(r.reference) + ' · ' + e(({ change: 'Değişiklik', cancel: 'İptal', refund: 'İade' })[r.kind] || r.kind), e(r.message) + ' · ' + e(r.status) + ' · ' + e(r.createdAt), ''); }).join('') : empty('Henüz işlem talebiniz yok', 'Rezervasyon değişikliği, iptal veya iade isteğiniz burada izlenir.');
    var reservationMessageList = reservationMessages.length ? reservationMessages.map(function (item) { return '<details class="acct-ticket"><summary><strong>' + e(item.reference) + ' · ' + e(item.listing) + '</strong><span>' + arr(item.messages).length + ' mesaj</span></summary><div class="acct-ticket-messages">' + arr(item.messages).map(function (m) { return '<div class="acct-ticket-message"><small>' + e(m.author === 'customer' ? 'Siz' : m.author === 'supplier' ? 'Tedarikçi' : 'Acente') + ' · ' + e(m.createdAt) + '</small><p>' + e(m.message) + '</p></div>'; }).join('') + form('reservation-messages', '<input type="hidden" name="reservation_id" value="' + e(item.id) + '">' + textarea('Mesaj yazın', 'message', 'Rezervasyonunuzla ilgili sorunuzu yazın'), 'Mesaj gönder') + '</div></details>'; }).join('') : empty('Rezervasyon görüşmesi yok', 'Rezervasyonunuz oluştuğunda tedarikçi ve acente ile burada yazışabilirsiniz.');
    var orderedTrips = trips.slice().sort(function (a, b) { return (a.startsOn || '9999').localeCompare(b.startsOn || '9999'); });
    var tripList = orderedTrips.length ? orderedTrips.map(function (trip) {
      var steps = arr(trip.steps), next = steps.find(function (step) { return step.status === 'open'; });
      var progress = steps.length ? steps.filter(function (step) { return step.status === 'done' || step.status === 'waived'; }).length + '/' + steps.length + ' adım' : 'Hazırlık bekleniyor';
      var dates = trip.startsOn ? e(trip.startsOn) + (trip.endsOn && trip.endsOn !== trip.startsOn ? ' – ' + e(trip.endsOn) : '') : 'Tarih bekleniyor';
      return '<details class="acct-ticket"><summary><strong>' + e(trip.listing) + ' · ' + e(trip.reference) + '</strong><span>' + dates + ' · ' + e(progress) + '</span></summary><div class="acct-ticket-messages"><p class="acct-form-note">' + (next ? 'Sıradaki adım: ' + e(next.title) : steps.length ? 'Kayıtlı hizmet adımları tamamlandı.' : 'Hizmet adımları acente tarafından hazırlanıyor.') + '</p>' + steps.map(function (step) { return row(e(step.title), e(({before:'Yolculuk öncesi',during:'Yolculuk sırasında',after:'Yolculuk sonrası'})[step.stage] || step.stage) + ' · ' + e(step.status === 'done' ? 'Tamamlandı' : step.status === 'waived' ? 'Gerekli değil' : 'Hazırlanıyor'), ''); }).join('') + '</div></details>';
    }).join('') : empty('Henüz seyahat akışı yok', 'Onaylanan rezervasyonlarınızın hazırlık ve hizmet adımları burada görünür.');
    var preferencesForm = form('preferences', '<label class="acct-check"><input type="checkbox" name="booking_email" ' + (prefs.bookingEmail !== false ? 'checked' : '') + '><span>Rezervasyon ve ödeme e-postaları</span></label><label class="acct-check"><input type="checkbox" name="price_email" ' + (prefs.priceEmail !== false ? 'checked' : '') + '><span>Fiyat düşüşü e-postaları</span></label><label class="acct-check"><input type="checkbox" name="marketing_email" ' + (prefs.marketingEmail ? 'checked' : '') + '><span>Kampanya ve kişisel öneri e-postaları</span></label><label class="acct-check"><input type="checkbox" name="marketing_whatsapp" ' + (prefs.marketingWhatsapp ? 'checked' : '') + '><span>WhatsApp ile kişisel öneriler</span></label>', 'Tercihleri kaydet');
    var notificationList = notes.length ? notes.map(function (n) { return '<div class="acct-portal-row' + (n.read ? '' : ' acct-unread') + '"><div><strong>' + e(n.title) + '</strong><small>' + e(n.message) + ' · ' + e(n.createdAt) + '</small></div>' + (n.read ? '' : '<button class="acct-mark-read" data-note="' + e(n.id) + '" type="button">Okundu</button>') + '</div>'; }).join('') : empty('Henüz bildirim yok', 'Hesabınızla ilgili bildirimler burada görünecek.');
    var alertForm = form('alerts', field('İlan bağlantısı veya kimliği', 'listing_id', 'text', 'required placeholder="/urunler/…"') + field('Hedef fiyat (ilan para biriminde)', 'target_price', 'number', 'min="0.01" step="0.01" required placeholder="Örn. 2500"'), 'Fiyat alarmı kur');
    var alertList = alerts.length ? alerts.map(function (a) { return row('<a href="/urunler/' + e(a.listingId) + '">' + e(a.title) + '</a>', 'Hedef ' + money(a.target, a.currency) + ' · Güncel ' + money(a.current, a.currency), del('alerts', a.id)); }).join('') : empty('Aktif fiyat alarmı yok', 'İlgilendiğiniz ilanın bağlantısını ve hedef fiyatı ekleyin.');
    var supportForm = form('tickets', field('Konu', 'subject', 'text', 'maxlength="160" required placeholder="Örn. Rezervasyon desteği"') + textarea('Mesajınız', 'message', 'Size nasıl yardımcı olabiliriz?'), 'Destek talebi aç');
    var ticketList = tickets.length ? tickets.map(function (t) { return '<details class="acct-ticket"><summary><strong>' + e(t.subject) + '</strong><span>' + e(t.status === 'open' ? 'Açık' : t.status === 'responded' ? 'Yanıtlandı' : 'Kapalı') + ' · ' + e(t.createdAt) + '</span></summary><div class="acct-ticket-messages">' + arr(t.messages).map(function (m) { return '<div class="acct-ticket-message"><small>' + e(m.author === 'staff' ? 'Acente' : 'Siz') + ' · ' + e(m.createdAt) + '</small><p>' + e(m.message) + '</p></div>'; }).join('') + (t.status === 'closed' ? '' : form('ticket-replies', '<input type="hidden" name="ticket_id" value="' + e(t.id) + '">' + textarea('Yanıt yazın', 'message', 'Mesajınız'), 'Yanıt gönder')) + '</div></details>'; }).join('') : empty('Henüz destek görüşmesi yok', 'Açtığınız talepler ve yanıtlar burada saklanır.');
    function suggestion(item, detail) {
      var status = item.feedback === 'interested' ? ' · İlgileniyorum' : item.feedback === 'not_interested' ? ' · Bana uygun değil' : item.feedback === 'more_like' ? ' · Benzerlerini göster' : '';
      var availability = item.availability === 'available' ? ' · Seçilen tarihlerde müsait' : item.availability === 'unavailable' ? ' · Şu an müsait değil' : ' · Müsaitlik teyidi gerekli';
      var delivery = item.delivery === 'delivered' ? ' · Teslim edildi' : item.delivery === 'read' ? ' · Okundu' : item.delivery === 'accepted' ? ' · Gönderim kabul edildi' : '';
      var actions = '<div class="acct-recommendation-actions"><button type="button" data-recommendation-choice="interested" data-listing-id="' + e(item.listingId) + '">İlgileniyorum</button><button type="button" data-recommendation-choice="not_interested" data-listing-id="' + e(item.listingId) + '">Uygun değil</button><button type="button" data-recommendation-choice="more_like" data-listing-id="' + e(item.listingId) + '">Benzerleri</button><a href="/iletisim?listing_id=' + e(item.listingId) + '">Teklif iste</a></div>';
      return '<div class="acct-portal-row acct-recommendation-row"><div><strong><a href="/urunler/' + e(item.listingId) + '">' + e(item.title) + ' ' + icon('arrow-up-right-01') + '</a></strong><small>' + e(item.locality || item.category || '') + ' · Güncel fiyat ' + money(item.price, item.currency) + availability + ' · ' + e(detail) + delivery + ' · ' + e(item.date) + e(status) + '</small>' + actions + '</div></div>';
    }
    var chatSuggestionList = chatSuggestions.length ? chatSuggestions.map(function (item) { return suggestion(item, 'Sohbet isteğinize göre'); }).join('') : empty('Henüz sohbet önerisi yok', 'Seyahat asistanıyla giriş yapmış olarak konuştuğunuzda taleplerinizle eşleşen ilanlar burada görünür.');
    var sentSuggestionList = sentSuggestions.length ? sentSuggestions.map(function (item) { return suggestion(item, item.channel === 'whatsapp' ? 'WhatsApp önerisi' : 'E-posta önerisi'); }).join('') : empty('Gönderilmiş öneri yok', 'WhatsApp veya e-posta ile gönderilen kişisel öneriler burada listelenir.');
    var categoryPaths = {hotel:'otel',holiday_home:'tatil-evi',yacht:'yat',tour:'tur',activity:'aktivite',flight:'ucus',car:'arac',cruise:'kruvaziyer',pilgrimage:'hac-umre',visa:'vize',ferry:'feribot',transfer:'transfer',beach:'sezlong',cinema:'sinema',event:'etkinlik',restaurant:'restoran',bus:'otobus'};
    var journeyList = journey.length ? journey.map(function (item) {
      var active = item.answer || '', offer = item.offer || null, listing = item.suggestion || null;
      var buttons = [['yes','Evet, göster'],['no','Hayır'],['later','Daha sonra']].map(function (choice) { return '<button type="button" class="' + (active === choice[0] ? 'is-selected' : '') + '" data-journey-answer="' + choice[0] + '" data-reservation-id="' + e(item.reservationId) + '" data-target-category="' + e(item.targetCategory) + '">' + choice[1] + '</button>'; }).join('');
      var canRedeem = offer && listing && listing.currency === 'TRY' && listing.availability === 'available';
      var result = active === 'yes' ? '<div class="acct-journey-result">' + (listing ? '<strong><a href="/urunler/' + e(listing.id) + '">' + e(listing.title) + ' ' + icon('arrow-up-right-01') + '</a></strong><small>' + e(listing.locality) + ' · ' + money(listing.price, listing.currency) + ' · ' + (listing.availability === 'available' ? 'Seçilen tarihlerde müsait' : listing.availability === 'unavailable' ? 'Seçilen tarihlerde müsait değil' : 'Müsaitlik teyidi gerekli') + '</small>' + (canRedeem ? '<button type="button" data-journey-offer data-reservation-id="' + e(item.reservationId) + '" data-listing-id="' + e(listing.id) + '">İndirimi kullan</button>' : '') : '<span>Bu bölgede şu an eşleşen ilan bulunamadı. Diğer seçeneklere bakabilirsiniz.</span>') + '<a href="/' + e(categoryPaths[item.targetCategory] || 'otel') + '">Tüm seçenekleri gör</a></div>' : '';
      var teaser = canRedeem && active !== 'no' ? '<p class="acct-journey-offer">Bu yolculuk için ' + e(offer.name) + ': %' + e(offer.percent) + ' indirim fırsatı · ' + e(offer.endsOn) + ' tarihine kadar. Koşullar ve nihai fiyat rezervasyon öncesinde teyit edilir.</p>' : '';
      return '<article class="acct-journey-card"><small>' + e(item.sourceTitle) + ' · ' + e(item.reference) + (item.region ? ' · ' + e(item.region) : '') + '</small><h4>' + e(item.question) + '</h4>' + teaser + '<div class="acct-journey-choices">' + buttons + '</div>' + result + '</article>';
    }).join('') : empty('Yeni bir yolculuk planlayalım', 'Onaylanan uçuş, otobüs, konaklama ve diğer rezervasyonlarınızdan sonra tamamlayıcı seyahat seçeneklerini burada soracağız.');
    var intentForm = form('travel-intent', field('Bölge', 'region', 'text', 'maxlength="120" value="' + e(intent.region || '') + '" placeholder="Örn. Bodrum"') + select('Kategori', 'category', [['', 'Hepsi'], ['hotel', 'Otel'], ['holiday_home', 'Tatil Evi'], ['yacht', 'Yat'], ['tour', 'Tur'], ['activity', 'Aktivite'], ['flight', 'Uçuş'], ['car', 'Araç'], ['cruise', 'Kruvaziyer'], ['pilgrimage', 'Hac & Umre'], ['visa', 'Vize'], ['ferry', 'Feribot'], ['transfer', 'Transfer'], ['beach', 'Şezlong'], ['cinema', 'Sinema'], ['event', 'Etkinlik'], ['restaurant', 'Restoran'], ['bus', 'Otobüs']]) + field('Başlangıç tarihi', 'start_date', 'date', 'value="' + e(intent.startDate || '') + '"') + field('Bitiş tarihi', 'end_date', 'date', 'value="' + e(intent.endDate || '') + '"') + field('Kişi sayısı', 'guests', 'number', 'min="1" max="50" value="' + e(intent.guests || 2) + '" required') + field('Üst bütçe (₺)', 'budget', 'number', 'min="1" step="1" value="' + e(intent.budget ? Math.round(Number(intent.budget) / 100) : '') + '"'), 'Tercihleri uygula');
    root.querySelector('.acct-content').insertAdjacentHTML('beforeend',
      pane('travelers', head('YOLCULARIM', 'Yolcu profilleri', 'Sık seyahat ettiğiniz kişilerin temel bilgilerini yönetin.') + '<div class="acct-panel">' + travelerList + '</div><div class="acct-panel acct-portal-add"><h3>Yeni yolcu</h3>' + travelerForm + '</div>') +
      pane('documents', head('SEYAHAT DOSYAM', 'Belgelerim', 'Bilet, voucher ve sigorta bağlantılarını bir arada tutun.') + '<div class="acct-panel">' + documentList + '</div><div class="acct-panel acct-portal-add"><h3>Belge bağlantısı ekle</h3>' + documentForm + '<p class="acct-form-note">Şimdilik güvenli HTTPS bağlantıları saklanır; dosya yükleme açıldığında belgeler doğrudan bu alana bağlanabilir.</p></div>') +
      pane('trip-timeline', head('SEYAHAT AKIŞIM', 'Yolculuklarınız', 'Rezervasyonunuzun hazırlık, hizmet ve kapanış adımlarını takip edin.') + '<div class="acct-panel">' + tripList + '</div>') +
      pane('billing', head('FATURA PROFİLLERİM', 'Fatura bilgileri', 'Kişisel veya kurumsal bilgilerinizi kaydedin.') + '<div class="acct-panel">' + billingList + '</div><div class="acct-panel acct-portal-add"><h3>Yeni fatura profili</h3>' + billingForm + '</div>') +
      pane('requests', head('REZERVASYON YÖNETİMİ', 'İşlem talepleri', 'Değişiklik, iptal ve iade isteklerinizi takip edin.') + '<div class="acct-panel">' + requestList + '</div><div class="acct-panel acct-portal-add"><h3>Yeni işlem talebi</h3>' + requestForm + '</div>') +
      pane('reservation-messages', head('REZERVASYON GÖRÜŞMELERİ', 'Rezervasyon mesajları', 'Rezervasyonunuzla ilgili tedarikçi ve acente yanıtlarını takip edin.') + '<div class="acct-panel">' + reservationMessageList + '</div>') +
      pane('notifications', head('HABERDAR OLUN', 'Bildirimler', 'Hesap bildirimlerinizi ve tercihlerinizi yönetin.') + '<div class="acct-panel">' + notificationList + '</div><div class="acct-panel acct-portal-add"><h3>E-posta tercihleri</h3>' + preferencesForm + '<p class="acct-form-note">Tercihler kaydedilir. E-posta gönderimi yalnızca ilgili bildirim hizmeti etkin olduğunda yapılır.</p></div>') +
      pane('alerts', head('FIRSATLARI KAÇIRMAYIN', 'Fiyat takibi', 'İlan hedef fiyata indiğinde hesap bildirimi alın.') + '<div class="acct-panel">' + alertList + '</div><div class="acct-panel acct-portal-add"><h3>Yeni fiyat alarmı</h3>' + alertForm + '</div>') +
      pane('recommendations', head('SİZE ÖZEL', 'Seyahat önerileriniz', 'Rezervasyonlarınızdan doğan ihtiyaçları birlikte tamamlayalım.') + '<div class="acct-panel"><h3>Yolculuğunuzu tamamlayalım</h3><p class="acct-form-note">Ulaşım, konaklama ve bölgede yapabilecekleriniz için birkaç kısa soru.</p>' + journeyList + '</div><div class="acct-panel acct-portal-add"><h3>Seyahat tercihlerinizi netleştirin</h3>' + intentForm + '</div><div class="acct-panel"><h3>Sohbetinizden seçtiklerimiz</h3>' + chatSuggestionList + '</div><div class="acct-panel"><h3>WhatsApp ve e-posta önerileri</h3>' + sentSuggestionList + '</div>') +
      pane('support', head('YARDIM MERKEZİ', 'Destek geçmişi', 'Acente ile görüşmelerinizi ve yanıtları takip edin.') + '<div class="acct-panel">' + ticketList + '</div><div class="acct-panel acct-portal-add"><h3>Yeni destek talebi</h3>' + supportForm + '</div>'));
    var intentSelect = root.querySelector('[data-resource="travel-intent"] select[name="category"]'); if (intentSelect) intentSelect.value = intent.category || '';

    function submit(resource, values, feedback) {
      values.set('csrf', (document.querySelector('meta[name="csrf-token"]') || {}).content || '');
      feedback.textContent = 'Kaydediliyor…';
      fetch('/api/public/account/portal/' + encodeURIComponent(resource), { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' }, body: values.toString() }).then(function (response) { return response.json().then(function (json) { if (!response.ok) throw new Error(json.error || 'İşlem tamamlanamadı.'); return json; }); }).then(function () { location.reload(); }).catch(function (error) { feedback.textContent = error.message || 'İşlem tamamlanamadı.'; if (feedback.tagName === 'BUTTON') feedback.disabled = false; });
    }
    root.addEventListener('submit', function (event) {
      var target = event.target;
      if (!target.matches('.acct-portal-form')) return;
      event.preventDefault();
      var values = new URLSearchParams(new FormData(target));
      if (target.dataset.resource === 'preferences') ['booking_email', 'price_email', 'marketing_email', 'marketing_whatsapp'].forEach(function (key) { values.set(key, target.elements[key].checked ? 'true' : 'false'); });
      if (target.dataset.resource === 'travel-intent') { var budget = Number(values.get('budget') || 0); values.set('budget_minor', budget > 0 ? String(Math.round(budget * 100)) : ''); }
      if (target.dataset.resource === 'alerts') {
        var raw = values.get('listing_id') || '';
        var match = raw.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i);
        if (!match) { target.querySelector('.acct-form-message').textContent = 'Geçerli bir ilan bağlantısı veya kimliği girin.'; return; }
        values.set('listing_id', match[0]);
        values.set('target_minor', String(Math.round(Number(values.get('target_price')) * 100)));
      }
      submit(target.dataset.resource, values, target.querySelector('.acct-form-message'));
    });
    root.addEventListener('click', function (event) {
      var offerButton = event.target.closest('[data-journey-offer]');
      if (offerButton) {
        offerButton.disabled = true;
        offerButton.textContent = 'Hazırlanıyor…';
        var offerValues = new URLSearchParams({ reservation_id: offerButton.dataset.reservationId, listing_id: offerButton.dataset.listingId, csrf: (document.querySelector('meta[name="csrf-token"]') || {}).content || '' });
        fetch('/api/public/account/portal/journey-offer', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' }, body: offerValues.toString() }).then(function (response) { return response.json().then(function (json) { if (!response.ok || !json.value) throw new Error(json.error || 'İndirim hazırlanamadı.'); return json; }); }).then(function (json) { location.assign('/rezervasyon?listing=' + encodeURIComponent(offerButton.dataset.listingId) + '&offer=' + encodeURIComponent(json.value)); }).catch(function (error) { offerButton.textContent = error.message || 'İndirim hazırlanamadı.'; offerButton.disabled = false; });
        return;
      }
      var journeyButton = event.target.closest('[data-journey-answer]');
      if (journeyButton) {
        journeyButton.disabled = true;
        submit('journey-answer', new URLSearchParams({ reservation_id: journeyButton.dataset.reservationId, target_category: journeyButton.dataset.targetCategory, answer: journeyButton.dataset.journeyAnswer }), journeyButton);
        return;
      }
      var choiceButton = event.target.closest('[data-recommendation-choice]');
      if (choiceButton) {
        choiceButton.disabled = true;
        var feedbackValues = new URLSearchParams({ listing_id: choiceButton.dataset.listingId, choice: choiceButton.dataset.recommendationChoice });
        submit('recommendation-feedback', feedbackValues, choiceButton);
        return;
      }
      var button = event.target.closest('[data-delete],[data-note]');
      if (!button) return;
      if (button.dataset.delete && !confirm('Bu kaydı silmek istiyor musunuz?')) return;
      var values = new URLSearchParams();
      values.set('id', button.dataset.id || button.dataset.note);
      if (button.dataset.delete) values.set('action', 'delete');
      submit(button.dataset.delete || 'notifications', values, button);
    });
    try {
      var pendingConversation = localStorage.getItem('nexus_chat_conversation_id');
      if (pendingConversation && /^[0-9a-f-]{36}$/i.test(pendingConversation)) {
        localStorage.removeItem('nexus_chat_conversation_id');
        var claimValues = new URLSearchParams({ conversation_id: pendingConversation, csrf: (document.querySelector('meta[name="csrf-token"]') || {}).content || '' });
        fetch('/api/public/account/portal/claim-conversation', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: claimValues.toString() })
          .then(function (response) { if (response.ok) location.reload(); }).catch(function () {});
      }
    } catch (_) {}
  };
}());
