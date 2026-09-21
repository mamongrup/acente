// Mobil menü mikro etkileşimleri — aydınlık/karanlık parite + tema çözümü.
//
// Bu spec üç GERÇEK hatanın nöbetçisidir:
//
//   1) `applyTheme(<boolean>)` — mağaza her yüklemede zorla karanlığa dönüyordu,
//      yani AYDINLIK TEMA HİÇ ULAŞILAMIYORDU (`data-theme="light"` ama
//      `class="dark"`). Önce bu düzeltildi, sonra aydınlık palet doğrulanabildi.
//   2) Panel çocuklarındaki `mm-stagger-in` animasyonu (`transform` + `forwards`)
//      `.mm-actions`'ı STACKING CONTEXT yapıyor; `.mm-pop`'un `z-index: 20`'si
//      oraya hapsolup arama kutusu/CATEGORIES etiketi ALTINDA kalıyordu —
//      dil/para seçenekleri tıklanamıyordu.
//   3) `.mm-acc-inner > a:hover` zemin+renk kuralları `@media (hover: hover)`
//      dışındaydı (dokunmatikte yapışkan hover) ve `.mm-direct`'in kendi
//      rengi/çerçevesi geçişsizdi (`transition: all 0s`).
//
// ÖLÇÜM İLKELERİ (v1'i yanlış yapan tuzaklar):
//   • İkon kontrastı İKONUN KENDİ kabının zeminine karşı ölçülür; başlığın
//     zemin zinciri (`.mm-acc`) beyaz çıktığı için hover'daki beyaz ikon
//     1.0 veriyordu. Zemin `svg.parentElement`'ten yürünür.
//   • `.mm-acc-inner` linkleri accordion KAPALIYKEN (`max-height: 0`,
//     `overflow: hidden`) hover almaz — ölçümden önce accordion açılır.
//   • Kayma kaynağı bileşene göre değişir: bazıları kendi `transform`'u,
//     bazıları svg/ok çocuğu üzerinden kayar.
const { test, expect } = require('@playwright/test');

const OPEN_BTN = '.bnav-item[data-act="menu"]';
const ACC_HEAD = '.mm-acc-head';
const SUBLINK = '.mm-acc-inner > a';
const DIRECT = '.mm-direct';
const ICO = '.mm-ico:not(.mm-ico--wa)';
const PILL = '.mm-pill';

// slide: kaymanın ölçüleceği yer — `svg` başlıktaki İLK svg'yi (ikon rozeti)
// verir; akordeon başlığının kayması ise CHEVRON'dadır (`translateX(3px)`),
// bu yüzden `arrow` kullanılır.
const TARGETS = [
  { key: 'akordeon başlığı', sel: ACC_HEAD, slide: 'arrow', minDynamic: true },
  { key: 'alt link', sel: SUBLINK, slide: 'svg', minDynamic: true },
  { key: 'doğrudan link', sel: DIRECT, slide: 'arrow', minDynamic: true },
  { key: 'ikon düğmesi', sel: ICO, slide: 'self', minDynamic: true },
  // Açıcı pill kaymaz, RENK değiştirir (kendi `slide`ı 'none' kalır — parite
  // iddiası yine geçerli, dinamiklik renk farkıyla kanıtlanır)
  { key: 'dil/para pill', sel: PILL, slide: 'self', minDynamic: false },
];

const HELPERS = `
function rgba(str) {
  const m = String(str).match(/rgba?\\(([^)]+)\\)/);
  if (!m) return null;
  const p = m[1].split(',').map(Number);
  return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
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
function measure(el, slideKind) {
  const cs = getComputedStyle(el);
  const svg = el.querySelector('svg');
  const arrow = el.querySelector('.mm-dir-arrow') || el.querySelector('.mm-acc-chev');
  const slideEl = slideKind === 'svg' ? svg : slideKind === 'arrow' ? arrow : el;
  const bg = effBg(el);
  // İkon kendi kabının zeminine karşı ölçülür (rozet zemini != başlık zemini)
  const svgBg = svg ? effBg(svg.parentElement) : null;
  const fg = rgba(cs.color);
  const slideT = slideEl ? getComputedStyle(slideEl).transform : null;
  const mm = slideT ? slideT.match(/matrix\(([^)]+)\)/) : null;
  const part = mm ? mm[1].split(',').map(Number) : null;
  return {
    color: cs.color,
    bg: 'rgb(' + bg.join(', ') + ')',
    contrast: contrast([fg.r, fg.g, fg.b], bg),
    transition: cs.transitionProperty + '|' + cs.transitionDuration,
    slide: slideT,
    // Kayma (px) ve ölçek: akordeon başlığının chevron'u açıkken ROTATE
    // taşıdığı için transform farkı tek başına kanıt değil; ölçüyü ayrıştırıyoruz.
    slideTranslate: part ? Math.abs(part[4]) + Math.abs(part[5]) : 0,
    slideScale: part ? Math.abs(part[0]) : 1,
    svgBg: svgBg ? 'rgb(' + svgBg.join(', ') + ')' : null,
    svgContrast: svg && svgBg
      ? (function () {
          const s = rgba(getComputedStyle(svg).color);
          return contrast([s.r, s.g, s.b], svgBg);
        })()
      : null,
  };
}
`;

