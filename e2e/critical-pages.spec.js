const { test, expect } = require('@playwright/test');
const { LISTING_TITLE } = require('./critical-pages-fixture');

const tenantId = process.env.E2E_CRITICAL_TENANT_ID;
const listingId = process.env.E2E_CRITICAL_LISTING_ID;
const isolatedTenantId = process.env.E2E_CRITICAL_ISOLATED_TENANT_ID;
const requestIdPattern = /^req-[A-Za-z0-9_-]{24}$/;

test.beforeAll(() => {
  // Keep test discovery (`playwright test --list`) read-only. Global setup
  // supplies these IDs only when the tests actually run.
  expect(tenantId && listingId && isolatedTenantId,
    'Critical-page fixture IDs were not provided by global setup.').toBeTruthy();
});

const criticalPages = [
  { name: 'home', path: `/?tenant=${tenantId}` },
  {
    name: 'category',
    path: `/otel?tenant=${tenantId}`,
    // The category landing renders its managed filters and listing preview.
    fixtureLocator: '.category-demo-filter',
    fixtureText: 'E2E Konaklama tipi',
  },
  {
    name: 'listing-detail',
    path: `/urunler/${listingId}?tenant=${tenantId}`,
    fixtureLocator: 'main.product-detail h1',
  },
];

for (const entry of criticalPages) {
  test(`critical page contract: ${entry.name}`, async ({ page }) => {
    const response = await page.goto(entry.path, { waitUntil: 'domcontentloaded' });
    expect(response).not.toBeNull();
    expect(response.status()).toBe(200);
    expect(response.headers()['x-request-id']).toMatch(requestIdPattern);
    expect(response.headers()['cross-origin-opener-policy']).toBe('same-origin');
    expect(response.headers()['x-permitted-cross-domain-policies']).toBe('none');
    expect(response.headers()['x-content-type-options']).toBe('nosniff');
    await expect(page.locator('header.chisfis-header-root')).toHaveCount(1);
    await expect(page.locator('footer.nx-site-footer')).toHaveCount(1);
    await expect(page.locator('main')).toHaveCount(1);
    if (entry.fixtureLocator) {
      await expect(page.locator(entry.fixtureLocator)).toContainText(
        entry.fixtureText || LISTING_TITLE,
        { timeout: 20_000 },
      );
    }
  });
}

test('critical page contract: managed category filter shows the matching listing', async ({ page }) => {
  await page.goto(`/otel?tenant=${tenantId}`);
  const group = page.locator('.category-filter-dropdown').filter({ hasText: 'E2E Konaklama tipi' });
  await expect(group).toHaveCount(1, { timeout: 20_000 });
  await group.locator('summary').click();
  const option = group.getByRole('checkbox', { name: 'E2E Otel' });
  await expect(option).toBeVisible();
  await option.check();
  await expect(page.locator('main')).toContainText(LISTING_TITLE);
});

test('critical page contract: listing detail is tenant-isolated', async ({ request }) => {
  const response = await request.get(`/urunler/${listingId}?tenant=${isolatedTenantId}`);
  expect(response.status()).toBe(404);
  expect(response.headers()['x-request-id']).toMatch(requestIdPattern);
  expect(await response.text()).not.toContain(LISTING_TITLE);
});

test('critical page contract: unknown listing returns 404', async ({ request }) => {
  const unknownListingId = '00000000-0000-4000-8000-000000000002';
  const response = await request.get(`/urunler/${unknownListingId}?tenant=${tenantId}`);
  expect(response.status()).toBe(404);
  expect(response.headers()['x-request-id']).toMatch(requestIdPattern);
  expect(await response.text()).not.toContain(LISTING_TITLE);
});

test('critical page contract: supplied request id is preserved', async ({ request }) => {
  const requestId = 'e2e-critical-pages-correlation';
  const response = await request.get(`/?tenant=${tenantId}`, {
    headers: { 'x-request-id': requestId },
  });
  expect(response.status()).toBe(200);
  expect(response.headers()['x-request-id']).toBe(requestId);
});
