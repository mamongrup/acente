// Mobil menü basma ( :active ) geri bildirimi — gerçek tarayıcı testleri.
//
// NEDEN: mobil menüdeki hover kurallarının TAMAMI `@media (hover: hover)`
// arkasında (parmakla dokunulan öğe "hover'ılı" kalmasın diye). Yani telefonda
// tek geri bildirim kaynağı basma hâlidir; o da yoktu — basan kullanıcı hiçbir
// tepki görmüyordu.
//
// SÖZLEŞME: basılı hâl `scale: .98` + bir basamak koyu zemin.
//   • Ölçek AYRI `scale` özelliğiyle verilir, shorthand `transform` ile değil:
//     hover `transform`'ları (`.mm-ico` translateY(-2px), `.mm-pop__opt`
//     translateX(2px), `.mm-foot-btn` translateY(-1px)) basma anında
//     SIFIRLANMAMALI — `scale` onlarla bileşir.
//   • Basılı süre .1s, bırakış taban ritme (.15–.2s) döner.
//   • Hareket azaltmada ölçek kapanır, zemin/renk geri bildirimi kalır.
//   • Basılı zeminde metin/ikon kontrastı hâlâ AA.
//
// Ölçüm: `mouse.down()` gerçek `:active` durumunu tetikler. Bırakma, öğeden
// UZAĞA taşındıktan sonra yapılır — aksi halde linkler tıklanıp sayfa değişir.
const { test, expect } = require('@playwright/test');

const OPEN_BTN = '.bnav-item[data-act="menu"]';

// Basılı hâlde beklenen zemin — kural: hover zemininin BİR BASAMAK koyusu.
// `.mm-foot-btn`'in hover zemini zaten neutral-100 olduğu için onun basılı hâli
// neutral-200'dür; ilk sürümde bu atlanmıştı ve üstünde basılı tutan kullanıcı
// hiçbir değişiklik görmüyordu (bu spec tam olarak bunu yakaladı).
const TARGETS = [
  { sel: '.mm-acc-head', key: 'akordeon başlığı', light: '--color-neutral-100', dark: '--color-neutral-700' },
  { sel: '.mm-acc-inner > a', key: 'alt link', light: '--color-neutral-100', dark: '--color-neutral-700' },
  { sel: '.mm-direct', key: 'doğrudan link', light: '--color-neutral-100', dark: '--color-neutral-700' },
  { sel: '.mm-ico:not(.mm-ico--wa)', key: 'ikon düğmesi', light: '--color-neutral-100', dark: '--color-neutral-700' },
  { sel: '.mm-foot-btn', key: 'footer düğmesi', light: '--color-neutral-200', dark: '--color-neutral-700' },
];

const OPT_BG = {
  light: '--color-neutral-200',
  dark: '--color-neutral-600',
};

const HELPERS = `
const __cv = document.createElement('canvas');
__cv.width = __cv.height = 1;
const __ctx = __cv.getContext('2d');
function rgba(str) {
  try {
    __ctx.clearRect(0, 0, 1, 1);
    __ctx.fillStyle = '#000';
    __ctx.fillStyle = String(str);
    __ctx.fillRect(0, 0, 1, 1);
    const d = __ctx.getImageData(0, 0, 1, 1).data;
    return { r: d[0], g: d[1], b: d[2], a: d[3] / 255 };
  } catch (e) { return null; }
}
function effBg(el) {
  const layers = [];
  let node = el;
  while (node && node.nodeType === 1) {
    const c = rgba(getComputedStyle(node).backgroundColor);
    if (c && c.a > 0) { layers.push(c); if (c.a >= 1) break; }
    node = node.parentElement;
  }
  let out = [255, 255, 255];
  for (let i = layers.length - 1; i >= 0; i--) {
    const l = layers[i];
    out = [l.r * l.a + out[0] * (1 - l.a), l.g * l.a + out[1] * (1 - l.a), l.b * l.a + out[2] * (1 - l.a)];
  }
  return out.map(Math.round);
}
function lum(rgb) {
  const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
  return 0.2126 * f(rgb[0]) + 0.7152 * f(rgb[1]) + 0.0722 * f(rgb[2]);
}
function contrast(fg, bg) {
  const a = Math.max(lum(fg), lum(bg)), b = Math.min(lum(fg), lum(bg));
  return Math.round(((a + 0.05) / (b + 0.05)) * 100) / 100;
}
function snap(el) {
  const cs = getComputedStyle(el);
  const bg = effBg(el);
  const fg = rgba(cs.color);
  const ico = el.querySelector('i, svg');
  const icoBg = ico ? effBg(ico.parentElement) : null;
  const icoFg = ico ? rgba(getComputedStyle(ico).color) : null;
  return {
    scale: cs.scale,
    transform: cs.transform,
    background: 'rgb(' + bg.join(', ') + ')',
    bgRaw: cs.backgroundColor,
    color: cs.color,
    contrast: contrast([fg.r, fg.g, fg.b], bg),
    icoContrast: icoFg && icoBg ? contrast([icoFg.r, icoFg.g, icoFg.b], icoBg) : null,
    transitionScale: cs.transitionProperty.includes('scale') ? cs.transitionDuration : null,
  };
}
`;

