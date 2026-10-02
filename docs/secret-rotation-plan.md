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

### Karar tablosu tek kaynakta (migration 271)

Dört karar senaryosu artık betiğin `switch`'i yerine
`agency.rotation_check_decision(state, age_hours, max_days,
previous_present)` fonksiyonunda yasar ve betik **bu fonksiyonu çağırır**.
Platform aynı tabloyu `events.rotation_check_decision` adıyla migration
192'de yazdı; iki projenin govdesi birebir aynıdır, yalnızca şema adı
farklıdır (`agency` ↔ `events`).

Dönen üçlü `(exit_code, severity, alert_kind)`:

| `alert_kind` | Karar |
|---|---|
| `none` | pencere açık, ya da doldu ama PREVIOUS kaldırılmış → çıkış 0 |
| `overdue` | yaş sınırı aşıldı (varsayılan 180 gün) → çıkış 1 |
| `window_expired_previous_present` | pencere doldu **ve** PREVIOUS hâlâ `.env`'de → çıkış 1 |
| `no_record` | kayıt yok (fail-closed) → çıkış 1 |
| `unexpected_state` | beklenmeyen/NULL durum → çıkış 2, uyarı yok |

Yaş kapısı (`overdue`) pencere durumundan **bağımsız ve önceliklidir**;
sıra platform muadiliyle ve eski betikle aynıdır.

### İki proje parite denetimi

`scripts/check-rotation-notify-parity.mjs` iki deponun betiğini
karşılaştırır: parametre adı/tipi/varsayılanı/**sırası**, karar
senaryoları, alarm kanalları, günlük yaş sınırı, çıkış dosyası ve karar
tablosu DB fonksiyonunun varlığı. Fark varsa stderr'e yazıp exit 1 verir
(AGENTS.md: sözleşme değişikliği tek taraflı olamaz).

Aynı denetim **pencere şemasını** da karşılaştırır — acente
`247_secret_rotation_window.sql` ↔ platform `187_secret_rotation_window.sql`:

- 4 fonksiyonun **imzası**: parametre tipleri, dönüş tipi ve
  **volatility** (`STABLE`/`VOLATILE`/`IMMUTABLE`). Aynı imza farklı
  volatility ile farklı plan/yanlış sonuç üretebilir.
- **Parametre adları**: çağıran taraflar named notation'a geçerse veya
  dokümantasyonlar birlikte güncellenmezse ayrılma olur.
- **Varsayılan pencere** (48 saat) ve seed edilen sır pencereleri
  (`SECRET_KEY_BASE`, `SECRET_KEY_BASE_PREVIOUS`).
- **Durum enum'u**: yalnız `unknown` / `open` / `expired`. Yeni bir durum
  tek tarafta eklenirse betiğin `switch`'i diğer projede eşleşmez.
- **CHECK kısıtı** (`window_hours` aralığı) ve `set_rotation_window`
  reddedilen aralık (fail-closed).

Migration dosyası numara **ve içerik** ile seçilir: numaralar tekrarlanabilir
(acente'de 247 iki dosyada kullanılır — `migrate.ps1` bunu zaten preflight
uyarısıyla bildirir ve `version` tam dosya adı olduğu için güvenlidir).

### NEXUS_CONFIG_KEY penceresi (sürümlü genişletme)

`247` yalnız iki sır seed'liyordu (`SECRET_KEY_BASE`,
`SECRET_KEY_BASE_PREVIOUS`); `NEXUS_CONFIG_KEY` satırsız kalıp varsayılan
değere (48 saat) düşüyordu. Pencere artık **açıkça yazılıdır**:

| migration | dosya |
|---|---|
| platform | `db/migrations/193_rotation_window_config_key.sql` |
| acente | `db/migrations/272_rotation_window_config_key.sql` |

`187`/`247` **değiştirilmez** (checksum korunur); genişletme yeni migration'da
gelir. `ON CONFLICT DO NOTHING` ile operatörün `set_rotation_window` ile
değiştirdiği mevcut ayar asla ezilmez.

**Kapsam: bu sır enformatiftir.** Ayarları şifreleyen üst anahtardır ve
kayıpsız değiştirilemez (`config-key.ps1` / `seal-legacy-secrets.ps1`
şifreli kayıt varken anahtarı yeniden üretmez). Dolayısıyla:

- **PREVIOUS karşılığı yoktur** — `expired` durumunda kaldırılacak bir değer
  bulunmaz.
- **Yaş kapısı (overdue) geçerlidir** ve uyarı üretir: anahtarın ne kadar
  süredir değiştirilmediği izlenir.
- **`expired` yalnızca raporlanır**, zorlama uygulanmaz.

Bu ayrım `record-secret-rotation.ps1` ve `notify-rotation-overdue.ps1`'nin
`NEXUS_CONFIG_KEY` metniyle tutarlıdır.

```powershell
node scripts/check-rotation-notify-parity.mjs
# veya iki proje kapısı içinde:
powershell -ExecutionPolicy Bypass -File scripts/check-two-project-contracts.ps1
```

Platform deposu hazır değilse (CI yalnızca acente'yi checkout eder)
denetim **atlanır** ve exit 0 verir — acente bağımsız çalışmaya devam
eder; tam denetim iki depo birlikte hazır olduğunda çalışır.

### Canlı karar matrisi (davranışsal parite)

Metin ve şema karşılaştırması tek başına yetersizdir: iki migration dosyası
aynı görünse de karar tablosunun **gövdesi** tek tarafta değiştirilmiş
olabilir ve iki proje aynı girdide farklı karar verir. Bu yüzden denetim
ikinci bir seviyede daha çalışır:

İki veritabanı **aynı senaryo matrisinden** koşulur ve
`(exit_code, severity, alert_kind)` üçlüleri karşılaştırılır. 14 senaryo:

| senaryo | beklenen |
|---|---|
| `open` (± PREVIOUS) | `0｜ok｜none` |
| `expired` + PREVIOUS var | `1｜warn｜window_expired_previous_present` |
| `expired` + PREVIOUS yok | `0｜ok｜none` |
| `unknown` (± PREVIOUS) — **fail-closed** | `1｜warn｜no_record` |
| 179 gün (eşik altı) | `1｜warn｜window_expired_previous_present` |
| 180 gün (eşik tam) — `>` kuralı | `1｜warn｜window_expired_previous_present` |
| 181 gün (eşik üstü) | `1｜warn｜overdue` |
| `overdue` + `open` durumu — **yaş kapısı öncelikli** | `1｜warn｜overdue` |
| beklenmeyen durum / NULL durum — **fail-closed** | `2｜error｜unexpected_state` |
| NULL eşik — yaş kapısı atlanır | `0｜ok｜none` |

Her senaryo **iki yönde** denetlenir: iki proje birbirine eşit olmalı
(parite) **ve** ikisi de sözleşmenin normaline uymalı — ikisi birlikte
yanlış olsa bile sapma sessizce geçmez. Ayrıca `alert_kind → exit kodu`
eşlemesi açıkça sabitlenir (`none→0`, `overdue`/`no_record`/
`window_expired_previous_present`→`1`, `unexpected_state→2`).

Her proje kendi kimliğiyle bağlanır: acente `agency_app`, platform
`nexus_owner`.

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

