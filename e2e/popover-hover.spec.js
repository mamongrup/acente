// Masaüstü header popover'larındaki hover mikro etkileşimi — gerçek tarayıcı testleri.
//
// NEDEN: mobil menüde satır seçenekleri `:hover`'da zemini soldurup hafifçe
// kayar, link ikonları primary renge dönüp 3px kayar (custom.css `.mm-*`).
// Masaüstü popover'ları aynı dili konuşmalı (chisfis-bridge.css `.nc-pop__*`).
//
// Ölçüm `page.hover` + computed style + `transitionrun` olayları üzerinden
// yapılır. Renkler sabit hex yerine **tema token'larına göre** doğrulanır
// (`--color-primary-600` → gerçek rgb), böylece palet değişince test
// anlamını korur. Kaymalar `@media (hover: hover)` ve `prefers-reduced-motion`
// altında değişir; ikisi de ayrı test edilir.
const { test, expect } = require('@playwright/test');

const PANEL_DISCOVER = '#popover-panel-2'; // Keşfet (kategori link listesi)
// Misafir satırları artık header popover'ında DEĞİL: sayaç arama bölümüne
// taşındı (hero formu + detay rezervasyon paneli). Bu yüzden misafir paneli
// ölçüm hedeflerinden ve satır testlerinden çıkarıldı.
const PANEL_TRAVEL = '#popover-panel-1'; // Travel (statik link listesi)
const PANEL_LOCALE = '#popover-panel-3'; // Dil/Para (seçenekler)
// İkonlu ilk link: yeni makette kategori kolonu ikon taşır, diğer kolonlar
// düz metindir (ikon mikro etkileşimi ölçülürken ikonsuz düğüm seçilmemeli).
const LINK = PANEL_DISCOVER + ' .nc-pop__link:has(i)';
// Seçili seçenek () zemini zaten vurgulu; hover ölçümü
// SEÇİLİ OLMAYAN bir seçenekte yapılır (aksi hâlde "zemin değişti mi?"
// ölçümü baştan vurgulu düğümü ölçer ve yanlış kırmızı verir).
// Seçili seçenek (`aria-checked="true"`) zemini zaten vurgulu; hover ölçümü
// SEÇİLİ OLMAYAN bir seçenekte yapılır — aksi hâlde "zemin değişti mi?"
// ölçümü baştan vurgulu düğümü ölçer ve yanlış kırmızı verir.
const OPT = PANEL_LOCALE + ' .mm-pop__opt[aria-checked="false"]';

// Tema zorlama: mağaza paleti tercih/saate göre çözülür. Test, sınıfı elle
// ayarlayarak deterministik olur (60 sn'lik auto tazeleme test süresince
// tetiklenmez).
async function forceTheme(page, mode) {
  await page.evaluate((m) => {
    const html = document.documentElement;
    html.classList.toggle('dark', m === 'dark');
    html.classList.toggle('sahra', false);
  }, mode);
}

// Bir CSS değişkenini tarayıcının kendi çözümlemesiyle rgb'ye çevirir.
async function varToRgb(page, varName) {
  return page.evaluate((name) => {
    const probe = document.createElement('span');
    probe.style.color = 'var(' + name + ')';
    document.body.appendChild(probe);
    const rgb = getComputedStyle(probe).color;
    probe.remove();
    return rgb;
  }, varName);
}

// ---------------------------------------------------------------------------
// Koyu tema parite ölçümü: WCAG kontrastı + hover geometrisi
// ---------------------------------------------------------------------------
// Renkler CANVAS ile normalize edilir: modern Chromium `color-mix(in oklab, …)`
// sonuçlarını `oklab(…)` olarak serileştirir, yani `rgba(` regex'i null döner.
const CONTRAST = `
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
function measure(el) {
  const cs = getComputedStyle(el);
  const bg = effBg(el);
  const fg = rgba(cs.color);
  const ico = el.querySelector('i, svg');
  const icoBg = ico ? effBg(ico.parentElement) : null;
  const icoFg = ico ? rgba(getComputedStyle(ico).color) : null;
  return {
    color: cs.color,
    bg: 'rgb(' + bg.join(', ') + ')',
    contrast: contrast([fg.r, fg.g, fg.b], bg),
    transform: cs.transform,
    icoColor: icoFg ? 'rgb(' + [icoFg.r, icoFg.g, icoFg.b].join(', ') + ')' : null,
    icoContrast: icoFg && icoBg ? contrast([icoFg.r, icoFg.g, icoFg.b], icoBg) : null,
  };
}
`;

