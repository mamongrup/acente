// NEXUS Agency — Pre-booking Offer & Post-booking Voucher Generator with WhatsApp & Mail
(function () {
  var offerForm = document.getElementById('offer-builder-form');
  if (!offerForm) return;

  var previewBox = document.getElementById('offer-preview-content');
  var wpBtn = document.getElementById('offer-whatsapp-btn');
  var mailBtn = document.getElementById('offer-mail-btn');

  function updatePreview() {
    var ref = document.getElementById('offer-ref') ? document.getElementById('offer-ref').value : 'TKF-2026-001';
    var customer = document.getElementById('offer-customer') ? document.getElementById('offer-customer').value : 'Sayın Misafirimiz';
    var phone = document.getElementById('offer-phone') ? document.getElementById('offer-phone').value.replace(/[^0-9]/g, '') : '';
    var email = document.getElementById('offer-email') ? document.getElementById('offer-email').value : '';
    var listing = document.getElementById('offer-listing') ? document.getElementById('offer-listing').value : 'Lüks Tatil Villası';
    var dates = document.getElementById('offer-dates') ? document.getElementById('offer-dates').value : '15-22 Temmuz 2026';
    var price = document.getElementById('offer-price') ? document.getElementById('offer-price').value : '45.000 TL';
    var notes = document.getElementById('offer-notes') ? document.getElementById('offer-notes').value : 'Ön ödeme: %35, Girişte kalan bakiye ödenecektir.';

    var msg = 'Sayın ' + customer + ',\n\n' +
      'NEXUS Acente üzerinden ' + listing + ' için hazırlanan özel teklifiniz:\n\n' +
      '📌 Teklif No: ' + ref + '\n' +
      '📅 Tarihler: ' + dates + '\n' +
      '💰 Toplam Fiyat: ' + price + '\n' +
      'ℹ️ Notlar: ' + notes + '\n\n' +
      'Teklifi onaylamak ve resmi rezervasyon formunuzu almak için lütfen yanıt veriniz.\n' +
      'İyi tatiller dileriz!';

    if (previewBox) {
      previewBox.textContent = msg;
    }

    if (wpBtn) {
      var wpUrl = 'https://api.whatsapp.com/send?phone=' + phone + '&text=' + encodeURIComponent(msg);
      wpBtn.onclick = function () {
        if (!phone) { alert('Lütfen geçerli bir telefon numarası girin.'); return; }
        window.open(wpUrl, '_blank');
      };
    }

    if (mailBtn) {
      var mailto = 'mailto:' + email + '?subject=' + encodeURIComponent('Rezervasyon Teklifi: ' + ref + ' - ' + listing) + '&body=' + encodeURIComponent(msg);
      mailBtn.onclick = function () {
        if (!email) { alert('Lütfen geçerli bir e-posta adresi girin.'); return; }
        window.location.href = mailto;
      };
    }
  }

  offerForm.addEventListener('input', updatePreview);
  updatePreview();
})();
