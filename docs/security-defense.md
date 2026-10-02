# Uygulama ve edge saldırı savunması

Uygulama saldırgana karşılık vermez. İstekleri sınırlar, güvenli biçimde
reddeder, korelasyon kimliği üretir ve servis sürekliliğini korur. Hacimsel
DDoS savunması uygulama sürecinde değil, CDN/WAF veya ters proxy katmanında
yapılmalıdır.

## Uygulama katmanı

- Giriş denemeleri e-posta ve istemci kimliğiyle sınırlandırılır; hesap ayrıca
  art arda başarısız girişlerde geçici olarak kilitlenir.
- İletişim, ödeme, sohbet ve public API uçlarının ayrı hız limitleri vardır.
- Diğer anonim HTML GET istekleri dakikada 300 istekle sınırlandırılır; statik
  dosyalar bu bütçeyi tüketmez.
- Hız sayaçları eşzamanlı isteklerde atomik olarak artar. Tablo 10.000 aktif
  anahtar sınırına ulaştığında süresi dolmuş kayıtları temizler; hâlâ doluysa
  yeni anahtarları geçici olarak reddeder.
- `429` yanıtları `Retry-After: 60` ve `Cache-Control: no-store` taşır.
- CSRF, tenant kapsamı, rol kontrolleri, hesap kilitleme, güvenli çerezler,
  CSP ve tarayıcı izolasyon başlıkları uygulama seviyesinde kalır.

## Güvenilir proxy sözleşmesi

Production varsayılanı istemcinin `X-Forwarded-For` veya
`CF-Connecting-IP` başlığına güvenmemektir. CDN/ters proxy aşağıdaki şartları
sağlıyorsa `TRUST_PROXY_HEADERS=true` kullanılabilir:

1. Uygulama portu internete doğrudan açık değildir; yalnız proxy erişebilir.
2. Proxy, istemciden gelen forwarding başlıklarını siler ve doğruladığı gerçek
   IP ile yeniden yazar. Kullanıcı girdisini mevcut başlığa eklemek yeterli
   değildir.
3. Proxy ile uygulama arasındaki trafik özel ağ, firewall veya karşılıklı TLS
   ile sınırlandırılır.
4. Aynı IP çözümleme politikası erişim logları, WAF ve uygulamada kullanılır.

Forwarding başlığındaki istemci değeri IPv4/IPv6 adresi olarak doğrulanır ve
tek biçime getirilir; geçersiz değer `unknown` olur.

Bu koşullar yoksa değer `false` kalmalıdır. Bu kipte uygulama sahte forwarding
başlıklarını güvenlik kararı için kullanmaz.

## Edge/CDN/WAF zorunlulukları

- TLS yalnız edge üzerinde değil, edge–origin arasında da korunur.
- Origin IP ve uygulama portu genel internete kapatılır.
- Bağlantı, header ve request-body boyut sınırları tanımlanır.
- Yavaş istek/slowloris süre aşımı ve eşzamanlı bağlantı limitleri uygulanır.
- Genel IP limiti yanında login, ödeme, iletişim ve API yollarına ayrı kurallar
  konur.
- Yönetici rotaları mümkünse VPN, IP allowlist veya kimlik farkındalıklı proxy
  arkasına alınır.
- WAF yalnız gözlem modunda başlangıç verisi topladıktan sonra engelleme moduna
  geçirilir; yanlış pozitifler için geri alma prosedürü bulunur.

## Operasyon

- `x-request-id`, zaman, rota, durum kodu ve karar nedeni güvenlik olaylarında
  tutulur; parola, oturum jetonu, API anahtarı ve ödeme verisi loglanmaz.
- `agency.security_events` yalnız sınırlı güvenlik metadatası tutar;
  `agency.security_quarantines` en fazla 24 saatlik geçici engel sözleşmesini
  uygular. Uygulama bu kayıtları sınırlandırılmış fonksiyonlar üzerinden
  işler. Üretimde migration sahibi ile uygulama rolü ayrıldığında tablolara
  doğrudan yazma yetkisi ayrıca kaldırılmalıdır.
