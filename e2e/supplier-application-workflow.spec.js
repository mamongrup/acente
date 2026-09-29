const { test, expect } = require('@playwright/test');

test('supplier can submit a category application and see its status', async ({ page }) => {
  await page.route('**/admin/supplier-operations/data', (route) => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ role: 'supplier', performance: {}, documents: [], documentTypes: ['tax_certificate'], settlements: [] }),
  }));
  await page.route('**/admin/supplier-operations/application', (route) => {
    if (route.request().method() === 'POST') return route.fulfill({ status: 200, body: 'ok' });
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ applications: [{ category: 'hotel', status: 'submitted', identityStatus: 'pending' }], categories: [{ code: 'hotel', name: 'Otel' }] }),
    });
  });
  await page.goto('/');
  await page.setContent('<div id="supplier-operations-content"></div>');
  await page.addScriptTag({ path: 'priv/static/supplier-operations.js' });
  await expect(page.locator('#supplier-operations-content')).toContainText('Tedarikçi başvurularım');
  await expect(page.locator('form[action="/admin/supplier-operations/application"] select[name="category_code"]')).toContainText('Otel');
  await page.locator('form[action="/admin/supplier-operations/application"] select[name="category_code"]').selectOption('hotel');
  await page.locator('form[action="/admin/supplier-operations/application"] input[required]').evaluateAll((inputs) => inputs.forEach((input) => { if (!input.value) input.value = input.type === 'email' ? 'test@example.invalid' : 'Test value'; }));
  await page.locator('form[action="/admin/supplier-operations/application"] button').click();
  await expect(page.locator('#supplier-application-notice')).toContainText('Başvuru kaydedildi');
});
