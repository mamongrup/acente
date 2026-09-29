# Panel kapsamı ve kalan işler

Bu belge `acente` uygulamasındaki üç erişim düzeyini esas alır: `admin` (acente sahibi/yönetici), `supplier` (tedarikçi) ve `sub_agency` (alt acente). `Nexustraveltech` ayrı bir merkezi platformdur; bu uygulama merkezi servis kapalıyken de çalışır.

## Bu aşamada çalışan alanlar

| Rol | Erişilebilir iş alanları |
| --- | --- |
| Yönetici | 17 kategorili katalog, rezervasyonlar, müşteri ve teklif talepleri, müşteri hizmetleri, kampanyalar, CMS, medya, alt acenteler, tedarikçi başvuruları, entegrasyon/senkronizasyon, ekip/yetki, raporlar; sipariş/ödeme/iade/fatura izleme |
| Tedarikçi | Kendi ilanları, fiyat ve müsaitlik, kendi ilanlarına ait rezervasyonlar ve talepler, medya düzenleme, tedarikçi kampanyaları |
| Alt acente | Kendi oluşturduğu rezervasyon, teklif ve müşteriler; katalog ve sistem ayarları menüde gösterilmez |

Başlangıç ekranında role göre hızlı işlemler, gerçek veritabanı metrikleri ve bekleyen iş sayıları gösterilir. Tedarikçinin listeleme ve talep sorguları `tenant_id` ile `owner_user_id` üzerinden sınırlanır. Bağlantı yoksa NEXUS durumu `Yok` görünür; yerel katalog ve temel işlemler devam eder.

`149_sub_agency_record_ownership.sql` müşteri, rezervasyon ve teklif kayıtlarına `created_by_user_id` ekler. `150_partner_organizations_and_assignments.sql` kuruluş, üye ve açık kayıt/talep atamasını ekler. Alt acente işlemleri artık aktif kuruluş üyeliği üzerinden sınırlandırılır. Kuruluş taşıma ve talep ataması gerçek HTTP üzerinden iki kullanıcıyla sınandı; başka kuruluşa ait kayda erişim ve yazma engellendi.

`151_supplier_booking_and_lead_workflow.sql` tedarikçinin kendi ilanına ait rezervasyon kabul/ret kararını ve talep yanıtını kaydeder. Yönetici inceleme kuyruğunda kararı rezervasyona uygulayabilir. `152_finance_review_workflow.sql` tutar sınırı korunan iade inceleme talebi ve ödeme mutabakatı ekler. İki işlem de denetim izine yazılır; gerçek sağlayıcı işlemini temsil etmez. Yerel HTTP kontrollerinde kısmi iade, fazla iade reddi, mutabakat ve mükerrer mutabakat reddi doğrulandı. Muhasebe CSV çıktısı bulunur.

`153_qnb_finance_provider_selection.sql` QNB Dijital Köprü tercihini tenant bazında kaydeder: ödeme için QNBpay, e-Fatura/e-Arşiv için QNB eSolutions. Her ikisi de erişim bilgileri verilene kadar `awaiting_credentials` durumundadır. Mevcut ParamPOS tahsilatı bu kayıt nedeniyle otomatik değiştirilmez; QNB'ye gerçek ödeme, iade veya belge gönderimi yapılmaz.

`scripts/check-shared-contracts.mjs` yerel ve merkezi projelerin aynı 17 kategoriyi ve sözleşme sürümünü kullandığını denetler. Merkezi proje yoksa bağımsız yerel çalışmayı kabul eder. Yerel bağlantı harness'i tekrar deneme, idempotency ve tenant feed ayrımını sınar; gerçek iki sunucu entegrasyon testinin yerini almaz.

## Sonraki uygulama ve doğrulama

`154–159` migration'ları ek rol seçimi, belge yenileme kaydı, tedarikçi hakedişi, inceleme görevlisi/SLA ve ek rol iptalini getirir. Ana üyelik değişiminde kullanıcının diğer rolleri korunur; kaldırılan etkin rolün oturumu ana role döner. Müşteri hesabı olan ve panel rolü de atanmış kullanıcı artık görev alanını değiştirebilir. Hakediş tahsil edilmiş rezervasyon ve komisyon kuralından hesaplanır; ödenme durumu banka referansı ve denetim iziyle kaydedilir.

