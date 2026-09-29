(function () {
  'use strict';
  var today = new Date(); today.setHours(0, 0, 0, 0);
  var maxDate = new Date(today); maxDate.setFullYear(maxDate.getFullYear() + 1);
  function locale() { return (window.NEXUS_LOCALE && window.NEXUS_LOCALE.lang) || document.documentElement.lang || 'tr'; }
  function translate(tr, en) { return locale() === 'tr' ? tr : en; }
  function iso(date) { return date ? date.getFullYear() + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0') : ''; }
  function parse(value) { if (!/^\d{4}-\d{2}-\d{2}$/.test(value || '')) return null; var d = new Date(value + 'T12:00:00'); return Number.isNaN(d.getTime()) ? null : d; }
  function same(a, b) { return a && b && iso(a) === iso(b); }
  function label(date) { return date ? new Intl.DateTimeFormat(locale(), { day: 'numeric', month: 'short' }).format(date) : ''; }
  function createCalendar(container, startInput, endInput, onChange) {
    var month = new Date(today.getFullYear(), today.getMonth(), 1);
    var start = parse(startInput.value), end = parse(endInput.value);
    var calendar = document.createElement('div'); calendar.className = 'nx-calendar';
    container.appendChild(calendar);
    var form = startInput.closest('form');
    var flexible = document.createElement('input'); flexible.type = 'hidden'; flexible.name = 'date_flex'; flexible.value = '0';
    if (form) form.appendChild(flexible);
    var flexBar = document.createElement('div'); flexBar.className = 'nx-date-flex';
    var flexLabel = document.createElement('span'); flexLabel.className = 'nx-date-flex-label';
    flexBar.appendChild(flexLabel);
    [0, 3, 7].forEach(function (days) {
      var option = document.createElement('button'); option.type = 'button'; option.className = 'nx-date-flex-option'; option.dataset.days = String(days);
      option.addEventListener('click', function () { flexible.value = String(days); updateFlex(); });
      flexBar.appendChild(option);
    });
    container.appendChild(flexBar);
    function updateFlex() {
      flexLabel.textContent = translate('Esnek tarih', 'Flexible dates');
      flexBar.querySelectorAll('button').forEach(function (button) {
        var days = Number(button.dataset.days);
        button.textContent = days ? '±' + days + ' ' + translate('gün', 'days') : translate('Tam', 'Exact');
        button.setAttribute('aria-pressed', String(flexible.value === button.dataset.days));
      });
    }
    updateFlex(); document.addEventListener('nexus:lang', updateFlex);
    function paint() {
      calendar.replaceChildren();
      var heading = document.createElement('div'); heading.className = 'nx-calendar-heading';
      var previous = document.createElement('button'); previous.type = 'button'; previous.className = 'nx-calendar-prev'; previous.textContent = '←'; previous.setAttribute('aria-label', translate('Önceki ay', 'Previous month'));
      previous.disabled = month.getFullYear() === today.getFullYear() && month.getMonth() === today.getMonth();
      previous.addEventListener('click', function () { month.setMonth(month.getMonth() - 1); paint(); });
      var title = document.createElement('strong'); title.textContent = new Intl.DateTimeFormat(locale(), { month: 'long', year: 'numeric' }).format(month);
      var next = document.createElement('button'); next.type = 'button'; next.className = 'nx-calendar-next'; next.textContent = '→'; next.setAttribute('aria-label', translate('Sonraki ay', 'Next month'));
      next.disabled = month.getFullYear() === maxDate.getFullYear() && month.getMonth() === maxDate.getMonth();
      next.addEventListener('click', function () { month.setMonth(month.getMonth() + 1); paint(); });
      heading.append(previous, title, next); calendar.appendChild(heading);
      var days = document.createElement('div'); days.className = 'nx-calendar-weekdays';
      var firstMonday = new Date(2024, 0, 1);
      for (var weekday = 0; weekday < 7; weekday++) {
        var day = new Date(firstMonday); day.setDate(day.getDate() + weekday);
        var caption = document.createElement('span'); caption.textContent = new Intl.DateTimeFormat(locale(), { weekday: 'short' }).format(day); days.appendChild(caption);
      }
      calendar.appendChild(days);
      var grid = document.createElement('div'); grid.className = 'nx-calendar-grid';
      var offset = (month.getDay() + 6) % 7;
      var total = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
      for (var blank = 0; blank < offset; blank++) grid.appendChild(document.createElement('span'));
      for (var dateNo = 1; dateNo <= total; dateNo++) {
        let date = new Date(month.getFullYear(), month.getMonth(), dateNo);
        var button = document.createElement('button'); button.type = 'button'; button.className = 'nx-calendar-day'; button.textContent = String(dateNo);
        button.setAttribute('aria-label', new Intl.DateTimeFormat(locale(), { day: 'numeric', month: 'long', year: 'numeric' }).format(date));
        button.disabled = date < today || date > maxDate;
        if (same(date, start)) button.classList.add('is-start');
        if (same(date, end)) button.classList.add('is-end');
        if (start && end && date > start && date < end) button.classList.add('is-between');
        if (same(date, today)) button.classList.add('is-today');
        button.addEventListener('click', function () {
          if (!start || end || date <= start) { start = date; end = null; }
          else if (Math.round((date - start) / 86400000) <= 31) end = date;
          else { start = date; end = null; }
          startInput.value = iso(start); endInput.value = iso(end);
          startInput.dispatchEvent(new Event('change', { bubbles: true }));
          endInput.dispatchEvent(new Event('change', { bubbles: true }));
          paint(); onChange(start, end);
        });
        grid.appendChild(button);
      }
      calendar.appendChild(grid);
      var hint = document.createElement('p'); hint.className = 'nx-calendar-hint';
      hint.textContent = !start || end ? translate('Giriş tarihini seçin', 'Select check-in date') : translate('Çıkış tarihini seçin (en fazla 31 gece)', 'Select check-out date (up to 31 nights)');
      calendar.appendChild(hint);
    }
    paint();
    document.addEventListener('nexus:lang', paint);
    return { refresh: function () { start = parse(startInput.value); end = parse(endInput.value); if (start) month = new Date(start.getFullYear(), start.getMonth(), 1); paint(); } };
  }
  function initMobile() {
    var panel = document.querySelector('.nx-mobile-search-panel'); if (!panel) return;
    var oldFields = panel.querySelector('.nx-trip-dates'); if (!oldFields) return;
    var start = oldFields.querySelector('[name="check_in"]'), end = oldFields.querySelector('[name="check_out"]');
    start.required = false; end.required = false;
    var trigger = document.createElement('button'); trigger.type = 'button'; trigger.className = 'nx-date-trigger';
    trigger.innerHTML = '<span class="nx-date-question"></span><strong class="nx-date-summary"></strong>';
    oldFields.before(trigger);
    var wrapper = document.createElement('div'); wrapper.className = 'nx-calendar-wrap'; wrapper.hidden = true; oldFields.after(wrapper);
    var guestSection = panel.querySelector('.nx-trip-guests');
    var ageSection = panel.querySelector('.nx-trip-ages');
    var guestTrigger = document.createElement('button'); guestTrigger.type = 'button'; guestTrigger.className = 'nx-guest-trigger';
    guestTrigger.innerHTML = '<span class="nx-guest-question"></span><strong class="nx-guest-summary"></strong>';
    guestSection.before(guestTrigger);
    guestSection.hidden = true; ageSection.hidden = true;
    function guestSummary() {
      var adults = Number(panel.querySelector('[name="adults"]').value || 1);
      var children = Number(panel.querySelector('[name="children"]').value || 0);
      var infants = Number(panel.querySelector('[name="infants"]').value || 0);
      guestTrigger.querySelector('.nx-guest-question').textContent = translate('Misafirler', 'Guests');
      guestTrigger.querySelector('.nx-guest-summary').textContent = (adults + children + infants) + ' ' + translate('Misafir', 'Guests') + ' · ' + adults + ' ' + translate('Yetişkin', 'Adults');
    }
    guestTrigger.addEventListener('click', function () {
      guestSection.hidden = !guestSection.hidden; ageSection.hidden = guestSection.hidden;
      if (!guestSection.hidden) setTimeout(function () { guestTrigger.scrollIntoView({ behavior: 'smooth', block: 'start' }); }, 30);
    });
    function summary(a, b) {
      trigger.querySelector('.nx-date-question').textContent = translate('Ne zaman?', 'When?');
      trigger.querySelector('.nx-date-summary').textContent = a && b ? label(a) + ' – ' + label(b) : (a ? label(a) + ' →' : translate('Tarih ekleyin', 'Add dates'));
    }
    function selectionChanged(a, b) {
      summary(a, b);
      if (a && b) { wrapper.hidden = true; guestSection.hidden = false; ageSection.hidden = false; guestTrigger.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
    }
    var calendar = createCalendar(wrapper, start, end, selectionChanged);
    trigger.addEventListener('click', function () {
      wrapper.hidden = !wrapper.hidden;
      if (!wrapper.hidden) {
        calendar.refresh();
        setTimeout(function () { trigger.scrollIntoView({ behavior: 'smooth', block: 'start' }); }, 30);
      }
    });
    panel.querySelector('.nx-search-clear').addEventListener('click', function () { wrapper.hidden = true; guestSection.hidden = true; ageSection.hidden = true; summary(null, null); calendar.refresh(); guestSummary(); });
    document.addEventListener('nexus:lang', function () { summary(parse(start.value), parse(end.value)); guestSummary(); });
    document.addEventListener('nexus:guests-changed', guestSummary);
    summary(parse(start.value), parse(end.value));
    guestSummary();
  }
  function initDesktop() {
    document.querySelectorAll('.hero-search-form .datepicker').forEach(function (picker) {
      var form = picker.closest('form'); if (!form) return;
      var start = form.querySelector('[name="checkin"]'), end = form.querySelector('[name="checkout"]'); if (!start || !end) return;
      start.value = ''; end.value = '';
      var parent = picker.closest('[id]');
      var trigger = parent && document.querySelector('[aria-controls="' + parent.id + '"]');
      var labelNode = trigger && trigger.querySelector('.block.font-semibold');
      if (labelNode) { labelNode.removeAttribute('data-home-i18n'); labelNode.removeAttribute('data-home-dynamic-key'); }
      if (trigger) trigger.addEventListener('click', function () {
        setTimeout(function () { if (parent && !parent.hidden) parent.scrollIntoView({ behavior: 'smooth', block: 'center' }); }, 50);
      });
      picker.replaceChildren(); picker.classList.add('nx-calendar-host');
      createCalendar(picker, start, end, function (a, b) {
        if (labelNode) labelNode.textContent = a && b ? label(a) + ' – ' + label(b) : a ? label(a) + ' →' : translate('Tarih ekleyin', 'Add dates');
        if (a && b && parent) { parent.hidden = true; parent.style.display = 'none'; if (trigger) trigger.setAttribute('aria-expanded', 'false'); }
      });
      if (labelNode) labelNode.textContent = translate('Tarih ekleyin', 'Add dates');
      document.addEventListener('nexus:lang', function () {
        if (labelNode) labelNode.textContent = start.value && end.value ? label(parse(start.value)) + ' – ' + label(parse(end.value)) : translate('Tarih ekleyin', 'Add dates');
      });
    });
  }
  function initContact() {
    document.querySelectorAll('.contact-page .inquiry-form').forEach(function (form) {
      var start = form.querySelector('input[name="check_in"]');
      var end = form.querySelector('input[name="check_out"]');
      var fields = start && start.closest('.form-grid-2');
      if (!start || !end || !fields) return;
      fields.classList.add('nx-contact-native-dates');
      var trigger = document.createElement('button'); trigger.type = 'button'; trigger.className = 'nx-date-trigger';
      trigger.innerHTML = '<span class="nx-date-question"></span><strong class="nx-date-summary"></strong>';
      fields.before(trigger);
      var wrapper = document.createElement('div'); wrapper.className = 'nx-calendar-wrap'; wrapper.hidden = true; fields.after(wrapper);
      function summary(a, b) {
        trigger.querySelector('.nx-date-question').textContent = translate('Seyahat tarihleri', 'Travel dates');
        trigger.querySelector('.nx-date-summary').textContent = a && b ? label(a) + ' – ' + label(b) : translate('Tarih ekleyin', 'Add dates');
        if (a && b) wrapper.hidden = true;
      }
      var calendar = createCalendar(wrapper, start, end, summary);
      trigger.addEventListener('click', function () { wrapper.hidden = !wrapper.hidden; if (!wrapper.hidden) calendar.refresh(); });
      document.addEventListener('nexus:lang', function () { summary(parse(start.value), parse(end.value)); });
      summary(parse(start.value), parse(end.value));
    });
  }
  function init() { initMobile(); initDesktop(); initContact(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true }); else init();
})();
