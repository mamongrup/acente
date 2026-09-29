const { test, expect } = require('@playwright/test');

test('supplier review escapes names and reports a rejected decision', async ({ page }) => {

  await page.route('**/admin/supplier-onboarding/data', (route) => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({
      applications: [{
        id: '00000000-0000-0000-0000-000000000001',
        name: '<img src=x onerror=alert(1)>',
        email: 'supplier@example.invalid',
        categories: 'hotel',
        status: 'submitted',
        identity_status: 'verified',
        document_count: '0',
        submitted_at: '2026-09-28',
        note: '',
      }],
      documents: [],
    }),
  }));
  await page.route('**/admin/supplier-onboarding/decision', (route) => route.fulfill({ status: 409, body: '' }));
  await page.goto('/');
  await page.setContent('<section id="supplier-onboarding-workspace"><button id="supplier-onboarding-refresh" type="button">Yenile</button><div id="supplier-onboarding-status-cards"></div><table><tbody id="supplier-onboarding-body"></tbody></table><div id="supplier-document-review"></div></section>');
  await page.addScriptTag({ path: 'priv/static/supplier-onboarding-admin.js' });
  await expect(page.locator('#supplier-onboarding-body')).toContainText('<img src=x onerror=alert(1)>');
  await expect(page.locator('#supplier-onboarding-body img')).toHaveCount(0);
  await page.locator('#supplier-onboarding-body button').first().click();
  await expect(page.locator('#supplier-onboarding-workspace [role="status"]')).toContainText('Karar mevcut başvuru durumunda uygulanamadı');
});