Merkezi `Nexustraveltech` projesinde `153–154` migration'ları belge yenileme geçmişi, bitiş tarihi uyarısı ve tedarikçinin kendi verilerine ait performans/hakediş ekranını getirir. İki proje sözleşmesindeki 17 kategori/sürüm testi, SQL rol-belge-hakediş örnekleri, merkezi panel sayfası ve gerçek iki sunucu REST smoke testi geçti.

Müşteri panelindeki **Size özel öneriler** bölümü, giriş yapmış müşterinin chatbox talebine ve kayıtlı bölge, kategori, tarih, kişi ve bütçe tercihlerine göre yayınlanmış ilan eşleşmelerini saklar. Sohbet sahipliği e-posta ve tenant üzerinden doğrulanır; başka müşteri sohbetinden öneri oluşturulamaz. Güncel fiyat, takvim ve kapasite tekrar sorgulanır. Müşteri öneriyi beğendiğini, ilgilenmediğini veya benzerlerini istediğini kaydedebilir ve teklif talep edebilir. WhatsApp/e-posta önerileri yalnızca bildirim kuyruğunda gerçekten `sent` olmuş ve o müşteriye ait kayıtlardan görünür. Yönetici müşteri ekranından ilan önerisi kuyruğa alabilir; e-posta ve WhatsApp tercihleri ayrı ayrı açık değilse gönderim reddedilir. Aynı müşteri/ilan/kanal için 24 saatlik tekrar gönderim koruması vardır. Öneri eşleme ve izin/gönderim akışı SQL ile, panel görünümü tarayıcıyla sınandı. WhatsApp önerisi onaylı şablon gerektirir; Meta erişim bilgileri ve webhook sırrı yapılandırılana kadar gerçek gönderim ve teslimat doğrulaması yapılamaz. SMTP kabulü e-posta teslimatı olarak gösterilmez.

Yönetici inceleme merkezinde tedarikçi rezervasyon kararları en fazla 50 kayıtlık toplu işlemle atomik uygulanır. Tekil ve toplu işlem tamamlanan görev atamasını kapatır. Süresi geçen görevler için sorumluya e-posta bildirimi kuyruğa alınabilir; aynı görev için 24 saat içinde tekrar bildirim engellenir, görev yeniden atanırsa veya son tarih değiştirilirse bildirim hakkı yenilenir. Bu işlemler tenant sınırı, işlem bütünlüğü ve tekrar koruması açısından SQL içinde doğrulandı. Gerçek e-posta gönderimi SMTP yapılandırmasına bağlıdır.

Tedarikçi hakedişi için tenant bazında etkinleştirilen çıkış sonrası gün kuralı eklendi. Saatlik panel operasyon işçisi, yalnızca tamamlanmış ve tahsil edilmiş rezervasyonlar için hakediş taslağı üretir; komisyon kuralı eksik kayıtları denetim izine alır. Tekrar işlem koruması ve banka ödeme referansı zorunluluğu sürer. Misafir, tedarikçi ve yönetici aynı rezervasyonun mesaj dizisinde yazışabilir; yazma izni tenant, müşteri e-postası ve ilan sahibi üzerinden doğrulanır. Misafire panel bildirimi oluşur. Bu akışlar SQL işlem testinde doğrulandı.

İnceleme görevleri ilan, başvuru, belge ve rezervasyon kararı sonuçlandığında veritabanı tetikleyicisiyle kapanır. İlan incelemesindeki eski `review` durumuna bağlı sorgular geçerli `pending_review` durumuna düzeltildi. Görev atama ve kapanma gerçek durum geçişiyle test edildi. İki veritabanındaki çalışan kategori doğrulayıcıları 17 kategori ve 51 örnek veriyle karşılaştırıldı; aynı sonucu verdi. Bağlı REST sözleşme smoke testi ve bağlantısız yerel çalışma kontrolü geçti.

Yerel ilan kodu NEXUS ilan koduyla çakışırsa import yerel ilanın kaynak ve içeriğini artık değiştirmez. Çakışma yönetici senkronizasyon ekranında kaydedilir; yönetici yerel kodu ayırabilir, ilan kimliği ve bağlı rezervasyonları korunur. Bu durum SQL işlem testinde doğrulandı. Canlı iki sunucu denetiminde, tenant tarafından yönetilen vitrin filtrelerinin sayısının farklı olması aktarımı durduruyordu; zorunlu sözleşme anahtarları karşılaştırılırken bu sayım dışarı alındı. Uygulama yeniden başlatıldığında iki NEXUS ilanı başarıyla aktarıldı.