// Panel başına ölçülecek seçenek sınıfları (hepsi gerçekten üretiliyor)
const PANEL_TARGETS = [
  { panel: PANEL_TRAVEL, name: 'Travel', sels: ['.nc-pop__head', '.nc-travel__item', '.nc-pop__link'] },
  { panel: PANEL_DISCOVER, name: 'Keşfet', sels: ['.nc-pop__head', '.nc-pop__link'] },
  { panel: PANEL_LOCALE, name: 'Dil/Para', sels: ['.mm-pop__opt', '.mm-pop__tab'] },
];

/**
 * Panelin SON linkini aktif duruma zorlar (ana sayfada hiçbiri aktif değil).
 *
 * Neden SON: `measureOptions` hem `.nc-pop__link` hem `[aria-current="page"]`
 * ölçer. İlk eleman zorlanınca iki satır AYNI düğümü ölçüyor ve normal linkin
 * hover'ı hiç kapsanmıyordu (mutasyon denemesinde ikon regresyonunu yalnız
 * ikinci test yakaladı). Ayrı düğümler seçilince tablo ikisini de kapsar.
 */
async function forceActive(page, panelSel) {
  return page.evaluate((sel) => {
    const links = document.querySelectorAll(sel + ' .nc-pop__link');
    if (links.length < 2) return false;
    const l = links[links.length - 1];
    l.classList.add('nc-pop__link--active');
    l.setAttribute('aria-current', 'page');
    return true;
  }, panelSel);
}

async function measureOptions(page, pref) {
  const rows = [];
  for (const p of PANEL_TARGETS) {
    await page.click('#' + p.panel.replace('#popover-panel-', 'popover-button-'));
    await page.waitForFunction((sel) => document.querySelector(sel)?.getAttribute('data-state') === 'open', p.panel);
    await page.waitForTimeout(500);
    const forced = await forceActive(page, p.panel);
    const sels = p.sels.concat(forced ? ['.nc-pop__link[aria-current="page"]'] : []);
    for (const sel of sels) {
      const loc = page.locator(p.panel + ' ' + sel).first();
      if ((await loc.count()) === 0) continue;
      const fn = new Function('el', `${CONTRAST}; return measure(el);`);
      const passive = await loc.evaluate(fn);
      await loc.hover();
      await page.waitForTimeout(280);
      const hover = await loc.evaluate(fn);
      await page.mouse.move(5, 500);
      await page.waitForTimeout(60);
      rows.push({ pref, panel: p.name, sel, passive, hover });
    }
    await page.click('#' + p.panel.replace('#popover-panel-', 'popover-button-'));
    await page.waitForTimeout(250);
  }
  return rows;
}

async function openPanel(page, buttonId, panelSel) {
  await page.click('#' + buttonId);
  await page.waitForFunction((sel) => document.querySelector(sel)?.getAttribute('data-state') === 'open', panelSel);
  // Kademeli giriş (nc-stagger-in) bitsin: satırların başlangıç durumu temiz
  // okunsun, aksi halde `transform` animasyonun ara değerini döndürür.
  // Not: `forwards` dolgulu animasyonlar bitince de `getAnimations()`'ta
  // kalır; bu yüzden "animasyon yok" değil "koşan animasyon yok" beklenir.
  await page.waitForFunction(
    (sel) => {
      const panel = document.querySelector(sel);
      if (!panel) return false;
      const busy = (el) => el.getAnimations().some((a) => a.playState === 'running');
      return !busy(panel) && Array.from(panel.querySelectorAll('*')).every((el) => !busy(el));
    },
    panelSel,
  );
}

async function hoverStyles(page, selector) {
  const read = () =>
    page.evaluate((sel) => {
      const el = document.querySelector(sel);
      const cs = getComputedStyle(el);
      const icon = el.querySelector('i, svg');
      return {
        background: cs.backgroundColor,
        transform: cs.transform,
        transition: cs.transitionProperty + '/' + cs.transitionDuration,
        icon: icon ? { color: getComputedStyle(icon).color, transform: getComputedStyle(icon).transform } : null,
      };
    }, selector);

  const before = await read();
  await page.hover(selector);
  await page.waitForTimeout(320);
  const after = await read();
  return { before, after };
}

