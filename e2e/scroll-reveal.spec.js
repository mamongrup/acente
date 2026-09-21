// Scroll-reveal (kademeli giriş) — gerçek tarayıcı testleri.
//
// NEDEN gerçek tarayıcı: önizleme webview'i CSS transition'larını oynatmaz
// (`getAnimations()` orada boş döner), bu yüzden reveal etkisi webview'de
// gözlemlenemez. Bu paket sistemdeki Edge/Chrome ile çalışır ve ölçümü
// **Transition/Animation API + computed style** üzerinden yapar.
//
// Kapsam:
//   1) Boot zinciri: reveal-boot.js + main.js devralması
//   2) Header: yüklenirken belirir, bittiğinde transform'suz kalır (sticky güvenliği)
//   3) Hero arama formu: sekmeler → alanlar → buton kademesi (masaüstü)
//   4) Bölüm kartları: gizli başlar, kaydırınca kademeli açılır
//   5) Sayfa sonuna kadar kaydırınca görünür hiçbir hedef gizli kalmaz
//   6) Motion-reduce ve JS kapalı sözleşmeleri (hiçbir şey gizlenmez)
const { test, expect } = require('@playwright/test');

const HEADER = 'header.chisfis-header-root';
const FEATURED_CARD = '.home-featured .featured-grid > *';

// Bir hedefi bulur, kaydırır ve reveal geçişini **sayfa içinde** ölçer;
// böylece tur gecikmesi ölçüme karışmaz (flaky olmayan deterministik ölçüm).
async function revealProbe(page, selector, index = 0) {
  return page.evaluate(
    async ({ selector, index }) => {
      const frames = (n) =>
        new Promise((res) => {
          let i = n;
          const step = () => (--i <= 0 ? res() : requestAnimationFrame(step));
          requestAnimationFrame(step);
        });

      const el = Array.from(document.querySelectorAll(selector))[index];
      if (!el) return { error: 'bulunamadı: ' + selector + ' [' + index + ']' };

      const before = {
        marked: el.hasAttribute('data-reveal'),
        opacity: parseFloat(getComputedStyle(el).opacity),
        delay: el.style.getPropertyValue('--reveal-delay'),
        transform: getComputedStyle(el).transform,
      };

      el.scrollIntoView({ block: 'center' });
      // `is-revealed` sınıfı eklenene kadar bekle (IO/scroll kapısı)
      let waited = 0;
      while (!el.classList.contains('is-revealed') && waited < 2500) {
        await frames(1);
        waited += 16;
      }
      const sawRevealedClass = el.classList.contains('is-revealed');
      const transitions = el.getAnimations().map((a) => {
        const t = a.effect && a.effect.getComputedTiming ? a.effect.getComputedTiming() : {};
        return {
          prop: a.transitionProperty || a.animationName || null,
          playState: a.playState,
          duration: t.duration,
          delay: t.delay,
        };
      });

      // Geçiş bitene kadar bekle
      let t2 = 0;
      while (parseFloat(getComputedStyle(el).opacity) < 1 && t2 < 2500) {
        await frames(1);
        t2 += 16;
      }

      return {
        before,
        sawRevealedClass,
        transitions,
        after: {
          opacity: parseFloat(getComputedStyle(el).opacity),
          transform: getComputedStyle(el).transform,
          marked: el.hasAttribute('data-reveal'),
          revealed: el.classList.contains('is-revealed'),
        },
      };
    },
    { selector, index },
  );
}

