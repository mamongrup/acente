# NEXUS Travel Tech / Acente güvenlik ve entegrasyon kontrolü

Tarih: 2026-09-23

Kapsam:

- `C:\laragon\www\acente`
- `C:\laragon\www\Nexustraveltech`

## Bu kontrolde uygulanan hızlı düzeltmeler

1. Acente HTTP yanıtlarına temel güvenlik header'ları eklendi:
   - `X-Content-Type-Options: nosniff`
   - `X-Frame-Options: SAMEORIGIN`
   - `Referrer-Policy: same-origin`
   - `Permissions-Policy`
   - temel CSP
2. Acente kur güncelleme worker'ında TCMB'den gelen kur değeri SQL'e yazılmadan önce numeric formatla doğrulanır hale getirildi.
3. Mevcut testler tekrar çalıştırıldı:
   - Acente: `273 passed, no failures`
   - NEXUS: `15 passed, no failures`
   - İki proje sözleşme kontrolü: başarılı
4. NEXUS tarafındaki bilinen `password123` demo platform alt kullanıcıları pasiflenir hale getirildi.
   - Eski seed migration artık bu hesapları aktif ve bilinen şifreli oluşturmuyor.
   - Mevcut kurulu veritabanları için `151_disable_known_demo_password_accounts.sql` migration'ı eklendi.
5. Acente bağımsız çalışma başlangıç uyarıları temizlendi.
   - NEXUS API kapalıyken acente artık tek satırla standalone moda geçtiğini bildiriyor; tekrar eden rezervasyon/listing sync uyarısı üretmiyor.
   - NEXUS HTTP çağrısına girmeden önce kısa TCP erişilebilirlik kontrolü eklendi; lokal NEXUS kapalıyken `INFO reason=Econnrefused at=Connecting` log gürültüsü kesildi.
   - Framework bilgi seviyesi socket logları production/dev başlangıç logunu kirletmemesi için `warning` seviyesine çekildi.
   - E-posta kuyruğu worker'ında geçici `ConnectionUnavailable` durumu tekrar eden alarm olarak basılmıyor; worker sessizce yeniden denemeye devam ediyor.
6. Genel kur API'si daha dayanıklı hale getirildi.
   - `GET /api/public/rates` DB/kur tablosu geçici erişilemezse 500 yerine TRY tabanlı güvenli fallback JSON'u döndürüyor.
   - Local kontrolde acente PostgreSQL cluster'ı tekrar başlatıldı ve `/api/public/rates` ile ana sayfa 200 doğrulandı.
7. Local servis sağlık kontrolü eklendi.
   - `scripts/run-server.ps1`, acente `.env` içindeki PostgreSQL host/port değerini başlangıçta kontrol ediyor.
   - Local `127.0.0.1` / `localhost` acente cluster'ı kapalıysa `C:\laragon\data\postgresql` üzerinden başlatmayı deniyor; yine erişilemiyorsa net uyarı veriyor.
8. Netgsm SMS gönderimi GET query string yerine XML POST'a taşındı.
   - Parola artık `https://api.netgsm.com.tr/sms/send/get/?password=...` URL'sine yazılmıyor.
   - Yeni akış `https://api.netgsm.com.tr/sms/send/xml` endpoint'ine XML POST gönderiyor.
   - XML alanları escape/CDATAsafe hale getirildi.
9. Kritik entegrasyon işlemlerine audit log eklendi.
   - ParamPOS entegrasyon ayarı güncellenince `integration.parampos.updated` audit kaydı yazılıyor.
   - NEXUS bağlantı onay callback'i API anahtarını sealed kaydedince `integration.nexus.connection_approved` audit kaydı yazılıyor.
10. Currency worker SQL hijyeni güçlendirildi.
   - Worker'ın SQL'e koyduğu `tenant_id` ve `task_run.id` değerleri UUID format kontrolünden geçiriliyor.
   - Geçersiz UUID ile gelen/bozulmuş kuyruk satırları doğrudan işlenmiyor.
11. Production TLS / cookie / edge rate-limit kapıları sertleştirildi.
   - Production yanıtlarında `Strict-Transport-Security: max-age=31536000; includeSubDomains` header'ı basılıyor.
   - Admin JS CSRF çerezi production'da `Secure` flag ile set ediliyor.
   - `scripts/check-production-gates.ps1`, production modda `TRUSTED_PROXY_SECURE_COOKIES=true` ve `EDGE_RATE_LIMIT_ENABLED=true` değerlerini zorunlu kılıyor.
   - Negatif gate testi bu bayraklar yokken fail etti; pozitif gate testi iki bayrak eklendiğinde geçti.