Sürüm kapısının ilk çalışmasında tur alt düğümleri ana kategori sanılıyordu; kontrol yalnız kök kategorileri sayacak şekilde düzeltildi. Paylaşılan tedarikçi/ilan JSON sözleşmesi veritabanındaki geçerli `1.2.0` sürümüne ve `tour_subcategory` alanına eşitlendi. Merkezi projeye tatil evi ve yat tema filtreleri eklendi. İki proje yerel DB ve sözleşme karşılaştırmaları artık 17 ana kategori, 78 aktif filtre maddesi ve 17 tedarikçi modülü için geçiyor. Kategori sayfası yönetici filtre başlığını gösteriyor; kritik sayfa tarayıcı testlerinin yedisi de geçti. `check-release-readiness.ps1 -SkipParampos` başarılıdır; ParamPOS yaşam döngüsü ve protokol testleri ayrıca geçti. Bu sonuç canlı QNB işlemlerini veya üretim kapılarını doğrulamaz.

Katalog sözleşmesi `1.1.0` ve tedarikçi/ilan sözleşmesi `1.2.0` birbirinden bağımsız sürümlenir. Yerel dosya denetimindeki aynı sürümü zorlayan yanlış varsayım kaldırıldı; bağlı ve NEXUS kurulu olmayan bağımsız kipte dosya denetimi geçti.

## Eksiksiz operasyon için kalan temel işler

1. **Kuruluş ve rol kapsamı:** Acente tarafında birden fazla rol atanıp seçiliyor. Kuruluş bazlı ayrıntılı izin kararları ve merkezi projede aynı çoklu kuruluş/rol modeli henüz eşitlenmedi. Geçmişte kuruluşa atanmamış müşteri, rezervasyon ve teklifler acente ağı ekranında listelenip yönetici tarafından açıkça atanabiliyor.
2. **Finans sağlayıcısı:** Kullanıcı QNBpay/QNB eSolutions test erişimlerini daha sonra sağlayacağını belirtti. Kimlik bilgileri ve doğrulanmış API sözleşmesi bekleniyor. Gerçek tahsilat, banka iadesi ve e-belge gönderimi yapılmıyor.
3. **Tedarikçi operasyonu:** Belge, hakediş, performans, rezervasyon kararı, misafir mesajları ve otomatik hakediş taslağı mevcut. Gerçek banka ödemesi sağlayıcı bağlantısını bekliyor.
4. **Yönetici incelemesi:** Görevli atama, son tarih, belge uyarısı, toplu karar, gecikme bildirimi ve dört inceleme türünün otomatik görev kapatması mevcut.
5. **Sözleşme eşitliği:** 17 kategorinin çalışan alan doğrulayıcıları örnek verilerde eşit. Ortak ilan alanlarının iki projedeki farklı fiziksel şemaya eşlenip aynı kararları vermesi, belge/iş akışı durumlarının ortak sürümlü şemaya taşınması ve aynı yetki kararlarının otomatik karşılaştırılması hâlâ gerekli.
6. **Entegrasyon:** İki gerçek sunucunun REST sözleşme testi geçti. Bağlı ve bağımsız tam rezervasyon akışı ile senkronizasyon çakışmasının panel üzerinden uçtan uca çözümü ayrıca sınanmalı.
7. **Tedarikçi başvurusu:** Merkezi proje onayı doğrulanmış kimlik ve kategoriye bağlı kabul edilmiş belgelerle sınırlar. Acente inceleme ekranı belge durumunu gösteriyor, ancak başvuruya belge yükleme/bağlama akışı ve aynı sunucu tarafı onay koşulları henüz yok. Bunlar birlikte tamamlanmadan iki projede onboarding karar eşitliği sağlanmış sayılmamalı.

Bu maddeler tamamlanmadan üç panel için “eksiksiz” denmemelidir.

## 28 Eylül yerel tamamlama

