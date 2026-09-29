/**
 * NEXUS AGENCY — Admin Listing Submissions Manager
 * Handles review, approval and rejection of public marketplace listing applications.
 */

(function () {
  'use strict';

  var workspace = document.getElementById('listing-submissions-workspace');
  if (!workspace) return;

  var cards = document.getElementById('listing-submissions-status-cards');
  var body = document.getElementById('listing-submissions-body');
  var refreshBtn = document.getElementById('listing-submissions-refresh');
  var statusFilter = document.getElementById('listing-submission-status-filter');

  var notice = document.createElement('div');
  notice.className = 'admin-notice';
  notice.style.display = 'none';
  notice.style.padding = '0.75rem 1rem';
  notice.style.marginBottom = '1rem';
  notice.style.borderRadius = '8px';
  workspace.prepend(notice);

  function readCookie(name) {
    var parts = document.cookie.split(/;\s*/);
    for (var i = 0; i < parts.length; i++) {
      var eq = parts[i].indexOf('=');
      if (eq > 0 && parts[i].slice(0, eq) === name) {
        return decodeURIComponent(parts[i].slice(eq + 1));
      }
    }
    return '';
  }

  function showNotice(msg, isError) {
    notice.style.display = 'block';
    notice.style.background = isError ? 'rgba(251, 113, 133, 0.15)' : 'rgba(52, 211, 153, 0.15)';
    notice.style.border = isError ? '1px solid rgba(251, 113, 133, 0.3)' : '1px solid rgba(52, 211, 153, 0.3)';
    notice.style.color = isError ? '#fb7185' : '#34d399';
    notice.textContent = msg;
    setTimeout(function () {
      notice.style.display = 'none';
    }, 6000);
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function formatPrice(minor, currency) {
    var val = (Number(minor) || 0) / 100;
    return val.toLocaleString('tr-TR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' ' + (currency || 'TRY');
  }

  function domainBadge(target) {
    if (target === 'both') {
      return '<span class="status-pill info" title="rezervasyonyap.com.tr + reservationinturkey.com">Her İkisi (Pazaryeri)</span>';
    }
    if (target === 'reservationinturkey') {
      return '<span class="status-pill" style="border-color:#818cf8; color:#818cf8;" title="Global Portal">reservationinturkey.com</span>';
    }
    return '<span class="status-pill" style="border-color:#22d3ee; color:#22d3ee;" title="Türkiye Vitrini">rezervasyonyap.com.tr</span>';
  }

  function statusBadge(status) {
    if (status === 'approved') return '<span class="status-pill success" style="color:#34d399; border-color:#34d399;">Onaylandı</span>';
    if (status === 'rejected') return '<span class="status-pill danger" style="color:#fb7185; border-color:#fb7185;">Reddedildi</span>';
    return '<span class="status-pill warning" style="color:#fbbf24; border-color:#fbbf24;">Beklemede</span>';
  }

  function renderMetrics(subs) {
    if (!cards) return;
    var counts = { pending: 0, approved: 0, rejected: 0, total: subs.length };
    subs.forEach(function (s) {
      if (s.status === 'approved') counts.approved++;
      else if (s.status === 'rejected') counts.rejected++;
      else counts.pending++;
    });

    cards.innerHTML = '' +
      '<div class="metric-card">' +
        '<div class="metric-title">Bekleyen İlanlar</div>' +
        '<div class="metric-value" style="color:#fbbf24;">' + counts.pending + '</div>' +
        '<div class="metric-desc">İnceleme bekleyen vitrin başvuruları</div>' +
      '</div>' +
      '<div class="metric-card">' +
        '<div class="metric-title">Onaylanan</div>' +
        '<div class="metric-value" style="color:#34d399;">' + counts.approved + '</div>' +
        '<div class="metric-desc">Kataloğa aktarılan ilanlar</div>' +
      '</div>' +
      '<div class="metric-card">' +
        '<div class="metric-title">Reddedilen</div>' +
        '<div class="metric-value" style="color:#fb7185;">' + counts.rejected + '</div>' +
        '<div class="metric-desc">Gerekçeyle reddedilenler</div>' +
      '</div>' +
      '<div class="metric-card">' +
        '<div class="metric-title">Toplam Başvuru</div>' +
        '<div class="metric-value">' + counts.total + '</div>' +
        '<div class="metric-desc">Tüm vitrin kayıtları</div>' +
      '</div>';
  }

  function renderTable(subs) {
    if (!body) return;
    if (subs.length === 0) {
      body.innerHTML = '<tr><td colspan="8" style="text-align:center; padding: 2rem; color:var(--text-muted);">Henüz bu filtreye uygun ilan başvurusu bulunmuyor.</td></tr>';
      return;
    }

    var html = subs.map(function (s) {
      var dateStr = s.created_at ? new Date(s.created_at).toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—';

      var actions = '';
      if (s.status === 'pending') {
        actions = '' +
          '<div style="display:flex; gap:0.4rem; flex-wrap:wrap;">' +
            '<button type="button" class="btn-sm btn-approve" data-id="' + s.id + '" style="padding:0.3rem 0.65rem; border-radius:6px; background:rgba(52,211,153,0.15); border:1px solid #34d399; color:#34d399; font-weight:600; cursor:pointer;">Onayla</button>' +
            '<button type="button" class="btn-sm btn-reject" data-id="' + s.id + '" style="padding:0.3rem 0.65rem; border-radius:6px; background:rgba(251,113,133,0.15); border:1px solid #fb7185; color:#fb7185; font-weight:600; cursor:pointer;">Reddet</button>' +
          '</div>';
      } else if (s.status === 'approved') {
        actions = '<span style="color:#34d399; font-size:0.85rem;"><i class="hgi-stroke hgi-tick-02"></i> Kataloğa Eklendi</span>';
      } else {
        actions = '<span style="color:#fb7185; font-size:0.82rem;" title="' + escapeHtml(s.admin_notes) + '">Red: ' + escapeHtml(s.admin_notes || 'Gerekçe belirtilmedi') + '</span>';
      }

      return '' +
        '<tr data-id="' + s.id + '">' +
          '<td>' +
            '<strong>' + escapeHtml(s.company_name) + '</strong><br>' +
            '<span style="font-size:0.82rem; color:var(--text-muted);">' + escapeHtml(s.contact_name) + '</span><br>' +
            '<a href="mailto:' + escapeHtml(s.email) + '" style="font-size:0.78rem; color:var(--neon-cyan);">' + escapeHtml(s.email) + '</a> ' +
            '<span style="font-size:0.78rem; color:var(--text-dim);">' + escapeHtml(s.phone) + '</span>' +
          '</td>' +
          '<td><span class="badge" style="background:rgba(148,180,230,0.1); padding:0.25rem 0.5rem; border-radius:6px; font-weight:600; font-size:0.8rem;">' + escapeHtml(s.category_code) + '</span></td>' +
          '<td>' +
            '<strong>' + escapeHtml(s.listing_title) + '</strong><br>' +
            '<span style="font-size:0.82rem; color:var(--text-muted);"><i class="hgi-stroke hgi-location-01"></i> ' + escapeHtml(s.locality) + '</span>' +
          '</td>' +
          '<td>' + domainBadge(s.domain_target) + '</td>' +
          '<td>' +
            '<strong>' + formatPrice(s.price_minor, s.currency) + '</strong><br>' +
            '<span style="font-size:0.78rem; color:var(--text-muted);">Kapasite: ' + (s.guest_capacity || '—') + ' kişi</span>' +
          '</td>' +
          '<td><span style="font-size:0.82rem; color:var(--text-muted);">' + dateStr + '</span></td>' +
          '<td>' + statusBadge(s.status) + '</td>' +
          '<td>' + actions + '</td>' +
        '</tr>';
    }).join('');

    body.innerHTML = html;
    attachTableEvents();
  }

  function attachTableEvents() {
    var approveBtns = body.querySelectorAll('.btn-approve');
    approveBtns.forEach(function (btn) {
      btn.addEventListener('click', function () {
        var id = btn.getAttribute('data-id');
        handleApprove(id, btn);
      });
    });

    var rejectBtns = body.querySelectorAll('.btn-reject');
    rejectBtns.forEach(function (btn) {
      btn.addEventListener('click', function () {
        var id = btn.getAttribute('data-id');
        handleReject(id, btn);
      });
    });
  }

  async function handleApprove(submissionId, btn) {
    var choice = confirm('Bu ilanı onaylayarak acente kataloğuna doğrudan aktarmak istiyor musunuz?\n\n- Tamam: Doğrudan yayına al (published)\n- İptal: Onaylamadan vazgeç');
    if (!choice) return;

    btn.disabled = true;
    btn.textContent = 'Onaylanıyor…';

    try {
      var csrfToken = readCookie('nexus_csrf');
      var formData = new URLSearchParams();
      formData.append('submission_id', submissionId);
      formData.append('initial_status', 'published');
      formData.append('csrf', csrfToken);

      var res = await fetch('/admin/listing-submissions/approve', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: formData.toString()
      });

      if (!res.ok) throw new Error('Sunucu hatası: ' + res.status);

      showNotice('İlan onaylandı ve kataloğa aktarıldı.', false);
      await loadData();
    } catch (err) {
      showNotice('Onaylama sırasında hata oluştu: ' + err.message, true);
      btn.disabled = false;
      btn.textContent = 'Onayla';
    }
  }

  async function handleReject(submissionId, btn) {
    var reason = prompt('Lütfen ret gerekçesini yazın (Tedarikçiye iletilecektir):', 'Bilgiler veya belgeler yetersiz görüldü.');
    if (reason === null) return;

    btn.disabled = true;
    btn.textContent = 'Reddediliyor…';

    try {
      var csrfToken = readCookie('nexus_csrf');
      var formData = new URLSearchParams();
      formData.append('submission_id', submissionId);
      formData.append('reason', reason);
      formData.append('csrf', csrfToken);

      var res = await fetch('/admin/listing-submissions/reject', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: formData.toString()
      });

      if (!res.ok) throw new Error('Sunucu hatası: ' + res.status);

      showNotice('İlan başvurusu reddedildi.', false);
      await loadData();
    } catch (err) {
      showNotice('Reddetme sırasında hata oluştu: ' + err.message, true);
      btn.disabled = false;
      btn.textContent = 'Reddet';
    }
  }

  async function loadData() {
    if (refreshBtn) refreshBtn.disabled = true;
    var status = statusFilter ? statusFilter.value : '';
    try {
      var res = await fetch('/admin/listing-submissions/data?status=' + encodeURIComponent(status), {
        credentials: 'same-origin',
        headers: { Accept: 'application/json' }
      });
      if (!res.ok) throw new Error('İlan verileri okunamadı (Kod: ' + res.status + ')');
      var data = await res.json();
      var subs = data.submissions || [];
      renderMetrics(subs);
      renderTable(subs);
    } catch (err) {
      if (body) {
        body.innerHTML = '<tr><td colspan="8" style="color:#fb7185; text-align:center; padding:1.5rem;">' + escapeHtml(err.message) + '</td></tr>';
      }
    } finally {
      if (refreshBtn) refreshBtn.disabled = false;
    }
  }

  if (refreshBtn) refreshBtn.addEventListener('click', loadData);
  if (statusFilter) statusFilter.addEventListener('change', loadData);

  loadData();
})();
