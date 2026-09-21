// Hero sekme listesi — klavye gezinmesi (roving tabindex), gerçek tarayıcı.
//
// NEDEN: şablon hero sekmelerini bağlantı olarak basar ve roving tabindex'i
// zaten verir (seçili `tabindex="0"`, diğerleri `-1`). Ok tuşları bağlı
// olmadığı için `-1` sekmelere klavyeyle HİÇ odaklanamıyordu: Tab listeye
// girip çıkıyor, diğer sekmeler erişilemez kalıyordu. Bu spec iki riski
// ölçer: (1) ok tuşları odağı + tabindex'i taşıyor mu, (2) bağlantı
// sekmelerinde ok tuşu yanlışlıkla SAYFA DEĞİŞTİRİYOR mu.
const { test, expect } = require('@playwright/test');

const LIST = '.hero-search-form [role="tablist"]';
const TAB = `${LIST} [role="tab"]`;

// Tarayıcıda çalışan gerçek fonksiyon (string gövde değil): roving durumunu
// ve odağı okur.
function rovingState() {
  const list = document.querySelector('.hero-search-form [role="tablist"]');
  if (!list) return null;
  const tabs = Array.prototype.slice
    .call(list.querySelectorAll('[role="tab"]'))
    .filter((t) => t.closest('[role="tablist"]') === list);
  return {
    count: tabs.length,
    tabbable: tabs.filter((t) => t.tabIndex === 0).map((t) => t.textContent.trim()),
    minus: tabs.filter((t) => t.tabIndex === -1).length,
    focused: document.activeElement ? document.activeElement.textContent.trim() : null,
    focusedIsTab: tabs.indexOf(document.activeElement) !== -1,
    vertical: list.getAttribute('aria-orientation'),
  };
}

test.describe('hero tablist keyboard navigation', () => {
  test('every tab is reachable with arrow keys (roving tabindex)', async ({ page }) => {
    await page.goto('/');

    const tabs = page.locator(TAB);
    await expect(tabs.first()).toBeVisible();
    const count = await tabs.count();
    expect(count).toBeGreaterThanOrEqual(3);

    // Açılış: liste içinde TEK tabbable sekme (roving invariant'ı).
    const initial = await page.evaluate(rovingState);
    expect(initial.count).toBe(count);
    expect(initial.tabbable.length).toBe(1);
    expect(initial.minus).toBe(count - 1);
    expect(initial.vertical).toBe('horizontal');

    // Seçili sekmeye odaklan, ok tuşlarıyla gezin.
    await tabs.first().focus();
    const url = page.url();
    const labels = [];

    for (let i = 0; i < count; i++) {
      const state = await page.evaluate(rovingState);
      labels.push(state.focused);
      // Odak gerçekten bir sekmede ve o sekme tabbable olan tek sekme.
      expect(state.focusedIsTab).toBe(true);
      expect(state.tabbable).toEqual([state.focused]);
      expect(state.minus).toBe(count - 1);
      await page.keyboard.press('ArrowRight');
    }

    // Tur tamamlandı: her sekme sırayla odaklandı (döngüsel).
    expect(new Set(labels).size).toBe(count);

    // Bağlantı sekmeleri: ok tuşu SAYFA DEĞİŞTİRMEMELİ.
    expect(page.url()).toBe(url);
  });

  test('Home and End jump to the first and last tab', async ({ page }) => {
    await page.goto('/');
    const tabs = page.locator(TAB);
    await expect(tabs.first()).toBeVisible();
    const count = await tabs.count();
    const lastLabel = (await tabs.nth(count - 1).textContent()).trim();
    const firstLabel = (await tabs.first().textContent()).trim();

    await tabs.nth(1).focus();
    await page.keyboard.press('End');
    let state = await page.evaluate(rovingState);
    expect(state.focused).toBe(lastLabel);

    await page.keyboard.press('Home');
    state = await page.evaluate(rovingState);
    expect(state.focused).toBe(firstLabel);
    expect(state.tabbable).toEqual([firstLabel]);
  });

  test('arrow keys wrap around the list', async ({ page }) => {
    await page.goto('/');
    const tabs = page.locator(TAB);
    await expect(tabs.first()).toBeVisible();
    const count = await tabs.count();
    const lastLabel = (await tabs.nth(count - 1).textContent()).trim();

    await tabs.first().focus();
    await page.keyboard.press('ArrowLeft');
    const state = await page.evaluate(rovingState);
    expect(state.focused).toBe(lastLabel);
  });
});
