const { test, expect } = require('@playwright/test');

test('logo ile anasayfaya dönünce hero mozaik yeniden oluşturulmaz', async ({ page }) => {
  await page.addInitScript(() => {
    window.__heroMosaicMoves = 0;
    new MutationObserver(records => records.forEach(record => record.removedNodes.forEach(node => {
      if (node.nodeType === 1 && (node.matches?.('.home-hero-mosaic') || node.querySelector?.('.home-hero-mosaic'))) {
        window.__heroMosaicMoves++;
      }
    }))).observe(document, { subtree: true, childList: true });
  });

  await page.goto('/tur');
  const heroRequests = [];
  const homeDocuments = [];
  page.on('request', request => {
    if (request.url().endsWith('/static/chisfis/images/hero-right.webp')) heroRequests.push(request.url());
    if (request.isNavigationRequest() && new URL(request.url()).pathname === '/') homeDocuments.push(request.url());
  });
  await page.locator('[data-mm-logo]:visible').first().click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.locator('body')).not.toHaveClass(/home-layout-pending/);
  await expect(page.locator('html')).not.toHaveClass(/has-reveal/);
  await expect(page.locator('.home-hero-mosaic img')).toHaveCount(3);
  expect(await page.evaluate(() => window.__heroMosaicMoves)).toBe(0);
  expect(heroRequests).toHaveLength(1);
  expect(homeDocuments).toHaveLength(1);
});
