// Navigasyon aktif-durum paritesi — masaüstü header menüsü ↔ mobil çekmece.
//
// NEDEN: aktif kategori sorusu iki dosyada iki AYRI kopya olarak
// yanıtlanıyordu ve kopyalar ayrıştı:
//   • mobil çekmece  → hem `/kategori/<slug>` yolunu hem
//                       `/urunler?kategori=<slug>` filtresini biliyordu,
//   • masaüstü menü  → YALNIZ sorgu filtresini biliyordu.
// Sonuç: `/kategori/hotel` sayfasında mobil menü vurgulu, masaüstü header
// menüsü vurgusuzdu — aynı sayfada iki farklı menü davranışı.
//
// Artık tek kaynak var (`window.NEXUS_NAV`, `main.js` §0c) ve iki tüketici de
// onu çağırıyor. Bu paket o davranışı GERÇEK tarayıcıda, ziyaretçinin
// gördüğü iki yüzey üzerinden ölçer.
//
// İkinci sözleşme: çekmece tetikleyicisi ETİKETE bağlı olmamalı. Sunucudan
// basılan hamburger etiketini sayfa diline göre çevirir; yalnız İngilizce
// "Open main menu" metnine bakan eski seçim yüzünden İngilizce dışındaki
// dillerde çekmece hiç kurulmuyordu. Test bunu `nexus_lang=de` ile ölçer.
const { test, expect } = require('@playwright/test');

const PORT = process.env.APP_PORT || 8082;
const ORIGIN = `http://127.0.0.1:${PORT}`;

const DESKTOP_POPOVER_BTN = '#popover-button-2';
const DESKTOP_POPOVER = '#popover-panel-2';
const DRAWER = '.mobile-menu';
const DRAWER_OPEN_BTN = '.bnav-item[data-act="menu"]';
const HEADER_HAMBURGER_ICON = 'header .hgi-menu-01';

// Masaüstü menüdeki bağlantılar: href + aktiflik (sınıf ve aria-current).
async function desktopLinks(page) {
  await page.evaluate((sel) => {
    const btn = document.querySelector(sel);
    if (btn && !document.querySelector('#popover-panel-2')) btn.click();
  }, DESKTOP_POPOVER_BTN);
  await page.waitForSelector(DESKTOP_POPOVER, { state: 'attached' });
  return page.$$eval(`${DESKTOP_POPOVER} a`, (els) =>
    els.map((el) => ({
      href: el.getAttribute('href'),
      current: el.getAttribute('aria-current'),
      activeClass: el.classList.contains('nc-pop__link--active'),
    })),
  );
}

// Çekmecedeki vurgulu bağlantılar (akordeon alt linkleri + doğrudan linkler).
async function drawerActive(page, openWith) {
  await page.evaluate(
    (args) => {
      const drawer = document.querySelector(args.drawer);
      if (drawer) drawer.setAttribute('data-state', 'closed');
      const trigger =
        args.openWith === 'hamburger'
          ? document.querySelector(args.hamburger)?.closest('button')
          : document.querySelector(args.bnav);
      if (trigger) trigger.click();
    },
    { drawer: DRAWER, bnav: DRAWER_OPEN_BTN, hamburger: HEADER_HAMBURGER_ICON, openWith },
  );
  await page.waitForFunction(
    (sel) => document.querySelector(sel)?.getAttribute('data-state') === 'open',
    DRAWER,
  );
  return page.$$eval(
    `${DRAWER} .mm-acc-link-active, ${DRAWER} [aria-current="page"]`,
    (els) => els.map((el) => el.getAttribute('href')),
  );
}

function desktopActive(links) {
  return links.filter((l) => l.current === 'page').map((l) => l.href);
}

