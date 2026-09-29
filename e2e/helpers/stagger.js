// Kademeli (stagger) giriş animasyonu ölçüm/doğrulama yardımcıları.
//
// TASARIM NOTU — önizleme webview'i CSS animasyonlarını hiç oynatmaz
// (`getAnimations()` boş döner). Bu yüzden ölçüm:
//   1) Animation API (`element.getAnimations()` + `effect.getComputedTiming()`)
//   2) computed style (animation-name/delay/duration/fill) üzerinden yapılır.
// Piksel/ekran görüntüsü karşılaştırması yoktur; bu, testi ortam kısıtlarına
// karşı dayanıklı kılar ama **yanlış pozitif üretmez**: animasyon gerçekten
// oynamıyorsa `playState`/`getAnimations()` doğrulaması kırmızıya düşer.
const { expect } = require('@playwright/test');

/**
 * Paneli açar, iki kare bekler ve çocukların animasyon durumunu ölçer.
 *
 * @param {import('@playwright/test').Page} page
 * @param {{ panelSelector: string, childSelector?: string, open: { type: 'id'|'selector', value: string } }} opts
 */
async function measureStagger(page, { panelSelector, stateSelector, childSelector = '*', open }) {
  return page.evaluate(
    async ({ panelSelector, stateSelector, childSelector, open }) => {
      const waitFrames = (n) =>
        new Promise((resolve) => {
          const step = () => (--n <= 0 ? resolve() : requestAnimationFrame(step));
          requestAnimationFrame(step);
        });

      const opener =
        open.type === 'id' ? document.getElementById(open.value) : document.querySelector(open.value);
      if (!opener) return { error: 'açma öğesi bulunamadı: ' + open.value };
      opener.click();
      await waitFrames(2);

      const panel = document.querySelector(panelSelector);
      if (!panel) return { error: 'panel bulunamadı: ' + panelSelector };
      // Açık/kapalı durumu her zaman panelde tutulmaz (çekmecede kök
      // `.mobile-menu` elemanındadır) — ayrı seçici verilebilir.
      const stateEl = stateSelector ? document.querySelector(stateSelector) : panel;
      if (!stateEl) return { error: 'durum öğesi bulunamadı: ' + stateSelector };

      const kids = Array.from(panel.querySelectorAll(':scope > ' + childSelector));
      return {
        state: stateEl.getAttribute('data-state'),
        hidden: panel.hidden,
        kids: kids.map((el, index) => {
          const cs = getComputedStyle(el);
          const anims = el.getAnimations();
          return {
            index,
            // Tarayıcı `display: none` elemanda animasyon çalıştırmaz; gizli
            // paneller (örn. locale popover'ının kapalı sekmesi) ölçüm dışıdır.
            rendered: el.getClientRects().length > 0,
            animationName: cs.animationName,
            animationDelayCss: parseFloat(cs.animationDelay) * 1000,
            animationDurationCss: parseFloat(cs.animationDuration) * 1000,
            animationFillMode: cs.animationFillMode,
            opacity: parseFloat(cs.opacity),
            animations: anims.length,
            playStates: anims.map((a) => a.playState),
            timings: anims.map((a) => {
              const t = a.effect && a.effect.getComputedTiming ? a.effect.getComputedTiming() : {};
              return { delay: t.delay, duration: t.duration, fill: t.fill };
            }),
          };
        }),
      };
    },
    { panelSelector, stateSelector, childSelector, open },
  );
}

/**
 * Kademeli animasyon sözleşmesini doğrular.
 * @returns {{delayMs:number[], durationMs:number}[]} ölçülen zamanlamalar
 */
