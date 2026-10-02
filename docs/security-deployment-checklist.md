# Güvenlik dağıtım kontrol listesi

Bu kontrol listesi, 2026-10 güvenlik paketinin (CSP sıkılaştırma, oturum-anahtarlı
public CSRF, proxy-IP güveni kısıtlama, AI XSS temizliği, hata sızıntısı
kapatmaları, `search_intent` hız limiti, LIKE kaçışları, CSP report-only
izleme ucu) canlıya alınmasında uygulanacak adımları sabitler.

Devam etmeden önce [production-gates.md](production-gates.md) ve
[server-transfer-runbook.md](server-transfer-runbook.md) kontrol edilmelidir;
bu belge onların yerine geçmez, güvenlik paketine özgü adımları ekler.

## 1. Ortam değişkenleri (zamanla ters orantılı risk → önce okunmalı)

| Değişken | Development | Production | Davranışı |
|---|---|---|---|
| `APP_ENV` | `development` | `production` | HSTS, secure cookie, proxy varsayılanı, health env bildirimi bunu okur |
| `TRUST_PROXY_HEADERS` | unset (veya `true`) | **`true`** (yalnız proxy arkasında) | `false`/unset+production → `X-Forwarded-For`/`CF-Connecting-IP` yok sayılır, istemci `unknown` sayılır |
| `CSP_REPORT_ONLY` | unset (enforcing) | **kademeli geçiş: `true` → sonra unset** | `true` iken CSP yalnız `content-security-policy-report-only` başlığıyla gönderilir |
| `SECRET_KEY_BASE` | 64+ karakter | 64+ karakter, rotasyon planına bağlı | CSRF HMAC'leri ve imzalı çerezler bu anahtardan türetilir |
| `SECRET_KEY_BASE_PREVIOUS` | unset | **yalnız rotasyon penceresinde** eski sır | Set iken eski imzalı `agency_session` kabul edilir ve current sır ile yeniden damgalanır (kullanıcılar zorunlu çıkışa düşmez). Pencere sonunda unset edilir; unset = pencere kapalı |

Kritik etkileşim: `TRUST_PROXY_HEADERS` production'da `true` DEĞİLSE hız-limiti
ve karantina anahtarı `unknown` olur — tüm internet tek kovaya düşer. Proxy
arkasında çalışıyorken bu değişken `true`, proxy'nin zincirdeki istemci IP'sini
doğru yazdığı doğrulanmadan açılmamalıdır.

`SECRET_KEY_BASE` değişirse tüm imzalı oturumlar ve buna bağlı CSRF türevleri
geçersizleşir; rotasyon [secret-rotation-plan.md](secret-rotation-plan.md)
ile yapılmalıdır. Çift sırlı pencere (`SECRET_KEY_BASE_PREVIOUS`) açıksa eski
imzalı oturumlar kabul edilip current sır ile yeniden damgalanır — kullanıcı
fark etmez. Not: pencere oturum imzasını kurtarır; sırrın sızdığı acil
durumda tek başına yetmez, tüm oturumlar iptal edilmelidir.

## 2. Dağıtım öncesi kontroller

