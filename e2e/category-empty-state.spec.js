const { test, expect } = require('@playwright/test');

test('empty yacht category keeps its own content without an empty-listing warning', async ({ page }) => {
  await page.route('**/api/public/listings?**', async (route) => {
    if (route.request().url().includes('kategori=yacht')) {
      await route.fulfill({ status: 200, contentType: 'application/json', body: '[]' });
    } else {
      await route.continue();
    }
  });

  await page.goto('/yat');
  await expect(page.locator('body')).not.toHaveClass(/category-results-pending/);
  await expect(page.locator('.category-page main .category-benefits')).toBeVisible();
  await expect(page.getByText('Bu kategoride henüz yayınlanmış ilan bulunmuyor.')).toHaveCount(0);
  await expect(page.locator('.category-listing-preview')).toHaveCount(0);
});

test('category benefits use the selected language and do not promise instant approval', async ({ page, context }) => {
  const origin = `http://127.0.0.1:${process.env.APP_PORT || 8082}`;
  await context.addCookies([{ name: 'nexus_lang', value: 'en', url: origin }]);
  await page.goto('/yat');
  const benefits = page.locator('.category-benefits');
  await expect(benefits).toBeVisible();
  await expect(benefits.getByText('Compare prices')).toBeVisible();
  await expect(benefits.getByText('Booking tracking')).toBeVisible();
  await expect(benefits.getByText('Instant confirmation')).toHaveCount(0);
});
