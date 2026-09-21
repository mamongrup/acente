// Scroll-reveal — MAĞAZA sayfaları (ilan listesi, kategori, ilan detayı).
//
// NEDEN ayrı paket: `scroll-reveal.spec.js` ana sayfanın builder çıktısına
// göre yazılmış. Store sayfalarında içerik `main`in doğrudan çocukları olarak
// geliyor ve başlık bloğu (`span.eyebrow`, `nav.listing-breadcrumb`, `h1`, `p`)
// `div`/`section` OLMADIĞI için genel blok taraması onları hiç görmüyordu:
// sayfa başlığı animasyonsuz açılırken altındaki filtre/araç çubuğu ve kartlar
// kademeli giriyordu.
//
// Ölçüm notları:
//   * Kademe gecikmeleri GEÇİCİ bir durumdur — `settle()` hem `data-reveal`ı
//     hem `--reveal-delay`ı siler. Bu yüzden değerler atandıkları anda bir
//     MutationObserver ile kaydedilir, temizlik sonrası hiçbir şey okunmaz.
//   * "Gizli kalmadı" iddiası OLAYLARA göre kurulur: görülen her hedef
//     `data-rv-seen` ile işaretlenir. Sayfadaki genel `opacity: 0` avı yanlış
//     pozitif verir — detay sayfasında hover zoom merceği (`.zoom-lens`,
//     `.zoom-result`) tasarım gereği gizlidir.
//   * Bekleme sabit süreyle DEĞİL yoklamayla yapılır: hedefi gizli başlangıç
//     durumu hesaplanana kadar bekleyen kapı (`whenHidden`) yükleme hızına göre
//     ~1 sn gecikebilir; sabit bekleme o karede yanlış kırmızı üretir.
const { test, expect } = require('@playwright/test');

const LIST = '/urunler';
const CATEGORY = '/kategori/hotel';

// Her sayfa tipinde kademe gecikmesi kaydedilecek seçiciler.
const WATCH = [
  'main > span.eyebrow',
  'main > nav.listing-breadcrumb',
  'main > h1',
  'main > p',
  '.product-grid > *',
  '.category-hero > *',
  'main > nav.detail-breadcrumb',
  'main > div.detail-gallery',
  '.listingSection__wrap > *',
];

// Gözlemci + kayıt: gecikmeler atandıkları anda, hedefler görüldükleri anda.
// Gözlemci init script'te kurulur ve `defer` main.js'ten ÖNCE bağlanır.
async function installRecorder(page) {
  await page.addInitScript((watch) => {
    window.__rv = { delays: {}, order: [], seen: 0 };
    const collect = () => {
      watch.forEach((sel) => {
        Array.prototype.forEach.call(document.querySelectorAll(sel), (el, i) => {
          const d = el.style.getPropertyValue('--reveal-delay');
          if (!d) return;
          const k = sel + '[' + i + ']';
          if (!(k in window.__rv.delays)) {
            window.__rv.delays[k] = parseFloat(d);
            window.__rv.order.push(k);
          }
        });
      });
      Array.prototype.forEach.call(document.querySelectorAll('[data-reveal]'), (el) => {
        if (!el.hasAttribute('data-rv-seen')) {
          el.setAttribute('data-rv-seen', '');
          // Kendi opaklığı 1'den küçükse main.js onu `--reveal-op`a yazar;
          // değer atandığı anda kaydedilir (settle() temizler).
          el.setAttribute('data-rv-op', el.style.getPropertyValue('--reveal-op') || '1');
          window.__rv.seen += 1;
        }
      });
    };
    const root = document.documentElement || document;
    new MutationObserver(collect).observe(root, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: ['style', 'data-reveal'],
    });
    collect();
  }, WATCH);
}

async function readDelays(page) {
  return page.evaluate(() => window.__rv);
}

/// Kuyruk boşalana kadar YOKLAR (sabit bekleme yok), sonra "görülen her hedef
/// görünür" iddiasını kurar. Dönen sayaç, ölçümün gerçekten hedef gördüğünü
/// kanıtlar (boş küme üzerinde geçen test yanıltıcı olurdu).
async function expectAllRevealed(page) {
  await page.waitForFunction(() => document.querySelectorAll('[data-reveal]').length === 0, null, {
    timeout: 8000,
  });
  const state = await page.evaluate(() => {
    const seen = Array.from(document.querySelectorAll('[data-rv-seen]'));
    return {
      seen: seen.length,
      // "Gizli kalmadı" = opaklık SIFIR değil. Bire eşitlik aranmaz: tasarım
      // gereği yarı saydam elemanlar (ör. `.category-hero-image` → .92) kendi
      // değerlerinde kalır — reveal onları 1'e zorlamaz (`--reveal-op`).
      invisible: seen.filter((el) => parseFloat(getComputedStyle(el).opacity) === 0).length,
      transformed: seen.filter((el) => getComputedStyle(el).transform !== 'none').length,
    };
  });
  expect(state.seen).toBeGreaterThan(0);
  expect(state.invisible).toBe(0);
  // Kalıcı transform kalmamalı: yapışkan çocuklar için containing block yaratmasın
  expect(state.transformed).toBe(0);
}