test.describe('masaüstü popover hover mikro etkileşimi', () => {
  test.use({ viewport: { width: 1280, height: 900 } });

  test('Keşfet bağlantısı: ikon primary renge döner, zemini geçirir ve 3px kayar', async ({ page }) => {
    // Geçiş olaylarını sayfa yüklenirken dinlemeye başla (dekoratif CSS değil,
    // gerçekten oynayan bir geçiş olduğunu kanıtlar).
    await page.addInitScript(() => {
      window.__hoverRuns = [];
      document.addEventListener(
        'transitionrun',
        (e) => {
          const link = e.target.closest ? e.target.closest('.nc-pop__link') : null;
          if (link) window.__hoverRuns.push({ prop: e.propertyName });
        },
        true,
      );
    });
    await page.goto('/');
    await openPanel(page, 'popover-button-2', PANEL_DISCOVER);
    await forceTheme(page, 'light');

    const primary600 = await varToRgb(page, '--color-primary-600');
    const neutral50 = await varToRgb(page, '--color-neutral-50');

    const r = await hoverStyles(page, LINK);
    // Zemin geçişi (light: neutral-50)
    expect(r.before.background).not.toBe(r.after.background);
    expect(r.after.background).toBe(neutral50);
    expect(r.before.transition).toContain('background-color');
    expect(r.before.transition).toContain('0.15s');
    // İkon: 3px sağa kayma + primary-600
    expect(r.before.icon.transform).toBe('none');
    expect(r.after.icon.transform).toBe('matrix(1, 0, 0, 1, 3, 0)');
    expect(r.after.icon.color).toBe(primary600);
    expect(r.before.transition).toContain('color');

    // Geçişler gerçekten oynadı mı?
    const runs = await page.evaluate(() => window.__hoverRuns);
    expect(runs.some((e) => e.prop === 'transform')).toBe(true);
    expect(runs.some((e) => e.prop === 'color')).toBe(true);
  });

  test('koyu temada hover ikonu AA-güvenli token’a bağlanır (primary-300), zemin nötr 700', async ({ page }) => {
    await page.goto('/');
    await openPanel(page, 'popover-button-2', PANEL_DISCOVER);
    await forceTheme(page, 'dark');

    const neutral700 = await varToRgb(page, '--color-neutral-700');
    const primary300 = await varToRgb(page, '--color-primary-300');

    // Token KAPSAMDA tanımlı olmalı — eskiden `var(--mm-accent, #a5b4fc)`
    // yalnızca fallback ile çalışıyordu (değeri değiştirmek isteyen biri
    // fallback'ı güncellemeyi unutunca sessizce eski renk kalırdı).
    const scoped = await page.evaluate((sel) => {
      const v = getComputedStyle(document.querySelector(sel)).getPropertyValue('--nc-accent').trim();
      const probe = document.createElement('span');
      probe.style.color = v || 'invalid';
      document.body.appendChild(probe);
      const rgb = getComputedStyle(probe).color;
      probe.remove();
      return rgb;
    }, PANEL_DISCOVER);
    expect(scoped).toBe(primary300);

    const r = await hoverStyles(page, LINK);
    // Eski sözleşme primary-500'dü → hover zemininde **2.3:1** (AA altı)
    expect(r.after.icon.color).toBe(primary300);
    expect(r.after.icon.color).not.toBe(await varToRgb(page, '--color-primary-500'));
    expect(r.after.icon.transform).toBe('matrix(1, 0, 0, 1, 3, 0)');
    expect(r.after.background).toBe(neutral700);

    // Kontrast gerçekten eşiğin üstünde mi?
    const c = await page.evaluate((sel) => {
      const el = document.querySelector(sel);
      const ico = el.querySelector('i, svg');
      const cs = getComputedStyle(ico);
      const cv = document.createElement('canvas'); cv.width = cv.height = 1;
      const ctx = cv.getContext('2d');
      const toRgb = (str) => {
        ctx.clearRect(0, 0, 1, 1); ctx.fillStyle = '#000'; ctx.fillStyle = str;
        ctx.fillRect(0, 0, 1, 1);
        const d = ctx.getImageData(0, 0, 1, 1).data;
        return [d[0], d[1], d[2]];
      };
      const lum = (rgb) => {
        const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
        return 0.2126 * f(rgb[0]) + 0.7152 * f(rgb[1]) + 0.0722 * f(rgb[2]);
      };
      const a = lum(toRgb(cs.color)), b = lum(toRgb(getComputedStyle(el).backgroundColor));
      return Math.round(((Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)) * 100) / 100;
    }, LINK);
    expect(c, 'ikon hover kontrastı (non-text 3:1)').toBeGreaterThanOrEqual(3);
  });

  test('koyu ve aydınlık hover paritesi: tüm seçenekler AA, geometri bit bit aynı', async ({ page }) => {
    // İki tema AYNI sayfada ölçülür: `forceTheme` yalnız `html.dark` sınıfını
    // değiştirir ve tüm renkler o sınıfa kapsamlıdır, bu yüzden ikinci bir
    // bağlam + ikinci sayfa yüklemesi ölçüme bir şey katmaz. Ana sayfa 19
    // görsel taşıyor; her `goto` yavaş diskte ~10 sn sürüyor ve iki yükleme
    // tek başına 30 sn'lik test bütçesini yakıyordu (ölçüm tablosu tamamen
    // basıldıktan SONRA zaman aşımı oluyordu — yani başarısızlık değer
    // değil süre kaynaklıydı).
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.goto('/');
    await forceTheme(page, 'light');
    const light = await measureOptions(page, 'light');
    await forceTheme(page, 'dark');
    const dark = await measureOptions(page, 'dark');

    const rows = [];
    for (const r of light.concat(dark)) {
      expect(r.passive.contrast, `${r.pref} ${r.panel} ${r.sel} pasif kontrast`).toBeGreaterThanOrEqual(4.5);
      expect(r.hover.contrast, `${r.pref} ${r.panel} ${r.sel} hover kontrast`).toBeGreaterThanOrEqual(4.5);
      if (r.hover.icoContrast !== null) {
        expect(r.hover.icoContrast, `${r.pref} ${r.panel} ${r.sel} ikon kontrastı`).toBeGreaterThanOrEqual(3);
      }
      rows.push(`${r.pref}/${r.panel}${r.sel}: ${r.passive.contrast}→${r.hover.contrast}`);
    }
    console.log('[popover parite] ' + rows.join(' | '));

    // Geometri iki temada aynı olmalı (mikro etkileşim dili temaya bağlı değil)
    const key = (x) => `${x.panel}|${x.sel}`;
    const lightMap = new Map(light.map((x) => [key(x), x]));
    for (const d of dark) {
      const l = lightMap.get(key(d));
      if (!l) continue;
      expect(d.passive.transform, `${key(d)} pasif geometri temalar arası aynı`).toBe(l.passive.transform);
      expect(d.hover.transform, `${key(d)} hover geometri temalar arası aynı`).toBe(l.hover.transform);
    }
  });

  test('Travel paneli satırı: zemini geçirir', async ({ page }) => {
    // NOT: misafir satırları burada ölçülmez — sayaç arama bölümüne taşındı,
    // header popover'ında misafir satırı/stepper kalmadı (tek sahip ilkesi).
    await page.goto('/');
    await openPanel(page, 'popover-button-1', PANEL_TRAVEL);
    await forceTheme(page, 'light');

    const ITEM = PANEL_TRAVEL + ' .nc-travel__item';
    const read = () =>
      page.evaluate((sel) => {
        const el = document.querySelector(sel);
        return {
          bg: getComputedStyle(el).backgroundColor,
          transition: getComputedStyle(el).transitionProperty,
        };
      }, ITEM);

    const before = await read();
    await page.hover(ITEM);
    await page.waitForTimeout(320);
    const after = await read();

    expect(before.transition).toContain('background-color');
    expect(after.bg).not.toBe(before.bg);
  });

  test('Dil/Para seçeneği mobil menüyle aynı kaymayı korur (2px)', async ({ page }) => {
    await page.goto('/');
    await openPanel(page, 'popover-button-3', PANEL_LOCALE);
    const r = await hoverStyles(page, OPT);
    expect(r.after.transform).toBe('matrix(1, 0, 0, 1, 2, 0)');
    expect(r.before.background).not.toBe(r.after.background);
  });

  test('prefers-reduced-motion: reduce → kayma yok, renk/zemin geri bildirimi kalır', async ({ browser }) => {
    const context = await browser.newContext({ reducedMotion: 'reduce', viewport: { width: 1280, height: 900 } });
    const page = await context.newPage();
    await page.goto('/');
    await openPanel(page, 'popover-button-2', PANEL_DISCOVER);
    const r = await hoverStyles(page, LINK);
    expect(r.after.icon.transform).toBe('none');
    expect(r.after.transform).toBe('none');
    expect(r.after.background).not.toBe(r.before.background);
    await context.close();
  });
});
