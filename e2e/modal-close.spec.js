// FAB modallarının (sepet + site arama) kapanış animasyonu — gerçek tarayıcı testi.
//
// NEDEN: iki modal da kapanışta `hidden` sınıfını ANINDA ekliyordu; `display:
// none` geçişi kestiği için kapanış hiç görünmüyordu (açılış da animasyonsuzdu).
// Artık `.nx-modal-closing` sınıfıyla 200 ms boyunca sönüp aşağı kayıyor, süre
// bitince `hidden` uygulanıyor; açılış aynı yolu tersine kullanıyor.
//
// Ölçüm Animation API + computed style üzerinden yapılır: önizleme webview'i
// CSS geçişlerini oynatmadığı için animasyonun *oynadığını* yalnız gerçek
// tarayıcı motoru ölçebilir.
//
// Kapsam:
//   1) Kapanışta modal anında kaybolmaz: fade + kayma oynar, sonra gizlenir
//   2) Site arama overlay'i aynı yoldan kapanır (girdi sönme BİTİNCE temizlenir)
//   3) Sönme sürerken yeniden açmak iptal eder (modal açık kalır)
//   4) `prefers-reduced-motion: reduce` → animasyon yok, anında kapanır
const { test, expect } = require('@playwright/test');

const CART_MODAL = '#cart-modal';
const CART_CLOSE = '#cart-modal-close';
const CART_OPEN = '#cart-fab-btn';
const SEARCH_MODAL = '#search-modal';
const SEARCH_CLOSE = '#search-modal-close';
// Demo ana sayfasında yüzen arama FAB'ı KALDIRILIR (main.js: `searchFab.remove()`):
// arama masaüstü header'ındaki birleşik alana taşındı. Overlay'i açan gerçek yol
// header formunun submit'idir ve sorguyu da modala taşır.
const SEARCH_OPEN_FIELD = '#nexus-header-search input';

// Sayfa içi ölçüm: tur gecikmesi zamanlamaya karışmasın.
function probe(modalSel, closeSel) {
  return `async ({ frames2, framesN, action }) => {
    const frames = (n) =>
      new Promise((res) => { let i = n; const step = () => (--i <= 0 ? res() : requestAnimationFrame(step)); requestAnimationFrame(step); });
    const root = document.querySelector('${modalSel}');
    if (!root) return { error: 'modal bulunamadı' };
    const panel = root.firstElementChild;

    const snap = () => {
      const rs = getComputedStyle(root);
      const ps = getComputedStyle(panel);
      const input = document.getElementById('site-search');
      return {
        closing: root.classList.contains('nx-modal-closing'),
        opening: root.classList.contains('nx-modal-opening'),
        hidden: root.classList.contains('hidden'),
        display: rs.display,
        rendered: root.getClientRects().length > 0,
        opacity: parseFloat(rs.opacity),
        panelOpacity: parseFloat(ps.opacity),
        transform: ps.transform,
        inputValue: input ? input.value : null,
        animations: panel.getAnimations().map((a) => ({
          name: a.transitionProperty || a.animationName || null,
          state: a.playState,
          dur: a.effect.getComputedTiming().duration,
        })),
      };
    };

    const before = snap();
    if (action === 'close') {
      const c = document.querySelector('${closeSel}');
      if (!c) return { error: 'kapatma düğmesi bulunamadı' };
      c.click();
    }
    await frames(frames2);
    const mid = snap();
    await frames(framesN);
    const after = snap();
    return { before, mid, after };
  }`;
}

function runProbe(page, modalSel, closeSel, opts) {
  return page.evaluate(new Function('args', `return (${probe(modalSel, closeSel)})(args);`), opts);
}

// Açılış da animasyonlu: ölçüme temiz bir "tam açık" durumundan başlamak
// gerekir. `nx-modal-opening` sınıfı ilk karede kalktığı için tek başına
// yetmez; opaklık 1'e oturana kadar beklenir (aksi halde kapanış ölçümü
// süren açılış geçişinin ortasından başlar).
async function openCart(page) {
  await page.goto('/');
  await page.click(CART_OPEN);
  await page.waitForFunction((sel) => {
    const m = document.querySelector(sel);
    return !!m && !m.classList.contains('hidden') && parseFloat(getComputedStyle(m).opacity) === 1;
  }, CART_MODAL);
}

