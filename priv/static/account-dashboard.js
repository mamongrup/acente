(()=>{if(!document.querySelector('script[src="/static/member-i18n.js"]')){const s=document.createElement('script');s.src='/static/member-i18n.js';s.defer=true;document.head.append(s);}})();
(function () {
  'use strict';
  var root = document.getElementById('account-dashboard');
  if (!root) return;
  const verificationStyle = document.createElement('link');
  verificationStyle.rel = 'stylesheet'; verificationStyle.href = '/static/customer-verification.css';
  document.head.appendChild(verificationStyle);
  const verificationScript = document.createElement('script');
  verificationScript.src = '/static/customer-verification.js';
  document.head.appendChild(verificationScript);

  function esc(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function icon(name) { return '<i class="hgi-stroke hgi-' + name + '" aria-hidden="true"></i>'; }
  function money(minor, currency) {
    var symbols = { TRY: '₺', EUR: '€', USD: '$', GBP: '£', RUB: '₽', CNY: '¥' };
    var code = String(currency || 'TRY').trim();
    return (symbols[code] || esc(code)) + ' ' + new Intl.NumberFormat(window.NEXUS_MEMBER_I18N?.lang()||'tr-TR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(Number(minor || 0) / 100);
  }
  function date(value) {
    if (!value) return 'Tarih belirtilmemiş';
    var parsed = new Date(String(value).slice(0, 10) + 'T12:00:00');
    return isNaN(parsed.getTime()) ? esc(value) : new Intl.DateTimeFormat(window.NEXUS_MEMBER_I18N?.lang()||'tr-TR', { day: 'numeric', month: 'long', year: 'numeric' }).format(parsed);
  }
  function status(value) {
    return ({ inquiry: 'Talep alındı', option: 'Ön rezervasyon', confirmed: 'Onaylandı', cancelled: 'İptal edildi', completed: 'Tamamlandı', pending: 'Beklemede', refunded: 'İade edildi', paid: 'Ödendi', unpaid: 'Ödeme bekliyor', authorized: 'Provizyonda', failed: 'Başarısız' })[value] || esc(value || 'Beklemede');
  }
  function category(value) {
    return ({ hotel: 'Otel', holiday_home: 'Tatil evi', yacht: 'Yat', tour: 'Tur', activity: 'Aktivite', flight: 'Uçuş', car: 'Araç', cruise: 'Kruvaziyer', pilgrimage: 'Hac & Umre', visa: 'Vize', ferry: 'Feribot', transfer: 'Transfer', beach: 'Şezlong', cinema: 'Sinema', event: 'Etkinlik', restaurant: 'Restoran', bus: 'Otobüs' })[value] || esc(value || 'Seyahat');
  }
  function empty(iconName, title, detail, link, linkText) {
    return '<div class="acct-empty"><span class="acct-empty-icon">' + icon(iconName) + '</span><h3>' + title + '</h3><p>' + detail + '</p><a class="acct-action" href="' + link + '">' + linkText + ' ' + icon('arrow-right-02') + '</a></div>';
  }
  function bookingCard(item) {
    return '<article class="acct-list-card"><div class="acct-list-icon">' + icon('calendar-03') + '</div><div class="acct-list-body"><div class="acct-list-top"><strong>' + esc(item.title) + '</strong><span class="acct-status acct-status-' + esc(item.status) + '">' + status(item.status) + '</span></div><p>' + category(item.category) + ' · ' + esc(item.reference) + '</p><div class="acct-list-meta"><span>' + icon('calendar-03') + ' ' + date(item.checkIn) + (item.checkOut ? ' – ' + date(item.checkOut) : '') + '</span><span>' + icon('user-multiple') + ' ' + Number(item.guests || 1) + ' misafir</span><span>' + icon('credit-card') + ' ' + status(item.paymentStatus) + '</span></div></div><strong class="acct-amount">' + money(item.amount, item.currency) + '</strong></article>';
  }
  function orderCard(item) {
    return '<article class="acct-list-card"><div class="acct-list-icon">' + icon('shopping-bag-01') + '</div><div class="acct-list-body"><div class="acct-list-top"><strong>Sipariş ' + esc(item.number) + '</strong><span class="acct-status acct-status-' + esc(item.status) + '">' + status(item.status) + '</span></div><p>' + date(item.date) + '</p><div class="acct-list-meta"><span>' + icon('credit-card') + ' Ödeme: ' + status(item.paymentStatus) + '</span></div></div><strong class="acct-amount">' + money(item.amount, item.currency) + '</strong></article>';
  }
  function favoriteCard(item) {
    return '<a class="acct-fav" href="/urunler/' + encodeURIComponent(item.id) + '"><span class="acct-fav-icon">' + icon('favourite') + '</span><span><strong>' + esc(item.title) + '</strong><small>' + category(item.category) + (item.locality ? ' · ' + esc(item.locality) : '') + '</small></span><b>' + money(item.price, item.currency) + '</b>' + icon('arrow-up-right-01') + '</a>';
  }
  function localSaved() {
    try { return JSON.parse(localStorage.getItem('nexus_saved_listings') || '[]').filter(function (id) { return /^[\w-]{8,}$/.test(String(id)); }); }
    catch (_) { return []; }
  }
  function render(data, benefits, portal, recommendations) {
    benefits = benefits || {};
    var bookings = Array.isArray(data.reservations) ? data.reservations : [];
    var orders = Array.isArray(data.orders) ? data.orders : [];
    var favorites = Array.isArray(data.favorites) ? data.favorites : [];
    var browserSaved = []; // Only account-owned favorites belong in the authenticated dashboard.
    var upcoming = bookings.filter(function (item) { return item.status !== 'cancelled' && item.status !== 'completed' && item.checkIn && item.checkIn >= new Date().toISOString().slice(0, 10); });
    var firstName = String(data.name || 'Misafir').trim().split(/\s+/)[0];
    var initial = firstName.slice(0, 1).toLocaleUpperCase(window.NEXUS_MEMBER_I18N?.lang()||'tr-TR');
    root.innerHTML =
      '<div class="acct-wrap"><div class="acct-crumb"><a href="/">Anasayfa</a>' + icon('arrow-right-01') + '<span>Hesabım</span></div>' +
      '<header class="acct-hero"><div class="acct-hero-copy"><div class="acct-eyebrow">NEXUS Agency · Müşteri hesabı</div><h1>Merhaba, ' + esc(firstName) + '<span class="acct-spark">✦</span></h1><p>Seyahatlerinizi, siparişlerinizi ve kaydettiğiniz yerleri tek yerden yönetin.</p><a class="acct-hero-link" href="/urunler">Yeni bir yolculuk keşfet ' + icon('arrow-up-right-01') + '</a></div><div class="acct-hero-mark"><span>' + esc(initial) + '</span><small>' + esc(data.name || '') + '</small></div></header>' +
      '<div class="acct-stats"><div><span class="acct-stat-icon">' + icon('airplane-take-off-01') + '</span><strong>' + upcoming.length + '</strong><small>Yaklaşan seyahat</small></div><div><span class="acct-stat-icon">' + icon('calendar-03') + '</span><strong>' + bookings.length + '</strong><small>Rezervasyon</small></div><div><span class="acct-stat-icon">' + icon('shopping-bag-01') + '</span><strong>' + orders.length + '</strong><small>Sipariş</small></div><div><span class="acct-stat-icon">' + icon('favourite') + '</span><strong>' + (favorites.length + browserSaved.length) + '</strong><small>Kaydedilen</small></div></div>' +
      '<div class="acct-layout"><nav class="acct-nav" aria-label="Hesap bölümleri"><div class="acct-nav-title">Hesabım</div>' +
      '<button type="button" data-tab="overview">' + icon('home-09') + ' Genel bakış</button><button type="button" data-tab="bookings">' + icon('calendar-03') + ' Rezervasyonlar <em>' + bookings.length + '</em></button><button type="button" data-tab="orders">' + icon('shopping-bag-01') + ' Siparişler ve ödemeler <em>' + orders.length + '</em></button><button type="button" data-tab="favorites">' + icon('favourite') + ' Favoriler <em>' + (favorites.length + browserSaved.length) + '</em></button><button type="button" data-tab="profile">' + icon('user-circle') + ' Profil ve güvenlik</button><div class="acct-nav-divider"></div><a href="/iletisim">' + icon('customer-support') + ' Yardım ve iletişim</a><form action="/logout" method="post"><button type="submit">' + icon('logout-01') + ' Çıkış yap</button></form></nav>' +
      '<div class="acct-content"><section class="acct-pane" data-pane="overview"><div class="acct-section-heading"><div><span>GENEL BAKIŞ</span><h2>Yolculuklarınız burada başlar</h2><p>Planlarınız ve hesabınızla ilgili güncel bilgiler.</p></div></div><div class="acct-overview-grid"><article class="acct-panel"><div class="acct-panel-head"><h3>Yaklaşan seyahatler</h3><button data-open="bookings">Tümünü gör ' + icon('arrow-right-02') + '</button></div>' + (upcoming.length ? upcoming.slice(0, 2).map(bookingCard).join('') : empty('calendar-03', 'Henüz yaklaşan seyahat yok', 'Yeni bir rezervasyon yaptığınızda seyahat planınız burada görünür.', '/urunler', 'Seyahatleri keşfet')) + '</article><article class="acct-panel acct-help"><span class="acct-help-icon">' + icon('customer-support') + '</span><h3>Yolculuğunuzda yanınızdayız</h3><p>Rezervasyon, ödeme veya seyahat planınızla ilgili yardım alın.</p><a href="/iletisim">Destek ekibine ulaşın ' + icon('arrow-right-02') + '</a></article></div><div class="acct-shortcuts"><h3>Hızlı erişim</h3><div><button data-open="bookings">' + icon('calendar-03') + '<span>Rezervasyonlarım</span>' + icon('arrow-right-02') + '</button><button data-open="orders">' + icon('credit-card') + '<span>Ödemelerim</span>' + icon('arrow-right-02') + '</button><button data-open="favorites">' + icon('favourite') + '<span>Favorilerim</span>' + icon('arrow-right-02') + '</button></div></div></section>' +
      '<section class="acct-pane" data-pane="bookings"><div class="acct-section-heading"><div><span>SEYAHATLERİM</span><h2>Rezervasyonlarım</h2><p>Onaylanan, bekleyen ve geçmiş rezervasyonlarınızı görüntüleyin.</p></div><a class="acct-outline" href="/urunler">Yeni rezervasyon ' + icon('arrow-up-right-01') + '</a></div><div class="acct-panel">' + (bookings.length ? bookings.map(bookingCard).join('') : empty('calendar-03', 'Henüz rezervasyonunuz yok', 'Otel, villa, tur ve diğer seçenekleri keşfederek ilk seyahatinizi planlayın.', '/urunler', 'İlanları keşfet')) + '</div></section>' +
      '<section class="acct-pane" data-pane="orders"><div class="acct-section-heading"><div><span>ALIŞVERİŞLERİM</span><h2>Siparişler ve ödemeler</h2><p>Satın alma ve ödeme durumlarınızı takip edin.</p></div></div><div class="acct-panel">' + (orders.length ? orders.map(orderCard).join('') : empty('shopping-bag-01', 'Henüz siparişiniz yok', 'Tamamlanan satın alma işlemleriniz burada listelenir.', '/urunler', 'Seçeneklere göz at')) + '</div></section>' +
      '<section class="acct-pane" data-pane="favorites"><div class="acct-section-heading"><div><span>KAYDETTİKLERİM</span><h2>Favorilerim</h2><p>İlginizi çeken yer ve deneyimlere yeniden göz atın.</p></div><a class="acct-outline" href="/urunler">Yeni seçenekler ' + icon('arrow-up-right-01') + '</a></div><div class="acct-panel">' + (favorites.length ? favorites.map(favoriteCard).join('') : '') + (browserSaved.length ? '<h3 class="acct-subheading">Bu tarayıcıda kaydedilenler</h3>' + browserSaved.map(function (id) { return '<a class="acct-fav" href="/urunler/' + encodeURIComponent(id) + '"><span class="acct-fav-icon">' + icon('favourite') + '</span><span><strong>Kaydedilen ilan</strong><small>İlanı görüntüle</small></span>' + icon('arrow-up-right-01') + '</a>'; }).join('') : '') + (!favorites.length && !browserSaved.length ? empty('favourite', 'Henüz favoriniz yok', 'Beğendiğiniz ilanları kalp simgesiyle kaydedebilirsiniz.', '/urunler', 'İlanları keşfet') : '') + '</div></section>' +
      '<section class="acct-pane" data-pane="profile"><div class="acct-section-heading"><div><span>HESAP AYARLARI</span><h2>Profil ve güvenlik</h2><p>Hesap bilgileriniz ve güvenliğiniz.</p></div></div><div class="acct-panel acct-profile"><div class="acct-profile-head"><span class="acct-avatar">' + esc(initial) + '</span><div><h3>' + esc(data.name || 'Misafir') + '</h3><p>Üyelik tarihi: ' + date(data.memberSince) + '</p></div></div><dl><div><dt>Ad soyad</dt><dd>' + esc(data.name || '—') + '</dd></div><div><dt>E-posta adresi</dt><dd>' + esc(data.email || '—') + '</dd></div><div><dt>Telefon</dt><dd>' + esc(data.phone || 'Henüz eklenmemiş') + '</dd></div></dl><div class="acct-security-note">' + icon('security-check') + '<span>Hesap bilgileriniz oturumunuzla korunur. Bilgilerinizde değişiklik veya şifre yardımı için destek ekibimizle iletişime geçin.</span></div><a class="acct-action" href="/iletisim">Hesap desteği alın ' + icon('arrow-right-02') + '</a></div></section></div></div></div>';
    var wallets = Array.isArray(benefits.wallets) ? benefits.wallets : [];
    var invoices = Array.isArray(benefits.invoices) ? benefits.invoices : [];
    var loyalty = benefits.loyalty || { tier: 'standard', points: 0 };
    var walletHtml = wallets.length ? wallets.map(function (wallet) {
      var transactions = Array.isArray(wallet.transactions) ? wallet.transactions : [];
      return '<article class="acct-wallet"><small>' + esc(wallet.currency) + ' CÜZDANI</small><strong>' + money(wallet.balance, wallet.currency) + '</strong><span>Kullanılabilir bakiye</span></article>' + (transactions.length ? '<div class="acct-wallet-transactions">' + transactions.map(function (item) { return '<div><span>' + esc(item.reference || item.type) + '<small>' + date(item.date) + '</small></span><strong>' + money(item.amount, wallet.currency) + '</strong></div>'; }).join('') + '</div>' : '');
    }).join('') : empty('wallet-01', 'Henüz cüzdan hareketi yok', 'İade ve tanımlanan bakiyeler burada görünecek.', '/iletisim', 'Yardım alın');
    var invoiceHtml = invoices.length ? invoices.map(function (item) {
      return '<article class="acct-list-card"><div class="acct-list-icon">' + icon('invoice-01') + '</div><div class="acct-list-body"><div class="acct-list-top"><strong>Fatura ' + esc(item.number) + '</strong><span class="acct-status acct-status-' + esc(item.status) + '">' + esc(item.status === 'sent' ? 'Düzenlendi' : item.status === 'draft' ? 'Taslak' : item.status === 'queued' ? 'Hazırlanıyor' : item.status === 'cancelled' ? 'İptal' : 'İşlemde') + '</span></div><p>Sipariş ' + esc(item.orderNumber) + ' · ' + date(item.date) + '</p><div class="acct-list-meta">' + esc(item.type === 'e_invoice' ? 'E-fatura' : item.type === 'e_archive' ? 'E-arşiv fatura' : 'Makbuz') + '</div></div><strong class="acct-amount">' + money(item.amount, item.currency) + '</strong></article>';
    }).join('') : empty('invoice-01', 'Henüz faturanız yok', 'Düzenlenen faturalarınız burada listelenecek.', '/iletisim', 'Fatura desteği');
    root.querySelector('.acct-nav-divider').insertAdjacentHTML('beforebegin', '<button type="button" data-tab="wallet">' + icon('wallet-01') + ' Cüzdan</button><button type="button" data-tab="loyalty">' + icon('award-01') + ' Puan ve sadakat</button><button type="button" data-tab="invoices">' + icon('invoice-01') + ' Faturalarım <em>' + invoices.length + '</em></button>');
    root.querySelector('.acct-content').insertAdjacentHTML('beforeend', '<section class="acct-pane" data-pane="wallet"><div class="acct-section-heading"><div><span>BAKİYEM</span><h2>Cüzdanım</h2><p>Tanımlanan bakiyeler ve hesap hareketleri.</p></div></div><div class="acct-panel"><div class="acct-wallet-grid">' + walletHtml + '</div></div></section><section class="acct-pane" data-pane="loyalty"><div class="acct-section-heading"><div><span>AVANTAJLARIM</span><h2>Puan ve sadakat</h2><p>Seyahatlerinizle bağlantılı üyelik bilgileri.</p></div></div><div class="acct-panel"><div class="acct-loyalty"><span class="acct-empty-icon">' + icon('award-01') + '</span><div><small>MEVCUT PUAN</small><strong>' + new Intl.NumberFormat(window.NEXUS_MEMBER_I18N?.lang()||'tr-TR').format(Number(loyalty.points || 0)) + '</strong><p>Üyelik seviyesi: ' + esc(loyalty.tier || 'standard') + '</p></div></div><div class="acct-security-note">' + icon('information-circle') + '<span>Tekrar rezervasyon indirimi ve puan kazanımı, yöneticinin dönemsel olarak etkinleştirdiği kampanya kurallarına göre uygulanır. ' + (Number(benefits.completedBookings || 0) > 0 ? 'Tamamlanmış rezervasyonunuz mevcut.' : 'İlk tamamlanan rezervasyonunuzdan sonra uygun kampanyalardan yararlanabilirsiniz.') + '</span></div></div></section><section class="acct-pane" data-pane="invoices"><div class="acct-section-heading"><div><span>BELGELERİM</span><h2>Faturalarım</h2><p>Siparişlerinize ait düzenlenmiş belgeler.</p></div></div><div class="acct-panel">' + invoiceHtml + '</div></section>');
    if (window.renderCustomerPortal) window.renderCustomerPortal(root, portal || {}, data, recommendations || {});
    var mergedTabs = { requests: 'bookings', documents: 'bookings', billing: 'orders', invoices: 'orders', alerts: 'favorites', travelers: 'profile', loyalty: 'wallet' };
    Object.keys(mergedTabs).forEach(function (source) {
      var destination = mergedTabs[source];
      var sourcePane = root.querySelector('[data-pane="' + source + '"]');
      var targetPane = root.querySelector('[data-pane="' + destination + '"]');
      if (!sourcePane || !targetPane) return;
      var section = document.createElement('div');
      section.className = 'acct-merged-section';
      while (sourcePane.firstChild) section.appendChild(sourcePane.firstChild);
      targetPane.appendChild(section);
      sourcePane.remove();
      var sourceButton = root.querySelector('.acct-nav [data-tab="' + source + '"]');
      if (sourceButton) sourceButton.remove();
    });
    var navLabels = { bookings: 'Seyahatlerim', orders: 'Sipariş ve faturalar', favorites: 'Favoriler ve fiyat takibi', recommendations: 'Size özel öneriler', profile: 'Profil ve yolcular', wallet: 'Cüzdan ve puanlar', support: 'Destek', notifications: 'Bildirimler' };
    Object.keys(navLabels).forEach(function (tab) {
      var button = root.querySelector('.acct-nav [data-tab="' + tab + '"]');
      if (button) button.innerHTML = button.querySelector('i').outerHTML + ' ' + navLabels[tab] + (button.querySelector('em') ? ' ' + button.querySelector('em').outerHTML : '');
    });
    root.querySelectorAll('.acct-nav-subtitle,.acct-nav > a[href="/iletisim"]').forEach(function (item) { item.remove(); });
    var divider = root.querySelector('.acct-nav-divider');
    fetch('/admin/role-context/data', { credentials: 'same-origin', headers: { Accept: 'application/json' }, cache: 'no-store' })
      .then(function (response) { return response.ok ? response.json() : null; })
      .then(function (roles) {
        if (!roles || !Array.isArray(roles.roles) || roles.roles.length < 2 || !divider) return;
        var link = document.createElement('a');
        link.href = '/admin/role-context';
        link.textContent = 'Görev alanı değiştir';
        divider.parentNode.insertBefore(link, divider);
      }).catch(function () {});
    ['overview', 'bookings', 'orders', 'favorites', 'recommendations', 'wallet', 'profile', 'notifications', 'support'].forEach(function (tab) {
      var button = root.querySelector('.acct-nav [data-tab="' + tab + '"]');
      if (button) divider.parentNode.insertBefore(button, divider);
    });
    function open(tab, updateHash) {
      tab = mergedTabs[tab] || tab;
      if (!root.querySelector('[data-pane="' + tab.replace(/[^a-z-]/g, '') + '"]')) tab = 'overview';
      root.querySelectorAll('[data-tab]').forEach(function (button) { var active = button.dataset.tab === tab; button.classList.toggle('active', active); button.setAttribute('aria-current', active ? 'page' : 'false'); });
      root.querySelectorAll('[data-pane]').forEach(function (pane) { pane.hidden = pane.dataset.pane !== tab; });
      if (updateHash) history.replaceState(null, '', '#'+tab);
      root.querySelector('.acct-content').scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }
    root.addEventListener('click', function (event) { var target = event.target.closest('[data-tab],[data-open]'); if (target) open(target.dataset.tab || target.dataset.open, true); });
    open(location.hash.slice(1), false);
  }
  Promise.all(['/api/public/account', '/api/public/account/benefits', '/api/public/account/portal', '/api/public/account/recommendations'].map(function (url, index) {
    return fetch(url, { credentials: 'same-origin', headers: { Accept: 'application/json' } }).then(function (response) {
      if (response.status === 401) { location.assign('/uye-girisi' + location.search); return null; }
      if (!response.ok) throw new Error('Hesap verileri yüklenemedi');
      return response.json();
    }).catch(function (error) { if (index === 3) return { chat: [], sent: [] }; throw error; });
  })).then(function (items) { if (items[0] && items[1] && items[2] && items[3]) render(items[0], items[1], items[2], items[3]); }).catch(function () {
    root.innerHTML = '<div class="acct-error"><h1>Hesap bilgileri açılamadı</h1><p>Lütfen sayfayı yenileyin veya destek ekibiyle iletişime geçin.</p><a href="/iletisim">Destek alın</a></div>';
  });
}());