async function newCtx(browser, pref, extra = {}) {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, ...extra });
  await ctx.addInitScript((v) => {
    try {
      localStorage.setItem('chisfis-theme', v);
      localStorage.setItem('chisfis-theme-pref', v);
    } catch (e) {}
  }, pref);
  const page = await ctx.newPage();
  await page.goto('/');
  await page.waitForTimeout(900);
  return { ctx, page };
}

async function openDrawer(page) {
  await page.evaluate((sel) => document.querySelector(sel).click(), OPEN_BTN);
  await page.waitForFunction(
    () => document.querySelector('.mobile-menu')?.getAttribute('data-state') === 'open',
  );
  await page.waitForTimeout(700);
  // Alt linklerin bulunduğu accordion açık olsun
  await page.evaluate(() => {
    const acc = document.querySelector('.mobile-menu .mm-acc');
    if (acc && acc.getAttribute('data-open') !== '1') acc.querySelector('.mm-acc-head').click();
  });
  await page.waitForTimeout(450);
}

async function tokenRgb(page, name) {
  return page.evaluate((n) => {
    const p = document.createElement('span');
    p.style.color = 'var(' + n + ')';
    document.body.appendChild(p);
    const v = getComputedStyle(p).color;
    p.remove();
    return v;
  }, name);
}

/**
 * Bırakışın ürettiği tıklamayı YUTAR (yakalama fazında).
 *
 * Neden gerekli: basılı hâli ölçmek için gerçek `mouse.down()` şart, ama
 * `mouse.up()` bir tıklama üretir ve o tıklamanın yan etkileri ölçümü bozar:
 *   • akordeon başlığı aç/kapa yapar → alt linkler görünmez olur,
 *   • linkler sayfa değiştirir,
 *   • fareyi uzağa taşıyıp bırakmak ise çekmece PERDESİNE tıklar → menü kapanır
 *     (ilk denemede tam bu oldu: döngü ikinci öğede kördü, 30 sn timeout).
 *
 * Bu yüzden tıklama yakalama fazında `preventDefault + stopPropagation` ile
 * yutulur. Sadece GÖRSEL basma hâli ölçüldüğü için bu doğrudur; tıklama
 * davranışı zaten `drawer-close`, `mobile-menu-active` ve `mobile-menu-parity`
 * spec'lerinin konusudur.
 */
async function suppressClicks(page) {
  await page.evaluate(() => {
    window.__pressSuppress = (e) => {
      e.preventDefault();
      e.stopPropagation();
    };
    document.addEventListener('click', window.__pressSuppress, true);
  });
}

async function unsuppressClicks(page) {
  await page.evaluate(() => {
    document.removeEventListener('click', window.__pressSuppress, true);
  });
}

/** Çekmece ve ilk accordion açık olsun (alt linkler görünür kalsın). */
async function ensureOpenState(page) {
  const state = await page.evaluate(() => ({
    drawer: document.querySelector('.mobile-menu')?.getAttribute('data-state'),
    acc: document.querySelector('.mobile-menu .mm-acc')?.getAttribute('data-open'),
  }));
  if (state.drawer !== 'open') {
    await openDrawer(page);
    return;
  }
  if (state.acc !== '1') {
    await page.evaluate(() =>
      document.querySelector('.mobile-menu .mm-acc .mm-acc-head').click(),
    );
    await page.waitForTimeout(400);
  }
}

/** Basılı hâli ölçer: hover → down → oku → up (tıklama yutulur) → oku. */
async function pressRead(page, selector) {
  await ensureOpenState(page);
  const loc = page.locator('.mobile-menu ' + selector).first();
  await loc.scrollIntoViewIfNeeded();
  const fn = new Function('el', `${HELPERS}; return snap(el);`);
  const idle = await loc.evaluate(fn);
  await loc.hover();
  await page.waitForTimeout(280);
  const hovered = await loc.evaluate(fn);

  await suppressClicks(page);
  await page.mouse.down();
  await page.waitForTimeout(180); // basılı süre .1s
  const pressed = await loc.evaluate(fn);
  await page.mouse.up();
  await page.waitForTimeout(240);
  const released = await loc.evaluate(fn);
  await unsuppressClicks(page);

  return { idle, hovered, pressed, released };
}