async function openSearch(page) {
  await page.goto('/');
  await page.fill(SEARCH_OPEN_FIELD, 'hotel');
  await page.press(SEARCH_OPEN_FIELD, 'Enter');
  await page.waitForFunction((sel) => {
    const m = document.querySelector(sel);
    return !!m && !m.classList.contains('hidden') && parseFloat(getComputedStyle(m).opacity) === 1;
  }, SEARCH_MODAL);
}

test.describe('FAB modal kapanış animasyonu', () => {
  test('sepet modalı kapanışta anında kaybolmaz: fade + kayma oynar, sonra gizlenir', async ({ page }) => {
    await openCart(page);

    // `frames2: 6`: geçiş bir sonraki karede başlar; ilk karede henüz 0
    // ilerleme görülür ve ölçüm titrer.
    const r = await runProbe(page, CART_MODAL, CART_CLOSE, { frames2: 6, framesN: 26, action: 'close' });
    expect(r.error).toBeUndefined();

    // Başlangıç: açık, ekranda, tam opak
    expect(r.before.hidden).toBe(false);
    expect(r.before.rendered).toBe(true);
    expect(r.before.display).toBe('flex');
    expect(r.before.opacity).toBe(1);
    expect(r.before.closing).toBe(false);

    // Kapanış sürerken: sönme sınıfı var, modal hâlâ render ediliyor
    expect(r.mid.closing, 'kapanış sönme sınıfından geçmeli').toBe(true);
    expect(r.mid.rendered, 'sönme sürerken modal DOM\'da kalmalı').toBe(true);
    expect(r.mid.display).toBe('flex');
    expect(r.mid.opacity).toBeLessThan(1);
    // Aşağı kayma başlamış olmalı: panel transformu artık identity değil
    expect(r.mid.transform).not.toBe('none');
    expect(r.mid.transform).not.toBe(r.before.transform);

    // Sönme bitince: sınıf temizlenir, modal gizlenir
    expect(r.after.closing).toBe(false);
    expect(r.after.hidden).toBe(true);
    expect(r.after.display).toBe('none');
    expect(r.after.rendered).toBe(false);
  });

  test('kapanış gerçekten oynar: transform + opacity geçişleri 200 ms', async ({ page }) => {
    await openCart(page);
    const r = await runProbe(page, CART_MODAL, CART_CLOSE, { frames2: 2, framesN: 26, action: 'close' });

    const running = r.mid.animations.filter((a) => a.state === 'running');
    expect(running.length, 'kapanışta en az bir geçiş oynamalı').toBeGreaterThanOrEqual(1);
    const props = running.map((a) => a.name);
    expect(props).toContain('transform');
    expect(props).toContain('opacity');

    // Süre CSS `.2s` ile ve JS `MODAL_CLOSE_MS` ile uyuşmalı
    const transform = running.find((a) => a.name === 'transform');
    expect(transform.dur).toBeCloseTo(200, -1);

    // Bitince hiçbir geçiş kalmaz (modal gizli)
    expect(r.after.animations.length).toBe(0);
  });

  test('site arama overlay\'i aynı yoldan kapanır; girdi sönme bitince temizlenir', async ({ page }) => {
    // Header formu açarken sorguyu modala taşır — kapanış sırasında bu
    // sorgunun ne zaman silindiğini ölçmek istiyoruz.
    await openSearch(page);
    const typed = await page.inputValue('#site-search');
    expect(typed).toBe('hotel');

    const r = await runProbe(page, SEARCH_MODAL, SEARCH_CLOSE, { frames2: 6, framesN: 26, action: 'close' });
    expect(r.error).toBeUndefined();

    expect(r.before.rendered).toBe(true);
    expect(r.before.inputValue).toBe('hotel');
    // Sönme sürerken sonuçlar kaybolmaz: sınıf var, içerik hâlâ yerinde
    expect(r.mid.closing).toBe(true);
    expect(r.mid.rendered).toBe(true);
    expect(r.mid.inputValue, 'sönme sürerken sorgu silinmemeli').toBe('hotel');
    expect(r.mid.opacity).toBeLessThan(1);

    expect(r.after.hidden).toBe(true);
    expect(r.after.rendered).toBe(false);
    expect(r.after.inputValue, 'temizlik ancak kapanış bitince').toBe('');
  });

  test('sönme sürerken yeniden açmak iptal eder: modal açık kalır', async ({ page }) => {
    await openCart(page);

    const r = await runProbe(page, CART_MODAL, CART_CLOSE, { frames2: 2, framesN: 8, action: 'close' });
    expect(r.mid.closing).toBe(true);

    // Sönme bitmeden yeniden aç
    await page.click(CART_OPEN);
    // Bekleyen gizleme ateşlenseydi modal kapanırdı.
    await page.waitForTimeout(420);
    const after = await page.evaluate((sel) => {
      const m = document.querySelector(sel);
      return {
        closing: m.classList.contains('nx-modal-closing'),
        hidden: m.classList.contains('hidden'),
        rendered: m.getClientRects().length > 0,
        opacity: parseFloat(getComputedStyle(m).opacity),
      };
    }, CART_MODAL);
    expect(after.closing, 'açılış bekleyen sönmeyi iptal etmeli').toBe(false);
    expect(after.hidden).toBe(false);
    expect(after.rendered).toBe(true);
    expect(after.opacity).toBe(1);
  });

  test('kapanış sürerken ikinci kapatma isteği yok sayılır (tek zamanlayıcı)', async ({ page }) => {
    await openCart(page);
    // Sönme sürerken ikinci bir kapatma isteği (kullanıcı Escape'e iki kez
    // bastı) erken dönmeli: aksi hâlde ikinci zamanlayıcı kurulur ve gizleme
    // uzar, ya da açılışla yarışır.
    await page.keyboard.press('Escape');
    const first = await page.evaluate((sel) => {
      const m = document.querySelector(sel);
      return { closing: m.classList.contains('nx-modal-closing'), hidden: m.classList.contains('hidden') };
    }, CART_MODAL);
    expect(first.closing).toBe(true);
    expect(first.hidden).toBe(false);

    await page.keyboard.press('Escape');
    const second = await page.evaluate((sel) => {
      const m = document.querySelector(sel);
      return { closing: m.classList.contains('nx-modal-closing'), hidden: m.classList.contains('hidden') };
    }, CART_MODAL);
    expect(second.closing, 'ikinci istek sönmeyi yeniden başlatmamalı').toBe(true);
    expect(second.hidden).toBe(false);

    await page.waitForTimeout(320);
    const gone = await page.evaluate((sel) => {
      const m = document.querySelector(sel);
      return { hidden: m.classList.contains('hidden'), closing: m.classList.contains('nx-modal-closing') };
    }, CART_MODAL);
    expect(gone.hidden).toBe(true);
    expect(gone.closing).toBe(false);
  });
});

test.describe('FAB modal kapanışı — hareket azaltma', () => {
  test.use({ reducedMotion: 'reduce' });

  test('reduced-motion altında modal animasyonsuz kapanır', async ({ page }) => {
    await openCart(page);
    await page.click(CART_CLOSE);
    await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
    const snap = await page.evaluate((sel) => {
      const m = document.querySelector(sel);
      const panel = m.firstElementChild;
      return {
        closing: m.classList.contains('nx-modal-closing'),
        hidden: m.classList.contains('hidden'),
        rendered: m.getClientRects().length > 0,
        animations: panel.getAnimations().length,
      };
    }, CART_MODAL);
    expect(snap.closing, 'reduced-motion: sönme sınıfı hiç eklenmemeli').toBe(false);
    expect(snap.hidden, 'reduced-motion: anında gizlenmeli').toBe(true);
    expect(snap.rendered).toBe(false);
    expect(snap.animations).toBe(0);
  });
});