Yeni veya daha önce eksik açılmış bağımsız acentelere 17 kanonik kategori,
106 kategori alanı, 17 tedarikçi modülü ve yönetilebilir filtrelerin eksik
kayıtları otomatik eklenir. Tenant'a ait mevcut ad, sıralama ve etkinlik
tercihleri değiştirilmez. Yeni tenant açma testi transaction içinde çalışıp
geri alınır.

İlan ve tenant silme yolundaki ticari kanal/partner bağlı kayıt izinleri
düzeltildi. Yerel sürüm kapısı, yedi kritik tarayıcı testi, iki proje sözleşme
eşitliği, NEXUS REST smoke testi, ParamPOS yaşam döngüsü, protokol ve yerel
HTTP/SOAP/PostgreSQL testleri geçti. Bunlar gerçek QNB tahsilatı veya OTA/PMS
üzerinden canlı rezervasyon teslimatı anlamına gelmez.

Tedarikçi modül sözlüğündeki yetkiler için iki projede 15 rolün 510 kararını
karşılaştıran kontrol eklendi. Bilinmeyen bir yetki kodu artık sahip rolünde de
reddedilir. Bu karar eşitliği kuruluş üyeliklerinin iki uygulamada tamamen aynı
şekilde atanıp uygulandığını tek başına kanıtlamaz.

İlan doğrulama karşılaştırması tek örnek tenant yerine mevcut dört acentenin
tamamında 17 kategori ve 204 örnek veriyle çalıştırıldı; sonuçlar eşit. Bu
kontrol iki proje sözleşme kapısına eklendi.

## 28 Eylül hizmet operasyonu devamı

Tedarikçi başvuru ve belge inceleme kararlarında veritabanı fonksiyonları artık
incelemeyi yapan kullanıcının aynı tenant içinde aktif yönetici rolünde
olduğunu doğrular. Başka tenant yöneticisi ve tedarikçi aktörü reddedilir;
aynı tenant içindeki yetkili ekip rolü kabul edilir. Doğrudan çağrılabilecek
`unchecked` karar fonksiyonu bırakılmadı. HTTP yönlendirmesi de yalnızca
`ok` sonucunda başarılı sayar; ret, eksik kayıt, geçersiz geçiş ve veritabanı
hatası ayrı durum kodlarıyla döner. Transaction testi yerel DB sözleşme
kapısına eklendi; iki proje sözleşme kontrolü ve 276 Gleam testi geçti.
Bu kontrol, uygulamanın paylaşılan DB rolüne doğrudan erişim sağlanması
durumunda aktör kimliğini kriptografik olarak bağlamaz; oturum düzeyinde
aktör doğrulaması ayrıca tasarlanmalıdır.

Başvuru kuyruğundaki tedarikçi adı ve e-posta artık HTML olarak yorumlanmaz.
İnceleme formu ret, eksik kayıt, geçersiz durum ve geçici hata sonuçlarını
ekranda bildirir; başarılı işlemde veriyi yeniler. Bu iki davranış bağımsız
tarayıcı testinde, panel şablonu ise 276 Gleam testinde doğrulandı.

Kategori vitrininin yat sayfasında boş liste uyarısı veren son istisnası
kaldırıldı. Varsayılan vitrin ve CMS fayda kartlarındaki fiyat farkı iadesi,
7/24 uzman desteği, anında onay ve ücretsiz iptal vaatleri; doğrulanabilir
fiyat karşılaştırma, destek kanalı, rezervasyon takibi ve ilana bağlı iptal
koşulu metinleriyle değiştirildi. `201_correct_default_category_benefits.sql`
yalnızca eski varsayılan metinleri taşıyan altı sayfa bloğunu güncelledi;
yönetici tarafından özelleştirilmiş metinlere dokunmaz. İngilizce görünüm
ve boş yat sayfası tarayıcı testi geçti.

Tedarikçi ve yönetici rezervasyon ekranında kategoriye özgü açık hizmet adımları
tarih sırasıyla, geciken ve yedi gün içinde yaklaşan iş sayılarıyla gösterilir.
Genel bakıştaki iş kuyruğu geciken ve henüz başlatılmamış hizmet akışlarını
ilgili rezervasyon ekranına bağlar; tedarikçi yalnızca kendi ilanlarını görür.
Müşteri seyahat akışı seyahat tarihine göre sıralanır ve sıradaki hizmet adımı
görünür. Yalnızca müsaitliği doğrulanmış öneride indirim kullanma düğmesi çıkar.