async function newCtx(browser, pref) {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
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
}

async function readTarget(page, t) {
  const loc = page.locator('.mobile-menu ' + t.sel).first();
  await loc.scrollIntoViewIfNeeded();
  const fn = new Function('el', 'kind', `${HELPERS}; return measure(el, kind);`);
  const passive = await loc.evaluate(fn, t.slide);
  await loc.hover();
  await page.waitForTimeout(280); // renk/transform geçişi (0.2s) tamamlansın
  const hover = await loc.evaluate(fn, t.slide);
  await page.mouse.move(2, 400); // hover'ı bırak (sonraki hedef kirli ölçülmesin)
  await page.waitForTimeout(80);
  return { passive, hover };
}

/** Accordion'lar kapalıyken alt linkler hover almaz → önce birini aç. */
async function openFirstAccordion(page) {
  await page.evaluate(() => {
    const acc = document.querySelector('.mobile-menu .mm-acc');
    if (acc && acc.getAttribute('data-open') !== '1') acc.querySelector('.mm-acc-head').click();
  });
  await page.waitForTimeout(450); // max-height .3s geçişi
}

const metresInTheme = async (browser, pref) => {
  const { ctx, page } = await newCtx(browser, pref);
  const theme = await page.evaluate(() =>
    document.documentElement.classList.contains('dark') ? 'dark' : 'light',
  );
  await openDrawer(page);

  const data = {};
  // Kapalı accordion gerekleri önce (chevron hâlâ translateX ile kayar)
  data[ACC_HEAD] = await readTarget(page, TARGETS[0]);
  data[ICO] = await readTarget(page, TARGETS[3]);
  data[PILL] = await readTarget(page, TARGETS[4]);
  data[DIRECT] = await readTarget(page, TARGETS[2]);
  // Sonra accordion açılıp alt linkler ölçülür
  await openFirstAccordion(page);
  data[SUBLINK] = await readTarget(page, TARGETS[1]);

  await ctx.close();
  return { theme, data };
};

test.describe('mağaza tema çözümü (zorla-karanlık regresyonu)', () => {
  test('açık tercih gerçekten aydınlık tema uygular', async ({ browser }) => {
    const { ctx, page } = await newCtx(browser, 'light');
    const s = await page.evaluate(() => ({
      hasDark: document.documentElement.classList.contains('dark'),
      hasSahra: document.documentElement.classList.contains('sahra'),
      dataTheme: document.documentElement.getAttribute('data-theme'),
      colorScheme: document.documentElement.style.colorScheme,
      panelBg: getComputedStyle(document.querySelector('.mobile-menu__panel')).backgroundColor,
      footLabel: (document.querySelector('.mm-foot-btn[data-role="theme"] span:not(.mm-foot-ico)') || {}).textContent,
    }));
    expect(s.dataTheme).toBe('light');
    expect(s.hasDark, 'aydınlık tercih dark sınıfını bırakmamalı').toBe(false);
    expect(s.hasSahra).toBe(false);
    expect(s.colorScheme).toBe('light');
    expect(s.footLabel).toBe('Light mode');
    await ctx.close();
  });

  test('koyu tercih dark sınıfını korur', async ({ browser }) => {
    const { ctx, page } = await newCtx(browser, 'dark');
    const s = await page.evaluate(() => ({
      hasDark: document.documentElement.classList.contains('dark'),
      dataTheme: document.documentElement.getAttribute('data-theme'),
      panelBg: getComputedStyle(document.querySelector('.mobile-menu__panel')).backgroundColor,
      footLabel: (document.querySelector('.mm-foot-btn[data-role="theme"] span:not(.mm-foot-ico)') || {}).textContent,
    }));
    expect(s.dataTheme).toBe('dark');
    expect(s.hasDark).toBe(true);
    expect(s.footLabel).toBe('Dark mode');
    await ctx.close();
  });
});

