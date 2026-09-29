(function () {
  const form = document.querySelector('[data-checkout-form="true"]');
  if (!form) return;
  const errorBox = form.querySelector('.checkout-error');
  const offerCode = new URLSearchParams(window.location.search).get('offer') || '';
  if (/^[0-9a-f]{36}$/.test(offerCode)) {
    const offerInput = document.createElement('input');
    offerInput.type = 'hidden';
    offerInput.name = 'offer_code';
    offerInput.value = offerCode;
    form.appendChild(offerInput);
    const requestKey = form.querySelector('[name="idempotency_key"]');
    if (requestKey) requestKey.value = 'journey-' + offerCode;
    const note = document.createElement('p');
    note.className = 'muted checkout-offer-note';
    note.textContent = 'Kampanya uygunluğu kontrol edilerek indirim ödeme tutarına uygulanır.';
    form.prepend(note);
    fetch('/api/public/account', { credentials: 'same-origin', headers: { Accept: 'application/json' } })
      .then(function (response) { if (!response.ok) throw new Error('account'); return response.json(); })
      .then(function (account) {
        const name = form.querySelector('[name="name"]');
        const email = form.querySelector('[name="email"]');
        const phone = form.querySelector('[name="phone"]');
        if (name && !name.value) name.value = account.name || '';
        if (email && account.email) {
          email.value = account.email;
          email.readOnly = true;
          email.title = 'İndirim, giriş yaptığınız müşteri hesabına bağlıdır.';
        }
        if (phone && !phone.value) phone.value = account.phone || '';
      }).catch(function () {
        if (errorBox) errorBox.textContent = 'İndirimi kullanmak için müşteri hesabınızla giriş yapın.';
      });
  }
  form.addEventListener('submit', async function (event) {
    event.preventDefault();
    if (errorBox) errorBox.textContent = '';
    const email = form.querySelector('[name="email"]');
    const phone = form.querySelector('[name="phone"]');
    if ((!email || !email.value.trim()) && (!phone || !phone.value.trim())) {
      if (errorBox) errorBox.textContent = 'Size ulaşabilmemiz için e-posta veya telefon numarası yazın.';
      return;
    }
    const button = form.querySelector('button[type="submit"]');
    if (button) {
      button.disabled = true;
      button.dataset.label = button.textContent;
      button.textContent = 'Hazırlanıyor…';
    }
    try {
      const response = await fetch(form.action, {
        method: 'POST',
        body: new FormData(form),
        headers: { Accept: 'application/json' },
        credentials: 'same-origin',
      });
      const data = await response.json();
      if (!response.ok || !data.ok) throw new Error(data.error || 'Rezervasyon oluşturulamadı.');
      if (!data.paymentUrl) throw new Error('Ödeme adresi oluşturulamadı.');
      window.location.assign(data.paymentUrl);
    } catch (error) {
      if (errorBox) errorBox.textContent = error.message || 'Bir hata oluştu. Lütfen tekrar deneyin.';
      if (button) {
        button.disabled = false;
        button.textContent = button.dataset.label || 'Ödeme adımına geç →';
      }
    }
  });
}());
