// Gerçek tarayıcı (Playwright) yapılandırması.
//
// NEDEN: Önizleme webview'i CSS animasyon/transition'larını hiç oynatmıyor —
// `element.getAnimations()` orada boş dönüyor, bu yüzden kademeli (stagger)
// giriş animasyonu webview'de gözlemlenemiyor. Bu paket gerçek Chromium/Edge
// motoruyla çalışır ve animasyonu **Animation API + computed style** üzerinden
// ölçer; ekran görüntüsü/piksel farkına bağlı olmadığı için kısıtlı ortamlarda
// da yanıltıcı sonuç üretmez.
//
// TARAYICI İNDİRİLMEZ: sistemde kurulu Edge/Chrome `channel` ile kullanılır.
//   PW_CHANNEL=msedge (varsayılan) | chrome | chromium
//   PW_EXECUTABLE_PATH=... ile tam yol da verilebilir.
// Hiçbiri yoksa: npx playwright install chromium
const { defineConfig } = require('@playwright/test');

const PORT = process.env.APP_PORT || 8082;
const BASE_URL = process.env.BASE_URL || `http://127.0.0.1:${PORT}`;

module.exports = defineConfig({
  testDir: './e2e',
  timeout: 30_000,
  expect: { timeout: 8_000 },
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  reporter: [['list']],
  globalSetup: require.resolve('./e2e/global-setup.js'),
  globalTeardown: require.resolve('./e2e/global-teardown.js'),
  use: {
    baseURL: BASE_URL,
    channel: process.env.PW_CHANNEL || 'msedge',
    executablePath: process.env.PW_EXECUTABLE_PATH || undefined,
    // ÖLÇÜM DETERMİNİZMİ: uygulama `prefers-reduced-motion: reduce` altında
    // animasyonları kapatıyor. Animasyonu ölçen projeler no-preference ile
    // çalışır; reduced-motion sözleşmesi ayrı testte doğrulanır.
    reducedMotion: 'no-preference',
    viewport: { width: 1280, height: 820 },
    trace: 'retain-on-failure',
  },
});
