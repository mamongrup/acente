const { test, expect } = require('@playwright/test');

test('control center renders live checks safely and refreshes', async ({ page }) => {
  let calls = 0;
  await page.route('**/admin/control-center/data', (route) => {
    calls += 1;
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        generatedAt: '2026-09-28T10:00:00Z',
        checks: [{ key: 'categories', title: '<img src=x onerror=alert(1)>', status: 'attention', metric: '16/17', detail: 'Eksik kategori', href: '/admin/categories' }],
      }),
    });
  });
  await page.goto('/');
  await page.setContent('<section id="control-center-workspace"><button id="control-center-refresh">Yenile</button><p id="control-center-status"></p><div id="control-center-summary"></div><div id="control-center-results"></div></section>');
  await page.addScriptTag({ path: 'priv/static/control-center.js' });
  await expect(page.locator('#control-center-results')).toContainText('<img src=x onerror=alert(1)>');
  await expect(page.locator('#control-center-results img')).toHaveCount(0);
  await expect(page.locator('#control-center-results a')).toHaveAttribute('href', '/admin/categories');
  await page.locator('#control-center-refresh').click();
  await expect.poll(() => calls).toBe(2);
});
