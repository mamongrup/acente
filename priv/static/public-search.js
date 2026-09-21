(() => {
  const form = document.querySelector('.product-search');
  if (!form) return;
  form.addEventListener('submit', async event => {
    const input = form.querySelector('[name="q"]');
    if (!input || !input.value.trim()) return;
    event.preventDefault();
    try {
      const response = await fetch(`/v1/search/intent?q=${encodeURIComponent(input.value)}`);
      const intent = await response.json();
      if (intent.category) form.querySelector('[name="kategori"]').value = intent.category;
      if (intent.location) form.querySelector('[name="konum"]').value = intent.location;
    } catch (_) { /* normal search remains available when intent service is unavailable */ }
    form.submit();
  });
})();