12. Manuel sync retry audit'e bağlandı.
   - `/admin/sync/retry` manuel import kuyruğu oluşturduğunda `sync.retry_queued` audit kaydı yazılıyor.
13. DB seviyesinde katalog/sözleşme audit trigger'ları eklendi.
   - `agency.category_filter_groups`, `agency.category_filter_items`, `agency.category_fields`, `agency.contract_versions` ve `agency.listings` değişiklikleri `agency.audit_logs` içine yazılıyor.
   - Bu kapsama router'ın kurtarılmış Erlang kısmından, bulk operasyonlardan veya scriptlerden gelen değişiklikler de giriyor.
   - Lokal DB'de trigger varlığı doğrulandı.
14. Runtime health check script'i eklendi.
   - `scripts/check-runtime-health.ps1`, PostgreSQL portunu, uygulama portunu, ana sayfayı ve `/api/public/rates` endpoint'ini kontrol ediyor.
   - Lokal çalıştırmada health check başarılı geçti.
15. Audit kayıtları panelde filtrelenebilir ve export edilebilir hale getirildi.
   - `/admin/reports/audits` JSON endpoint'i eklendi; `q`, `entity`, `action`, `limit` filtrelerini destekliyor.
   - `/admin/reports/audits.csv` CSV export endpoint'i eklendi.
   - İki endpoint de oturum ve admin/owner yetkisi istiyor; oturumsuz erişimde 401 doğrulandı.
   - Panel rapor ekranına audit arama, varlık filtresi ve CSV indir aksiyonu eklendi.
16. Audit retention / arşivleme politikası eklendi.
   - `agency.audit_log_archives` arşiv tablosu ve `agency.archive_audit_logs(keep_days,batch_size)` fonksiyonu eklendi.
   - Varsayılan script `scripts/run-audit-retention.ps1`, 365 günden eski audit kayıtlarını batch halinde arşivler.
   - Güvenlik sınırı: retention 30 günden kısa tutulamaz; batch boyutu 1–50000 aralığı dışına çıkamaz.
   - Lokal çalıştırmada arşivlenecek eski kayıt olmadığı için `Archived rows: 0` sonucu alındı.
17. AI supervisor worker SQL hijyeni güçlendirildi.
   - Worker'ın SQL'e koyduğu `tenant_id` ve `task_run.id` değerleri UUID format kontrolünden geçiriliyor.
   - Bozulmuş veya beklenmeyen job satırları doğrudan SQL'e gömülmeden reddediliyor.
18. NEXUS test/inceleme scriptlerindeki demo şifre kullanımı kilitlendi.
   - `password123` artık yalnızca `ALLOW_DEMO_PASSWORDS=true` açıkça verilirse kullanılabiliyor.
   - Admin/supplier/agency parolaları için gerçek env değerleri tercih ediliyor.
   - `set_easy_passwords.ps1`, açık demo bayrağı olmadan public demo şifrelerini DB'ye yazmayı reddediyor.
19. Secret hygiene kontrolü kalıcı script'e bağlandı.
   - `scripts/check-secret-hygiene.ps1` eklendi.
   - Kontrol düz metin settings secret'larını, integration credentials içindeki düz secret anahtarlarını, AI key pool/provider düz değerlerini ve agency şemasında kart/CVV saklama kolonlarını denetliyor.
   - Lokal sonuç: `settings_plain=0`, `integration_plain=0`, `ai_pool_plain=0`, `ai_provider_plain=0`, `payment_card_columns=0`.
20. Release readiness ve ödeme/entegrasyon checklistleri tamamlandı.
   - `scripts/check-release-readiness.ps1` eklendi; build, runtime health, secret hygiene, audit retention, iki proje sözleşme eşitliği, ParamPOS testleri ve NEXUS REST smoke testini tek komutta çalıştırıyor.
   - ParamPOS lifecycle migration tekrar çalıştırılabilir hale getirildi.
   - ParamPOS HTTP integration fixture'ı ilan sözleşmesine ve sealed credential modeline uyumlu hale getirildi.
   - Production dışı local SOAP fixture endpointi yalnızca test/development ortamında kabul ediliyor; production ParamPOS endpoint kısıtı korunuyor.
   - NEXUS REST smoke testi NEXUS servisi ayağa kaldırıldıktan sonra başarılı geçti.
   - Audit rapor paneline detay modalı eklendi; metadata artık CSV indirmeden panelde incelenebilir.
