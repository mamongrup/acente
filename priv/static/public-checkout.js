(function () {
  const form = document.querySelector('[data-checkout-form="true"]');
  if (!form) return;
  const errorBox = form.querySelector('.checkout-error');
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
