# ParamPOS canlıya geçiş checklist

Bu checklist production deploy öncesinde ve ParamPOS credential değişikliklerinden sonra çalıştırılır.

## Zorunlu teknik kontroller

1. Production ortamında `APP_ENV=production` olmalıdır.
2. `APP_ORIGIN` gerçek public HTTPS domain olmalıdır.
3. ParamPOS endpoint yalnızca şu alan adlarından biri olmalıdır:
   - `https://testposws.param.com.tr`
   - `https://posws.param.com.tr`
4. Local SOAP fixture endpointleri (`http://127.0.0.1:*`, `http://localhost:*`) yalnızca production dışı ortamda kabul edilir.
5. ParamPOS terminal kodu, kullanıcı adı, parola ve GUID sealed saklanmalıdır.
6. Kart numarası, CVV/CVC veya PAN saklayan DB kolonu bulunmamalıdır.
7. `scripts/check-secret-hygiene.ps1` sıfır açık bulmalıdır.

## Zorunlu akış testleri

Tek komut:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-parampos.ps1
```

Bu testler şunları doğrular:

- lifecycle migration tekrar çalıştırılabilir;
- checkout idempotency aynı payload için aynı order/session döndürür;
- farklı payload aynı idempotency key ile reddedilir;
- 3D start duplicate istekleri yeni tahsilat başlatmaz;
- başarısız 3D rezervasyonu onaylamaz;
- süresi dolmuş callback charge yapmaz;
- başarılı callback order ve reservation kaydını idempotent biçimde onaylar;
- üç 3D denemesinde yalnızca bir gerçek pay çağrısı oluşur.

## Canlı işlem sonrası kontrol

1. ParamPOS panelinde işlem tutarı ile `agency.orders.total_minor` eşleşmelidir.
2. `agency.payments.status='paid'` yalnızca provider başarılı sonuç döndürdüyse oluşmalıdır.
3. Aynı provider callback tekrar geldiğinde ikinci tahsilat veya ikinci reservation confirmation oluşmamalıdır.
4. Audit kaydı ve ödeme logları müşteri kart verisi içermemelidir.
