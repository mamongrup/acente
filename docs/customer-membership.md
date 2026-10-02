# Müşteri üyeliği ve güvenliği

## Yerel olarak uygulananlar

- Üyelik, giriş, e-posta doğrulama ve parola yenileme: `/uye-ol`, `/uye-girisi`, `/parolami-unuttum`.
- Yeni üye, e-posta doğrulanmadan hesap verilerine erişemez; eski `/login` yolu da aynı kontrolü uygular.
- Manuel kimlik kuyruğu: `/admin/customer-verification`. Bekleyen sayısı, karar gerekçesi ve üye bildirimi bulunur. Karar için yeniden yönetici parolası, MFA etkinse ayrıca kod gerekir.
- Tam T.C. numarası saklanmaz. Manuel karar `manual_approved`, resmi NVİ sonucu `nvi_verified` olarak ayrı tutulur. KPS erişim olmadan etkinleştirilmez.
- Hesap güvenliği: kendi numarasına WhatsApp kodu isteme, kod doğrulama, e-posta/telefon değişikliği, aktif oturum listesi, oturumu tek tek veya topluca kapatma.
- İletişim değişikliği mevcut parolayı ve yeni adrese gelen kodu gerektirir; onaydan önce eski bilgi korunur. Eski e-postaya değişiklik bildirimi gider.
- Yönetici MFA: `/admin/security`. TOTP uygulaması, şifrelenmiş anahtar, tek kullanımlık sekiz kurtarma kodunun yalnız özetlerinin saklanması, tekrar kullanım engeli ve dakikada beş doğrulama sınırı. Etkinleştirme diğer oturumları kapatır. Varsayılan olarak mevcut yöneticilere otomatik zorunluluk getirilmez; her yönetici kurulumunu tamamlayarak açar.
- Kodlar 10 dakika geçerli, beş yanlış denemede kullanılamaz. Yeniden kod için 60 saniye, kullanıcı başına saatte 10 sınırı uygulanır.
- Üyelik endpointlerinde tenant/istemci başına dakikada 20 isteklik ortak sınır vardır. IP, mevcut güvenilir proxy başlığı sözleşmesiyle alınır; güvenilir IP mevcut değilse tenant için ortak kovaya düşer. Üretimde proxy gerçek IP başlıklarını temizleyip yazmalı ve `TRUST_PROXY_HEADERS` buna göre ayarlanmalıdır.
- Parola yenileme her iki oturum deposundaki oturumları kapatır. Yeni parola en az 12 karakterdir ve bcrypt için 72 baytı aşamaz.
- Yeni üyelik ve güvenlik arayüzünün çeviri kataloğu TR/EN/DE/RU/FR/ZH içerir. Ana hesap navigasyonu da bu kataloğa bağlanmıştır. Dil tercihleri vitrinle ortak çerez ve `chisfis-lang` kaynağında korunur. Yönetilebilir/editoryal içerik kaynak metnine geri döner.
- E-posta OTP metni seçilen dilde oluşturulur; WhatsApp onaylanmış şablonun yapılandırılmış dilini kullanır.

## WhatsApp bağlantısı

