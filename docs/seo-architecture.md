# Otomatik SEO yapısı

## Yönetim

`/admin/seo` ekranından canlı HTTPS site adresi, ana sayfa başlığı/açıklaması ve Google Search Console doğrulama kodu yönetilir. Alanlar boş bırakılırsa mevcut site ayarları ve ilan içerikleri kullanılır. İlanlarda başlık, açıklama ve indeksleme tercihi değiştirilebilir; arama tüm tenant ilanlarını kapsar ve ilk 50 sonucu gösterir. İngilizce, Almanca, Rusça, Fransızca ve Çince başlık/açıklamalar panelden girilebilir ve mevcut çeviriler düzenlenebilir.

## Yeni ve mevcut ilanlar

Migration `247_automatic_listing_seo.sql`, mevcut ilanları değiştirmeden SEO kayıtlarını tamamlar. Yeni ilan ekleme kaynağından bağımsız olarak PostgreSQL trigger'ı SEO kaydı oluşturur. Sistem 17 kanonik kategoriyi kapsar; NEXUS bağlantısı gerekli değildir. Aynı başlıkta ilanların adresleri ayrıştırılır; aynı tenant içindeki eşzamanlı oluşturma işlemleri kilitle korunur. Başlık değişse bile ilk adres korunur. UUID bağlantıları ve güncel başlıktan türetilen alternatif adresler kalıcı yönlendirmeyle sabit adrese gider. Sunucudaki kart bağlantıları doğrudan sabit adrese dönüştürülür.

SEO tablosu sunum katmanına aittir. Ortak ilan sözleşmesi, kategori alanları ve yayınlama doğrulamaları değişmez. Tüm sorgular tenant kapsamında çalışır; yönetici diğer tenant ilanını değiştiremez.

## Tarama ve çoklu dil

Canonical, meta açıklama, robots, Open Graph ve JSON-LD ilk HTML yanıtında bulunur; tarayıcı betiği bunları değiştirmez. Her dil ayrı bir URL kullanır: Türkçe adres korunur; diğer diller `/en/`, `/de/`, `/ru/`, `/fr/`, `/zh/` klasörleri altında dildeki kategori ve ilan slug'ıyla sunulur. Eski `?lang=` bağlantıları ilgili dil adresine 301 yönlenir. URL panelden değişirse önceki adres yönlendirme tablosunda korunur. Yalnızca gerçek başlık ve açıklama çevirisi bulunan diller hreflang ve sitemap'e girer. Çevirisi eksik ilan sürümleri Türkçe canonical ile noindex döner. Mevcut görsel arayüz çevirisi, yayıncı açıklamasının çevirisi olarak varsayılmaz. Ana sayfa, 17 kategori ve CMS sayfaları için de her dilin bağımsız SEO kaydı vardır. Genel sayfaların yabancı dilde başlığı/açıklaması tamamlanmadan indeksleme açılmaz. İlanın çevrilmiş içerik başlığı/açıklaması ile SEO başlığı/meta açıklaması ayrı alanlardır.

Giriş, hesap, yönetim, API, rezervasyon/ödeme, önizleme, tenant seçimi, filtreli sonuç ve hata yanıtları indekslemeye kapatılır. İlan bazında noindex panelden seçilebilir. Şema gerçek fiyat, para birimi, konum, kapasite ve görsellerden üretilir; varsayımsal puan, yorum veya stok eklenmez. Hotel/VacationRental/Service, BreadcrumbList, TravelAgency ve WebPage kullanılır. Şema bulunması Google'ın zengin sonuç göstereceği anlamına gelmez; özellikle VacationRental için yayıncı verisinin Google gerekliliklerini ayrıca karşılaması gerekir.

## Sitemap ve görseller

`/sitemap.xml` ve `/sitemap-index.xml` çalışır. Kategori, içerik ve ilan haritaları ayrıdır. İlan haritaları 1000 kayıtla bölünür; taslak/duraklatılmış/arşivlenmiş ve noindex ilanlar dışarıda kalır. Yayınlanmış CMS içerikleri gerçek yayın tarihiyle eklenir; dahili home/category şablonları eklenmez. SEO/çeviri değişiklikleri ilan haritasının lastmod tarihini günceller.

İlan galerisindeki görseller ilk HTML'de boyut ve alt metinle gelir. Ana görsel eager/high priority; diğerleri lazy yüklenir. JavaScript sunucudaki görselleri yeniden oluşturmadan galeri kontrollerini bağlar. Mevcut detay tasarımı korunur.

## Doğrulama ve canlıya çıkış

`gleam build` ve `e2e/seo.spec.js` ile yeni 17 kategori, sabit adres/yönlendirme, yayın durumları, tenant izolasyonu, panel, dil sürümleri, sitemap, mobil genişlik ve galeri denetlenir. Üyelik kurulum testleri ayrıca çalıştırılır.

Canlı alan adı yayımlandığında panelden canlı site adresini ve Search Console doğrulama kodunu girin; Google Search Console'da sitemap-index.xml gönderin. Yerel site ölçümleri gerçek kullanıcı Core Web Vitals verisi değildir. Canlı ortamda Search Console/PageSpeed ile LCP, INP ve CLS izlenmelidir. CDN, barındırma gecikmesi, harici görsellerin boyutu ve yayınlanan içeriğin kalitesi sonuçları etkiler. Sıralama garantisi verilmez.

Son yerel doğrulama: Gleam derlemesi başarılı; 4 SEO/tarayıcı testi, 4 üyelik kurulum testi ve automatic_listing_seo_test.sql başarılı. Mevcut ilanlarda eksik SEO kaydı: 0. İçerik sitemap'indeki mevcut 5 URL'nin tamamı HTTP 200.

## Dil başına SEO (migration 248)

`agency.seo_locales`, tenant + kaynak + dil kapsamında URL, SEO başlığı, meta açıklaması, anahtar kelimeler, Open Graph başlığı/açıklaması/görseli ve noindex tercihini ayrı tutar. İlan içerik çevirileri mevcut `agency.translations` tablosunda saklanır. Tek dilde kaydetme diğer dil kayıtlarını değiştirmez. Anahtar kelimeler içerik planlaması için yönetilir; Google meta keywords alanını sıralamada kullanmaz.

Yeni tenant, ilan ve CMS sayfalarında dil kayıtları otomatik oluşturulur. Gerçek çevrilmiş ilan başlığı/açıklaması hazırsa yabancı slug ilk başlıktan üretilir ve korunur. Sadece dil klasörüne uygun yollar kabul edilir; yönetim/API/hesap/statik yollar SEO adresi olarak atanamaz. URL çakışmaları kaydı engeller. URL değişiklikleri `agency.seo_path_aliases` ile korunur. Silinen ilanın dil kayıtları temizlenir. Kaynak ilan sözleşmesi değişmez.

Canonical, hreflang, sitemap, Open Graph, Twitter ve WebPage.inLanguage ilgili dilin verilerini kullanır. URL'deki dil, ziyaretçinin çerezinden bağımsızdır. Dil seçicisi aynı kaynağın hedef dil adresini açar. Sunucu ve JavaScript galerisi görsel alt metinlerini o dilin ilan başlığıyla üretir.

Son doğrulama: 6 SEO testi + 4 üyelik testi başarılı; language_specific_seo_test.sql yeni tenant, altı dil kaydı, çevrilmiş slug, eski URL ve ilan silme davranışlarını doğrular. Canlı sıralama ve gerçek kullanıcı performans ölçümleri yerel test sonucu değildir.
