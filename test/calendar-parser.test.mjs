import test from 'node:test';
import assert from 'node:assert/strict';
import { parseCalendar } from '../scripts/lib/calendar-parser.mjs';
import { publicAddress, fetchCalendar } from '../scripts/lib/calendar-fetch.mjs';
const now = new Date('2026-10-02T00:00:00Z');
const ics = body => `BEGIN:VCALENDAR\r\nVERSION:2.0\r\n${body}\r\nEND:VCALENDAR\r\n`;
const event = (extra = '') => `BEGIN:VEVENT\r\nUID:one@example.test\r\nDTSTART;VALUE=DATE:20261011\r\nDTEND;VALUE=DATE:20261018\r\n${extra}\r\nEND:VEVENT`;
test('all-day stays preserve the exclusive checkout date', () => {
 const [b] = parseCalendar(ics(event()), 'Europe/Istanbul', now);
 assert.equal(b.start, '2026-10-11'); assert.equal(b.end, '2026-10-18'); assert.equal(b.key.length, 64);
});
test('cancelled and transparent events are not stock blocks', () => {
 assert.equal(parseCalendar(ics(event('STATUS:CANCELLED')), 'Europe/Istanbul', now).length, 0);
 assert.equal(parseCalendar(ics(event('TRANSP:TRANSPARENT')), 'Europe/Istanbul', now).length, 0);
});
test('recurrence exclusions are respected', () => {
 const body='BEGIN:VEVENT\r\nUID:weekly\r\nDTSTART;VALUE=DATE:20261011\r\nDTEND;VALUE=DATE:20261012\r\nRRULE:FREQ=WEEKLY;COUNT=3\r\nEXDATE;VALUE=DATE:20261018\r\nEND:VEVENT';
 const b = parseCalendar(ics(body), 'Europe/Istanbul', now);
 assert.deepEqual(b.map(x => x.start), ['2026-10-11','2026-10-25']);
});
test('timed blocks use the configured business timezone', () => {
 const body='BEGIN:VEVENT\r\nUID:timed\r\nDTSTART:20261010T220000Z\r\nDTEND:20261011T010000Z\r\nEND:VEVENT';
 const [b] = parseCalendar(ics(body), 'Europe/Istanbul', now);
 assert.equal(b.start,'2026-10-11'); assert.equal(b.end,'2026-10-12');
});
test('invalid calendars fail instead of silently deleting previous blocks', () => {
 assert.throws(() => parseCalendar('<html>error</html>'));
 assert.throws(() => parseCalendar(ics('BEGIN:VEVENT\r\nUID:invalid\r\nEND:VEVENT')));
});
test('private network destinations and unsafe URL schemes are refused', async () => {
 for (const ip of ['127.0.0.1','10.1.2.3','169.254.169.254','172.16.0.1','192.168.1.1','100.64.0.1','::1']) assert.equal(publicAddress(ip),false);
 assert.equal(publicAddress('8.8.8.8'),true);
 await assert.rejects(fetchCalendar('http://127.0.0.1/calendar.ics'));
 await assert.rejects(fetchCalendar('https://127.0.0.1/calendar.ics'));
 await assert.rejects(fetchCalendar('https://user:password@example.com/calendar.ics'));
});
