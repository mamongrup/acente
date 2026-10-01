const { test, expect } = require('@playwright/test');

const routes = ['/', '/otel', '/tatil-evi', '/yat', '/tur', '/aktivite', '/ucus',
  '/arac', '/kruvaziyer', '/hac-umre', '/vize', '/feribot', '/transfer', '/sezlong',
  '/sinema', '/etkinlik', '/restoran', '/otobus', '/iletisim', '/login'];

for (const width of [360, 768]) {
  test(`public pages fit a ${width}px screen`, async ({ page }) => {
    test.setTimeout(120_000);
    await page.setViewportSize({ width, height: 844 });
    for (const path of routes) {
      const response = await page.goto(path);
      expect(response.status(), path).toBeLessThan(400);
      await expect(page.locator('main')).toBeVisible();
      await expect.poll(() => page.evaluate(() =>
        document.documentElement.scrollWidth - innerWidth), { message: path }).toBeLessThanOrEqual(1);
      const smallInputs = await page.locator('input:not([type=hidden]):not([type=checkbox]):not([type=radio]), textarea, select').evaluateAll(nodes =>
        nodes.filter(node => node.getBoundingClientRect().width > 0 &&
          parseFloat(getComputedStyle(node).fontSize) < 16).map(node => node.name || node.id));
      expect(smallInputs, `${path}: controls must avoid focus zoom`).toEqual([]);
    }
  });
}

test('phone menu opens from the header and closes without trapping the page', async ({ page }) => {
  await page.setViewportSize({ width: 360, height: 740 });
  await page.goto('/');
  await page.locator('.mh-menu-btn').click();
  await expect(page.locator('.mobile-menu')).toHaveAttribute('data-state', 'open');
  await expect(page.locator('.mobile-menu__panel')).toBeVisible();
  await page.locator('.mobile-menu__close').click();
  await expect(page.locator('.mobile-menu')).toHaveAttribute('data-state', 'closed');
  await expect(page.locator('html')).not.toHaveClass(/overflow-hidden/);
});
