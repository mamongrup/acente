(function () {
  var url = new URL(window.location.href);
  var tenant = url.searchParams.get('tenant');
  if (!tenant) return;
  if (/^[0-9a-f-]{36}$/i.test(tenant)) {
    document.cookie = 'nexus_public_tenant=' + encodeURIComponent(tenant) + '; Path=/; SameSite=Lax';
  }
  url.searchParams.delete('tenant');
  history.replaceState(history.state, '', url.pathname + url.search + url.hash);
})();
