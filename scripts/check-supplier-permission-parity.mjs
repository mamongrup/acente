import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const agencyRoot = resolve(import.meta.dirname, '..');
const nexusRoot = process.env.NEXUS_PROJECT_ROOT || resolve(agencyRoot, '..', 'Nexustraveltech');
const psql = existsSync('C:/laragon/bin/postgresql/postgresql/bin/psql.exe')
  ? 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe' : 'psql';

function config(root) {
  const file = resolve(root, '.env');
  if (!existsSync(file)) throw new Error(`Database configuration missing: ${root}`);
  const values = {};
  for (const raw of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    const index = line.indexOf('=');
    if (index > 0 && !line.startsWith('#')) values[line.slice(0, index).trim()] = line.slice(index + 1).trim();
  }
  return values;
}

function query(settings, sql) {
  const result = spawnSync(psql, ['-X', '-w', '-At', '-v', 'ON_ERROR_STOP=1',
    '-h', settings.PGHOST, '-p', settings.PGPORT,
    '-U', settings.PGUSER, '-d', settings.PGDATABASE, '-c', sql], {
    encoding: 'utf8',
    env: { ...process.env, PGPASSWORD: settings.PGPASSWORD },
  });
  if (result.status !== 0) throw new Error('Supplier permission database query failed.');
  return result.stdout.replaceAll('\r', '').trim();
}

const agency = config(agencyRoot);
const nexus = config(nexusRoot);
const agencyFunction = 'agency.role_allows_supplier_permission(text,text)';
const nexusFunction = 'onboarding.role_allows_supplier_permission(text,text)';
const sources = [
  query(agency, `select pg_get_functiondef('${agencyFunction}'::regprocedure)`),
  query(nexus, `select pg_get_functiondef('${nexusFunction}'::regprocedure)`),
];
const roles = [...new Set(sources.flatMap(source =>
  [...source.matchAll(/'([a-z_]+)'/g)].map(match => match[1])))].sort();
roles.push('unknown_role');
const contract = JSON.parse(readFileSync(resolve(agencyRoot, 'contracts', 'supplier-listing-contract.v1.json'), 'utf8'));
const permissions = [...new Set(Object.values(contract.supplier_panel_module_details)
  .flatMap(module => module.permissions))].sort();
permissions.push('supplier.unknown.action');
assert.ok(roles.length > 5 && permissions.length > 20, 'Permission matrix is unexpectedly small');

const quote = value => `'${value.replaceAll("'", "''")}'`;
const roleValues = roles.map(role => `(${quote(role)})`).join(',');
const permissionValues = permissions.map(permission => `(${quote(permission)})`).join(',');
function decisions(settings, schema) {
  const permissionSql = `with roles(role) as (values ${roleValues}), permissions(permission) as (values ${permissionValues})
    select role||'|'||permission||'|'||case when ${schema}.role_allows_supplier_permission(role,permission)
      then 'true' else 'false' end from roles cross join permissions order by role,permission`;
  const anySql = `with roles(role) as (values ${roleValues}), lists(value) as (values
    (''),(${quote(permissions[0])}),(${quote(`${permissions[0]},supplier.unknown.action`)}),
    ('supplier.unknown.action'))
    select role||'|any:'||value||'|'||case when ${schema}.role_allows_any_supplier_permission(role,value)
      then 'true' else 'false' end from roles cross join lists order by role,value`;
  return [...query(settings, permissionSql).split('\n'), ...query(settings, anySql).split('\n')];
}

const agencyDecisions = decisions(agency, 'agency');
const nexusDecisions = decisions(nexus, 'onboarding');
const mismatches = agencyDecisions.filter((value, index) => value !== nexusDecisions[index]);
assert.equal(agencyDecisions.length, nexusDecisions.length, 'Permission decision count differs');
assert.deepEqual(mismatches, [], `Permission decision mismatches: ${mismatches.slice(0, 8).join(', ')}`);
assert.ok(agencyDecisions.includes('owner|supplier.unknown.action|false'), 'Unknown permissions must be denied');
console.log(`Supplier permission parity passed: ${roles.length} roles, ${permissions.length} permissions, ${agencyDecisions.length} decisions.`);
