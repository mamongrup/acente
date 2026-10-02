# Satış ve kanal operasyonları

## Ürün yönü

NEXUS kendi dağıtım altyapısıdır. Acente bağımsız kurulabilir; rakip kanal yöneticisi hesabı gerekmez. Merkezi platform bağlantısı isteğe bağlı ve API üzerinden yapılır.

## Yönetim ekranı

`/admin/commerce-operations` finans hazırlığını, mevcut teslim kuyruklarını, kategori yayın sayılarını, dil içeriklerini ve takvim çakışmalarını gösterir. Finans durumunun hazır görünmesi gerçek tahsilat veya sağlayıcı onayı kanıtı değildir. Canlı ödeme ve e-belge için sağlayıcı bağlantısı ayrıca tamamlanmalıdır.

## Dış takvim

Yerel tatil evi veya yat ilanını seçip HTTPS iCal bağlantısını ve saat dilimini kaydedin. İşçi bağlantıyı düzenli alır. Hata olduğunda son başarılı doluluk korunur; yalnız başarılı ve doğrulanmış takvim kendi önceki bloklarını değiştirir. Bir bağlantıyı kaldırmak diğer takvimleri ve elle girilmiş stoku değiştirmez.

İhracat bağlantısı kişisel misafir bilgilerini içermez. Bağlantıyı bilenler takvimi okuyabilir; gerektiğinde bağlantıyı yenileyerek önceki anahtarı geçersiz kılın. Dış takvimler anlık stok garantisi sağlamaz. Mevcut rezervasyonlarla sonradan oluşan çakışmalar ekran üzerinden incelenmelidir.

İşçi için Node.js ve `npm ci` gerekir. Başlatma: `scripts/calendar-worker.ps1`; tek kontrol: `scripts/calendar-worker.ps1 -Once`. Üretimde işçi servis olarak sürekli çalıştırılmalıdır.

## Yapay zekâ incelemesi

İlan seçilerek içerik kalitesi incelemesi çalıştırılır. Sonuçlar öneridir; yayın içeriği, fiyat, stok veya resmi doğrulama sonucu otomatik değiştirilmez. Bulgulardaki alıntılar kaynak metinle kontrol edilir. İnceleme kaynak metin, sağlayıcı ve model bilgileriyle kayıt altına alınır. Yapılandırılmış sağlayıcı yoksa açık hata gösterilir; sahte çeviri veya inceleme oluşturulmaz.

## Henüz tamamlanmamış kapsam

Bu ekran mevcut NEXUS teslim kuyruklarını izler; yeni platform dağıtım API'sinin tamamlandığı anlamına gelmez. Bağlı ilanlarda satış desteği mevcut üç kategoriyle sınırlıdır. Diğer kategorilerin rezervasyon motorları, gerçek e-belge teslimi ve gelen WhatsApp mesajlarının ortak gelen kutusuna bağlanması ayrı çalışmalardır.