- [ ] `gleam build` uyarısız (bilinen 2 zararsız Gleam 1.18 uyarısı hariç).
- [ ] `gleam test` — router test paketi tamamen yeşil. Lighthouse audit
  testleri canlı sunucu ister: sunucu kapalıyken yerelde `[SKIP]` ile geçer,
  `REQUIRE_LIVE_SERVER=true` iken (CI'nın ayarladığı) gürültülü kırılır.
  Dağıtım öncesi tam denetim için 8082'de sunucu çalışırken koşulmalı
  (`scripts/run-dev.ps1`).
- [ ] `scripts/check-production-gates.ps1` production env ile temiz dönüyor.
- [ ] Veritabanı migration'ları güncel (`scripts/apply-pending-migrations.ps1`).
- [ ] `POST /api/csp-report` uç noktasına uygulama kullanıcısından erişilebildiği
  ve `agency.security_events`'e yazabildiği doğrulandı (aşağıdaki smoke adımı).

Smoke:

```bash
curl -si -X POST https://<domain>/api/csp-report \
  -H 'content-type: application/csp-report' \
  --data '{"csp-report":{"document-uri":"https://<domain>/","violated-directive":"script-src","blocked-uri":"https://evil.example/x.js"}}'
# Beklenen: HTTP 204
```

## 3. Kademeli CSP geçişi (report-only → enforcing)

1. **Faz 0 — hazırlık:** `CSP_REPORT_ONLY=true` ile yayınla. Kullanıcılar
   etkilenmez; tarayıcılar ihlalleri `/api/csp-report`'a gönderir.
2. **Faz 1 — izleme (en az 7 gün):** İhlal akışını sorgula (bkz. bölüm 5).
   `script-src`/`style-src` ihlalleri üç gruba ayrılır:
   - **Bilinen üçüncü parti** (Tawk, Hugeicons, OpenStreetMap): politika
     beyaz listesine eklenecekse önce sözleşme kararı, sonra kod değişikliği.
   - **Kendi inline script/stil bloklarımız**: koddan düzeltilir (nonce ya da
     harici dosya). Politika gevşetilerek KAPATILMAZ.
   - **Saldırı kalıntısı / enjeksiyon denemesi**: `blocked-uri` içinde
     `javascript:` vb. varsa olay güvenlik incelemesine alınır; politika
     değişikliği GEREKMEZ.
3. **Faz 2 — enforcing:** İhlal akışı 7 gün boyunca 0 gerçek ihlal verince
   `CSP_REPORT_ONLY` unset edilir; artık `content-security-policy` uygulanır.
4. **Geri dönüş:** Enforcing sonrası kapanan sayfa olursa `CSP_REPORT_ONLY=true`
   tek değişkenle eski davrana döner (yeniden dağıtım gerekmez).

## 4. Rollout sırası

1. Migration'ları uygula.
2. Ortam değişkenlerini ayarla (yeni değişkenler dahil).
3. Uygulamayı yeniden başlat, `/health` çıktısında `"environment":"production"`
   görüldüğünü doğrula (artık sabit `development` yazmıyor).
4. Proxy arkasında IP doğrulaması: hız-limitli bir uca (`/v1/search/intent`)
   üst üste istek atıp 429 dönen yanıtların `retry-after` taşıdığını ve
   `agency.security_events`'te `client_id`'nin gerçek IP olarak kaydedildiğini
   kontrol et. `unknown` görünüyorsa proxy başlık zinciri bozuk demektir.
5. Public form akışı: `/iletisim` sayfasından gerçek bir teklif talebi gönder —
   anonim ziyaretçi akışı 303 `/iletisim?sent=1` dönmeli. (Oturumlu akış
   otomatik testlerle sabitlendi: `public_inquiry_csrf_session_bound_token_test`.)
6. ParamPOS test POS'u ile bir 3D Secure denemesi yap; `form-action` yönlendirmesi
   CSP tarafından engellenmemeli.

## 5. CSP izleme planı (report-only dönemi ve sonrası)

Günlük kontrol (ilk hafta her gün, sonra haftalık). Bu kontrolü tek komutta
yapan betik hazır: `pwsh scripts/daily-csp-report.ps1` — saat/yönerge/kaynak
kırılımı, en çok ihlal üreten istemci ve sayfalar, hız-limiti (429) sayaçları
ve `-OutFile` ile dosya çıktısı verir; `-AlertThreshold` aşıldığında exit
kodu 2 döner. İnceleme için elle sorgu:

```sql
-- Son 24 saatin ihlal özeti: hangi yönerge, hangi engellenen kaynak
-- (metadata, tarayıcının gönderdiği ham rapordur; alanlar 'csp-report'
-- anahtarı altındadır)
select date_trunc('hour', occurred_at) as saat,
       metadata->'csp-report'->>'violated-directive' as yonerge,
       metadata->'csp-report'->>'blocked-uri' as kaynak,
       count(*) as adet
from agency.security_events
where event_type = 'csp_violation'
  and occurred_at > now() - interval '24 hours'
group by 1, 2, 3
order by adet desc;
```

- `metadata` gövdesi, tarayıcının gönderdiği ham CSP raporudur (16 KB'a kadar).
- Uyarı eşiği: aynı `client_id`'den dakikada 20'den fazla rapor zaten
  uygulama tarafında 429 ile kesilir; SQL'de ani sıçramalar enjeksiyon
  denemesi sinyali olabilir.
- `security_events` saklama süresi `agency.purge_security_defense_data`
  politikasına bağlıdır; CSP olayları `info` seviyesindedir ve alarm gürültüsü
  yaratmamak için `warning`/`critical` akışından ayrı değerlendirilmelidir.

## 6. Yeni güvenlik davranışlarının özet sözleşmesi

- **Public CSRF:** Oturumlu tarayıcıda token `agency_session`'dan HMAC ile
  türetilir (`nexus:csrf:v1`); oturumsuz ziyaretçide `agency_csrf` çerezi ile
  form alanının sabit-zamanlı eşleşmesi (double-submit) beklenir. 4 public POST
  (`/iletisim`, `/api/public/chat`, `.../checkout/start`, `.../parampos/start`)
  bu kapıdan geçer; CSRF reddi (403) diğer doğrulamalardan önce gelir.
- **Proxy IP güveni:** `request_client_id`/`request_client_ip` yalnızca
  `trust_proxy_headers()` doğruysa iletelenmiş başlıkları okur.
- **CSP:** Rastgele `https:` script kaynağı yok; `object-src 'none'`;
  `form-action` ParamPOS ödeme hostlarını kapsar.
- **Hız limitleri:** `POST /v1/search/intent` → 30/dk; `POST /api/csp-report`
  → 20/dk istemci başına.
