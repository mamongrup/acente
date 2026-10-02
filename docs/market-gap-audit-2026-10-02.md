# Acente ve kanal yönetimi karşılaştırması

Tarih: 2 Ekim 2026. Bu denetim öneri çalışmasıdır; uygulama davranışı değiştirilmedi.

## Kapsam ve kanıt sınırı

Acente kaynak kodu, migration'lar, mevcut veritabanının varsayılan vitrinine ait toplu durumlar, yerel HTTP uçları ve seçilmiş mobil sayfalar incelendi. Merkezi NEXUS projesinin kaynakları kanal bağlantısı açısından sınırlı ve salt okunur tarandı. Rakiplerin resmi ürün ve yardım sayfaları kullanıldı; ücretli yönetim panellerinde işlem yapılmadı.

Bu inceleme tüm sistemin uçtan uca kabul testi veya canlı satış onayı değildir. Sağlayıcılara gerçek ödeme, iade, e-belge veya mesaj gönderilmedi. Eski test raporları bugünün canlı işlem kanıtı sayılmadı.

## Bugün doğrulananlar

- `/health`, `/login`, `/otel`, `/tatil-evi`, `/yat`, `/robots.txt`, `/sitemap.xml`: HTTP 200.
- Chrome, 390×844 görünümünde giriş, üç kategori ve Göcek yat detay sayfası: yatay taşma yok; yüklenmesini tamamlamış bozuk görsel yok; gözlenen JavaScript çalışma hatası yok. Tüm cihazlar veya sayfalar için garanti değildir.
- 17 kategorili sözleşme, tenant kapsamında ilanlar, yerel ve isteğe bağlı NEXUS REST senkronizasyonu mevcut.
- Üyelik, e-posta/telefon doğrulaması, manuel kimlik incelemesi, yönetici güvenliği, müşteri destek/iptal/değişiklik talepleri mevcut.
- Fiyat takibi, favoriler, müşteri belgeleri, terk edilmiş sepet, CRM, bildirim kuyruğu, finans görünümü ve AI önerileri mevcut; bunlar yok diye değerlendirilmedi.
- Altı dil için bağımsız SEO profili, URL, canonical, hreflang ve sitemap altyapısı mevcut.
- Varsayılan vitrinde yayımlanmış dört ilan var: otel, tatil evi, tur ve yat. Bu sayı yalnız bu vitrindir; bütün tenant'ların kataloğu değildir.

## Öncelikli açıklar

| Öncelik | Konu | Kanıt ve tamamlanacak iş |
|---|---|---|
| P0 | Gerçek satış ve finans zinciri | Varsayılan vitrinin finans sağlayıcı durumları ParamPOS ve QNB için `awaiting_credentials`. Ödeme/iade korumaları ve yerel testler var. Sağlayıcı ortamında stok → ödeme → onay → iptal/iade → belge → mutabakat aynı sipariş üzerinden doğrulanmalı. QNB için ayar kaydı bulunması çalışan belge gönderim adaptörü kanıtı değildir; gönderim/durum sorgusu/yeniden deneme tamamlanmalı veya doğrulanmalı. |
| P0 | Gerçek OTA dağıtımı | `sales_channels`, eşleme ve outbox altyapısı var; varsayılan vitrinde kayıtlı satış kanalı ve entegrasyon yok. İncelenen kaynaklarda Booking.com/Expedia/Airbnb'ye çalışan iki yönlü taşıma adaptörü bulunamadı. Bağlantı sağlayıcısı, oda/ünite ve fiyat planı eşlemesi, gelen rezervasyon/değişiklik/iptal ve dış kanal teslim kanıtı gerekir. NEXUS kataloğu senkronizasyonu ayrı bir özelliktir. |
| P0 | iCal'ın çalıştırılması | İlan formu URL'yi metadata'ya kaydediyor; `ical_feeds` tablosu var, varsayılan vitrinde kayıt yok. Düzenli ICS okuma, dışa aktarma ve takvim bloklarını güncelleyen süreç bulunamadı. Bunlar kaynak bazlı blok, saat dilimi, iptal, yinelenen olay, son başarılı çalışma ve hata alarmıyla kurulmalı. iCal, fiyat veya anlık stok API'sinin yerini tutmaz. |
| P1 | Kanal operasyon ekranı | Kuyruk ve teslim özeti SQL altyapısı var. Tek ekranda kanal bağlantısı/eşleme, fiyat-stok-kısıt matrisi, son başarılı teslim, bekleyen olaylar, başarısızlık nedeni ve güvenli tekrar deneme sunulmalı. Test/live durumu gerçek teslim kanıtına dayanmalı. |
| P1 | Kategoriye özel satış | Bağlı NEXUS ilanlarında doğrudan ödeme otel, tatil evi ve yatla sınırlı; diğer kategoriler teklif kipine yönlendiriliyor. Bu koruma doğru, ancak 17 kategori için tamamlanmış satış motoru anlamına gelmez. Seans, araç, koltuk, bilet/voucher, tedarikçi teyidi ve iptal kuralları kategori bazında geliştirilip ortak sözleşmeyle eşit tutulmalı. |
| P1 | Çok dilli gerçek içerik | Varsayılan vitrinin 27 kaynak × 6 dil SEO satırlarında bağımsız başlık ve açıklama alanları boş. Türkçe kaynak geri dönüşü çalışır; bu durum Türkçe SEO yok demek değildir. Metadata veya çeviri tablosu ayrıca içerik sağlayabilir; bu incelemede bunların tümü dil kalite kontrolünden geçirilmedi. Dil bazlı editoryal içerik ve SEO alanları doldurulmalı; tamamlanmamış diller hazır içerik gibi indekslenmemeli. |
| P1 | Birleşik iletişim | E-posta/WhatsApp gönderimi, doğrulama, teslim webhook'u ve destek talepleri var. OTA mesajları, gelen WhatsApp mesajları ve e-postayı aynı rezervasyon konuşmasında birleştiren uçtan uca akış doğrulanmadı. Personel atama, cevapsız mesaj süresi, şablon ve konuşma geçmişi gerekir. |
| P1 | Üretim kabulü | Yerel sayfaların çalışması üretim hazırlığı değildir. Gerçek alan adı/TLS, sağlayıcı webhook erişimi, bildirim teslimi, izleme/alarmlar, gerçekçi yük, yedekten geri dönüş ve bağımsız/bağlı mod kabul kapıları üretimde doğrulanmalı. Mevcut test/yedek araçları korunmalı. |
| P2 | Ticari raporlama | Finans, haftalık rapor ve fiyat önerisi altyapısı var. Kanal bazında komisyon sonrası net kâr, rezervasyon dönüşümü, iptal oranı, doluluk, ADR/RevPAR, satış temposu ve fiyat eşitliği raporları gerçek işlem verisiyle doğrulanmalı. AI fiyat önerisi, piyasa verisine bağlı ve kanallara teslimi izlenen gelir yönetimi motoruyla eşdeğer değildir. |

