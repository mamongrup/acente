// SSR para birimi — gerçek tarayıcı testi.
//
// NEDEN: fiyatlar sunucuda `nexus_currency` çerezine göre render edilmeli
// (ilk boyama doğru, JS kapalıyken de). İstemci katmanı (main.js FX) aynı
// seçimi sayfa yenilemeden uygular; iki katman çakışırsa fiyat İKİ KEZ
// dönüştürülür. Bu paket:
//   1) JS'siz (ham HTTP) yanıtlarda fiyatların hedef para biriminde
//      basıldığını ve dönüşümün istemci kuralıyla birebir olduğunu ölçer,
//   2) detay sayfasında büyük fiyat + JSON-LD offer tutarlılığını doğrular,
//   3) gerçek tarayıcıda JS boot sonrası fiyatın DEĞİŞMEDİĞİNİ (çift dönüşüm
//      yok) ve istemci geçişinin doğru hesapladığını gösterir,
//   4) ana sayfadaki vitrin/demo kartlarının da (şablonun sıkı biçimi:
//      `₺2.800/gece`) sunucuda dönüştuğunu ve birim spanının korunduğunu
//      ölçer,
//   5) kapsam dışı sayfaların TRY çerezli yanıtla birebir aynı kaldığını
//      kanıtlar (`/iletisim`, gerçek TRY tahsilatı `/odeme/parampos`).
const { test, expect } = require('@playwright/test');

const PORT = process.env.APP_PORT || 8082;
const ORIGIN = `http://127.0.0.1:${PORT}`;
const LISTINGS = '/urunler';

// İstemci biçim kuralı (main.js FX.format) — beklenen metin buradan üretilir.
function formatMoney(value, symbol) {
  const n = value >= 1000 ? Math.round(value) : Math.round(value * 100) / 100;
  const str = n.toLocaleString('en-US', {
    minimumFractionDigits: n >= 1000 ? 0 : 2,
    maximumFractionDigits: n >= 1000 ? 0 : 2,
  });
  return symbol + ' ' + str;
}

// main.js FX.formatTry: sunucunun TRY biçimi (kuruş, ayraçsız)
function formatTry(minorText) {
  return '₺ ' + (Number(minorText) / 100).toFixed(2);
}

// Vitrin/demo kartı sıkı biçimi: simge tutara BİTİŞİK
// (ssr_currency.format_featured / main.js FX.formatCompact).
function formatCompact(value, symbol) {
  const n = value >= 1000 ? Math.round(value) : Math.round(value * 100) / 100;
  const str = n.toLocaleString('en-US', {
    minimumFractionDigits: n >= 1000 ? 0 : 2,
    maximumFractionDigits: n >= 1000 ? 0 : 2,
  });
  return symbol + str;
}

// Vitrin kartının TRY biçimi (main.js FX.formatTryCompact): Türkçe binlik
// ayracı '.', simge bitişik — `₺2.800`.
function formatTryCompact(minorText) {
  return '₺' + (Number(minorText) / 100).toLocaleString('tr-TR', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  });
}

// Ana sayfa vitrin kartları: kanonik tutar + basılan metin + birim soneki.
// Yapı: <span class="featured-card-price" …>₺2.800<span
// class="featured-card-price-unit">/gece</span></span> — metin ile birim
// ayrı düğümdedir, bu yüzden istemci yalnız metni değiştirebilir.
const FEATURED_RE =
  /class="featured-card-price"([^>]*)>([^<]*)<span class="featured-card-price-unit">([^<]*)</g;

function featuredCards(html) {
  const out = [];
  let m;
  FEATURED_RE.lastIndex = 0;
  while ((m = FEATURED_RE.exec(html)) !== null) {
    out.push({
      minor: (m[1].match(/data-price-minor="(\d+)"/) || [])[1],
      cur: (m[1].match(/data-price-cur="([A-Z]+)"/) || [])[1],
      text: m[2],
      unit: m[3],
    });
  }
  return out;
}

// Kanonik tutar taşıyan fiyat düğümleri ve hemen ardındaki fiyat metni.
// Öznitelik sırası derleyicinin kararı (cur/minor yer değiştirebilir), bu
// yüzden etiket sıra bağımsız ayrıştırılır.
const NODE_RE = /<(strong|div)([^>]*data-price-minor="\d+"[^>]*)>([^<]*)/g;

function priceNodes(html) {
  const out = [];
  let m;
  NODE_RE.lastIndex = 0;
  while ((m = NODE_RE.exec(html)) !== null) {
    const attrs = m[2];
    out.push({
      tag: m[1],
      minor: (attrs.match(/data-price-minor="(\d+)"/) || [])[1],
      cur: (attrs.match(/data-price-cur="([A-Z]+)"/) || [])[1],
      text: m[3],
    });
  }
  return out;
}

function cardPrices(html) {
  return priceNodes(html).filter((node) => node.tag === 'strong');
}

function detailPrice(html) {
  return priceNodes(html).find((node) => node.tag === 'div') || null;
}

