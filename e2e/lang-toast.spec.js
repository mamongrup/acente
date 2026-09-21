// Dil değişimi bildirimi (geri al) — gerçek tarayıcı testi.
//
// NEDEN: kalıcı dil seçimi geri bildirim ister; kullanıcı yanlışlıkla dil
// değiştirirse tek dokunuşla eski dile dönebilmelidir. Tüm seçim yolları
// (masaüstü globe popover'ı, mobil mm-pill popover'ı, eski .lang-toggle
// döngüsü) `nexus:lang` olayından geçer; bildirim oradan tek yerde üretilir.
// Bu paket:
//   1) dil seçiminin bildirimi tetiklediğini ve mesajın hedef dilde
//      basıldığını ölçer,
//   2) "Geri" düğmesinin önceki dili gerçekten geri getirdiğini (çerez +
//      localStorage) ve bildirimi kapattığını doğrular,
//   3) geri-almanın yeni bir bildirim doğurmadığını (döngü yok) kanıtlar,
//   4) dil değişmediğinde (aynı dil yeniden seçilince) bildirim çıkmadığını
//      ve sayfa açılışında bildirim olmadığını gösterir.
const { test, expect } = require('@playwright/test');

const PORT = process.env.APP_PORT || 8082;
const ORIGIN = `http://127.0.0.1:${PORT}`;

const TOAST = '.store-toast';
const ACTION = '.store-toast__action';

async function readPrefs(page) {
  return page.evaluate(() => ({
    cookie: document.cookie,
    storage: window.localStorage.getItem('chisfis-lang'),
    lang: window.NEXUS_LOCALE && window.NEXUS_LOCALE.lang,
  }));
}

// Bildirimin O AN yokluğunu kanıtlar. `toHaveCount(0)` yanıltıcıdır:
// 8 sn'ye kadar yoklar ve bildirim 7 sn sonra kendi kendine kapandığı için
// yanlış pozitif geçer. Burada kısa bir bekleme sonrası anlık sayım yapılır
// (otomatik kapanmadan çok önce).
async function expectNoToast(page) {
  await page.waitForTimeout(300);
  expect(await page.locator(TOAST).count()).toBe(0);
}

// İngilizce ile başla: iki dil arasında deterministik geçiş yapabilelim.
async function bootEnglish(page, context) {
  await context.addCookies([
    { name: 'nexus_lang', value: 'en', url: ORIGIN },
  ]);
  await page.goto('/');
  await page.waitForFunction(() => !!window.NEXUS_LOCALE);
}

// Globe popover'ından dil seç (masaüstü kırılımı). Mobil menünün mm-pill
// popover'ı da aynı sınıfları taşır; panel `aria-controls` ile
// hedeflenir, böylece gizli kopya seçilmez.
async function pickLanguage(page, code) {
  await page.click('#popover-button-3');
  const popId = await page.getAttribute('#popover-button-3', 'aria-controls');
  const opt = page.locator(`#${popId} .mm-pop__opt[data-kind="lang"][data-val="${code}"]`);
  await expect(opt).toBeVisible();
  await opt.click();
}

