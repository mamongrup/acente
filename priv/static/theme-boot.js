// theme-boot.js: Clare HTML flash onemini onler.
// Sayfa yuklenirken data-theme'i hemen uygular.
// Kullanici tercihi yoksa (veya 'auto' ise) zaman dilimine gore secim yapar.
(function(){
  // Keep the pre-paint choice in sync with the interactive theme controller.
  // A legacy value is still respected for existing visitors.
  var k='chisfis-theme-pref';
  var legacy='nexus-theme-pref';
  var s=localStorage.getItem(k) || localStorage.getItem(legacy);
  var t;
  if(s==='dark'||s==='light'){
    t=s;
  } else {
    // auto: zamana gore
    var h=new Date().getHours();
    t=(h>=7&&h<19)?'light':'dark';
  }
  document.documentElement.setAttribute('data-theme',t);
})();
