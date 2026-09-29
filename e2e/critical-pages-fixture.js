const { randomUUID } = require('node:crypto');
const { existsSync, readFileSync } = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const TENANT_SLUG = 'e2e-critical-pages';
const ISOLATED_TENANT_SLUG = 'e2e-critical-pages-isolated';
const LISTING_CODE = 'E2E-CRITICAL-HOTEL';
const LISTING_TITLE = 'E2E Contract Hotel';
const ADMIN_EMAIL = 'e2e-mobile-layout-admin@nexus.local';
const ADMIN_PASSWORD = 'e2e-critical-admin-password';

function loadLocalEnv() {
  const envPath = path.resolve(__dirname, '..', '.env');
  if (!existsSync(envPath)) return;

  for (const rawLine of readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const separator = line.indexOf('=');
    if (separator < 1) continue;
    const key = line.slice(0, separator).trim();
    if (process.env[key] === undefined) process.env[key] = line.slice(separator + 1).trim();
  }
}

function psqlExecutable() {
  if (process.env.PSQL_EXECUTABLE) return process.env.PSQL_EXECUTABLE;
  const laragon = 'C:/laragon/bin/postgresql/postgresql/bin/psql.exe';
  return process.platform === 'win32' && existsSync(laragon) ? laragon : 'psql';
}

function runSql(sql, action) {
  loadLocalEnv();

  const required = ['PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER'];
  const missing = required.filter((key) => !process.env[key]);
  if (missing.length) {
    throw new Error(`Critical-page fixture requires ${missing.join(', ')} (environment or .env).`);
  }

  const result = spawnSync(psqlExecutable(), [
    '-X', '-w', '-v', 'ON_ERROR_STOP=1', '-At',
    '-h', process.env.PGHOST,
    '-p', process.env.PGPORT,
    '-U', process.env.PGUSER,
    '-d', process.env.PGDATABASE,
  ], { input: sql, encoding: 'utf8', env: process.env });

  if (result.status !== 0) {
    throw new Error(`Critical-page fixture could not be ${action}:\n${result.stderr || result.stdout}`);
  }
  return result.stdout;
}