## Emsal ürünlerden çıkarılan ölçütler

- [SiteMinder kanal yöneticisi](https://www.siteminder.com/channel-manager/): oda/fiyat planı dağıtımı ve kanal bağlantıları. [SiteMinder ürün paketleri](https://www.siteminder.com/pricing/): satış temposu, fiyat eşitliği, rakip fiyatları, PMS, ödeme ve metasearch ölçütleri.
- [HotelRunner kanal yöneticisi](https://hotelrunner.com/en/products/channel-manager/): stok, fiyat, müsaitlik ve promosyonların kanallara dağıtılması. [Resmi geliştirici belgeleri](https://developers.hotelrunner.com/): oda, fiyat, müsaitlik ve rezervasyon alışverişi.
- [Cloudbeds](https://www.cloudbeds.com/): PMS, kanal yönetimi, rezervasyon motoru, ödeme ve misafir iletişiminin birlikte çalışması.
- [Guesty birleşik gelen kutusu](https://www.guesty.com/features/unified-inbox/): OTA, e-posta, SMS ve WhatsApp iletişiminin aynı operasyon görünümünde yönetimi.
- [ENUYGUN otel vitrini](https://www.enuygun.com/otel/): tarih/destinasyon araması ve ücretsiz iptal gibi rezervasyon koşullarına göre seçim. [Ödeme yardım sayfası](https://www.enuygun.com/otel/sikca-sorulan-sorular/odeme-islemleri/) ve [Jolly yardım merkezi](https://www.jollytur.com/yardim-merkezi): müşteri açısından anlaşılır ödeme/rezervasyon/iptal açıklamaları.
- [Etstur iptal/iade paketi](https://www.etstur.com/Iptal-ve-Iade-Paketi): isteğe bağlı rezervasyon koruma ürünü örneği. Aynı koşullar doğrudan kopyalanmamalı; uygun sağlayıcı ve ürün sözleşmesiyle geliştirilmelidir.

Bu kaynaklar rakiplerin yayımladığı ürün özellikleridir; rakip sistemlerin hatasız çalıştığına dair bağımsız test değildir.

## Sonraki ürün geliştirmeleri

1. Arama sonuçlarında seçili tarihe göre toplam ücret, zorunlu ek ücretler, ön ödeme ve iptal koşullarının tutarlı gösterimi. Kategori detaylarının ve ödeme tutarının aynı fiyat kaynağından gelmesi.
2. Mevcut fiyat takibini çalışan bildirim teslimiyle doğrulamak; uygun ürünlerde dolu tarih için bekleme listesi ve müşterinin onaylayacağı alternatif tarih önerisi.
3. Tedarikçi/işletme ve ilan doğrulama durumunu müşteriye açık anlatmak; yorumlarda gerçekleşmiş rezervasyonla doğrulanan yorumları ayırmak. Demo içerik gerçek satış/yorum gibi sunulmamalı.
4. Tedarikçi için takvim, teslim görevleri, belge süresi ve hakediş görünümü. Merkezi PMS operasyonu NEXUS tarafında; acente yerel ilanlarını yönetmeye devam eder. İki taraf birbirinin veritabanına bağlanmaz.
5. Mobil panelde acil işlere erişim, push bildirimleri ve uygun kapsamda PWA. Yerel temel satış/operasyon doğrulanmadan ayrı native uygulama ilk öncelik değil.

## Önerilen sıra

Önce tek tam satış/finans zinciri; ardından bir gerçek kanal bağlantısı ve çalışan iCal; sonra kanal operasyon ekranı, birleşik iletişim ve dil içerikleri. Daha sonra kategori motorları ve ticari raporlar genişletilir.

Öncelik seçimi mevcut kanıtlarla Jev'e de soruldu. Satış zinciri ilk öncelik olarak seçildi; yalnız eşleme tabloları/iCal formu bulunmasının çalışan kanal yöneticisi iddiasına yeterli olmadığı değerlendirmesi desteklendi. Nihai değerlendirme kod ve gözlenen durumla yapıldı.

Teknik belge borcu: README'deki eski `NEXUS_PG*` bağlantı anlatımı, güncel REST tabanlı senkronizasyon ve zorunlu mimari ilkeleriyle uyumlu hale getirilmeli.
