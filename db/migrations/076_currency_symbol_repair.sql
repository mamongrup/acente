-- Para birimi simgeleri: SAR kaydı yer tutucu '?' ile gelmiş (veri hatası).
-- Vitrin fiyatları simgeyi agency.currencies.symbol'den basar (SSR fiyat
-- dönüşümü + /api/public/rates), bu yüzden bozuk simge doğrudan kullanıcıya
-- "? 1,234" olarak yansıyordu.
--
-- Uygulama tarafında da (Gleam ssr_currency.display_symbol, main.js FX.format)
-- boş/`?` simge için derleme içi yedek tablo vardır; bu migration veri
-- kaynağını düzeltir.
UPDATE agency.currencies
SET symbol = '﷼'
WHERE code = 'SAR'
  AND (symbol IS NULL OR trim(symbol) IN ('', '?'));
