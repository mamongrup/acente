const { test, expect } = require('@playwright/test');

for (const path of ['/', '/urunler']) {
  test(`public layout is shared on ${path}`, async ({ page }) => {
    await page.goto(path, { waitUntil: 'domcontentloaded' });
    await expect(page.locator('header.chisfis-header-root')).toHaveCount(1);
    await expect(page.locator('footer')).toHaveCount(1);
    await expect(page.locator('#popover-button-1')).toBeVisible();
    await expect(page.locator('#popover-button-2')).toBeVisible();
    await expect(page.locator('#popover-button-3')).toBeVisible();
    await expect(page.locator('#nexus-header-mic')).toBeVisible();

    const locale = page.locator('#popover-button-3');
    // The shared header now uses the site's icon font rather than inline SVG.
    await expect(locale.locator('i.hgi-globe')).toHaveCount(1);
    await expect(locale.locator('i.hgi-money-01')).toHaveCount(1);
    await locale.click();
    await expect(locale).toHaveAttribute('aria-expanded', 'true');
    await expect(page.locator('#popover-panel-3')).toBeVisible();
    await locale.click();
    await expect(locale).toHaveAttribute('aria-expanded', 'false');

    const row = await page.locator('#nexus-header-search').evaluate((el) => {
      const form = el.querySelector('form').getBoundingClientRect();
      const mic = el.querySelector('#nexus-header-mic').getBoundingClientRect();
      return { formTop: form.top, micTop: mic.top, gap: mic.left - form.right };
    });
    expect(Math.abs(row.formTop - row.micTop)).toBeLessThan(3);
    expect(row.gap).toBeGreaterThanOrEqual(0);
  });
}

test('hero category icons contain only Hugeicons glyphs', async ({ page }) => {
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  const tabs = page.locator('.hero-search-form [role="tablist"] [role="tab"]');
  await expect(tabs).toHaveCount(8);
  for (const tab of await tabs.all()) {
    const icon = tab.locator(':scope > i.hgi-stroke');
    await expect(icon).toHaveCount(1);
    await expect(icon).toHaveText('');
    expect(await icon.evaluate((el) => getComputedStyle(el, '::before').content)).toMatch(/^".+"$/);
  }
  await tabs.last().click();
  const menuPosition = await page.locator('.hero-more-menu.is-open').evaluate((menu) => ({
    menuTop: menu.getBoundingClientRect().top,
    railBottom: menu.parentElement.querySelector('[role="tablist"]').getBoundingClientRect().bottom,
  }));
  expect(menuPosition.menuTop).toBeGreaterThan(menuPosition.railBottom);
  const moreIcons = page.locator('.hero-more-menu.is-open i.hgi-stroke');
  await expect(moreIcons).toHaveCount(10);
  for (const icon of await moreIcons.all()) {
    expect(await icon.evaluate((el) => getComputedStyle(el, '::before').content)).toMatch(/^".+"$/);
  }
});

test('location subtitle aligns with its heading', async ({ page }) => {
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  const alignment = await page.locator('.hero-search-form input[name="location"]').evaluate((input) => ({
    headingLeft: input.getBoundingClientRect().left,
    subtitleLeft: input.nextElementSibling.getBoundingClientRect().left,
  }));
  expect(Math.abs(alignment.headingLeft - alignment.subtitleLeft)).toBeLessThanOrEqual(1);
});

test('category navigation uses language-specific clean URLs', async ({ page }) => {
  await page.addInitScript(() => localStorage.setItem('nexus_lang', 'tr'));
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  const holidayHome = page.locator('.hero-search-form [role="tab"][aria-label="Villa"]');
  await expect(holidayHome).toHaveAttribute('href', '/tatil-evi');
  const documentRequests = [];
  page.on('request', (request) => {
    if (request.isNavigationRequest()) documentRequests.push(new URL(request.url()).pathname + new URL(request.url()).search);
  });
  await page.locator('#popover-button-1').click();
  const catalogueHolidayHome = page.locator('#popover-panel-1 a.nc-travel__item').nth(1);
  await expect(catalogueHolidayHome).toHaveAttribute('href', '/tatil-evi');
  await catalogueHolidayHome.click();
  await expect(page).toHaveURL(/\/tatil-evi$/);
  expect(documentRequests).toEqual(['/tatil-evi']);
  const oldRoute = await page.request.get('/kategori/holiday_home');
  expect(oldRoute.status()).toBe(404);
  for (const [lang, slug] of [['de', 'ferienhaus'], ['ru', 'dom-otdyha'], ['fr', 'maison-de-vacances'], ['zh', 'dujiawu']]) {
    expect(await page.evaluate((code) => window.NEXUS_CATEGORY_URL('holiday_home', code), lang)).toBe('/' + slug);
    expect((await page.request.get('/' + slug)).status()).toBe(200);
  }
  expect(await page.evaluate(() => window.NEXUS_CATEGORY_URL('holiday_home', 'en'))).toBe('/holiday-home');
});

