// reveal-boot.js: scroll-reveal gizli durumunu ILK BOYAMADAN ONCE isaretler.
//
// Neden ayri bir boot script? main.js `defer` ile yuklenir; ilk boyama ondan
// once olabildigi icin gizlemeyi main.js'e birakmak "once gorun, sonra kaybol"
// titremesi (FOUC) uretir. theme-boot.js ile ayni desen: render-blocking,
// boyamadan once calisir.
//
// Progressive enhancement sozlesmesi:
//   * Azaltilmis hareket tercihinde hicbir sey gizlenmez (sinif eklenmez).
//   * main.js denetleyicisi devraldiginda `data-reveal-ready` isareti koyar.
//     main.js yuklenemez/coker de 3 sn sonra bu sinif kaldirilir; icerik
//     asla gorunmez kalmaz.
(function () {
  var html = document.documentElement;
  var mq = window.matchMedia ? window.matchMedia('(prefers-reduced-motion: reduce)') : null;
  if (mq && mq.matches) return;

  html.classList.add('has-reveal');

  // Guvenlik agi: denetleyici devralmadiysa gizlemeyi geri al.
  window.setTimeout(function () {
    if (!html.hasAttribute('data-reveal-ready')) html.classList.remove('has-reveal');
  }, 3000);
})();
