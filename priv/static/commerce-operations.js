(() => {
  'use strict';
  const esc = x => String(x ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' })[c]);
  const stamp = x => x ? new Intl.DateTimeFormat('tr', { dateStyle:'short', timeStyle:'short' }).format(new Date(x)) : 'Henüz çalışmadı';
  const status = document.getElementById('operations-status');
  document.querySelector('.operations').insertAdjacentHTML('beforeend','<section class="op-card"><h2>Yapay zekâ ile ilan kalite incelemesi</h2><p>İlanın kayıtlı içeriğindeki eksik açıklamaları ve çelişkili iddiaları kaynak alıntılarıyla inceleyin. Öneriler ilanı, fiyatı veya yayın durumunu otomatik değiştirmez.</p><form id="listing-quality"><label>İlan<select name="listing_id" id="quality-listing" required></select></label><button>İçeriği incele</button></form><div id="quality-result" aria-live="polite"></div><p class="hint">Üretilen sonuçların kaynakta olmayan alıntıları kabul edilmez. Gerçekler ve öneriler insan tarafından kontrol edilmelidir. <a href="/admin/ai">Yapay zekâ bağlantıları ve diğer araçlar</a></p></section>');
  const stateNames = { awaiting_credentials:'Bağlantı bilgileri bekleniyor', configured:'Ayarlar kayıtlı; gerçek işlem kontrolü gerekli', disabled:'Kapalı', test:'Test', live:'Canlı', pending:'Bekliyor', sending:'İşleniyor', sent:'Teslim edildi', failed:'Başarısız' };
  const name = x => stateNames[x] || x || 'Yapılandırılmadı';
  async function post(action, values, base = '/admin/commerce-operations/') {
    values.set('csrf', document.querySelector('meta[name="csrf-token"]').content);
    const r = await fetch(base + action, { method:'POST', credentials:'same-origin', body:values });
    if (!r.ok) {let message='İşlem tamamlanamadı. Bağlantıyı ve yetkinizi kontrol edin.';try{message=(await r.json()).error||message;}catch{}throw new Error(message);}
    return r.json();
  }
  async function refresh() {
    const r = await fetch('/admin/commerce-operations/data', { credentials:'same-origin', cache:'no-store' });
    if (!r.ok) throw new Error('Operasyon bilgileri alınamadı.');
    const d = await r.json(), f = d.finance || {};
    const local = d.listings.filter(x => x.source !== 'nexus' && ['holiday_home','yacht'].includes(x.category));
    const qualitySelect=document.getElementById('quality-listing'),qualitySelected=qualitySelect.value;
    qualitySelect.innerHTML=d.listings.map(x=>`<option value="${esc(x.id)}">${esc(x.title)}</option>`).join('');
    if(d.listings.some(x=>x.id===qualitySelected))qualitySelect.value=qualitySelected;
    for (const id of ['calendar-listing','calendar-export-listing']) {
      const el = document.getElementById(id), selected = el.value;
      el.innerHTML = local.map(x => `<option value="${esc(x.id)}">${esc(x.title)}</option>`).join('');
      if (local.some(x => x.id === selected)) el.value = selected;
    }
    document.getElementById('operations-readiness').innerHTML = `<div class="op-grid"><div class="op-stat">Ödeme<strong>${esc(f.paymentProvider || 'ParamPOS')}</strong>${esc(name(f.paymentStatus))}<p><a href="/admin/integrations">Bağlantıyı düzenle</a></p></div><div class="op-stat">E-belge<strong>${esc(f.documentProvider || 'QNB eSolutions')}</strong>${esc(name(f.documentStatus))}<p><a href="/admin/finance-overview">Finans işlemleri</a></p></div><div class="op-stat">Aktif dış takvim<strong>${d.feeds.filter(x => x.active).length}</strong>${d.feeds.filter(x => x.active && x.error).length} bağlantıda hata</div><div class="op-stat">Takvim çakışması<strong>${d.conflicts.length}</strong>Mevcut rezervasyonları inceleyin</div></div>`;
    document.getElementById('calendar-feeds').innerHTML = d.feeds.length ? d.feeds.map(x => `<article class="op-row"><div><strong>${esc(x.listing)} · ${esc(x.label)}</strong><p>${esc(x.host)} · ${esc(x.timezone)} · ${x.events} etkinlik</p><p>Son başarılı çalışma: ${esc(stamp(x.lastSync))}</p>${x.error ? `<p class="op-error">${esc(x.error)}</p>` : ''}</div><span class="op-badge">${x.active ? (x.working ? 'İşleniyor' : 'Etkin') : 'Kaldırıldı'}</span>${x.active ? `<div class="op-actions"><button data-action="calendar-sync" data-feed="${esc(x.id)}">Güncellemeyi sıraya al</button><button class="secondary" data-action="calendar-remove" data-feed="${esc(x.id)}">Bağlantı bloklarını kaldır</button></div>` : ''}</article>`).join('') : '<p>Henüz takvim bağlantısı yok.</p>';
    document.getElementById('calendar-conflicts').innerHTML = d.conflicts.length ? d.conflicts.map(x => `<p class="op-error">${esc(x.reference)} · ${esc(x.listing)} · ${esc(x.arrival)} — ${esc(x.departure)}</p>`).join('') : '<p>Gözlenen takvim çakışması yok.</p>';
    document.getElementById('operations-channels').innerHTML = `<p>NEXUS rezervasyon teslimleri: ${esc(Object.entries(d.nexusQueue).map(([k,v]) => `${name(k)}: ${v}`).join(' · ') || 'Kayıt yok')}</p><p>Yerel dağıtım kuyruğu: ${esc(Object.entries(d.channelQueue).map(([k,v]) => `${name(k)}: ${v}`).join(' · '))}</p>` + (d.channels.length ? d.channels.map(x => `<div class="op-row"><strong>${esc(x.name)}</strong><span>${esc(name(x.mode))}</span><span>${esc(stamp(x.lastSync))}</span></div>`).join('') : '<p>Tanımlı dağıtım kanalı yok. NEXUS bağlantısı <a href="/admin/integrations">bağlantı ayarlarından</a> yönetilir.</p>');
    document.getElementById('operations-languages').innerHTML = '<h3>Dile özel SEO alanları</h3><div class="op-grid">' + d.languages.map(x => `<div class="op-stat">${esc(x.language.toUpperCase())}<strong>${x.filled} / ${x.profiles}</strong>Başlık ve açıklama girilmiş profil</div>`).join('') + '</div><p>Kaynak veya çeviri geri dönüşü bu sayıya dahil değildir. <a href="/admin/seo">Dil içeriklerini düzenle</a></p>';
    document.getElementById('operations-categories').innerHTML = '<h3>Kategori yayını</h3>' + d.categories.map(x => `<div class="op-row"><strong>${esc(x.code)}</strong><span>${x.published} yayımlanmış ilan</span>${x.connectedInquiryOnly ? `<span class="op-badge">${x.connectedInquiryOnly} bağlı ilan teklif ile ilerler</span>` : ''}</div>`).join('');
    document.getElementById('operations-metrics').innerHTML = d.metrics.length ? '<div class="op-grid">' + d.metrics.map(x => `<div class="op-stat">${esc(x.currency)}<strong>${esc(new Intl.NumberFormat('tr', { style:'currency',currency:x.currency }).format(Number(x.paidRevenueMinor)/100))}</strong>${x.bookings} rezervasyon · ${x.cancelled} iptal</div>`).join('') + '</div>' : '<p>Son 30 günde rezervasyon yok.</p>';
  }
  document.getElementById('calendar-save').addEventListener('submit', async e => {
    e.preventDefault(); const button=e.target.querySelector('button');button.disabled=true;
    try { await post('calendar-save',new URLSearchParams(new FormData(e.target)));status.textContent='Takvim bağlantısı kaydedildi; güncelleme sıraya alındı.';await refresh(); }
    catch(err){status.textContent=err.message;}finally{button.disabled=false;}
  });
  document.getElementById('calendar-export').addEventListener('submit',async e => {
    e.preventDefault();const button=e.target.querySelector('button');button.disabled=true;
    try {const d=await post('calendar-export',new URLSearchParams(new FormData(e.target)));const url=new URL(d.path,location.origin).href;
      document.getElementById('calendar-export-result').innerHTML=`<label>Gizli takvim bağlantısı<input readonly value="${esc(url)}" aria-label="Gizli takvim bağlantısı"></label><p>Bu bağlantıyı takvimi okuyacak sisteme ekleyin. Lokal adres yalnız yerel ağdan erişilebilir.</p>`;
    }catch(err){status.textContent=err.message;}finally{button.disabled=false;}
  });
  document.getElementById('calendar-feeds').addEventListener('click',async e => {
    const b=e.target.closest('[data-action]');if(!b)return;
    if(b.dataset.action==='calendar-remove'&&!confirm('Bu bağlantının blokları kalkacak. Diğer bloklar ve yerel stok korunur. Devam edilsin mi?'))return;
    b.disabled=true;try{const result=await post(b.dataset.action,new URLSearchParams({feed_id:b.dataset.feed}));if(!result.changed)throw new Error('Bağlantı bulunamadı.');status.textContent='İşlem kaydedildi.';await refresh();}catch(err){status.textContent=err.message;b.disabled=false;}
  });
  document.getElementById('operations-refresh').addEventListener('click',()=>refresh().catch(e=>status.textContent=e.message));
  document.getElementById('listing-quality').addEventListener('submit',async e=>{
    e.preventDefault();const button=e.target.querySelector('button'),result=document.getElementById('quality-result');button.disabled=true;result.textContent='Kayıtlı kaynak içerik inceleniyor…';
    try{const d=await post('listing-quality',new URLSearchParams(new FormData(e.target)),'/admin/ai/');const review=JSON.parse(d.review);
      result.innerHTML=`<p>${esc(review.summary)}</p>`+review.findings.map(x=>`<article class="op-row"><div><strong>${esc(x.field)}</strong>${x.evidence?`<blockquote>${esc(x.evidence)}</blockquote>`:''}<p>${esc(x.suggestion)}</p><small>İnsan incelemesi gerekli</small></div></article>`).join('');
    }catch(err){result.textContent=err.message;}finally{button.disabled=false;}
  });
  refresh().catch(e=>status.textContent=e.message);
})();
