# Secret rotation planı

Bu plan production ortamındaki kritik sırların güvenli biçimde yenilenmesi için uygulanır. Amaç; ParamPOS, NEXUS bağlantısı, oturum imzası ve veritabanı sırlarının düz metne düşmeden değiştirilebilmesi ve eski anahtarların kontrollü biçimde devreden çıkarılmasıdır.

## Kapsam

- `SECRET_KEY_BASE`
- `NEXUS_CONFIG_KEY`
- `PARAMPOS_CLIENT_CODE`
- `PARAMPOS_CLIENT_USERNAME`
- `PARAMPOS_CLIENT_PASSWORD`
- `PARAMPOS_GUID`
- `PGPASSWORD`
- NEXUS entegrasyon API anahtarları
- Diğer ödeme, SMS, e-posta, AI ve üçüncü taraf servis anahtarları

## Rotation sırası

1. Yeni secret üret.
2. Yeni secret’ı yalnızca yetkili secret store veya production `.env` yönetim alanına yaz.
3. Uygulama tarafında secret hygiene kontrolünü çalıştır.
4. Yeni secret ile smoke test yap.
5. Eski secret’ı sağlayıcı panelinden devre dışı bırak.
6. Audit log ve provider panelinden beklenmeyen başarısız giriş/işlem var mı kontrol et.
7. Rotation tarihini operasyon notuna işle.

## Lokal doğrulama

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-secret-hygiene.ps1
powershell -ExecutionPolicy Bypass -File scripts/check-production-gates.ps1 -EnvPath .env.production
```

## ParamPOS özel notları

- Kart numarası, CVV veya ödeme formundan gelen hassas kart verisi veritabanına yazılmaz.
- ParamPOS credential değerleri loglara, audit metadata içine veya frontend payload’larına eklenmez.
- ParamPOS production’a geçmeden önce `.env.production` üzerinde production gate çalıştırılır.
- Test credential’ları production ortamında kullanılmaz.

## NEXUS API anahtarı özel notları

- NEXUS bağlantı anahtarları DB’de sealed/saklı formatta tutulur.
- Düz metin anahtar admin panelinde tekrar gösterilmez.
- Rotation sonrasında `/admin/sync` ekranında bağlantı, son başarılı sync ve başarısız iş kartları kontrol edilir.

## Acil rotation

Aşağıdaki durumlardan biri varsa beklemeden rotation yapılır:

- Secret yanlışlıkla log, terminal çıktısı, issue, mail veya dokümana yazıldıysa.
- Üçüncü taraf sağlayıcı “credential compromised” uyarısı verdiyse.
- Yetkisiz admin, sunucu veya repo erişimi şüphesi varsa.
- Production gate ya da secret hygiene kontrolü düz metin veya zayıf secret bulduysa.