21. Audit izlenebilirliği kullanıcı/IP/tarayıcı seviyesine genişletildi.
   - `agency.audit_logs` ve arşiv tablosuna `user_agent` alanı eklendi.
   - ParamPOS entegrasyon güncellemesi, NEXUS bağlantı onayı ve manuel sync retry audit kayıtlarında request IP ve user-agent tutuluyor.
   - Rapor ekranı ve CSV export artık kullanıcı adı/e-posta, IP ve user-agent alanlarını gösteriyor.
22. NEXUS operasyon paneli genişletildi.
   - `/admin/sync` ekranında bağlantı/onay dışında NEXUS kaynaklı ilan sayısı, başarısız sync işi, son başarılı sync ve son hata ayrı kartlarda izleniyor.
   - Bu görünüm acente-NEXUS entegrasyonunda sessiz bozulmaları daha erken yakalamak için eklendi.
23. CI, secret rotation ve restore drill işletim kurgusu eklendi.
   - `.github/workflows/release-readiness.yml` temel build, PowerShell parse ve production gate negatif smoke kontrolü çalıştırır.
   - `docs/secret-rotation-plan.md` kritik secret değişim prosedürünü tanımlar.
   - `scripts/backup-restore-drill.ps1` ve `docs/backup-restore-drill.md` yedek alma ve geçici veritabanına restore doğrulama akışını tanımlar.
24. Legacy temizlik ve tekrar yazım guard'ları eklendi.
   - Referansı olmayan pasif `villa` ana kategori kalıntısı kaldırıldı; `holiday_home.property_type` alt tür modeli korunuyor.
   - `agency.settings` düz secret anahtarları ve `agency.integrations.credentials` düz secret JSON alanları için validated CHECK constraint eklendi.
   - Eski ana kategori alias'larının `agency.categories` ve `agency.listings` içine tekrar yazılması DB seviyesinde engellendi.
   - `scripts/check-legacy-cleanup.ps1` release readiness akışına bağlandı.
25. NEXUS rezervasyon teslim worker hatası düzeltildi.
   - Worker claim CTE'si `event_type` ve `reservation_status` alanlarını döndürmediği için başlangıçta `queue unavailable` uyarısı üretiyordu.
   - Claim sorgusu düzeltildi ve hata özeti loglanacak hale getirildi.
   - `scripts/check-nexus-reservation-queue.ps1` release readiness akışına eklendi; aynı sorgu artık otomatik smoke test ediliyor.
26. İstek korelasyonu tekilleştirildi.
   - Her HTTP isteğinde gelen `x-request-id` değeri 128 karakterle sınırlandırılıyor; yoksa güvenli rastgele bir kimlik üretiliyor.
   - Üretilen kimlik request içine geri yazılarak audit kaydı, hata bağlamı ve response header aynı kimliği kullanıyor.
   - Yanıtlar `x-request-id` ile izlenebilir hale getirildi.
27. Auth redirect regresyonu giderildi.
   - Kurtarılmış router'ın giriş/çıkış cookie akışında geliştirme cookie güvenlik alanı yanlış boolean'a dönüştürülmüş ve 500 üretiyordu.
   - Cookie attribute kaynağı tekrar Wisp/HTTP varsayılanlarıyla uyumlu hale getirildi.
   - Giriş, çıkış ve para birimi cookie testleri yeniden çalıştırıldı; toplam 273 Gleam testi başarılı.
28. Kritik storefront sayfaları için tarayıcı regresyon testi eklendi.
   - Ana sayfa, kategori sayfası ve ilan detay sayfası Playwright ile 200/500, request-id ve ortak header/footer/main DOM sözleşmeleriyle doğrulanıyor.
   - Son koşum: 3/3 kritik sayfa başarılı.