test.describe('scroll-reveal — masaüstü', () => {
  test.use({ viewport: { width: 1280, height: 820 } });

  test('boot zinciri: gizli durum ilk boyamada işaretlenir, denetleyici devralır', async ({ page }) => {
    await page.goto('/');
    const state = await page.evaluate(() => ({
      hasReveal: document.documentElement.classList.contains('has-reveal'),
      ready: document.documentElement.hasAttribute('data-reveal-ready'),
      bootScript: !!document.querySelector('script[src*="reveal-boot.js"]'),
      marked: document.querySelectorAll('[data-reveal]').length,
    }));
    expect(state.bootScript).toBe(true);
    expect(state.hasReveal).toBe(true);
    expect(state.ready).toBe(true);
    // Kaydırma öncesi (aşağıdaki bölümler) gizli durumda işaretlenmiş olmalı
    expect(state.marked).toBeGreaterThan(0);
  });

  test('header yüklenirken opacity geçişiyle belirir ve sonunda transform\'suz kalır', async ({ page }) => {
    // transitionrun olaylarını ilk boyamadan önce dinlemeye başla
    await page.addInitScript(() => {
      window.__revealEvents = [];
      document.addEventListener(
        'transitionrun',
        (e) => {
          const cls = String(e.target.className || '').split(/\s+/).slice(0, 2).join('.');
          window.__revealEvents.push({ target: e.target.tagName.toLowerCase() + '.' + cls, prop: e.propertyName });
        },
        true,
      );
    });
    await page.goto('/');

    await page.waitForFunction(
      () => !document.querySelector('header.chisfis-header-root').hasAttribute('data-reveal'),
      null,
      { timeout: 5000 },
    );

    const events = await page.evaluate(() => window.__revealEvents.filter((e) => /chisfis-header-root/.test(e.target)));
    expect(events.some((e) => e.prop === 'opacity')).toBe(true);

    const header = await page.evaluate(() => {
      const el = document.querySelector('header.chisfis-header-root');
      const cs = getComputedStyle(el);
      return { opacity: cs.opacity, transform: cs.transform, marked: el.hasAttribute('data-reveal') };
    });
    expect(header.marked).toBe(false);
    expect(header.opacity).toBe('1');
    // Kalıcı transform kalmamalı: sticky çocukları bozmaması bunun garantisi.
    expect(header.transform).toBe('none');
  });

  test('reveal sonrası header transform\'suz kalır (yapışkan satır sözleşmesi)', async ({ page }) => {
    await page.goto('/');
    await page.waitForFunction(
      () => !document.querySelector('header.chisfis-header-root').hasAttribute('data-reveal'),
      null,
      { timeout: 5000 },
    );
    await page.evaluate(() => window.scrollTo(0, 900));
    await page.waitForTimeout(400);
    const state = await page.evaluate(() => {
      const header = document.querySelector('header.chisfis-header-root');
      const stickyRow = document.querySelector('header .sticky');
      return {
        headerTransform: getComputedStyle(header).transform,
        headerOpacity: getComputedStyle(header).opacity,
        stickyPosition: stickyRow ? getComputedStyle(stickyRow).position : null,
        stickyTop: stickyRow ? getComputedStyle(stickyRow).top : null,
      };
    });
    // Kalıcı transform yok → yapışkan (sticky) torunlar için containing block
    // yaratılmaz; şablonun `sticky top-0` satırı çalışmaya devam eder.
    expect(state.headerTransform).toBe('none');
    expect(state.headerOpacity).toBe('1');
    expect(state.stickyPosition).toBe('sticky');
    expect(state.stickyTop).toBe('0px');
  });

  test('hero: başlık → sekmeler → alanlar → buton kademesi ve görünür kalma', async ({ page }) => {
    // Kademe gecikmeleri GEÇİCİ bir durumdur: hero görüş alanında olduğu için
    // geçiş biter bitmez `settle()` hem `data-reveal`ı hem `--reveal-delay`ı
    // SİLER (kartların kendi hover geçişleri devralınmasın diye). Yükleme
    // yavaşladığında `goto` bu temizlikten SONRA döner ve anlık okuma NaN
    // verir — ölçüm yükleme hızına bağlı kalırdı. Bu yüzden değerler
    // atandıkları anda kaydedilir ve iddialar bu kayıttan yapılır;
    // temizlik sonrası hiçbir şey okunmaz.
    await page.addInitScript(() => {
      window.__reveal = { heading: null, tabs: null, fields: [] };
      const FORM = '.hero-search-form';
      const collect = () => {
        const wrap = document.querySelector('main > div.container > div');
        if (wrap && window.__reveal.heading === null) {
          const d = wrap.style.getPropertyValue('--reveal-delay');
          if (d) window.__reveal.heading = parseFloat(d);
        }
        const tabs = document.querySelector(FORM + ' [role="tablist"]');
        if (tabs && window.__reveal.tabs === null) {
          const d = tabs.style.getPropertyValue('--reveal-delay');
          if (d) window.__reveal.tabs = parseFloat(d);
        }
        const form = document.querySelector(FORM + ' form');
        if (form && !window.__reveal.fields.length) {
          const vals = Array.from(form.children).map((el) =>
            el.style.getPropertyValue('--reveal-delay'),
          );
          // Tüm alanlar tek senkron blokta işaretlenir; biri eksikse
          // kayıt yapılmaz (kısmi liste yanıltıcı olurdu).
          if (vals.length && vals.every((v) => v)) {
            window.__reveal.fields = vals.map(parseFloat);
          }
        }
      };
      document.addEventListener('DOMContentLoaded', () => {
        collect();
        new MutationObserver(collect).observe(document.documentElement, {
          subtree: true,
          attributes: true,
          attributeFilter: ['style'],
        });
      });
    });
    await page.goto('/');
    await page.waitForFunction(() => window.__reveal && window.__reveal.fields.length > 0, null, {
      timeout: 8000,
    });
    const hero = await page.evaluate(() => window.__reveal);
    expect(hero.heading).not.toBeNull();
    expect(hero.tabs).not.toBeNull();
    expect(hero.heading).toBeLessThan(hero.tabs);
    expect(hero.fields.length).toBeGreaterThanOrEqual(3);
    // Sabit artan kademe (STEP = .06s)
    expect(hero.fields[1] - hero.fields[0]).toBeCloseTo(0.06, 5);
    expect(hero.fields[2] - hero.fields[1]).toBeCloseTo(0.06, 5);
    // Sekmeler ilk alandan önce (başlık → sekmeler → alanlar sırası)
    expect(hero.tabs).toBeLessThan(hero.fields[0]);

    // Hero görüş alanında: yüklenirken reveal olmalı ve sonunda görünür kalmalı
    const probe = await page.evaluate(async () => {
      const frames = (n) =>
        new Promise((res) => {
          let i = n;
          const step = () => (--i <= 0 ? res() : requestAnimationFrame(step));
          requestAnimationFrame(step);
        });
      let w = 0;
      while (w < 2500) {
        const pending = Array.from(document.querySelectorAll('.hero-search-form [data-reveal]'));
        if (!pending.length) break;
        await frames(1);
        w += 16;
      }
      const els = Array.from(document.querySelectorAll('.hero-search-form [role="tablist"], .hero-search-form form > *'));
      return els.map((el) => ({
        opacity: parseFloat(getComputedStyle(el).opacity),
        marked: el.hasAttribute('data-reveal'),
      }));
    });
    for (const el of probe) {
      expect(el.marked).toBe(false);
      expect(el.opacity).toBe(1);
    }
  });

  test('bölüm kartları gizli başlar, kaydırınca kademeli açılır', async ({ page }) => {
    await page.goto('/');

    const before = await page.evaluate((sel) => {
      return Array.from(document.querySelectorAll(sel)).map((el) => ({
        opacity: parseFloat(getComputedStyle(el).opacity),
        marked: el.hasAttribute('data-reveal'),
        delay: parseFloat(el.style.getPropertyValue('--reveal-delay') || 'NaN'),
        top: Math.round(el.getBoundingClientRect().top),
      }));
    }, FEATURED_CARD);

    expect(before.length).toBeGreaterThanOrEqual(3);
    // Ekranın çok altındaki kartlar gizli ve işaretli olmalı
    expect(before.every((c) => c.marked)).toBe(true);
    expect(before.every((c) => c.opacity === 0)).toBe(true);
    // Gecikmeler artan olmalı (kademeli giriş)
    for (let i = 1; i < before.length; i++) {
      expect(before[i].delay).toBeGreaterThan(before[i - 1].delay);
    }

    const probe = await revealProbe(page, FEATURED_CARD, 0);
    expect(probe.error).toBeUndefined();
    expect(probe.before.opacity).toBe(0);
    expect(probe.sawRevealedClass).toBe(true);
    const opacityTransition = probe.transitions.find((t) => t.prop === 'opacity');
    expect(opacityTransition, 'opacity geçişi kaydedilmeli').toBeTruthy();
    expect(opacityTransition.playState).toBe('running');
    expect(opacityTransition.duration).toBeGreaterThanOrEqual(500);
    expect(probe.after.opacity).toBe(1);
    // Geçiş bitince işaret kaldırılır → kartın kendi hover geçişi devralınmaz
    expect(probe.after.marked).toBe(false);
    expect(probe.after.transform).toBe('none');
  });

  test('sayfa sonuna kadar kaydırılınca görünür hiçbir hedef gizli kalmaz', async ({ page }) => {
    await page.goto('/');
    const height = await page.evaluate(() => document.body.scrollHeight);
    for (let y = 0; y < height; y += 600) {
      await page.evaluate((yy) => window.scrollTo(0, yy), y);
      await page.waitForTimeout(120);
    }
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(1200);

    const stuck = await page.evaluate(() =>
      Array.from(document.querySelectorAll('[data-reveal]'))
        .filter((el) => el.getClientRects().length > 0)
        .map((el) => el.tagName.toLowerCase() + '.' + String(el.className).split(/\s+/).slice(0, 2).join('.')),
    );
    expect(stuck).toEqual([]);
  });
});

