// Mobil çekmece kapanış animasyonu (slide-out + fade) — gerçek tarayıcı testi.
//
// NEDEN: çekmece kapanışta ANINDA `display: none` oluyordu; açılışta oynayan
// slide-in'in tersi hiç görünmüyordu. Artık `.mm-closing` sınıfıyla 280 ms
// boyunca görünür kalıp sağa kayarak ve sönerek kapanıyor.
//
// Ölçüm Animation API + computed style üzerinden yapılır (piksel farkı yok) —
// önizleme webview'i CSS geçişlerini oynatmadığı için animasyonun *oynadığını*
// yalnız gerçek tarayıcı motoru ölçebilir.
//
// Kapsam:
//   1) Kapanışta çekmece anında kaybolmaz: `mm-closing` + slide-out + fade
//   2) Sönme sürerken yeniden açmak iptal eder (çekmece açık kalır)
//   3) `prefers-reduced-motion: reduce` → animasyon yok, anında kapanır
//   4) Kapanış tamamlanınca kaydırma kilidi bırakılır
const { test, expect } = require('@playwright/test');

const ROOT = '.mobile-menu';
const PANEL = '.mobile-menu__panel';
const BACKDROP = '.mobile-menu__backdrop';
// Alt bardaki Menü düğmesi her zaman görünür (üst bar hamburger'ı yalnız
// kaydırınca beliren yapışkan satırda).
const OPEN_BTN = '.bnav-item[data-act="menu"]';
// Üst bar hamburgeri: çekmeceyi `openMenu()` ile açar (alt bar Menü düğmesi
// `/ data-act="menu"` ise `set(true)` yolundan geçer). İki ayrı iptal yolu.
const TOP_BAR_MENU_BTN = '.mh-menu-btn';
const CLOSE_BTN = '.mobile-menu__close';

// Sayfa içi ölçüm: tur gecikmesi zamanlamaya karışmasın.
const PROBE = `async ({ frames2, framesN, action }) => {
  const frames = (n) =>
    new Promise((res) => { let i = n; const step = () => (--i <= 0 ? res() : requestAnimationFrame(step)); requestAnimationFrame(step); });
  const root = document.querySelector('${ROOT}');
  const panel = document.querySelector('${PANEL}');
  if (!root || !panel) return { error: 'çekmece bulunamadı' };

  const snap = () => {
    const ps = getComputedStyle(panel);
    const bs = getComputedStyle(document.querySelector('${BACKDROP}'));
    return {
      state: root.getAttribute('data-state'),
      closing: root.classList.contains('mm-closing'),
      rendered: panel.getClientRects().length > 0,
      rootDisplay: getComputedStyle(root).display,
      opacity: parseFloat(ps.opacity),
      transform: ps.transform,
      transitionProp: ps.transitionProperty,
      backdropOpacity: parseFloat(bs.opacity),
      animations: panel.getAnimations().map((a) => ({
        name: a.animationName || a.transitionProperty || null,
        state: a.playState,
        dur: a.effect.getComputedTiming().duration,
      })),
      locked: document.documentElement.classList.contains('overflow-hidden'),
    };
  };

  const before = snap();
  if (action === 'close') document.querySelector('${CLOSE_BTN}').click();
  await frames(frames2);
  const mid = snap();
  await frames(framesN);
  const after = snap();
  return { before, mid, after };
}`;

// NOT: `page.click` actionability kapısı burada gerçek bir regresyon kapısıdır.
// Sohbet FAB'ı bir dönem alt barın "Menü" düğmesini tam üzerinde örtüyordu ve
// tıklama FAB'a gidiyordu; `page.click` o durumda "subtree intercepts pointer
// events" ile kırmızı olur.
async function openDrawer(page) {
  await page.goto('/');
  await page.click(OPEN_BTN);
  await page.waitForFunction((sel) => document.querySelector(sel)?.getAttribute('data-state') === 'open', ROOT);
  // Panelin kendi kademeli girişi bitsin: ölçüm temiz başlangıç görsün.
  await page.waitForFunction(() => document.querySelector('.mobile-menu__panel').getAnimations().length === 0);
}