`199_service_task_overdue_notifications.sql` ile geciken, hâlâ açık hizmet
adımları için ilan sahibine e-posta bildirim kuyruğu eklendi. Aynı adım en fazla
24 saatte bir yeniden kuyruğa alınır; işlem tenant, rezervasyon durumu ve ilan
sahibi kapsamında denetlenir. Saatlik panel operasyon işçisi bu kuyruğu üretir.
Yerel transaction testi ilk bildirimleri, aynı çalıştırmada tekrar üretmeme ve
tenant dışı çağrıyı reddetmeyi doğruladı. SMTP yapılandırması yoksa gerçek
e-posta teslimatı doğrulanmış sayılmaz.

## 28 Eylül rezervasyon ve ödeme güvenliği

NEXUS kaynaklı ilanda yerel rezervasyonun kuyruğa alınması artık ödeme için
yeterli sayılmaz. `200_nexus_checkout_fulfillment_gate.sql`, ödeme oturumu
açılmadan veya eski bir oturum ilerlemeden önce merkezi rezervasyonun başarılı
yanıtını ve boş olmayan rezervasyon referansını doğrular. Merkezi yanıt bekleniyor
ya da reddedildiyse müşteri ödeme aşamasına geçemez; arayüz tedarikçi onayının
beklendiğini bildirir. Durum değişikliği webhook'u da oluşturma onayı gelmeden
kuyruktan alınmaz. Manuel ilanların ödeme yolu etkilenmez.

Merkezi projede `159_reservation_status_requires_booking.sql`, durum webhook'unu
aynı acente, ilan ve rezervasyona ait önceden işlenmiş oluşturma olayı yoksa
reddeder. Bağlı REST smoke testi bilinmeyen rezervasyonun reddini; merkezi SQL
testi aynı kapsamda geçerli olayın kabulünü ve çapraz acente reddini doğrular.

Tam Gleam test takımındaki güncelliğini yitirmiş mikrofon, rota, para birimi ve
paylaşılan yerleşim beklentileri geçerli ürün davranışına uyarlandı. Kategori
kartları ve bölge etiketlerindeki sekiz düşük kontrastlı renk düzeltildi;
tenant URL hazırlama scripti `defer` ile yüklenir. Test takımı 276/276 geçiyor.

Bu bölüm yazıldığında merkezi `create_marketplace_booking` satış yolu kapalıydı.
Bağlı acente konaklama rezervasyonu için sonraki bölümde açıklanan ayrı stoklu
akış eklendi. Doğrudan NEXUS pazaryeri satış yolu kapalı kalır.

## 28 Eylül süper yönetim denetimleri

`/admin/control-center` tenant yöneticisine 15 canlı denetim gösterir: 17 kanonik
kategori, isteğe bağlı NEXUS bağlantısı, her iş tipi/bağlantının son senkronizasyon
durumu, rezervasyon iletimleri, ödemesi alınmış fakat NEXUS onayı gelmemiş
rezervasyonlar, merkezi stoklu akışı olmayan bağlı kategori ilanları, ilan
eşleme çakışmaları, bildirim hataları, AI işçi
sağlığı, kayıtlı bileşen sağlığı, ödeme bağlantısı, tedarikçi onay kuyruğu, fatura
hataları, iade incelemesi ve etkin yönetici sayısı. Her sonuç ilgili yönetim
ekranına bağlanır. Sayfa ve veri uçları yalnızca aynı tenant içindeki aktif
yönetici/owner oturumuna açıktır. NEXUS ve ödeme bağlantısı yapılandırılmamışsa
isteğe bağlı durumuyla gösterilir; eski başarısız sync işleri yeni başarılı işin
üstüne yanlış alarm yazmaz. Denetimler canlı veritabanı okumasıdır; dış sağlayıcı
erişimini veya uçtan uca tahsilatı doğruladığı iddia edilmez.

Bu görünüm tenant sınırını aşan platform operatörlüğü vermez. Merkezi NEXUS
tenantlarının toplu denetimi ayrı bir platform yetkisi ve denetim iziyle
tasarlanmalıdır. QNB canlı ödeme/e-fatura doğrulaması erişim bilgileri
sağlandığında tamamlanabilir. Acente tedarikçi başvurusunda kategoriye ait
belge yükleme ve kimlik doğrulama ile onay kapısı hâlâ merkezi akışla tam eşit
değildir; yalnızca yönetim görünümü bu işlemi tamamlamış sayılmaz.

