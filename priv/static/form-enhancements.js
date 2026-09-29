/**
 * form-enhancements.js — Form alanlarını daha kullanışlı hale getiren geliştirmeler:
 *   1. Sık kullanılan input alanlarına autocomplete datalist desteği
 *   2. Telefon input maskesi (+90 5XX XXX XX XX)
 *   3. Para birimi input formatı (binlik ayracı)
 *   4. Select alanlarında filtreleme (typing ile arama)
 *   5. Form alanlarına floating label desteği
 */
(function () {
  'use strict';

  // ---- 1. Datalist sözlükleri: sık kullanılan değerler ----
  var DATALISTS = {
    'region-name': [
      'Bodrum', 'Marmaris', 'Fethiye', 'Kuşadası', 'Antalya', 'Alanya',
      'Kaş', 'Kalkan', 'Göcek', 'Datça', 'Ölüdeniz', 'Çeşme', 'Alaçatı',
      'Assos', 'Ayvalık', 'Cunda', 'Bozcaada', 'Gökçeada', 'Trabzon',
      'Rize', 'Artvin', 'Sapanca', 'Abant', 'Yedigöller', 'Kapadokya',
      'Pamukkale', 'Efes', 'Side', 'Belek', 'Kemer', 'Olympos', 'Çıralı',
      'Kaş', 'Demre', 'Myra', 'Simena', 'Üçağız', 'Kekova'
    ],
    'city': [
      'Muğla', 'Antalya', 'İstanbul', 'İzmir', 'Ankara', 'Bursa', 'Trabzon',
      'Rize', 'Artvin', 'Aydın', 'Balıkesir', 'Çanakkale', 'Düzce', 'Sakarya',
      'Bolu', 'Nevşehir', 'Denizli', 'Isparta', 'Burdur', 'Aksaray', 'Kayseri'
    ],
    'country': [
      'Türkiye', 'Almanya', 'İngiltere', 'Rusya', 'Hollanda', 'Fransa',
      'İtalya', 'İspanya', 'ABD', 'Belçika', 'Avusturya', 'İsveç',
      'Norveç', 'Danimarka', 'İsviçre', 'Yunanistan', 'Bulgaristan',
      'İran', 'Suudi Arabistan', 'BAE', 'Katar', 'Kuveyt', 'Irak',
      'Azerbaycan', 'Gürcistan', 'Ukrayna', 'Polonya', 'Çekya'
    ],
    'room-type': [
      'Standart Çift Kişilik', 'Deluxe Çift Kişilik', 'Süit', 'King Size',
      'Twin', 'Triple', 'Quad', 'Aile Odası', 'Manzaralı Oda',
      'Havuz Manzaralı', 'Deniz Manzaralı', 'Bahçe Manzaralı',
      'Engelli Odası', 'Konektif Oda', 'Balkonlu Oda', 'Jakuzili Oda',
      'Çatı Katı Süit', 'Kraliyet Süit', 'Balayı Süit', 'Villa'
    ],
    'amenity': [
      'WiFi', 'Klima', 'Klima (Split)', 'Merkezi Klima', 'Kapalı Havuz',
      'Açık Havuz', 'Aquapark', 'Çocuk Havuzu', 'Jakuzi', 'Hamam',
      'Sauna', 'Spa', 'Fitness Salonu', 'Tenis Kortu', 'Basketbol Sahası',
      'Voleybol Sahası', 'Bilardo', 'Masa Tenisi', 'Playstation',
      'Sinema Salonu', 'Oyun Odası', 'Çocuk Kulübü', 'Mini Club',
      'Animasyon', 'Canlı Müzik', 'DJ', 'Bar', 'Restoran', 'Kafe',
      'Market', 'Market (7/24)', 'Otopark', 'Vale Otopark', 'Jeneratör',
      'Asansör', 'Kablosuz İnternet', 'Smart TV', 'Uydu TV', 'Kasa',
      'Minibar', 'Çay-Kahve Seti', 'Balkon', 'Teras', 'Bahçe',
      'Deniz Manzarası', 'Havuz Manzarası', 'Dağ Manzarası',
      'Denize Sıfır', 'Plaj', 'Özel Plaj', 'Shuttle Servisi',
      'Havalimanı Transferi', 'Concierge', 'Resepsiyon 24 Saat',
      'Çamaşırhane', 'Kuru Temizleme', 'Ütü Servisi', 'Bebek Yatağı',
      'Bebek Sandalyesi', 'Evcil Hayvan Dostu', 'Sigara İçilmeyen Oda'
    ],
    'language': [
      'Türkçe', 'İngilizce', 'Almanca', 'Rusça', 'Fransızca', 'İspanyolca',
      'İtalyanca', 'Hollandaca', 'Arapça', 'Farsça', 'Japonca', 'Korece',
      'Çince', 'Portekizce', 'Yunanca', 'Bulgarca', 'Rumence', 'Lehçe',
      'İsveççe', 'Norveççe', 'Fince', 'Danca', 'Macarca', 'Çekçe'
    ],
    'transport-type': [
      'Özel Araç', 'Taksi', 'Minibüs', 'Otobüs', 'VIP Transfer',
      'Helikopter', 'Tekne', 'Feribot', 'Tren', 'Uçak', 'Kiralık Araç',
      'Shuttle', 'Bisiklet', 'ATV', 'Motorsiklet', 'Scooter'
    ],
    'activity': [
      'Dalış', 'Şnorkel', 'Yelkenli', 'Kano', 'Kayak', 'Rafting',
      'ATV Safari', 'Jeep Safari', 'Balon Turu', 'Yamaç Paraşütü',
      'Rafting', 'Zipline', 'Paintball', 'Okçuluk', 'Binicilik',
      'Doğa Yürüyüşü', 'Bisiklet Turu', 'Fishing', 'Yoga', 'Pilates',
      'SPA Masajı', 'Hamam', 'Vitamin Bar'
    ],
    'season': [
      'Yıl Boyu', 'Yaz (Haziran-Eylül)', 'İlkbahar (Mart-Mayıs)',
      'Sonbahar (Eylül-Kasım)', 'Kış (Aralık-Şubat)', 'Erken Rezervasyon',
      'Bayram', 'Yılbaşı', 'Sömestir', 'Festivaller'
    ]
  };

  // Datalist'leri oluştur
  Object.keys(DATALISTS).forEach(function (key) {
    var ids = Object.keys(DATALISTS);
    if (ids.indexOf(key) === -1) return;
    var list = document.createElement('datalist');
    list.id = 'dl-' + key;
    DATALISTS[key].forEach(function (val) {
      var opt = document.createElement('option');
      opt.value = val;
      list.appendChild(opt);
    });
    document.body.appendChild(list);
  });

  // Tüm input alanlarını tara ve uygun datalist ata
  document.querySelectorAll('input[type="text"], input[type="email"], input[type="tel"], input:not([type])').forEach(function (input) {
    // E-posta ve giriş alanları konum/oda gibi öneri listelerine bağlanmamalı.
    if (input.type === 'email' || input.closest('form[action="/login"]')) return;
    var name = (input.name || '').toLowerCase();
    var placeholder = (input.placeholder || '').toLowerCase();
    var label = '';

    // İlgili label'ı bul
    var labelEl = input.closest('label') || (input.id && document.querySelector('label[for="' + input.id + '"]'));
    if (labelEl) label = labelEl.textContent.toLowerCase();

    var combined = name + ' ' + placeholder + ' ' + label;

    // Hangi datalist ile eşleştiğini bul
    var matched = null;
    var matchPatterns = {
      'region-name': ['region', 'bölge', 'region-name', 'bolge'],
      'city': ['city', 'şehir', 'sehir', 'il'],
      'country': ['country', 'ülke', 'ulke', 'vatandaslik'],
      'room-type': ['room', 'oda', 'room-type', 'oda_tipi'],
      'amenity': ['amenity', 'ozellik', 'özellik', 'facilit'],
      'language': ['language', 'dil', 'lang'],
      'transport-type': ['transport', 'ulasim', 'ulaşım', 'transfer', 'araç', 'arac'],
      'activity': ['activity', 'aktivite', 'etkinlik', 'tur'],
      'season': ['season', 'donem', 'dönem', 'mevsim']
    };

    Object.keys(matchPatterns).forEach(function (dlKey) {
      if (matched) return;
      matchPatterns[dlKey].forEach(function (pat) {
        if (combined.indexOf(pat) !== -1) matched = dlKey;
      });
    });

    if (matched) {
      input.setAttribute('list', 'dl-' + matched);
      input.setAttribute('autocomplete', 'on');
    }
  });

  // ---- 2. Telefon input maskesi ----
  document.querySelectorAll('input[type="tel"], input[name*="phone"], input[name*="telefon"]').forEach(function (input) {
    input.setAttribute('placeholder', '+90 5XX XXX XX XX');
    input.addEventListener('input', function (e) {
      var val = e.target.value.replace(/[^0-9+]/g, '');
      if (val.length > 0 && val.charAt(0) === '+') {
        // +90 formatında formatla
        var digits = val.replace(/\+/g, '');
        if (digits.length > 0) {
          var formatted = '+90';
          if (digits.length > 2) {
            formatted += ' ' + digits.substring(2, 5);
          } else if (digits.length > 0) {
            formatted += ' ' + digits.substring(2);
          }
          if (digits.length > 5) {
            formatted += ' ' + digits.substring(5, 8);
          }
          if (digits.length > 8) {
            formatted += ' ' + digits.substring(8, 10);
          }
          if (digits.length > 10) {
            formatted += ' ' + digits.substring(10, 12);
          }
          e.target.value = formatted;
        }
      }
    });
  });

  // ---- 3. Para birimi input formatı ----
  document.querySelectorAll('input[name*="price"], input[name*="fiyat"], input[name*="tutar"], input[name*="amount"], input[name*="budget"]').forEach(function (input) {
    input.setAttribute('inputmode', 'numeric');
    input.addEventListener('blur', function (e) {
      var val = e.target.value.replace(/[^0-9.,]/g, '');
      if (val) {
        // Binlik ayracı ekle
        var parts = val.split(/[.,]/);
        if (parts[0]) {
          parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, '.');
          e.target.value = parts.join(parts.length > 1 ? ',' : '');
        }
      }
    });
    input.addEventListener('focus', function (e) {
      // Formatlamayı kaldır — düzenleme kolaylığı için
      e.target.value = e.target.value.replace(/\./g, '').replace(',', '.');
    });
  });

  // ---- 4. Select alanlarında filtreleme ----
  document.querySelectorAll('select[multiple], select[data-filterable]').forEach(function (select) {
    // Arama kutusu ekle
    var wrapper = document.createElement('div');
    wrapper.className = 'filterable-select-wrap';
    select.parentNode.insertBefore(wrapper, select);
    wrapper.appendChild(select);

    var search = document.createElement('input');
    search.type = 'text';
    search.className = 'filterable-select-search';
    search.placeholder = 'Ara...';
    search.setAttribute('aria-label', select.getAttribute('aria-label') || 'Seçenekleri filtrele');
    wrapper.insertBefore(search, select);

    search.addEventListener('input', function () {
      var query = this.value.toLowerCase();
      Array.from(select.options).forEach(function (opt) {
        opt.style.display = opt.text.toLowerCase().indexOf(query) !== -1 ? '' : 'none';
      });
    });
  });

  // ---- 5. Floating label desteği ----
  document.querySelectorAll('input[placeholder]:not([type="hidden"]):not([type="submit"]):not([type="checkbox"]):not([type="radio"])').forEach(function (input) {
    // Zaten floating label varsa atla
    if (input.closest('.floating-label-wrap')) return;

    var parent = input.parentNode;
    // Label varsa ve parent'taysa floating label uygula
    if (parent && parent.classList && !parent.classList.contains('floating-label-wrap')) {
      var label = parent.querySelector('label');
      if (label && parent.children.length <= 3) {
        // Floating label wrapper ekle
        var wrap = document.createElement('div');
        wrap.className = 'floating-label-wrap';
        parent.insertBefore(wrap, input);
        wrap.appendChild(label);
        wrap.appendChild(input);

        // Başlangıç durumu
        if (input.value) wrap.classList.add('has-value');

        input.addEventListener('input', function () {
          wrap.classList.toggle('has-value', !!this.value);
        });
        input.addEventListener('focus', function () {
          wrap.classList.add('is-focused');
        });
        input.addEventListener('blur', function () {
          wrap.classList.remove('is-focused');
        });
      }
    }
  });

  // ---- 6. Textarea otomatik yükseklik ----
  document.querySelectorAll('textarea').forEach(function (ta) {
    ta.style.minHeight = '80px';
    ta.style.resize = 'vertical';
    ta.addEventListener('input', function () {
      this.style.height = 'auto';
      this.style.height = Math.min(this.scrollHeight, 400) + 'px';
    });
  });

  // ---- 7. Sayısal inputlarda ok tuşları ile ayarlama ----
  document.querySelectorAll('input[type="number"]').forEach(function (input) {
    input.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        var step = parseFloat(this.step) || 1;
        var max = parseFloat(this.max);
        var val = parseFloat(this.value) || 0;
        if (isNaN(max) || val + step <= max) this.value = val + step;
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        var step2 = parseFloat(this.step) || 1;
        var min = parseFloat(this.min);
        var val2 = parseFloat(this.value) || 0;
        if (isNaN(min) || val2 - step2 >= min) this.value = val2 - step2;
      }
    });
  });

  // ---- 8. Form gönderim kilidi (çift tıklama engeli) ----
  document.querySelectorAll('form').forEach(function (form) {
    // Giriş formunda tarayıcının doğal POST akışına müdahale etme.
    if (form.getAttribute('action') === '/login') return;
    form.addEventListener('submit', function (event) {
      var btn = form.querySelector('button[type="submit"], input[type="submit"]');
      if (!btn || btn.disabled) return;
      // Submitter'ı senkron olarak kapatmak Chrome'da doğal form gönderimini
      // iptal edebilir. Varsayılan işlem başladıktan sonra kilitle.
      setTimeout(function () {
        if (event.defaultPrevented) return;
        btn.disabled = true;
        btn.dataset.originalText = btn.textContent;
        btn.textContent = 'Kaydediliyor...';
        // Hata durumunda sayfa yerinde kalırsa kilidi kaldır.
        setTimeout(function () {
          btn.disabled = false;
          btn.textContent = btn.dataset.originalText || 'Kaydet';
        }, 5000);
      }, 0);
    });
  });

})();
