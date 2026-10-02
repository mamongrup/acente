/* Public category URL contract. Category codes stay stable; paths are localized. */
(function () {
  'use strict';
  if (window.NEXUS_CATEGORY_URL && window.NEXUS_CATEGORY_CODE) return;
  var slugs = {
    tr: {hotel:'otel', holiday_home:'tatil-evi', yacht:'yat', tour:'tur', activity:'aktivite', flight:'ucus', car:'arac', cruise:'kruvaziyer', pilgrimage:'hac-umre', visa:'vize', ferry:'feribot', transfer:'transfer', beach:'sezlong', cinema:'sinema', event:'etkinlik', restaurant:'restoran', bus:'otobus'},
    en: {hotel:'hotel', holiday_home:'holiday-home', yacht:'yacht', tour:'tour', activity:'activity', flight:'flight', car:'car', cruise:'cruise', pilgrimage:'pilgrimage', visa:'visa', ferry:'ferry', transfer:'transfer', beach:'beach', cinema:'cinema', event:'event', restaurant:'restaurant', bus:'bus'},
    de: {hotel:'hotel', holiday_home:'ferienhaus', yacht:'yacht', tour:'tour', activity:'aktivitaet', flight:'flug', car:'auto', cruise:'kreuzfahrt', pilgrimage:'wallfahrt', visa:'visum', ferry:'faehre', transfer:'transfer', beach:'liegestuhl', cinema:'kino', event:'veranstaltung', restaurant:'restaurant', bus:'bus'},
    ru: {hotel:'otel', holiday_home:'dom-otdyha', yacht:'yahta', tour:'tur', activity:'aktivnost', flight:'polet', car:'avtomobil', cruise:'kruiz', pilgrimage:'palomnichestvo', visa:'viza', ferry:'parom', transfer:'transfer', beach:'lezhak', cinema:'kino', event:'sobytie', restaurant:'restoran', bus:'avtobus'},
    ar: {hotel:'fndq', holiday_home:'mnzl-lltl', yacht:'yacht', tour:'rhl', activity:'nshat', flight:'rylh', car:'syar', cruise:'rhl-bhry', pilgrimage:'hjj-omr', visa:'tashyr', ferry:'qtar-bhry', transfer:'nql', beach:'shaty', cinema:'synyma', event:'falyh', restaurant:'mtm', bus:'hafl'},
    fr: {hotel:'hotel', holiday_home:'maison-de-vacances', yacht:'yacht', tour:'circuit', activity:'activite', flight:'vol', car:'voiture', cruise:'croisiere', pilgrimage:'pelerinage', visa:'visa', ferry:'ferry', transfer:'transfert', beach:'transat', cinema:'cinema', event:'evenement', restaurant:'restaurant', bus:'bus'},
    zh: {hotel:'jiudian', holiday_home:'dujiawu', yacht:'yacht', tour:'lvyou', activity:'huodong', flight:'feiji', car:'qiche', cruise:'youlun', pilgrimage:'chaosheng', visa:'qianzheng', ferry:'du-lun', transfer:'jiesong', beach:'shatan-yizi', cinema:'dianying', event:'yanchu', restaurant:'canting', bus:'gongjiao'}
  };
  var cookieLang = (document.cookie.match(/(?:^|;\s*)nexus_lang=([^;]+)/) || [])[1];
  var lang = window.NEXUS_SEO?.lang || cookieLang || document.documentElement.lang || 'tr';
  window.NEXUS_CATEGORY_SLUGS = slugs;
  window.NEXUS_CATEGORY_URL = function (code, selectedLang) {
    var chosen=selectedLang||lang;if(window.NEXUS_SEO?.categoryUrls?.[chosen]?.[code])return window.NEXUS_SEO.categoryUrls[chosen][code];
    var map = slugs[chosen] || slugs.tr;
    return '/' + (map[code] || slugs.tr[code] || code);
  };
  window.NEXUS_CATEGORY_CODE = function (path) {
    if(window.NEXUS_SEO && String(path)===location.pathname)path=window.NEXUS_SEO.basePath;
    var slug = String(path || '').split(/[?#]/)[0].replace(/^\//, '');
    for (var language in slugs) {
      for (var code in slugs[language]) {
        if (slugs[language][code] === slug) return code;
      }
    }
    return '';
  };
  window.NEXUS_LISTING_URL = function (item) {
    if(item?.id&&window.NEXUS_SEO?.listingUrls?.[item.id])return window.NEXUS_SEO.listingUrls[item.id];
    if (!item || !item.category || !item.title) return '/urunler/' + encodeURIComponent(item && item.id || '');
    var slug = String(item.title).toLocaleLowerCase('tr-TR')
      .replace(/ı/g, 'i').replace(/ğ/g, 'g').replace(/ü/g, 'u')
      .replace(/ş/g, 's').replace(/ö/g, 'o').replace(/ç/g, 'c')
      .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
    return window.NEXUS_CATEGORY_URL(item.category, 'tr') + '/' + encodeURIComponent(slug);
  };
  document.addEventListener('nexus:lang', function (event) {
    var target=window.NEXUS_SEO?.urls?.[event.detail?.lang];if(target&&decodeURI(location.pathname)!==target){const u=new URL(target,location.origin);const current=new URL(location.href);['tenant','preview'].forEach(k=>{if(current.searchParams.has(k))u.searchParams.set(k,current.searchParams.get(k));});location.assign(u.href);}
    lang = String((event.detail && event.detail.lang) || document.documentElement.lang || 'tr').toLowerCase();
  });
  document.addEventListener('DOMContentLoaded', function () {
    if (window.NEXUS_SEO || !document.body.classList.contains('category-page')) return;
    var code = window.NEXUS_CATEGORY_CODE(location.pathname);
    if (!code) return;
    document.querySelectorAll('link[rel="alternate"][hreflang]').forEach(function (alternate) {
      var alternateLang = alternate.hreflang === 'x-default' ? 'tr' : alternate.hreflang;
      if (slugs[alternateLang]) alternate.href = location.origin + window.NEXUS_CATEGORY_URL(code, alternateLang);
    });
  });
})();