test.describe('scroll-reveal — mobil', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test('mobil header + bölümler açılır, gizli hero formu asılı kalmaz', async ({ page }) => {
    await page.goto('/');
    // Mobilde masaüstü hero formu `display:none` — işaretlenmemeli (asılı hedef olmasın)
    const heroMarked = await page.evaluate(() => document.querySelectorAll('.hero-search-form [data-reveal]').length);
    expect(heroMarked).toBe(0);

    const probe = await revealProbe(page, '.home-adventure .adventure-grid > *', 0);
    expect(probe.error).toBeUndefined();
    expect(probe.before.opacity).toBe(0);
    expect(probe.after.opacity).toBe(1);

    // Mobilde de reveal sonrası kalıcı transform kalmamalı
    const after = await page.evaluate(() => {
      const header = document.querySelector('header.chisfis-header-root');
      const stickyRow = document.querySelector('header .sticky');
      return {
        transform: getComputedStyle(header).transform,
        marked: header.hasAttribute('data-reveal'),
        stickyPosition: stickyRow ? getComputedStyle(stickyRow).position : null,
      };
    });
    expect(after.marked).toBe(false);
    expect(after.transform).toBe('none');
    expect(after.stickyPosition).toBe('sticky');
  });
});

test.describe('scroll-reveal — sözleşmeler', () => {
  test('prefers-reduced-motion: reduce → hiçbir şey gizlenmez', async ({ browser }) => {
    const context = await browser.newContext({ reducedMotion: 'reduce', viewport: { width: 1280, height: 820 } });
    const page = await context.newPage();
    await page.goto('/');
    const state = await page.evaluate(() => ({
      hasReveal: document.documentElement.classList.contains('has-reveal'),
      marked: document.querySelectorAll('[data-reveal]').length,
      hiddenCards: Array.from(document.querySelectorAll('.home-featured .featured-grid > *')).filter(
        (el) => parseFloat(getComputedStyle(el).opacity) < 1,
      ).length,
    }));
    expect(state.hasReveal).toBe(false);
    expect(state.marked).toBe(0);
    expect(state.hiddenCards).toBe(0);
    await context.close();
  });

  test('JavaScript kapalıyken içerik görünür (progressive enhancement)', async ({ browser }) => {
    const context = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 1280, height: 820 } });
    const page = await context.newPage();
    await page.goto('/');
    // JS yok → reveal-boot.js de main.js de çalışmaz; hiçbir kart gizlenmemeli.
    const count = await page.locator('.home-featured .featured-grid > *').count();
    expect(count).toBeGreaterThan(0);
    const firstVisible = await page.locator('.home-featured .featured-grid > *').first().isVisible();
    expect(firstVisible).toBe(true);
    const opacity = await page
      .locator('.home-featured .featured-grid > *')
      .first()
      .evaluate((el) => getComputedStyle(el).opacity);
    expect(opacity).toBe('1');
    await context.close();
  });
});