async function getHtml(request, path, currency) {
  const res = await request.get(path, {
    headers: currency ? { cookie: `nexus_currency=${currency}` } : {},
  });
  return { status: res.status(), html: await res.text() };
}

test.describe('SSR para birimi', () => {
  let rates;

  test.beforeAll(async ({ request }) => {
    const res = await request.get('/api/public/rates');
    expect(res.ok()).toBeTruthy();
    const data = await res.json();
    rates = data.rates;
    expect(rates.USD && rates.USD.rate).toBeTruthy();
  });

  test('liste sayfası fiyatları sunucuda (JS yok) seçili para biriminde basılır', async ({
    request,
  }) => {
    const { html } = await getHtml(request, LISTINGS, 'USD');
    const prices = cardPrices(html);
    expect(prices.length).toBeGreaterThan(0);

    const symbols = new Set();
    prices.forEach((p) => {
      // Kanonik tutar korunur: TRY kuruş + ilanın para birimi
      expect(p.cur).toBe('TRY');
      const expected = formatMoney(Number(p.minor) / 100 / rates.USD.rate, rates.USD.symbol);
      expect(p.text, `kart ${p.minor} USD karşılığı`).toBe(expected);
      symbols.add(p.text.trim().charAt(0));
    });
    // Tüm fiyatlar hedef simgeyle basıldı (₺ kalmadı)
    expect([...symbols]).toEqual([rates.USD.symbol]);

    // Gövdede metin olarak basılmış TRY fiyatı kalmadı
    expect(/>₺ \d/.test(html)).toBe(false);
  });

  test('TRY çereziyle çıktı değişmez (sunucunun kendi biçimi korunur)', async ({ request }) => {
    const withCookie = await getHtml(request, LISTINGS, 'TRY');
    const withoutCookie = await getHtml(request, LISTINGS);
    expect(withCookie.html).toBe(withoutCookie.html);
    const prices = cardPrices(withCookie.html);
    expect(prices.length).toBeGreaterThan(0);
    prices.forEach((p) => {
      expect(p.text).toBe(formatTry(p.minor));
    });
  });

  test('detay sayfası: büyük fiyat ve JSON-LD offer tutarlı dönüşülür', async ({ request }) => {
    const tryPage = await getHtml(request, LISTINGS, 'TRY');
    const link = tryPage.html.match(/\/urunler\/([0-9a-f-]{36})/);
    expect(link).toBeTruthy();
    const path = `/urunler/${link[1]}`;

    const tryDetail = detailPrice((await getHtml(request, path, 'TRY')).html);
    const usdDetail = detailPrice((await getHtml(request, path, 'USD')).html);
    expect(tryDetail).toBeTruthy();
    expect(usdDetail).toBeTruthy();
    // Kanonik tutar iki yanıtta aynı (dönüşüm gösterim katmanında)
    expect(usdDetail.minor).toBe(tryDetail.minor);
    expect(usdDetail.cur).toBe('TRY');
    expect(tryDetail.text).toBe(formatTry(tryDetail.minor));

    const amount = Number(usdDetail.minor) / 100;
    const converted = amount / rates.USD.rate;
    expect(usdDetail.text).toBe(formatMoney(converted, rates.USD.symbol));

    // JSON-LD: görünür fiyatla aynı para birimi ve tutar (2 ondalık)
    const usd = await getHtml(request, path, 'USD');
    expect(usd.html).toContain(
      `"priceCurrency":"USD","price":${Math.round(converted * 100) / 100}`,
    );

    // Detay sayfasında metin olarak TRY fiyatı kalmadı, kanonik tutar duruyor
    expect(/>₺ \d/.test(usd.html)).toBe(false);
    expect(usd.html).toContain(`data-price-minor="${usdDetail.minor}"`);

    // Rezervasyon sayfası da aynı ilan fiyatını seçili para biriminde basar
    const bookingTry = await getHtml(request, `/rezervasyon?listing=${link[1]}`, 'TRY');
    const booking = await getHtml(request, `/rezervasyon?listing=${link[1]}`, 'USD');
    const bookingNodes = priceNodes(bookingTry.html);
    expect(bookingNodes.length).toBe(1);
    expect(bookingNodes[0].cur).toBe('TRY');
    expect(bookingNodes[0].text).toBe(formatTry(bookingNodes[0].minor));
    expect(booking.html).toContain(
      formatMoney(Number(bookingNodes[0].minor) / 100 / rates.USD.rate, rates.USD.symbol),
    );
    expect(/>₺ \d/.test(booking.html)).toBe(false);
  });

  test('gerçek tarayıcı: JS boot fiyatı değiştirmez, geçiş doğru hesaplanır', async ({
    page,
    context,
    request,
  }) => {
    await context.addCookies([{ name: 'nexus_currency', value: 'USD', url: ORIGIN }]);
    const ssr = cardPrices((await getHtml(request, LISTINGS, 'USD')).html);
    const expected = ssr.map((p) => formatMoney(Number(p.minor) / 100 / rates.USD.rate, rates.USD.symbol));

    await page.goto(LISTINGS);
    // İstemci katmanı fiyatları yeniden yazar; sonuç SSR metniyle AYNI olmalı
    await expect
      .poll(async () => page.$$eval('.card-price strong', (els) => els.map((e) => e.textContent)))
      .toEqual(expected);

    const net = await fetchRates(page);
    expect(net.USD.rate).toBeCloseTo(rates.USD.rate, 4);

    // JPY benzeri hedef değil, kayıtlı kurlarla EUR'a geçiş
    await page.evaluate(() => window.NEXUS_LOCALE.applyCurrency('EUR'));
    const eurExpected = ssr.map((p) =>
      formatMoney(Number(p.minor) / 100 / net.EUR.rate, net.EUR.symbol),
    );
    await expect
      .poll(async () => page.$$eval('.card-price strong', (els) => els.map((e) => e.textContent)))
      .toEqual(eurExpected);

    // TRY'ye dönüş: sunucunun TRY biçimi (kuruş, ayraçsız) geri yazılır
    await page.evaluate(() => window.NEXUS_LOCALE.applyCurrency('TRY'));
    const tryExpected = ssr.map((p) => formatTry(p.minor));
    await expect
      .poll(async () => page.$$eval('.card-price strong', (els) => els.map((e) => e.textContent)))
      .toEqual(tryExpected);

    // Misafir seçimi çereze yazılır (SSR sonraki yüklemede onu kullanır)
    await page.evaluate(() => window.NEXUS_LOCALE.applyCurrency('GBP'));
    const cookie = await page.evaluate(() => document.cookie);
    expect(cookie).toContain('nexus_currency=GBP');

    const afterReload = await getHtml(request, LISTINGS, 'GBP');
    expect(afterReload.html).toContain(rates.GBP.symbol + ' ');
    expect(/>₺ \d/.test(afterReload.html)).toBe(false);
  });

  test('ana sayfa vitrin kartları sunucuda (JS yok) seçili para biriminde basılır', async ({
    request,
  }) => {
    const tryHtml = (await getHtml(request, '/', 'TRY')).html;
    const usdHtml = (await getHtml(request, '/', 'USD')).html;

    const trCards = featuredCards(tryHtml);
    const usdCards = featuredCards(usdHtml);
    expect(trCards.length).toBeGreaterThan(0);
    expect(usdCards.length).toBe(trCards.length);

    trCards.forEach((card, i) => {
      const usd = usdCards[i];
      // Kanonik tutar iki yanıtta aynı (dönüşüm yalnız gösterim katmanında)
      expect(usd.minor).toBe(card.minor);
      expect(usd.cur).toBe('TRY');

      // TRY: şablonun kendi sıkı biçimi (binlik '.')
      expect(card.text, `kart ${card.minor} TRY metni`).toBe(formatTryCompact(card.minor));
      // Hedef para birimi: istemci kuralıyla birebir (kuruş ayracı ',')
      const converted = Number(card.minor) / 100 / rates.USD.rate;
      expect(usd.text, `kart ${card.minor} USD metni`).toBe(
        formatCompact(converted, rates.USD.symbol),
      );
      // Birim soneki dönüşümden etkilenmez
      expect(usd.unit).toBe(card.unit);
      expect(card.unit).toBeTruthy();
    });

    // Dönüşen tutar TRY metnini bırakmaz; TRY yanıtında sıkı biçim vardır
    expect(/>₺\d/.test(tryHtml)).toBe(true);
    expect(/>₺\d/.test(usdHtml)).toBe(false);
  });

  test('kapsam dışı sayfalar TRY çerezli yanıtla aynı kalır', async ({ request }) => {
    for (const path of ['/iletisim', '/odeme/parampos']) {
      const usd = await getHtml(request, path, 'USD');
      const tryRes = await getHtml(request, path, 'TRY');
      expect(usd.status).toBe(tryRes.status);
      // İstek başına değişen CSRF jetonu dışında gövde birebir aynı olmalı:
      // bu sayfalar kapsam dışı olduğu için fiyat geçişi dokunmaz.
      expect(stable(usd.html), `${path} kapsam dışı olmalı`).toBe(stable(tryRes.html));
    }
  });
});

// İstek başına değişen alanlar ayrıştırılarak gövde karşılaştırılabilir
// hâle getirilir. Üçü de her istekte yeniden üretilir:
//   - <meta content="…" name="csrf-token">
//   - <input name="csrf_token" … value="…">
//   - <input name="idempotency_key" … value="…">
function stable(html) {
  return html
    .replace(/content="[^"]*" name="csrf-token"/g, 'name="csrf-token"')
    .replace(
      /(name="(?:csrf_token|idempotency_key)"[^>]*?value=")[^"]*(")/g,
      '$1$2',
    );
}

// Tarayıcıdaki kur tablosunu (istemci katmanının kullandığı) okur.
async function fetchRates(page) {
  return page.evaluate(async () => {
    const res = await fetch('/api/public/rates', { cache: 'no-store' });
    const data = await res.json();
    return data.rates;
  });
}
