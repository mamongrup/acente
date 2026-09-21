// Popover kapanış sönmesi (.nx-closing) — gerçek tarayıcı testleri.
//
// NEDEN: kapanışta panel anında `display: none` oluyordu; artık 140 ms'lik bir
// opacity sönmesi oynatılıyor (chisfis-bridge.css `nx-panel-out`). Ölçüm
// Animation API + computed style üzerinden yapılır (piksel farkı yok), çünkü
// önizleme webview'i animasyonları oynatmaz.
//
// Kapsam:
//   1) Kapanışta panel bir süre görünür kalır, sönme oynar, sonra gizlenir
//   2) Sönme sürerken yeniden açmak sönmeyi iptal eder (panel görünür kalır)
//   3) Escape ile kapanış da aynı sönmeyi kullanır
//   4) prefers-reduced-motion: reduce → sönme yok, anında kapanır
const { test, expect } = require('@playwright/test');

const BTN = '#popover-button-2'; // Keşfet popover'ı
const PANEL = '#popover-panel-2';

// Sayfa içi ölçüm: tur gecikmesi zamanlamaya karışmasın.
const PROBE = `async ({ panelSel, action, waitFrames }) => {
  const frames = (n) =>
    new Promise((res) => { let i = n; const step = () => (--i <= 0 ? res() : requestAnimationFrame(step)); requestAnimationFrame(step); });
  const panel = document.querySelector(panelSel);
  if (!panel) return { error: 'panel yok: ' + panelSel };

  const snap = () => ({
    state: panel.getAttribute('data-state'),
    hidden: panel.hidden,
    closing: panel.classList.contains('nx-closing'),
    rendered: panel.getClientRects().length > 0,
    display: getComputedStyle(panel).display,
    opacity: parseFloat(getComputedStyle(panel).opacity),
    panelAnim: panel.getAnimations().map((a) => ({ name: a.animationName || null, state: a.playState, dur: a.effect.getComputedTiming().duration })),
    childAnim: Array.from(panel.children).map((c) => getComputedStyle(c).animationName).filter((n) => n !== 'none'),
    childOpacity: Array.from(panel.children).map((c) => parseFloat(getComputedStyle(c).opacity)),
  });

  // Sönmenin GERÇEKTEN başladığını olay kaydıyla da yakala: 'mid' anlık
  // görüntüsü 2 kare sonra alınıyor ve yük altında 2 kare 140 ms'i aşarsa
  // animasyon bitmiş olur (titresimin kaynağı buydu).
  const seen = [];
  const rec = (e) => {
    const anim = e.target.getAnimations().find((a) => a.animationName === e.animationName);
    seen.push({
      name: e.animationName,
      dur: anim ? anim.effect.getComputedTiming().duration : null,
      target: e.target === panel ? 'panel' : 'child',
    });
  };
  document.addEventListener('animationstart', rec, true);

  const before = snap();
  if (action === 'outside') document.body.dispatchEvent(new MouseEvent('click', { bubbles: true }));
  else if (action === 'escape') document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
  await frames(2);
  const mid = snap();
  await frames(waitFrames);
  const after = snap();
  document.removeEventListener('animationstart', rec, true);
  return { before, mid, after, seen };
}`;

async function openPopover(page) {
  await page.goto('/');
  await page.click(BTN);
  await page.waitForFunction((sel) => document.querySelector(sel)?.getAttribute('data-state') === 'open', PANEL);
  // Panelin kendi giriş animasyonu (nc-pop-in .15s) bitsin: ölçüm temiz
  // başlangıç değerini (opacity 1) görsün.
  await page.waitForFunction((sel) => document.querySelector(sel).getAnimations().length === 0, PANEL);
}

