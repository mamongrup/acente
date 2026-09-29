/**
 * Legacy icon bridge.
 *
 * The panel historically embedded emoji and typographic glyphs directly in
 * labels.  Keep those labels accessible while rendering every decorative UI
 * icon through the same Hugeicons font used by the storefront.
 */
(function () {
  'use strict';

  var icons = {
    '✕': 'cancel-01', '✓': 'tick-02', '✦': 'ai-beautify', '✨': 'ai-beautify',
    '←': 'arrow-left-01', '↻': 'refresh', '🚀': 'rocket-01', '⚡': 'flash',
    '📸': 'camera-01', '📍': 'location-01', '★': 'star', '♡': 'favourite',
    '🏨': 'building-02', '🍽️': 'restaurant-01', '🏖️': 'beach',
    '⚓': 'anchor-point', '👥': 'user-group', '👨‍✈️': 'user-star-01',
    '⏱️': 'clock-01', '🧭': 'compass-01', '🚗': 'car-01',
    '🕹️': 'settings-02', '🛡️': 'shield-01', '🚢': 'boat',
    '🎫': 'ticket-02', '🧳': 'luggage-01', '💺': 'chair-01',
    '🍷': 'bottle-wine', '⛱️': 'beach-02', '🍹': 'drink',
    '🌍': 'global', '📋': 'invoice-01', '🕋': 'mosque-01',
    '✈️': 'airplane-01', '🎟️': 'ticket-01', '🔞': 'user',
    '🛁': 'bathtub-01', '🚿': 'shower-head', '💡': 'bulb',
    '🔗': 'link-01', '🔍': 'search-01', '💳': 'credit-card',
    '📅': 'calendar-03', '✉️': 'mail-01', '🖨️': 'printer',
    '💾': 'floppy-disk', '📱': 'smart-phone-01', '💱': 'money-exchange-01',
    '📊': 'analytics-01', '⚖️': 'legal-document-01', '🎨': 'paint-brush-01',
    '🤖': 'ai-beautify', '📦': 'package', '🛏️': 'bed',
    '🏊': 'swimming', '🎾': 'tennis-ball', '❄️': 'snow',
    '📶': 'wifi-01', '⛽': 'gas-stove', '🕒': 'clock-01',
    '☀️': 'sun-01', '☕': 'coffee-01', '♨️': 'hot-tube', '♿': 'wheelchair',
    '⛵': 'sailboat', '🌅': 'sunrise', '🌊': 'waterfall-down-01',
    '🌲': 'leaf-01', '🌿': 'leaf-01', '🍳': 'restaurant-01',
    '🍸': 'drink', '🍿': 'popcorn', '🎁': 'gift', '🎈': 'gift',
    '🎧': 'headphones', '🎭': 'theater', '🎶': 'music-note-01',
    '🏄': 'surfboard', '🏋️': 'dumbbell-01', '🏡': 'home-01',
    '🐾': 'user', '👤': 'user', '👶': 'baby-01', '💧': 'waterfall-down-01',
    '💼': 'briefcase-01', '📁': 'folder-01', '📐': 'ruler',
    '📖': 'book-01', '📧': 'mail-01', '📺': 'film-01',
    '🔄': 'refresh', '🔊': 'volume-high', '🔌': 'plug-01',
    '🔑': 'key-01', '🔥': 'fire', '🔧': 'wrench-01',
    '🕌': 'mosque-01', '🗣️': 'user', '🤝': 'handshake',
    '🤿': 'swimming', '🥂': 'drink', '🥗': 'salad',
    '🥤': 'drink', '🥩': 'steak', '🧊': 'snow', '🧒': 'child',
    '🧖': 'hot-tube', '🧥': 'user', '🧺': 'shopping-bag-01',
    '🩺': 'stethoscope', '🚌': 'bus-01', '🚐': 'van',
    '🚤': 'boat', '🚪': 'door-01', '🛌': 'bed',
    '🛍️': 'shopping-bag-01', '🛎️': 'bell', '🛣️': 'road',
    '🛖': 'hut', '🪜': 'arrow-up-01', '➕': 'add-01', '↔': 'arrow-left-right',
    '✍️': 'pencil-edit-01', '✏️': 'pencil-edit-01', '🌐': 'global',
    '🏢': 'building-03', '🗑️': 'delete-02', '🦺': 'shield-01'
  };
  var tokens = Object.keys(icons).sort(function (a, b) { return b.length - a.length; });
  var selector = tokens.map(function (token) {
    return token.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }).join('|');
  var pattern = new RegExp('(' + selector + ')', 'g');
  var aliases = {
    'hgi-user-edit': 'hgi-user-edit-01',
    'hgi-horizontal-settings-slider': 'hgi-settings-02',
    'hgi-flight': 'hgi-airplane-01',
    'hgi-airplane-03': 'hgi-airplane-01',
    'hgi-heart-01': 'hgi-favourite',
    'hgi-anchor': 'hgi-anchor-point',
    'hgi-hiking': 'hgi-adventure',
    'hgi-sailboat': 'hgi-sailboat-coastal',
    'hgi-ship': 'hgi-cargo-ship',
    'hgi-user-02': 'hgi-user',
    'hgi-car-front': 'hgi-car-01',
    'hgi-global-01': 'hgi-globe',
    'hgi-home-residence': 'hgi-home-01',
    'hgi-slash-01': 'hgi-slash'
  };

  function normalizeIconClass(icon) {
    Object.keys(aliases).forEach(function (oldName) {
      if (icon.classList.contains(oldName)) icon.classList.replace(oldName, aliases[oldName]);
    });
  }

  function replaceKnownSvg(svg) {
    if (!svg || !svg.parentNode || svg.closest('[data-mm-logo],.mm-logo,.trend-chart,.sparkline')) return;
    // The hero search already has vector icons in the first HTML response.
    // Replacing them with the icon font changes their apparent size after paint.
    if (svg.closest('.hero-search-form form')) return;
    var link = svg.closest('a[href]');
    var href = link ? link.getAttribute('href') || '' : '';
    var social = {
      'facebook.com': 'facebook-01', 'instagram.com': 'instagram',
      'x.com': 'new-twitter', 'twitter.com': 'twitter',
      'github.com': 'github', 'youtube.com': 'youtube'
    };
    var name = Object.keys(social).find(function (domain) { return href.indexOf(domain) !== -1; });
    var icon = name ? social[name] : '';
    var path = svg.querySelector('path');
    var d = path ? path.getAttribute('d') || '' : '';
    if (!icon) {
      if (d.indexOf('M17 17L21 21') === 0 || d.indexOf('m20 20-4.2-4.2') === 0) icon = 'search-01';
      else if (d.indexOf('M12 3a3 3') === 0) icon = 'mic-01';
      else if (d.indexOf('M18 6L6.00081') === 0) icon = 'cancel-01';
      else if (d.indexOf('M4 5L20 5') === 0) icon = 'menu-01';
      else if (d.indexOf('M18 8a6 6') === 0) icon = 'notification-01';
      else if (d.indexOf('M3 3h1.1') === 0 || d.indexOf('M10.5 20.25') === 0) icon = 'shopping-cart-01';
      else if (d.indexOf('M20 21.0001') === 0) icon = 'user';
      else if (d.indexOf('M3 11.9896') === 0) icon = 'home-01';
      else if (d.indexOf('M12.53 16.28') === 0) icon = 'arrow-down-01';
      else if (d.indexOf('M15 10.5a3 3') === 0) icon = 'location-01';
      else if (d.indexOf('M6.28 5.22') === 0) icon = 'arrow-down-01';
      else if (d.indexOf('M6 12H18') === 0) icon = 'building-02';
      else if (d.indexOf('M3 22C7.67798') === 0) icon = 'adventure';
      else if (d.indexOf('M9 19L12 15') === 0) icon = 'restaurant-01';
      else if (d.indexOf('M2 15.7501') === 0) icon = 'beach';
      else if (d.indexOf('M2 21.9684') === 0) icon = 'airplane-01';
      else if (d.indexOf('M6.75 3v2.25') === 0) icon = 'calendar-03';
      else if (d.indexOf('M15.75 19.5') === 0) icon = 'arrow-left-01';
      else if (d.indexOf('m8.25 4.5') === 0) icon = 'arrow-right-01';
      else if (d.indexOf('M18 7.5v3') === 0) icon = 'user-add-01';
      else if (d.indexOf('M4.25 12a.75') === 0) icon = 'minus-sign';
      else if (d.indexOf('M12 3.75a.75') === 0) icon = 'add-01';
      else if (d.indexOf('M13.5 4.5 21') === 0) icon = 'arrow-right-01';
      else if (d.indexOf('M10.4107 19.9677') === 0) icon = 'favourite';
      else if (d.indexOf('M15.5 11C15.5') === 0) icon = 'location-01';
      else if (d.indexOf('M10.788 3.21') === 0) icon = 'star';
      else if (d.indexOf('M12.97 3.97') === 0) icon = 'arrow-right-01';
      else if (d.indexOf('M4.5 5.653') === 0) icon = 'play';
    }
    if (!icon) return;
    var replacement = document.createElement('i');
    replacement.className = 'hgi-stroke hgi-' + icon + ' ' + (svg.getAttribute('class') || '');
    replacement.setAttribute('aria-hidden', 'true');
    if (svg.hasAttribute('width')) replacement.style.width = svg.getAttribute('width') + 'px';
    if (svg.hasAttribute('height')) replacement.style.height = svg.getAttribute('height') + 'px';
    svg.parentNode.replaceChild(replacement, svg);
  }

  function replaceText(node) {
    if (!node.nodeValue || !pattern.test(node.nodeValue)) return;
    pattern.lastIndex = 0;
    var fragment = document.createDocumentFragment();
    var cursor = 0;
    node.nodeValue.replace(pattern, function (token, _match, offset) {
      if (offset > cursor) fragment.appendChild(document.createTextNode(node.nodeValue.slice(cursor, offset)));
      var icon = document.createElement('i');
      icon.className = 'hgi-stroke hgi-' + icons[token] + ' legacy-hgi-icon';
      icon.setAttribute('aria-hidden', 'true');
      fragment.appendChild(icon);
      var accessible = document.createElement('span');
      accessible.className = 'sr-only';
      accessible.setAttribute('data-keep-symbols', '');
      accessible.style.cssText = 'position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0';
      accessible.textContent = token;
      fragment.appendChild(accessible);
      cursor = offset + token.length;
      return token;
    });
    if (cursor < node.nodeValue.length) fragment.appendChild(document.createTextNode(node.nodeValue.slice(cursor)));
    node.parentNode.replaceChild(fragment, node);
  }

  function normalize(root) {
    if (!root || root.nodeType !== 1 || root.closest('script,style,textarea,[data-keep-symbols]')) return;
    if (root.matches('i.hgi-stroke')) normalizeIconClass(root);
    root.querySelectorAll('i.hgi-stroke').forEach(normalizeIconClass);
    if (root.localName === 'svg') replaceKnownSvg(root);
    else root.querySelectorAll('svg').forEach(replaceKnownSvg);
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    var nodes = [];
    while (walker.nextNode()) {
      var parent = walker.currentNode.parentElement;
      if (parent && !parent.closest('script,style,textarea,i.hgi-stroke,[data-keep-symbols]')) nodes.push(walker.currentNode);
    }
    nodes.forEach(replaceText);
  }

  function start() {
    normalize(document.body);
    new MutationObserver(function (records) {
      records.forEach(function (record) {
        Array.prototype.forEach.call(record.addedNodes, function (node) {
          if (node.nodeType === 3 && node.parentElement && !node.parentElement.closest('[data-keep-symbols]')) replaceText(node);
          else normalize(node);
        });
      });
    }).observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
}());
