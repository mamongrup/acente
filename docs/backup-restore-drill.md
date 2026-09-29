# Backup / restore drill

Bu doküman acente veritabanının düzenli yedeklenmesi ve yedeğin gerçekten geri döndürülebilir olduğunun test edilmesi için kullanılır.

## Yedek alma

```powershell
powershell -ExecutionPolicy Bypass -File scripts/backup-restore-drill.ps1
```

Varsayılan olarak dump dosyası `.local/backups` altına yazılır. Bu klasör lokal operasyon çıktısıdır; repo’ya commit edilmemelidir.

## Restore testi

```powershell
powershell -ExecutionPolicy Bypass -File scripts/backup-restore-drill.ps1 -RestoreTest
```

Uygulama veritabanı kullanıcısında `CREATEDB` yetkisi yoksa, bu güvenli ve beklenen bir durumdur. Restore drill için bakım yetkili kullanıcı verilir:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/backup-restore-drill.ps1 -RestoreTest -MaintenanceUser postgres
```

Bu komut:

1. Mevcut veritabanından `pg_dump -Fc` ile dump üretir.
2. Geçici bir restore veritabanı oluşturur.
3. Dump’ı geçici veritabanına geri yükler.
4. `agency.tenants` üzerinden temel doğrulama sorgusu çalıştırır.
5. Geçici veritabanını siler.

## Sıklık

- Production öncesi: zorunlu
- Büyük migration öncesi: zorunlu
- Büyük migration sonrası: zorunlu
- Production ortamında: en az haftalık restore drill

## Başarısızlık durumunda

- Migration veya release durdurulur.
- Son başarılı dump dosyası ve restore hata çıktısı saklanır.
- `docs/security-audit-2026-09-23.md` veya güncel operasyon raporuna olay notu eklenir.
- Restore doğrulanmadan production değişikliği yapılmaz.
