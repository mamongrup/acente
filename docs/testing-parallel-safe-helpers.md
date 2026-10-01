# Paralel güvenli test yardımcıları — kısa rehber

gleeunit testleri **aynı VM'de paralel süreçlerde** koşar. Süreç-genel durumu
(OS env, paylaşılan DB hesapları) mutasyona uğratan her test, koşumlar arasında
kanıtlanmış şekilde sızar: bir testin bıraktığı `SECRET_KEY_BASE` sonraki testin
farklı bir dünyada çalışmasına, iki paralel testin aynı hesabın giriş
sayaçlarında yarışması lockout kesinliğini bozar. Bu rehberdeki üç yardımcı bu
iki tehlike sınıfını kapatır.

Uygulama: [src/nexus_agency/erl/agency_test_env.erl](../src/nexus_agency/erl/agency_test_env.erl)
— Gleam tarafındaki pub bağları paylaşılan [test/support.gleam](../test/support.gleam)
modülündedir. Test dosyanıza bağlamak için:

```gleam
import support.{create_unique_admin, env_set, env_unset, unique_username, with_env2, with_lock, with_unique_session}
```

## Yardımcılar

### `with_lock(name, owner, body)` — adlandırılmış kilit

Erlang `global:set_lock` ile serileştirir; gövde panik atsa bile kilit
`after` bloğunda serbest kalır ve **gövdenin sonucunu döndürür** (ezmez).

```gleam
with_lock("account_lockout", "account_lockout_owner", fn() {
  // Bu bölge aynı anda yalnız bir testte koşar.
  kesinlik_gerektiren_adimlar()
})
```

Ne zaman: iki test aynı anda dokunamaz — hesap-çapraz sayaçlar, tek-of
kaynaklar, sıra-duyarlı kurulumlar.

### `with_env2(name, updates, body)` — kilitli, panik-güvenli env kapsamı

`updates: List(#(String, EnvUpdate))` içindeki değişkenlerin eski değerlerini
kaydeder, `body` bitince (panik dahil) **hepsini eski haline döndürür**.
`EnvUnset` değişkeni kaldırır; pencereyi kapatmak için `env_unset()`,
açmak/set etmek için `env_set(v)` kullanılır.

```gleam
with_env2("secret_rotation_window", [
  #("SECRET_KEY_BASE_PREVIOUS", env_set(old_secret)),
  #("SECRET_KEY_BASE", env_set(simulate.default_secret_key_base)),
], fn() { pencere_acikken_davranis(db) })
```

Ne zaman: `SECRET_KEY_BASE`, `SECRET_KEY_BASE_PREVIOUS`, `CSP_REPORT_ONLY`
gibi süreç-genel env'e dokunan her test. İki env testi aynı anda koşamaz;
kilit adı test alanını tanımlar (ör. `"secret_rotation_window"`).

### `with_unique_session(db, tag, body)` — benzersiz hesap + oturum

`parallel-<tag>-<rastgele>@nexus.local` e-postasıyla admin hesabını upsert
eder, `auth.login` ile oturum açar, `body(email, session_token)`'ı koşar ve
**blok her nasıl sonuçlanırsa sonuçlansın `auth.logout` garanti eder**. Şifre
her zaman `admin123456`.

```gleam
with_unique_session(db, "currencypref", fn(email, session_token) {
  reset_currency_pref(db, email)
  ... simulate.cookie("agency_session", session_token, wisp.Signed) ...
})
```

Ne zaman: oturumlu istek gerektiren her DB testi. Paylaşılan
`integration-admin@nexus.local` hesabının giriş sayaçlarına paralel
dokunmazsınız.

### `unique_username(tag)` + `create_unique_admin(db, email)` — login-akışı testleri için

`with_unique_session` oturumu **önceden** açtığı için login akışının
kendisini test edenler (ör. `login_success_redirects_to_admin_test`,
`account_locks_after_failed_attempts_test`) bunu kullanamaz; onlar hesabı
kendi açar, formu/servisi kendi dener:

```gleam
let email = unique_username("loginsuccess")
create_unique_admin(db, email)
// ... login POST bu e-posta ile ...
```

## Karar tablosu

| Test... | Kullanım |
|---|---|
| Oturumlu istek yapıyor | `with_unique_session(db, "etiket", fn(email, token) { ... })` |
| Login/lockout akışını doğruluyor | `unique_username` + `create_unique_admin` (gerekirse `with_lock`) |
| OS env'e dokunuyor | `with_env2` (kilit adı: test alanı) |
| Hesap-çapraz kesinlik / serileştirme | `with_lock` |
| Hiçbiri — saf hesaplama | Yardımcı gerekmez |