test.describe('Dil değişimi bildirimi (geri al)', () => {
  test.use({ viewport: { width: 1280, height: 900 } });

  test('dil seçimi bildirim açar; mesaj hedef dilde ve bir "Geri" düğmesi vardır', async ({
    page,
    context,
  }) => {
    await bootEnglish(page, context);
    // Açılışta bildirim yok
    await expectNoToast(page);

    await pickLanguage(page, 'tr');

    const toast = page.locator(TOAST);
    await expect(toast).toBeVisible();
    // Mesaj yeni dilde basılır ve dilin kendi adını taşır (🇹🇷 Türkçe)
    await expect(toast.locator('.store-toast__msg')).toHaveText('Dil değiştirildi: 🇹🇷 Türkçe');
    // "Geri" düğmesi de hedef dilde etiketlenir
    await expect(toast.locator(ACTION)).toHaveText('Geri');
    // Tercih gerçekten uygulandı
    const prefs = await readPrefs(page);
    expect(prefs.cookie).toContain('nexus_lang=tr');
    expect(prefs.storage).toBe('tr');
    expect(prefs.lang).toBe('tr');
    // Bildirim durum olarak ekran okuyucuya duyurulur
    await expect(page.locator('#store-toast-host')).toHaveAttribute('aria-live', 'polite');
    await expect(toast).toHaveAttribute('role', 'status');
  });

  test('"Geri" önceki dili geri getirir ve bildirimi kapatır (yeni bildirim yok)', async ({
    page,
    context,
  }) => {
    await bootEnglish(page, context);
    await pickLanguage(page, 'de');
    const toast = page.locator(TOAST);
    await expect(toast).toBeVisible();
    await expect(toast.locator('.store-toast__msg')).toHaveText('Sprache geändert: 🇩🇪 Deutsch');

    await toast.locator(ACTION).click();

    // Dil İngilizceye döndü (çerez + localStorage + ortak kaynak)
    await expect
      .poll(async () => (await readPrefs(page)).storage)
      .toBe('en');
    const prefs = await readPrefs(page);
    expect(prefs.cookie).toContain('nexus_lang=en');
    expect(prefs.lang).toBe('en');

    // Bildirim kapandı ve geri-alma yeni bir bildirim doğurmadı
    await expectNoToast(page);
  });

  test('geri-alma sonrası yeni bir dil seçimi yeniden bildirim gösterir', async ({
    page,
    context,
  }) => {
    await bootEnglish(page, context);
    await pickLanguage(page, 'ru');
    await expect(page.locator(TOAST)).toBeVisible();
    await page.locator(ACTION).click();
    await expectNoToast(page);

    await pickLanguage(page, 'tr');
    await expect(page.locator(TOAST)).toBeVisible();
    await expect(page.locator(TOAST).locator('.store-toast__msg')).toHaveText(
      'Dil değiştirildi: 🇹🇷 Türkçe',
    );
  });

  test('aynı dil yeniden seçilince bildirim çıkmaz', async ({ page, context }) => {
    await bootEnglish(page, context);
    await pickLanguage(page, 'en');
    // Dil zaten en: ne değişim ne bildirim
    await expectNoToast(page);
    expect((await readPrefs(page)).storage).toBe('en');
  });
});

// Mobil menü (mm-pill popover) ayrı bir seçim yoludur ve aynı geri-alma
// deneyimini vermelidir — aksi halde yalnız masaüstünde bildirim çıkardı.
test.describe('Dil değişimi bildirimi — mobil menü yolu', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  async function openMobilePill(page) {
    await page.evaluate(() =>
      document.querySelector('.bnav-item[data-act="menu"]').click(),
    );
    await page.waitForFunction(
      () => document.querySelector('.mobile-menu')?.getAttribute('data-state') === 'open',
    );
    await page.waitForTimeout(600);
    await page.evaluate(() =>
      document.querySelector('.mobile-menu .mm-pill').click(),
    );
    await page.waitForTimeout(300);
  }

  test('mobil mm-pill dil seçimi bildirim açar ve Geri eski dile döner', async ({
    page,
    context,
  }) => {
    await bootEnglish(page, context);
    await openMobilePill(page);

    const opt = page.locator('.mobile-menu .mm-pop__opt[data-kind="lang"][data-val="tr"]');
    await expect(opt).toBeVisible();
    await opt.click();

    const toast = page.locator(TOAST);
    await expect(toast).toBeVisible();
    await expect(toast.locator('.store-toast__msg')).toHaveText(
      'Dil değiştirildi: 🇹🇷 Türkçe',
    );
    expect((await readPrefs(page)).storage).toBe('tr');

    await toast.locator(ACTION).click();
    await expectNoToast(page);
    expect((await readPrefs(page)).storage).toBe('en');
  });
});
