const { test, expect } = require('@playwright/test');

test('seyahat asistanı destek ikonunda arama ve mesajı birleştirir', async ({ page }) => {
  await page.route('**/api/public/concierge?*', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ ok: true, parsed: { summary: 'Kaş tatili' }, listings: [
      { id: 'test-listing', title: 'Kaş Villa', locality: 'Kaş', category: 'holiday_home' },
    ] }),
  }));
  await page.goto('/arac');
  await expect(page.locator('#nexus-concierge-root')).toHaveCount(0);
  await page.locator('.nexus-chat-toggle').click();
  await page.locator('.nexus-chat-choice[data-channel="assistant"]').click();
  await expect(page.locator('.nexus-chat-search')).toBeVisible();
  await page.locator('.nexus-chat-query').fill('Kaş villa');
  await page.locator('.nexus-chat-find').click();
  await expect(page.locator('.nexus-chat-result')).toContainText('Kaş Villa');
  await page.locator('.nexus-chat-tab[data-tab="message"]').click();
  await expect(page.locator('.nexus-chat-name')).toBeVisible();
});

test('mobil destek seçeneği aynı asistan panelini açar', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/arac');
  await expect(page.locator('#nexus-concierge-root')).toHaveCount(0);
  await page.evaluate(() => document.dispatchEvent(new Event('nexus:support-chooser')));
  await page.locator('.nx-support-option[data-channel="assistant"]').click();
  await expect(page.locator('.nexus-chat-search')).toBeVisible();
});