test('home keeps the demo body without a second header or footer', async ({ page }) => {
  await page.setViewportSize({ width: 1366, height: 768 });
  await page.goto('/', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('main h1')).toContainText('Hotel, car,');
  await expect(page.locator('main img[src="/static/chisfis/images/hero-right.webp"]')).toHaveCount(1);
  await expect(page.locator('header.chisfis-header-root')).toHaveCount(1);
  await expect(page.locator('footer')).toHaveCount(1);
  await expect(page.locator('main')).toHaveCount(1);
  await expect(page.locator('#search-fab-wrap')).toBeHidden();
  await expect(page.locator('.nexus-chat-toggle')).toBeVisible();
  await page.waitForTimeout(1200);
  const demoGeometry = await page.evaluate(() => {
    const h1 = document.querySelector('main h1').getBoundingClientRect();
    const hero = document.querySelector('main img').getBoundingClientRect();
    return { h1Left: h1.left, heroLeft: hero.left, heroRight: hero.right };
  });
  expect(demoGeometry.h1Left).toBeGreaterThanOrEqual(58);
  expect(demoGeometry.h1Left).toBeLessThanOrEqual(60);
  expect(demoGeometry.heroLeft).toBeGreaterThanOrEqual(696);
  expect(demoGeometry.heroRight).toBeLessThanOrEqual(1308);
});

for (const path of ['/', '/urunler']) {
  test(`all header menus use the demo surface on ${path}`, async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.goto(path, { waitUntil: 'domcontentloaded' });

    for (const number of [1, 2, 3, 4, 5]) {
      const trigger = page.locator(`#popover-button-${number}`);
      const panel = page.locator(`#popover-panel-${number}`);
      await trigger.click();
      await expect(panel).toBeVisible();
      const box = await panel.boundingBox();
      expect(box).not.toBeNull();
      expect(box.x).toBeGreaterThanOrEqual(-1);
      expect(box.x + box.width).toBeLessThanOrEqual(1367);
      if (number === 1) expect(box.width).toBe(320);
      if (number === 2) {
        expect(box.width).toBeGreaterThan(1300);
        expect(box.y).toBeGreaterThanOrEqual(75);
        await expect(panel.locator('.nc-mega > div')).toHaveCount(5);
      }
      if (number === 3) {
        expect(box.width).toBe(384);
        await expect(panel.locator('.mm-pop__tab')).toHaveCount(2);
      }
      await trigger.click();
      await expect(trigger).toHaveAttribute('aria-expanded', 'false');
    }
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow).toBeLessThanOrEqual(1);
  });

  test(`search stretches and header icons align on ${path}`, async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 768 });
    await page.goto(path, { waitUntil: 'domcontentloaded' });
    const geometry = await page.evaluate(() => {
      const box = (selector) => document.querySelector(selector).getBoundingClientRect();
      const search = box('#nexus-header-search');
      const catalog = box('#popover-button-1');
      const categories = box('#popover-button-2');
      const catalogDivider = document.querySelector('#popover-button-1').parentElement.parentElement.previousElementSibling.getBoundingClientRect();
      const locale = box('#popover-button-3');
      return {
        search: { x: search.x, width: search.width, right: search.right, y: search.y },
        catalogRight: catalog.right,
        categoriesLeft: categories.left,
        catalogLeadGap: catalog.left - catalogDivider.right,
        categoriesTrailGap: locale.left - categories.right,
        actions: ['#popover-button-3', '#popover-button-4', '#cart-fab-btn', '#popover-button-5'].map((selector) => {
          const rect = box(selector);
          return { x: rect.x, right: rect.right, width: rect.width, height: rect.height, y: rect.y };
        }),
        notificationIcon: box('#popover-button-4 i.hgi-stroke').width,
        cartIcon: box('#cart-fab-btn i.hgi-stroke').width,
      };
    });
    expect(geometry.search.width).toBeGreaterThan(400);
    expect(geometry.search.x).toBeGreaterThan(geometry.catalogRight);
    expect(geometry.search.right).toBeLessThan(geometry.categoriesLeft);
    expect(Math.abs(geometry.categoriesTrailGap - geometry.catalogLeadGap), JSON.stringify(geometry)).toBeLessThanOrEqual(4);
    for (const action of geometry.actions) {
      expect(action.width).toBeGreaterThanOrEqual(44);
      expect(action.height).toBe(44);
      expect(Math.abs(action.y - geometry.search.y)).toBeLessThan(2);
    }
    expect(geometry.notificationIcon).toBe(geometry.cartIcon);
    for (let index = 1; index < geometry.actions.length; index += 1) {
      expect(geometry.actions[index].x - geometry.actions[index - 1].right).toBeLessThanOrEqual(12);
    }
  });
}
