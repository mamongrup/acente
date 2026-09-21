// Kalan dropdown yüzeyleri — kontrast + geometri parite paketi.
//
// KAPSAM: `popover-hover.spec.js` header popover'larını (misafirler, keşfet,
// dil/para) ölçüyordu; dışarıda kalan dört yüzey burada:
//   1) İlan detayı **tarih paneli** (`.chisfis-date-panel` + datepicker),
//   2) İlan detayı **misafir paneli** (`.chisfis-guest-panel` + stepper),
//   3) Liste/kategori **filtre menüsü** (`.product-search`, kategori pilleri,
//      sıralama, mobil katlanır toggle),
//   4) Header **hesap menüsü** ve **bildirim paneli** (`#popover-panel-5/-4`).
//
// SÖZLEŞMELER (her yüzey, HER İKİ temada):
//   * metin ≥ 4.5 (büyük metin ≥ 3.0), ikon ≥ 3.0 — WCAG AA.
//   * etkileşimli hedef hover'da GERÇEKTEN tepki verir (renk veya geometri
//     değişir). Bu, koyu temada `html.dark .x` specificity'sinin çıplak
//     `.x:hover` kuralını yediği hataları yakalar: hazır aralık çipleri koyu
//     temada 9.96 → 9.96 ile hiç tepki vermiyordu.
//   * hover geometrisi iki temada bit bit aynı.
//   * HAREKETSİZ (disabled) hedefler muaf: WCAG 1.4.3 etkin olmayan arayüz
//     bileşenlerini kapsam dışı bırakır. Muafiyet gizli değil, aşağıdaki
//     `EXEMPT` listesinde gerekçesiyle durur.
//
// Ölçüm `getComputedStyle` + 1×1 canvas normalizasyonuyla yapılır: modern
// Chromium `color-mix(in oklab, …)` sonuçlarını `oklab(…)` olarak serileştirir,
// `rgba(` regex'i bu renklerde sessizce null döner.
const { test, expect } = require('@playwright/test');

