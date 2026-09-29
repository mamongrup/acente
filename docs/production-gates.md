# Production gates

Bu proje şu an varsayılan olarak local development modunda çalışacak şekilde korunur. Production açmadan önce aşağıdaki kapılar sağlanmalıdır.

## Zorunlu kontroller

- `APP_ENV=production`
- `APP_ORIGIN` gerçek public domain olmalı ve `https://` ile başlamalıdır.
- `SECRET_KEY_BASE` en az 64 karakterlik rastgele değer olmalıdır.
- `NEXUS_CONFIG_KEY` en az 64 karakterlik rastgele değer olmalıdır.
- PostgreSQL bağlantı bilgileri açıkça tanımlı olmalıdır: `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`.
- NEXUS entegrasyonu kullanılacaksa `NEXUS_API_ORIGIN` production ortamında `https://` olmalı ve localhost olmamalıdır.
- `TRUSTED_PROXY_SECURE_COOKIES=true` olmalıdır. Bu bayrak, production ortamında reverse proxy/TLS arkasında cookie güvenlik davranışının bilinçli açıldığını gösterir.
- `EDGE_RATE_LIMIT_ENABLED=true` olmalıdır. Bu bayrak, uygulama içi limitlere ek olarak reverse proxy/WAF/edge katmanında dağıtık rate-limit kurallarının aktif edildiğini gösterir.
- TLS/HSTS/reverse proxy yapılandırması uygulama önünde tamamlanmış olmalıdır.
- Secret rotation planı olmadan production secret değiştirilmemelidir; sealed kayıtlar `NEXUS_CONFIG_KEY` ile açılır.

## Local secret hazırlığı

Local ortamda eksik veya kısa secret değerlerini üretmek için:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ensure-local-secrets.ps1
```

Bu script secret değerlerini ekrana yazdırmaz.

## Production gate kontrolü

Production için env kontrolü:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-production-gates.ps1
```

`APP_ENV=development` iken script sadece production kontrollerinin atlandığını bildirir. `APP_ENV=production` olduğunda eksik veya güvensiz ayarlar hata olarak döner.

## Tek komut release readiness kontrolü

 Build, runtime health, secret hygiene, legacy cleanup, worker hygiene, audit retention smoke, rezervasyon kuyruğu, NEXUS callback flow, iki proje sözleşme kontrolü, ParamPOS testleri ve NEXUS REST smoke testini tek seferde çalıştırmak için:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-release-readiness.ps1
```

Production env kapılarını da zorlamak için:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-release-readiness.ps1 -Production
```

Harici servis veya fixture hazır değilse geçici olarak `-SkipParampos`, `-SkipNexusRest`, `-SkipTwoProjectContracts` veya yalnızca tarayıcı bağımlılığı kurulmamış ortamlarda `-SkipBrowser` kullanılabilir. Production deploy öncesinde bu skip bayrakları kullanılmamalıdır.

## Migration bütünlüğü

Migration dosyaları `system.schema_migrations` tablosunda SHA-256 checksum ile izlenir. Uygulanmış bir migration dosyası değiştirilmişse normal migration koşumu bilinçli olarak durur. Sadece değişikliğin kasıtlı olduğu incelendikten sonra:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/rebaseline-migration.ps1 `
  -MigrationName 073_parampos_lifecycle -ConfirmIntentional
```

Bu işlem migration'ı yeniden çalıştırmaz; yalnızca incelenmiş dosyanın yeni checksum'ını kaydeder.

## Kritik storefront tarayıcı kontrolü

Bu kontrol yalnızca migration'ları uygulanmış yerel PostgreSQL ile çalışan acente
sunucusunu bekler. `.env` veritabanı bağlantısını sağlamalıdır; test kurulumu kendi
tenant ve yayınlanmış otel ilanı fixture'ını idempotent olarak oluşturur ve test
sonunda kaldırır.

Ana sayfa, kategori ve ilan detay sayfalarının ortak header/footer/main sözleşmesini ve `x-request-id` başlığını Playwright ile doğrulamak için:

```powershell
npm run test:e2e -- --grep "critical page contract"
```

Bu üç sayfadan biri 500 dönerse, ortak layout eksikse veya request correlation header kaybolursa release kabul edilmemelidir.

## Runtime sağlık kontrolü

Local veya deployment sonrası temel servis sağlığını kontrol etmek için:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-runtime-health.ps1
```

Bu kontrol PostgreSQL portunu, uygulama portunu, ana sayfayı ve `/api/public/rates` endpoint'ini doğrular.

## Secret hygiene kontrolü

ParamPOS, SMTP, Netgsm, sosyal medya, AI ve NEXUS benzeri entegrasyonlarda düz metin secret kalmadığını ve ödeme kartı saklama kolonu bulunmadığını kontrol etmek için:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-secret-hygiene.ps1
```

Bu kontrol production deploy öncesinde production gate ve runtime health ile birlikte çalıştırılmalıdır.

## Secret rotation

Production secret değişimleri `docs/secret-rotation-plan.md` planına göre yapılmalıdır. ParamPOS ve NEXUS credential değerleri hiçbir koşulda log, audit metadata veya frontend payload içine yazılmaz.

## Backup / restore drill

Production değişikliği veya büyük migration öncesinde yedek alınmalı ve restore testi yapılmalıdır:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/backup-restore-drill.ps1 -RestoreTest
```

Uygulama DB kullanıcısında `CREATEDB` yetkisi yoksa restore drill bakım kullanıcısı ile çalıştırılır: `-MaintenanceUser postgres` veya ortamınıza ait bakım rolü.

Restore testi başarılı olmadan production migration veya release yapılmamalıdır. Detaylı prosedür `docs/backup-restore-drill.md` içindedir.

## Audit retention

Audit kayıtları uzun süreli saklama için arşiv tablosuna taşınabilir. Varsayılan politika 365 günden eski kayıtları arşivler:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-audit-retention.ps1
```

Kural olarak retention süresi 30 günden kısa olamaz. Production'da bu script günlük veya haftalık zamanlanmış görev olarak çalıştırılmalıdır.

## CI release readiness

`.github/workflows/release-readiness.yml` workflow'u push ve pull request sırasında build, Gleam testleri, PowerShell script parse kontrolleri ve production gate negatif smoke testini çalıştırır. Lokal DB/NEXUS gerektiren tam readiness kontrolü hâlâ deployment öncesinde operatör tarafından çalıştırılmalıdır.
