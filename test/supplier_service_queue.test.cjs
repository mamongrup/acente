const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const host = { innerHTML: '', textContent: '' };
const items = [
  { id: 'confirmed', reference: 'R-1', listing: 'Tur', customer: '<Misafir>', category: 'tour', checkIn: '2026-09-20', status: 'confirmed', serviceTasks: [{ id: 'task-1', title: 'Rehberi doğrula', stage: 'before', status: 'open' }] },
  { id: 'cancelled', reference: 'R-2', listing: 'Otel', customer: 'Başka misafir', category: 'hotel', checkIn: '2026-09-20', status: 'cancelled', serviceTasks: [{ id: 'task-2', title: 'Oda hazırla', stage: 'before', status: 'open' }] },
];
const context = {
  document: { getElementById: () => host },
  fetch: () => Promise.resolve({ ok: true, json: () => Promise.resolve(items) }),
  Intl,
  Date,
  Array,
  Number,
  Error,
};
vm.runInNewContext(fs.readFileSync('priv/static/supplier-bookings.js', 'utf8'), context);
setImmediate(() => {
  assert.match(host.innerHTML, /Hizmet iş sırası/);
  assert.match(host.innerHTML, /Rehberi doğrula/);
  assert.doesNotMatch(host.innerHTML.split('Rezervasyon<\/th>')[0], /Oda hazırla/);
  assert.match(host.innerHTML, /&lt;Misafir&gt;/);
  assert.doesNotMatch(host.innerHTML, /<Misafir>/);
});
