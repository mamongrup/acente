import ical from 'node-ical';
import { createHash } from 'node:crypto';
import { parentPort, workerData } from 'node:worker_threads';

const day = (date, timezone) => {
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(date).map(p => [p.type, p.value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
};
const plusDay = value => new Date(Date.parse(value + 'T00:00:00Z') + 86400000).toISOString().slice(0, 10);

export function parseCalendar(text, timezone = 'Europe/Istanbul', now = new Date()) {
  if (Buffer.byteLength(text) > 1024 * 1024 || !/^BEGIN:VCALENDAR\s*$/mi.test(text)
    || !/^END:VCALENDAR\s*$/mi.test(text)) throw new Error('invalid_calendar');
  new Intl.DateTimeFormat('en', { timeZone: timezone });
  const from = new Date(now.getTime() - 730 * 86400000);
  const to = new Date(now.getTime() + 730 * 86400000);
  const parsed = ical.sync.parseICS(text);
  const blocks = new Map();
  const inputEvents = Object.values(parsed).filter(e => e.type === 'VEVENT');
  if (inputEvents.length > 5000) throw new Error('too_many_events');
  for (const event of inputEvents) {
    if (event.status === 'CANCELLED' || event.transparency === 'TRANSPARENT') continue;
    if (!event.start || !event.uid) throw new Error('missing_event_dates');
    const instances = ical.expandRecurringEvent(event, { from, to, expandOngoing: true });
    if (instances.length > 5000) throw new Error('too_many_occurrences');
    for (const instance of instances) {
      if (instance.status === 'CANCELLED' || instance.transparency === 'TRANSPARENT') continue;
      // Floating DATE values are parsed at midnight in the runtime's local zone.
      // Rendering them in UTC shifts dates backwards on servers east of UTC.
      const tz = instance.isFullDay ? (event.start.tz || Intl.DateTimeFormat().resolvedOptions().timeZone) : timezone;
      const start = day(instance.start, tz);
      let end = instance.end ? day(instance.end, tz) : plusDay(start);
      if (!instance.isFullDay && instance.end) {
        const hms = new Intl.DateTimeFormat('en', { timeZone: tz, hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' }).format(instance.end);
        if (hms !== '00:00:00') end = plusDay(end);
      }
      if (end <= start) end = plusDay(start);
      if (Date.parse(end) - Date.parse(start) > 730 * 86400000) throw new Error('event_duration_limit');
      // Hash the UID: never store external guest names or descriptions.
      const key = createHash('sha256').update(String(event.uid) + ':' + instance.start.toISOString()).digest('hex');
      blocks.set(key, { key, start, end });
      if (blocks.size > 5000) throw new Error('too_many_occurrences');
    }
  }
  // An unsupported/broken VEVENT must not silently clear the previous blocks.
  const represented = inputEvents.length + inputEvents.reduce((n, e) => n + new Set(Object.values(e.recurrences || {})).size, 0);
  if ((text.match(/^BEGIN:VEVENT\s*$/gmi) || []).length !== represented) throw new Error('invalid_event_structure');
  return [...blocks.values()];
}

if (parentPort) {
  try { parentPort.postMessage({ events: parseCalendar(workerData.text, workerData.timezone) }); }
  catch { parentPort.postMessage({ error: 'Takvim biçimi veya tarihleri desteklenmiyor. Önceki bloklar korundu.' }); }
}