- Uygulama `429` olaylarını istemci başına en fazla 10 saniyede bir kaydeder.
  Aynı istemcinin 10 dakikada 12 kayıtlı ihlali olursa 5 dakika karantinaya
  alınır. Karantina sonraki isteklerin başında kontrol edilir. Şema henüz
  uygulanmadıysa veya veritabanı geçici olarak cevap vermezse uygulama
  çalışmaya devam eder; edge limitleri geçerli kalır.
- Log saklama süresi ve boyut kotası tanımlanır; log sistemi disk/veritabanı
  tüketerek ikinci bir DoS kaynağı haline gelmemelidir. Uygulanan dosya
  politikası aşağıdaki bölümdedir.
- Ani `401`, `403`, `404`, `429` ve ödeme hatası artışları için alarm kurulur.
- Kalıcı IP engeli otomatik verilmez. Önce süreli edge karantinası uygulanır;
  kalıcı karar yönetici incelemesi gerektirir.
- Her production değişikliğinden sonra `scripts/check-release-readiness.ps1`
  ve kontrollü yük testi çalıştırılır.
- Güvenlik olayları ve süresi dolmuş karantinalar zamanlanmış olarak
  `scripts/run-security-retention.ps1` ile temizlenir.

## Log dosyası saklama politikası

`scripts/run-security-retention.ps1` veritabanı temizliğinin ardından operasyonel
log dosyalarına da yaş ve boyut sınırı uygular. `check-release-readiness.ps1`
akışındaki "Security retention smoke" adımı betiği zaten çağırdığı için bu
temizlik ayrı bir zamanlama gerekmez ve her production kontrolünde çalışır.

| Parametre | Varsayılan | Aralık | Davranış |
|---|---|---|---|
| `LogPath` | `.local/rotation-check.log` | dosya yolu listesi | Boş bırakılırsa varsayılan dosya kullanılır; verilirse liste varsayılanın yerine geçer. Kök yolu olmayan yollar depo köküne göre çözülür. |
| `LogKeepDays` | `30` | 1-3650 | Satır başındaki `YYYY-MM-DD HH:MM:SS` damgası bu eşiği aşan satırlar atılır. |
| `LogMaxKb` | `256` | 1-102400 | Dosya bu bütçeyi aşarsa **en yeni satırlar korunur**, eskiler atılır. |

Kurallar:

- Satırlar ham bayt aralığı olarak işlenir; kalan içerik bit düzeyinde kopyalanır.
  Kısmen bozuk kodlamalı satırlar yeniden kodlanmaz.
- Damgası okunamayan satırlar yaş filtresiyle asla atılmaz; kanıt satırı
  olduğu varsayılır. Boyut tavanı gerektiğinde yine de atılabilirler.
- Boyut tavanı her zaman en az bir satır bırakır; tek satır tavanı aşsa bile
  en yeni satır korunur.
- Kırpma geçici dosyaya yazılıp `Move-Item -Force` ile değiştirilir; yazma
  satır sonları CRLF olarak normalleştirilir.
- Kırpma gerekmediğinde dosya hiç yeniden yazılmaz; ikinci çalıştırma
  değişiklik yapmaz (idempotent).
- Olmayan dosya atlanır ve özet çıktıda belirtilir; eksik kanıt dosyası
  temizlik akışını durdurmaz.
- Aralık dışı parametre, veritabanına bağlanılmadan başta reddedilir.

Her çalıştırma atılan satır sayısını, kalan bayt sayısını ve bütçeyi özetler:

```
Log retention: trimmed .local/rotation-check.log (age=12 lines, size=340 lines, 262144 bytes left)
Log retention summary: files=1 age_dropped=12 size_dropped=340 (keep_days=30 max_kb=256)
```
