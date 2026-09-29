// Kademeli giriş animasyonları — gerçek tarayıcı testleri.
//
// Kapsam:
//   1) Masaüstü header popover'ları  (.nc-pop      → nc-stagger-in .28s)
//   2) Mobil menü çekmecesi          (.mobile-menu__panel → mm-stagger-in .32s)
//   3) Hareket azaltma sözleşmesi    (prefers-reduced-motion: reduce)
//
// Her senaryo iki soruyu birden yanıtlar:
//   a) Animasyon GERÇEKTEN oynuyor mu?  → getAnimations() + playState + zamanlama
//   b) Bittikten sonra panel GÖRÜNÜR kalıyor mu? → opacity 1 + ölçülebilir kutu
const { test, expect } = require('@playwright/test');
const { measureStagger, expectStaggered, expectSettledVisible } = require('./helpers/stagger');

// ---------------------------------------------------------------------------
// 1) Masaüstü popover'lar
// ---------------------------------------------------------------------------
const DESKTOP_POPOVERS = [
  { id: 'popover-button-1', panel: 'popover-panel-1', name: 'Yolcular', children: '.nc-travel > *' },
  { id: 'popover-button-2', panel: 'popover-panel-2', name: 'Şablonlar', children: '.nc-mega > *' },
  { id: 'popover-button-3', panel: 'popover-panel-3', name: 'Dil/Para birimi' },
  { id: 'popover-button-5', panel: 'popover-panel-5', name: 'Hesap' },
];

test.describe('masaüstü popover kademeli giriş', () => {
  test.use({ viewport: { width: 1280, height: 820 } });

  for (const popover of DESKTOP_POPOVERS) {
    test(`${popover.name}: öğeler kademeli belirir ve panel görünür kalır`, async ({ page }) => {
      await page.goto('/');

      const measured = await measureStagger(page, {
        panelSelector: '#' + popover.panel,
        childSelector: popover.children,
        open: { type: 'id', value: popover.id },
      });
      expectStaggered(measured, {
        animationName: 'nc-stagger-in',
        durationMs: 280,
        label: popover.name,
      });

      await expectSettledVisible(page, {
        panelSelector: '#' + popover.panel,
        childSelector: popover.children,
        label: popover.name,
      });
    });
  }

  test('kademeli gecikmeler popover çocuk sayısıyla büyür (.06s adım)', async ({ page }) => {
    await page.goto('/');
    const measured = await measureStagger(page, {
      panelSelector: '#popover-panel-2',
      childSelector: '.nc-mega > *',
      open: { type: 'id', value: 'popover-button-2' },
    });
    const timings = expectStaggered(measured, {
      animationName: 'nc-stagger-in',
      durationMs: 280,
      label: 'Şablonlar',
      minChildren: 5,
    });
    // İlk gecikme .06s, her öğede +.04s artış (şablon değerleriyle birebir)
    expect(timings[0].delayMs).toBeCloseTo(60, -1);
    expect(timings[1].delayMs).toBeCloseTo(100, -1);
    expect(timings[timings.length - 1].delayMs).toBeGreaterThan(timings[0].delayMs);
  });

  test('popover kapatılıp yeniden açıldığında animasyon tekrar oynar', async ({ page }) => {
    await page.goto('/');
    const panel = '#popover-panel-2';

    // 1. açılış
    let measured = await measureStagger(page, {
      panelSelector: panel,
      childSelector: '.nc-mega > *',
      open: { type: 'id', value: 'popover-button-2' },
    });
    expectStaggered(measured, { animationName: 'nc-stagger-in', durationMs: 280, label: 'Şablonlar #1' });
    await expectSettledVisible(page, { panelSelector: panel, childSelector: '.nc-mega > *', label: 'Şablonlar #1' });

    // kapat (dış tıklama popover'ları kapatır)
    await page.mouse.click(5, 5);
    await page.waitForFunction(
      (sel) => document.querySelector(sel).getAttribute('data-state') === 'closed',
      panel,
    );

    // 2. açılış — animasyon yeniden başlamalı (opacity tekrar 1'e dönmeli)
    measured = await measureStagger(page, {
      panelSelector: panel,
      childSelector: '.nc-mega > *',
      open: { type: 'id', value: 'popover-button-2' },
    });
    expectStaggered(measured, { animationName: 'nc-stagger-in', durationMs: 280, label: 'Şablonlar #2' });
    await expectSettledVisible(page, { panelSelector: panel, childSelector: '.nc-mega > *', label: 'Şablonlar #2' });
  });
});

// ---------------------------------------------------------------------------
// 2) Mobil menü çekmecesi
// ---------------------------------------------------------------------------
test.describe('mobil çekmece kademeli giriş', () => {
  test.use({ viewport: { width: 390, height: 844 }, hasTouch: true });

  test('çekmece öğeleri sırayla belirir ve görünür kalır', async ({ page }) => {
    await page.goto('/');

    const measured = await measureStagger(page, {
      panelSelector: '.mobile-menu__panel',
      // Çekmecede açık/kapalı durumu kök elemanda tutulur:
      // `.mobile-menu[data-state="open"] .mobile-menu__panel > *`
      stateSelector: '.mobile-menu',
      open: { type: 'selector', value: '.bnav-item[data-act="menu"], .mh-menu-btn' },
    });
    const timings = expectStaggered(measured, {
      animationName: 'mm-stagger-in',
      durationMs: 320,
      label: 'Mobil çekmece',
    });
    // Şablon değerleri: ilk gecikme .18s, adım .05s
    expect(timings[0].delayMs).toBeCloseTo(180, -1);
    expect(timings[1].delayMs).toBeCloseTo(230, -1);

    await expectSettledVisible(page, {
      panelSelector: '.mobile-menu__panel',
      label: 'Mobil çekmece',
    });
  });
});

// ---------------------------------------------------------------------------
// 3) Hareket azaltma sözleşmesi (ortamdan bağımsız, deterministik)
// ---------------------------------------------------------------------------
test.describe('hareket azaltma sözleşmesi', () => {
  test.use({ viewport: { width: 1280, height: 820 }, reducedMotion: 'reduce' });

  test('reduced-motion altında animasyon kapalı ve öğeler anında görünür', async ({ page }) => {
    await page.goto('/');
    const measured = await measureStagger(page, {
      panelSelector: '#popover-panel-2',
      childSelector: '.nc-mega > *',
      open: { type: 'id', value: 'popover-button-2' },
    });

    expect(measured.error).toBeUndefined();
    expect(measured.kids.length).toBeGreaterThanOrEqual(2);
    for (const kid of measured.kids) {
      const at = `reduced-motion #${kid.index}`;
      expect(kid.animationName, `${at}: animasyon kapalı olmalı`).toBe('none');
      expect(kid.animations, `${at}: animasyon nesnesi olmamalı`).toBe(0);
      expect(kid.opacity, `${at}: anında görünür olmalı`).toBe(1);
    }
  });

  test('reduced-motion altında mobil çekmece de animasyonsuz açılır', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('/');
    const measured = await measureStagger(page, {
      panelSelector: '.mobile-menu__panel',
      stateSelector: '.mobile-menu',
      open: { type: 'selector', value: '.bnav-item[data-act="menu"], .mh-menu-btn' },
    });

    expect(measured.error).toBeUndefined();
    for (const kid of measured.kids) {
      expect(kid.animationName, `çekmece #${kid.index}: animasyon kapalı olmalı`).toBe('none');
      expect(kid.opacity, `çekmece #${kid.index}: anında görünür olmalı`).toBe(1);
    }
  });
});
