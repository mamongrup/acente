// Hero sekme etiketleri — hover mikro etkileşimi (gerçek tarayıcı).
//
// NEDEN: şablonun kendi kuralı yalnız `transition: color .2s` verir ve alt çizgi
// göstergesini SEÇİLİ sekmeye saklar. Projenin mikro etkileşim dilinde hover
// her zaman renk + yumuşak zemin + küçük kayma ve bir gösterge önizlemesidir.
// Bu spec o dilin hero sekmelerinde gerçekten oynadığını ölçer ve en kritik
// riski kapatır: zemin/çizgi katmanları NEGATİF insetle çizilmeli, aksi halde
// sekme satırı genişliği ve seçili alt çizginin ölçüsü şablondan sapar.
//
// Ölçüm computed style üzerinden yapılır (piksel farkı yok).
const { test, expect } = require('@playwright/test');

const TAB = '.hero-search-form [role="tablist"] [role="tab"]';

const PROBE = `(el) => {
  const cs = getComputedStyle(el);
  const before = getComputedStyle(el, '::before');
  const after = getComputedStyle(el, '::after');
  return {
    label: el.textContent.trim(),
    selected: el.hasAttribute('data-selected'),
    color: cs.color,
    transform: cs.transform,
    transition: cs.transitionProperty + '|' + cs.transitionDuration,
    washOpacity: parseFloat(before.opacity),
    washBg: before.backgroundColor,
    washInset: [before.top, before.right, before.bottom, before.left].join(' '),
    underline: after.content,
    underlineOpacity: parseFloat(after.opacity),
    underlineAnim: after.animationName,
    outline: cs.outlineWidth + ' ' + cs.outlineStyle + ' ' + cs.outlineColor,
    outlineOffset: cs.outlineOffset,
  };
}`;

// İki sabit tema değeri (şablonun Tailwind sınıfları)
const HOVER_LIGHT = 'rgb(55, 65, 81)'; // neutral-700
const HOVER_DARK = 'rgb(156, 163, 175)'; // neutral-400
const WASH_LIGHT = 'rgb(249, 250, 251)'; // neutral-50
const WASH_DARK = 'rgb(55, 65, 81)'; // neutral-700

async function theme(page) {
  return page.evaluate(() =>
    document.documentElement.classList.contains('dark') ? 'dark' : 'light',
  );
}

async function openHome(page) {
  await page.goto('/');
  await page.waitForSelector(TAB);
  await page.waitForTimeout(400);
}

test.describe('hero sekme hover mikro etkileşimi', () => {
  test.use({ viewport: { width: 1280, height: 900 } });

  test('pasif sekmede zemin görünmez, geçişler tanımlı, alt çizgi yok', async ({ page }) => {
    await openHome(page);
    const t = await theme(page);
    const tabs = page.locator(TAB);
    const passive = await tabs.nth(1).evaluate(new Function('el', `return (${PROBE})(el);`));

    expect(passive.washOpacity).toBe(0);
    expect(passive.underline).toBe('none');
    // Projenin mikro etkileşim dili: renk + kayma geçişi birlikte tanımlı
    expect(passive.transition).toContain('color');
    expect(passive.transition).toContain('transform');
    expect(passive.transition).toContain('0.2s');
    expect(passive.transition).toContain('0.15s');
    // Zemin katmanı negatif insetle çizilir (layout'a girmez)
    expect(passive.washInset).toBe('-4px -8px -4px -8px');
    expect(passive.washBg).toBe(t === 'dark' ? WASH_DARK : WASH_LIGHT);
  });

  test('hover: zemin belirir, 2px kayar, alt çizgi önizlenir — layout değişmez', async ({ page }) => {
    await openHome(page);
    const t = await theme(page);
    const tabs = page.locator(TAB);

    const layoutBefore = await page.evaluate(
      (sel) => Array.from(document.querySelectorAll(sel)).map((e) => Math.round(e.getBoundingClientRect().width * 100)),
      TAB,
    );

    await tabs.nth(1).hover();
    await page.waitForTimeout(160);
    const hovered = await tabs.nth(1).evaluate(new Function('el', `return (${PROBE})(el);`));
    const passiveColor = t === 'dark' ? HOVER_DARK : HOVER_LIGHT;

    expect(hovered.selected).toBe(false);
    expect(hovered.color, 'şablonun hover rengi korunmalı').toBe(passiveColor);
    expect(hovered.transform, 'mikro kayma (2px)').toBe('matrix(1, 0, 0, 1, 2, 0)');
    expect(hovered.washOpacity, 'zemini geçirmeli').toBe(1);
    // Alt çizgi önizlemesi: soluk, soldan açılır
    expect(hovered.underline).toBe('""');
    expect(hovered.underlineOpacity).toBeCloseTo(0.45, 2);
    expect(hovered.underlineAnim).toBe('tabHoverIn');

    const layoutAfter = await page.evaluate(
      (sel) => Array.from(document.querySelectorAll(sel)).map((e) => Math.round(e.getBoundingClientRect().width * 100)),
      TAB,
    );
    expect(layoutAfter, 'hover satır genişliğini değiştirmemeli').toEqual(layoutBefore);
  });

  test('seçili sekme kalıcı göstergesini korur (hover önizlemesi almaz)', async ({ page }) => {
    await openHome(page);
    const selected = page.locator(`${TAB}[data-selected]`);
    await expect(selected).toHaveCount(1);

    await selected.hover();
    await page.waitForTimeout(160);
    const s = await selected.evaluate(new Function('el', `return (${PROBE})(el);`));

    // Kalıcı çizgi `tabSlide` animasyonuyla gelir, hover önizlemesiyle ezilmez
    expect(s.underlineAnim).toBe('tabSlide');
    expect(s.underlineOpacity).toBe(1);
    // Zemin + kayma yine uygulanır (hover geri bildirimi her sekmede var)
    expect(s.washOpacity).toBe(1);
    expect(s.transform).toBe('matrix(1, 0, 0, 1, 2, 0)');
  });

  test('klavye odağında görünür halka: şablonun outline-hidden sınıfı telafi edilir', async ({ page }) => {
    await openHome(page);
    const selected = page.locator(`${TAB}[data-selected]`);
    await selected.evaluate((el) => el.focus());
    await page.waitForTimeout(80);
    const s = await selected.evaluate(new Function('el', `return (${PROBE})(el);`));

    expect(s.outline).toBe('2px solid rgb(99, 102, 241)'); // --color-primary-500
    expect(s.outlineOffset).toBe('3px');
  });
});

test.describe('hero sekme hover — hareket azaltma', () => {
  test.use({ viewport: { width: 1280, height: 900 }, reducedMotion: 'reduce' });

  test('reduced-motion: kayma ve animasyon yok, renk/zemin geri bildirimi kalır', async ({ page }) => {
    await openHome(page);
    const tabs = page.locator(TAB);
    await tabs.nth(1).hover();
    await page.waitForTimeout(160);
    const h = await tabs.nth(1).evaluate(new Function('el', `return (${PROBE})(el);`));

    expect(h.transition).toContain('none');
    expect(h.transform, 'kayma olmamalı').toBe('none');
    expect(h.underlineAnim, 'önizleme animasyonsuz').toBe('none');
    expect(h.underlineOpacity).toBeCloseTo(0.45, 2);
    // Geri bildirim kaybolmaz
    expect(h.washOpacity).toBe(1);
  });
});
