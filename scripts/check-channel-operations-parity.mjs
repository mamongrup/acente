import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
const agency = fileURLToPath(new URL('../',import.meta.url));
const nexus = process.env.NEXUS_PROJECT_ROOT || resolve(agency,'../Nexustraveltech');
const read = (root,path) => readFileSync(resolve(root,path),'utf8').replaceAll('\r\n','\n');
const contract = JSON.parse(read(agency,'contracts/channel-operations.v1.json'));
assert.deepEqual(JSON.parse(read(nexus,'contracts/channel-operations.v1.json')),contract,'Operation contract differs');
for (const path of ['scripts/lib/calendar-parser.mjs','scripts/lib/calendar-fetch.mjs','test/calendar-parser.test.mjs']) {
  assert.equal(read(agency,path),read(nexus,path),`${path} differs`);
}
const agencyClient=read(agency,'src/nexus_agency/ai_client.gleam');
const nexusClient=read(nexus,'src/nexus/ai_client.gleam');
const reviewEnd=source => source.slice(source.indexOf('/// Review only'),source.indexOf('\n}',source.indexOf('pub fn validate_listing_review'))+2).trim();
// Formatting may differ; retain complete string literals and all meaningful tokens.
const tokens = source => (source.match(/"(?:\\.|[^"\\])*"|[^\s,]+/g)||[]).join('');
assert.equal(tokens(reviewEnd(agencyClient)),tokens(reviewEnd(nexusClient)),'AI review prompt or evidence validation differs');
assert.equal(contract.calendar.end_date,'exclusive');
assert.equal(contract.delivery.competitor_connection_required,false);
for(const [root,schema] of [[agency,'agency'],[nexus,'inventory']]){
  const worker=read(root,'scripts/calendar-worker.mjs');
  assert.ok(worker.includes(`${schema}.claim_external_calendars`));
  assert.ok(worker.includes(`${schema}.complete_external_calendar`));
}
console.log('Shared operations parity passed: contract, calendar parser/network policy, AI review and worker adapters.');
