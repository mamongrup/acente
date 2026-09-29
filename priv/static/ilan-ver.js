/**
 * NEXUS TRAVEL TECH — Self-Service Supplier Listing Wizard
 * Multi-domain marketplace: rezervasyonyap.com.tr & reservationinturkey.com
 * Supports all 17 canonical categories seamlessly.
 */

(function () {
  'use strict';

  var root = document.getElementById('ilan-ver-root');
  if (!root) return;

  var lang = root.getAttribute('data-lang') || 'tr';
  var initialDomainTarget = root.getAttribute('data-domain-target') || 'both';

  var i18n = {
    tr: {
      badge: 'NEXUS MARKETPLACE ONBOARDING',
      hero_title: 'Tesis ve Hizmetlerinizi Milyonlara Ulaştırın',
      hero_desc: 'Oteller, villalar, yatlar, turlar ve 17 turizm kategorisinde ilanınızı dakikalar içinde ekleyin; hem Türkiye hem Global vitrinde anında yerinizi alın.',
      step1: 'Kategori',
      step2: 'Firma Bilgisi',
      step3: 'İlan & Fiyat',
      step4: 'Yayın & Onay',
      step1_title: 'Turizm Hizmet Kategorinizi Seçin',
      step1_desc: 'Portföyünüzdeki ana kategori türünü belirleyin. İlanınız bu kategoriye uygun filtrelerle yayınlanacaktır.',
      step2_title: 'Tedarikçi & İletişim Bilgileri',
      step2_desc: 'Rezervasyon ve sözleşme süreçlerinde iletişim kuracağımız yasal yetkili bilgileri.',
      step3_title: 'İlan Detayları ve Fiyatlandırma',
      step3_desc: 'Müşterilerinizin vitrinde göreceği ana başlık, konum ve başlangıç fiyatlandırması.',
      step4_title: 'Yayın Tercihleri ve Son Onay',
      step4_desc: 'İlanınızın hangi portallarda ve hangi şartlarda yayınlanacağını seçin.',
      next: 'Devam Et',
      back: 'Geri',
      submit: 'İlan Başvurusunu Gönder',
      submitting: 'Gönderiliyor…',
      company_name: 'Firma / İşletme Unvanı',
      contact_name: 'Yetkili Ad Soyad',
      email: 'E-posta Adresi',
      phone: 'İletişim Telefonu',
      tax_id: 'Vergi No / T.C. Kimlik No',
      tax_office: 'Vergi Dairesi (Opsiyonel)',
      listing_title: 'İlan Başlığı',
      listing_title_hint: 'Örn: Bodrum Yalıkavak Deniz Manzaralı Lüks Villa',
      locality: 'Konum / İl - İlçe',
      locality_hint: 'Örn: Muğla, Bodrum, Yalıkavak',
      description: 'Hizmet / Tesis Açıklaması',
      currency: 'Para Birimi',
      price: 'Taban / Başlangıç Fiyatı',
      guest_capacity: 'Misafir Kapasitesi / Kontenjan',
      domain_target: 'Yayınlanacağı Portallar',
      both_title: 'Her İki Portalda Yayınla',
      both_desc: 'rezervasyonyap.com.tr (TR/TRY) + reservationinturkey.com (Global/EUR)',
      both_badge: 'Maksimum Satış',
      ry_title: 'Sadece rezervasyonyap.com.tr',
      ry_desc: 'Türkiye iç pazar vitrini ve yerli misafir hedefi (TRY para birimi)',
      rit_title: 'Sadece reservationinturkey.com',
      rit_desc: 'Yurt dışı pazar ve çok dilli uluslararası misafir hedefi (EUR/USD para birimi)',
      terms_consent: 'Tedarikçi sözleşmesini ve kişisel verilerin korunması koşullarını okudum, onaylıyorum.',
      err_select_cat: 'Lütfen bir kategori seçin.',
      err_company: 'Firma unvanı gereklidir.',
      err_contact: 'Yetkili ad soyad gereklidir.',
      err_email: 'Geçerli bir e-posta adresi girin.',
      err_phone: 'Geçerli bir telefon numarası girin.',
      err_title: 'İlan başlığı en az 5 karakter olmalıdır.',
      err_locality: 'Konum bilgisi gereklidir.',
      err_price: 'Lütfen geçerli bir başlangıç fiyatı girin.',
      err_terms: 'Devam etmek için sözleşme onayını işaretlemelisiniz.',
      success_title: 'İlan Başvurunuz Alındı!',
      success_desc: 'Başvurunuz başarıyla kaydedildi. Operasyon ekibimiz bilgilerinizi inceledikten sonra ilanınız onaylanıp yayına alınacaktır.',
      ref_label: 'Başvuru Takip Kodu:',
      new_listing_btn: 'Yeni Bir İlan Ekle'
    },
    en: {
      badge: 'NEXUS MARKETPLACE ONBOARDING',
      hero_title: 'Reach Millions of Travelers in Turkey',
      hero_desc: 'List your hotels, villas, yachts, tours and experiences across 17 tourism categories. Get direct bookings on our multi-domain marketplace.',
      step1: 'Category',
      step2: 'Company',
      step3: 'Listing & Price',
      step4: 'Publishing',
      step1_title: 'Select Tourism Category',
      step1_desc: 'Choose the canonical category that best fits your inventory.',
      step2_title: 'Supplier & Contact Information',
      step2_desc: 'Official company details and authorized contact person for reservations.',
      step3_title: 'Listing Details & Base Pricing',
      step3_desc: 'Information that will be displayed to guests on the marketplace.',
      step4_title: 'Publishing Portals & Review',
      step4_desc: 'Select domain visibility and confirm submission.',
      next: 'Continue',
      back: 'Back',
      submit: 'Submit Listing Application',
      submitting: 'Submitting…',
      company_name: 'Company / Business Legal Name',
      contact_name: 'Authorized Contact Name',
      email: 'Business Email',
      phone: 'Phone Number (with country code)',
      tax_id: 'Tax ID / VAT Registration',
      tax_office: 'Tax Administration (Optional)',
      listing_title: 'Listing Title',
      listing_title_hint: 'e.g. Luxury Seafront Villa with Private Pool in Kalkan',
      locality: 'Location / City, District',
      locality_hint: 'e.g. Antalya, Kas, Kalkan',
      description: 'Property or Tour Description',
      currency: 'Currency',
      price: 'Starting Base Price',
      guest_capacity: 'Max Guest Capacity / Capacity',
      domain_target: 'Target Marketplace Domains',
      both_title: 'Publish on Both Marketplaces',
      both_desc: 'rezervasyonyap.com.tr (Domestic) + reservationinturkey.com (Global)',
      both_badge: 'Max Exposure',
      ry_title: 'Only rezervasyonyap.com.tr',
      ry_desc: 'Turkish domestic travelers (TRY currency)',
      rit_title: 'Only reservationinturkey.com',
      rit_desc: 'International inbound travelers (EUR/USD currencies)',
      terms_consent: 'I agree to the Supplier Terms & Conditions and Privacy Policy.',
      err_select_cat: 'Please select a category.',
      err_company: 'Company legal name is required.',
      err_contact: 'Contact name is required.',
      err_email: 'Please provide a valid email.',
      err_phone: 'Please provide a valid phone number.',
      err_title: 'Title must be at least 5 characters.',
      err_locality: 'Location is required.',
      err_price: 'Please enter a valid starting price.',
      err_terms: 'You must accept the terms to proceed.',
      success_title: 'Listing Application Received!',
      success_desc: 'Your submission has been queued for review. Our team will verify the details and activate your listing within 24 hours.',
      ref_label: 'Tracking Reference:',
      new_listing_btn: 'Submit Another Listing'
    }
  };

  var t = i18n[lang] || i18n.tr;

  // 17 Canonical Categories
  var categories = [
    { code: 'hotel', name: lang === 'en' ? 'Hotel' : 'Otel', icon: 'building-07', desc: lang === 'en' ? 'Hotels, resorts & boutique stays' : 'Şehir otelleri, butik & resort tesisler' },
    { code: 'holiday_home', name: lang === 'en' ? 'Holiday Home / Villa' : 'Tatil Evi & Villa', icon: 'home-08', desc: lang === 'en' ? 'Villas, apartments, bungalows' : 'Villa, apart, bungalow, daire & residence', note: lang === 'en' ? 'Includes villas, apartments, bungalows under holiday_home' : 'Villa, apart, bungalow alt türlerini kapsar' },
    { code: 'yacht', name: lang === 'en' ? 'Yacht & Boat' : 'Yat & Tekne', icon: 'anchor', desc: lang === 'en' ? 'Gulets, motor yachts, catamarans' : 'Gulet, motoryat, yelkenli, katamaran', note: lang === 'en' ? 'Includes gulet, motoryacht, catamaran types' : 'Gulet, motoryat, yelkenli alt türlerini kapsar' },
    { code: 'tour', name: lang === 'en' ? 'Tour' : 'Tur', icon: 'compass', desc: lang === 'en' ? 'Day trips, cultural & adventure tours' : 'Günübirlik, kültür ve doğa turları' },
    { code: 'activity', name: lang === 'en' ? 'Activity' : 'Aktivite', icon: 'ticket-01', desc: lang === 'en' ? 'Diving, paragliding, safaris' : 'Dalış, yamaç paraşütü, safari, rafting' },
    { code: 'flight', name: lang === 'en' ? 'Flight' : 'Uçuş', icon: 'airplane-01', desc: lang === 'en' ? 'Charter, scheduled & private flights' : 'Tarifeli, charter ve özel uçuş biletleri' },
    { code: 'car', name: lang === 'en' ? 'Car Rental' : 'Araç Kiralama', icon: 'car-01', desc: lang === 'en' ? 'Economy, luxury, SUV vehicles' : 'Ekonomik, lüks ve SUV araç kiralama' },
    { code: 'cruise', name: lang === 'en' ? 'Cruise' : 'Kruvaziyer', icon: 'ship', desc: lang === 'en' ? 'Mediterranean & Aegean cruises' : 'Ege ve Akdeniz gemi seyahatleri' },
    { code: 'pilgrimage', name: lang === 'en' ? 'Hajj & Umrah' : 'Hac & Umre', icon: 'moon-stars', desc: lang === 'en' ? 'Pilgrimage packages & arrangements' : 'Kutsal topraklar turları ve organizasyon' },
    { code: 'visa', name: lang === 'en' ? 'Visa Service' : 'Vize Danışmanlığı', icon: 'passport', desc: lang === 'en' ? 'Schengen, US & global visa services' : 'Schengen, ABD ve global vize işlemleri' },
    { code: 'ferry', name: lang === 'en' ? 'Ferry' : 'Feribot', icon: 'waves', desc: lang === 'en' ? 'Greek Islands & domestic ferry lines' : 'Yunan adaları ve yurt içi hatlar' },
    { code: 'transfer', name: lang === 'en' ? 'VIP Transfer' : 'Transfer', icon: 'steering-wheel', desc: lang === 'en' ? 'Airport shuttle & private VIP transfer' : 'Havalimanı VIP ve grup transfer hizmetleri' },
    { code: 'beach', name: lang === 'en' ? 'Beach & Sunbed' : 'Şezlong & Beach', icon: 'sun-02', desc: lang === 'en' ? 'Beach club, lounge & sunbed booking' : 'Beach club, loca ve şezlong rezervasyonu' },
    { code: 'cinema', name: lang === 'en' ? 'Cinema' : 'Sinema', icon: 'film-01', desc: lang === 'en' ? 'Movie tickets & premiere bookings' : 'Sinema seansları ve salon rezervasyonları' },
    { code: 'event', name: lang === 'en' ? 'Event & Concert' : 'Etkinlik & Konser', icon: 'music-note-01', desc: lang === 'en' ? 'Festivals, concerts & theater tickets' : 'Festival, konser ve tiyatro biletleri' },
    { code: 'restaurant', name: lang === 'en' ? 'Restaurant & Dining' : 'Restoran & Gastronomi', icon: 'restaurant-01', desc: lang === 'en' ? 'Fine dining, reservations & chef tables' : 'Masa rezervasyonu, gurme tadım menüleri' },
    { code: 'bus', name: lang === 'en' ? 'Bus Tickets' : 'Otobüs', icon: 'bus-01', desc: lang === 'en' ? 'Intercity bus tickets & transfers' : 'Şehirlerarası otobüs biletleri' }
  ];

  var state = {
    step: 1,
    category: '',
    company_name: '',
    contact_name: '',
    email: '',
    phone: '',
    tax_id: '',
    tax_office: '',
    listing_title: '',
    locality: '',
    description: '',
    currency: initialDomainTarget === 'reservationinturkey' ? 'EUR' : 'TRY',
    price: '',
    guest_capacity: 2,
    domain_target: initialDomainTarget === 'reservationinturkey' ? 'reservationinturkey' : 'both',
    terms_accepted: false,
    submitting: false,
    submitted_id: null
  };

  function render() {
    if (state.submitted_id) {
      renderSuccess();
      return;
    }

    var progressWidth = ((state.step - 1) / 3) * 100;

    var html = '' +
      '<div class="ilan-ver-hero">' +
        '<div class="ilan-ver-badge"><i class="hgi-stroke hgi-sparkles" aria-hidden="true"></i> ' + t.badge + '</div>' +
        '<h1>' + t.hero_title + '</h1>' +
        '<p>' + t.hero_desc + '</p>' +
      '</div>' +

      '<div class="ilan-ver-stepper">' +
        '<div class="ilan-ver-stepper-progress" style="width: ' + progressWidth + '%"></div>' +
        renderStepItem(1, t.step1) +
        renderStepItem(2, t.step2) +
        renderStepItem(3, t.step3) +
        renderStepItem(4, t.step4) +
      '</div>' +

      '<div class="ilan-ver-card">' +
        renderStepContent() +
        renderFooter() +
      '</div>';

    root.innerHTML = html;
    attachEvents();
  }

  function renderStepItem(stepNum, label) {
    var cls = 'ilan-ver-step-item';
    if (state.step === stepNum) cls += ' active';
    if (state.step > stepNum) cls += ' completed';

    var inner = state.step > stepNum ? '<i class="hgi-stroke hgi-tick-02" aria-hidden="true">✓</i>' : stepNum;

    return '' +
      '<div class="' + cls + '">' +
        '<div class="ilan-ver-step-circle">' + inner + '</div>' +
        '<div class="ilan-ver-step-label">' + label + '</div>' +
      '</div>';
  }

  function renderStepContent() {
    switch (state.step) {
      case 1:
        return renderStep1();
      case 2:
        return renderStep2();
      case 3:
        return renderStep3();
      case 4:
        return renderStep4();
      default:
        return '';
    }
  }

  function renderStep1() {
    var cards = categories.map(function (c) {
      var isSel = state.category === c.code ? ' selected' : '';
      return '' +
        '<div class="category-card' + isSel + '" data-cat="' + c.code + '">' +
          '<div class="cat-check">✓</div>' +
          '<i class="hgi-stroke hgi-' + c.icon + ' cat-icon" aria-hidden="true"></i>' +
          '<div class="cat-name">' + c.name + '</div>' +
          '<div class="cat-desc">' + c.desc + '</div>' +
        '</div>';
    }).join('');

    var selectedCatObj = categories.find(function (c) { return c.code === state.category; });
    var noteHtml = '';
    if (selectedCatObj && selectedCatObj.note) {
      noteHtml = '<div class="category-subtype-note"><i class="hgi-stroke hgi-information-circle"></i> ' + selectedCatObj.note + '</div>';
    }

    return '' +
      '<div class="ilan-ver-card-header">' +
        '<h2>' + t.step1_title + '</h2>' +
        '<p>' + t.step1_desc + '</p>' +
      '</div>' +
      '<div class="category-grid">' + cards + '</div>' +
      noteHtml +
      '<div id="cat-error" class="field-error" style="display:' + (state.catError ? 'block' : 'none') + '">' + t.err_select_cat + '</div>';
  }

  function renderStep2() {
    return '' +
      '<div class="ilan-ver-card-header">' +
        '<h2>' + t.step2_title + '</h2>' +
        '<p>' + t.step2_desc + '</p>' +
      '</div>' +
      '<div class="form-row">' +
        '<div class="form-group">' +
          '<label>' + t.company_name + ' <span class="required">*</span></label>' +
          '<input type="text" id="inp-company" value="' + escapeHtml(state.company_name) + '" placeholder="' + (lang === 'en' ? 'e.g. Aegean Coast Travel Ltd.' : 'Örn: Ege Sahil Turizm Ltd. Şti.') + '">' +
          '<div class="field-error" id="err-company">' + t.err_company + '</div>' +
        '</div>' +
        '<div class="form-group">' +
          '<label>' + t.contact_name + ' <span class="required">*</span></label>' +
          '<input type="text" id="inp-contact" value="' + escapeHtml(state.contact_name) + '" placeholder="' + (lang === 'en' ? 'e.g. John Doe' : 'Örn: Ahmet Yılmaz') + '">' +
          '<div class="field-error" id="err-contact">' + t.err_contact + '</div>' +
        '</div>' +
      '</div>' +
      '<div class="form-row">' +
        '<div class="form-group">' +
          '<label>' + t.email + ' <span class="required">*</span></label>' +
          '<input type="email" id="inp-email" value="' + escapeHtml(state.email) + '" placeholder="rezervasyon@firma.com">' +
          '<div class="field-error" id="err-email">' + t.err_email + '</div>' +
        '</div>' +
        '<div class="form-group">' +
          '<label>' + t.phone + ' <span class="required">*</span></label>' +
          '<input type="tel" id="inp-phone" value="' + escapeHtml(state.phone) + '" placeholder="+90 532 000 0000">' +
          '<div class="field-error" id="err-phone">' + t.err_phone + '</div>' +
        '</div>' +
      '</div>' +
      '<div class="form-row">' +
        '<div class="form-group">' +
          '<label>' + t.tax_id + '</label>' +
          '<input type="text" id="inp-taxid" value="' + escapeHtml(state.tax_id) + '" placeholder="1234567890">' +
          '<span class="hint">' + (lang === 'en' ? 'Optional at initial submission' : 'Başvuru aşamasında opsiyoneldir') + '</span>' +
        '</div>' +
        '<div class="form-group">' +
          '<label>' + t.tax_office + '</label>' +
          '<input type="text" id="inp-taxoffice" value="' + escapeHtml(state.tax_office) + '" placeholder="' + (lang === 'en' ? 'e.g. Bodrum' : 'Örn: Bodrum Vergi Dairesi') + '">' +
        '</div>' +
      '</div>';
  }

  function renderStep3() {
    return '' +
      '<div class="ilan-ver-card-header">' +
        '<h2>' + t.step3_title + '</h2>' +
        '<p>' + t.step3_desc + '</p>' +
      '</div>' +
      '<div class="form-group">' +
        '<label>' + t.listing_title + ' <span class="required">*</span></label>' +
        '<input type="text" id="inp-title" value="' + escapeHtml(state.listing_title) + '" placeholder="' + t.listing_title_hint + '">' +
        '<div class="field-error" id="err-title">' + t.err_title + '</div>' +
      '</div>' +
      '<div class="form-row">' +
        '<div class="form-group">' +
          '<label>' + t.locality + ' <span class="required">*</span></label>' +
          '<input type="text" id="inp-locality" value="' + escapeHtml(state.locality) + '" placeholder="' + t.locality_hint + '">' +
          '<div class="field-error" id="err-locality">' + t.err_locality + '</div>' +
        '</div>' +
        '<div class="form-group">' +
          '<label>' + t.guest_capacity + '</label>' +
          '<input type="number" id="inp-capacity" min="1" max="1000" value="' + (state.guest_capacity || 2) + '">' +
        '</div>' +
      '</div>' +
      '<div class="form-row">' +
        '<div class="form-group">' +
          '<label>' + t.currency + '</label>' +
          '<select id="inp-currency">' +
            '<option value="TRY"' + (state.currency === 'TRY' ? ' selected' : '') + '>TRY (₺) - Türk Lirası</option>' +
            '<option value="EUR"' + (state.currency === 'EUR' ? ' selected' : '') + '>EUR (€) - Euro</option>' +
            '<option value="USD"' + (state.currency === 'USD' ? ' selected' : '') + '>USD ($) - US Dollar</option>' +
          '</select>' +
        '</div>' +
        '<div class="form-group">' +
          '<label>' + t.price + ' <span class="required">*</span></label>' +
          '<input type="number" id="inp-price" step="0.01" min="1" value="' + escapeHtml(state.price) + '" placeholder="Örn: 2500.00">' +
          '<div class="field-error" id="err-price">' + t.err_price + '</div>' +
        '</div>' +
      '</div>' +
      '<div class="form-group">' +
        '<label>' + t.description + '</label>' +
        '<textarea id="inp-desc" rows="4" placeholder="' + (lang === 'en' ? 'Highlight unique features, views, amenities or inclusions...' : 'Tesisin ya da turun öne çıkan özelliklerini, dahil hizmetleri ve olanaklarını belirtin...') + '">' + escapeHtml(state.description) + '</textarea>' +
      '</div>';
  }

  function renderStep4() {
    var catObj = categories.find(function (c) { return c.code === state.category; }) || { name: state.category };

    var bothSel = state.domain_target === 'both' ? ' selected' : '';
    var rySel = state.domain_target === 'rezervasyonyap' ? ' selected' : '';
    var ritSel = state.domain_target === 'reservationinturkey' ? ' selected' : '';

    return '' +
      '<div class="ilan-ver-card-header">' +
        '<h2>' + t.step4_title + '</h2>' +
        '<p>' + t.step4_desc + '</p>' +
      '</div>' +

      '<div class="domain-targets-grid">' +
        '<div class="domain-target-card' + bothSel + '" data-target="both">' +
          '<div class="dt-header">' +
            '<span class="dt-title">' + t.both_title + '</span>' +
            '<span class="dt-badge">' + t.both_badge + '</span>' +
          '</div>' +
          '<div class="dt-desc">' + t.both_desc + '</div>' +
        '</div>' +
        '<div class="domain-target-card' + rySel + '" data-target="rezervasyonyap">' +
          '<div class="dt-header">' +
            '<span class="dt-title">' + t.ry_title + '</span>' +
          '</div>' +
          '<div class="dt-desc">' + t.ry_desc + '</div>' +
        '</div>' +
        '<div class="domain-target-card' + ritSel + '" data-target="reservationinturkey">' +
          '<div class="dt-header">' +
            '<span class="dt-title">' + t.rit_title + '</span>' +
          '</div>' +
          '<div class="dt-desc">' + t.rit_desc + '</div>' +
        '</div>' +
      '</div>' +

      '<div class="summary-box">' +
        '<div class="summary-row"><span class="label">' + t.step1 + '</span><span class="val">' + catObj.name + '</span></div>' +
        '<div class="summary-row"><span class="label">' + t.company_name + '</span><span class="val">' + escapeHtml(state.company_name) + '</span></div>' +
        '<div class="summary-row"><span class="label">' + t.contact_name + '</span><span class="val">' + escapeHtml(state.contact_name) + ' (' + escapeHtml(state.phone) + ')</span></div>' +
        '<div class="summary-row"><span class="label">' + t.listing_title + '</span><span class="val">' + escapeHtml(state.listing_title) + '</span></div>' +
        '<div class="summary-row"><span class="label">' + t.locality + '</span><span class="val">' + escapeHtml(state.locality) + '</span></div>' +
        '<div class="summary-row"><span class="label">' + t.price + '</span><span class="val">' + Number(state.price || 0).toLocaleString() + ' ' + state.currency + '</span></div>' +
      '</div>' +

      '<div class="form-group" style="margin-top: 1rem;">' +
        '<label style="display:flex; align-items:center; gap:0.5rem; cursor:pointer;">' +
          '<input type="checkbox" id="chk-terms"' + (state.terms_accepted ? ' checked' : '') + ' style="width:auto; margin:0;">' +
          '<span>' + t.terms_consent + '</span>' +
        '</label>' +
        '<div class="field-error" id="err-terms">' + t.err_terms + '</div>' +
      '</div>';
  }

  function renderFooter() {
    var backBtn = state.step > 1 ? '<button type="button" class="ilan-ver-btn secondary" id="btn-back">← ' + t.back + '</button>' : '<div></div>';
    var nextText = state.step === 4 ? (state.submitting ? t.submitting : t.submit) : (t.next + ' →');
    var nextCls = state.step === 4 ? 'ilan-ver-btn primary' : 'ilan-ver-btn primary';

    return '' +
      '<div class="ilan-ver-footer">' +
        backBtn +
        '<button type="button" class="' + nextCls + '" id="btn-next"' + (state.submitting ? ' disabled' : '') + '>' + nextText + '</button>' +
      '</div>';
  }

  function renderSuccess() {
    var html = '' +
      '<div class="ilan-ver-card success-card">' +
        '<div class="success-icon">✓</div>' +
        '<h3>' + t.success_title + '</h3>' +
        '<p>' + t.success_desc + '</p>' +
        '<div class="ref-box">' + t.ref_label + ' <strong>#' + state.submitted_id.substring(0, 8).toUpperCase() + '</strong></div>' +
        '<div>' +
          '<button type="button" class="ilan-ver-btn primary" id="btn-new-listing">' + t.new_listing_btn + '</button>' +
        '</div>' +
      '</div>';

    root.innerHTML = html;
    var btn = document.getElementById('btn-new-listing');
    if (btn) {
      btn.addEventListener('click', function () {
        state.step = 1;
        state.submitted_id = null;
        state.category = '';
        state.listing_title = '';
        state.price = '';
        render();
      });
    }
  }

  function attachEvents() {
    // Step 1: Category cards
    if (state.step === 1) {
      var catCards = root.querySelectorAll('.category-card');
      catCards.forEach(function (card) {
        card.addEventListener('click', function () {
          state.category = card.getAttribute('data-cat');
          state.catError = false;
          render();
        });
      });
    }

    // Step 4: Domain target cards
    if (state.step === 4) {
      var dtCards = root.querySelectorAll('.domain-target-card');
      dtCards.forEach(function (card) {
        card.addEventListener('click', function () {
          state.domain_target = card.getAttribute('data-target');
          render();
        });
      });

      var chk = document.getElementById('chk-terms');
      if (chk) {
        chk.addEventListener('change', function () {
          state.terms_accepted = chk.checked;
        });
      }
    }

    // Navigation buttons
    var btnBack = document.getElementById('btn-back');
    if (btnBack) {
      btnBack.addEventListener('click', function () {
        saveCurrentInputs();
        if (state.step > 1) {
          state.step--;
          render();
        }
      });
    }

    var btnNext = document.getElementById('btn-next');
    if (btnNext) {
      btnNext.addEventListener('click', function () {
        saveCurrentInputs();
        if (validateStep(state.step)) {
          if (state.step < 4) {
            state.step++;
            render();
          } else {
            submitForm();
          }
        }
      });
    }
  }

  function saveCurrentInputs() {
    if (state.step === 2) {
      var c = document.getElementById('inp-company');
      var ct = document.getElementById('inp-contact');
      var em = document.getElementById('inp-email');
      var ph = document.getElementById('inp-phone');
      var tx = document.getElementById('inp-taxid');
      var to = document.getElementById('inp-taxoffice');
      if (c) state.company_name = c.value.trim();
      if (ct) state.contact_name = ct.value.trim();
      if (em) state.email = em.value.trim();
      if (ph) state.phone = ph.value.trim();
      if (tx) state.tax_id = tx.value.trim();
      if (to) state.tax_office = to.value.trim();
    } else if (state.step === 3) {
      var ti = document.getElementById('inp-title');
      var loc = document.getElementById('inp-locality');
      var cap = document.getElementById('inp-capacity');
      var cur = document.getElementById('inp-currency');
      var pr = document.getElementById('inp-price');
      var desc = document.getElementById('inp-desc');
      if (ti) state.listing_title = ti.value.trim();
      if (loc) state.locality = loc.value.trim();
      if (cap) state.guest_capacity = parseInt(cap.value, 10) || 2;
      if (cur) state.currency = cur.value;
      if (pr) state.price = pr.value.trim();
      if (desc) state.description = desc.value.trim();
    }
  }

  function validateStep(step) {
    var valid = true;
    if (step === 1) {
      if (!state.category) {
        state.catError = true;
        var err = document.getElementById('cat-error');
        if (err) err.style.display = 'block';
        valid = false;
      }
    } else if (step === 2) {
      if (!state.company_name) { showErr('err-company'); valid = false; } else hideErr('err-company');
      if (!state.contact_name) { showErr('err-contact'); valid = false; } else hideErr('err-contact');
      if (!state.email || !state.email.includes('@')) { showErr('err-email'); valid = false; } else hideErr('err-email');
      if (!state.phone || state.phone.length < 7) { showErr('err-phone'); valid = false; } else hideErr('err-phone');
    } else if (step === 3) {
      if (!state.listing_title || state.listing_title.length < 5) { showErr('err-title'); valid = false; } else hideErr('err-title');
      if (!state.locality) { showErr('err-locality'); valid = false; } else hideErr('err-locality');
      var p = parseFloat(state.price);
      if (isNaN(p) || p <= 0) { showErr('err-price'); valid = false; } else hideErr('err-price');
    } else if (step === 4) {
      if (!state.terms_accepted) { showErr('err-terms'); valid = false; } else hideErr('err-terms');
    }
    return valid;
  }

  function showErr(id) {
    var el = document.getElementById(id);
    if (el) el.style.display = 'block';
  }

  function hideErr(id) {
    var el = document.getElementById(id);
    if (el) el.style.display = 'none';
  }

  function submitForm() {
    state.submitting = true;
    render();

    var priceNum = parseFloat(state.price) || 0;
    var priceMinor = Math.round(priceNum * 100);

    var payload = {
      company_name: state.company_name,
      contact_name: state.contact_name,
      email: state.email,
      phone: state.phone,
      tax_id: state.tax_id || '',
      tax_office: state.tax_office || '',
      category: state.category,
      listing_title: state.listing_title,
      locality: state.locality,
      description: state.description,
      currency: state.currency,
      price_minor: priceMinor,
      guest_capacity: state.guest_capacity || 2,
      domain_target: state.domain_target
    };

    fetch('/api/public/listing-submit', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(payload)
    })
      .then(function (res) {
        if (!res.ok) {
          throw new Error('Server returned ' + res.status);
        }
        return res.json();
      })
      .then(function (data) {
        state.submitting = false;
        state.submitted_id = data.submission_id || 'SUB-' + Date.now();
        render();
      })
      .catch(function (err) {
        state.submitting = false;
        render();
        alert((lang === 'en' ? 'Submission error: ' : 'Başvuru gönderilirken bir hata oluştu: ') + err.message);
      });
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // Initial render
  render();
})();