29. Bildirim ve sosyal medya worker'ları için UUID/tenant kapsamı guard'ları eklendi.
   - Kuyruktan gelen `id` ve `tenant_id` değerleri UUID doğrulaması olmadan dinamik SQL'e geçirilmiyor.
   - Claim sorgularında `FOR UPDATE SKIP LOCKED` ve tenant kapsamı korunuyor.
   - `scripts/check-worker-hygiene.ps1` release readiness akışına bağlandı.
30. NEXUS bağlantı onay callback'i pozitif akışla test edildi.
   - `POST /v1/nexus/connection-approved` gerçek router üzerinden çalıştırılıyor.
   - API anahtarı `api_key_sealed` olarak saklanıyor; düz `api_key` alanı yazılmıyor.
   - Callback audit kaydı request-id ile doğrulanıyor.
   - Test transaction sonunda bilinçli rollback yapıyor; veritabanında test tenant/secret bırakmıyor.
   - `scripts/check-nexus-callback-flow.ps1` release readiness akışına bağlandı.

## Öncelikli yapılacak işler

### P0 — Üretime açılmadan önce zorunlu

1. Production gate netleştirilmeli.
   - İki uygulama da şu an local/dev odaklı çalışıyor.
   - Acente tarafında `docs/production-gates.md` ve `scripts/check-production-gates.ps1` eklendi.
   - `APP_ENV=production` için `APP_ORIGIN=https://...`, 64+ karakter `SECRET_KEY_BASE`, 64+ karakter `NEXUS_CONFIG_KEY`, PostgreSQL env değerleri ve production NEXUS origin kontrolleri yapılıyor.
   - `TRUSTED_PROXY_SECURE_COOKIES=true` ve `EDGE_RATE_LIMIT_ENABLED=true` artık production'da zorunlu.
   - Local `.env` için `scripts/ensure-local-secrets.ps1` eklendi; kısa/eksik `SECRET_KEY_BASE` ve `NEXUS_CONFIG_KEY` değerlerini ekrana basmadan güvenli rastgele değerlerle tamamlıyor.
   - Kalan production kapsamı: deploy pipeline'da bu gate scriptinin zorunlu adım yapılması ve proxy konfigürasyonunun gerçek ortamda doğrulanması.

2. Gizli değer saklama politikası standartlaştırılmalı.
   - NEXUS bağlantı API anahtarı acente tarafında artık `api_key_sealed` olarak AES-GCM sealed saklanıyor; eski düz metin `api_key` ilk okumada otomatik sealed alana taşınıp düz alan kaldırılıyor.
   - ParamPOS `username`, `password` ve `guid` değerleri artık `agency.integrations.credentials` içinde düz metin değil `*_sealed` alanlarıyla saklanıyor. Eski düz metin kayıtlar ilk kullanımda sealed alana taşınıp düz alanlar kaldırılıyor.
   - Legacy ayar formundan gelebilecek `parampos_password` ve `parampos_guid` değerleri de düz metin olarak `agency.settings` içine yazılmıyor; girilirse `*_sealed` olarak saklanıp düz alan temizleniyor.
   - ParamPOS servis adresi yalnızca `https://testposws.param.com.tr` ve `https://posws.param.com.tr` alan adlarıyla sınırlandı; admin panelinden farklı host girilmesi engellendi.
   - SMTP parolası ve AI API key ayarları sealed okunur/yazılır hale getirildi; eski düz metin değerler ilk kullanımda `*_sealed` alana taşınıp düz kayıt kaldırılıyor.
   - Entegrasyon kayıtlarında `password`, `api_key`, `token`, `netgsm_pass`, `whatsapp_token`, `access_token` ve `pinterest_token` yeni kayıtlarda `*_sealed` olarak saklanıyor. Bildirim ve sosyal medya worker'ları sealed değerleri çözebiliyor, eski düz metin kayıtlarla da geriye uyumlu çalışıyor.
   - AI key pool ve legacy AI provider token kayıtları artık yeni kayıtlarda sealed saklanıyor. AI key pool eski düz kayıtları ilk kullanımda sealed değere taşınıyor.
   - Eski veritabanında yalnız düz metin kalmış gizli değerleri güvenli biçimde dönüştürmek için `scripts/seal-legacy-secrets.ps1` eklendi. Varsayılan dry-run çalışır; gerçek dönüşüm için `-Apply` gerekir.
   - Acente tarafına NEXUS ile aynı modelde secret helper eklendi.
   - Local doğrulama: legacy secret sealing dry-run/apply çalıştırıldı; `settings_plain=0`, `integration_plain=0`, `ai_pool_plain=0`, `ai_provider_plain=0` sonucu alındı.

