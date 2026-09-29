(() => {
  const body = document.getElementById('inquiries-table-body');
  if (!body) return;

  const esc = v => String(v ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  function getCsrf() {
    const m = document.querySelector('meta[name="csrf-token"]');
    if (m && m.content) return m.content;
    return (document.cookie.match(/(?:^|;\s*)(?:nexus_csrf|agency_csrf)=([^;]*)/) ?? ['', ''])[1];
  }

  // ── AI Reply Modal ─────────────────────────────────────────────────────────
  function ensureModal() {
    if (document.getElementById('ai-inquiry-modal')) return;
    const modal = document.createElement('div');
    modal.id = 'ai-inquiry-modal';
    modal.style.cssText = [
      'display:none;position:fixed;inset:0;z-index:9999',
      'background:rgba(0,0,0,0.7);backdrop-filter:blur(4px)',
      'align-items:center;justify-content:center'
    ].join(';');
    modal.innerHTML = `
      <div style="background:var(--glass-base,#1a1f2e);border:1px solid rgba(255,255,255,0.12);
                  border-radius:16px;width:min(640px,96vw);padding:28px;position:relative;">
        <button id="ai-modal-close" style="position:absolute;top:12px;right:14px;background:none;
                border:none;color:var(--text-pure,#fff);font-size:20px;cursor:pointer;">✕</button>
        <h3 style="margin:0 0 6px;color:var(--text-pure,#fff)">✨ AI ile Yanıt Taslağı Hazırla</h3>
        <p id="ai-modal-guest" style="font-size:13px;color:var(--text-muted,#aaa);margin:0 0 12px;"></p>
        <div id="ai-modal-status" style="font-size:13px;color:var(--text-muted,#aaa);margin:0 0 10px;min-height:20px;"></div>
        <textarea id="ai-modal-output" rows="10"
          style="width:100%;box-sizing:border-box;border-radius:8px;padding:12px;
                 background:rgba(0,0,0,0.35);color:var(--text-pure,#fff);
                 border:1px solid rgba(255,255,255,0.1);font-size:13px;line-height:1.6;
                 resize:vertical;font-family:inherit;"
          placeholder="AI taslağı burada görünecek…"></textarea>
        <div style="margin-top:12px;display:flex;gap:8px;flex-wrap:wrap;">
          <button id="ai-modal-copy" class="secondary"
            style="font-size:13px;">📋 Kopyala</button>
          <button id="ai-modal-regen" class="btn-ai-pill"
            style="font-size:13px;">🔄 Yeniden Üret</button>
          <button id="ai-modal-close2" class="secondary"
            style="font-size:13px;margin-left:auto;">Kapat</button>
        </div>
      </div>`;
    document.body.appendChild(modal);

    document.getElementById('ai-modal-close').onclick =
    document.getElementById('ai-modal-close2').onclick = () => { modal.style.display = 'none'; };
    document.getElementById('ai-modal-copy').onclick = () => {
      const ta = document.getElementById('ai-modal-output');
      navigator.clipboard.writeText(ta.value).then(() => {
        document.getElementById('ai-modal-status').textContent = '✅ Panoya kopyalandı.';
        setTimeout(() => { document.getElementById('ai-modal-status').textContent = ''; }, 2000);
      });
    };
    modal.addEventListener('click', e => { if (e.target === modal) modal.style.display = 'none'; });
  }

  function openAiReplyModal(row) {
    ensureModal();
    const modal = document.getElementById('ai-inquiry-modal');
    const guestEl = document.getElementById('ai-modal-guest');
    const statusEl = document.getElementById('ai-modal-status');
    const output = document.getElementById('ai-modal-output');
    const regenBtn = document.getElementById('ai-modal-regen');

    guestEl.textContent = `Misafir: ${row.full_name} — İlan: ${row.listing_title || 'Genel talep'}`;
    statusEl.textContent = '⏳ Yapay zeka yanıt taslağı hazırlıyor…';
    output.value = '';
    modal.style.display = 'flex';

    async function generate() {
      statusEl.textContent = '⏳ Yapay zeka yanıt taslağı hazırlıyor…';
      output.value = '';
      regenBtn.disabled = true;

      const params = new URLSearchParams();
      params.append('csrf', getCsrf());
      params.append('csrf_token', getCsrf());
      params.append('inquiry_id', row.id);
      params.append('listing_title', row.listing_title || '');
      params.append('guest_name', row.full_name || '');
      params.append('message', row.message || '');
      params.append('check_in', row.check_in || '');
      params.append('check_out', row.check_out || '');
      params.append('guest_count', String(row.guest_count || 1));

      try {
        const res = await fetch('/admin/ai/inquiry-reply', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: params.toString(),
          credentials: 'same-origin'
        });
        const data = await res.json();
        if (data.ok && data.draft) {
          output.value = data.draft;
          statusEl.textContent = '✅ Taslak hazır. Düzenleyip gönderebilirsiniz.';
        } else {
          statusEl.textContent = '⚠️ Hata: ' + (data.error || 'Taslak üretilemedi');
        }
      } catch (err) {
        statusEl.textContent = '⚠️ ' + err.message;
      } finally {
        regenBtn.disabled = false;
      }
    }

    regenBtn.onclick = generate;
    generate();
  }

  // ── Row Renderer ───────────────────────────────────────────────────────────
  window.loadInquiries = async () => {
    const response = await fetch('/admin/inquiries/data', { credentials: 'same-origin' });
    const rows = await response.json();

    if (!rows.length) {
      body.innerHTML = '<tr><td colspan="5">Açık teklif talebi yok.</td></tr>';
      return;
    }

    body.innerHTML = rows.map(row => `
      <tr data-row-id="${esc(row.id)}">
        <td>${esc(row.full_name)}<br><small>${esc(row.email)}</small></td>
        <td>${esc(row.listing_title || 'Genel talep')}</td>
        <td>${esc(row.check_in || '-')} → ${esc(row.check_out || '-')}<br>
            <small>${esc(row.guest_count || 1)} misafir</small></td>
        <td>
          <form method="post" action="/admin/inquiries/status">
            <input type="hidden" name="id" value="${esc(row.id)}">
            <select name="status" onchange="this.form.submit()">
              <option ${row.status === 'new' ? 'selected' : ''}>new</option>
              <option ${row.status === 'contacted' ? 'selected' : ''}>contacted</option>
              <option ${row.status === 'converted' ? 'selected' : ''}>converted</option>
              <option ${row.status === 'closed' ? 'selected' : ''}>closed</option>
            </select>
          </form>
          ${row.status !== 'converted' ? `
            <form method="post" action="/admin/inquiries/convert" style="margin-top:4px">
              <input type="hidden" name="id" value="${esc(row.id)}">
              <button type="submit" class="secondary">Rezervasyona dönüştür</button>
            </form>` : ''}
        </td>
        <td>
          <button type="button" class="btn-ai-pill btn-ai-reply"
            data-row='${JSON.stringify(row).replace(/'/g, "&#39;")}'
            style="font-size:12px;padding:5px 10px;white-space:nowrap;">
            ✨ AI Yanıt Taslağı
          </button>
        </td>
      </tr>`).join('');

    // Delegate click for AI reply buttons
    body.querySelectorAll('.btn-ai-reply').forEach(btn => {
      btn.addEventListener('click', () => {
        try {
          const row = JSON.parse(btn.dataset.row.replace(/&#39;/g, "'"));
          openAiReplyModal(row);
        } catch (e) {
          console.error('AI reply parse error', e);
        }
      });
    });
  };

  window.loadInquiries();
})();
