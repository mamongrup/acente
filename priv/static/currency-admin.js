(function () {
  var form = document.getElementById('currency-refresh-form');
  if (!form) return;

  var button = document.getElementById('currency-refresh-button');
  var message = document.getElementById('currency-refresh-status');
  var lastUpdated = document.getElementById('currency-last-updated');

  function setMessage(text, state) {
    message.textContent = text;
    message.dataset.state = state || '';
  }

  function applyStatus(data) {
    if (!data || !data.rates) return;
    Object.keys(data.rates).forEach(function (code) {
      var input = document.querySelector('[data-currency-rate="' + code + '"]');
      if (input) input.value = data.rates[code];
    });
    if (data.updatedAt && lastUpdated) {
      lastUpdated.textContent = new Date(data.updatedAt).toLocaleString('tr-TR');
      lastUpdated.dataset.updatedAt = data.updatedAt;
    }
  }

  function loadStatus() {
    return fetch('/static/currency-status.json?v=' + Date.now(), { cache: 'no-store' })
      .then(function (response) {
        if (!response.ok) throw new Error('Kur bilgisi okunamadı');
        return response.json();
      })
      .then(applyStatus);
  }

  loadStatus().catch(function () {
    if (lastUpdated) lastUpdated.textContent = 'Henüz güncellenmedi';
  });

  form.addEventListener('submit', function (event) {
    event.preventDefault();
    var previous = lastUpdated && lastUpdated.dataset.updatedAt;
    button.disabled = true;
    button.textContent = 'Kurlar güncelleniyor…';
    setMessage('TCMB verileri alınıyor.', 'working');

    fetch(form.action, { method: 'POST', credentials: 'same-origin' })
      .then(function (response) {
        if (!response.ok) throw new Error('Güncelleme başlatılamadı');
        var attempts = 0;
        return new Promise(function (resolve, reject) {
          var timer = setInterval(function () {
            attempts += 1;
            fetch('/static/currency-status.json?v=' + Date.now(), { cache: 'no-store' })
              .then(function (statusResponse) { return statusResponse.json(); })
              .then(function (data) {
                applyStatus(data);
                if (data.updatedAt && data.updatedAt !== previous) {
                  clearInterval(timer);
                  resolve();
                } else if (attempts >= 15) {
                  clearInterval(timer);
                  reject(new Error('Güncelleme zaman aşımına uğradı'));
                }
              })
              .catch(function () {});
          }, 1000);
        });
      })
      .then(function () { setMessage('Tüm kurlar başarıyla güncellendi.', 'success'); })
      .catch(function (error) { setMessage(error.message, 'error'); })
      .then(function () {
        button.disabled = false;
        button.textContent = 'Tüm kurları şimdi güncelle';
      });
  });
})();
