# Güvenlik dağıtım kontrol listesi — yerel prova kaydı (2026-10-02)

[security-deployment-checklist.md](security-deployment-checklist.md) içindeki
rollout adımları yerel geliştirme ortamında (PostgreSQL 18.2, 127.0.0.1:5432 /
nexus_agency; uygulama sunucusu **ayrık 8083 portu** ile) uçtan uca prova
edildi. Aynı makinede başka bir iş parçacığına ait 8082 dev sunucusu
çalıştığından tüm prova trafiği APP_PORT=8083 üzerinden yürütüldü ve bitişte
tamamı temizlendi.

## Sonuç özeti

| # | Checklist adımı | Sonuç | Kanıt |
|---|---|---|---|
| 1 | §1 Ortam matrisi | ✅ | Dev `.env` tabloyla uyumlu: `APP_ENV`/`TRUST_PROXY_HEADERS`/`CSP_REPORT_ONLY` unset, `SECRET_KEY_BASE`/`NEXUS_CONFIG_KEY` 64 karakter, `SECRET_KEY_BASE_PREVIOUS` yok (pencere kapalı). Sırlar rapora kopyalanmadı. |
| 2 | §2.1 `gleam build` | ✅ | Uyarısız derleme (3.7 sn; bilinen Gleam 1.18 uyarıları hariç temiz). |
| 3 | §2.2 `gleam test` (sunucusuz) | ✅ | 335 passed, no failures; Lighthouse denetimi "[SKIP] canli sunucu yok" ile geçti (desteklenen kip). |
| 4 | §2.2 tam denetim (canlı sunucu) | ✅ | Prova sunucusu 8083'te ayakta iken `REQUIRE_LIVE_SERVER=true APP_ORIGIN=http://127.0.0.1:8083 gleam test` → **335 passed, [SKIP] yok**. |
| 5 | §2.3 `check-production-gates.ps1` | ✅ | Dev .env → "production gates skipped" (0); sentetik prod env → "Production gate check passed." (0); `TRUST_PROXY_HEADERS` eksik → throw; `SECRET_KEY_BASE=CHANGE_ME` → throw. |
| 6 | §2.4 migration güncelliği | ✅* | `migrate.ps1` idempotent; 258 dahil güncel. Betik prova detayları ve bulgular aşağıda. |
| 7 | §2.5 + §4.3 `/health` | ✅ | `{"service":"nexus-agency","database":"ready","environment":"development"}` (ortam bildirimi artık sabit `development` değil). |
| 8 | §2.5 CSP smoke (`POST /api/csp-report`) | ✅ | Anonim POST → **HTTP 204**; `agency.security_events`'e `csp_violation` yazıldı (sonra etiketle silindi). |
| 9 | §4.4 Hız limiti + client_id | ✅ | 25 üst üste POST → **20×204 + 5×429**; 429 yanıtları `retry-after: 60` taşıdı; olaylar `client_id='unknown'` olarak kaydedildi (dev'de beklenen). |
| 10 | §1 Proxy güveni davranışı | ✅ | `X-Forwarded-For: 203.0.113.77`'li istek **ayrı kovaya** düştü (204 döndü, kayıt `client_id=203.0.113.77`) — development'ta iletilen başlıklar okunur, production+unset'te `unknown`'a zorlanır. |
| 11 | §4.5 Public form akışı | ✅ | GET `/iletisim` → double-submit token (`csrf_token` alanı + `agency_csrf` çerezi); POST → **303 `/iletisim?sent=1`**; talep `agency.public_inquiries`'e yazıldı (sonra prova kaydı silindi). |
| 12 | §4.6 ParamPOS 3D Secure | ⚠️ kısmi | CSP `form-action` test POS hostlarını kapsıyor (`https://testposws.param.com.tr` başlıkta doğrulandı); csrf'siz POST → **403** (CSRF reddi diğer doğrulamalardan önce — §6). Gerçek 3D denemesi yapılamadı: yerelde `agency.integrations`'ta aktif parampos kaydı yok (yapılandırma operatör adımı). |
| 13 | §5 Günlük CSP izleme | ✅ | `daily-csp-report.ps1 -Hours 24 -OutFile …` koştu; prova etiketli 21 ihlali saat/sayfa kırılımıyla raporladı ve `WARNING: CSP ihlal sayisi (21) esigi asti (0)` ile **exit 2** döndü (uyarı eşiği davranışı kanıtlandı). |
| 14 | §3 Faz 0/1/2 + geri dönüş | ℹ️ | Başlık tarafı kanıtlandı: enforcing başlığı gönderiliyor (`content-security-policy`), `CSP_REPORT_ONLY=true` iken report-only'a dönmesi koddaki sözleşmedir. 7 günlük izleme döngüsü yerelde simüle edilemez. |

## Prova sırasında tespit edilen checklist bulguları (bu işte düzeltildi)

1. **§2.4 `apply-pending-migrations.ps1` referansı**: Betik `-U postgres -d
   nexus_agency` hedefini **sert kodluyor** (param/env/.env okumuyor) ve
   `175..224` varsayılan aralığındadır; boş bir veritabanına 175+ ham
   uygulanamıyor (bağımlılıklar yok). Checklist'teki migration güncelliği
   adımı `scripts/migrate.ps1` olarak düzeltildi; betik "güncel DB'de idempotent
   üst-dolum" aracı olarak açıklandı.
2. **§4.4 uç referansı**: `POST /v1/search/intent` acente uygulamasında yok
   (platform API ucudur; acentede 404). Hız-limiti provası acentenin gerçek
   hız-limitli ucu `POST /api/csp-report` (20/dk, §6) ile yapıldı; checklist
   buna düzeltildi.
3. **Gözlem (aksiyon yok)**: 429 yanıtları `agency.security_events`'e
   `rate_limit` olayı yazmıyor; §5'teki rate_limit bölümü üretim proxy/WAF
   katmanının olaylarına da dayanır. İstenirse ayrı iş.

## Kanıt detayları

- **Migration prova detayı:** `migrate.ps1` ile güncellenmiş taze kurulum
  (scratch DB, 260 ledger kaydı) üzerinde `apply-pending-migrations` 175-258
  aralığı → **86 OK / 1 FAIL**; tek başarısız `192_seed_new_tenant_catalog.sql`
  (migrate.ps1'in apply-time yamalı migration'ı; ham kaynak kendini-tohumlayan
  tek-tenant kurulumda çalışmaz). Yani betik taze kurulum aracı değildir;
  güncel DB'de idempotent yeşildir.
- **Hız limiti sayıları:** 25 isteklik seri: 20×204 (kova), 5×429; son
  istekte `HTTP/1.1 429 Too Many Requests` + `retry-after: 60`.
- **CSRF:** `POST /api/public/checkout/parampos/start` (csrf'siz, sahte
  session) → 403; `POST /iletisim` (geçerli token) → 303 `/iletisim?sent=1`.

## Temizlik (prova izleri sıfırlandı)

- Prova sunucusu (8083) kapatıldı; **8082'deki diğer iş parçacığına ait
  sunucuya hiç dokunulmadı**.
- `agency.security_events`: 21 prova `csp_violation` kaydı silindi (sonra
  0); `rate_limit` kaydı oluşmamıştı (0).
- `agency.public_inquiries`: prova talebi (`checklist-prova@example.test`)
  silindi (DELETE 1, sonra 0).
- Prova dosyaları (geçici env'ler, sim koşucu kopyası, sunucu logları ve
  `.local/run-dev-8083.ps1` yardımcısı) `.local/` altında kaldı/girmedi.
