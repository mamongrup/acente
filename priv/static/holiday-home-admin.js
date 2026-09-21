(function () {
  var root = document.getElementById('holiday-home-manager');
  if (!root) return;

  var module = root.dataset.module;
  var content = document.getElementById('hh-manager-content');
  var title = document.getElementById('hh-page-title');
  var intro = document.getElementById('hh-page-intro');
  var status = document.getElementById('hh-save-status');
  var key = 'nexus.hh.' + module + '.v1';
  var defaults = {
    'property-types': ['Villa', 'Apart', 'Bungalov', 'Daire', 'Residence'],
    themes: ['Deniz manzaralı', 'Denize sıfır', 'Muhafazakar', 'Lüks', 'Balayı', 'Aile', 'Doğa içinde', 'Havuz', 'Jakuzi / spa', 'Tarihi / butik'],
    faq: [
      {q:'Giriş ve çıkış saatleri nedir?',a:'Giriş ve çıkış saatleri ilan sayfasında ve rezervasyon onayında belirtilir.'},
      {q:'Minimum kaç gece konaklamam gerekir?',a:'Minimum gece sayısı ilan detayında ve fiyat özetinde gösterilir.'},
      {q:'Rezervasyonu iptal edersem ne olur?',a:'İptal ve iade koşulları her ilanda ayrı tanımlanır.'},
      {q:'Hasar depozitosu alınıyor mu?',a:'Depozito tutarı ve iade koşulları ilan üzerinde belirtilir.'}
    ],
    rules: [
      {text:'Çocuklar için uygundur',level:'ok'}, {text:'Evcil hayvan kabul edilmez',level:'warning'},
      {text:'Sigara içilmez',level:'warning'}, {text:'Parti ve etkinlik düzenlenemez',level:'warning'}
    ],
    inclusions: {included:['Elektrik kullanımı','Havuz bakımı','İlk temizlik','Su kullanımı','Tüp kullanımı'],excluded:['Ek temizlik','Ek yatak','Oyun ablası','Ulaşım hizmeti']}
  };
  var data;
  try { data = JSON.parse(localStorage.getItem(key)) || defaults[module]; } catch (_) { data = defaults[module]; }
  if (module === 'property-types') {
    ['Villa', 'Apart', 'Bungalov', 'Daire', 'Residence'].forEach(function (item) {
      if (data.indexOf(item) === -1) data.push(item);
    });
    save();
  }

  var meta = {
    'property-types':['Tatil evi tipi','Yeni ilan ve ilan düzenlemede kullanılan tip listesini ekleyin, düzenleyin ve sıralayın.'],
    themes:['Tatil evi teması','Vitrin filtreleri ile ilan özelliklerinde kullanılan tema etiketlerini yönetin.'],
    faq:['SSS şablonu','Yeni ilanlara otomatik gelen soru ve yanıtları düzenleyin ve sıralayın.'],
    inclusions:['Dahil & Hariç (fiyat)','İlan formunda seçilebilen standart fiyat kalemlerini yönetin.'],
    rules:['Konaklama kuralları','İlanlarda seçilecek onay ve uyarı maddelerini yönetin.'],
    availability:['Aylık müsaitlik','İlan seçip günleri müsait/dolu yapın ve günlük fiyat override girin.'],
    recovery:['Kurtarma / Arşiv','Arşivlenmiş Tatil Evi ilanlarını görüntüleyin ve yeniden taslağa alın.']
  };
  title.textContent = (meta[module] || ['Tatil Evi',''])[0];
  intro.textContent = (meta[module] || ['',''])[1];

  function esc(v) { var d=document.createElement('div'); d.textContent=v||''; return d.innerHTML; }
  function save() { localStorage.setItem(key, JSON.stringify(data)); status.textContent='Kaydedildi · ' + new Date().toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'}); }
  function move(list, i, delta) { var n=i+delta; if(n<0||n>=list.length)return; var x=list[i];list[i]=list[n];list[n]=x;render();save(); }
  function toolbar(placeholder,label) { return '<div class="hh-toolbar"><input class="hh-new" placeholder="'+placeholder+'"><button type="button" class="primary hh-add">+ '+label+'</button></div>'; }

  function renderSimple() {
    content.innerHTML = toolbar(module==='themes'?'Yeni vitrin etiketi':'Yeni tip adı','Ekle') + '<div class="hh-list">'+data.map(function(x,i){return '<article class="hh-row"><input data-i="'+i+'" value="'+esc(x)+'"><div><button data-up="'+i+'">↑</button><button data-down="'+i+'">↓</button><button class="danger" data-del="'+i+'">Sil</button></div></article>';}).join('')+'</div>';
  }
  function renderCards(kind) {
    content.innerHTML='<div class="hh-list">'+data.map(function(x,i){var faq=kind==='faq';return '<article class="hh-card"><div class="hh-card-head"><strong>'+(faq?'SSS #'+(i+1):'Kural #'+(i+1))+'</strong><div><button data-up="'+i+'">↑</button><button data-down="'+i+'">↓</button><button class="danger" data-del="'+i+'">Kaldır</button></div></div>'+(faq?'<label>Soru (TR)<input data-field="q" data-i="'+i+'" value="'+esc(x.q)+'"></label><label>Yanıt (TR)<textarea data-field="a" data-i="'+i+'">'+esc(x.a)+'</textarea></label>':'<label>Kural metni<input data-field="text" data-i="'+i+'" value="'+esc(x.text)+'"></label><label>Önem<select data-field="level" data-i="'+i+'"><option value="ok" '+(x.level==='ok'?'selected':'')+'>Onay (yeşil)</option><option value="warning" '+(x.level==='warning'?'selected':'')+'>Uyarı (turuncu)</option></select></label>')+'</article>';}).join('')+'</div><button type="button" class="primary hh-add-card">+ '+(kind==='faq'?'Soru':'Kural')+' ekle</button>';
  }
  function renderInclusions() {
    content.innerHTML='<div class="hh-columns">'+[['included','Fiyata dahil'],['excluded','Fiyata hariç']].map(function(pair){var k=pair[0];return '<section class="glass-subcard" data-kind="'+k+'"><h3>'+pair[1]+'</h3>'+toolbar('Yeni kalem','Kalem ekle')+'<div class="hh-list">'+data[k].map(function(x,i){return '<article class="hh-row"><input data-kind="'+k+'" data-i="'+i+'" value="'+esc(x)+'"><button class="danger" data-kind="'+k+'" data-del="'+i+'">Sil</button></article>';}).join('')+'</div></section>';}).join('')+'</div>';
  }
  function renderCalendar() {
    content.innerHTML='<div class="hh-toolbar"><select id="hh-listing"><option value="">İlan seçin</option></select><input id="hh-month" type="month"><button id="hh-open">Tümü müsait</button><button id="hh-closed">Tümü dolu</button></div><div class="hh-calendar" id="hh-calendar"></div>';
    var m=document.getElementById('hh-month');m.value=new Date().toISOString().slice(0,7);
    fetch('/admin/catalog/data',{credentials:'same-origin'}).then(function(r){return r.json();}).then(function(items){var s=document.getElementById('hh-listing');items.filter(function(x){var c=(x.category||'').toLowerCase();return c==='villa'||c==='holiday_home';}).forEach(function(x){s.insertAdjacentHTML('beforeend','<option value="'+x.id+'">'+esc(x.title)+'</option>');});});
    function days(){var p=m.value.split('-'), count=new Date(+p[0],+p[1],0).getDate(), html='';for(var i=1;i<=count;i++)html+='<article class="hh-day" data-open="1"><strong>'+i+'</strong><span>Müsait</span><input type="number" placeholder="Fiyat"></article>';document.getElementById('hh-calendar').innerHTML=html;}
    m.addEventListener('change',days);days();
    document.getElementById('hh-open').onclick=function(){document.querySelectorAll('.hh-day').forEach(function(d){d.dataset.open='1';d.querySelector('span').textContent='Müsait';});};
    document.getElementById('hh-closed').onclick=function(){document.querySelectorAll('.hh-day').forEach(function(d){d.dataset.open='0';d.querySelector('span').textContent='Dolu';});};
    content.addEventListener('click',function(e){var d=e.target.closest('.hh-day');if(d&&e.target.tagName!=='INPUT'){d.dataset.open=d.dataset.open==='1'?'0':'1';d.querySelector('span').textContent=d.dataset.open==='1'?'Müsait':'Dolu';}});
  }
  function renderRecovery(){content.innerHTML='<div class="empty-state"><h3>Arşivlenmiş ilan bulunamadı</h3><p>İlanlar “archived” durumuna alındığında güvenli kurtarma için burada listelenecek.</p><a class="primary" href="/admin/catalog?cat=holiday_home">İlanlara git</a></div>';}
  function render(){if(module==='property-types'||module==='themes')renderSimple();else if(module==='faq'||module==='rules')renderCards(module);else if(module==='inclusions')renderInclusions();else if(module==='availability')renderCalendar();else renderRecovery();}
  render();
  content.addEventListener('input',function(e){var i=Number(e.target.dataset.i);if(Number.isNaN(i))return;if(module==='property-types'||module==='themes')data[i]=e.target.value;else if(module==='inclusions')data[e.target.dataset.kind][i]=e.target.value;else data[i][e.target.dataset.field]=e.target.value;save();});
  content.addEventListener('click',function(e){var i;if(e.target.matches('[data-up]')){i=+e.target.dataset.up;move(data,i,-1);}if(e.target.matches('[data-down]')){i=+e.target.dataset.down;move(data,i,1);}if(e.target.matches('[data-del]')){i=+e.target.dataset.del;if(module==='inclusions')data[e.target.dataset.kind].splice(i,1);else data.splice(i,1);render();save();}if(e.target.matches('.hh-add')){var box=e.target.closest('.hh-toolbar'),v=box.querySelector('.hh-new').value.trim();if(!v)return;if(module==='inclusions'){var k=e.target.closest('[data-kind]').dataset.kind;data[k].push(v);}else data.push(v);render();save();}if(e.target.matches('.hh-add-card')){data.push(module==='faq'?{q:'',a:''}:{text:'',level:'ok'});render();save();}});
  document.getElementById('hh-save').onclick=save;
})();
