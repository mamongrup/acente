// Masaüstü header popover çevirisi — gerçek tarayıcı testleri.
//
// NEDEN: paneller tamamen istemcide (`header-popovers.js`) üretilir, yani
// sunucunun SSR çeviri geçişi onlara dokunamaz. Bir dönem gövdeler sabit
// Türkçe metinle kuruluyordu: İngilizce/Almanca gezen kullanıcı "Misafirler",
// "Keşfet", "Giriş yap" görüyordu.
//
// Bu paket üç şeyi kanıtlar:
//   1) Dört dilde dört panelin TÜM etiketleri (başlık, misafir satırı, alt
//      yazı, kategori, hesap linki, boş bildirim metni) seçili dilde basılır,
//   2) dil değişimi panel AÇIKKEN de etiketleri tazeler (sayfa yenilemeden),
//   3) tazeleme kullanıcı durumunu bozmaz: misafir sayacı korunur ve sayaç
//      tıklama başına TAM BİR artar (eski kod panel her açılışta dinleyiciyi
//      yeniden bağlıyordu → 3 açılıştan sonra tıklama sayacı 3 katlıyordu).
const { test, expect } = require('@playwright/test');

const PORT = process.env.APP_PORT || 8082;
const ORIGIN = `http://127.0.0.1:${PORT}`;

const btn = (n) => `#popover-button-${n}`;
const panel = (n) => `#popover-panel-${n}`;

// Dil başına beklenen etiketler — sözlüklerin birebir yansıması.
const EXPECT = {
  en: {
    guests: 'Guests',
    rows: ['Adults', 'Children', 'Infants'],
    subs: ['Ages 13+', 'Ages 2–12', 'Under 2'],
    explore: 'Explore',
    cats: ['Hotels', 'Holiday homes & villas', 'Tours', 'Activities', 'Yacht rental'],
    notifications: 'Notifications',
    empty: 'You have no new notifications.',
    host: 'Become a host',
    signin: 'Sign in',
    create: 'Create account',
  },
  tr: {
    guests: 'Misafirler',
    rows: ['Yetişkin', 'Çocuk', 'Bebek'],
    subs: ['13+ yaş', '2–12 yaş', '2 yaş altı'],
    explore: 'Keşfet',
    cats: ['Oteller', 'Tatil evleri ve villalar', 'Turlar', 'Aktiviteler', 'Yat kiralama'],
    notifications: 'Bildirimler',
    empty: 'Yeni bildiriminiz yok.',
    host: 'Ev sahibi olun',
    signin: 'Giriş yap',
    create: 'Hesap oluştur',
  },
  de: {
    guests: 'Gäste',
    rows: ['Erwachsene', 'Kinder', 'Kleinkinder'],
    subs: ['Ab 13 Jahren', '2–12 Jahre', 'Unter 2'],
    explore: 'Entdecken',
    cats: ['Hotels', 'Ferienhäuser & Villen', 'Touren', 'Aktivitäten', 'Yachtcharter'],
    notifications: 'Benachrichtigungen',
    empty: 'Sie haben keine neuen Benachrichtigungen.',
    host: 'Gastgeber werden',
    signin: 'Anmelden',
    create: 'Konto erstellen',
  },
  ru: {
    guests: 'Гости',
    rows: ['Взрослые', 'Дети', 'Младенцы'],
    subs: ['От 13 лет', '2–12 лет', 'До 2 лет'],
    explore: 'Обзор',
    cats: ['Отели', 'Дома и виллы для отпуска', 'Туры', 'Активности', 'Аренда яхты'],
    notifications: 'Уведомления',
    empty: 'У вас нет новых уведомлений.',
    host: 'Стать хозяином',
    signin: 'Войти',
    create: 'Создать аккаунт',
  },
};

// Sunucu dili `nexus_lang` çerezinden basar; JS katmanı aynı değeri
// NEXUS_LOCALE.lang'e yazar — ikisi de doğrulanır.
async function boot(page, context, lang) {
  await context.addCookies([{ name: 'nexus_lang', value: lang, url: ORIGIN }]);
  await page.goto('/');
  await page.waitForFunction(() => !!(window.NEXUS_T && window.NEXUS_LOCALE));
  await page.waitForFunction((l) => window.NEXUS_LOCALE.lang === l, lang);
}

async function openPanel(page, n) {
  await page.click(btn(n));
  await page.waitForFunction(
    (sel) => document.querySelector(sel)?.getAttribute('data-state') === 'open',
    panel(n),
  );
  // Kademeli giriş animasyonu bitsin (metin okuma sonrası stabil olsun)
  await page.waitForTimeout(320);
}

// Gerçek UI yolu: globe popover'ından dil seç (panel kapalıyken).
async function pickLanguage(page, code) {
  await page.click(btn(3));
  const popId = await page.getAttribute(btn(3), 'aria-controls');
  const opt = page.locator(`#${popId} .mm-pop__opt[data-kind="lang"][data-val="${code}"]`);
  await expect(opt).toBeVisible();
  await opt.click();
  await page.waitForFunction((c) => window.NEXUS_LOCALE.lang === c, code);
}