### P1 — Entegrasyon güvenliği ve operasyonel sağlamlık

4. Worker script SQL kullanımı standardize edilmeli.
   - Currency worker ve AI supervisor worker'da UUID doğrulaması eklendi; bildirim worker'da secret okuma ve claim akışı korunuyor.
   - Kalan teknik borç: PowerShell worker SQL'lerinin tamamını psql değişkenleri veya uygulama içi parameterized worker'a taşımak.

5. NEXUS onay callback retry akışı canlı e2e teste bağlanmalı.
   - Kodda callback takip/retry var.
   - Bir sonraki adım gerçek HTTP zinciriyle bağlantı isteği → onay → acente callback → feed sync testidir.

6. Rate limit / brute-force kapsamı genişletilmeli.
   - Acente panel `POST /login` ve `POST /v1/nexus/connection-approved` için kısa pencereli uygulama içi rate-limit eklendi.
   - NEXUS panel `POST /login` ve hatalı acente bağlantı anahtarı denemeleri için kısa pencereli uygulama içi rate-limit eklendi.
   - Acente public uçları için uygulama katmanı IP bazlı erken rate-limit eklendi:
     - `POST /iletisim`: 10 dakikada 5 istek.
     - `POST /api/public/checkout/start`: 10 dakikada 8 istek.
     - `POST /api/public/checkout/parampos/start`: 10 dakikada 8 istek.
     - `POST /api/public/checkout/parampos/return`: 5 dakikada 40 istek.
     - `POST /api/public/chat`: 5 dakikada 30 istek.
     - `GET /api/public/rates`: 1 dakikada 120 istek.
     - Diğer `GET /api/public/*`: 1 dakikada 180 istek.
   - Smoke test: `/api/public/rates` için 125 ardışık istekte `120 x 200`, ardından `5 x 429` alındı.
   - Production gate artık edge/WAF rate-limit bayrağını zorunlu kılıyor.
   - Kalan kapsam: gerçek reverse proxy / WAF kural setinin deployment ortamında doğrulanması.

### P2 — Savunma derinliği

8. Audit log kapsamı genişletilmeye devam edilmeli.
   - ParamPOS entegrasyon güncellemesi, NEXUS bağlantı onayı, manuel sync retry, katalog filtreleri, kategori alanları, sözleşme versiyonları ve ilan değişiklikleri audit'e bağlandı.
   - Audit raporlama ekranına filtre/arama ve CSV export eklendi.
   - Uzun dönem audit arşivleme/retention politikası eklendi.
   - Audit detay modalı eklendi.

9. CSP sıkılaştırma kademeli yapılmalı.
   - Acente tarafına temel CSP eklendi.
   - Inline script/style azaltıldıkça CSP `unsafe-inline` kaldırılabilir.

10. Scriptlerdeki development-only test şifreleri ayrıştırılmalı.
    - NEXUS tarafındaki bilinen test/inceleme scriptleri `ALLOW_DEMO_PASSWORDS=true` şartına bağlandı.
    - Kalan kapsam: ileride eklenecek test scriptleri için aynı kural kod inceleme checklist'ine alınmalı.


## Bu kontrolde iyi görünen alanlar

- `.env` dosyaları git dışı tutuluyor.
- NEXUS feed ve webhook endpoint'lerinde agency scoped API key kontrolü var.
- Acente callback endpoint'i yanlış anahtarı 401 ile reddediyor ve smoke test bunu kontrol ediyor.
- Tenant/kategori/tedarikçi/ilan sözleşmeleri iki projede otomatik karşılaştırılıyor.
- NEXUS bağlantı onayı sonrası API key düz metin outbox'a yazılmıyor; retry sırasında yeni anahtar üretiliyor.
- ParamPOS dönüş akışında provider hash doğrulaması, transaction/session eşleşmesi ve DB state-machine geçişi var; ödeme sonucu idempotent biçimde işleniyor.
- ParamPOS kart bilgileri yerel veritabanına yazılmıyor; 3D Secure başlatma formundan sağlayıcı SOAP çağrısına aktarılıyor.
- Secret hygiene kontrolü ParamPOS/entegrasyon düz metin secret ve kart saklama kolonu bulunmadığını otomatik doğruluyor.
