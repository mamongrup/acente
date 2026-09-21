# NEXUS Travel Tech proje kuralları

## İki proje, isteğe bağlı entegrasyon

Bu uygulama aşağıdaki iki yerel projenin birlikte oluşturduğu sistemin acente tarafıdır:

- `C:\laragon\www\Nexustraveltech`: merkezi tedarikçi/platform paneli
- `C:\laragon\www\acente`: acente sitesi ve acente yönetim paneli

Bu iki proje entegre çalışabilmelidir; ancak entegrasyon zorunlu bir çalışma koşulu değildir. Her acente sitesi merkezi tedarikçi paneline bağlanmadan da kurulabilmeli, yönetilebilmeli ve son kullanıcıya hizmet verebilmelidir.

### Zorunlu mimari ilkeler

1. Acente uygulaması bağımsız çalışır. `Nexustraveltech` kapalı, erişilemez veya hiç yapılandırılmamış olsa bile acente paneli, acentenin kendi ilanları ve temel site fonksiyonları çalışmaya devam eder.
2. Bir acente sahibi kendi otel, tur, villa, araç, uçuş veya diğer ilanlarını doğrudan acente panelinden oluşturabilir ve yönetebilir.
3. Acente, isterse merkezi tedarikçi paneline bağlanarak harici tedarikçi ilanlarını kendi sitesinde yayınlayabilir.
4. Bir acente veya acente sahibi aynı zamanda tedarikçi rolü üstlenebilir. Roller birbirini dışlamaz; yetkilendirme kullanıcı, kuruluş ve tenant kapsamında açıkça modellenir.
5. Yerel ilanlar ile tedarikçi panelinden senkronize edilen ilanlar veri modelinde ayırt edilir. Her kayıtta kaynak, kaynak sistem kimliği, sahip kuruluş/tenant ve senkronizasyon durumu izlenebilir olmalıdır.
6. Senkronizasyon yerel veriyi sessizce ezmez. Çakışma, eşleme, yayın durumu ve fiyat/stok güncellemeleri için belirgin kurallar kullanılır; işlemler mümkün olduğunca idempotent tasarlanır.
7. Entegrasyon hataları acente sitesini kullanılamaz hale getirmez. Uzak servis çağrıları zaman aşımı, tekrar deneme ve güvenli geri dönüş davranışına sahip olur.
8. Tenant verileri kesin biçimde yalıtılır. Bir acente başka bir acentenin özel ilanlarına, müşterilerine, rezervasyonlarına veya bağlantı bilgilerine erişemez.
9. Ortak sözleşmeler sürümlü API veya olay şemalarıyla tanımlanır. İki proje birbirinin veritabanına doğrudan bağlanmaz ve diğer projenin iç tablolarına bağımlı kod yazmaz.
10. Yeni özellikler hem bağımsız acente senaryosunda hem de tedarikçi paneline bağlı senaryoda test edilir. Entegrasyonun bulunmadığı durum bir hata değil, desteklenen normal çalışma kipidir.

Bu kurallar; veri modeli, yetkilendirme, ilan yönetimi, rezervasyon, fiyat/stok senkronizasyonu ve ileride kurulacak tüm entegrasyonlarda önceliklidir.

## Kanonik kategori sözlüğü

Her iki projede kullanılacak nihai ana kategori listesi aşağıdaki 17 kategoridir. Veritabanı, API, senkronizasyon, ilan formları, tedarikçi başvuruları ve yetkilendirmelerde `code` değerleri birebir aynı kullanılmalıdır:

| code | Türkçe ad |
|---|---|
| `hotel` | Otel |
| `holiday_home` | Tatil Evi |
| `yacht` | Yat |
| `tour` | Tur |
| `activity` | Aktivite |
| `flight` | Uçuş |
| `car` | Araç |
| `cruise` | Kruvaziyer |
| `pilgrimage` | Hac & Umre |
| `visa` | Vize |
| `ferry` | Feribot |
| `transfer` | Transfer |
| `beach` | Şezlong |
| `cinema` | Sinema |
| `event` | Etkinlik |
| `restaurant` | Restoran |
| `bus` | Otobüs |

Bu listenin dışında yeni bir ana kategori iki projeden yalnızca birine eklenemez. Yeni kategori önce ortak sözleşmeye sürümlü olarak eklenir, ardından iki projede uygulanır. `villa`, `apart`, `bungalow`, `daire` ve `residence` bağımsız ana kategori değildir; `holiday_home` ana kategorisinin `property_type` alt türleri olarak modellenir. Yat bölümü de aynı mantıkla çalışır: `gulet`, `motoryat`, `yelkenli`, `katamaran` ve `tekne` bağımsız ana kategori değildir; `yacht` ana kategorisinin `yacht_type` alt türleri olarak modellenir. `spa` ve `package` bağımsız ana kategori değildir; gerekiyorsa ilgili ana kategorilerin alt türü veya modülü olarak modellenir.

Acente uygulamasındaki eski kodlar geçiş sırasında şu eşlemeyle kanonik kodlara dönüştürülür: `OTEL→hotel`, `VILLA→holiday_home`, `holiday_home→holiday_home`, `villa→holiday_home`, `YAT→yacht`, `TUR→tour`, `AKTIVITE→activity`, `UCUS→flight`, `ARAC→car`, `KRUVAZIYER→cruise`, `HAC_UMRE→pilgrimage`, `VIZE→visa`, `FERIBOT→ferry`, `TRANSFER→transfer`, `SEZLONG→beach`, `SINEMA→cinema`, `ETKINLIK→event`, `RESTORAN→restaurant`, `OTOBUS→bus`.

