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

## SECRET_KEY_BASE rotasyonunun oturum etkisi

### Çift sırlı pencere (kullanıcı kaybı olmadan rotasyon)

`SECRET_KEY_BASE` değiştirilirken eski değeri 24–48 saat boyunca
`SECRET_KEY_BASE_PREVIOUS` olarak da tanımlayın. Pencere açıkken uygulama:

1. İmzalı `agency_session` çerezini current sır ile doğrulamayı dener.
2. Olmazsa previous sır ile dener; geçerliyse isteği current-era bağlantıyla
   işler ve **yanıt çerezini current sır ile yeniden damgalar** — tarayıcı
   ilk yanıtta yeni döneme taşınır (dönüş yolculuğu penceresiz çalışır).
3. Pencere kapatıldığında (env unset) eski imzalar yeniden reddedilir;
   pencere kalıcı bir gevşeme değildir.

Bu pencere yalnızca **imzalı çerez** katmanını kurtarır: kullanıcılar oturum
ve oturum-türevli CSRF token'larını korur, public anonim double-submit
akışı sırdan bağımsız olduğundan hiçbir zaman etkilenmez. Sırrın sızdığı
acil rotasyonda pencere yeterli değildir — eski sırrı yeniden başlatmayın ve
`tüm oturumları iptal edin` (aşağıya bakınız).

### Penceresiz acil rotasyon

`SECRET_KEY_BASE` tek başına değişirse imzalı çerezlerin tümü geçersizleşir:
kullanıcılar bir sonraki istekte anonim kalır ve yeniden giriş yapmalıdır.
Regresyon sözleşmesi: `test/router_test.gleam` altındaki `secret_rotation_*`
testleri (imzalı oturum + oturum-türevli CSRF reddi, anonim akışın
etkilenmemesi, yeni oturumun yeniden bağlanması, pencere migrasyonu +
yeniden damgalama + pencere kapandığında düşme).

## Rotasyon yaşı denetimi

`SECRET_KEY_BASE` (ve `NEXUS_CONFIG_KEY`) rotasyon tarihleri
`agency.secret_rotations` tablosunda tutulur
(db/migrations/238_secret_rotation_baseline.sql). Her rotasyonda:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/record-secret-rotation.ps1 -Name SECRET_KEY_BASE -Source planned
```

`scripts/check-secret-hygiene.ps1` son rotasyon yaşını bu tablodan hesaplar:

- Kayıt yok → **bilinmiyor** → hygiene hatası (fail-closed; kayıtsız sır
  denetlenemez). Mevcut sırrın devreye alınma tarihiyle baseline alın.
- Yaş, `-SecretKeyRotationMaxDays` (varsayılan 180 gün) üstündeyse →
  **overdue** → hygiene hatası (`-WarnOnly` ile uyarıya düşürülebilir).
- Yaş aralık içindeyse → kontrol geçer.

### 48 saatlik çift sırlı pencere denetimi

Pencere durumu artık veritabanında da izlenir
(db/migrations/247_secret_rotation_window.sql; platform karşılığı 187/188 —
çift yönlü sözleşme paritesi). `agency.secret_rotation_settings` tablosu sır
bazlı pencere süresini tutar (varsayılan 48 saat) ve owner tarafında
`SELECT agency.set_rotation_window('SECRET_KEY_BASE', 48);` ile
değiştirilebilir. `scripts/check-secret-hygiene.ps1` pencere durumunu da
denetler:

- `open` → pencere açık; `SECRET_KEY_BASE_PREVIOUS` env'deyse pencere
  içinde kaldırılmalıdır (bilgi mesajı).
- `expired` → pencere kapandı; `SECRET_KEY_BASE_PREVIOUS` hâlâ env'deyse
  hygiene hatası (kaldırın), kaldırılmışsa kontrol geçer.
- `unknown` → rotasyon kaydı yok; yaş denetimindeki fail-closed kuralı
  geçerlidir.

## Haftalık rotasyon bildirici (opsiyonel)

`scripts/notify-rotation-overdue.ps1`, pencere denetimini haftalık olarak
çalıştırıp aşım durumunda webhook/e-posta uyarısı üretir (platform'daki
aynı adlı betiğin acente aynası):

- Durum kaynağı `agency.rotation_window_state('SECRET_KEY_BASE')`
  (247 sözleşmesi; hygiene ile aynı kaynak).
- Çıkış sözleşmesi: `open` ve penceresi dolmuş + PREVIOUS kaldırılmış
  durumlar → 0; `expired` + PREVIOUS env'de, rotasyon yaşı
  `-SecretKeyRotationMaxDays` (varsayılan 180 gün) aşımı ve `unknown`
  (fail-closed) → 1; DB'ye erişilemezse → 2.
- Yaş kapısı pencere durumundan bağımsızdır ve önce değerlendirilir.
- Uyarı kanalları bağımsızdır: `-WebhookUrl` (Slack uyumlu POST) ve
  `-MailTo` + SMTP parametreleri (acente `.env`'sinde MAIL_* sözleşmesi
  yoktur; SMTP ayarları parametreyle verilir).
- Her koşum `.local/rotation-check.log` dosyasına yazılır.

Haftalık zamanlama (idempotent; kanal parametreleri görev argümanlarına
 gömülür, değiştirmek için yeniden çalıştırın):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/register-rotation-check-task.ps1 `
  -MailTo ops@acme.test -MailHost smtp.acme.test -MailFrom alerts@acme.test
```

Görev geçerli kullanıcı oturumunda çalışır; makine kapalı kaldığında kaçan
çalışma (StartWhenAvailable) sonraki açılışta telafi edilir.

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

