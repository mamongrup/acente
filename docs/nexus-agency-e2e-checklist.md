# NEXUS ↔ Acente entegrasyon e2e checklist

Bu checklist iki projenin birlikte çalışmasının kırılmadığını kanıtlamak için kullanılır.

## Ön koşullar

- NEXUS HTTP servisi çalışır durumda olmalıdır.
- Acente HTTP servisi çalışır durumda olmalıdır.
- İki PostgreSQL instance erişilebilir olmalıdır.
- Acente `.env` içinde NEXUS bağlantı değişkenleri tanımlı olmalıdır.
- Acente tek başına çalışma modu NEXUS kapalıyken de bozulmamalıdır.

## Otomatik kontroller

Tam paket:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-release-readiness.ps1
```

Yalnız REST sözleşme smoke:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-nexus-rest-contract.ps1
```

Yalnız iki proje sözleşme eşitliği:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-two-project-contracts.ps1
```

## Doğrulanan zincir

1. NEXUS `/v1/health` servis ve DB hazır yanıtı verir.
2. Yanlış API anahtarı agency-scoped feed endpointinde 401 döndürür.
3. Doğru API anahtarı agency-scoped listing feed döndürür.
4. Feed içindeki listing için inventory endpoint sözleşmeye uygun yanıt verir.
5. Rezervasyon status webhook şeması ve yetkisi doğrulanır.
6. Acente callback endpointi yanlış anahtarı 401 ile reddeder.
7. Kategori, tedarikçi, ilan, panel modülü ve yönetilebilir filtre sözleşmeleri iki projede eşleşir.

## Manuel e2e simülasyon

Veri aktarım ve reservation webhook simülasyonu için:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run-e2e-simulation.ps1
```

Bu script artık hardcoded DB şifresi taşımaz; gerekli değerleri environment veya `.env` üzerinden bekler.
