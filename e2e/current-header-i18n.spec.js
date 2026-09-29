const { test, expect } = require('@playwright/test');

const origin = `http://127.0.0.1:${process.env.APP_PORT || 8082}`;
const names = {
  tr: ['Konaklama', 'Ana sayfa'],
  en: ['Stays', 'Home Page'],
  de: ['Unterkünfte', 'Startseite'],
  ru: ['Проживание', 'Главная'],
  fr: ['Séjours', 'Accueil'],
  zh: ['住宿', '首页'],
};

test('current travel and template menus follow the storefront language', async ({ page, context }) => {
  for (const [lang, expected] of Object.entries(names)) {
    await context.clearCookies();
    await context.addCookies([{ name: 'nexus_lang', value: lang, url: origin }]);
    await page.goto('/');
    await page.waitForFunction((code) => window.NEXUS_LOCALE?.lang === code, lang);

    await page.locator('#popover-button-1').click();
    await expect(page.locator('#popover-panel-1 .nc-travel__item strong').first()).toHaveText(expected[0]);
    await page.locator('#popover-button-2').click();
    await expect(page.locator('#popover-panel-2 .nc-pop__head').first()).toHaveText(expected[1]);
  }
});

test('open travel menu changes language without losing its open state', async ({ page, context }) => {
  await context.addCookies([{ name: 'nexus_lang', value: 'en', url: origin }]);
  await page.goto('/');
  await page.locator('#popover-button-1').click();
  await expect(page.locator('#popover-panel-1 .nc-travel__item strong').first()).toHaveText('Stays');
  await page.evaluate(() => document.dispatchEvent(new CustomEvent('nexus:lang', { detail: { lang: 'tr' } })));
  await expect(page.locator('#popover-panel-1')).toHaveAttribute('data-state', 'open');
  await expect(page.locator('#popover-panel-1 .nc-travel__item strong').first()).toHaveText('Konaklama');
});
