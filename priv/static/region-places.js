(function () {
  function safeImage(value) {
    var url = String(value || '').trim();
    return /^https?:\/\//i.test(url) || /^\/(?!\/)/.test(url) ? url : '';
  }
  function articleUrl(slug) {
    return '/' + String(slug || '').split('/').map(encodeURIComponent).join('/');
  }
  function appendText(parent, tag, className, value) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    node.textContent = value;
    parent.appendChild(node);
    return node;
  }
  document.querySelectorAll('.builder-region-places').forEach(function (section) {
    var config = {}, posts = [];
    try { config = JSON.parse(section.dataset.regionConfig || '{}'); } catch (_) {}
    try { posts = JSON.parse(section.dataset.posts || '[]'); } catch (_) {}
    if (!Array.isArray(posts)) posts = [];
    var region = String(config.regionSlug || '').trim().toLocaleLowerCase('tr-TR');
    if (region) posts = posts.filter(function (post) { return String(post.regionSlug || '').toLocaleLowerCase('tr-TR') === region; });
    var archive = location.pathname === '/blog/gezilesi-yerler';
    // Category templates were seeded with this block globally. Show it there
    // only when an editor deliberately selected a region for that page.
    if (!archive && !region) { section.remove(); return; }
    posts = posts.slice(0, archive ? posts.length : Math.max(1, Math.min(6, Number(config.limit) || 3)));
    // An empty category guide would become a large unrelated photo block.
    // Keep the archive's empty state, but omit empty promotional blocks.
    if (!archive && !posts.length) { section.remove(); return; }
    if (archive) section.classList.add('builder-region-places-archive');
    section.textContent = '';
    var copy = document.createElement('div'); copy.className = 'builder-region-places-copy';
    appendText(copy, 'span', 'builder-region-places-eyebrow', 'BÖLGE REHBERİ');
    appendText(copy, 'h2', '', config.title || 'Gezilesi Yerler');
    if (posts.length) {
      posts.forEach(function (post) {
        var link = document.createElement('a'); link.className = 'builder-region-place-item'; link.href = articleUrl(post.slug);
        appendText(link, 'span', 'builder-region-place-label', post.regionSlug ? post.regionSlug.replace(/-/g, ' ') : 'Gezilesi Yerler');
        appendText(link, 'strong', '', post.title || 'Bölge rehberi');
        appendText(link, 'small', '', post.description || 'Gezi yazısını okuyun.');
        copy.appendChild(link);
      });
    } else {
      appendText(copy, 'p', 'builder-region-places-empty', 'Bu bölge için henüz yayınlanmış gezi yazısı bulunmuyor. Gezilesi Yerler kategorisine yazı eklediğinizde burada görünecek.');
    }
    if (location.pathname !== '/blog/gezilesi-yerler') {
      var all = appendText(copy, 'a', 'builder-region-places-all', 'Tüm gezilesi yerler →');
      all.href = '/blog/gezilesi-yerler';
    }
    var media = document.createElement('div'); media.className = 'builder-region-places-media';
    var image = document.createElement('img');
    image.src = safeImage(config.imageUrl) || safeImage(posts[0] && posts[0].coverImage) || '/static/chisfis/images/pexels-photo-131423.home.webp';
    image.alt = posts[0] && posts[0].title || 'Gezilesi yerler';
    image.loading = 'lazy';
    media.appendChild(image);
    posts.slice(0, 3).forEach(function (post, index) {
      var bubble = document.createElement('a'); bubble.className = 'builder-region-place-bubble builder-region-place-bubble-' + (index + 1); bubble.href = articleUrl(post.slug);
      var thumb = document.createElement('img'); thumb.src = safeImage(post.coverImage) || image.src; thumb.alt = ''; thumb.loading = 'lazy'; bubble.appendChild(thumb);
      appendText(bubble, 'span', '', post.title || 'Gezilesi Yerler');
      media.appendChild(bubble);
    });
    section.append(copy, media);
  });
})();