// Panel AÇIKKEN dil değişimi: herhangi bir dış tıklama (`closeAll`) panelleri
// kapatır — locale popover'ını açmak da paneli kapatır. Yani açık bir panel dil
// değişimini ancak ortak kanaldan görebilir: tüm seçim yollarının (globe
// popover, mm-pill, .lang-toggle) aktığı `nexus:lang` olayı. Tazelenecek
// sözleşme bu yüzden olay seviyesinde ölçülür.
async function emitLang(page, code) {
  await page.evaluate((c) => {
    document.dispatchEvent(new CustomEvent('nexus:lang', { detail: { lang: c } }));
  }, code);
  await page.waitForFunction((c) => window.NEXUS_LOCALE.lang === c, code);
}

async function texts(page, sel) {
  return page.locator(sel).allInnerTexts();
}

test.describe('Masaüstü header popover çevirisi', () => {
  test.use({ viewport: { width: 1280, height: 900 } });

  test('dört dilde dört panelin tüm etiketleri seçili dilde basılır', async ({ page, context }) => {
    for (const lang of ['en', 'tr', 'de', 'ru']) {
      const exp = EXPECT[lang];
      await boot(page, context, lang);

      // 1) Misafirler: başlık + satır etiketleri + alt yazılar
      await openPanel(page, 1);
      await expect(page.locator(panel(1) + ' .nc-pop__head')).toHaveText(exp.guests);
      expect(await texts(page, panel(1) + ' .nc-pop__row-label')).toEqual(exp.rows);
      expect(await texts(page, panel(1) + ' .nc-pop__row-sub')).toEqual(exp.subs);

      // 2) Keşfet: kategori etiketleri (mobil çekmeceyle aynı anahtarlar)
      await openPanel(page, 2);
      await expect(page.locator(panel(2) + ' .nc-pop__head')).toHaveText(exp.explore);
      expect(await texts(page, panel(2) + ' .nc-pop__link')).toEqual(exp.cats);

      // 3) Bildirimler: başlık + boş durum metni
      await openPanel(page, 4);
      await expect(page.locator(panel(4) + ' .nc-pop__head')).toHaveText(exp.notifications);
      await expect(page.locator(panel(4) + ' .nc-pop__empty p')).toHaveText(exp.empty);

      // 4) Hesap: üç link de çevrilir
      await openPanel(page, 5);
      expect(await texts(page, panel(5) + ' .nc-pop__link')).toEqual([
        exp.host,
        exp.signin,
        exp.create,
      ]);

      // Hiçbir panelde çevrilmemiş (Türkçe) metin kalmamalı — dil tr değilse
      const leftover = await page.evaluate(() => {
        const bad = ['Misafirler', 'Keşfet', 'Bildirimler', 'Giriş yap', 'Hesap oluştur', 'Yetişkin'];
        const found = [];
        document.querySelectorAll('.nc-pop').forEach((p) => {
          const t = p.textContent || '';
          bad.forEach((w) => { if (t.indexOf(w) !== -1) found.push(w); });
        });
        return found;
      });
      if (lang !== 'tr') expect(leftover).toEqual([]);
    }
  });

  test('dil değişimi AÇIK paneli sayfa yenilemeden tazeler', async ({ page, context }) => {
    await boot(page, context, 'en');
    await openPanel(page, 1);
    await expect(page.locator(panel(1) + ' .nc-pop__head')).toHaveText('Guests');

    await emitLang(page, 'tr');

    // Panel hâlâ açık (sayfa yenilenmedi) ve içeriği Türkçe
    await expect(page.locator(panel(1))).toHaveAttribute('data-state', 'open');
    await expect(page.locator(panel(1) + ' .nc-pop__head')).toHaveText('Misafirler');
    expect(await texts(page, panel(1) + ' .nc-pop__row-label')).toEqual([
      'Yetişkin',
      'Çocuk',
      'Bebek',
    ]);

    await emitLang(page, 'ru');
    await expect(page.locator(panel(1) + ' .nc-pop__head')).toHaveText('Гости');
    // Kapalı paneller de tazelenir: bir sonraki açılışta doğru dil hazır
    await expect(page.locator(panel(2) + ' .nc-pop__link').first()).toHaveText('Отели');
    await expect(page.locator(panel(4) + ' .nc-pop__empty p')).toHaveText(
      'У вас нет новых уведомлений.',
    );

    // ARIA etiketleri de hedef dilde (stepper'da sabit ek kalmamalı)
    const aria = await page.getAttribute(panel(1) + ' .nc-stepper__btn', 'aria-label');
    expect(aria).toBe('Уменьшить: Взрослые');
  });

  test('gerçek dil seçimi (globe popover) kapalı panelleri de tazeler', async ({ page, context }) => {
    await boot(page, context, 'en');
    await openPanel(page, 1);
    // Panel kapanır (locale popover'ını açmak closeAll çalıştırır) ama tazeleme
    // gerçekleşmiş olmalı
    await pickLanguage(page, 'de');
    await openPanel(page, 1);
    await expect(page.locator(panel(1) + ' .nc-pop__head')).toHaveText('Gäste');
    await expect(page.locator(panel(5) + ' .nc-pop__link').first()).toHaveText('Gastgeber werden');
  });

  test('dil değişimi misafir sayacını sıfırlamaz ve sayaç çalışmaya devam eder', async ({
    page,
    context,
  }) => {
    await boot(page, context, 'en');
    await openPanel(page, 1);

    const plusAdults = page.locator(panel(1) + ' .nc-stepper__btn[data-guest="adults"][data-step="1"]');
    await plusAdults.click();
    await plusAdults.click();
    const before = await page.locator(panel(1) + ' .nc-stepper__val').first().innerText();
    expect(before).toBe('4');

    await emitLang(page, 'de');
    // Değer korunur (gövde yeniden basıldı ama durum panelin dışında yaşıyor)
    expect(await page.locator(panel(1) + ' .nc-stepper__val').first().innerText()).toBe('4');
    await expect(page.locator(panel(1) + ' .nc-pop__head')).toHaveText('Gäste');

    // Tazeleme sonrası sayaç yeni düğümlerle de TAM BİR artar
    await plusAdults.click();
    expect(await page.locator(panel(1) + ' .nc-stepper__val').first().innerText()).toBe('5');
  });

  test('sayaç panel her açılışta yeniden bağlanmaz: tıklama başına tam bir artış', async ({
    page,
    context,
  }) => {
    await boot(page, context, 'en');

    // Paneli 4 kez aç/kapa — eski kodda dinleyiciler birikir ve tek tıklama
    // sayacı katlayarak artırırdı.
    for (let i = 0; i < 4; i++) {
      await openPanel(page, 1);
      await page.click(btn(1));
      await page.waitForTimeout(200);
    }
    await openPanel(page, 1);

    const val = page.locator(panel(1) + ' .nc-stepper__val').first();
    expect(await val.innerText()).toBe('2');
    await page.locator(panel(1) + ' .nc-stepper__btn[data-guest="adults"][data-step="1"]').click();
    expect(await val.innerText()).toBe('3');
    await page.locator(panel(1) + ' .nc-stepper__btn[data-guest="children"][data-step="1"]').click();
    expect(await page.locator(panel(1) + ' .nc-stepper__val').nth(1).innerText()).toBe('1');
  });

  test('yetişkin sayacı 1 altında inmez, üst sınır 16', async ({ page, context }) => {
    await boot(page, context, 'en');
    await openPanel(page, 1);

    const adults = page.locator(panel(1) + ' .nc-stepper__val').first();
    const minus = page.locator(panel(1) + ' .nc-stepper__btn[data-guest="adults"][data-step="-1"]');
    const plus = page.locator(panel(1) + ' .nc-stepper__btn[data-guest="adults"][data-step="1"]');

    await minus.click();
    expect(await adults.innerText()).toBe('1');
    await minus.click();
    expect(await adults.innerText()).toBe('1');

    for (let i = 0; i < 20; i++) await plus.click();
    expect(await adults.innerText()).toBe('16');
  });

  test('Keşfet kategorileri mobil çekmeceyle aynı etiketleri kullanır', async ({ page, context }) => {
    // Mobil kırılım: çekmece alt barın "Menü" düğmesiyle açılır
    await page.setViewportSize({ width: 390, height: 780 });
    await boot(page, context, 'de');

    await page.evaluate(() => document.querySelector('.bnav-item[data-act="menu"]').click());
    await page.waitForFunction(() => {
      const m = document.querySelector('.mobile-menu');
      return m && m.getAttribute('data-state') === 'open';
    });
    // Akordeonların alt linkleri görünür olsun
    await page.evaluate(() => {
      document.querySelectorAll('.mm-acc').forEach((acc) => {
        if (acc.getAttribute('data-open') !== '1') acc.querySelector('.mm-acc-head').click();
      });
    });
    await page.waitForTimeout(250);

    const drawer = await texts(page, '.mobile-menu .mm-acc-inner > a, .mobile-menu .mm-direct');
    // Masaüstü popover'ı aynı anahtarlardan beslenir: çekmecede olan her
    // kategori etiketi panelde de aynı yazımla görünmeli.
    const desktop = await page.evaluate(() => {
      const out = [];
      document.querySelectorAll('#popover-panel-2 .nc-pop__link').forEach((a) => out.push(a.textContent.trim()));
      return out;
    });
    expect(desktop.length).toBe(5);
    for (const label of desktop) {
      expect(drawer).toContain(label);
    }
  });
});