test.describe('popover kapanış sönmesi', () => {
  test.use({ viewport: { width: 1280, height: 820 } });

  test('kapanışta panel anında kaybolmaz: sönme oynar, sonra gizlenir', async ({ page }) => {
    await openPopover(page);
    const r = await page.evaluate(
      new Function('args', 'return (' + PROBE + ')(args)'),
      { panelSel: PANEL, action: 'outside', waitFrames: 20 },
    );

    expect(r.before.rendered).toBe(true);
    expect(r.before.opacity).toBe(1);

    // Sönme başladı ama panel hâlâ DOM'da ve görünür
    expect(r.mid.state).toBe('closed'); // durum ANINDA kapanır (düğme mantığı bozulmasın)

    // Sönmenin başladığı İKİ kanaldan doğrulanır: ara anlık görüntü ya da
    // `animationstart` kaydı. Yük altında 2 kare 140 ms'i aşarsa sönme bitmiş
    // olur (animasyon listeden düşer) — olay kaydı bunu titreşimsiz yakalar.
    const fadeStarted = r.mid.closing || r.seen.some((s) => s.name === 'nx-panel-out');
    expect(fadeStarted, 'sönme başlamış olmalı').toBe(true);

    if (r.mid.closing) {
      // Zamanlama ara durumu yakaladıysa görsel sözleşmeler birebir ölçülür
      expect(r.mid.hidden).toBe(false);
      expect(r.mid.rendered).toBe(true);
      expect(r.mid.opacity).toBeLessThan(1);
    }

    const panelOut =
      r.mid.panelAnim.find((a) => a.name === 'nx-panel-out') ||
      r.seen.find((s) => s.name === 'nx-panel-out');
    expect(panelOut, 'nx-panel-out animasyonu kaydedilmeli').toBeTruthy();
    expect(panelOut.dur).toBe(140);
    // Çocuklar `opacity: 0` temelli olduğundan sönme sırasında da animasyon alır
    const childFade =
      r.mid.childAnim.includes('nx-child-out') ||
      r.seen.some((s) => s.name === 'nx-child-out');
    expect(childFade, 'nx-child-out çocuk animasyonu kaydedilmeli').toBe(true);
    if (r.mid.closing) {
      expect(Math.min(...r.mid.childOpacity)).toBeGreaterThan(0);
    }

    // Süre bitince tamamen gizlenir
    expect(r.after.hidden).toBe(true);
    expect(r.after.display).toBe('none');
    expect(r.after.rendered).toBe(false);
    expect(r.after.closing).toBe(false);
  });

  test('sönme sürerken yeniden açmak sönmeyi iptal eder', async ({ page }) => {
    await openPopover(page);
    // Sayfa içi yardımcı yeniden açmayı butona tıklayarak yapar
    const result = await page.evaluate(async ({ btnSel, panelSel }) => {
      const frames = (n) => new Promise((res) => { let i = n; const step = () => (--i <= 0 ? res() : requestAnimationFrame(step)); requestAnimationFrame(step); });
      const panel = document.querySelector(panelSel);
      const btn = document.querySelector(btnSel);
      // kapat (dış tık)
      document.body.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      await frames(2);
      const closing = panel.classList.contains('nx-closing');
      // sönme sürerken yeniden aç
      btn.click();
      await frames(25); // ~400ms
      return {
        closingAtReopen: closing,
        state: panel.getAttribute('data-state'),
        hidden: panel.hidden,
        closingAfter: panel.classList.contains('nx-closing'),
        opacity: parseFloat(getComputedStyle(panel).opacity),
        rendered: panel.getClientRects().length > 0,
        openAnimation: panel.getAnimations().some((a) => a.animationName === 'nx-panel-out'),
      };
    }, { btnSel: BTN, panelSel: PANEL });

    expect(result.closingAtReopen).toBe(true);
    expect(result.state).toBe('open');
    expect(result.hidden).toBe(false);
    expect(result.closingAfter).toBe(false);
    expect(result.opacity).toBe(1);
    expect(result.rendered).toBe(true);
    // Sönme animasyonu artık oynamıyor
    expect(result.openAnimation).toBe(false);
  });

  test('Escape ile kapanış da sönmeyi kullanır', async ({ page }) => {
    await openPopover(page);
    const r = await page.evaluate(
      new Function('args', 'return (' + PROBE + ')(args)'),
      { panelSel: PANEL, action: 'escape', waitFrames: 20 },
    );
    expect(r.mid.closing).toBe(true);
    expect(r.mid.rendered).toBe(true);
    expect(r.after.hidden).toBe(true);
  });

  test('prefers-reduced-motion: reduce → sönme yok, anında kapanır', async ({ browser }) => {
    const context = await browser.newContext({ reducedMotion: 'reduce', viewport: { width: 1280, height: 820 } });
    const page = await context.newPage();
    await openPopover(page);
    const r = await page.evaluate(
      new Function('args', 'return (' + PROBE + ')(args)'),
      { panelSel: PANEL, action: 'outside', waitFrames: 2 },
    );
    expect(r.mid.closing).toBe(false);
    expect(r.mid.hidden).toBe(true);
    expect(r.mid.rendered).toBe(false);
    expect(r.after.hidden).toBe(true);
    await context.close();
  });
});
