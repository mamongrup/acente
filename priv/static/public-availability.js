(() => {
  const box = document.getElementById('public-availability');
  if (!box) return;
  const form = document.getElementById('booking-form');
  const startInput = form?.querySelector('[name="check_in"]');
  const endInput = form?.querySelector('[name="check_out"]');
  const today = new Date(); today.setHours(0, 0, 0, 0);
  let month = new Date(today.getFullYear(), today.getMonth(), 1);
  let availability = new Map();
  let status = 'Müsaitlik bilgisi yükleniyor…';
  let availabilityStatus = status;
  const iso = date => [date.getFullYear(), String(date.getMonth() + 1).padStart(2, '0'), String(date.getDate()).padStart(2, '0')].join('-');
  const preview=['127.0.0.1','localhost'].includes(location.hostname) && (new URLSearchParams(location.search).has('preview') || location.pathname==='/tatil-evi/bodrum-yalikavak-panoramik-deniz-manzarali-luks-balayi-villasi' || location.pathname==='/yat/gocek-koylari-26m-luks-gulet-murettebatli-mavi-yolculuk');
  const closed=entry=>!!(entry && (entry.closed || Number(entry.available)<=0));
  function validRange(from,to){
    for(let day=new Date(from+'T00:00:00');day<to;day.setDate(day.getDate()+1))if(closed(availability.get(iso(day))))return false;
    return true;
  }
  function summaryPopup(){
    if(!startInput?.value || !endInput?.value)return;
    document.querySelector('.reservation-summary-dialog')?.remove();
    const dialog=document.createElement('dialog');dialog.className='reservation-summary-dialog';
    const heading=document.createElement('h2');heading.textContent='Rezervasyon özeti';
    const dates=document.createElement('p');const locale=window.NEXUS_LOCALE?.lang || 'tr';const format=value=>new Date(value+'T00:00:00').toLocaleDateString(locale,{day:'numeric',month:'short',year:'numeric'});dates.textContent=format(startInput.value)+' — '+format(endInput.value);
    const totals=document.createElement('div');totals.className='reservation-summary-totals';
    document.querySelectorAll('.reference-booking-summary>div').forEach(row=>totals.append(row.cloneNode(true)));
    const note=document.createElement('p');note.textContent='Hasar depozitosu, tatil evine girişte nakit olarak ödenir.';
    const pay=document.createElement('button');pay.type='button';pay.textContent='Ödemeye geç';pay.className='reservation-summary-pay';
    pay.onclick=()=>{dialog.close();form.requestSubmit();};
    const close=document.createElement('button');close.type='button';close.textContent='Kapat';close.onclick=()=>dialog.close();
    const returnFocus=document.activeElement;
    dialog.append(heading,dates,totals,note,pay,close);document.body.append(dialog);dialog.showModal();close.focus({preventScroll:true});
    dialog.addEventListener('click',event=>{if(event.target===dialog){const rect=dialog.getBoundingClientRect();if(event.clientX<rect.left || event.clientX>rect.right || event.clientY<rect.top || event.clientY>rect.bottom)dialog.close();}});
    dialog.addEventListener('close',()=>{returnFocus?.isConnected && returnFocus.focus({preventScroll:true});});
    dialog.addEventListener('close',()=>dialog.remove());
  }
  function select(date) {
    if (!startInput || !endInput) return;
    const value = iso(date);
    status = availabilityStatus;
    if (!startInput.value || endInput.value || value <= startInput.value) {
      startInput.value = value; endInput.value = '';
    } else {
      // Known closed dates must not be crossed; unknown dates require a quote.
      for (let day = new Date(startInput.value + 'T00:00:00'); day < date; day.setDate(day.getDate() + 1)) {
        const entry = availability.get(iso(day));
        if (entry && (entry.closed || Number(entry.available) <= 0)) {
          status = 'Seçilen aralıkta uygun olmayan gün var. Başka bir tarih seçin.';
          render(); return;
        }
      }
      endInput.value = value;
    }
    startInput.dispatchEvent(new Event('change', { bubbles: true }));
    render();
    if(endInput.value)summaryPopup();
  }
  function render() {
    box.replaceChildren();
    const toolbar = document.createElement('div'); toolbar.className = 'detail-calendar-toolbar';
    const prev = document.createElement('button'); prev.type = 'button'; prev.textContent = '‹'; prev.setAttribute('aria-label', 'Önceki ay');
    prev.disabled = month <= new Date(today.getFullYear(), today.getMonth(), 1);
    prev.onclick = () => { month = new Date(month.getFullYear(), month.getMonth() - 1, 1); render(); };
    const next = document.createElement('button'); next.type = 'button'; next.textContent = '›'; next.setAttribute('aria-label', 'Sonraki ay');
    next.onclick = () => { month = new Date(month.getFullYear(), month.getMonth() + 1, 1); render(); };
    toolbar.append(prev, next); box.appendChild(toolbar);
    const months = document.createElement('div'); months.className = 'detail-calendar-months';
    for (let offset = 0; offset < 2; offset++) {
      const first = new Date(month.getFullYear(), month.getMonth() + offset, 1);
      const panel = document.createElement('div'); panel.className = 'detail-calendar-month';
      const heading = document.createElement('h3'); heading.textContent = first.toLocaleDateString(window.NEXUS_LOCALE?.lang || 'tr-TR', { month: 'long', year: 'numeric' }); panel.appendChild(heading);
      const grid = document.createElement('div'); grid.className = 'detail-calendar-grid';
      Array.from({length:7},(_,i)=>new Date(2026,0,5+i).toLocaleDateString(window.NEXUS_LOCALE?.lang || 'tr-TR',{weekday:'short'})).forEach(name => { const label = document.createElement('span'); label.textContent = name; grid.appendChild(label); });
      for (let i = 0; i < (first.getDay() + 6) % 7; i++) grid.appendChild(document.createElement('span'));
      const count = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate();
      for (let i = 1; i <= count; i++) {
        const date = new Date(first.getFullYear(), first.getMonth(), i), value = iso(date), entry = availability.get(value);
        const day = document.createElement('button'); day.type = 'button'; day.textContent = i; day.dataset.date = value;
        const unavailable = closed(entry);
        const checkout = !!(startInput?.value && !endInput?.value && value > startInput.value && validRange(startInput.value,date));
        // Checkout does not consume that day's inventory.
        day.disabled = date < today || (unavailable && !checkout);
        day.classList.toggle('is-unavailable', unavailable);
        const previous=availability.get(iso(new Date(date.getFullYear(),date.getMonth(),date.getDate()-1)));
        day.classList.toggle('is-turnover',!!(entry?.turnover || (!unavailable && closed(previous)) || (unavailable && !closed(previous) && date>today)));
        day.classList.toggle('is-booking-start',unavailable && !closed(previous) && date>today);
        day.classList.toggle('is-past',date<today);
        day.setAttribute('aria-label', date.toLocaleDateString(window.NEXUS_LOCALE?.lang || 'tr-TR') + (unavailable ? checkout ? ', yalnızca çıkış tarihi' : ', uygun değil' : entry ? ', müsait' : ', müsaitlik teyidi gerekir'));
        const selected = value === startInput?.value || value === endInput?.value;
        day.setAttribute('aria-pressed', String(selected));
        day.classList.toggle('is-selected', selected);
        day.classList.toggle('in-range', !!(endInput?.value && value > startInput.value && value < endInput.value));
        day.classList.toggle('is-available', !!(entry && !unavailable && !day.disabled));
        day.onclick = () => select(date); grid.appendChild(day);
      }
      panel.appendChild(grid); months.appendChild(panel);
    }
    box.appendChild(months);
    const note = document.createElement('p'); note.className = 'detail-calendar-note'; note.setAttribute('role', 'status');
    note.textContent = status; box.appendChild(note);
  }
  startInput?.addEventListener('change', render);
  document.addEventListener('nexus:lang', render);
  render();
  const suffix = box.dataset.tenant ? `?tenant=${encodeURIComponent(box.dataset.tenant)}` : '';
  fetch(`/v1/listings/${encodeURIComponent(box.dataset.listingId)}/availability${suffix}`, { credentials: 'same-origin' })
    .then(response => { if (!response.ok) throw new Error('availability'); return response.json(); })
    .then(days => {
      if (!Array.isArray(days)) throw new Error('availability');
      availability = new Map(days.filter(day => /^\d{4}-\d{2}-\d{2}$/.test(day.day)).map(day => [day.day, day]));
      if(preview && !days.length){for(const [offset,from,to] of [[0,1,9],[0,19,26],[1,8,14]]){for(let d=from;d<=to;d++){const date=new Date(today.getFullYear(),today.getMonth()+offset,d);availability.set(iso(date),{closed:true,available:0});}const boundary=new Date(today.getFullYear(),today.getMonth()+offset,to+1);availability.set(iso(boundary),{closed:false,available:1,turnover:true});}}
      status = 'İşaretli günler müsait. Bilgisi olmayan tarihler için rezervasyon adımında teyit alınır.';
      if (preview && !days.length) status='Demo müsaitlik takvimi: gri günler doludur; diğer tarihler için müsaitlik teyidi gerekir.';
      else if (!days.some(day => !day.closed && Number(day.available) > 0)) status = 'Yakın tarihlerde uygun kapasite görünmüyor. Tarih seçerek müsaitliği teyit edin.';
      availabilityStatus = status;
      render();
    }).catch(() => { status = availabilityStatus = 'Müsaitlik bilgisi şu anda alınamıyor. Tarih seçerek teklif isteyebilirsiniz.'; render(); });
})();