test.describe('mobil menü basma geri bildirimi', () => {
  for (const pref of ['light', 'dark']) {
    test(`${pref}: basılı hâl scale .98 + zemin kararması verir, bırakınca döner`, async ({ browser }) => {
      const { ctx, page } = await newCtx(browser, pref);
      await openDrawer(page);

      const rows = [];

      for (const t of TARGETS) {
        const r = await pressRead(page, t.sel);
        const expectedBg = await tokenRgb(page, t[pref]);
        // Basılı hâl: ölçek .98
        expect(r.idle.scale, `${t.key} boştayken ölçek yok`).toBe('none');
        expect(r.pressed.scale, `${t.key} basılıyken .98`).toBe('0.98');
        // Zemin kararması: beklenen token'a birebir eşit ve DİNLENME hâlinden
        // farklı (fare bağlamında hover zemini ile aynı olabilir — dokunmatikte
        // hover yoktur, orada değişimin kaynağı bu basamaktır).
        expect(r.pressed.background, `${t.key} basılı zemin`).toBe(expectedBg);
        expect(r.pressed.background, `${t.key} dinlenme zeminiyle aynı olmamalı`)
          .not.toBe(r.idle.background);
        // Bırakınca döner
        expect(r.released.scale, `${t.key} bırakınca ölçek geri döner`).toBe('none');
        // Basılı hâlde de okunur kalır
        expect(r.pressed.contrast, `${t.key} basılı kontrast`).toBeGreaterThanOrEqual(4.5);
        if (r.pressed.icoContrast !== null) {
          expect(r.pressed.icoContrast, `${t.key} basılı ikon kontrastı`).toBeGreaterThanOrEqual(3);
        }
        // Basmaya özel hızlı süre (.1s) — bırakışta taban ritim
        expect(r.pressed.transitionScale, `${t.key} ölçek geçişi tanımlı`).toContain('0.1s');
        rows.push(`${t.key}: ${r.idle.background} → ${r.pressed.background}`);
      }
      console.log(`[basma ${pref}] ${rows.join(' | ')}`);
      await ctx.close();
    });
  }

  test('ölçek hover kaymasını SIFIRLAMAZ (ayrı scale özelliği)', async ({ browser }) => {
    const { ctx, page } = await newCtx(browser, 'light');
    await openDrawer(page);

    // İkon düğmesi: hover'da translateY(-2px)
    const ico = await pressRead(page, '.mm-ico:not(.mm-ico--wa)');
    expect(ico.hovered.transform, 'hover kayması uygulanmış').toBe('matrix(1, 0, 0, 1, 0, -2)');
    expect(ico.pressed.transform, 'basılıyken hover kayması KORUNUR').toBe(ico.hovered.transform);
    expect(ico.pressed.scale, 've üstüne ölçek biner').toBe('0.98');

    // Footer düğmesi: hover'da translateY(-1px)
    const foot = await pressRead(page, '.mm-foot-btn');
    expect(foot.hovered.transform).toBe('matrix(1, 0, 0, 1, 0, -1)');
    expect(foot.pressed.transform, 'footer kayması korunur').toBe(foot.hovered.transform);

    await ctx.close();
  });

  test('WhatsApp düğmesi marka yeşilini korur, yeşilin koyu tonuna kararır', async ({ browser }) => {
    const { ctx, page } = await newCtx(browser, 'light');
    await openDrawer(page);
    const r = await pressRead(page, '.mm-ico--wa');
    expect(r.pressed.scale).toBe('0.98');
    expect(r.pressed.background).toBe('rgb(22, 163, 74)'); // #16a34a
    expect(r.idle.background).toBe('rgb(34, 197, 94)'); // #22c55e
    await ctx.close();
  });

  test('dil/para seçenekleri ve sekmelerinde de basma geri bildirimi var', async ({ browser }) => {
    const { ctx, page } = await newCtx(browser, 'light');
    await openDrawer(page);
    await page.evaluate(() => document.querySelector('.mobile-menu .mm-pill').click());
    await page.waitForTimeout(400);

    const optBg = await tokenRgb(page, OPT_BG.light);
    const opt = await pressRead(page, '.mm-pop__opt');
    expect(opt.pressed.scale).toBe('0.98');
    expect(opt.pressed.background).toBe(optBg); // seçenekler bir basamak daha koyu
    expect(opt.pressed.transform, 'seçenek kayması (translateX 2px) korunur')
      .toBe(opt.hovered.transform);

    const tab = await pressRead(page, '.mm-pop__tab');
    expect(tab.pressed.scale).toBe('0.98');
    expect(tab.pressed.background).not.toBe(tab.hovered.background);
    await ctx.close();
  });

  test('pill basma geri bildirimi verir', async ({ browser }) => {
    const { ctx, page } = await newCtx(browser, 'light');
    await openDrawer(page);
    const r = await pressRead(page, '.mm-pill');
    expect(r.pressed.scale).toBe('0.98');
    expect(r.pressed.background).not.toBe(r.hovered.background);
    await ctx.close();
  });

  test('hareket azaltmada ölçek yok, zemin kararması kalır', async ({ browser }) => {
    // Tema AÇIKÇA sabitlenir: `newCtx` olmadan bağlam tema tercihi taşımaz
    // ve sayfa zaman-bazlı `auto` çözümüne düşer — akşam/gece yüklenişte
    // karanlık palet açılır, oysa karşılaştırma AYDINLIK tokenla yapılır ve
    // test saat bağımlı olarak düşer (ölçülen: karanlık neutral-700'e karşı
    // aydınlık neutral-100). Aydınlık tema tüm kardeş testlerde olduğu gibi
    // burada da sabitlenir.
    const { ctx, page } = await newCtx(browser, 'light', { reducedMotion: 'reduce' });
    await openDrawer(page);

    const bg = await tokenRgb(page, TARGETS[0].light);
    const loc = page.locator('.mobile-menu ' + TARGETS[0].sel).first();
    const fn = new Function('el', `${HELPERS}; return snap(el);`);
    await loc.hover();
    await suppressClicks(page);
    await page.mouse.down();
    await page.waitForTimeout(150);
    const pressed = await loc.evaluate(fn);
    await page.mouse.up();
    await unsuppressClicks(page);

    expect(pressed.scale, 'ölçek hareketi kapalı').toBe('none');
    expect(pressed.background, 'zemin geri bildirimi kalır').toBe(bg);
    await ctx.close();
  });

  test('dokunmatik bağlamda (hover: none) basma kuralları hover kapısına takılmıyor', async ({ browser }) => {
    // `hasTouch: true` → `@media (hover: none)` eşleşir: hover kuralları yok, yani
    // basma hâli bu bağlamdaki tek geri bildirimdir.
    const { ctx, page } = await newCtx(browser, 'light', { hasTouch: true });
    const hoverNone = await page.evaluate(() => matchMedia('(hover: none)').matches);
    test.skip(!hoverNone, 'bu motor hover:none eşleştirmedi');

    await openDrawer(page);
    const bg = await tokenRgb(page, TARGETS[0].light);
    const sel = '.mobile-menu ' + TARGETS[0].sel;

    // 1) Hover gerçekten YOK: fare benzeri hareket hover stili uygulamıyor
    const icoSel = '.mobile-menu .mm-ico:not(.mm-ico--wa)';
    await page.locator(icoSel).first().hover();
    await page.waitForTimeout(300);
    const hovered = await page.evaluate((s) => ({
      transform: getComputedStyle(document.querySelector(s)).transform,
      border: getComputedStyle(document.querySelector(s)).borderColor,
    }), icoSel);
    expect(hovered.transform, 'hover: none bağlamında hover kayması yok').toBe('none');

    // 2) Basma hâli yine de uygulanır. Sentetik CDP `touchStart` bu motorda
    //    `:active` tetiklemiyor (ölçüldü: 400 ms sonra bile `:active` yok), bu
    //    yüzden DevTools'un "force element state" yolu kullanılır — kuralın
    //    hover kapısına takılmadığını KANITLAR. Gerçek bir fare basması için
    //    light/dark testleri var, kural hover'dan bağımsız aynı bildirimlerdir.
    const cdp = await ctx.newCDPSession(page);
    await cdp.send('DOM.enable');
    await cdp.send('CSS.enable');
    const { root } = await cdp.send('DOM.getDocument', { depth: -1 });
    const { nodeId } = await cdp.send('DOM.querySelector', { nodeId: root.nodeId, selector: sel });
    await cdp.send('CSS.forcePseudoState', { nodeId, forcedPseudoClasses: ['active'] });
    await page.waitForTimeout(200);
    const pressed = await page.evaluate((s) => {
      const cs = getComputedStyle(document.querySelector(s));
      return { scale: cs.scale, bg: cs.backgroundColor };
    }, sel);
    await cdp.send('CSS.forcePseudoState', { nodeId, forcedPseudoClasses: [] });

    expect(pressed.scale, 'dokunmatikte (hover yokken) basma ölçeği uygulanır').toBe('0.98');
    expect(pressed.bg, 'dokunmatikte basma zemini token’a eşit').toBe(bg);
    await ctx.close();
  });
});
