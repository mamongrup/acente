const { test, expect } = require('@playwright/test');

const categories = ['hotel', 'holiday_home', 'yacht', 'tour', 'activity', 'flight', 'car', 'cruise', 'pilgrimage', 'visa', 'ferry', 'transfer', 'beach', 'cinema', 'event', 'restaurant', 'bus'];
const listingId = process.env.E2E_CRITICAL_LISTING_ID;
const tenantId = process.env.E2E_CRITICAL_TENANT_ID;
const path = `/urunler/${listingId}?tenant=${tenantId}`;

test('shared detail template supports every canonical category and viewport', async ({ page, request }) => {
  test.setTimeout(90_000);
  const response = await request.get(path);
  expect(response.ok()).toBeTruthy();
  const html = await response.text();
  let category;
  // Exercise the shared browser template without creating 17 database records.
  await page.route('**/detail-template/*', route => route.fulfill({
    contentType: 'text/html', body: html.replace('product-detail category-hotel', `product-detail category-${category}`),
  }));
  await page.route('**/api/public/listings*', route => route.fulfill({ json: [{
    id: listingId, category, currency: 'TRY', priceMinor: 125000,
    amenities: ['wifi'], guestCount: 2, reviewCount: 0,
  }] }));
  for (category of categories) {
    await page.goto(`/detail-template/${category}`);
    await expect(page.locator('main.reference-listing-detail')).toHaveAttribute('data-category', category);
    await expect(page.locator('.reference-detail-amenities')).toContainText('Wi-Fi');
    await expect(page.locator('.reference-community')).toHaveCount(1);
    await expect(page.locator('.detail-breadcrumb')).toBeVisible();
    await expect(page.locator('.reference-detail-facts')).toHaveCount(['holiday_home', 'yacht'].includes(category) ? 1 : 0);
    if (category === 'hotel') {
      await expect(page.locator('.reference-host-line, .reference-owner')).toHaveCount(0);
    }
    for (const width of [1440, 768, 390, 360]) {
      await page.setViewportSize({ width, height: 900 });
      await expect.poll(() => page.locator('.detail-gallery').evaluate(node => node.getBoundingClientRect().height)).toBeGreaterThan(250);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `${category} at ${width}px`).toBeTruthy();
    }
  }
});

test('detail stays usable when catalogue and availability requests fail', async ({ page }) => {
  await page.route('**/api/public/listings*', route => route.abort());
  await page.route('**/availability*', route => route.abort());
  await page.goto(path);
  await expect(page.locator('.reference-community')).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Fiyat bilgileri' })).toHaveCount(1);
  await expect(page.locator('.detail-calendar-note')).toContainText('şu anda alınamıyor');
  await page.locator('.gallery-main').click();
  await expect(page.locator('.chisfis-lightbox')).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.locator('.chisfis-lightbox')).toHaveCount(0);
  await expect(page.locator('#booking-form button[type=submit]')).toBeEnabled();
});

test('inline calendar and booking picker share dates and reject a range over a closed day', async ({ page }) => {
  const date = offset => {
    const d = new Date(); d.setDate(d.getDate() + offset);
    return [d.getFullYear(), String(d.getMonth() + 1).padStart(2, '0'), String(d.getDate()).padStart(2, '0')].join('-');
  };
  await page.route('**/availability*', route => route.fulfill({ json: [
    { day: date(1), available: 2, closed: false },
    { day: date(2), available: 0, closed: true },
    { day: date(3), available: 2, closed: false },
  ] }));
  await page.goto(path);
  await expect(page.locator('.detail-calendar-note')).toContainText('İşaretli günler');
  // Future month navigation also covers execution at the end of a month.
  await page.locator('.detail-calendar-toolbar').getByRole('button', { name: 'Sonraki ay' }).click();
  await page.locator('.detail-calendar-toolbar').getByRole('button', { name: 'Önceki ay' }).click();
  await page.locator(`.detail-calendar-grid [data-date="${date(1)}"]`).click();
  await expect(page.locator(`.detail-calendar-grid [data-date="${date(2)}"]`)).toHaveClass(/is-unavailable/);
  await page.locator(`.detail-calendar-grid [data-date="${date(3)}"]`).click();
  await expect(page.locator('.detail-calendar-note')).toContainText('uygun olmayan gün');
  await expect(page.locator('#booking-form [name=check_out]')).toHaveValue('');
  await expect(page.locator('.chisfis-date-value')).not.toHaveText('Tarih seçin');
  await page.locator(`.detail-calendar-grid [data-date="${date(2)}"]`).click();
  await expect(page.locator('#booking-form [name=check_out]')).toHaveValue(date(2));
  await page.locator('.chisfis-guest-trigger').click();
  await page.locator('[data-target=adults][data-step="1"]').click();
  await expect(page.locator('#booking-form [name=guests]')).toHaveValue('3');
});

test('hotel reservation popovers keep dates and guests without showing pricing', async ({ page }) => {
  const date = offset => {
    const d = new Date(); d.setDate(d.getDate() + offset);
    return [d.getFullYear(), String(d.getMonth() + 1).padStart(2, '0'), String(d.getDate()).padStart(2, '0')].join('-');
  };
  await page.goto(path);
  await expect(page.locator('.detail-sidebar [data-price-minor]')).toBeHidden();
  await expect(page.getByRole('heading', { name: 'Fiyat bilgileri' })).toHaveCount(0);
  await page.locator('.chisfis-date-trigger').click();
  await expect(page.locator('.chisfis-date-panel')).toBeVisible();
  await expect(page.locator('.reference-calendar-month')).toHaveCount(2);
  await page.locator(`.reference-calendar-grid [data-date="${date(1)}"]`).click();
  await page.locator(`.reference-calendar-grid [data-date="${date(4)}"]`).click();
  await expect(page.locator('.chisfis-date-panel')).toBeHidden();
  await expect(page.locator('.reference-booking-summary')).toBeHidden();
  await page.locator('.reference-date-clear').click();
  await expect(page.locator('#booking-form [name=check_in]')).toHaveValue('');
  await expect(page.locator('.reference-booking-summary')).toBeHidden();
  await page.locator('.chisfis-date-trigger').click();
  await page.locator(`.reference-calendar-grid [data-date="${date(1)}"]`).click();
  await page.locator(`.reference-calendar-grid [data-date="${date(4)}"]`).click();
  await page.locator('.chisfis-guest-trigger').click();
  await page.locator('[data-target=adults][data-step="1"]').click();
  await expect(page.locator('#booking-form [name=guests]')).toHaveValue('3');
  await page.keyboard.press('Escape');
  await expect(page.locator('.chisfis-guest-panel')).toBeHidden();
  await page.route('**/rezervasyon?*', route => route.fulfill({ contentType: 'text/html', body: 'Booking continuation' }));
  await page.locator('#booking-form button[type=submit]').click();
  await page.waitForURL('**/rezervasyon?*');
  const params = new URL(page.url()).searchParams;
  expect(params.get('check_in')).toBe(date(1));
  expect(params.get('check_out')).toBe(date(4));
  expect(params.get('guests')).toBe('3');
  expect(params.get('tenant')).toBe(tenantId);
});