test.describe('mobil çekmece kapanış animasyonu', () => {
  test.use({ viewport: { width: 390, height: 844 }, hasTouch: true });

  test('alt bardaki Menü düğmesine dokunma gerçekten ulaşır (FAB örtmüyor)', async ({ page }) => {
    await page.goto('/');
    const hit = await page.evaluate(() => {
      const btn = document.querySelector('.bnav-item[data-act="menu"]');
      if (!btn) return { error: 'Menü düğmesi yok' };
      const b = btn.getBoundingClientRect();
      const top = document.elementFromPoint(b.x + b.width / 2, b.y + b.height / 2);
      const fab = document.querySelector('.nexus-chat-toggle');
      const fb = fab && fab.getBoundingClientRect();
      const bar = document.querySelector('.bnav-bar');
      const bb = bar ? bar.getBoundingClientRect() : b;
      return {
        topIsButton: !!(top && top.closest('.bnav-item[data-act="menu"]')),
        topClass: top ? top.className : null,
        // FAB'ın alt kenarı ile alt barın üst kenarı arasındaki boşluk
        fabBottomGap: fb ? Math.round(bb.y - (fb.y + fb.height)) : null,
      };
    });
    expect(hit.error).toBeUndefined();
    expect(hit.topIsButton, `Menü düğmesinin üstünde ${hit.topClass} var`).toBe(true);
    // FAB, alt barın üstünde durmalı (negatif boşluk = çakışma)
    expect(hit.fabBottomGap).toBeGreaterThanOrEqual(8);
  });

  test('kapanışta çekmece anında kaybolmaz: slide-out + fade oynar, sonra gizlenir', async ({ page }) => {
    await openDrawer(page);

    // `frames2`: kapanıştan hemen sonraki ölçüm. Geçiş bir sonraki karede
    // başlar, o yüzden 2 kare yerine 6 kare beklenir (aksi halde ilk karede
    // henüz 0 ilerleme görülür ve ölçüm titrer).
    const r = await page.evaluate(
      new Function('args', `return (${PROBE})(args);`),
      { frames2: 6, framesN: 26, action: 'close' },
    );
    expect(r.error).toBeUndefined();

    // Başlangıç: açık, kaydırma kilitli, panel yerinde
    expect(r.before.state).toBe('open');
    expect(r.before.rendered).toBe(true);
    expect(r.before.opacity).toBe(1);
    expect(r.before.locked).toBe(true);

    // 2 kare sonra: durum ANINDA closed, ama panel hâlâ render ediliyor
    expect(r.mid.state).toBe('closed');
    expect(r.mid.closing).toBe(true);
    expect(r.mid.rendered, 'sönme sürerken panel DOM\'da kalmalı').toBe(true);
    expect(r.mid.rootDisplay).toBe('block');

    // Kayma + sönme başlamış olmalı: transform artık identity değil
    expect(r.mid.transform).not.toBe('none');
    expect(r.mid.transform).not.toBe(r.before.transform);

    // Sönme tamamlanınca: sınıf temizlenir, çekmece gizlenir, kilit bırakılır
    expect(r.after.closing).toBe(false);
    expect(r.after.rendered).toBe(false);
    expect(r.after.rootDisplay).toBe('none');
    expect(r.after.locked).toBe(false);
  });

  test('backdrop da kapanışta söner (opaklık düşer)', async ({ page }) => {
    await openDrawer(page);
    const r = await page.evaluate(
      new Function('args', `return (${PROBE})(args);`),
      { frames2: 6, framesN: 26, action: 'close' },
    );
    expect(r.before.backdropOpacity).toBe(1);
    expect(r.mid.backdropOpacity).toBeLessThan(1);
    expect(r.after.backdropOpacity).toBe(0);
  });

  test('sönme sürerken yeniden açmak iptal eder: çekmece açık kalır', async ({ page }) => {
    await openDrawer(page);

    const r = await page.evaluate(
      new Function('args', `return (${PROBE})(args);`),
      { frames2: 2, framesN: 8, action: 'close' },
    );
    expect(r.mid.closing).toBe(true);

    // Sönme bitmeden yeniden aç (üst bar hamburger'ı / alt bar Menü düğmesi)
    await page.click(OPEN_BTN);
    // Bekleyen gizleme ateşlenseydi çekmece kapanırdı.
    await page.waitForTimeout(420);
    const after = await page.evaluate(() => {
      const root = document.querySelector('.mobile-menu');
      const panel = root.querySelector('.mobile-menu__panel');
      return {
        state: root.getAttribute('data-state'),
        closing: root.classList.contains('mm-closing'),
        rendered: panel.getClientRects().length > 0,
        opacity: parseFloat(getComputedStyle(panel).opacity),
      };
    });
    expect(after.state).toBe('open');
    expect(after.closing).toBe(false);
    expect(after.rendered).toBe(true);
    expect(after.opacity).toBe(1);

    // İkinci iptal yolu: ÜST BAR hamburgeri (`.mh-menu-btn`) — çekmeceyi
    // `openMenu()` ile açar. İki yol da bekleyen gizlemeyi iptal etmeli.
    //
    // Eski sürüm burada şablonun gizli `.sr-only` metnini ("Open main menu")
    // arıyordu; o düğme mağaza maketinde ARTIK YOK, dolayısıyla `if (sp)`
    // koruması tıklamayı sessizce atlıyor ve iddia yalnızca rastlantıyla
    // geçebiliyordu. Seçici artık gerçek tetikleyici; bulunamazsa test düşer.
    const snap = async () =>
      page.evaluate(() => {
        const root = document.querySelector('.mobile-menu');
        const panel = root.querySelector('.mobile-menu__panel');
        return {
          state: root.getAttribute('data-state'),
          closing: root.classList.contains('mm-closing'),
          rendered: panel.getClientRects().length > 0,
        };
      });

    await page.click(CLOSE_BTN);
    await page.waitForTimeout(60);
    expect((await snap()).closing, 'ikinci kapanış da sönme yolundan geçmeli').toBe(true);
    await page.click(TOP_BAR_MENU_BTN);
    await page.waitForTimeout(420);
    const after2 = await snap();
    expect(after2.state, 'üst bar hamburgeri ile yeniden açılış çekmeceyi kapatmamalı').toBe('open');
    expect(after2.closing).toBe(false);
    expect(after2.rendered).toBe(true);
  });

  test('kayma + sönme gerçekten oynar: panel geçiş animasyonları running', async ({ page }) => {
    await openDrawer(page);
    const r = await page.evaluate(
      new Function('args', `return (${PROBE})(args);`),
      { frames2: 2, framesN: 26, action: 'close' },
    );

    // Sönme sürerken panele bağlı çalışan geçişler olmalı (transform/opacity)
    const running = r.mid.animations.filter((a) => a.state === 'running');
    expect(running.length, 'kapanışta en az bir geçiş oynamalı').toBeGreaterThanOrEqual(1);
    const props = running.map((a) => a.name);
    expect(props).toContain('transform');
    expect(props).toContain('opacity');
    // Kayma süresi CSS `.28s` ile uyuşmalı
    const transform = running.find((a) => a.name === 'transform');
    expect(transform.dur).toBeCloseTo(280, -1);

    // Bitince hiçbir geçiş kalmaz (panel gizli)
    expect(r.after.animations.length).toBe(0);
  });
});

test.describe('çekmece kapanışı — hareket azaltma', () => {
  test.use({ viewport: { width: 390, height: 844 }, hasTouch: true, reducedMotion: 'reduce' });

  test('reduced-motion altında çekmece animasyonsuz kapanır', async ({ page }) => {
    await openDrawer(page);
    await page.click(CLOSE_BTN);
    await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
    const snap = await page.evaluate(() => {
      const root = document.querySelector('.mobile-menu');
      const panel = root.querySelector('.mobile-menu__panel');
      return {
        state: root.getAttribute('data-state'),
        closing: root.classList.contains('mm-closing'),
        rendered: panel.getClientRects().length > 0,
        animations: panel.getAnimations().length,
      };
    });
    expect(snap.state).toBe('closed');
    expect(snap.closing, 'reduced-motion: sönme sınıfı hiç eklenmemeli').toBe(false);
    expect(snap.rendered, 'reduced-motion: anında kapanmalı').toBe(false);
    expect(snap.animations).toBe(0);
  });
});
