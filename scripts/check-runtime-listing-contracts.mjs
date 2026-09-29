import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';

const root = resolve(import.meta.dirname, '..');
const peer = process.env.NEXUS_PROJECT_ROOT || resolve(root, '..', 'Nexustraveltech');
const categories = JSON.parse(readFileSync(resolve(root,'contracts/catalog-categories.v1.json'),'utf8')).categories.map(x => x.code);
const pg = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe';

function envFor(project) {
  const file = resolve(project,'.env');
  if (!existsSync(file)) throw Error(`${project}: veritabanı ayarları bulunamadı`);
  const env = {...process.env};
  for (const line of readFileSync(file,'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*([^#=]+)\s*=\s*(.*)\s*$/);
    if (match) env[match[1].trim()] = match[2].trim();
  }
  return env;
}
function query(env, sql) {
  return execFileSync(pg,['-X','-w','-At','-v','ON_ERROR_STOP=1','-h',env.PGHOST,'-p',env.PGPORT,'-U',env.PGUSER,'-d',env.PGDATABASE,'-c',sql],{env,encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
}
function quoted(value) { return `'${value.replaceAll("'","''")}'`; }
const local = envFor(root);
const central = envFor(peer);
const tenants = query(local,"select id::text from agency.tenants order by created_at,id").split(/\r?\n/).filter(Boolean);
assert.ok(tenants.length > 0,'Acente tenantı bulunamadı');

let checks = 0;
for (const tenant of tenants) {
  assert.match(tenant,/^[0-9a-f-]{36}$/,'Geçersiz acente tenant kimliği');
  for (const category of categories) {
    const required = JSON.parse(query(local,`select coalesce(json_agg(field_key order by field_key)::text,'[]') from agency.validate_listing_contract('${tenant}'::uuid,${quoted(category)},'{}'::jsonb)`));
    const nexusRequired = JSON.parse(query(central,`select coalesce(json_agg(field_key order by field_key)::text,'[]') from onboarding.validate_listing_contract(${quoted(category)},'{}'::jsonb)`));
    assert.deepEqual(required,nexusRequired,`${tenant}/${category}: zorunlu ilan alanları farklı`);
  const scenarios = [
    {},
    {contract_fields:Object.fromEntries(required.map(field => [field,'sample']))},
    {contract_fields:Object.fromEntries(required.slice(0,1).map(field => [field,'sample']))}
  ];
    for (const payload of scenarios) {
      const encoded = quoted(JSON.stringify(payload));
      const agencyMissing = JSON.parse(query(local,`select coalesce(json_agg(field_key order by field_key)::text,'[]') from agency.validate_listing_contract('${tenant}'::uuid,${quoted(category)},${encoded}::jsonb)`));
      const nexusMissing = JSON.parse(query(central,`select coalesce(json_agg(field_key order by field_key)::text,'[]') from onboarding.validate_listing_contract(${quoted(category)},${encoded}::jsonb)`));
      assert.deepEqual(agencyMissing,nexusMissing,`${tenant}/${category}: örnek ilan alan doğrulaması farklı`);
      checks++;
    }
  }
}
process.stdout.write(`Çalışan ilan doğrulayıcıları eşit: ${tenants.length} tenant, ${categories.length} kategori, ${checks} örnek.\n`);
