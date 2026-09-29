# İki proje: sunucuya aktarım ve devreye alma

Bu kaynak paketi `Nexustraveltech` ve `acente` projelerini birlikte taşır. Acente tek başına çalışabilir; NEXUS bağlantısı isteğe bağlıdır. Gerçek alan adı, sunucu ve sağlayıcı erişimleri belirlendiğinde aşağıdaki adımlar uygulanır. `scripts/start.ps1` geliştirme içindir; üretimde `run-production.ps1` kullanılır.

## 1. Paket ve ön koşullar

- `scripts/prepare-two-project-package.ps1` çalıştırılır. Oluşan ZIP ve `.sha256` birlikte taşınır. Sunucuda SHA-256 eşleşmesi ve her projenin `release-manifest.json` dosyasındaki dosya hash'leri doğrulanır.
- Hedef sunucuda PowerShell 7, Gleam, Erlang/OTP (`erlc` dahil), PostgreSQL istemci araçları (`psql`, `pg_dump`, `pg_restore`) ve ters proxy gerekir. Veritabanı, yedekleme ve worker süreçleri için ayrı servis yönetimi kurulmalıdır. Uygulamalar varsayılan olarak yalnızca `127.0.0.1` üzerinde dinler.
- ZIP, kaynak kodunu ve mevcut yerel çalışma ağacındaki izlenmeyen kaynak dosyalarını içerir. Veritabanı içeriği, `.env`, sağlayıcı anahtarları, yüklenen medya ve çalışma zamanı dosyaları bu pakette **yoktur**; bunlar ayrı, erişim kısıtlı yedeklerden taşınır.
- Paket kökünde iki proje dizini bulunur. Sürüm geçişinde önce dosyalar, sonra veritabanı yedeği ve migration, sonra uygulama/worker servisleri ele alınır.

## 2. Veritabanı ve sırlar

Her proje için ayrı PostgreSQL veritabanı oluşturun. `Nexustraveltech` tarafında `nexus_owner` şema sahibi, `nexus_app` sınırlı çalışma kullanıcısıdır. Acente tarafında `agency_app` sınırlı çalışma kullanıcısıdır; migration için ayrı, şemayı oluşturma ve güncelleme yetkisi olan operatör kullanıcısı gerekir. Roller ve veritabanları migration öncesinde DBA tarafından oluşturulmalıdır. `agency_app` rolünü migration 024'teki eski örnek parolayla bırakmayın.

Mevcut veriyi taşıyacaksanız veritabanı yedeklerini **ayrı** aktarın ve yeni veritabanlarına geri yükleyin. Uygulama koduyla aynı sürümün şema geçmişi (`system.schema_migrations`) de yedekte olmalıdır. Geri yükleme sonrası iki projenin migration komutları kalan sürümleri uygular ve daha önce uygulanmış dosyaların checksum'ını denetler. Eski migration dosyalarını değiştirmeyin.

Yeni acente kurulumu için, çalışma kullanıcısı `agency_app` önceden oluşturulmuş olmalıdır. Acente migration komutu bir operatör `.env` dosyasıyla çağrılabilir: `pwsh ./scripts/migrate.ps1 -EnvPath .env.migration`. Bu dosyada `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD` operatör bilgileri bulunur; dağıtım paketine ve web sürecine konmaz. `024_runtime_compatibility` yalnızca NEXUS veritabanı yoksa eski çapraz veritabanı iznini atlar. Bu, bağımsız acente kurulumunu destekler ve migration kaynak checksum'ını korur.

`Nexustraveltech/scripts/migrate.ps1` kendi `.env` dosyasındaki `PGOWNER` ve `PGOWNER_PASSWORD` ile çalışır. Migration bittikten sonra bu bilgiler web ve worker süreçlerinin ortamından temizlenmelidir. `.env` dosyaları yalnızca servis hesabına okunabilir olmalıdır.

## 3. Üretim yapılandırması

Her projede `.env.production.example` dosyasını `.env` olarak kopyalayın. `CHANGE_ME` değerlerini sunucuda üretilen ayrı sırlarla değiştirin. `SECRET_KEY_BASE` ve `NEXUS_CONFIG_KEY` en az 64 karakter olmalı; şifreleme anahtarı yeniden dağıtımlarda sabit tutulmalıdır. Gerçek HTTPS alan adı ve `APP_PUBLIC_HOST` aynı hostu göstermelidir. Acente tek başına çalışacaksa `NEXUS_API_ORIGIN` ve `NEXUS_API_KEY` ikisi de boş bırakılır. Bağlantı kurulacaksa ikisi birlikte yapılandırılır.

```powershell
pwsh ./scripts/check-production-gates.ps1 -EnvPath .env
```

Komutu her proje dizininde ayrı çalıştırın. Ters proxy TLS sonlandırmalı, gerçek `Host` başlığını geçirmeli ve istemciden gelen `Forwarded`/`X-Forwarded-*` başlıklarını silip güvenilir değerleri kendisi yazmalıdır. Uygulama portları doğrudan internete açılmamalıdır. Acente için güvenli çerez davranışı ve uç katman istek sınırı zorunludur. Sağlık kontrolü doğrudan loopback adresine gidiyorsa NEXUS için `Host: APP_PUBLIC_HOST` gönderilmelidir.

## 4. Başlatma ve kontrol

Migration ve geri yükleme sonrası her uygulamayı ayrı servis olarak `pwsh ./scripts/run-production.ps1` ile çalıştırın. Sürekli görevleri her worker için ayrı servis olarak `pwsh ./scripts/run-production-worker.ps1 -Name <ad>` ile çalıştırın; kullanılabilir adlar scriptlerdeki allowlist'tedir. Servis yöneticisi yeniden başlatma, log toplama ve beklenmedik çıkış uyarısı sağlamalıdır. Aynı worker'ın iki kopyasını aynı tenant/veritabanı üzerinde başlatmayın.

İlk kabulde şu sıralamayı uygulayın:

1. Yerel `scripts/check-two-project-readiness.ps1` sonucunu ve ZIP hash'ini saklayın.
2. Sunucuda iki veritabanının yedeğini/geri yüklemesini ve migration checksum denetimini tamamlayın.
3. Önce NEXUS, sonra acente uygulaması ile gerekli worker'ları başlatın. Bağımsız acente kipinde NEXUS adımı gerekmez.
4. HTTPS üzerinden giriş, tenant yalıtımı, ilan arama, rezervasyon, panel yetkileri ve iki proje arasındaki isteğe bağlı senkronizasyon akışını test edin.
5. Dış ödeme, e-fatura, e-posta/WhatsApp ve sosyal medya gönderimini ilgili gerçek kimlik bilgileri gelene kadar canlı kabul testinden ayrı tutun; örnek anahtarlarla canlı işlem yapmayın.

Geri dönüş için önce web/worker servislerini durdurun, önceki kaynak paketini ve o pakete ait veritabanı yedeğini birlikte geri yükleyin, sonra servisleri tekrar başlatın. Yalnız kodu veya yalnız şemayı geri çevirmeyin. DNS, alan adı, TLS sertifikası, servis yöneticisi ve dış sağlayıcı anahtarları sunucu seçildiğinde tamamlanır.