Entegrasyonlar > WhatsApp: Phone Number ID, şifrelenerek saklanan kalıcı erişim belirteci ve aktif bağlantı.
Ayarlar > SMS & Mesajlaşma: `whatsapp_auth_template`, `whatsapp_auth_language`, `whatsapp_api_version`.
Copy-code Authentication şablonu gerekir; gövde ve URL düğmesi aynı OTP ile doldurulur. Graph API sürümü yapılandırmadan alınır, kod içine sabitlenmez.
[Meta şablon referansı](https://www.postman.com/meta/whatsapp-business-platform/request/6vkv46u/create-authentication-template-w-otp-copy-code-button).

İşçi 30 saniyede kuyruğu kontrol eder. HTTPS sertifikası ve host doğrulanır; bağlantı/istek zaman aşımı ve en fazla üç deneme bulunur. Süresi dolmuş/tüketilmiş kodlar gönderilmez. Başarılı API yanıtı `sent` (sağlayıcı kabulü) anlamındadır; telefon doğrulaması yalnız doğru kodla gerçekleşir. Teslim/okundu anlamına gelmez. Hata durumu kullanıcıya gösterilir. Kodlar tamamlanan/başarısız WhatsApp işlerinden ve süresi dolan e-posta içeriklerinden temizlenir.

## Yönetici tarafından tamamlanacak dış yapılandırma

- Gerçek üyelik sözleşmesi ve gizlilik metni yayınlanmalıdır. Eksik metinlerle kayıt kapalıdır; örnek hukuki metin üretime eklenmedi.
- SMTP hesabı, WhatsApp erişim belirteci, onaylı Authentication şablonu ve desteklenen Graph sürümü panelden girilmeli.
- Gerçek e-posta/WhatsApp alıcısıyla teslim testi bu bilgilerin ardından yapılmalı. Yerel testlerde gerçek kullanıcıya mesaj gönderilmedi.
- Resmi KPS yetkisi gelirse servis bağlantısı ayrıca uygulanıp doğrulanmalı. Manuel onay KPS başvurusuna bağımlı değildir.

## Migration ve testler

Migration sırası: 239–246. İdempotent migration dosyaları normal dağıtım aracıyla uygulanır.
SQL testleri: `customer_membership_auth_test.sql`, `customer_verification_test.sql`, `customer_security_extensions_test.sql`; transaction sonunda rollback.
Erlang referans testi: `escript test/customer_security_worker.escript`.
Tarayıcı testleri: `e2e/member-auth.spec.js`, `e2e/member-security.spec.js`; yalnız oluşturdukları test tenantını temizlerler.
Test kapsamı: mobil/masaüstü, altı dil, gerçek kayıt/e-posta kapısı, tenant sınırları, CSRF, parola ve kod, oturumlar, MFA kurulumu ve kurtarma kodu tekrarı, WhatsApp işçisinin geçersiz bağlantıyla güvenli başarısızlığı.

## Kurulum kontrolü ve testler

Yönetim menüsündeki **Üyelik kurulumu ve bildirimler** (`/admin/membership-setup`) bağlantısından:

- E-posta, WhatsApp, webhook, sözleşme ve kişisel yönetici MFA ayarlarının hazır/eksik durumu görülür. Hazır, yalnız gerekli yapılandırmanın bulunmasıdır; teslim garantisi değildir.
- SMTP sunucusu, kullanıcı, parola, gönderen ve port panelden kaydedilir. Parola tenant kapsamında şifrelenir. SMTP istemcisi 587/25 için zorunlu STARTTLS, 465 için TLS ve sertifika/hostname doğrulaması kullanır; TLS kurulmadan AUTH göndermez.
- E-posta testi yalnız oturumdaki yönetici adresine gider. WhatsApp test alıcısı E.164 biçiminde girilir; yalnız izin verilen test numarası kullanılmalıdır. İşlem için yönetici parolası ve etkinse MFA kodu gerekir. Testler tenant başına dakikada bir sınırlandırılır.
- Gönderimler arka plan kuyruğunda işlenir. Sonuçlar 10 saniyede yenilenir. E-posta için sağlayıcı kabulü, WhatsApp için kabul/teslim/okundu/başarısız ayrılır. Test gönderimi bir müşterinin doğrulamasını veya kimlik durumunu değiştirmez.
- Bekleyen kimlik başvuruları ve başarısız üyelik doğrulama gönderimleri bildirim merkezinde toplanır; inceleme ve bağlantı ayarlarına bağlantı bulunur.
- Üye genel bakışında doğrulama özeti, profilinde sonraki adım ve inceleme durumu gösterilir.

### WhatsApp webhook kurulumu

Meta App Secret ve en az 16 karakterlik doğrulama belirtecini kurulum ekranına girin. Anahtarlar tekrar gösterilmez, şifreli saklanır. Ekrandaki callback adresi `/api/webhooks/membership-whatsapp/<tenant UUID>` biçimindedir. Aynı belirteci Meta paneline girin ve `messages` alanına abone olun. Meta'nın erişebileceği HTTPS adresi gerekir; localhost üzerinden gerçek webhook teslimi beklenmez.

GET doğrulama challenge'ı ve POST HMAC-SHA256 imzası doğrulanır. Tenant ile Phone Number ID eşleşmeden kayıt güncellenmez. Tekrarlanan veya geciken `sent` olayları `delivered/read` durumunu geri düşürmez. WhatsApp sağlayıcı mesaj kimliği OTP işine kaydedilir. Bu callback üyelik OTP/test mesajları içindir; önceki genel öneri mesajı webhook'u korunmuştur.

Referans: [Meta webhook doğrulaması](https://whatsapp.github.io/WhatsApp-Nodejs-SDK/api-reference/webhooks/start/).

Ek doğrulamalar: `test/sql/membership_setup_test.sql`, `test/membership_setup_worker.escript`, `e2e/membership-setup.spec.js`.
