(function () {
  var builderList = document.getElementById('page-builder-list');
  var builderType = document.getElementById('page-builder-type');
  var builderAdd = document.getElementById('page-builder-add');
  var builderJson = document.getElementById('page-builder-json');
  var builderPreview = document.getElementById('page-builder-preview');
  var blocks = [];
  var labels = {hero:'Hero / Arama',featured_listings:'Öne çıkan ilanlar',category_grid:'Kategori kartları',trust_strip:'Güven şeridi',rich_text:'Zengin metin',newsletter:'Bülten kayıt'};
  function syncBuilder(){
    if(!builderList) return;
    builderList.textContent='';
    blocks.forEach(function(block,index){
      var card=document.createElement('div'); card.className='page-builder-block'; card.draggable=true; card.dataset.index=index;
      var head=document.createElement('div'); head.className='page-builder-block-head';
      var title=document.createElement('strong'); title.textContent=(index+1)+'. '+(labels[block.type]||block.type); head.appendChild(title);
      var actions=document.createElement('span');
      var up=document.createElement('button'); up.type='button'; up.textContent='↑'; up.title='Yukarı taşı'; up.onclick=function(){if(index){var x=blocks.splice(index,1)[0];blocks.splice(index-1,0,x);syncBuilder();}};
      var down=document.createElement('button'); down.type='button'; down.textContent='↓'; down.title='Aşağı taşı'; down.onclick=function(){if(index<blocks.length-1){var x=blocks.splice(index,1)[0];blocks.splice(index+1,0,x);syncBuilder();}};
      var del=document.createElement('button'); del.type='button'; del.textContent='Sil'; del.onclick=function(){blocks.splice(index,1);syncBuilder();};
      actions.appendChild(up);actions.appendChild(down);actions.appendChild(del);head.appendChild(actions);card.appendChild(head);
      var input=document.createElement('input'); input.placeholder='Modül başlığı veya kısa içerik'; input.value=block.title||''; input.oninput=function(){block.title=input.value;syncValue();}; card.appendChild(input);
      builderList.appendChild(card);
    }); syncValue();
    if(builderPreview) builderPreview.textContent=blocks.length ? blocks.length+' modül hazır — yayınlamadan önce önizleyebilirsiniz.' : 'Henüz modül eklenmedi.';
  }
  function syncValue(){if(builderJson) builderJson.value=JSON.stringify(blocks);}
  if(builderAdd) builderAdd.onclick=function(){blocks.push({type:builderType.value,title:''});syncBuilder();};
  syncBuilder();
  var slugInput=document.getElementById('cms-slug');
  var requestedSlug=new URLSearchParams(window.location.search).get('slug');
  if(requestedSlug && slugInput){slugInput.value=requestedSlug;fetch('/admin/cms/blocks?slug='+encodeURIComponent(requestedSlug),{credentials:'same-origin',cache:'no-store'}).then(function(r){return r.ok?r.json():[]}).then(function(rows){blocks=(rows||[]).map(function(row){var c={};try{c=JSON.parse(row.content||'{}')}catch(e){}return {type:row.type,title:c.title||'',content:c};});syncBuilder();}).catch(function(){});}

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
