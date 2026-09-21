// Panel (yönetim) i18n katmanı — gerçek tarayıcı testi.
//
// NEDEN: panel bölüm başlıkları ve menü öğeleri Türkçe sabit metindi ve bölüm
// başlığı AYNI ZAMANDA form/varlık dispeç anahtarıydı (`case title { "Bölgeler"
// -> ... }`). Bu paket, dispeç slug'a taşındıktan sonra dilin gerçekten
// çalıştığını ve modüllerin hâlâ yüklendiğini ölçer — çünkü eski kurulumda
// `?lang=en` başlığı çevirseydi yanlış form/asset seçecekti.
//
// Ölçülenler:
//   1) `?lang=` ve `agency_lang` çerezi bölüm başlığını (h1 + kırıntı) değiştirir,
//   2) yan menü öğeleri (Genel bakış / Overview / Übersicht / Обзор) ve
//      inquiries/notifications etiketleri çevrilir,
//   3) mobil tab bar ve topbar dil seçici aria etiketleri çevrilir,
//   4) KATALOG modülleri (06-wizard.css, listing-wizard.js) her dilde yüklenir —
//      başlıkla anahtarlama geri gelirse bu test kırmızı olur.
const { test, expect } = require('@playwright/test');

const PORT = process.env.APP_PORT || 8082;
const ORIGIN = `http://127.0.0.1:${PORT}`;
const CREDS = {
  email: process.env.PANEL_EMAIL || 'acente@nexus.local',
  password: process.env.PANEL_PASSWORD || 'admin123456',
  tenant_slug: '',
};

// Beklenen yerelleştirilmiş metinler (i18n.gleam ile birebir).
const HEADINGS = {
  tr: { catalog: 'Katalog', reservations: 'Rezervasyonlar', first_menu: 'Genel bakış' },
  en: { catalog: 'Catalog', reservations: 'Reservations', first_menu: 'Overview' },
  de: { catalog: 'Katalog', reservations: 'Buchungen', first_menu: 'Übersicht' },
  ru: { catalog: 'Каталог', reservations: 'Бронирования', first_menu: 'Обзор' },
};

let sessionCookie = null;

test.beforeAll(async ({ playwright }) => {
  const api = await playwright.request.newContext({ baseURL: ORIGIN });
  const res = await api.post('/login', { form: CREDS });
  const state = await api.storageState();
  await api.dispose();
  const cookie = (state.cookies || []).find((c) => c.name === 'agency_session');
  if (res.status() >= 400 || !cookie) {
    return; // aşağıdaki testler skip eder
  }
  sessionCookie = cookie;
});

test.beforeEach(async ({ context }) => {
  test.skip(!sessionCookie, 'panel oturumu açılamadı (seed kullanıcı/şifre yok)');
  // API bağlamında alınan oturum çerezini tarayıcı bağlamına taşı.
  await context.addCookies([sessionCookie]);
});

// Dil tercihini çerezle ver (topbar `/set-lang/<code>` akışıyla aynı yol).
async function withLang(context, lang) {
  await context.addCookies([
    { name: 'agency_lang', value: lang, url: ORIGIN },
  ]);
}

test.describe('Panel i18n — başlıklar ve menü öğeleri', () => {
  test('bölüm başlığı ve kırıntı seçili dilde basılır', async ({ page, context }) => {
    for (const lang of ['tr', 'en', 'de', 'ru']) {
      await withLang(context, lang);
      await page.goto(`/admin/catalog?lang=${lang}`);
      await expect(page.locator('h1').first()).toHaveText(HEADINGS[lang].catalog);
      await expect(page.locator('.crumb-wrap .highlight').first()).toHaveText(
        HEADINGS[lang].catalog,
      );

      await page.goto(`/admin/reservations?lang=${lang}`);
      await expect(page.locator('h1').first()).toHaveText(
        HEADINGS[lang].reservations,
      );
    }
  });

  test('yan menü, inquiries/notifications ve mobil tab bar etiketleri çevrilir', async ({
    page,
    context,
  }) => {
    for (const lang of ['tr', 'en', 'de', 'ru']) {
      await withLang(context, lang);
      await page.goto(`/admin/catalog?lang=${lang}`);

      // İlk menü öğesi (Genel bakış / Overview / Übersicht / Обзор)
      await expect(
        page.locator('.sidebar-menu-link').first(),
      ).toHaveText(HEADINGS[lang].first_menu);

      // Sayfa bölümünde olmayan iki yeni menü etiketi
      const expected = {
        tr: ['Teklif Talepleri', 'Bildirim Merkezi'],
        en: ['Quote requests', 'Notification center'],
        de: ['Angebotsanfragen', 'Benachrichtigungszentrum'],
        ru: ['Запросы предложений', 'Центр уведомлений'],
      }[lang];
      const labels = await page.$$eval(
        '.sidebar-menu-link',
        (els) => els.map((e) => e.textContent.trim()),
      );
      expect(labels).toContain(expected[0]);
      expect(labels).toContain(expected[1]);

      // Mobil tab bar aria etiketi (dile göre)
      const mobileMenu = {
        tr: 'Mobil menü',
        en: 'Mobile menu',
        de: 'Mobiles Menü',
        ru: 'Мобильное меню',
      }[lang];
      await expect(page.locator('.panel-tab-bar')).toHaveAttribute(
        'aria-label',
        mobileMenu,
      );
    }
  });

  test('katalog modülleri her dilde yüklenir (slug dispeçi bozulmadı)', async ({
    page,
    context,
  }) => {
    for (const lang of ['tr', 'en', 'de', 'ru']) {
      await withLang(context, lang);
      const res = await page.goto(`/admin/catalog?lang=${lang}`);
      const html = await res.text();
      // Katalog bölümünün ek CSS + JS modülleri
      expect(html, `${lang} wizard css`).toContain('/static/css/06-wizard.css');
      expect(html, `${lang} listing-wizard`).toContain('/static/listing-wizard.js');
      // Yanlış sayfaya ait modül yüklenmemeli (regions CSS katalog'da yok)
      expect(html, `${lang} regions css`).not.toContain('/static/css/11-regions.css');
    }
  });

  test('topbar dil seçici aria etiketi seçili dilde', async ({ page, context }) => {
    await withLang(context, 'en');
    await page.goto('/admin/catalog?lang=en');
    const aria = await page.getAttribute('#topbar-lang-btn', 'aria-label');
    expect(aria).toContain('Language selection');

    await withLang(context, 'ru');
    await page.goto('/admin/catalog?lang=ru');
    const ariaRu = await page.getAttribute('#topbar-lang-btn', 'aria-label');
    expect(ariaRu).toContain('Выбор языка');
  });

  test('çerez ile sorgu parametresi çakışırsa sorgu kazanır', async ({ page, context }) => {
    await withLang(context, 'tr');
    await page.goto('/admin/catalog?lang=en');
    await expect(page.locator('h1').first()).toHaveText('Catalog');
  });
});
