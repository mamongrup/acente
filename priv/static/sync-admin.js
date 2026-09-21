(function () {
  const workspace = document.getElementById("sync-workspace");
  if (!workspace) return;

  const cards = document.getElementById("sync-contract-cards");
  const jobsBody = document.getElementById("sync-jobs-body");
  const refresh = document.getElementById("sync-refresh");

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

  async function load() {
    if (refresh) refresh.disabled = true;
    try {
      const res = await fetch("/admin/sync/data", {
        credentials: "same-origin",
        headers: { Accept: "application/json" },
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Sync durumu okunamadı");
      renderCards(data.contract || []);
      renderJobs(data.jobs || []);
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
