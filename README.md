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

Acente uygulaması açılışta ve ardından her 60 saniyede bir NEXUS kataloğunu
senkronize eder. NEXUS'ta `published` durumundaki ilanlar bütün acente
tenant'larında `source=nexus` olarak yayınlanır. Başlık, açıklama, kategori,
konum, fiyat ve görseller tekrar kayıt oluşturmadan güncellenir. NEXUS'ta
yayından alınan bir ilan acente tarafında otomatik olarak `paused` durumuna
geçer; acentenin elle oluşturduğu ilanlara dokunulmaz.

Bağlantıyı etkinleştirmek için `.env.example` içindeki `NEXUS_PG*`
değişkenlerini `.env` dosyasına ekleyin. `NEXUS_PGUSER` yalnızca
`catalog.marketplace_listings` fonksiyonunu çalıştırma yetkisine sahip bir
PostgreSQL kullanıcısı olmalıdır.

## Kuyruk işçileri

`scripts/start.ps1` uygulamayla birlikte beş kuyruk işçisini çalıştırır:

- `followup-worker.ps1`: yeni talepleri 5 saat, 10 saat, 2 gün ve 5 gün takip kuyruğuna alır.
- `notification-worker.ps1`: SMTP, Netgsm veya WhatsApp Cloud bağlantısı yapılandırılmışsa bildirimleri gönderir; eksik bağlantıyı hata olarak kaydedip üstel beklemeyle tekrar dener.
- `social-worker.ps1`: Facebook ve Threads metin gönderilerini, Instagram ve Pinterest medya gönderilerini yapılandırılmış hesaplara yayınlar. Medya URL'si eksik gönderiler hata olarak işaretlenir.
- `ai-supervisor-worker.ps1`: yalnızca `ai.*` görevlerini izler ve yeniden kuyruğa alır.

Bildirim ve sosyal gönderilerinin deneme sayısı, son hata bilgisi ve zamanlaması panelde görünür. Başarısız bildirimler Bildirim Merkezi'nden tekrar kuyruğa alınabilir.