function seedCriticalPagesFixture() {
  const tenantId = randomUUID();
  const isolatedTenantId = randomUUID();
  const adminUserId = randomUUID();
  const listingId = randomUUID();
  const sql = `
    BEGIN;
    INSERT INTO agency.tenants (id, legal_name, brand_name, slug)
    VALUES ('${tenantId}', 'E2E Critical Pages', 'E2E Critical Pages', '${TENANT_SLUG}')
    ON CONFLICT (slug) DO UPDATE SET
      legal_name = EXCLUDED.legal_name,
      brand_name = EXCLUDED.brand_name;

    INSERT INTO agency.users (
      id, tenant_id, email, display_name, membership_type, active, password_hash
    )
    SELECT
      '${adminUserId}', id, '${ADMIN_EMAIL}', 'E2E Mobile Admin', 'admin', true,
      crypt('${ADMIN_PASSWORD}', gen_salt('bf'))
    FROM agency.tenants WHERE slug = '${TENANT_SLUG}'
    ON CONFLICT (tenant_id, email) DO UPDATE SET
      display_name = EXCLUDED.display_name,
      membership_type = EXCLUDED.membership_type,
      active = true,
      password_hash = EXCLUDED.password_hash,
      failed_login_attempts = 0,
      locked_until = NULL;

    INSERT INTO agency.tenants (id, legal_name, brand_name, slug)
    VALUES ('${isolatedTenantId}', 'E2E Isolated Tenant', 'E2E Isolated Tenant', '${ISOLATED_TENANT_SLUG}')
    ON CONFLICT (slug) DO UPDATE SET
      legal_name = EXCLUDED.legal_name,
      brand_name = EXCLUDED.brand_name;

    INSERT INTO agency.listings (
      id, tenant_id, code, category, title, locality, description, currency,
      price_minor, status, source, metadata, images, amenities, owner_info,
      cancellation_policy
    )
    SELECT
      '${listingId}', id, '${LISTING_CODE}', 'hotel', '${LISTING_TITLE}',
      'Bodrum, Muğla', 'Deterministic critical-page contract fixture.', 'TRY',
      125000, 'published', 'manual',
      '{"contract_fields":{"property_type":"Hotel","room_types":"Standart Oda","board_type":"Oda Kahvaltı","check_in_time":"14:00","check_out_time":"12:00"}}'::jsonb,
      '["/static/chisfis/images/hero-right.webp"]'::jsonb, '[]'::jsonb,
      '{"name":"E2E Fixture"}'::jsonb,
      '{"policy":"Fixture cancellation policy"}'::jsonb
    FROM agency.tenants WHERE slug = '${TENANT_SLUG}'
    ON CONFLICT (tenant_id, code) DO UPDATE SET
      category = EXCLUDED.category,
      title = EXCLUDED.title,
      locality = EXCLUDED.locality,
      description = EXCLUDED.description,
      currency = EXCLUDED.currency,
      price_minor = EXCLUDED.price_minor,
      status = EXCLUDED.status,
      source = EXCLUDED.source,
      metadata = EXCLUDED.metadata,
      images = EXCLUDED.images,
      amenities = EXCLUDED.amenities,
      owner_info = EXCLUDED.owner_info,
      cancellation_policy = EXCLUDED.cancellation_policy,
      updated_at = now();

    INSERT INTO agency.category_filter_groups
      (tenant_id, category_code, group_key, title, display_type, sort_order)
    SELECT id, 'hotel', 'property_type', 'E2E Konaklama tipi', 'chips', 10
    FROM agency.tenants WHERE slug = '${TENANT_SLUG}'
    ON CONFLICT (tenant_id, category_code, group_key) DO UPDATE SET
      title = EXCLUDED.title, active = true;

    INSERT INTO agency.category_filter_items
      (group_id, item_key, title, contract_field_key, contract_value, sort_order)
    SELECT g.id, 'hotel', 'E2E Otel', 'property_type', 'Hotel', 10
    FROM agency.category_filter_groups g
    JOIN agency.tenants t ON t.id = g.tenant_id
    WHERE t.slug = '${TENANT_SLUG}' AND g.category_code = 'hotel'
      AND g.group_key = 'property_type'
    ON CONFLICT (group_id, item_key) DO UPDATE SET
      title = EXCLUDED.title, contract_value = EXCLUDED.contract_value, active = true;
    COMMIT;

    SELECT t.id::text || '|' || l.id::text || '|' || isolated.id::text
    FROM agency.tenants t
    JOIN agency.listings l ON l.tenant_id = t.id AND l.code = '${LISTING_CODE}'
    CROSS JOIN agency.tenants isolated
    WHERE t.slug = '${TENANT_SLUG}' AND isolated.slug = '${ISOLATED_TENANT_SLUG}';
  `;

  const output = runSql(sql, 'created');
  const match = output.match(/([0-9a-f-]{36})\|([0-9a-f-]{36})\|([0-9a-f-]{36})/i);
  if (!match) throw new Error(`Critical-page fixture IDs were not returned:\n${output}`);
  return { tenantId: match[1], listingId: match[2], isolatedTenantId: match[3] };
}

function cleanupCriticalPagesFixture() {
  runSql(`
    BEGIN;
    DELETE FROM agency.category_filter_groups
    WHERE tenant_id IN (
      SELECT id FROM agency.tenants
      WHERE slug IN ('${TENANT_SLUG}', '${ISOLATED_TENANT_SLUG}')
    );
    DELETE FROM agency.listings
    WHERE tenant_id IN (
      SELECT id FROM agency.tenants
      WHERE slug IN ('${TENANT_SLUG}', '${ISOLATED_TENANT_SLUG}')
    );
    DELETE FROM agency.tenants
    WHERE slug IN ('${TENANT_SLUG}', '${ISOLATED_TENANT_SLUG}');
    COMMIT;
  `, 'removed');
}

module.exports = {
  ADMIN_EMAIL,
  ADMIN_PASSWORD,
  LISTING_TITLE,
  TENANT_SLUG,
  cleanupCriticalPagesFixture,
  seedCriticalPagesFixture,
};
