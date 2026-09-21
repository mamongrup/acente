(function () {
  var campaignsTable = document.getElementById('campaigns-table-body');
  var couponsTable = document.getElementById('coupons-table-body');
  if (!campaignsTable || !couponsTable) return;

  var audienceSelect = document.getElementById('campaign-audience');
  var couponAudienceSelect = document.getElementById('coupon-audience');
  var requestedAudience = new URLSearchParams(window.location.search).get('audience');
  if (audienceSelect && ['all', 'agency', 'supplier'].indexOf(requestedAudience) !== -1) {
    audienceSelect.value = requestedAudience;
  }
  if (couponAudienceSelect && ['all', 'agency', 'supplier'].indexOf(requestedAudience) !== -1) {
    couponAudienceSelect.value = requestedAudience;
  }

  function audienceLabel(value) {
    return value === 'supplier' ? 'Yalnız tedarikçi' : value === 'agency' ? 'Yalnız acente' : 'Acente + tedarikçi';
  }

  function visibleForAudience(campaign) {
    if (!requestedAudience || requestedAudience === 'all') return true;
    return campaign.audience === 'all' || campaign.audience === requestedAudience;
  }

  function cell(value) {
    var node = document.createElement('td');
    node.textContent = value || '—';
    return node;
  }
  function empty(table, columns, message) {
    var row = document.createElement('tr');
    var td = document.createElement('td');
    td.colSpan = columns;
    td.className = 'empty-state';
    td.textContent = message;
    row.appendChild(td);
    table.appendChild(row);
  }

  fetch('/admin/campaigns/data', { credentials: 'same-origin', cache: 'no-store' })
    .then(function (response) {
      if (!response.ok) throw new Error('Kampanya verileri yüklenemedi');
      return response.json();
    })
    .then(function (data) {
      campaignsTable.textContent = '';
      couponsTable.textContent = '';
      var campaigns = data.campaigns.filter(visibleForAudience);
      if (!campaigns.length) empty(campaignsTable, 6, 'Bu kapsamda henüz kampanya yok.');
      campaigns.forEach(function (campaign) {
        var row = document.createElement('tr');
        row.appendChild(cell(campaign.name));
        row.appendChild(cell(campaign.kind));
        row.appendChild(cell(audienceLabel(campaign.audience)));
        row.appendChild(cell((campaign.startsAt || '—') + ' → ' + (campaign.endsAt || '—')));
        row.appendChild(cell(campaign.discount ? '%' + campaign.discount : '—'));
        row.appendChild(cell(campaign.status));
        campaignsTable.appendChild(row);
      });
      if (!data.coupons.length) empty(couponsTable, 5, 'Henüz kupon yok.');
      var coupons = data.coupons.filter(visibleForAudience);
      if (!coupons.length) empty(couponsTable, 6, 'Bu kapsamda henüz kupon yok.');
      coupons.forEach(function (coupon) {
        var row = document.createElement('tr');
        row.appendChild(cell(coupon.code));
        row.appendChild(cell(audienceLabel(coupon.audience)));
        row.appendChild(cell(coupon.discount ? '%' + coupon.discount : '—'));
        row.appendChild(cell(coupon.usedCount + ' / ' + coupon.usageLimit));
        row.appendChild(cell(coupon.endsAt));
        row.appendChild(cell(coupon.status));
        couponsTable.appendChild(row);
      });
    })
    .catch(function (error) {
      campaignsTable.textContent = '';
      couponsTable.textContent = '';
      empty(campaignsTable, 6, error.message);
      empty(couponsTable, 6, error.message);
    });
})();
