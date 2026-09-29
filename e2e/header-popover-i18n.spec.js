// Current desktop header contract. The former guest-counter popover moved to
// the hero search form; this file verifies the menus that actually exist.
const { test, expect } = require('@playwright/test');

const origin = `http://127.0.0.1:${process.env.APP_PORT || 8082}`;
const copy = {
  en: { notice: 'Notifications', empty: 'You have no new notifications.', signin: 'Sign in' },
  tr: { notice: 'Bildirimler', empty: 'Yeni bildiriminiz yok.', signin: 'Giriş yap' },
  de: { notice: 'Benachrichtigungen', empty: 'Sie haben keine neuen Benachrichtigungen.', signin: 'Anmelden' },
  ru: { notice: 'Уведомления', empty: 'У вас нет новых уведомлений.', signin: 'Войти' },
};

test.describe('desktop header popover translations', () => {
  test.use({ viewport: { width: 1280, height: 900 } });

  test('notification and account menus render in the selected language', async ({ page, context }) => {
    for (const [lang, expected] of Object.entries(copy)) {
      await context.clearCookies();
      await context.addCookies([{ name: 'nexus_lang', value: lang, url: origin }]);
      await page.goto('/');
      await page.waitForFunction((code) => window.NEXUS_LOCALE?.lang === code, lang);
      await page.locator('#popover-button-4').click();
      await expect(page.locator('#popover-panel-4 .nc-pop__head')).toHaveText(expected.notice);
      await expect(page.locator('#popover-panel-4 .nc-pop__empty p')).toHaveText(expected.empty);
      await page.locator('#popover-button-5').click();
      await expect(page.locator('#popover-panel-5 .nc-pop__link').nth(1)).toHaveText(expected.signin);
    }
  });

  test('an open menu refreshes when language changes', async ({ page, context }) => {
    await context.addCookies([{ name: 'nexus_lang', value: 'en', url: origin }]);
    await page.goto('/');
    await page.locator('#popover-button-4').click();
    await expect(page.locator('#popover-panel-4 .nc-pop__head')).toHaveText('Notifications');
    await page.evaluate(() => document.dispatchEvent(new CustomEvent('nexus:lang', { detail: { lang: 'ru' } })));
    await expect(page.locator('#popover-panel-4')).toHaveAttribute('data-state', 'open');
    await expect(page.locator('#popover-panel-4 .nc-pop__head')).toHaveText('Уведомления');
  });

  test('category links remain navigable after changing language', async ({ page, context }) => {
    await context.addCookies([{ name: 'nexus_lang', value: 'en', url: origin }]);
    await page.goto('/');
    await page.locator('#popover-button-2').click();
    const links = page.locator('#popover-panel-2 a.nc-pop__link[href^="/"]');
    await expect(links.first()).toBeVisible();
    expect(await links.count()).toBeGreaterThanOrEqual(5);
    await page.evaluate(() => document.dispatchEvent(new CustomEvent('nexus:lang', { detail: { lang: 'de' } })));
    await expect(links.first()).toBeVisible();
    expect(await links.first().getAttribute('href')).not.toContain('/kategori/');
  });
});
