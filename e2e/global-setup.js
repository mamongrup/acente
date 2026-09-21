// Test öncesi iki kapı: (1) sunucu erişilebilir mi, (2) gerçek tarayıcı
// başlatılabiliyor mu?
//
// Testler önizleme webview'ine bağlı DEĞİLDİR; yalnızca HTTP üzerinden sunucuya
// ve sistemde kurulu Chromium/Edge ikilisine dayanır. Her iki kapı da
// başarısız olduğunda Playwright'ın anlaşılmaz "ECONNREFUSED" /
// "Executable doesn't exist" hataları yerine ne yapılacağını söyleyen bir
// mesaj üretir.
const { request, chromium } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL || `http://127.0.0.1:${process.env.APP_PORT || 8082}`;
const CHANNEL = process.env.PW_CHANNEL || 'msedge';

async function assertServerReachable() {
  const ctx = await request.newContext();
  try {
    // Bağımsız istek bağlamında baseURL yok — tam URL gerekir.
    const res = await ctx.get(`${BASE_URL}/`, { timeout: 5_000 });
    if (!res.ok()) throw new Error(`HTTP ${res.status()}`);
  } catch (err) {
    throw new Error(
      [
        `Sunucuya ulaşılamadı: ${BASE_URL} (${err.message})`,
        '',
        'e2e testleri çalışan bir sunucu bekler. Başlatmak için:',
        '  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\run-dev.ps1',
        'Farklı port için: BASE_URL=http://127.0.0.1:<port> npm run test:e2e',
      ].join('\n'),
    );
  } finally {
    await ctx.dispose();
  }
}

async function assertBrowserLaunchable() {
  let browser;
  try {
    browser = await chromium.launch({
      channel: CHANNEL,
      executablePath: process.env.PW_EXECUTABLE_PATH || undefined,
    });
  } catch (err) {
    throw new Error(
      [
        `Tarayıcı başlatılamadı (channel: ${CHANNEL}) — ${err.message.split('\n')[0]}`,
        '',
        'Bu testler GERÇEK bir tarayıcı motoru gerektirir (önizleme webview’i',
        'animasyonları oynatmadığı için kullanılamaz). Seçenekler:',
        '  1) Sistemde kurulu tarayıcıyı seçin:  PW_CHANNEL=chrome npm run test:e2e',
        '  2) Tarayıcı ikilisini indirin:      npx playwright install chromium',
        '  3) Tam yol verin:                   PW_EXECUTABLE_PATH="C:\\...\\chrome.exe" npm run test:e2e',
      ].join('\n'),
    );
  } finally {
    if (browser) await browser.close();
  }
}

module.exports = async () => {
  await assertServerReachable();
  await assertBrowserLaunchable();
};
