(function () {
  const workspace = document.getElementById("supplier-onboarding-workspace");
  if (!workspace) return;

  const cards = document.getElementById("supplier-onboarding-status-cards");
  const body = document.getElementById("supplier-onboarding-body");
  const documentsWrap = document.getElementById("supplier-document-review");
  const refresh = document.getElementById("supplier-onboarding-refresh");

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function statusLabel(status) {
    const labels = {
      draft: "Taslak",
      submitted: "Gönderildi",
      in_review: "İncelemede",
      approved: "Onaylandı",
      rejected: "Reddedildi",
      suspended: "Askıda",
    };
    return labels[status] || status || "—";
  }

  function statusClass(status) {
    if (status === "approved") return "status-pill";
    if (status === "rejected" || status === "suspended") return "status-pill danger";
    if (status === "in_review" || status === "submitted") return "status-pill warning";
    return "status-pill muted";
  }

  function renderCards(applications) {
    if (!cards) return;
    const counts = { draft: 0, submitted: 0, in_review: 0, approved: 0, issue: 0 };
    (applications || []).forEach((app) => {
      if (app.status === "rejected" || app.status === "suspended") counts.issue += 1;
      else if (Object.prototype.hasOwnProperty.call(counts, app.status)) counts[app.status] += 1;
    });
    const rows = [
      ["Taslak", counts.draft, "Tamamlanmamış başvuru"],
      ["Gönderildi", counts.submitted, "İnceleme bekliyor"],
      ["İncelemede", counts.in_review, "Operasyon kontrolünde"],
      ["Onaylandı", counts.approved, "Tedarikçi aktif"],
      ["Askıda/Ret", counts.issue, "Aksiyon gerekiyor"],
    ];
    cards.innerHTML = rows
      .map(([title, value, desc]) => `<article class="metric"><span>${escapeHtml(title)}</span><strong>${escapeHtml(value)}</strong><small>${escapeHtml(desc)}</small></article>`)
      .join("");
  }

  function renderTable(applications) {
    if (!body) return;
    if (!applications || !applications.length) {
      body.innerHTML = `<tr><td colspan="8">Henüz tedarikçi başvurusu yok.</td></tr>`;
      return;
    }
    body.innerHTML = applications
      .map((app) => {
        const supplier = app.name ? `${app.name}<br><small>${app.email}</small>` : app.email;
        const actions = renderActions(app);
        return `<tr>
          <td>${supplier}</td>
          <td>${escapeHtml(app.categories || "—")}</td>
          <td><span class="${statusClass(app.status)}">${escapeHtml(statusLabel(app.status))}</span></td>
          <td>${escapeHtml(statusLabel(app.identity_status))}</td>
          <td>${escapeHtml(app.document_count)}</td>
          <td>${escapeHtml(app.submitted_at)}</td>
          <td>${escapeHtml(app.note)}</td>
          <td>${actions}</td>
        </tr>`;
      })
      .join("");
  }

  function documentStatusLabel(status) {
    const labels = {
      missing: "Eksik",
      pending: "Bekliyor",
      approved: "Onaylandı",
      rejected: "Reddedildi",
    };
    return labels[status] || status || "—";
  }

  function documentTypeLabel(type) {
    const labels = {
      tax_certificate: "Vergi levhası",
      authorized_signature: "İmza sirküleri / yetki belgesi",
      trade_registry_or_chamber_record: "Ticaret sicil / oda kaydı",
      service_license_if_required: "Gerekli hizmet lisansı",
      bank_account_verification: "Banka hesap doğrulama",
    };
    return labels[type] || type;
  }

  function documentDecisionForm(doc, decision, label, className) {
    if (!doc.document_id) return "";
    return `<form method="post" action="/admin/supplier-onboarding/document-decision" class="inline-action-form">
      <input type="hidden" name="document" value="${escapeHtml(doc.document_id)}">
      <input type="hidden" name="decision" value="${escapeHtml(decision)}">
      <input type="hidden" name="note" value="">
      <button type="submit" class="${escapeHtml(className || "secondary")}">${escapeHtml(label)}</button>
    </form>`;
  }

  function renderDocuments(applications, documents) {
    if (!documentsWrap) return;
    if (!applications || !applications.length) {
      documentsWrap.innerHTML = `<p class="muted">Belge incelemesi için başvuru yok.</p>`;
      return;
    }

    const byApplication = {};
    (documents || []).forEach((doc) => {
      if (!byApplication[doc.application_id]) byApplication[doc.application_id] = [];
      byApplication[doc.application_id].push(doc);
    });

    documentsWrap.innerHTML = applications
      .map((app) => {
        const docs = byApplication[app.id] || [];
        const title = app.name || app.email || app.id;
        const rows = docs.length
          ? docs
              .map((doc) => {
                const actions = doc.status === "missing"
                  ? `<span class="muted">Tedarikçiden bekleniyor</span>`
                  : `<div class="table-actions">${documentDecisionForm(doc, "approved", "Onayla", "primary")}${documentDecisionForm(doc, "rejected", "Reddet", "secondary")}${documentDecisionForm(doc, "pending", "Beklet", "secondary")}</div>`;
                return `<tr>
                  <td>${escapeHtml(documentTypeLabel(doc.document_type))}</td>
                  <td><span class="${statusClass(doc.status)}">${escapeHtml(documentStatusLabel(doc.status))}</span></td>
                  <td>${escapeHtml(doc.media_id || "—")}</td>
                  <td>${escapeHtml(doc.reviewed_at || "—")}</td>
                  <td>${escapeHtml(doc.note || "")}</td>
                  <td>${actions}</td>
                </tr>`;
              })
              .join("")
          : `<tr><td colspan="6">Bu başvuru için belge sözleşmesi bulunamadı.</td></tr>`;

        return `<details class="document-review-card">
          <summary>
            <strong>${escapeHtml(title)}</strong>
            <span class="muted">${escapeHtml(app.categories || "kategori yok")}</span>
          </summary>
          <table class="data-table">
            <thead><tr><th>Belge</th><th>Durum</th><th>Medya</th><th>İnceleme</th><th>Not</th><th>Aksiyon</th></tr></thead>
            <tbody>${rows}</tbody>
          </table>
        </details>`;
      })
      .join("");
  }

  function decisionButton(app, decision, label, className) {
    return `<form method="post" action="/admin/supplier-onboarding/decision" class="inline-action-form">
      <input type="hidden" name="application" value="${escapeHtml(app.id)}">
      <input type="hidden" name="decision" value="${escapeHtml(decision)}">
      <input type="hidden" name="note" value="">
      <button type="submit" class="${escapeHtml(className || "secondary")}">${escapeHtml(label)}</button>
    </form>`;
  }

  function renderActions(app) {
    if (app.status === "submitted" || app.status === "draft" || app.status === "rejected") {
      return `<div class="table-actions">${decisionButton(app, "in_review", "İncele", "secondary")}${decisionButton(app, "approved", "Onayla", "primary")}</div>`;
    }
    if (app.status === "in_review") {
      return `<div class="table-actions">${decisionButton(app, "approved", "Onayla", "primary")}${decisionButton(app, "rejected", "Reddet", "secondary")}</div>`;
    }
    if (app.status === "approved") {
      return `<div class="table-actions">${decisionButton(app, "suspended", "Askıya al", "secondary")}</div>`;
    }
    if (app.status === "suspended") {
      return `<div class="table-actions">${decisionButton(app, "approved", "Tekrar onayla", "primary")}</div>`;
    }
    return `<span class="muted">Aksiyon yok</span>`;
  }

  async function load() {
    if (refresh) refresh.disabled = true;
    try {
      const res = await fetch("/admin/supplier-onboarding/data", {
        credentials: "same-origin",
        headers: { Accept: "application/json" },
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Başvurular okunamadı");
      renderCards(data.applications || []);
      renderTable(data.applications || []);
      renderDocuments(data.applications || [], data.documents || []);
    } catch (error) {
      if (body) body.innerHTML = `<tr><td colspan="8">${escapeHtml(error.message)}</td></tr>`;
      if (documentsWrap) documentsWrap.innerHTML = `<p class="muted">${escapeHtml(error.message)}</p>`;
    } finally {
      if (refresh) refresh.disabled = false;
    }
  }

  if (refresh) refresh.addEventListener("click", load);
  load();
})();