test.describe('mobil menü mikro etkileşim paritesi', () => {
  for (const pref of ['light', 'dark']) {
    test(`${pref}: hover durumları AA eşiğinin üstünde, mikro etkileşimler oynuyor`, async ({ browser }) => {
      const { theme, data } = await metresInTheme(browser, pref);
      expect(theme, 'istenen tema uygulanmış olmalı').toBe(pref);

      const rows = [];
      for (const t of TARGETS) {
        const m = data[t.sel];
        expect(m.passive.contrast, `${t.key} pasif kontrast`).toBeGreaterThanOrEqual(4.5);
        expect(m.hover.contrast, `${t.key} hover kontrast`).toBeGreaterThanOrEqual(4.5);
        if (m.hover.svgContrast !== null) {
          expect(m.hover.svgContrast, `${t.key} hover ikon kontrastı (${m.svgBg})`)
            .toBeGreaterThanOrEqual(3);
        }
        expect(m.hover.transition, `${t.key} geçiş tanımlı`).not.toContain('all|0s');
        rows.push(`${t.key}: ${m.passive.contrast}→${m.hover.contrast}`);
      }
      console.log(`[${pref}] ${rows.join(' | ')}`);
    });
  }

  test('mikro etkileşimler iki temada aynı ve gerçek', async ({ browser }) => {
    const light = await metresInTheme(browser, 'light');
    const dark = await metresInTheme(browser, 'dark');

    // Hover'da GERÇEKTEN kayması gereken hedefler (akordeon başlığı hariç:
    // aktif akordeonun chevron'u tabanda `rotate(180deg)` taşır, hover'da
    // renk değiştirir — bu yüzden orada ölçüt renk farkıdır)
    const SLIDES = [
      { sel: DIRECT, kind: 'ok', why: 'translateX(4px)' },
      { sel: ICO, kind: 'kendisi', why: 'translateY(-2px)' },
      { sel: SUBLINK, kind: 'ok svg', why: 'translateX(3px)' },
    ];

    for (const t of TARGETS) {
      const l = light.data[t.sel];
      const d = dark.data[t.sel];
      // Tema paritesi: hover'ın ürettiği geometri iki temada bit bit aynı
      expect(l.hover.slide, `${t.key} hover geometrisi temalar arası aynı`).toBe(d.hover.slide);
      expect(l.hover.slideTranslate, `${t.key} kayma miktarı temalar arası aynı`)
        .toBe(d.hover.slideTranslate);
      // Hover tepkisi: renk ya da konum değişmeli
      const reacted = l.hover.color !== l.passive.color || l.hover.slide !== l.passive.slide;
      expect(reacted, `${t.key} hover'da tepki veriyor`).toBe(true);
    }

    const acc = light.data[ACC_HEAD];
    expect(acc.hover.color, 'akordeon başlığı hover’da renk değiştirir')
      .not.toBe(acc.passive.color);

    for (const s of SLIDES) {
      const l = light.data[s.sel];
      const d = dark.data[s.sel];
      expect(l.hover.slideTranslate, `${s.sel} aydınlıkta kayıyor (${s.why})`)
        .toBeGreaterThan(0);
      expect(d.hover.slideTranslate, `${s.sel} karanlıkta kayıyor (${s.why})`)
        .toBeGreaterThan(0);
      expect(s.kind.length).toBeGreaterThan(1);
    }

    // Zemin katmanı iki temada farklı tondur (adaptif olduğunun kanıtı)
    expect(light.data[SUBLINK].hover.bg, 'alt link hover zemini temaya göre değişir')
      .not.toBe(dark.data[SUBLINK].hover.bg);
  });

  test('dil/para popover’ı panel içeriğinin altında kalmaz ve tıklanabilir', async ({ browser }) => {
    const { ctx, page } = await newCtx(browser, 'light');
    await openDrawer(page);

    await page.evaluate(() => document.querySelector('.mobile-menu .mm-pill').click());
    await page.waitForTimeout(400);

    const geom = await page.evaluate(() => {
      const pop = document.querySelector('.mobile-menu .mm-pop');
      const r = pop.getBoundingClientRect();
      const panel = document.querySelector('.mobile-menu__panel').getBoundingClientRect();
      const hit = document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2);
      return {
        insidePanel: r.top >= panel.top && r.bottom <= panel.bottom,
        hitBelongsToPopover: !!(hit && hit.closest('.mm-pop')),
        hitClass: hit ? hit.className : null,
      };
    });
    expect(geom.insidePanel).toBe(true);
    expect(geom.hitBelongsToPopover, `merkezde ${geom.hitClass} var`).toBe(true);

    // Gerçek tıklama: seçilen seçenek `data-val` ile takip edilir —
    // `[aria-checked="false"]` locator'ı tıklamadan sonra BAŞKA bir seçeneğe
    // çözülür ve yanlış negatif verir.
    const target = page.locator('.mobile-menu .mm-pop__opt[data-kind="lang"][aria-checked="false"]').first();
    const val = await target.getAttribute('data-val');
    await target.click();
    await page.waitForTimeout(300);
    await expect(
      page.locator(`.mobile-menu .mm-pop__opt[data-kind="lang"][data-val="${val}"]`),
    ).toHaveAttribute('aria-checked', 'true');

    // İlk seçeneği geri yükle (test hermetik kalsın)
    const restore = page.locator('.mobile-menu .mm-pop__opt[data-kind="lang"][aria-checked="false"]').first();
    const back = await restore.getAttribute('data-val');
    await restore.click();
    await page.waitForTimeout(250);
    await expect(
      page.locator(`.mobile-menu .mm-pop__opt[data-kind="lang"][data-val="${back}"]`),
    ).toHaveAttribute('aria-checked', 'true');

    await ctx.close();
  });
});
