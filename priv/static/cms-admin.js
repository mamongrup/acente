(function () {
  var builderList = document.getElementById('page-builder-list');
  var builderType = document.getElementById('page-builder-type');
  var builderAdd = document.getElementById('page-builder-add');
  var builderJson = document.getElementById('page-builder-json');
  var builderPreview = document.getElementById('page-builder-preview');
  var blocks = [];
  var labels = {hero:'Hero / Arama',source_section:'Sayfanın hazır bölümü',region_places:'Gezilesi Yerler / Bölge tanıtımı',featured_listings:'Öne çıkan ilanlar',category_grid:'Kategori kartları',trust_strip:'Güven şeridi',benefit_cards:'Neden bizi seçin kartları',video_gallery:'Video galerisi',destination_grid:'Destinasyon kartları',how_it_works:'Nasıl çalışır adımları',stay_types:'Konaklama tipleri',blog_cards:'Blog kartları',divider:'Bölüm ayırıcı',rich_text:'Zengin metin',newsletter:'Bülten kayıt',filter_bar:'Filtre çubuğu',listing_grid:'İlan ızgarası',listing_collection:'Seçilebilir ilan listeleme',image_gallery:'Görsel galeri',faq:'SSS / Sorular',cta:'Harekete geçirici alan',testimonials:'Müşteri yorumları'};
  var sectionOptions = {
    home:[['hero','Hero ve arama'],['adventure','Maceraya çıkalım'],['why_host','Neden ev sahibi olmalı?'],['featured','Öne çıkan konaklamalar'],['divider_one','Birinci ayırıcı'],['how_it_works','Nasıl çalışır?'],['become_host','Ev sahibi ol'],['newsletter','Bülten'],['divider_two','İkinci ayırıcı'],['explore_nearby','Yakın yerleri keşfet'],['host_cta','Ev sahibi çağrısı'],['stay_types','Konaklama tipleri'],['videos','Videolar'],['news','Uzaklardan haberler']],
    category:[['hero','Hero ve arama'],['results_heading','İlan sayısı ve harita'],['filters','Filtreler'],['listings','İlan kartları'],['region','Bölgeye göre keşfet'],['theme','Temaya göre keşfet'],['benefits','Neden bizi seçin?']]
  };
  var benefitIcons = [['secure','Kalkan'],['price','Fiyat rozeti'],['support','Kulaklık'],['confirm','Şimşek'],['cancel','Yenileme'],['choice','Dünya']];
  var benefitDefaults = [
    {icon:'secure',title:'Güvenli Rezervasyon',description:'SSL şifreleme ve 3D Secure ödeme altyapısıyla güvenle rezervasyon yapın.'},
    {icon:'price',title:'Fiyatları Karşılaştırın',description:'İlanların fiyat ve koşullarını rezervasyon öncesinde inceleyin.'},
    {icon:'support',title:'Seyahat Desteği',description:'Sorularınız ve talepleriniz için destek kanallarımızı kullanın.'},
    {icon:'confirm',title:'Rezervasyon Takibi',description:'Rezervasyonunuzun durumunu hesabınızdan takip edin.'},
    {icon:'cancel',title:'Açık İptal Koşulları',description:'İptal ve değişiklik koşullarını ilan sayfasında inceleyin.'},
    {icon:'choice',title:'Geniş Seçenek',description:'Türkiye geneli ve dünyaya açılan kapsamlı ürün portföyümüz.'}
  ];
  function scopeOptions(){var slug=document.getElementById('cms-slug')?.value||new URLSearchParams(location.search).get('slug')||'';return slug==='home'||slug==='home-global'?sectionOptions.home:sectionOptions.category;}
  var catalog = [], filterGroups = [], campaigns = [];
  var categories = {hotel:'Otel',holiday_home:'Tatil Evi',yacht:'Yat',tour:'Tur',activity:'Aktivite',flight:'Uçuş',car:'Araç',cruise:'Kruvaziyer',pilgrimage:'Hac & Umre',visa:'Vize',ferry:'Feribot',transfer:'Transfer',beach:'Şezlong',cinema:'Sinema',event:'Etkinlik',restaurant:'Restoran',bus:'Otobüs'};
  function field(parent,label,node){var wrap=document.createElement('label');wrap.className='builder-collection-field';var name=document.createElement('span');name.textContent=label;wrap.appendChild(name);wrap.appendChild(node);parent.appendChild(wrap);return node;}
  function selectField(parent,label,values,current,change){var select=document.createElement('select');values.forEach(function(entry){var option=document.createElement('option');option.value=entry[0];option.textContent=entry[1];select.appendChild(option);});select.value=current||values[0][0];select.onchange=function(){change(select.value);};return field(parent,label,select);}
  function multiField(parent,label,values,selected,change){var wrap=document.createElement('fieldset');wrap.className='builder-collection-options';var legend=document.createElement('legend');legend.textContent=label;wrap.appendChild(legend);values.forEach(function(entry){var row=document.createElement('label');var check=document.createElement('input');check.type='checkbox';check.value=entry[0];check.checked=selected.indexOf(entry[0])>=0;check.onchange=function(){change(Array.prototype.slice.call(wrap.querySelectorAll('input:checked')).map(function(input){return input.value;}));};row.appendChild(check);row.appendChild(document.createTextNode(entry[1]));wrap.appendChild(row);});if(!values.length){var note=document.createElement('small');note.textContent='Bu kategoride henüz seçenek yok.';wrap.appendChild(note);}parent.appendChild(wrap);}
  function collectionEditor(card,block){
    var settings=document.createElement('div');settings.className='builder-collection-settings';
    selectField(settings,'Kategori',Object.keys(categories).map(function(key){return [key,categories[key]];}),block.category||'holiday_home',function(value){block.category=value;block.values=[];block.listingIds=[];syncBuilder();});
    selectField(settings,'Listeleme tipi',[['region','Bölgeye göre'],['theme','Temaya göre'],['type','Tipe göre'],['budget','Bütçeye göre'],['campaign','Kampanyaya göre']],block.mode||'region',function(value){block.mode=value;block.values=[];syncBuilder();});
    var items=catalog.filter(function(item){return item.category===(block.category||'holiday_home');});
    var mode=block.mode||'region';
    if(mode==='region'){
      var regions=Array.from(new Set(items.map(function(item){return String(item.locality||'').split(',').pop().trim();}).filter(Boolean))).sort();
      multiField(settings,'Gösterilecek bölgeler',regions.map(function(value){return [value,value];}),block.values||[],function(values){block.values=values;syncValue();});
    } else if(mode==='theme'){
      var themes=filterGroups.filter(function(group){return group.category===(block.category||'holiday_home')&&group.key==='theme'&&group.active!==false;}).flatMap(function(group){return group.items||[];}).filter(function(item){return item.active!==false;});
      multiField(settings,'Gösterilecek temalar',themes.map(function(item){return [item.contractValue||item.key,item.title];}),block.values||[],function(values){block.values=values;syncValue();});
    } else if(mode==='type'){
      var types=Array.from(new Set(items.map(function(item){return item.propertyType;}).filter(Boolean))).sort();
      multiField(settings,'Gösterilecek tipler',types.map(function(value){return [value,value];}),block.values||[],function(values){block.values=values;syncValue();});
    } else if(mode==='budget'){
      var currencies=Array.from(new Set(items.map(function(item){return item.currency;}).filter(Boolean))).sort();
      selectField(settings,'Para birimi',currencies.length?currencies.map(function(value){return [value,value];}):[['TRY','TRY']],block.currency||currencies[0]||'TRY',function(value){block.currency=value;syncValue();});
      [['minPrice','En düşük fiyat'],['maxPrice','En yüksek fiyat']].forEach(function(pair){var input=document.createElement('input');input.type='number';input.min='0';input.value=block[pair[0]]||'';input.oninput=function(){block[pair[0]]=input.value;syncValue();};field(settings,pair[1],input);});
    } else {
      selectField(settings,'Kampanya',[['','Kampanya seçin']].concat(campaigns.map(function(item){return [item.id,item.name+' ('+item.status+')'];})),block.campaignId||'',function(value){block.campaignId=value;syncValue();});
      multiField(settings,'Kampanyada gösterilecek ilanlar',items.map(function(item){return [String(item.id),item.title];}),block.listingIds||[],function(values){block.listingIds=values;syncValue();});
    }
    var limit=document.createElement('input');limit.type='number';limit.min='1';limit.max='24';limit.value=block.limit||8;limit.oninput=function(){block.limit=limit.value;syncValue();};field(settings,'En fazla ilan',limit);
    card.appendChild(settings);
  }
  function sourceEditor(card,block){
    var settings=document.createElement('div');settings.className='builder-collection-settings';
    var options=scopeOptions();
    selectField(settings,'Sayfadaki bölüm',options,block.sectionKey||options[0][0],function(value){block.sectionKey=value;syncBuilder();});
    var toggle=document.createElement('input');toggle.type='checkbox';toggle.checked=block.enabled!==false;toggle.onchange=function(){block.enabled=toggle.checked;syncValue();};field(settings,'Yayında göster',toggle);
    var description=document.createElement('input');description.placeholder='Boş bırakılırsa mevcut açıklama kullanılır';description.value=block.description||'';description.oninput=function(){block.description=description.value;syncValue();};field(settings,'Alt açıklama (isteğe bağlı)',description);
    if(block.sectionKey==='hero'){
      if(!Array.isArray(block.images))block.images=['','',''];
      ['Üst sol görsel URL’si','Alt sol görsel URL’si','Sağ uzun görsel URL’si'].forEach(function(label,index){
        var image=document.createElement('input');image.type='text';image.placeholder='Boş bırakılırsa mevcut fotoğraf kullanılır';image.value=block.images[index]||'';
        image.oninput=function(){block.images[index]=image.value.trim();syncValue();};field(settings,label,image);
      });
    }
    card.appendChild(settings);
    if(block.sectionKey==='benefits') benefitsEditor(card,block);
  }
  function benefitsEditor(card,block){
    if(!Array.isArray(block.items)) block.items=JSON.parse(JSON.stringify(benefitDefaults));
    var editor=document.createElement('div');editor.className='builder-benefits-editor';
    var heading=document.createElement('strong');heading.textContent='Avantaj kartları';editor.appendChild(heading);
    block.items.forEach(function(item,index){
      var row=document.createElement('div');row.className='builder-benefit-item';
      var tools=document.createElement('div');tools.className='builder-benefit-item-head';
      var label=document.createElement('strong');label.textContent=(index+1)+'. '+(item.title||'Yeni kart');tools.appendChild(label);
      [['↑','Yukarı taşı',-1],['↓','Aşağı taşı',1]].forEach(function(action){var button=document.createElement('button');button.type='button';button.textContent=action[0];button.title=action[1];button.disabled=(action[2]<0&&index===0)||(action[2]>0&&index===block.items.length-1);button.onclick=function(){var moved=block.items.splice(index,1)[0];block.items.splice(index+action[2],0,moved);syncBuilder();};tools.appendChild(button);});
      var remove=document.createElement('button');remove.type='button';remove.textContent='Sil';remove.onclick=function(){block.items.splice(index,1);syncBuilder();};tools.appendChild(remove);row.appendChild(tools);
      selectField(row,'Simge',benefitIcons,item.icon||'secure',function(value){item.icon=value;syncValue();});
      var title=document.createElement('input');title.value=item.title||'';title.oninput=function(){item.title=title.value;label.textContent=(index+1)+'. '+(title.value||'Yeni kart');syncValue();};field(row,'Başlık',title);
      var description=document.createElement('textarea');description.rows=2;description.value=item.description||'';description.oninput=function(){item.description=description.value;syncValue();};field(row,'Açıklama',description);
      editor.appendChild(row);
    });
    var add=document.createElement('button');add.type='button';add.className='builder-benefit-add';add.textContent='+ Yeni avantaj kartı';add.onclick=function(){block.items.push({icon:'secure',title:'Yeni avantaj',description:''});syncBuilder();};editor.appendChild(add);
    card.appendChild(editor);
  }
  function regionPlacesEditor(card,block){
    var settings=document.createElement('div');settings.className='builder-collection-settings';
    var note=document.createElement('p');note.className='builder-module-note';note.textContent='Yayındaki Gezilesi Yerler blog yazıları bu bölümde gösterilir. Blog yazılarına bölge slugı ve kapak görseli ekleyin.';settings.appendChild(note);
    var region=document.createElement('input');region.placeholder='Boş bırakılırsa tüm bölgeler';region.value=block.regionSlug||'';region.oninput=function(){block.regionSlug=region.value.trim();syncValue();};field(settings,'Bölge slugı (isteğe bağlı)',region);
    var image=document.createElement('input');image.type='text';image.placeholder='Boş bırakılırsa yazının kapak görseli';image.value=block.imageUrl||'';image.oninput=function(){block.imageUrl=image.value;syncValue();};field(settings,'Büyük görsel URL’si',image);
    var limit=document.createElement('input');limit.type='number';limit.min='1';limit.max='6';limit.value=block.limit||3;limit.oninput=function(){block.limit=Math.max(1,Math.min(6,Number(limit.value)||3));syncValue();};field(settings,'Gösterilecek yazı',limit);
    card.appendChild(settings);
  }
  function textField(parent,label,value,change,multiline){var input=document.createElement(multiline?'textarea':'input');if(multiline)input.rows=3;input.value=value||'';input.oninput=function(){change(input.value);syncValue();};field(parent,label,input);return input;}
  function commonModuleEditor(card,block){
    var settings=document.createElement('div');settings.className='builder-collection-settings';
    textField(settings,'Açıklama',block.body,function(value){block.body=value;},true);
    if(['hero','cta','rich_text'].indexOf(block.type)>=0){textField(settings,'Buton yazısı',block.button_text,function(value){block.button_text=value;});textField(settings,'Buton bağlantısı',block.button_url,function(value){block.button_url=value;});}
    if(['hero','cta'].indexOf(block.type)>=0)textField(settings,'Görsel URL’si',block.imageUrl,function(value){block.imageUrl=value;});
    if(['featured_listings','listing_grid','filter_bar'].indexOf(block.type)>=0){
      selectField(settings,'İlan kategorisi',[['','Sayfanın kategorisi / tümü']].concat(Object.keys(categories).map(function(key){return [key,categories[key]];})),block.category||'',function(value){block.category=value;syncValue();});
      if(block.type!=='filter_bar'){var limit=document.createElement('input');limit.type='number';limit.min='1';limit.max='24';limit.value=block.limit||8;limit.oninput=function(){block.limit=Number(limit.value)||8;syncValue();};field(settings,'İlan sayısı',limit);}
    }
    if(block.type==='category_grid')multiField(settings,'Gösterilecek kategoriler',Object.keys(categories).map(function(key){return [key,categories[key]];}),block.values||[],function(values){block.values=values;syncValue();});
    card.appendChild(settings);
    if(block.type==='benefit_cards'){benefitsEditor(card,block);return;}
    var itemTypes=['trust_strip','image_gallery','video_gallery','faq','testimonials','destination_grid','how_it_works','stay_types','blog_cards'];
    if(itemTypes.indexOf(block.type)<0)return;
    if(!Array.isArray(block.items))block.items=[];
    var editor=document.createElement('div');editor.className='builder-benefits-editor';
    var heading=document.createElement('strong');heading.textContent='Modül öğeleri';editor.appendChild(heading);
    block.items.forEach(function(item,index){
      var row=document.createElement('div');row.className='builder-benefit-item';
      var head=document.createElement('div');head.className='builder-benefit-item-head';
      var name=document.createElement('strong');name.textContent=(index+1)+'. '+(item.title||'Yeni öğe');head.appendChild(name);
      var remove=document.createElement('button');remove.type='button';remove.textContent='Sil';remove.onclick=function(){block.items.splice(index,1);syncBuilder();};head.appendChild(remove);row.appendChild(head);
      textField(row,block.type==='faq'?'Soru':'Başlık',item.title,function(value){item.title=value;name.textContent=(index+1)+'. '+(value||'Yeni öğe');});
      textField(row,block.type==='faq'?'Yanıt':'Açıklama',item.description,function(value){item.description=value;},true);
      if(['image_gallery','video_gallery','testimonials','destination_grid','how_it_works','stay_types','blog_cards'].indexOf(block.type)>=0)textField(row,'Görsel URL’si',item.imageUrl,function(value){item.imageUrl=value;});
      if(['destination_grid','how_it_works','stay_types','blog_cards'].indexOf(block.type)>=0)textField(row,'Bağlantı',item.url,function(value){item.url=value;});
      if(block.type==='video_gallery')textField(row,'Video bağlantısı',item.url,function(value){item.url=value;});
      editor.appendChild(row);
    });
    var add=document.createElement('button');add.type='button';add.className='builder-benefit-add';add.textContent='+ Öğesi ekle';add.onclick=function(){block.items.push({title:'Yeni öğe',description:'',imageUrl:'',url:''});syncBuilder();};editor.appendChild(add);card.appendChild(editor);
  }
  function syncBuilder(){
    if(!builderList) return;
    builderList.textContent='';
    blocks.forEach(function(block,index){
      var card=document.createElement('div'); card.className='page-builder-block'; card.draggable=true; card.dataset.index=index;
      card.ondragstart=function(e){e.dataTransfer.setData('text/plain',String(index));};
      card.ondragover=function(e){e.preventDefault();};
      card.ondrop=function(e){e.preventDefault();var from=Number(e.dataTransfer.getData('text/plain'));if(from!==index){var x=blocks.splice(from,1)[0];blocks.splice(index,0,x);syncBuilder();}};
      var head=document.createElement('div'); head.className='page-builder-block-head';
      var title=document.createElement('strong'); title.textContent=(index+1)+'. '+(block.type==='source_section'?(scopeOptions().find(function(option){return option[0]===block.sectionKey;})||[])[1]||'Sayfa bölümü':labels[block.type]||block.type); head.appendChild(title);
      var actions=document.createElement('span');
      var up=document.createElement('button'); up.type='button'; up.textContent='↑'; up.title='Yukarı taşı'; up.onclick=function(){if(index){var x=blocks.splice(index,1)[0];blocks.splice(index-1,0,x);syncBuilder();}};
      var down=document.createElement('button'); down.type='button'; down.textContent='↓'; down.title='Aşağı taşı'; down.onclick=function(){if(index<blocks.length-1){var x=blocks.splice(index,1)[0];blocks.splice(index+1,0,x);syncBuilder();}};
      var del=document.createElement('button'); del.type='button'; del.textContent='Sil'; del.onclick=function(){blocks.splice(index,1);syncBuilder();};
      var dup=document.createElement('button'); dup.type='button'; dup.textContent='Çoğalt'; dup.onclick=function(){blocks.splice(index+1,0,JSON.parse(JSON.stringify(block)));syncBuilder();};
      actions.appendChild(up);actions.appendChild(down);actions.appendChild(dup);actions.appendChild(del);head.appendChild(actions);card.appendChild(head);
      var input=document.createElement('input'); input.placeholder='Modül başlığı veya kısa içerik'; input.value=block.title||''; input.oninput=function(){block.title=input.value;syncValue();}; card.appendChild(input);
      if(block.type==='listing_collection') collectionEditor(card,block);
      if(block.type==='source_section') sourceEditor(card,block);
      if(block.type==='region_places') regionPlacesEditor(card,block);
      if(block.type!=='source_section'&&block.type!=='region_places'&&block.type!=='listing_collection')commonModuleEditor(card,block);
      builderList.appendChild(card);
    }); syncValue();
    if(builderPreview) builderPreview.textContent=blocks.length ? blocks.length+' modül hazır — yayınlamadan önce önizleyebilirsiniz.' : 'Henüz modül eklenmedi.';
  }
  function syncValue(){if(builderJson) builderJson.value=JSON.stringify(blocks);}
  if(builderAdd) builderAdd.onclick=function(){var type=builderType.value;blocks.push(type==='source_section'?{type:'source_section',sectionKey:scopeOptions()[0][0],enabled:true,title:''}:type==='region_places'?{type:'region_places',title:'Gezilesi Yerler',blogCategory:'gezilesi-yerler',regionSlug:'',imageUrl:'',limit:3}:type==='listing_collection'?{type:type,title:'',category:'holiday_home',mode:'region',values:[],listingIds:[],limit:8}:{type:type,title:'',body:'',category:'',values:[],items:[],limit:8});syncBuilder();};
  syncBuilder();
  Promise.all([
    fetch('/api/public/listings',{credentials:'same-origin'}).then(function(r){return r.ok?r.json():[]}).catch(function(){return []}),
    fetch('/admin/categories/filter-data',{credentials:'same-origin'}).then(function(r){return r.ok?r.json():[]}).catch(function(){return []}),
    fetch('/admin/campaigns/data',{credentials:'same-origin'}).then(function(r){return r.ok?r.json():{campaigns:[]}}).catch(function(){return {campaigns:[]}})
  ]).then(function(data){catalog=Array.isArray(data[0])?data[0]:[];filterGroups=Array.isArray(data[1])?data[1]:[];campaigns=data[2].campaigns||[];syncBuilder();});
  var slugInput=document.getElementById('cms-slug');
  var requestedSlug=new URLSearchParams(window.location.search).get('slug');
  var cmsForm=builderList && builderList.closest('form');
  var saveButton=cmsForm && cmsForm.querySelector('button[type=submit]');
  if(requestedSlug && saveButton) saveButton.disabled=true;
  if(requestedSlug && slugInput){slugInput.value=requestedSlug;fetch('/admin/cms/blocks?slug='+encodeURIComponent(requestedSlug),{credentials:'same-origin',cache:'no-store'}).then(function(r){return r.ok?r.json():[]}).then(function(rows){blocks=(rows||[]).map(function(row){var c={};try{c=JSON.parse(row.content||'{}')}catch(e){}if(c.content&&typeof c.content==='object')c=Object.assign({},c.content,c);delete c.content;c.type=row.type;return c;});syncBuilder();}).catch(function(){});}

  var table = document.getElementById('cms-table-body');
  if (!table) return;

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }

  fetch('/admin/cms/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('CMS sayfaları yüklenemedi');
      return response.json();
    })
    .then(function (pages) {
      if(requestedSlug && cmsForm){
        var current=pages.find(function(page){return page.slug===requestedSlug;});
        if(current){
          var seo={};try{seo=JSON.parse(current.seo||'{}')}catch(e){}
          cmsForm.elements.template.value=current.template||'standard';
          cmsForm.elements.status.value=current.status||'draft';
          cmsForm.elements.seo_title.value=current.seoTitle||'';
          cmsForm.elements.seo_description.value=seo.description||'';
          cmsForm.elements.seo_keywords.value=seo.keywords||'';
          cmsForm.elements.blog_category.value=seo.blog_category||'';
          cmsForm.elements.region_slug.value=seo.region_slug||'';
          cmsForm.elements.cover_image.value=seo.cover_image||'';
          var scope=cmsForm.elements.category_scope;
          if(scope) scope.value=seo.category_scope||'global';
        }
        if(saveButton) saveButton.disabled=false;
      }
      table.textContent = '';
      if (!pages.length) {
        var empty = document.createElement('tr');
        var message = document.createElement('td');
        message.colSpan = 5;
        message.className = 'empty-state';
        message.textContent = 'Henüz CMS sayfası yok.';
        empty.appendChild(message);
        table.appendChild(empty);
        return;
      }
      pages.forEach(function (page) {
        var row = document.createElement('tr');
        row.appendChild(cell(page.slug));
        row.appendChild(cell(page.template));
        row.appendChild(cell(page.status));
        row.appendChild(cell(page.seoTitle));
        row.appendChild(cell(page.publishedAt));
        var actions=document.createElement('td'); var edit=document.createElement('a'); edit.href='/admin/cms?slug='+encodeURIComponent(page.slug)+'#page-builder'; edit.className='btn-table-new'; edit.textContent='Düzenle'; actions.appendChild(edit); row.appendChild(actions);
        table.appendChild(row);
      });
    })
    .catch(function (error) {
      table.textContent = '';
      var row = document.createElement('tr');
      var message = document.createElement('td');
      message.colSpan = 5;
      message.className = 'empty-state error';
      message.textContent = error.message;
      row.appendChild(message);
      table.appendChild(row);
    });
})();
