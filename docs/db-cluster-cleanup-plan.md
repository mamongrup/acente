# 5432 PostgreSQL kümesi — ters yönlü kalıntı taraması ve temizlik planı

Tarih: 2026-10-02 · Küme: `127.0.0.1:5432` (acente geliştirme) · Yöntem: salt-okunur katalog sorguları (`pg_namespace`, `pg_class`, `pg_proc`, `pg_roles`, `pg_database`, `pg_stat_activity`). Hiçbir DDL çalıştırılmadı.

## Bulgular

1. **`nexus_agency` temiz.** Platform kök şemaları (`catalog`, `core`, `events`, `booking`, `inventory`, `finance`, `cms`, `ai`, `onboarding`, `partners`, `organization`, `settings`, `operations`) yok; `nexus_owner`/`nexus_app` rollerinin bu DB'de sahipliği sıfır; `parallel-*`/`sim-*` rolü yok. Fonksiyon gövdelerindeki `catalog.`/`events.` dizileri `nexus.catalog.categories` gibi sözleşme adlarıdır; şema referansı değildir.
2. **`auth` şeması platform kalıntısı DEĞİL — acentenin kendi oturum şeması.** `002_agency_auth.sql` yaratıyor (`CREATE SCHEMA IF NOT EXISTS auth`); `auth.sessions` + `auth.login/logout/session/switch_role` tümü `agency_app` sahipliğinde ve `src/nexus_agency/auth.gleam` / `router_impl.erl` tarafından aktif çağrılıyor. `agency_auth` ile birlikte ikisi de acenteye aittir; **ASLA düşürülmemeli.** Şema adına bakarak silme kararı verilemez; sahiplik + kod referansı kanıtı şarttır.
3. **`system` şeması meşru** — acente `scripts/migrate.ps1` kitablığı (`system.schema_migrations`).
4. **Tek kalıntı: eski `nexustraveltech` DB (12 MB).** Sahibi `nexus_owner`, aktif bağlantı yok, migration-takipsiz (`system` yok). İçerik: `agency` (91 obje), `agency_auth` (1), `auth` (1), `core` (0) — açıkta kalmış eski bir acente şema kopyası + boş platform şema iskeleti. Canlı platform akışı 5433'tedir; `.env`'ler doğru kümelere işaret ediyor (doğrulandı).
5. **5432'de `nexus_owner` (SÜPERKULLANICI) ve `nexus_app` rolleri duruyor.** `nexus_agency` içinde sahiplikleri yok; eski DB düştükten sonra güvenle düşürülebilirler. `nexus_owner` kendi kendini düşüremez → işlem `postgres` süper kullanıcısıyla yapılmalı.

## Temizlik planı (ONAY BEKLİYOR — çalıştırılmadı)

Ön koşul (mevcut durumda doğru): platform `.env` → 5433/nexustraveltech; acente `.env` → 5432/nexus_agency. Ayrıca her iki `scripts/migrate.ps1` artık iki yönlü yanlış-DB guard'ı içeriyor (acente: `catalog` varsa durur; platform: `agency` varsa durur) — bu tür kirletmelerin yeniden oluşmasını zorlaştırır.

```powershell
# 1) Yedek (5432; nexus_owner şifresi gerekli, bilinmiyorsa postgres süper kullanıcısı)
pg_dump -h 127.0.0.1 -p 5432 -U nexus_owner -d nexustraveltech -Fc -f backup_nexustraveltech_5432.dump

# 2) Eski DB'yi düşür (5432, postgres süper kullanıcısı)
psql -h 127.0.0.1 -p 5432 -U postgres -c "DROP DATABASE IF EXISTS nexustraveltech WITH (FORCE);"

# 3) Roller. Önce doğrudan dene; "objects depend on it" hatası verirse hata mesajındaki
#    DB'de REASSIGN OWNED + DROP OWNED çalıştırıp tekrar dene (kalıntı yoksa no-op).
psql -h 127.0.0.1 -p 5432 -U postgres -c "DROP ROLE IF EXISTS nexus_app;"
psql -h 127.0.0.1 -p 5432 -U postgres -c "DROP ROLE IF EXISTS nexus_owner;"

# 4) Doğrulama
psql -h 127.0.0.1 -p 5432 -U agency_app -d nexus_agency -c "SELECT datname FROM pg_database WHERE NOT datistemplate;"   # nexustraveltech gitmeli
psql -h 127.0.0.1 -p 5432 -U agency_app -d nexus_agency -c "SELECT rolname FROM pg_roles WHERE rolname LIKE 'nexus%';"  # boş dönmeli
# ve acente test zinciri yeşil: scripts/test.ps1
```

Not: Adımlar yalnızca eski DB'ye ve nexus rollerine dokunur; `nexus_agency` içinde `agency`/`agency_auth`/`auth`/`system` şemalarına veri müdahalesi planlanmamıştır. `nexus_owner` 5432'de süperkullanıcıdır; düşürüldükten sonra 5432 kümesinde yalnızca `postgres` ve `agency_app` kalır.