const LIST = '/urunler';
const DETAIL = '/urunler/6381a4d4-af56-4263-b2d1-b274da897487';

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
function measure(el) {
  const cs = getComputedStyle(el);
  const bg = effBg(el);
  const fg = rgba(cs.color) || { r: 0, g: 0, b: 0 };
  return {
    contrast: contrast([fg.r, fg.g, fg.b], bg),
    bg: 'rgb(' + bg.join(', ') + ')',
    color: cs.color,
    transform: cs.transform,
    /* Hover tepkisi yalnız renk/geometri değildir: bazı yüzeyler kenarlık
       rengi ve halka gölgesiyle tepki verir (tarih tetikleyicisi gibi).
       Bunlar ölçülmezse "hover tepkisi yok" YANLIŞ kırmızı üretir. */
    borderColor: cs.borderTopColor,
    boxShadow: cs.boxShadow,
    fontSize: parseFloat(cs.fontSize),
    fontWeight: parseInt(cs.fontWeight, 10) || 400,
  };
}
`;

const MEASURE_FN = new Function('el', `${HELPERS}; return measure(el);`);

// WCAG eşikleri: 18.66px+ kalın veya 24px+ metin "büyük metin" sayılır.
const TEXT_MIN = 4.5;
const LARGE_TEXT_MIN = 3.0;
const ICON_MIN = 3.0;

function minContrast(kind, m) {
  if (kind === 'icon') return ICON_MIN;
  const large = m.fontSize >= 24 || (m.fontWeight >= 700 && m.fontSize >= 18.66);
  return large ? LARGE_TEXT_MIN : TEXT_MIN;
}

// Hareketsiz hedefler — WCAG 1.4.3 istisnası. Gerekçesi burada açıkça durur.
const EXEMPT = [
  {
    sel: 'button.datepicker__day--disabled',
    why: 'etkin olmayan gün (disabled) — WCAG 1.4.3 kapsam dışı; üstü çizili + not-allowed ile işaretli',
  },
];

/* Muafiyet eşleşmesi: muafiyet girdileri tek bir compound seçicidir
 * (`button.datepicker__day--disabled`). Hedef seçiciler ise kapsayıcı
 * öneki taşıyabilir (`.chisfis-date-panel button.datepicker__day--disabled`);
 * tam eşitlik aradığımda muafiyet sessizce tutmuyordu ve etkin olmayan gün
 * "AA ihlali" olarak raporlanıyordu. Karşılaştırma hedefin SON compound'u
 * üzerinden yapılır. */
function isExempt(sel) {
  const last = sel.split(/[\s>]+/).pop();
  return EXEMPT.some((e) => e.sel === sel || e.sel === last);
}

async function forceTheme(page, mode) {
  await page.evaluate((m) => {
    const html = document.documentElement;
    html.classList.toggle('dark', m === 'dark');
    html.classList.toggle('sahra', false);
  }, mode);
}

/* Panel açıcıları — İKİ tuzak var, ikisi de burada kapatılır:
 *   1) Tetikleyiciler AÇ/KAPA'dır: kör bir `click` açık paneli KAPATIR. Bu
 *      yüzden önce durum okunur, yalnız kapalıysa tıklanır.
 *   2) Panel açıkken başka bir alanın üzerine binebilir (tarih paneli misafir
 *      alanını örter), o zaman Playwright'ın eyleme geçebilirliği bekleyen
 *      `page.click` zaman aşımına düşer. Doğrudan DOM tıklaması kullanılır —
 *      mobil menü testlerinde de aynı desen var.
 * Zorla `data-open` yazmak da denenmedi değil: sayfanın kendi kapanış
 * mantığıyla yarışıp hover ölçümünü zaman aşımına düşürüyor.
 */
function domClick(sel) {
  return (page) =>
    page.evaluate((s) => {
      const el = document.querySelector(s);
      if (el) el.click();
    }, sel);
}

async function openIfClosed(page, triggerSel, isOpenExpr, waitExpr) {
  const open = await page.evaluate(new Function('return ' + isOpenExpr));
  if (!open) await domClick(triggerSel)(page);
  await page.waitForFunction(new Function('return ' + waitExpr), null, { timeout: 4000 });
}

const OPENERS = {
  date: (page) =>
    openIfClosed(
      page,
      '.chisfis-date-trigger',
      "!!document.querySelector('.chisfis-date-panel')?.hasAttribute('data-open')",
      "!!document.querySelector('.chisfis-date-panel')?.hasAttribute('data-open')",
    ),
  guest: (page) =>
    openIfClosed(
      page,
      '.chisfis-guest-trigger',
      "!!document.querySelector('.chisfis-guest-panel')?.hasAttribute('data-open')",
      "!!document.querySelector('.chisfis-guest-panel')?.hasAttribute('data-open')",
    ),
  travelers: (page) =>
    openIfClosed(
      page,
      '#popover-button-1',
      "document.querySelector('#popover-panel-1')?.getAttribute('data-state') === 'open'",
      "document.querySelector('#popover-panel-1')?.getAttribute('data-state') === 'open'",
    ),
  explore: (page) =>
    openIfClosed(
      page,
      '#popover-button-2',
      "document.querySelector('#popover-panel-2')?.getAttribute('data-state') === 'open'",
      "document.querySelector('#popover-panel-2')?.getAttribute('data-state') === 'open'",
    ),
  globe: (page) =>
    openIfClosed(
      page,
      '#popover-button-3',
      "document.querySelector('#popover-panel-3')?.getAttribute('data-state') === 'open'",
      "document.querySelector('#popover-panel-3')?.getAttribute('data-state') === 'open'",
    ),
  account: (page) =>
    openIfClosed(
      page,
      '#popover-button-5',
      "document.querySelector('#popover-panel-5')?.getAttribute('data-state') === 'open'",
      "document.querySelector('#popover-panel-5')?.getAttribute('data-state') === 'open'",
    ),
  notifications: (page) =>
    openIfClosed(
      page,
      '#popover-button-4',
      "document.querySelector('#popover-panel-4')?.getAttribute('data-state') === 'open'",
      "document.querySelector('#popover-panel-4')?.getAttribute('data-state') === 'open'",
    ),
  // Masaüstünde filtre gövdesi görünür; mobilde katlanır toggle açılır.
  filterDesktop: async () => {},
  filterMobile: (page) =>
    openIfClosed(
      page,
      '.listing-filter-toggle',
      "!!document.querySelector('.listing-filter-body')?.classList.contains('is-open')",
      "!!document.querySelector('.listing-filter-body')?.classList.contains('is-open')",
    ),
};

const DATE_TARGETS = [
  { sel: '.chisfis-date-panel .datepicker__nav', kind: 'icon', hover: true, open: 'date' },
  { sel: '.chisfis-date-panel .datepicker__month-select', kind: 'text', open: 'date' },
  { sel: '.chisfis-date-panel .datepicker__year-select', kind: 'text', open: 'date' },
  { sel: '.chisfis-date-panel .datepicker__preset-btn', kind: 'text', hover: true, open: 'date', name: 'hazır aralık çipi' },
  { sel: '.chisfis-date-panel .datepicker__day-name', kind: 'text', open: 'date', name: 'gün adı' },
  {
    sel: '.chisfis-date-panel button.datepicker__day:not(.datepicker__day--disabled):not(.datepicker__day--outside-month)',
    kind: 'text',
    hover: true,
    open: 'date',
    name: 'gün hücresi',
  },
  { sel: '.chisfis-date-panel button.datepicker__day--disabled', kind: 'text', open: 'date', name: 'kapalı gün' },
  { sel: '.chisfis-date-panel button.datepicker__day--selected', kind: 'text', open: 'date', name: 'seçili gün', injectSelected: true },
  { sel: '.chisfis-date-panel button.datepicker__day--in-range', kind: 'text', open: 'date', name: 'aralık günü', injectSelected: true },
  { sel: '.chisfis-date-trigger', kind: 'text', hover: true, name: 'tarih tetikleyicisi' },
];

const GUEST_TARGETS = [
  { sel: '.chisfis-guest-panel .guest-stepper-label', kind: 'text', open: 'guest' },
  { sel: '.chisfis-guest-panel .guest-stepper-sub', kind: 'text', open: 'guest' },
  { sel: '.chisfis-guest-panel .guest-stepper-value', kind: 'text', open: 'guest' },
  { sel: '.chisfis-guest-panel .guest-stepper-btn', kind: 'icon', hover: true, open: 'guest', name: 'stepper düğmesi' },
  { sel: '.chisfis-guest-trigger', kind: 'text', hover: true, name: 'misafir tetikleyicisi' },
];

const FILTER_TARGETS = [
  { sel: '.product-search select', kind: 'text' },
  { sel: '.product-search button[type="submit"]', kind: 'text', hover: true, name: 'arama gönder' },
  { sel: '.product-category-pills a:not(.active)', kind: 'text', hover: true, name: 'kategori pili' },
  { sel: '.product-category-pills a.active', kind: 'text', name: 'aktif kategori pili' },
  { sel: '.products-sort', kind: 'text', name: 'sıralama' },
  { sel: '.products-toolbar > span', kind: 'text', name: 'sonuç sayısı' },
];

const MOBILE_FILTER_TARGETS = [
  { sel: '.listing-filter-toggle', kind: 'text', hover: true, open: 'filterMobile', name: 'filtre açıcı' },
  { sel: '.listing-filter-toggle-chevron', kind: 'icon', open: 'filterMobile', name: 'filtre oku' },
  ...FILTER_TARGETS.map((t) => ({ ...t, open: 'filterMobile' })),
];

/* Header popover'larının TAMAMI: hesap (5) ve bildirim (4) dışında
 * Seyahat Edenler (1, misafir sayaçları), Şablonlar (2, keşfet listesi) ve
 * dil/para (3, sekmeli ızgara) panelleri de aynı paketten geçer — dördü de
 * kullanıcının gördüğü açılır yüzeylerdir ve koyu temada ayrı ayrı
 * kayabiliyorlardı. */
const HEADER_TARGETS = [
  { sel: '#popover-panel-5 .nc-pop__link', kind: 'text', hover: true, open: 'account', name: 'hesap linki' },
  { sel: '#popover-panel-4 .nc-pop__head', kind: 'text', open: 'notifications', name: 'bildirim başlığı' },
  { sel: '#popover-panel-4 .nc-pop__empty p', kind: 'text', open: 'notifications', name: 'boş durum metni' },
  { sel: '#popover-panel-4 .nc-pop__empty i', kind: 'icon', open: 'notifications', name: 'boş durum ikonu' },
  // 1 — Seyahat Edenler (misafir sayaçları)
  { sel: '#popover-panel-1 .nc-pop__head', kind: 'text', open: 'travelers', name: 'misafir panel başlığı' },
  { sel: '#popover-panel-1 .nc-pop__row-label', kind: 'text', open: 'travelers', name: 'misafir satır etiketi' },
  { sel: '#popover-panel-1 .nc-pop__row-sub', kind: 'text', open: 'travelers', name: 'misafir satır alt yazısı' },
  { sel: '#popover-panel-1 .nc-stepper__val', kind: 'text', open: 'travelers', name: 'sayaç değeri' },
  { sel: '#popover-panel-1 .nc-stepper__btn', kind: 'icon', hover: true, open: 'travelers', name: 'sayaç düğmesi' },
  // 2 — Şablonlar (Keşfet listesi)
  { sel: '#popover-panel-2 .nc-pop__head', kind: 'text', open: 'explore', name: 'keşfet başlığı' },
  { sel: '#popover-panel-2 .nc-pop__link', kind: 'text', hover: true, open: 'explore', name: 'keşfet bağlantısı' },
  { sel: '#popover-panel-2 .nc-pop__link .hgi-stroke', kind: 'icon', open: 'explore', name: 'keşfet ikonu' },
  // 3 — Dil / para (sekmeli ızgara)
  { sel: '#popover-panel-3 .mm-pop__tab[data-selected]', kind: 'text', open: 'globe', name: 'seçili dil/para sekmesi' },
  { sel: '#popover-panel-3 .mm-pop__tab:not([data-selected])', kind: 'text', hover: true, open: 'globe', name: 'dil/para sekmesi' },
  { sel: '#popover-panel-3 .mm-pop__opt', kind: 'text', hover: true, open: 'globe', name: 'dil/para seçeneği' },
  { sel: '#popover-panel-3 .mm-pop__opt-main', kind: 'text', open: 'globe', name: 'seçenek ana metni' },
  { sel: '#popover-panel-3 .mm-pop__opt-sub', kind: 'text', open: 'globe', name: 'seçenek alt metni' },
  { sel: '#popover-panel-3 .mm-pop__tick', kind: 'icon', open: 'globe', name: 'seçim tiki' },
];

/* Panel yüzeyleri birbirini DIŞLAMAZ: tarih paneli (geniş, tetikleyicinin
 * altına taşarak açılır) açıkken misafir panelinin düğmeleri onun altında
 * kalır ve Playwright hover'ı "intercepts pointer events" ile zaman aşımına
 * düşer. Aynı kaynaklı ikinci tuzak: başka panel açıkken ölçülen panel
 * olmayan hedefler (misafir tetikleyicisi gibi) da örtülebilir. Bu yüzden
 * her ölçümden önce hedefin kendi paneli hariç tüm açık paneller kapatılır.
 */
const PANEL_STATE = {
  date: [
    '.chisfis-date-trigger',
    "!!document.querySelector('.chisfis-date-panel')?.hasAttribute('data-open')",
  ],
  guest: [
    '.chisfis-guest-trigger',
    "!!document.querySelector('.chisfis-guest-panel')?.hasAttribute('data-open')",
  ],
};

async function closeOtherPanels(page, keep) {
  for (const key of Object.keys(PANEL_STATE)) {
    if (key === keep) continue;
    const [triggerSel, isOpenExpr] = PANEL_STATE[key];
    const open = await page.evaluate(new Function('return ' + isOpenExpr));
    if (open) await domClick(triggerSel)(page);
  }
}

async function openFor(page, key, surface) {
  if (!key) return;
  const opener = OPENERS[key];
  if (opener) await opener(page, surface);
}

// Bir hedefi ölçer: pasif + (istenmişse) hover. Panel açıcı her ölçümden önce
// yeniden çalışır — sayfa kendi etkileşimiyle paneli kapatabildiği için
// hedeflerin görünür kalması garanti edilmelidir.
async function measureTarget(page, surface, target, mode) {
  /* `open` anahtarı OLMAYAN hedefler de temizlenir: aksi hâlde önceki
   * hedeften açık kalan panel, tetikleyiciyi `[aria-expanded="true"]`
   * durumunda bırakır ve pasif taban zaten "aktif" stili taşıdığı için
   * hover ölçümü hiçbir fark göstermez (yanlış kırmızı). */
  await closeOtherPanels(page, target.open);
  if (target.open) await openFor(page, target.open, surface);
  if (target.injectSelected) {
    await page.evaluate(() => {
      const days = document.querySelectorAll(
        '.chisfis-date-panel button.datepicker__day:not(.datepicker__day--disabled):not(.datepicker__day--outside-month)',
      );
      if (days.length > 8) {
        days[5].classList.add('datepicker__day--in-range');
        days[6].classList.add('datepicker__day--selected');
      }
    });
  }
  await page.waitForTimeout(80);
  if (target.hover) {
    /* Temiz pasif taban: fare önceki hedefin üzerinde kalmış olabilir ve
     * ölçülen eleman `:hover` durumunda okunur — o zaman hover ölçümü aynı
     * değeri verir ve test "tepki yok" diye YANLIŞ kırmızı üretir. */
    await page.mouse.move(2, 2);
    await page.waitForTimeout(120);
  }
  const loc = page.locator(target.sel).first();
  if ((await loc.count()) === 0) return { ...target, mode, missing: true };
  const passive = await loc.evaluate(MEASURE_FN);
  let hover = null;
  if (target.hover) {
    await loc.hover({ timeout: 4000 });
    await page.waitForTimeout(220);
    hover = await loc.evaluate(MEASURE_FN);
  }
  return { ...target, mode, passive, hover };
}

function assertTarget(row) {
  const label = `${row.name || row.sel} [${row.mode}]`;
  expect(row.missing, `${row.sel} bulunamadı`).not.toBe(true);
  const min = minContrast(row.kind, row.passive);
  if (isExempt(row.sel)) return;
  expect(row.passive.contrast, `${label} pasif kontrast`).toBeGreaterThanOrEqual(min);
  if (row.hover) {
    // Hover GERÇEKTEN tepki vermeli: renk ya da geometri değişmeli.
    const reacted =
      row.hover.contrast !== row.passive.contrast ||
      row.hover.transform !== row.passive.transform ||
      row.hover.borderColor !== row.passive.borderColor ||
      row.hover.boxShadow !== row.passive.boxShadow;
    const diff =
      `pasif ${JSON.stringify({ c: row.passive.contrast, t: row.passive.transform, b: row.passive.borderColor, s: row.passive.boxShadow })}` +
      ` / hover ${JSON.stringify({ c: row.hover.contrast, t: row.hover.transform, b: row.hover.borderColor, s: row.hover.boxShadow })}`;
    expect(reacted, `${label} hover tepkisi yok — ${diff}`).toBe(true);
    expect(row.hover.contrast, `${label} hover kontrast`).toBeGreaterThanOrEqual(min);
  }
}

function logRow(surface, row) {
  if (row.missing) {
    console.log(`[dropdown parite] ${surface} MISSING ${row.sel}`);
    return;
  }
  const h = row.hover ? ` → ${row.hover.contrast}` : '';
  const geo = row.hover && row.hover.transform !== row.passive.transform ? ` geo→${row.hover.transform}` : '';
  console.log(
    `[dropdown parite] ${surface}/${row.mode} ${row.kind} ${row.sel}: ${row.passive.contrast}${h}${geo}`,
  );
}

test.describe('dropdown yüzeyleri: kontrast + geometri paritesi', () => {
  test.use({ viewport: { width: 1280, height: 900 } });

  test('detay: tarih ve misafir panelleri iki temada da AA', async ({ page }) => {
    await page.goto(DETAIL);
    await page.waitForTimeout(700);
    const rows = [];
    for (const mode of ['light', 'dark']) {
      await forceTheme(page, mode);
      await page.waitForTimeout(150);
      for (const target of [...DATE_TARGETS, ...GUEST_TARGETS]) {
        const row = await measureTarget(page, 'detay', target, mode);
        logRow('detay', row);
        rows.push(row);
      }
    }
    rows.forEach(assertTarget);

    // Geometri paritesi: aynı hedefin hover transform'u iki temada aynı olmalı
    for (const target of [...DATE_TARGETS, ...GUEST_TARGETS].filter((t) => t.hover)) {
      const light = rows.find((r) => r.sel === target.sel && r.mode === 'light');
      const dark = rows.find((r) => r.sel === target.sel && r.mode === 'dark');
      if (light?.hover && dark?.hover) {
        expect(dark.hover.transform, `${target.sel} hover geometrisi temalar arasında farklı`).toBe(
          light.hover.transform,
        );
      }
    }
  });

  test('liste: filtre menüsü iki temada da AA', async ({ page }) => {
    await page.goto(LIST);
    await page.waitForTimeout(700);
    const rows = [];
    for (const mode of ['light', 'dark']) {
      await forceTheme(page, mode);
      await page.waitForTimeout(150);
      for (const target of FILTER_TARGETS) {
        const row = await measureTarget(page, 'filtre', target, mode);
        logRow('filtre', row);
        rows.push(row);
      }
    }
    rows.forEach(assertTarget);
  });

  test('header: hesap menüsü ve bildirim paneli iki temada da AA', async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(700);
    const rows = [];
    for (const mode of ['light', 'dark']) {
      await forceTheme(page, mode);
      await page.waitForTimeout(150);
      for (const target of HEADER_TARGETS) {
        const row = await measureTarget(page, 'header', target, mode);
        logRow('header', row);
        rows.push(row);
      }
    }
    rows.forEach(assertTarget);
  });
});

test.describe('dropdown yüzeyleri: mobil filtre menüsü', () => {
  test.use({ viewport: { width: 390, height: 780 } });

  test('katlanır filtre açıcısı ve gövdesi iki temada da AA', async ({ page }) => {
    await page.goto(LIST);
    await page.waitForTimeout(700);
    const rows = [];
    for (const mode of ['light', 'dark']) {
      await forceTheme(page, mode);
      await page.waitForTimeout(150);
      for (const target of MOBILE_FILTER_TARGETS) {
        const row = await measureTarget(page, 'filtre-mobil', target, mode);
        logRow('filtre-mobil', row);
        rows.push(row);
      }
    }
    rows.forEach(assertTarget);
  });
});
