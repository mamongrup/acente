# NEXUS + acente ortak yol haritası — 29 Eylül 2026

Bu belge, `C:\laragon\www\Nexustraveltech` ve `C:\laragon\www\acente` için yerel kanıta dayalı çalışma sırasıdır. Tam ürün envanteri veya üretim onayı değildir. Eski durum belgelerindeki tamamlandı/tamamlanmadı ifadeleri güncel migration ve testlerle yeniden doğrulanmadan karar sayılmaz.

## Bugünkü doğrulanan temel

- İki servis yerelde 200 ve `database=ready` döndürüyor; ortamları development.
- `acente/scripts/check-two-project-contracts.ps1` başarılı: 17 ana kategori (1.1.0), tedarikçi/ilan sözleşmesi (1.2.0), 78 aktif filtre maddesi, 17 tedarikçi modülü ve 608 rol/izin kararı eşit.
- Bağlı acentenin otel, tatil evi ve yat rezervasyonunda merkezi stok, teklif/para birimi ve ödeme durum kapıları var. Diğer bağlı kategorilerde doğrudan checkout güvenli biçimde engellenip teklif talebine yönlendiriliyor. Doğrudan NEXUS pazaryeri satış ucu halen kapalı.
- Acente AI kalite değerlendirmesi kaydedilmiş gerçek çıktı ve desteklenen metin kurallarıyla çalışıyor. Kampanya e-postası SMTP kuyruğuna bağlandı; gerçek teslim ve sağlayıcı adaptörleri ayrı doğrulama gerektiriyor.
- Çalışma ağaçları çok geniş: denetim anında acentede 323, NEXUS'ta 77 değişmiş/yeni dosya. Bu sayı kalite sorunu kanıtı değildir; değişiklikleri güvenilir sürümlere ayırma ihtiyacıdır.

## Sıralama ve kabul kapıları

| Sıra | İş paketi | Uygulanacak iş | Bitti denme koşulu |
|---|---|---|---|
| 0 | Sürüm tabanı | İki çalışma ağacındaki değişiklikleri sahiplik ve amaca göre gözden geçir; migration checksum ve yedek/geri yükleme denemesini doğrula; acente ve NEXUS CI kapılarına iki veritabanlı sözleşme, bağlı/bağımsız akış ve güvenlik testlerini ekle. | Temiz ve izlenebilir sürüm adayı; iki projede aynı commit çiftinden tekrarlanabilir yeşil test ve geri dönüş prosedürü. |
| 1 | Ortak kuruluş, rol ve ilan sözleşmesi | Çoklu kuruluş/rol ataması ve etkin bağlamı iki tarafta eşitle; 1.2.0 sözleşmesinin ortak ilan alanlarını, belge ve durum geçişlerini çalışan doğrulayıcılara taşı; tenant sınırlarını negatif testlerle denetle. Acente kendi başına çalışmaya devam etmeli. | Aynı örnek başvuru ve ilan iki projede aynı yetki, doğrulama ve durum kararını verir; farklı tenant erişimi reddedilir; NEXUS kapalıyken yerel ilan/rezervasyon çalışır. |
| 2 | Tek tam satış zinciri | Önce otel/tatil evi/yat için acente ve NEXUS arasında teklif → stok kilidi → sipariş → ödeme sonucu → onay → iptal/iade → hakediş/muhasebe olaylarını tek kimlikle izle. Doğrudan NEXUS pazaryeri 503 yolunu yalnız bu zincir doğrulandığında aç. | Çift istek, son stok yarışı, timeout, gecikmiş ödeme, iptal ve webhook tekrarı testleri; hiçbir durumda çift rezervasyon veya sahte ödeme/PNR yok. |
| 3 | Kategoriye özgü motorlar | Kalan 14 bağlı ana kategori için sırayla gerçek kapasite modeli, fiyat birimi, tedarikçi teyidi, bilet/voucher ve iptal kuralını kur. Tek bir genel otel takvimi ile hepsini açma. | Her açılan kategori için hem yerel acente hem bağlı satış/teklif ve hata telafisi testi; bitmeyen kategori güvenli teklif kipinde kalır. |
| 4 | Operasyon ve finans | Rezervasyon, tedarikçi belge süresi, inceleme, hakediş ve iade görevlerini iki panelde tek vaka/olay kimliğiyle ilişkilendir; yöneticiye atama, SLA, kanıt, retry ve mutabakat görünümü ver. | Tedarikçi, acente, müşteri ve süper admin aynı olayın yetkili görünümünü görür; muhasebe fişi ve bakiye doğrulanmış kaynağa dayanır. |
| 5 | AI, sosyal medya ve ticari büyüme | AI çıktısını sağlayıcı yanıtı, onay, maliyet ve kalite testiyle ilişkilendir; sosyal gönderide platform kimliği ve belirsiz teslim incelemesini koru; müşteri çapraz satışını gerçek seyahat olayları ve izinlere göre ölç. | Gönderildi/yayınlandı/başarılı durumları dış kanıtsız oluşmaz; izin iptali gönderimi durdurur; kampanya dönüşümü ve marj ölçülebilir. |
| 6 | Çok dil ve üretim hazırlığı | İki panel ve vitrin için alan/filtre/işlem metni locale denetimi, para birimi ve fiyat doğruluğu, erişilebilirlik, yük testleri, gözlemleme, güvenli dağıtım ve restore tatbikatı. | Üretim kapıları atlama bayrağı olmadan geçer; mobil/masaüstü kritik akışlar, altı dil ve iki proje birlikte regresyonsuz çalışır. |