## 28 Eylül platform ve tedarikçi başvuru tamamlaması

Merkezi NEXUS `/admin/control-center` yalnızca platform `owner` rolündeki
NEXUS kullanıcısına açıldı. On çapraz tenant toplu denetimi; kategori sayısı,
tedarikçi başvurusu ve kimlik/belge kuyrukları, ilan incelemesi, eski envanter,
acente bağlantıları, başarısız syndication, gecikmiş olaylar ve e-fatura
retlerini canlı veriden okur. Veritabanı fonksiyonu da aktör, tenant ve
çalışma alanını doğrular; başka aktör için satır döndürmez. Merkezi DB
transaction testi, 15 Gleam testi ve iki proje sözleşme kapısı geçti.

Acente tedarikçisi 17 kanonik kategoriden biri için ortak sözleşmedeki kimlik,
kuruluş, vergi, yetkili, banka/iletişim bilgilerini vererek başvuru açabilir.
Başvuru aynı kullanıcı ve kategori için tekrar gönderildiğinde kopyalanmaz.
Tedarikçi belgeleri başvuruya bağlanır; inceleme sonuçları iki kayıt arasında
eşlenir. Yönetici kanıt notuyla kimlik sonucunu kaydeder. Onay, doğrulanmış
kimlik ve beş zorunlu belgenin en güncel onaylı, süresi dolmamış sürümünü
gerektirir. Eski onaylı belgenin yeni reddedilmiş belgeyi gizlemesi ve süresi
dolmuş belgeyle yeniden onay transaction testlerinde reddedildi. Tedarikçi
başvuru ve yönetici inceleme tarayıcı testleri geçti; acente 276 Gleam testi
ve yerel DB sözleşme kapısı geçti.

QNBpay ve Dijital Köprü'nün canlı uçları için erişim bilgileri henüz
sağlanmadığından gerçek tahsilat, GİB gönderimi ve mutabakat doğrulanamaz.
Yeni merkezi e-fatura kaydı artık sağlayıcı yanıtı gelmeden `Kuyrukta`
başlatılır. Kimlik kararı şu anda yönetici kanıt notuna dayalı manuel
incelemedir; harici kimlik sağlayıcısı bağlanmış sayılmaz.

## 28 Eylül belge kaynağı ve sırası

Başvuru onayında en güncel kaydın gerçek tedarikçi belgesine bağlı olması;
kaynak belgenin aynı tenant, aynı tedarikçi ve aynı belge türüne ait olması;
iki kaydın da onaylı ve kaynak belgenin süresinin geçmemiş olması gerekir.
Başvuruya doğrudan eklenmiş boş/onaylı satırlar kanıt sayılmaz. Belge durum
değişiklikleri artan `revision` ile sıralanır; aynı transaction içindeki
zaman damgası eşitliği eski bir belgeyi yanlışlıkla en yeni kayıt yapamaz.
Yönetim ekranı kaynak eşleşmesi bulunmayan belgeyi işaretler. Boş belge,
yeni belge, süresi dolmuş belge ve tamamlanmış başvuru transaction senaryoları;
iki proje sözleşme kontrolü, 276 Gleam testi ve iki tarayıcı testi geçti.

Kaynak belgesi olmayan başvuru belgesi artık inceleme ekranından da
onaylanamaz. Onaylı başvurunun zorunlu belgesi reddedilir veya beklemeye
alınırsa başvuru `suspended` olur; yeniden belge kabulü ve yönetici onayı
gerekir. Bu durum değişikliği doğrudan tedarikçi belgesinden gelen eşzamanlı
güncellemelerde de tetiklenir. İlgili karar ve askıya alma senaryoları
veritabanı testinde, yönetim görünümü tarayıcı testinde doğrulandı.

