# NEXUS Acente Platformu

Bağımsız çalışabilen ve NEXUS kataloğuna bağlanabilen çok kiracılı seyahat acentesi platformu.

## İlk hedef

- Acente tenant ve marka ayarları
- Yönetici, alt acente, tedarikçi, personel ve müşteri üyelikleri
- Bağımsız katalog ve NEXUS katalog bağlantısı
- Hızlı ilan arama, teklif ve rezervasyon çekirdeği

## Üyelik tipleri ve panel yetkileri

Ekip ekranı (`/admin/team`) yalnızca yöneticilere açıktır. Yönetici beş
yerleşik üyelik tipinden birini seçerek hesap oluşturur veya günceller:

- **Yönetici:** tüm panel, entegrasyon, AI, CMS ve ekip ayarları.
- **Personel:** katalog, rezervasyon, müşteri, talep ve rapor operasyonları.
- **Tedarikçi:** katalog ve yalnızca tedarikçi hedefli kampanyalar.
- **Alt acente:** katalog, rezervasyon, müşteri ve talep operasyonları.
- **Müşteri:** yalnızca vitrin ve rezervasyon akışı; `/admin` erişimi yoktur.

Roller `agency.roles` ve `agency.user_roles` tablolarında tenant'a bağlı
yetki setleriyle tutulur. Hassas ayar ve içerik uçları sunucu tarafında
yönetici rolüyle korunur; arayüzde menünün gizlenmesi tek başına güvenlik
kontrolü olarak kullanılmaz.

Genel sohbetten gelen yalnız telefon talepleri de tenant kapsamı korunarak
`/admin/inquiries` ekranından müşteri ve rezervasyon kaydına dönüştürülebilir.

Uygulama Gleam + Wisp + Lustre, veritabanı PostgreSQL kullanır. Geliştirme portu 8082, NEXUS ise 8081'dir.

Yayınlanan CMS sayfaları (standart ve blog şablonları) kendi slug'larıyla
vitrinde açılır; örneğin `/hakkimizda` veya `/kas-gezi-rehberi`. Sayfa
başlığı, SEO alanları, canonical/OG etiketleri ve page builder modülleri aynı
yayın kaydından üretilir. Uygulama ve altyapı izleme için `/health` (kısa
liveness) ve `/v1/health` uçları JSON olarak `database: ready` döndürür.

Vitrin istekleri tenant kapsamını korur. Aynı geliştirme alanında belirli bir
tenant'ı görmek için URL'ye `?tenant=<slug veya UUID>` eklenebilir; üretimde
subdomain host adı tenant slug'ı olarak kullanılır. Tenant belirtilmediğinde
yayınlanmış varsayılan `nexus-demo` kataloğu kullanılır. İlan detayları,
müsaitlik, rezervasyon, teklif, sohbet ve sitemap bu kapsamı birlikte taşır.

## NEXUS ilan senkronizasyonu

Acente bağımsız çalışır. NEXUS bağlantısı isteğe bağlıdır ve yönetim panelinin entegrasyon alanından yapılandırılır. İki proje sürümlü API üzerinden haberleşir; birbirinin veritabanına bağlanmaz.

Senkronizasyon tenant ve yetkilendirilmiş katalog kapsamında çalışır. Yerel ilanlar ile NEXUS kaynaklı ilanlar ayrı izlenir. Bağlantı hatası yerel kataloğun çalışmasını durdurmaz. Rakip kanal yöneticilerine bağlantı zorunlu değildir.

## Satış ve kanal operasyonları

`/admin/commerce-operations` ekranında finans hazırlığı, teslim kuyrukları, takvim bağlantıları, rezervasyon çakışmaları ve dil içeriklerinin durumu görülebilir. Yapay zekâ ilan incelemesi yapılandırılmış sağlayıcı kullanır; öneriler yayın içeriğini otomatik değiştirmez. Sağlayıcı yoksa çeviri veya inceleme yapılmış gibi gösterilmez.

İsteğe bağlı dış takvim işçisi Node.js ve `npm ci` ile kurulan bağımlılıkları gerektirir. `scripts/calendar-worker.ps1` düzenli çalışır; `-Once` tek tur çalıştırır. Takvim bağlantısı başarısız olduğunda önceki doluluk korunur. Dış takvim yerel tatil evi ve yat ilanlarında desteklenir; stok verisini silmeden müsaitlik üzerinde uygulanır.

## Kuyruk işçileri

`scripts/start.ps1` uygulamayla birlikte kuyruk işçilerini çalıştırır:

- `followup-worker.ps1`: yeni talepleri 5 saat, 10 saat, 2 gün ve 5 gün takip kuyruğuna alır.
- `notification-worker.ps1`: SMTP, Netgsm veya WhatsApp Cloud bağlantısı yapılandırılmışsa bildirimleri gönderir; eksik bağlantıyı hata olarak kaydedip üstel beklemeyle tekrar dener.
- `social-worker.ps1`: Facebook ve Threads metin gönderilerini, Instagram ve Pinterest medya gönderilerini yapılandırılmış hesaplara yayınlar. Medya URL'si eksik gönderiler hata olarak işaretlenir.
- `ai-supervisor-worker.ps1`: yalnızca `ai.*` görevlerini izler ve yeniden kuyruğa alır.

Bildirim ve sosyal gönderilerinin deneme sayısı, son hata bilgisi ve zamanlaması panelde görünür. Başarısız bildirimler Bildirim Merkezi'nden tekrar kuyruğa alınabilir.