## Tedarikçi ve ilan sözleşmesi eşitliği

`Nexustraveltech` ile `acente` projelerinde tedarikçi olarak çalışma kuralları ve ilan üretme ölçütleri aynı sürümlü sözleşmenin uygulaması olmalıdır. Taraflardan biri diğerinden bağımsız bir iş kuralı, zorunlu alan, kategori özelliği veya yayın koşulu tanımlayamaz.

Zorunlu eşitlik kapsamı:

1. Tedarikçi başvuru adımları, kimlik/kuruluş bilgileri, kategori seçimi, gerekli belgeler, sözleşme onayları, banka ve vergi bilgileri, inceleme, ret, onay, askıya alma ve belge yenileme kuralları iki tarafta aynıdır.
2. Tedarikçi rolleri, panel yetkileri, kullanıcı rolleri, departman erişimleri ve kategori bazlı işlem izinleri aynı yetki kodlarını ve aynı karar kurallarını kullanır.
3. İlan oluşturma, taslak kaydetme, düzenleme, incelemeye gönderme, onaylama, yayınlama, duraklatma, arşivleme ve silme durumları ile durum geçişleri aynıdır.
4. Her kategori için alan kodları, görünen adlar, veri türleri, seçenekler, ölçü birimleri, zorunluluk, varsayılan değer, doğrulama, koşullu görünürlük ve belge gereksinimleri aynıdır.
5. İlanlarda istenen ortak bilgiler; sahiplik, tedarikçi, kategori, başlık, açıklama, konum, iletişim, medya, kapasite, ünite, müsaitlik, fiyat, vergi, komisyon, politika, iptal/iade, belge, yayın ve senkronizasyon bilgileridir.
6. Kategoriye özel öznitelikler serbest metin veya projeye özel kolon adlarıyla çoğaltılmaz; ortak `field_key` ve sürümlü kategori şeması üzerinden saklanır.
7. Aynı sözleşme sürümündeki bir ilan iki projede doğrulandığında aynı sonucu vermelidir. Bir tarafta geçerli olan veri diğer tarafta ek gerekçe olmadan geçersiz sayılamaz.
8. Panel arayüzleri hedef kullanıcıya göre farklı düzenlenebilir; fakat iş kuralları, alan anlamları, doğrulama sonuçları, yetki kararları ve durum makineleri farklılaştırılamaz.
9. Sözleşme değişiklikleri `contract_version`, geriye uyumluluk kuralı ve veri migration'ı ile birlikte iki projede yayımlanır. Tek taraflı şema değişikliği yasaktır.
10. Sözleşme uyumu otomatik kontrat testleriyle denetlenir. Testler kategori listesini, alan tanımlarını, enum değerlerini, zorunlulukları, durum geçişlerini ve örnek ilan doğrulama sonuçlarını iki tarafta karşılaştırır.

Bağımsız çalışma durumunda acente uygulaması ortak sözleşmenin yerel, sürümlü bir kopyasını kullanır. NEXUS bağlantısı yeniden kurulduğunda sözleşme sürümleri karşılaştırılır; uyumsuz veri sessizce ezilmez ve migration uygulanmadan yeni sürüme geçirilmez.

## Yönetilebilir kategori filtreleri ve çoklu dil

Kategori altında vitrinde veya arama ekranında görünecek filtre başlıkları, alt kategori benzeri gruplar, tip listeleri ve seçenek maddeleri kod içine sabit yazılmaz. Ana kategori kodları ve ilan doğrulama alanları sözleşme ile sabit kalır; fakat kullanıcıya gösterilen filtre grupları ve maddeleri admin panelinden yönetilir.

Zorunlu kurallar:

1. Yönetilebilir filtre sistemi 17 ana kategorinin tamamı için geçerlidir: `hotel`, `holiday_home`, `yacht`, `tour`, `activity`, `flight`, `car`, `cruise`, `pilgrimage`, `visa`, `ferry`, `transfer`, `beach`, `cinema`, `event`, `restaurant`, `bus`. Her ana kategori kendi filtre gruplarını ve filtre maddelerini admin panelinden alır; sistem yalnızca `holiday_home` veya `yacht` için özel çalışacak şekilde tasarlanamaz.
2. `holiday_home.property_type` ve `yacht.yacht_type` gibi sözleşme alanları doğrulama için kanoniktir; ancak bunların vitrindeki başlığı, gruplaması, sırası ve seçenek sunumu admin tarafından tanımlanabilir. Aynı ilke diğer tüm kategorilerin sözleşme alanları için de geçerlidir.
3. Filtre grupları `category_code`, `group_key`, başlık, görünüm tipi, sıralama, aktiflik ve çoklu seçim kuralı ile saklanır.
4. Filtre maddeleri `item_key`, başlık, bağlı sözleşme alanı, bağlı değer, sıralama ve aktiflik ile saklanır.
5. Türkçe kaynak metin girildiğinde sistem aktif dillere çeviri kayıtlarını otomatik oluşturur. Çeviriler hazır değilse Türkçe kaynak metin güvenli geri dönüş olarak kullanılır.
6. Bu yapı hem bağımsız acente sitesinde hem NEXUS bağlantılı senaryoda aynı anlamı taşımalıdır. Tek tarafa özel filtre başlığı, seçenek anahtarı veya çeviri davranışı eklenemez.