Saatlik acente panel işçisi onaylı tedarikçi başvurularını yeniden denetler.
Gün değişiminde süresi dolan zorunlu belge bulunursa başvuruyu audit kaydıyla
otomatik askıya alır; tekrar çalıştırma aynı başvuruyu ikinci kez işlemez.
NEXUS tarafında süresi dolmuş belgeyle yeniden onaylama engellendi ve süper
yönetici denetim merkezine onaylı tedarikçilerin süresi dolan belge sayısı
eklendi. Merkezi saatlik görev, süresi dolan zorunlu belgesi olan onaylı
başvuruyu `review` durumuna geçirir ve audit kaydı oluşturur; aynı kaydı
tekrar işlemez. Başlangıç betiği görevi tek süreç olarak başlatır. İki
projedeki süre sonu davranışı transaction testleriyle doğrulandı.

## 28 Eylül tedarikçi ilan yayın kapısı

Acente uygulamasında yalnızca `membership_type=supplier` olan kullanıcının
`manual` kaynaklı kendi ilanı yayına alınırken, aynı tenant/kategori için
onaylı tedarikçi başvurusu aranır. Acente yöneticisinin kendi ilanları ve
NEXUS'tan senkronize edilen ilanlar bağımsız çalışma ilkesini korur.
Tedarikçi kategori onayını kaybederse ilgili yayınlanmış yerel ilanlar
`paused` olur ve her değişiklik audit kaydına geçer. NEXUS tarafında onayı
kaybeden tedarikçi kuruluşun aynı kategorideki yayınlanmış ilanları `draft`
ve moderasyon `suspended` durumuna geçer; yeniden yayın için onay gerekir.
Belge süresinin dolmasıyla başlayan otomatik durum değişimi de ilan kapısını
tetikler. İki projede yayın yasağı ve otomatik durdurma transaction testleri,
ortak sözleşme kontrolleri ve iki acente tarayıcı testi geçti.

## 28 Eylül bağlı acente rezervasyonunun stoklu akışı

NEXUS'a bağlı acentenin otel, tatil evi ve yat ilanlarında oluşturma webhook'u,
yayın/bağlantı izni ve günlük stok takvimi üzerinden gerçek merkezi rezervasyon
kaydını açar. Müsaitlik günleri aynı ilan kilidi altında satıldı olarak işaretlenir.
Tekrar anahtarı aynı acente, ilan ve rezervasyona bağlıdır; ikinci çağrı stok
düşmez. Acente sipariş tutarı ve para birimi merkezi takvim teklifiyle eşleşmezse
işlem geri alınır. Acente ödeme kapısı merkezi rezervasyon UUID'sini, tutarı,
para birimini ve son ödeme zamanını doğrular. İptal ve ödeme durumu merkezdeki
rezervasyona işlenir; iptal stoğu serbest bırakır. Ödenmemiş kayıtlar 45 dakika
sonra merkezi işçi tarafından iptal edilir; gecikmiş ödeme olayı reddedilir.

Bu akışın veritabanı testleri oluşturma, tekrar deneme, fiyat uyuşmazlığı,
ödeme durumu, iptal, süre aşımı ve stok iadesini doğruladı. İki proje sözleşme
kontrolleri ve Gleam test takımları geçti. Gerçek ödeme sağlayıcısı ile uçtan uca
satış ve bağlantılı diğer kategori stok modelleri ayrıca doğrulanmalıdır.
Doğrudan NEXUS pazaryeri `create_marketplace_booking` işlevi kapalıdır.

Bağlı akışın operasyon takibi eklendi. Acente süper yönetim ekranı tahsil
edilmiş fakat NEXUS durum onayı ulaşmamış rezervasyonları ayrı uyarı olarak
gösterir; bu bildirimler geçici hatalarda daha uzun süre yeniden denenir.
Merkezi süper yönetim ekranı ayrılmış stok, son ödeme süresi yaklaşan
rezervasyonlar ve son yedi gündeki webhook retlerini topluca gösterir.
Retler müşteri iletişim bilgileri saklanmadan, tekrar anahtarı ve hata koduyla
kaydedilir; 90 günlük saklama süresi uygulanır. Merkeze ulaşmayan ödeme
bildirimi veya süre aşımından sonra tahsil edilen tutar otomatik mutabakat
sayılmaz; yönetici incelemesi ve gerektiğinde iade gerekir.

Acente senkronizasyon ekranında başarısız rezervasyon teslimatları yeniden
denenebilir. Yönetici işlemi eski deneme sayısını denetim kaydına geçirir ve
kuyruk sayacını sıfırlar; böylece otomatik deneme sınırına ulaşmış olay da işçi
tarafından yeniden alınır. Merkezi sistemin kesin `booking_expired` yanıtı
alan teslimatlar otomatik yeniden denemeye açılmaz, incelemeye bırakılır.

