(function () {
  'use strict';
  var params = new URLSearchParams(location.search);
  var from = params.get('check_in'), to = params.get('check_out');
  if (!from || !to || to <= from) return;
  var locale = (window.NEXUS_LOCALE && window.NEXUS_LOCALE.lang) || document.documentElement.lang || 'tr';
  var tr = locale === 'tr';
  var quoteParams = new URLSearchParams();
  ['check_in', 'check_out', 'q', 'konum', 'kategori', 'tenant'].forEach(function (key) { if (params.get(key)) quoteParams.set(key, params.get(key)); });
  var flexDays = [0, 3, 7].includes(Number(params.get('date_flex'))) ? Number(params.get('date_flex')) : 0;
  function shiftDate(value, days) { var date = new Date(value + 'T12:00:00'); date.setDate(date.getDate() + days); return date.getFullYear() + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0'); }
  function fetchQuotes(offset) {
    var search = new URLSearchParams(quoteParams);
    search.set('check_in', shiftDate(from, offset)); search.set('check_out', shiftDate(to, offset));
    return fetch('/api/public/search-quotes?' + search, { credentials: 'same-origin' }).then(function (r) { return r.ok ? r.json() : []; }).then(function (items) {
      return (Array.isArray(items) ? items : []).map(function (item) { item.searchCheckIn = search.get('check_in'); item.searchCheckOut = search.get('check_out'); item.searchOffset = offset; return item; });
    }).catch(function () { return []; });
  }
  function money(minor, currency) {
    return new Intl.NumberFormat(locale, { style: 'currency', currency: currency || 'TRY', maximumFractionDigits: 0 }).format((Number(minor) || 0) / 100);
  }
  function text(tag, value, className) {
    var node = document.createElement(tag); node.textContent = value; if (className) node.className = className; return node;
  }
  function roomNames(value) {
    if (Array.isArray(value)) return value.map(function (item) { return typeof item === 'string' ? { title: item } : item; }).filter(function (item) { return item && (item.name || item.title); });
    if (typeof value === 'string') { try { return roomNames(JSON.parse(value)); } catch (_) { return value.split(',').map(function (item) { return { title: item.trim() }; }).filter(function (item) { return item.title; }); } }
    return [];
  }
  var offsets = [0]; for (var day = 1; day <= flexDays; day++) offsets.push(-day, day);
  Promise.all([
    Promise.all(offsets.map(fetchQuotes)).then(function (groups) {
      var best = new Map();
      groups.flat().forEach(function (quote) {
        var previous = best.get(quote.id);
        if (!previous || (quote.available && !previous.available) || (quote.available === previous.available && Math.abs(quote.searchOffset) < Math.abs(previous.searchOffset))) best.set(quote.id, quote);
      });
      return Array.from(best.values());
    }),
    fetch('/api/public/listings?' + new URLSearchParams(params.get('tenant') ? { tenant: params.get('tenant') } : {}), { credentials: 'same-origin' }).then(function (r) { return r.ok ? r.json() : []; })
  ]).then(function (data) {
    var quotes = Array.isArray(data[0]) ? data[0] : [];
    var listings = Array.isArray(data[1]) ? data[1] : [];
    var byId = new Map(listings.map(function (item) { return [item.id, item]; }));
    var detailMatch = location.pathname.match(/^\/urunler\/([^/]+)\/?$/);
    if (detailMatch) {
      var selected = quotes.find(function (item) { return item.id === decodeURIComponent(detailMatch[1]); });
      if (selected) renderDetail(selected);
      return;
    }
    var requestedGuests = Number(params.get('guests') || 0);
    var requestedAdults = Number(params.get('adults') || requestedGuests || 2);
    var requestedChildren = Number(params.get('children') || 0);
    quotes = quotes.filter(function (quote) {
      if (quote.category === 'hotel') {
        var options = roomNames(quote.roomTypes);
        return !options.length || options.some(function (room) {
          return (!room.adults || Number(room.adults) >= requestedAdults) && (!room.children || Number(room.children) >= requestedChildren);
        });
      }
      var capacity = Number((byId.get(quote.id) || {}).guestCount || 0);
      return !requestedGuests || !capacity || capacity >= requestedGuests;
    });
    var grid = document.querySelector('main.products-page .product-grid');
    if (!grid) return;
    quotes.sort(function (a, b) { return Number(b.available) - Number(a.available) || Number(a.totalMinor) - Number(b.totalMinor); });
    var section = document.createElement('section'); section.className = 'nx-quote-results';
    section.appendChild(text('h2', tr ? 'Seçilen tarihler için sonuçlar' : 'Results for your dates'));
    section.appendChild(text('p', from + ' – ' + to + (flexDays ? ' · ±' + flexDays + (tr ? ' gün esnek' : ' flexible days') : '') + ' · ' + (params.get('guests') || '2') + (tr ? ' misafir' : ' guests'), 'nx-quote-summary'));
    if (!quotes.length) section.appendChild(text('p', tr ? 'Bu arama için ilan bulunamadı.' : 'No listings found for this search.'));
    var cards = document.createElement('div'); cards.className = 'nx-quote-grid';
    quotes.forEach(function (quote) {
      var listing = byId.get(quote.id) || {};
      var link = document.createElement('a'); link.className = 'nx-quote-card';
      var detail = new URLSearchParams(location.search); detail.delete('konum'); detail.delete('q'); detail.delete('kategori'); detail.delete('date_flex'); detail.set('check_in', quote.searchCheckIn); detail.set('check_out', quote.searchCheckOut);
      link.href = '/urunler/' + encodeURIComponent(quote.id) + '?' + detail;
      var image = Array.isArray(listing.images) && listing.images[0];
      if (image) { var img = document.createElement('img'); img.src = image; img.alt = ''; img.loading = 'lazy'; link.appendChild(img); }
      var content = document.createElement('div'); content.className = 'nx-quote-card-content';
      content.appendChild(text('small', quote.locality || ''));
      content.appendChild(text('strong', quote.title));
      if (quote.searchOffset) content.appendChild(text('small', quote.searchCheckIn + ' – ' + quote.searchCheckOut));
      content.appendChild(text('span', quote.availabilityKnown ? (quote.available ? (tr ? 'Müsait' : 'Available') : (tr ? 'Dolu' : 'Unavailable')) : (tr ? 'Müsaitlik teyidi gerekli' : 'Availability needs confirmation'), quote.available ? 'nx-quote-available' : 'nx-quote-unknown'));
      content.appendChild(text('b', money(quote.totalMinor, quote.currency) + (quote.availabilityKnown ? (tr ? ' / seçilen tarihler' : ' / selected dates') : (tr ? ' / tahmini toplam' : ' / estimated total'))));
      link.appendChild(content); cards.appendChild(link);
    });
    section.appendChild(cards); grid.replaceWith(section);
  }).catch(function () {});
  function renderDetail(quote) {
    var main = document.querySelector('main'); if (!main) return;
    var box = document.createElement('section'); box.className = 'nx-quote-detail';
    box.appendChild(text('h2', quote.availabilityKnown ? (tr ? 'Seçilen tarihlerin fiyatı' : 'Price for your dates') : (tr ? 'Seçilen tarihler için tahmini fiyat' : 'Estimated price for your dates')));
    box.appendChild(text('p', from + ' – ' + to + ' · ' + (params.get('guests') || '2') + (tr ? ' misafir' : ' guests')));
    box.appendChild(text('strong', money(quote.totalMinor, quote.currency)));
    box.appendChild(text('p', quote.availabilityKnown ? (quote.available ? (tr ? 'Bu tarihlerde müsait.' : 'Available for these dates.') : (tr ? 'Bu tarihlerde dolu.' : 'Unavailable for these dates.')) : (tr ? 'Müsaitlik için teyit alın.' : 'Please confirm availability.')));
    if (quote.category === 'hotel') {
      var requestedAdults = Number(params.get('adults') || params.get('guests') || 2);
      var requestedChildren = Number(params.get('children') || 0);
      var rooms = roomNames(quote.roomTypes).filter(function (room) {
        return (!room.adults || Number(room.adults) >= requestedAdults) && (!room.children || Number(room.children) >= requestedChildren);
      });
      if (rooms.length) {
        box.appendChild(text('h3', tr ? 'Oda tipleri' : 'Room types'));
        var list = document.createElement('ul'); rooms.forEach(function (room) {
          var item = document.createElement('li');
          item.appendChild(text('strong', room.title || room.name));
          var details = [room.bed, room.size_m2 && room.size_m2 + ' m²', room.view_type].filter(Boolean).join(' · ');
          if (details) item.appendChild(text('small', details));
          list.appendChild(item);
        }); box.appendChild(list);
        box.appendChild(text('small', tr ? 'Oda bazında fiyat ve müsaitlik için teyit gerekir.' : 'Room rates and availability require confirmation.'));
      } else {
        box.appendChild(text('p', tr ? 'Seçilen kişi sayısına uygun oda tipi bulunamadı.' : 'No room type matches the selected guests.'));
      }
    }
    main.insertBefore(box, main.firstChild);
  }
})();
