(function () {
  var root = document.getElementById('module-controls');
  if (!root) return;
  var status = document.createElement('p');
  status.className = 'muted';
  status.textContent = 'Modül politikaları yükleniyor…';
  root.appendChild(status);
  fetch('/admin/module-controls/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (r) { if (!r.ok) throw new Error('Rapor yüklenemedi'); return r.json(); })
    .then(function (rows) {
      status.textContent = rows.length ? rows.map(function (row) {
        return row.module_key + ': ' + row.mode + ' · günlük ' + row.daily_limit + ' · haftalık ' + row.weekly_limit + ' · aylık ' + row.monthly_limit;
      }).join(' | ') : 'Henüz modül politikası tanımlanmadı.';
    })
    .catch(function () { status.textContent = 'Modül politikaları yüklenemedi.'; });
  var report = document.createElement('p');
  report.className = 'muted';
  report.textContent = 'Son 30 günlük çalışma raporu yükleniyor…';
  root.appendChild(report);
  fetch('/admin/module-controls/report', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (r) { if (!r.ok) throw new Error('Rapor yüklenemedi'); return r.json(); })
    .then(function (rows) {
      report.textContent = rows.length ? rows.slice(0, 8).map(function (row) {
        return row.report_date + ' · ' + row.module_key + ' · ✓' + row.completed_count + ' ⚠' + row.failed_count + ' ⏭' + row.skipped_count + ' · maliyet ' + row.cost_cents;
      }).join(' | ') : 'Henüz çalışma raporu oluşmadı.';
    })
    .catch(function () { report.textContent = 'Çalışma raporu yüklenemedi.'; });
}());