function expectStaggered(measured, { animationName, durationMs, label, minChildren = 2 }) {
  expect(measured.error, `${label}: ölçüm hatası — ${measured.error}`).toBeUndefined();
  expect(measured.state, `${label}: panel açık (data-state=open) olmalı`).toBe('open');

  // Yalnızca render edilen çocuklar animasyon üretebilir; gizli paneller
  // (display: none) atlanır ve sayıları rapora yazılır.
  const rendered = measured.kids.filter((k) => k.rendered);
  const skipped = measured.kids.length - rendered.length;
  expect(
    rendered.length,
    `${label}: animasyon ölçülecek en az ${minChildren} görünür çocuk bekleniyordu ` +
      `(toplam ${measured.kids.length}, gizli ${skipped})`,
  ).toBeGreaterThanOrEqual(minChildren);

  const timings = [];
  for (const kid of rendered) {
    const at = `${label} #${kid.index}`;
    // 1) Animasyon bildirilmiş
    expect(kid.animationName, `${at}: animation-name`).toBe(animationName);
    expect(kid.animationFillMode, `${at}: animation-fill-mode`).toBe('forwards');
    expect(kid.animationDurationCss, `${at}: CSS süresi`).toBeCloseTo(durationMs, 0);
    // 2) GERÇEK TARAYICI KANITI: Animation API canlı animasyon döndürmeli
    expect(
      kid.animations,
      `${at}: getAnimations() boş — animasyon motoru çalışmıyor`,
    ).toBeGreaterThanOrEqual(1);
    expect(
      kid.playStates,
      `${at}: animasyon "running" değil (${JSON.stringify(kid.playStates)})`,
    ).toContain('running');
    // 3) Animation API zamanlaması computed style'ı teyit etmeli
    const timing = kid.timings[0];
    expect(timing, `${at}: animasyon zamanlaması okunamadı`).toBeTruthy();
    expect(timing.duration, `${at}: Animation API süresi`).toBeCloseTo(durationMs, 0);
    expect(timing.fill, `${at}: Animation API fill`).toBe('forwards');
    timings.push({ delayMs: timing.delay, cssDelayMs: kid.animationDelayCss });
  }

  // 4) Kademe: gecikmeler pozitif ve artan olmalı; CSS ile API uyuşmalı
  expect(timings[0].delayMs, `${label}: ilk gecikme pozitif olmalı`).toBeGreaterThan(0);
  for (let i = 1; i < timings.length; i += 1) {
    expect(
      timings[i].delayMs,
      `${label}: #${i} gecikmesi #${i - 1} gecikmesinden büyük olmalı`,
    ).toBeGreaterThan(timings[i - 1].delayMs);
  }
  for (const t of timings) {
    expect(t.cssDelayMs, `${label}: CSS/API gecikme uyuşmazlığı`).toBeCloseTo(t.delayMs, 0);
  }

  // 5) Animasyonun başında en az ilk öğe görünmez olmalı (kademe gözle görülür)
  expect(
    rendered[0].opacity,
    `${label}: ilk öğe animasyon başında opacity < 1 olmalı`,
  ).toBeLessThan(1);

  return timings;
}

/**
 * Animasyon bitince panelin ve çocuklarının GÖRÜNÜR kaldığını doğrular.
 *
 * Bu, "popover görünmez kalır" regresyonunun kapısıdır: taban kural çocukları
 * `opacity: 0` yapar ve yalnızca `forwards` fill'li animasyon onları görünür
 * hâle getirir. Animasyon oynamazsa panel içi boş görünür.
 */
async function expectSettledVisible(page, { panelSelector, childSelector = '*', label }) {
  const probe = { panelSelector, childSelector };

  await page.waitForFunction(
    ({ panelSelector, childSelector }) => {
      const panel = document.querySelector(panelSelector);
      if (!panel) return false;
      // Gizli çocuklar (display: none) beklemeye dahil edilmez.
      const kids = Array.from(panel.querySelectorAll(':scope > ' + childSelector)).filter(
        (el) => el.getClientRects().length > 0,
      );
      if (kids.length === 0) return false;
      return kids.every((el) =>
        parseFloat(getComputedStyle(el).opacity) === 1 &&
        el.getAnimations().every((animation) => animation.playState !== 'running'),
      );
    },
    probe,
    { timeout: 5_000 },
  );

  const result = await page.evaluate(({ panelSelector, childSelector }) => {
    const panel = document.querySelector(panelSelector);
    const kids = Array.from(panel.querySelectorAll(':scope > ' + childSelector)).filter(
      (el) => el.getClientRects().length > 0,
    );
    const box = panel.getBoundingClientRect();
    return {
      renderedCount: kids.length,
      opacities: kids.map((el) => parseFloat(getComputedStyle(el).opacity)),
      panelVisibility: getComputedStyle(panel).visibility,
      panelOpacity: parseFloat(getComputedStyle(panel).opacity),
      width: box.width,
      height: box.height,
      stillRunning: kids
        .flatMap((el) => el.getAnimations())
        .filter((a) => a.playState === 'running').length,
    };
  }, probe);

  expect(result.renderedCount, `${label}: görünür öğe sayısı > 0`).toBeGreaterThan(0);
  expect(
    result.opacities.every((o) => o === 1),
    `${label}: animasyon sonunda tüm GÖRÜNÜR öğeler opacity 1 olmalı ` +
      `(${JSON.stringify(result.opacities)})`,
  ).toBe(true);
  expect(result.panelOpacity, `${label}: panel opacity`).toBe(1);
  expect(result.panelVisibility, `${label}: panel görünürlüğü`).toBe('visible');
  expect(result.width, `${label}: panel genişliği > 0`).toBeGreaterThan(0);
  expect(result.height, `${label}: panel yüksekliği > 0`).toBeGreaterThan(0);
  expect(result.stillRunning, `${label}: animasyonlar bitmiş olmalı`).toBe(0);

  return result;
}

module.exports = { measureStagger, expectStaggered, expectSettledVisible };
