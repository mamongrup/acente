(() => {
  const box = document.getElementById('public-availability');
  if (!box) return;
  const id = box.dataset.listingId;
  const tenant = box.dataset.tenant || '';
  const suffix = tenant ? `?tenant=${encodeURIComponent(tenant)}` : '';
  fetch(`/v1/listings/${encodeURIComponent(id)}/availability${suffix}`, { credentials: 'same-origin' })
    .then(response => response.json())
    .then(days => {
      const visible = days.filter(day => !day.closed && Number(day.available) > 0).slice(0, 14);
      box.innerHTML = visible.length
        ? visible.map(day => `<span class="availability-day"><b>${day.day}</b><small>${day.available} müsait</small></span>`).join('')
        : '<span class="muted">Yakın tarihlerde uygun kapasite görünmüyor.</span>';
    })
    .catch(() => { box.textContent = 'Müsaitlik bilgisi şu anda alınamıyor.'; });
})();
