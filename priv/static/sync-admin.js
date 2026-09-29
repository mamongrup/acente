(function () {
  const workspace = document.getElementById("sync-workspace");
  if (!workspace) return;

  const cards = document.getElementById("sync-contract-cards");
  const healthCards = document.getElementById("sync-health-cards");
  const jobsBody = document.getElementById("sync-jobs-body");
  const refresh = document.getElementById("sync-refresh");
  const conflictHost = document.createElement("div");
  conflictHost.id = "sync-conflicts";
  const deliveryHost = document.createElement("div");
  deliveryHost.id = "sync-reservation-deliveries";
  const jobCard = workspace.querySelector(".table-card");
  if (jobCard) jobCard.before(conflictHost, deliveryHost);

  const labels = {
    catalog_contract_version: ["Katalog sözleşmesi", "Kategori sözlüğü"],
    supplier_listing_contract_version: ["İlan sözleşmesi", "Alan ve durum kuralları"],
    active_category_count: ["Kategoriler", "Aktif ana kategori sayısı"],
    active_filter_item_count: ["Filtreler", "Aktif yönetilebilir filtre maddeleri"],
    active_supplier_module_count: ["Panel modülleri", "Ortak tedarikçi panel modülleri"],
    supplier_module_detail_signature: ["Modül detay imzası", "Kapsam ve yetki sözleşmesi"],
  };

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function renderCards(contract) {
    if (!cards) return;
    const byKey = {};
    (contract || []).forEach((row) => {
      byKey[row.key] = row.value;
    });
    cards.innerHTML = Object.keys(labels)
      .map((key) => {
        const [title, desc] = labels[key];
        const value = byKey[key] || "—";
        return `<article class="metric"><span>${escapeHtml(title)}</span><strong>${escapeHtml(value)}</strong><small>${escapeHtml(desc)}</small></article>`;
      })
      .join("");
  }

  function renderHealth(rows) {
    if (!healthCards) return;
    const health = Array.isArray(rows) && rows.length ? rows[0] : {};
    const items = [
      ["NEXUS bağlantısı", health.configured === "true" ? "Hazır" : "Eksik", "Endpoint ve API anahtarı"],
      ["Onay durumu", health.connection_status || "—", "Acentenin bağlantı başvurusu"],
      ["Son senkronizasyon", health.last_sync_at || "Henüz yok", health.last_sync_status || "—"],
      ["Son başarılı sync", health.last_success_at || "Henüz yok", "Başarılı import zamanı"],
      ["NEXUS ilanları", health.nexus_listings || "0", "Merkezden senkronize edilen ilan"],
      ["Başarısız sync işleri", health.failed_jobs || "0", health.last_sync_error || "Son hata yok"],
      ["Rezervasyon kuyruğu", `${health.pending_deliveries || "0"} bekleyen / ${health.failed_deliveries || "0"} başarısız`, "Olay teslim durumu"],
    ];
    healthCards.innerHTML = items.map(([title, value, desc]) =>
      `<article class="metric"><span>${escapeHtml(title)}</span><strong>${escapeHtml(value)}</strong><small>${escapeHtml(desc)}</small></article>`
    ).join("");
  }

  function statusClass(status) {
    if (status === "success") return "status-pill";
    if (status === "failed") return "status-pill danger";
    if (status === "running") return "status-pill warning";
    return "status-pill muted";
  }

  function renderJobs(jobs) {
    if (!jobsBody) return;
    if (!jobs || !jobs.length) {
      jobsBody.innerHTML = `<tr><td colspan="6">Henüz sync işi yok.</td></tr>`;
      return;
    }
    jobsBody.innerHTML = jobs
      .map((job) => {
        return `<tr>
          <td>${escapeHtml(job.job_type)}</td>
          <td><span class="${statusClass(job.status)}">${escapeHtml(job.status)}</span></td>
          <td>${escapeHtml(job.started_at)}</td>
          <td>${escapeHtml(job.finished_at)}</td>
          <td>${escapeHtml(job.items_count)}</td>
          <td>${escapeHtml(job.error)}</td>
        </tr>`;
      })
      .join("");
  }

  function renderConflicts(conflicts) {
    if (!conflicts || !conflicts.length) {
      conflictHost.innerHTML = '';
      return;
    }
    const csrf = (document.querySelector('meta[name="csrf-token"]') || {}).content || '';
    conflictHost.innerHTML = '<section class="quick"><h3>İlan kodu çakışmaları (' + conflicts.length + ')</h3><p class="muted">Yerel ilan korunuyor. Uzak ilanı ayrıca yayınlamak için yerel kodu ayırın; yerel ilan kimliği ve rezervasyonları korunur.</p><div class="partner-lead-list">' + conflicts.map((item) =>
      '<div class="partner-lead-row"><div><strong>' + escapeHtml(item.title) + '</strong><br><small>Yerel kod: ' + escapeHtml(item.code) + ' · NEXUS kimliği: ' + escapeHtml(item.externalId) + '</small></div><form method="post" action="/admin/sync/resolve-conflict" class="partner-action-form"><input type="hidden" name="csrf" value="' + escapeHtml(csrf) + '"><input type="hidden" name="conflict_id" value="' + escapeHtml(item.id) + '"><button type="submit">Kodu ayır</button></form></div>'
    ).join('') + '</div></section>';
  }

  function renderDeliveries(deliveries) {
    const rows = Array.isArray(deliveries) ? deliveries : [];
    const csrf = (document.querySelector('meta[name="csrf-token"]') || {}).content || '';
    deliveryHost.innerHTML = '<section class="quick"><div class="section-heading"><div><h3>NEXUS rezervasyon teslimatları</h3><p class="muted">Bekleyen ve başarısız son 50 olay. Süresi dolmuş rezervasyonlar yönetici incelemesi gerektirir.</p></div><a class="secondary" href="/admin/reservations">Rezervasyonlara git</a></div>' +
      (rows.length ? '<div class="table-card"><table class="data-table"><thead><tr><th>Rezervasyon</th><th>Olay</th><th>Durum</th><th>Deneme</th><th>Son hata</th><th>İşlem</th></tr></thead><tbody>' + rows.map((item) => {
        const retry = item.canRetry ? '<form method="post" action="/admin/sync/retry-reservation"><input type="hidden" name="csrf" value="' + escapeHtml(csrf) + '"><input type="hidden" name="delivery_id" value="' + escapeHtml(item.id) + '"><button class="secondary" type="submit">Tekrar dene</button></form>' : '<span class="muted">İncele</span>';
        return '<tr><td>' + escapeHtml(item.reference) + '</td><td>' + escapeHtml(item.eventType) + ' · ' + escapeHtml(item.reservationStatus) + '</td><td>' + escapeHtml(item.status) + '</td><td>' + escapeHtml(item.attempts) + '</td><td>' + escapeHtml(item.error) + '</td><td>' + retry + '</td></tr>';
      }).join('') + '</tbody></table></div>' : '<p class="muted">Bekleyen veya başarısız rezervasyon teslimatı yok.</p>') + '</section>';
  }

  async function load() {
    if (refresh) refresh.disabled = true;
    try {
      const [res, deliveryRes] = await Promise.all([
        fetch("/admin/sync/data", { credentials: "same-origin", headers: { Accept: "application/json" } }),
        fetch("/admin/sync/deliveries", { credentials: "same-origin", headers: { Accept: "application/json" } }),
      ]);
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Sync durumu okunamadı");
      if (!deliveryRes.ok) throw new Error("Rezervasyon teslimatları okunamadı");
      const deliveries = await deliveryRes.json();
      renderCards(data.contract || []);
      renderHealth(data.health || []);
      renderJobs(data.jobs || []);
      renderConflicts(data.conflicts || []);
      renderDeliveries(deliveries);
    } catch (error) {
      if (jobsBody) {
        jobsBody.innerHTML = `<tr><td colspan="6">${escapeHtml(error.message)}</td></tr>`;
      }
    } finally {
      if (refresh) refresh.disabled = false;
    }
  }

  if (refresh) refresh.addEventListener("click", load);
  load();
})();
