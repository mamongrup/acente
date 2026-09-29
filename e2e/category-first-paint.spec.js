const { test, expect } = require('@playwright/test');

const categoryPaths = [
  'otel', 'tatil-evi', 'yat', 'tur', 'aktivite', 'ucus', 'arac',
  'kruvaziyer', 'hac-umre', 'vize', 'feribot', 'transfer', 'sezlong',
  'sinema', 'etkinlik', 'restoran', 'otobus',
];
const visibleTabs = new Set(['otel', 'tatil-evi', 'yat', 'tur', 'aktivite', 'ucus', 'arac', 'otobus']);

test('category rail is correct in the first HTML response', async ({ request }) => {
  for (const path of categoryPaths) {
    const response = await request.get('/' + path);
    expect(response.ok(), path).toBeTruthy();
    const html = await response.text();
    const selected = [...html.matchAll(/<a class="group\/tab[^>]+role="tab" aria-selected="true"[^>]+href="([^"]+)"/g)]
      .map(match => match[1]);
    expect(selected, path).toEqual(visibleTabs.has(path) ? ['/' + path] : []);
  }
});

test('results count appears only after listings resolve', async ({ page }) => {
  await page.route('**/api/public/listings*', async route => {
    await new Promise(resolve => setTimeout(resolve, 1500));
    await route.continue();
  });
  await page.goto('/arac', { waitUntil: 'domcontentloaded' });
  const heading = page.locator('.category-results-head');
  await expect(page.locator('main [role="tab"][aria-selected="true"]')).toHaveAttribute('href', '/arac');
  await expect(heading).toBeHidden();
  await expect(heading).toBeVisible();
  await expect(heading.locator('h1')).toContainText(/\d+ Araç kiralama ilanı/);
});

test('hero search icons keep their SVG size and empty category guide stays absent', async ({ page }) => {
  await page.goto('/arac', { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  const icons = page.locator('.hero-search-form form svg[data-slot="icon"].size-5:visible');
  await expect(icons).toHaveCount(3);
  const sizes = await icons.evaluateAll(nodes => nodes.map(node => ({
    width: Math.round(node.getBoundingClientRect().width),
    height: Math.round(node.getBoundingClientRect().height),
  })));
  expect(sizes).toEqual(Array.from({ length: 3 }, () => ({ width: 28, height: 28 })));
  await expect(page.locator('.hero-search-form form i.hgi-location-01, .hero-search-form form i.hgi-calendar-03, .hero-search-form form i.hgi-user-add-01')).toHaveCount(0);
  await expect(page.locator('.builder-region-places')).toHaveCount(0);

  await page.goto('/blog/gezilesi-yerler', { waitUntil: 'load' });
  await expect(page.locator('.builder-region-places-archive')).toBeVisible();
});