async function scrollToBottom(page) {
  await page.evaluate(async () => {
    const step = Math.round(window.innerHeight * 0.7);
    for (let y = 0; y <= document.body.scrollHeight; y += step) {
      window.scrollTo(0, y);
      await new Promise((r) => setTimeout(r, 80));
    }
    window.scrollTo(0, document.body.scrollHeight);
    await new Promise((r) => setTimeout(r, 300));
  });
}

// Detay URL'i liste sayfasından keşfedilir — sabit UUID seed verisine bağlı kalmasın.
async function detailHref(page) {
  await page.goto(LIST);
  const href = await page.getAttribute('a[href*="/urunler/"]', 'href');
  expect(href, 'liste sayfasında ürün bağlantısı bulunamadı').toBeTruthy();
  return href;
}

test.describe('scroll-reveal — mağaza sayfaları', () => {
  test.use({ viewport: { width: 1280, height: 820 } });

  test('ilan listesi: başlık bloğu (eyebrow → kırıntı → h1 → lede) kademeli işaretlenir', async ({
    page,
  }) => {
    await installRecorder(page);
    await page.goto(LIST);
    await page.waitForFunction(() => window.__rv && window.__rv.order.length >= 4, null, {
      timeout: 10000,
    });
    const rv = await readDelays(page);

    // Yeni kapsam: `div`/`section` olmayan başlık elemanları da hedef oldu.
    for (const sel of [
      'main > span.eyebrow[0]',
      'main > nav.listing-breadcrumb[0]',
      'main > h1[0]',
      'main > p[0]',
    ]) {
      expect(rv.delays[sel], sel + ' işaretlenmedi').not.toBeUndefined();
    }
    // Sabit artan kademe (STEP = .06s)
    expect(rv.delays['main > span.eyebrow[0]']).toBeCloseTo(0, 5);
    expect(rv.delays['main > nav.listing-breadcrumb[0]']).toBeCloseTo(0.06, 5);
    expect(rv.delays['main > h1[0]']).toBeCloseTo(0.12, 5);
    expect(rv.delays['main > p[0]']).toBeCloseTo(0.18, 5);

    // Izgara kartları da kendi kademesiyle
    expect(rv.delays['.product-grid > *[1]'] - rv.delays['.product-grid > *[0]']).toBeCloseTo(0.06, 5);

    await scrollToBottom(page);
    await expectAllRevealed(page);
    const h1 = await page.evaluate(() => {
      const el = document.querySelector('main > h1');
      const cs = getComputedStyle(el);
      return { opacity: cs.opacity, transform: cs.transform, marked: el.hasAttribute('data-reveal') };
    });
    expect(h1.marked).toBe(false);
    expect(h1.opacity).toBe('1');
    expect(h1.transform).toBe('none');
  });

  test('reveal hedefin KENDİ opaklığını korur (yarı saydam görsel parlamaz)', async ({ page }) => {
    // Kategori hero görseli tasarım gereği 1'den küçük opaklıkla durur. Reveal
    // kuralı `opacity: 1` dayatırsa animasyon boyunca parlar, `settle()` anında
    // kendi değerine düşer (gözle görülür sıçrama). Kanıt: reveal penceresi
    // boyunca her karede ölçülen MAKSİMUM opaklık, hedefin kendi değerini
    // aşmamalı — `--reveal-op` kaldırılırsa maksimum 1'e çıkar ve test kırmızı olur.
    await page.addInitScript(() => {
      window.__opMax = { own: null, max: null };
      const tick = () => {
        const el = document.querySelector('.category-hero-image');
        if (el) {
          const op = parseFloat(getComputedStyle(el).opacity);
          if (window.__opMax.own === null) window.__opMax.own = op;
          if (el.hasAttribute('data-rv-seen')) {
            window.__opMax.max = Math.max(window.__opMax.max === null ? 0 : window.__opMax.max, op);
          }
        }
        requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    });
    await installRecorder(page);
    await page.goto(CATEGORY);
    await page.waitForFunction(() => window.__rv && window.__rv.seen > 0, null, { timeout: 10000 });
    await page.waitForTimeout(2500);

    const probe = await page.evaluate(() => ({
      own: window.__opMax.own,
      max: window.__opMax.max,
      current: (() => {
        const el = document.querySelector('.category-hero-image');
        return el ? parseFloat(getComputedStyle(el).opacity) : null;
      })(),
    }));
    expect(probe.own).not.toBeNull();
    expect(probe.max).not.toBeNull();
    // Kendi değeri 1'den küçük olmalı (yoksa bu test anlamsız olurdu)
    expect(probe.own).toBeLessThan(1);
    // Reveal penceresinde bu değerin üstüne çıkılmamış olmalı
    expect(probe.max).toBeLessThanOrEqual(probe.own + 0.02);
    expect(probe.current).toBeCloseTo(probe.own, 2);

    await scrollToBottom(page);
    await expectAllRevealed(page);
  });

  test('kendi opaklığı 0 olan katman reveal hedefi yapılmaz (bir an görünmez)', async ({
    page,
  }) => {
    // Bu sayfaların mevcut hedefleri arasında `opacity: 0` bir eleman yok
    // (zoom merceği zaten hedef değil), yani koruma yalnız iddiayla
    // kanıtlanamaz. Bu yüzden durum YAPAY olarak kurulur: `main`in doğrudan
    // çocuğu olan iki `<p>` eklenir — biri `opacity: 0` katman, biri normal.
    // Beklenen: normal olan işaretlenir, katman ASLA (reveal onu 0.55 sn
    // boyunca görünür yapardı). Markalama `defer` main.js'te olduğu için
    // enjeksiyon DOM parse edilirken yapılmalı.
    await installRecorder(page);
    await page.addInitScript(() => {
      const inject = () => {
        const main = document.querySelector('main');
        if (!main || document.getElementById('rv-probe-overlay')) return;
        const overlay = document.createElement('p');
        overlay.id = 'rv-probe-overlay';
        overlay.style.opacity = '0';
        overlay.textContent = 'overlay-probe';
        const plain = document.createElement('p');
        plain.id = 'rv-probe-plain';
        plain.textContent = 'plain-probe';
        main.appendChild(overlay);
        main.appendChild(plain);
      };
      new MutationObserver(inject).observe(document, { subtree: true, childList: true });
      document.addEventListener('DOMContentLoaded', inject);
    });
    await page.goto(LIST);
    await page.waitForFunction(() => !!document.getElementById('rv-probe-plain'), null, {
      timeout: 8000,
    });
    await scrollToBottom(page);
    await expectAllRevealed(page);

    const state = await page.evaluate(() => ({
      overlayMarked: document.getElementById('rv-probe-overlay').hasAttribute('data-rv-seen'),
      overlayOpacity: parseFloat(getComputedStyle(document.getElementById('rv-probe-overlay')).opacity),
      plainMarked: document.getElementById('rv-probe-plain').hasAttribute('data-rv-seen'),
      plainOpacity: parseFloat(getComputedStyle(document.getElementById('rv-probe-plain')).opacity),
    }));
    // Enjeksiyon markalamadan ÖNCE olmuş olmalı: normal eleman hedef oldu.
    expect(state.plainMarked).toBe(true);
    expect(state.plainOpacity).toBe(1);
    // Katman hedef olmadı ve gizli kaldı.
    expect(state.overlayMarked).toBe(false);
    expect(state.overlayOpacity).toBe(0);
  });

  test('ilan listesi: geçiş gerçekten oynar (opacity) ve kademe uygulanır', async ({ page }) => {
    await page.addInitScript(() => {
      window.__runs = [];
      document.addEventListener(
        'transitionrun',
        (e) => {
          const cls = String(e.target.className || '').split(/\s+/).slice(0, 2).join('.');
          window.__runs.push({
            target: e.target.tagName.toLowerCase() + '.' + cls,
            prop: e.propertyName,
            delay: getComputedStyle(e.target).transitionDelay,
          });
        },
        true,
      );
    });
    await page.goto(LIST);
    await page.waitForFunction(
      () => !document.querySelector('main > h1').hasAttribute('data-reveal'),
      null,
      { timeout: 8000 },
    );
    const runs = await page.evaluate(() => window.__runs);
    const opacityRuns = runs.filter((r) => r.prop === 'opacity');
    expect(opacityRuns.length).toBeGreaterThan(0);
    // Başlık elemanlarından en az biri geçişe girmiş olmalı (yeni kapsam)
    expect(runs.some((r) => /^(h1|span|nav)/.test(r.target))).toBe(true);
    // Kademe gerçekten uygulanmış: en az bir hedefin gecikmesi 0'dan büyük
    const delayed = runs.filter((r) => parseFloat(r.delay) > 0);
    expect(delayed.length).toBeGreaterThan(0);
  });

  test('kategori sayfası: hero bloğu ve kartlar kademeli, sonunda hepsi görünür', async ({
    page,
  }) => {
    await installRecorder(page);
    await page.goto(CATEGORY);
    await page.waitForFunction(() => window.__rv && window.__rv.order.length >= 3, null, {
      timeout: 10000,
    });
    const rv = await readDelays(page);
    expect(rv.delays['.category-hero > *[1]'] - rv.delays['.category-hero > *[0]']).toBeCloseTo(0.06, 5);
    expect(rv.delays['.category-hero > *[2]']).toBeGreaterThan(rv.delays['.category-hero > *[1]']);

    await scrollToBottom(page);
    await expectAllRevealed(page);
  });

  test('ilan detayı: kırıntı ve galeri hedef, yapışkan rezervasyon kartı transform\'suz kalır', async ({
    page,
  }) => {
    await installRecorder(page);
    const href = await detailHref(page);
    await page.goto(href);
    await page.waitForFunction(() => window.__rv && window.__rv.order.length > 0, null, {
      timeout: 10000,
    });
    const rv = await readDelays(page);
    const covered = Object.keys(rv.delays);
    // Yeni kapsam: `main > nav` (kırıntı). Galeri de `main > div` bloğu olarak
    // çocuklarıyla kapsanıyor.
    expect(covered.some((k) => k.indexOf('main > nav.detail-breadcrumb') === 0)).toBe(true);
    expect(covered.length).toBeGreaterThan(2);

    await scrollToBottom(page);
    await expectAllRevealed(page);

    const sticky = await page.evaluate(() => {
      const el = document.querySelector('main .sticky');
      if (!el) return null;
      const cs = getComputedStyle(el);
      return {
        position: cs.position,
        transform: cs.transform,
        opacity: cs.opacity,
        marked: el.hasAttribute('data-reveal'),
      };
    });
    if (sticky) {
      // `transform: none` → yapışkan davranış bozulmaz (containing block yok)
      expect(sticky.marked).toBe(false);
      expect(sticky.transform).toBe('none');
      expect(sticky.opacity).toBe('1');
      expect(sticky.position).toBe('sticky');
    }
  });

  test('üç sayfa tipinde de: tam kaydırma sonrası gizli hedef kalmaz', async ({ page }) => {
    for (const path of [LIST, CATEGORY]) {
      await installRecorder(page);
      await page.goto(path);
      await scrollToBottom(page);
      await expectAllRevealed(page);
    }
    const href = await detailHref(page);
    await installRecorder(page);
    await page.goto(href);
    await scrollToBottom(page);
    await expectAllRevealed(page);
  });
});

test.describe('scroll-reveal — mağaza sayfaları / azaltılmış hareket', () => {
  test.use({ viewport: { width: 1280, height: 820 }, reducedMotion: 'reduce' });

  test('hareket azaltmada hiçbir şey gizlenmez', async ({ page }) => {
    for (const path of [LIST, CATEGORY]) {
      await page.goto(path);
      const state = await page.evaluate(() => ({
        hasReveal: document.documentElement.classList.contains('has-reveal'),
        marked: document.querySelectorAll('[data-reveal]').length,
        hiddenText: Array.from(document.querySelectorAll('main h1, main p, main .product-grid > *'))
          .filter((el) => el.getClientRects().length)
          .filter((el) => parseFloat(getComputedStyle(el).opacity) < 1).length,
      }));
      expect(state.hasReveal).toBe(false);
      expect(state.marked).toBe(0);
      expect(state.hiddenText).toBe(0);
    }
  });
});

test.describe('scroll-reveal — mağaza sayfaları / JS kapalı', () => {
  test.use({ viewport: { width: 1280, height: 820 }, javaScriptEnabled: false });

  test('JS yoksa içerik gizlenmez (progressive enhancement)', async ({ page }) => {
    await page.goto(LIST);
    // Gizli başlangıç durumu `html.has-reveal`e bağlıdır; o sınıfı reveal-boot.js
    // ekler — JS yoksa ne sınıf ne işaretleme olur.
    await expect(page.locator('html')).not.toHaveClass(/has-reveal/);
    const h1 = page.locator('main > h1');
    await expect(h1).toBeVisible();
    expect((await h1.innerText()).length).toBeGreaterThan(0);
    const card = page.locator('.product-grid > *').first();
    if ((await card.count()) > 0) await expect(card).toBeVisible();
  });
});
