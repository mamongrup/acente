const { test, expect } = require('@playwright/test');

const URL = 'http://127.0.0.1:8082/urunler?tenant=ca43626b-4d77-41d8-898c-317576e991b5';

test.use({ viewport: { width: 390, height: 780 } });

const state = (page) =>
  page.evaluate(() => {
    const t = document.querySelector('.listing-filter-toggle');
    const b = document.querySelector('.listing-filter-body');
    return {
      aria: t.getAttribute('aria-expanded'),
      open: b.classList.contains('is-open'),
      max: b.style.maxHeight,
    };
  });

test('filtre toggle: tek sahip, aria durumu gerçeği yansıtır', async ({ page }) => {
  await page.goto(URL);
  await page.waitForTimeout(900);

  const closed = await state(page);
  expect(closed.open).toBe(false);
  expect(closed.aria).toBe('false');

  // 1) Aç: panel görünür + aria true
  await page.evaluate(() => document.querySelector('.listing-filter-toggle').click());
  await page.waitForTimeout(500);
  const open = await state(page);
  expect(open.open).toBe(true);
  expect(open.aria).toBe('true');

  // 2) Dış tıklama: panel açık kalır ve aria etiketi GERÇEĞİ söyler
  //    (main.js §12 + header-popovers.js süpürmeleri bu düğmeye dokunmamalı)
  await page.evaluate(() => document.querySelector('.products-toolbar').click());
  await page.waitForTimeout(300);
  const afterOutside = await state(page);
  expect(afterOutside.open).toBe(true);
  expect(afterOutside.aria).toBe('true');

  // 3) Kapat: ikinci tıklama kapatır, aria false
  await page.evaluate(() => document.querySelector('.listing-filter-toggle').click());
  await page.waitForTimeout(500);
  const reclosed = await state(page);
  expect(reclosed.open).toBe(false);
  expect(reclosed.aria).toBe('false');

  // 4) Ok simgesi gerçek açık durumda dönmüş olmalı (CSS aria-expanded'e bağlı)
  await page.evaluate(() => document.querySelector('.listing-filter-toggle').click());
  await page.waitForTimeout(500);
  const chevron = await page.evaluate(() => {
    const c = document.querySelector('.listing-filter-toggle-chevron');
    return { transform: getComputedStyle(c).transform, text: c.textContent };
  });
  expect(chevron.transform).not.toBe('none');
});
