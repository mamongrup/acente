import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { Worker } from 'node:worker_threads';
import { fileURLToPath } from 'node:url';
import { fetchCalendar } from './lib/calendar-fetch.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
for (const line of readFileSync(root + '.env', 'utf8').split(/\r?\n/)) {
  const match = line.match(/^\s*([^#=]+)\s*=\s*(.*)$/);
  if (match) process.env[match[1].trim()] = match[2].trim();
}
const quote = value => "'" + String(value).replaceAll("'", "''") + "'";
const sql = query => execFileSync('psql', ['-X', '-w', '-At', '-v', 'ON_ERROR_STOP=1',
  '-h', process.env.PGHOST, '-p', process.env.PGPORT, '-U', process.env.PGUSER, '-d', process.env.PGDATABASE],
  { input: query, encoding: 'utf8', timeout: 30000, stdio: ['pipe', 'pipe', 'pipe'] }).trim();

function parse(text, timezone) {
  return new Promise((resolve, reject) => {
    const worker = new Worker(new URL('./lib/calendar-parser.mjs', import.meta.url), {
      workerData: { text, timezone }, resourceLimits: { maxOldGenerationSizeMb: 64 },
    });
    const timer = setTimeout(() => { worker.terminate(); reject(new Error('calendar_parse_timeout')); }, 5000);
    worker.once('message', result => { clearTimeout(timer); worker.terminate(); result.error ? reject(new Error(result.error)) : resolve(result.events); });
    worker.once('error', error => { clearTimeout(timer); reject(error); });
    worker.once('exit', code => { clearTimeout(timer); if (code !== 0) reject(new Error('calendar_parser_exit')); });
  });
}

do {
  try {
    // Claim contains tenant_id and uses FOR UPDATE SKIP LOCKED in PostgreSQL.
    const feeds = JSON.parse(sql('select agency.claim_external_calendars()::text;'));
    for (const feed of feeds) {
      let events = [], error = '';
      try { events = await parse(await fetchCalendar(feed.url), feed.timezone); }
      catch { error = 'Takvim alınamadı veya doğrulanamadı. Önceki bloklar korundu; bağlantıyı kontrol edin.'; }
      sql(`select agency.complete_external_calendar(${quote(feed.tenant_id)}::uuid,${quote(feed.id)}::uuid,${quote(feed.claim)}::uuid,${quote(JSON.stringify(events))}::jsonb,${quote(error)});`);
      console.log(JSON.stringify({ feed: feed.id, tenant_id: feed.tenant_id, status: error ? 'failed' : 'synced', events: events.length }));
    }
  } catch {
    console.error('Takvim işçisi veritabanı işlemini tamamlayamadı.');
    if (process.argv.includes('--once')) process.exitCode = 1;
  }
  if (process.argv.includes('--once')) break;
  await new Promise(resolve => setTimeout(resolve, 60000));
} while (true);
