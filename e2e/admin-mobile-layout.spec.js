const { test, expect } = require('@playwright/test');
const { ADMIN_EMAIL, ADMIN_PASSWORD, TENANT_SLUG } = require('./critical-pages-fixture');
const mobilePages = [
  '/admin',
  '/admin/catalog?cat=hotel&view=overview',
  '/admin/reservations',
  '/admin/customers',
  '/admin/categories',
  '/admin/campaigns',
  '/admin/cms',
  '/admin/media',
  '/admin/integrations',
  '/admin/languages',
  '/admin/currencies',
  '/admin/reports',
  '/admin/settings',
];

test.use({ viewport: { width: 390, height: 844 } });

let sessionCookie;

test.beforeAll(async ({ playwright, baseURL }) => {
  const api = await playwright.request.newContext({ baseURL });
  const response = await api.post('/login', {
    form: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD, tenant_slug: TENANT_SLUG },
  });
  expect(response.status()).toBeLessThan(400);
  const state = await api.storageState();
  sessionCookie = state.cookies.find((cookie) => cookie.name === 'agency_session');
  await api.dispose();
  expect(sessionCookie).toBeTruthy();
});

test.beforeEach(async ({ context }) => {
  await context.addCookies([sessionCookie]);
});

for (const path of mobilePages) {
  test(`admin mobile layout: ${path}`, async ({ page }) => {
    const response = await page.goto(path, { waitUntil: 'domcontentloaded' });
    expect(response).not.toBeNull();
    expect(response.status()).toBe(200);
    await expect(page.locator('.mobile-nav-toggle')).toBeVisible();
    await expect(page.locator('.dashboard .sidebar')).toBeHidden();

    const layout = await page.evaluate(() => ({
      viewportWidth: document.documentElement.clientWidth,
      documentWidth: document.documentElement.scrollWidth,
      contentWidth: Math.ceil(
        document.querySelector('.panel-content')?.getBoundingClientRect().width || 0,
      ),
    }));
    expect(layout.documentWidth).toBeLessThanOrEqual(layout.viewportWidth + 1);
    expect(layout.contentWidth).toBeLessThanOrEqual(layout.viewportWidth);
  });
}