## 28 Eylül hazırlık kapısı ve yetki eşitliği

Rezervasyon kuyruğu hazırlık kontrolü yalnız şema ve fonksiyonları okur; gerçek
teslimatları `processing` durumuna almaz ve misafir bilgilerini konsola yazmaz.
Bağımsız acentede NEXUS API anahtarı ve merkezi proje kurulumu yoksa hazırlık
denetimi yerel kategori, ilan ve servis kontrollerini yürütür; merkezi bağlantı
testlerini açıkça atlar. Yerel bağımsız kip ve bağlı kip hazırlık kontrolleri
geçti. Bağlı kipte callback testi ilk geniş koşuda sorgu zaman aşımı verdi,
ayrı çalıştırmada ve sonraki geniş koşuda geçti.

İki proje sözleşme kapısına tedarikçi rol/izin kararlarının tüm matrisi eklendi:
16 rol, 34 izin, `any` varyasyonları ve bilinmeyen izin reddi dahil 608 karar
aynı sonuç verdi. Bu sonuç kuruluş bazlı çoklu rol modelinin veya veritabanı
RLS yalıtımının tamamlandığı anlamına gelmez.

Merkezi süper yönetim ve acente kontrol merkezi, otel/tatil evi/yat dışındaki
bağlı ve yayınlanmış ilanları ayrı uyarı olarak sayar. Bu kategoriler için
merkezi stoklu ödeme kabul edildiği izlenimi verilmemelidir. Kategoriye özgü
stok, biletleme ve hizmet teyidi modeli kurulmadan canlı tahsilat açılmamalıdır.

Bağlı otel/tatil evi/yat dışındaki ilanların checkout sayfası artık ödeme formu
yerine ürün sayfasına yönlendiren açıklama ile 409 döner. API üzerinden doğrudan
sipariş oluşturma veritabanı tetikleyicisiyle engellenir; geçmiş bir siparişin
ödeme oturumu da rezervasyon hazır denetiminden geçemez. Aynı tur kategorisinde
acentenin kendi ilanı için sipariş ve ödeme oturumu testi geçti. Canlı yerel
serviste checkout sayfasının ve doğrudan API isteğinin 409 döndüğü, sipariş
oluşturulmadığı doğrulandı. Diğer bağlı kategorilerin satışa
açılması için merkezi rezervasyon ve stok sözleşmeleri ayrıca uygulanmalıdır.
Desteklenmeyen bağlı ilanın checkout ekranı artık ürün sayfasına geri döndürmek
yerine ilan ve tenant kimliğini koruyarak çalışan teklif formuna bağlanır.
Bağlı ilanın para birimi TRY olmasa da bu güvenli talep yolu gösterilir.
Checkout bağlantısı geçerli giriş/çıkış tarihlerini ve kişi sayısını da teklif
formuna taşır. Ürün detayındaki rezervasyon formuna tenant kimliği eklendi;
çoklu acente kurulumunda sorgu başka tenant'a düşmez.
Ürün detayında bağlı ve stoklu rezervasyonu olmayan kategorilerin ana düğmesi
doğrudan teklif formunu açar; desteklenen bağlı otel/tatil evi/yat ile yerel
ilanların rezervasyon düğmesi korunur. HTTP testi iki düğme hedefini de denetler.

Teklif talebinde ilan ve tenant eşleşmesi veritabanı tetikleyicisiyle korunur;
başka acenteye ait ilan artık sessizce genel talebe dönüştürülmez. Aynı tekrar
anahtarıyla gelen talep tek kayıt ve tek bildirim üretir. Bildirim sorgusunun
belirsiz SQL parametre türü düzeltildi; önceki durumda talep kaydolurken e-posta
kuyruğu oluşmuyordu. Genel ilansız talepler çalışmaya devam eder. HTTP ve
veritabanı testleri bu yolları doğruladı.
Talep ile bildirim artık tek SQL işleminde yazılır. Bildirim alıcısı müşterinin
adresi yerine acentenin `contact_email` ayarından, yoksa etkin yönetici
hesabından seçilir. İki alıcı da tanımlı değilse talep panelde kaydedilir,
adresi olmayan e-posta gönderim kuyruğuna eklenmez.