## Kritik tuzak: "restore sonrası" davranış kapsam İÇİNDE test edilemez

`with_env2(..., fn() { ... })` kapanışına koyduğunuz her şey **env hâlâ
değiştirilmişken** koşar. "Env eski değerine döndükten sonra X davranışı"
iddiası kapanışın **dışına** yazılmalıdır — gövde bunu döndürür:

```gleam
// 1-3: pencere açıkken davranış (kapanış içinde).
let session_token =
  with_env2("secret_rotation_window", [...], fn() { pencere_govdesi(db) })

// 4: pencere kapandı (restore edildi) — kapanışın DIŞINDA.
eski_tarayici(session_token) |> router.handle(db, origin) |> should_status(403)
```

Bu hatayı derlenmiş artefakttan yakalamıştık: adım 4 kapanış içindeyken test
"pencere kapalıyken 403" bekleyip 303 alıyordu.

## Yeni test şablonları

### 1) Oturumlu uç testi (en yaygın)

```gleam
pub fn admin_something_requires_session_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      with_unique_session(db, "somethingshort", fn(_email, session_token) {
        let resp =
          simulate.browser_request(http.Post, "/admin/something")
          |> simulate.cookie("agency_session", session_token, wisp.Signed)
          |> simulate.form_body([#("csrf", csrf.token_for(session_token))])
          |> router.handle(db, origin)
        resp.status |> should.equal(204)
      })
    }
  }
}
```

### 2) Login-akışı testi (benzersiz hesap, oturum yardımcısız)

```gleam
pub fn login_flow_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      let email = unique_username("loginflow")
      create_unique_admin(db, email)
      let resp =
        simulate.browser_request(http.Post, "/login")
        |> simulate.form_body([#("email", email), #("password", "admin123456")])
        |> router.handle(db, origin)
      resp.status |> should.equal(303)
    }
  }
}
```

### 3) Env-duyarlı davranış testi

```gleam
pub fn feature_reads_env_test() {
  case real_db() {
    Error(Nil) -> panic as database_required()
    Ok(db) -> {
      with_env2("feature_env_alani", [#("MY_FLAG", env_set("on"))], fn() {
        davranis_on_modunda(db)
      })
      // Kapanışın dışında: MY_FLAG eski haline döndü.
      davranis_normal_modunda(db)
    }
  }
}
```

## Statik kontrol: paylaşılan admin kullanımı

[scripts/check-test-shared-admin.ps1](../scripts/check-test-shared-admin.ps1),
`test/` altındaki tüm `.gleam` dosyalarını tarar: `integration-admin@nexus.local`
literalini ve `pref_email` tanımını/kullanımını satır düzeyinde bulur. Mevcut,
kasıtlı olarak bırakılmış kullanımlar (fixture seed INSERT'i, `pref_email`
sabiti, üç seri testin inline login satırları, üç rotasyon gövdesi) allowlist'te
**taban sayaçlarıyla** tutulur. Allowlist dışı bir kullanım veya tabanını aşan
bir desen kontrolü kırmızıya düşürür — yeni testler paylaşılan hesabı geri
getiremez, yardımcılar fiilen zorunlu kalır.

Lokal koşum:
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-test-shared-admin.ps1`

Not: tüm desen eşleşmesi `CultureInvariant` bayrağıyla yapılır; tr-TR yerelinde
`-imatch`'in `i` ile `I`'yı eşleşmemesi (Türkçe I) tuzağına düşülmez.

## Kabul kontrol listesi

- [ ] Test süreç-genel durum mutasyona uğratıyor mu? → üç yardımcıdan biri zorunlu.
- [ ] Paylaşılan `integration-admin` kullanılıyorsa gerekçe var mı? (Varsayılan: yok.)
- [ ] "Env restore edildi" iddiası `with_env2` kapanışının **dışında** mı?
- [ ] Bloklar `body` sonucunu döndürüyor mu (sonuç ezme yok)?
- [ ] CI'da bu paket [release-readiness.yml](../.github/workflows/release-readiness.yml)
  içindeki **3 koşuluk flakiness dumanına** takılıyor — yeşil 3 koşum desenin kanıtıdır.
- [ ] Paylaşılan admin kontrolü yeşil mi? [release-readiness.yml](../.github/workflows/release-readiness.yml)
  içindeki **Shared test admin usage check** adımı ve yerelde
  `scripts/check-test-shared-admin.ps1`; allowlist'e yalnızca gerekçeli,
  kasıtlı kullanımlar eklenir.
