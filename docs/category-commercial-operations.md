# Kategori ve ticari operasyonlar

Bu uygulama 17 ana kategoriyi aynı yerel acente çekirdeğinde çalıştırır. NEXUS
bağlantısı isteğe bağlıdır. Kategori hizmet adımı sözleşmesi acente ve merkezi
projede aynı 51 satırla tutulur; `node scripts/check-category-service-steps.mjs`
iki yerel kopyayı karşılaştırır.

## Çalışan akışlar

- Onaylı rezervasyon için kategoriye özel üç hizmet adımı idempotent biçimde
  açılır. Yönetici veya ilanın tedarikçisi adımları kapatabilir; başka tenant ya
  da tedarikçi kendi dışındaki rezervasyona işlem yapamaz. Tedarikçi rezervasyon
  ekranında durum izlenir; müşteri panelinde yalnız kendi rezervasyonunun adım
  başlığı ve durumu gösterilir. Aynı kullanıcının tenant kapsamındaki ikincil
  yönetici/tedarikçi rolü de bu işlemlerde geçerlidir.
- Yönetici `/admin/commercial-operations` ekranında yerel ilanlar için fiyat
  önerisi ve onayı, alt acente sözleşmesi ve kontenjanı, dönemsel B2B bonus
  kampanyası ve isteğe bağlı kanal eşlemesini yönetir. Bonus varsayılan olarak
  kapalıdır; yalnız kampanyanın para birimindeki tamamlanmış ve ödenmiş
  rezervasyonda kazanılır, ödeme iadesinde geri alınır.
- Yerel ilanın fiyat veya günlük müsaitliği değiştiğinde yalnız etkin eşlemesi
  olan kanallar için tekrar işlem korumalı gönderim kaydı oluşur. Test kanalı
  dış sisteme veri göndermez; kanal bağlantısı olmadığı durumda rezervasyon
  ve yerel ilan işlemleri çalışır.
- Sözleşme kontenjanı tarih, kuruluş, ilan, serbest bırakma günü ve satış
  durdurma koşullarıyla kontrol edilir. Anlaşmalı net fiyat ve para birimi
  doğrulanır. Bir rezervasyona aynı kontenjanın mükerrer ayrılması ve aynı
  alt acentede voucher kodunun tekrar kullanılması engellenir.
- Müşteri paneli, 17 kategorideki onaylı ve yakın tarihli rezervasyonlardan
  hareketle 48 tamamlayıcı seyahat sorusu arasından ilgili olanları gösterir.
  Uçuş/otobüs ardından transfer, araç, konaklama ve aktivite; konaklama ardından
  ulaşım, transfer, araç, aktivite ve plaj sorulur. Yanıtlar rezervasyon ve
  müşteri kapsamında tutulur. Yayındaki aynı bölge ilanları önerilir.
- Yönetici, müşteri tamamlayıcı satış kampanyasını kaynak ve hedef kategori,
  dönem ve indirim oranıyla taslak olarak tanımlar, etkinleştirir veya
  duraklatır. Etkin ve geçerli kampanya yoksa müşteriye indirim vaadi
  gösterilmez. Müşteri öneri kartından indirimi seçip uygun bir TRY ilanında
  rezervasyona geçtiğinde kampanya ve fiyat tekrar doğrulanır; indirim sipariş,
  rezervasyon ve ödeme oturumu toplamına uygulanır. Hak tek siparişte kullanılır.
- “Evet, göster” yanıtları ticari operasyon panelinde satış fırsatı olarak
  görünür. Yönetici bu fırsatları yeni, görüşüldü veya kapatıldı durumuna alıp
  takip notu ekleyebilir. Bu işlem müşteriye otomatik mesaj göndermez.

## Dış bağımlılıklar ve açık işler

- OTA/PMS sağlayıcılarının gerçek API sözleşmesi, kimlik bilgileri, rezervasyon
  webhook'ları ve gönderim işçisi henüz bağlı değildir. Kanal kuyruğu canlı
  senkronizasyon veya overbooking garantisi olarak sunulmaz.
- QNBpay tahsilat/iade ve QNB eSolutions belge gönderimi için sağlayıcı test
  erişimi bekleniyor. Yerel finans kayıtları gerçek banka veya e-belge işlemi
  sayılmaz.
- Tamamlayıcı satış indirimi yerel rezervasyon tahsilat tutarına bağlandı.
  Harici ödeme sağlayıcısının canlı tahsilatı ve iade mutabakatı erişim
  sağlandığında ayrıca doğrulanmalıdır.
- Merkezi NEXUS ile kategori hizmet adımı sözleşmesi eşitlenmiştir. Ticari
  kuralların ve tam rezervasyon yaşam döngüsünün iki projede otomatik uçtan uca
  eşitliği ayrıca doğrulanmalıdır.
- Mevcut veritabanı uygulama rolü tabloların da sahibidir. HTTP işlemleri rol
  ve tenant kapsamına göre sınırlandırılır; ayrı kısıtlı runtime rolü ve RLS
  veritabanı düzeyinde ek yalıtım için gereklidir.

## Doğrulama

`test/category_service_operations.sql` ve `test/commercial_operations.sql`
transaction içinde örnek akışları çalıştırır ve geri alır. Kategori sözleşmesi
kontrolü, `gleam build`, Erlang router derlemesi ve tarayıcı HTTP uçları ayrıca
denetlenir. Genel `gleam test` paketi bu çalışmayla ilgili olmayan mevcut
başarısızlıklar içerir; tam paket geçişi olarak raporlanmamalıdır.
`test/customer_journey_cross_sell.sql` rezervasyon kapsamı, bölge eşleşmesi,
kampanya etkinleştirme/duraklatma, satış fırsatı takibi, tek kullanımlık
indirim, sipariş tutarı ve tenant yalıtımını
kontrol eder.