test.describe('masaüstü ↔ mobil aktif kategori paritesi', () => {
  test.use({ viewport: { width: 1280, height: 900 } });

  test('kategori sayfası (/otel): İKİ menü de vurgular', async ({ page }) => {
    await page.goto('/otel');
    const desktop = await desktopLinks(page);
    const drawer = await drawerActive(page, 'bnav');

    // Masaüstü: kategori sayfasında eskiden vurgusuz kalıyordu
    expect(desktopActive(desktop)).toContain('/otel');
    // Sınıf da verilmeli (vurgunun görsel taşıyıcısı)
    const hotel = desktop.find((l) => l.href === '/otel');
    expect(hotel.activeClass).toBe(true);
    // Tek bağlantı aktif olmalı — komşular vurgusuz
    expect(desktopActive(desktop)).toHaveLength(1);
    // Mobil çekmece aynı kategoriyi işaret eder (yol biçimiyle)
    expect(drawer).toEqual(['/otel']);
  });

  test('liste filtresi (/urunler?kategori=yacht): İKİ menü de vurgular', async ({ page }) => {
    await page.goto('/urunler?kategori=yacht');
    const desktop = await desktopLinks(page);
    const drawer = await drawerActive(page, 'bnav');

    expect(desktopActive(desktop)).toEqual(['/yat']);
    expect(drawer).toEqual(['/yat']);
  });

  test('doğrudan rota eşlemesi (/urunler?kategori=car → /arac)', async ({ page }) => {
    await page.goto('/urunler?kategori=car');
    const drawer = await drawerActive(page, 'bnav');
    // Araçlar/Uçuşlar kategori sayfası değil; liste filtresinden eşlenir
    expect(drawer).toEqual(['/arac']);
  });

  test('filtresiz liste sayfasında hiçbir kategori vurgulanmaz', async ({ page }) => {
    await page.goto('/urunler');
    const desktop = await desktopLinks(page);
    const drawer = await drawerActive(page, 'bnav');
    expect(desktopActive(desktop)).toEqual([]);
    expect(drawer).toEqual([]);
  });

  test('çekmece tetikleyicisi etikete bağlı değil: Almanca arayüzde de açılır', async ({
    context,
    page,
  }) => {
    await context.addCookies([{ name: 'nexus_lang', value: 'de', url: ORIGIN }]);
    await page.goto('/urunler?kategori=hotel');

    // Sunucu hamburger etiketini ÇEVİRİR (İngilizce metne bakan eski seçim
    // tam da bu yüzden kaçırıyordu).
    const label = await page.$eval(HEADER_HAMBURGER_ICON, (icon) =>
      icon.closest('button').textContent.trim(),
    );
    expect(label).not.toMatch(/open main menu/i);
    expect(label.length).toBeGreaterThan(0);

    // Yapısal iz sayesinde çekmece kurulu ve açılıyor
    await expect(page.locator(DRAWER)).toHaveCount(1);
    const drawer = await drawerActive(page, 'hamburger');
    expect(drawer).toEqual(['/hotel']);
  });

  test('ortak kaynak yüklenir ve betik sırası doğrudur', async ({ page }) => {
    await page.goto('/urunler?kategori=hotel');
    const order = await page.evaluate(() => {
      const srcs = Array.from(document.scripts).map((s) => s.getAttribute('src') || '');
      return {
        mainIndex: srcs.findIndex((s) => /main\.js/.test(s)),
        popoversIndex: srcs.findIndex((s) => /header-popovers\.js/.test(s)),
      };
    });
    expect(order.mainIndex).toBeGreaterThanOrEqual(0);
    expect(order.popoversIndex).toBeGreaterThanOrEqual(0);
    // NEXUS_NAV'ı tanımlayan betik ÖNCE yürümeli
    expect(order.mainIndex).toBeLessThan(order.popoversIndex);

    const nav = await page.evaluate(() => ({
      hasNav: typeof window.NEXUS_NAV === 'object' && window.NEXUS_NAV !== null,
      api: window.NEXUS_NAV
        ? [
            typeof window.NEXUS_NAV.isActiveCategory,
            typeof window.NEXUS_NAV.isActiveHref,
            typeof window.NEXUS_NAV.isListing,
          ]
        : null,
      // Tek kaynak: her iki form da aynı predicate'te
      byPath: window.NEXUS_NAV ? window.NEXUS_NAV.isActiveCategory('hotel') : null,
      byQuery: window.NEXUS_NAV ? window.NEXUS_NAV.isActiveCategory('tour') : null,
    }));
    expect(nav.hasNav).toBe(true);
    expect(nav.api).toEqual(['function', 'function', 'function']);
    expect(nav.byPath).toBe(true);
    expect(nav.byQuery).toBe(false);
  });
});