## Paralel çalışabilecek işler

- Kullanıcı erişimi gerektirmeyen işler: ortak sözleşme testleri, tenant/rol denetimi, kategori motoru tasarımı ve yerel motorları, operasyonda vaka/audit birliği, AI kalite ve sosyal gönderim gözlemlenebilirliği, CI ve yedek tatbikatı.
- Kullanıcının daha sonra sağlayacağı erişime bağlı işler: QNBpay test hesabı ve doğrulanmış API, QNB Dijital Köprü e-belge erişimi, gerçek banka/hakediş yöntemi, sosyal ağ uygulama yetkileri, canlı e-posta/mesaj sağlayıcıları ve üretim alan adı/TLS. Erişim gelmeden gerçek tahsilat, GİB gönderimi veya teslim başarı iddiası yok.

## İlk uygulama dilimi

1. İki projenin mevcut değişiklikleri için sürüm envanteri çıkar ve ortak release kapısını CI içinde çalıştır.
2. Kuruluş/rol bağlamı ile ilan yaşam döngüsündeki kalan karar farklarını test fixture'larıyla görünür kıl.
3. Bir otel veya tatil evi üzerinden bağlı ve bağımsız rezervasyonun uçtan uca olay çizelgesini oluştur; ödeme sağlayıcısı gelene kadar ödeme doğrulamasını sahte başarıya çevirmeden test adaptörüyle sınırla.

Öncelik seçimi: sözleşme denetimi ve sürüm tabanı, daha fazla ekran veya kategori açılmadan önce gelir. Bugünkü testler ortak kategori/izin çekirdeğinin uyumlu olduğunu gösteriyor; ürünün bütünü için eşitlik veya canlı satış kanıtı değildir.

## 29 Eylül yerel test ilerlemesi

- Acente yayın öncesi kontrolü, çalışma zamanı ilan doğrulama eşitliği ve NEXUS REST smoke testi geçti (`scripts/check-release-readiness.ps1 -SkipParampos -SkipBrowser`).
- NEXUS `scripts/test.ps1` artık Gleam testlerine ek olarak `db/tests/category_values.sql` ve `test/*.sql` altındaki yeni rezervasyon, yönetim, tedarikçi ve webhook veritabanı testlerini de çalıştırıyor. Tam yerel test dizisi geçti.
- Eski NEXUS test ilanları yeni tedarikçi onayı, 17 kategorili sözlük ve yayın alanı zorunluluklarına uyarlandı. Üretim yayın korumaları gevşetilmedi.
- Acente CI Gleam 1.18.1 kullanıyor, worker hijyenini denetliyor ve güvensiz üretim yapılandırmasının reddedildiğini süreç çıkış koduyla doğruluyor.
- Acente tam yerel yayın kontrolü geçti: yedi kritik tarayıcı testi, ParamPOS protokol/HTTP/veritabanı testleri ve NEXUS REST smoke dahil. NEXUS tam yerel test dizisi de 15 Gleam testi ve tüm SQL testleriyle geçti.
- NEXUS ve acente yedekleri ayrı geçici veritabanlarına geri yüklendi; sırasıyla kuruluş ve tenant kayıtları sorgulanarak doğrulandı. Acente tatbikatında yerel `postgres` bakım kullanıcısı kullanıldı; uygulama kullanıcısına `CREATEDB` yetkisi verilmedi.
- `scripts/check-two-project-readiness.ps1 -RestoreDrill -AgencyMaintenanceUser postgres` iki tam test dizisini ve iki geri yükleme tatbikatını tek çağrıda geçti. Eski `/urunler/{id}` bağlantısının tenant parametresini slug yönlendirmesinde düşürmesi düzeltildi; ilan detay tarayıcı testi geçti. ParamPOS testi uzun ilan karşılaştırmasından önce çalıştırıldığında ortak kapı geçti.
- Bunlar yerel doğrulamalardır. CI üzerinde iki veritabanlı gerçek kurulum, temiz sürüm adayı, sağlayıcı bağlantıları ve üretim sunucusu kapıları henüz tamamlanmadı. Sunucu bilgileri kullanıcı tercihine göre son aşamada alınacak.
- **İş Paketi 0 (Sürüm Tabanı) Tamamlandı**: Bekleyen tüm migration'lar (Acente 175-224, NEXUS 139-175) uygulandı, trigger idempotency düzeltmeleri yapıldı. Her iki projede de working tree temizlendi ve git commit ile sabitlendi. `.local/releases/nexus-two-projects-20260929-160707.zip` sürüm paketi ve SHA-256 manifestosu başarıyla üretildi.
