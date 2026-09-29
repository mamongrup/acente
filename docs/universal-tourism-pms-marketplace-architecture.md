# Evrensel Turizm İşletim Sistemi (Universal Tourism OS & PMS) ve Çift Vitrinli Pazaryeri Mimarisi
**Sürüm:** 1.0.0 — **Tarih:** 29 Eylül 2026  
**Kapsam:** `C:\laragon\www\Nexustraveltech` (Platform / Tedarikçi PMS) & `C:\laragon\www\acente` (Acente / Pazaryeri Vitrini)

---

## 1. Vizyon ve Stratejik Konumlandırma

### 1.1. Sektördeki Boşluk ve ElektraWeb Analizi
ElektraWeb ve türevi geleneksel PMS yazılımları, yalnızca **otelcilik** operasyonlarına (oda, yatak, resepsiyon folyosu, gece denetimi) odaklıdır. Günümüz turizm pazarında hızla büyüyen villa/tatil evi, yat charter, günübirlik tur, rehberli aktivite, VIP transfer ve şezlong gibi kategoriler bu sistemlerde ya hiç desteklenmemekte ya da eğreti çözümlerle yönetilmeye çalışılmaktadır.

### 1.2. Yeni Nesil Çözümümüz
Bu mimari iki kardeş projeyi bir araya getirerek sektöre **"17 Kanonik Kategorili Evrensel Turizm İşletim Sistemi"** sunar:
1. **NEXUS Travel Tech (`Nexustraveltech`):** 17 kategoriyi destekleyen merkezi tedarikçi PMS'i, B2B envanter dağıtım havuzu, resmi bildirim köprüleri (KBS, U-ETDS, Liman) ve hakediş mutabakat çekirdeği.
2. **Acente & Pazaryeri (`acente`):** Dış tedarikçilerin kendi ilanlarını önyüzden ekleyebildiği self-service platform ve iki hedef kitleye özel çalışan çift vitrinli pazar yeri:
   - `rezervasyonyap.com.tr` (Yerli Pazar · B2C · TRY · ParamPOS)
   - `reservationinturkey.com` (Global Pazar · Çok Dilli · EUR/USD · Stripe/Uluslararası Ödeme)

---

## 2. Plan A: NEXUS Travel Tech (`Nexustraveltech`)
*Merkezi Tedarikçi & Platform İşletim Sistemi (Universal Tourism PMS)*

### 2.1. 17 Kategoriye Özel Operasyon & Varlık Yönetimi Motoru
Her kategori kendi operasyonel gerçekliğine uygun varlık modelleriyle yönetilir:
- **`hotel` (Otel):** Oda tipleri, pansiyon modelleri (UAI, AI, BB), kat planı, resepsiyon folyosu, gece denetimi (night audit).
- **`holiday_home` (Tatil Evi & Villa):** Müstakil villa envanteri, hasar depozito blokesi, temizlikçi/bahçıvan görev takvimi, giriş-çıkış fotoğraflı hasar denetimi.
- **`yacht` (Yat & Tekne):** Kabin veya tam kiralama, kaptan/mürettebat atama, liman bağlama, kumanya ve yakıt ikmal seyir defteri.
- **`tour` & `activity` (Tur & Aktivite):** Seans/slot yönetimi, kontenjan, rehber ve servis aracı ataması, mobil yolcu yoklama listesi.
- **`car` & `transfer` (Araç & VIP Transfer):** Araç filosu, şoför dispatch, plaka takibi, uçuş numarasıyla otomatik rötar/gecikme senkronizasyonu.
- **`beach` (Şezlong & Beach Club):** QR kodlu interaktif şezlong haritası, gün boyu doluluk takibi, minimum harcama kuralları.
- **`pilgrimage` (Hac & Umre):** Kafile yönetimi, Diyanet/Bakanlık kota takibi, Mekke-Medine otel ve transfer paketlemesi.
- **Diğer Kategoriler:** `flight`, `cruise`, `visa`, `ferry`, `cinema`, `event`, `restaurant`, `bus` kendi sözleşme ve bilet/voucher kurallarıyla çalışır.

### 2.2. Resmi Bildirim & Yasal Uyumluluk Köprüsü
- **Emniyet / Jandarma KBS Entegrasyonu:** Otel ve villalar için misafir TC/Pasaport bilgilerinin resmi KBS formatında tek tıkla iletimi.
- **U-ETDS Entegrasyonu:** Transfer ve tur yolcularının Ulaştırma Bakanlığı zorunlu U-ETDS sistemine anında bildirimi.
- **Liman Başkanlığı & Seyir İzinleri:** Yat ve tekneler için dijital seyir izin belgesi evrak üretimi.

### 2.3. B2B Envanter Dağıtım & Takas Havuzu (Channel Manager)
- Tedarikçilerin tek merkezden ilan açarak tüm bağlı acentelere toptan/komisyonlu satış yetkisi verebilmesi.
- 2 yönlü takvim entegrasyonu (iCal, Airbnb, Booking.com, Vrbo, Viator, GetYourGuide).

### 2.4. Finans, Hakediş & Cari Hesap Merkezi
- Komisyon hesaplama motoru (%10-%20 platform komisyonu).
- QNB Dijital Köprü e-Fatura / e-Arşiv otomatik entegrasyonu.
- Tedarikçi onaylı hakediş havuzu (Escrow) ve banka transfer dökümleri.

---

## 3. Plan B: Acente & Çift Vitrinli Pazaryeri (`acente`)
*Önyüz İlan Toplama, Çift Alan Adlı Vitrin ve Acente Operasyonu*

### 3.1. Önyüz "İlanını Ekle / Tedarikçi Ol" Sihirbazı (`/ilan-ver`)
Dış tedarikçilerin sisteme doğrudan başvurup ilan oluşturabilmesi:
1. **Adım 1 - Kategori & Bölge Seçimi:** 17 kanonik kategoriden biri seçilir, il/ilçe/mahalle belirlenir.
2. **Adım 2 - İlan Özellikleri & Kapasite:** Kategoriye özel dinamik alanlar (oda sayısı, yatak, banyo, klima, havuz, bagaj vb.).
   - *AI Fast-Fill Desteği:* Broşür veya serbest metin yapıştırıldığında yapay zeka alanları otomatik doldurur.
3. **Adım 3 - Görseller & Başlık/Açıklama:** Sürükle-bırak fotoğraf yükleme, SEO uyumlu başlık ve açıklama.
4. **Adım 4 - Fiyatlandırma & Takvim:** Gecelik veya kişi başı taban fiyat, para birimi, sezonluk fiyatlar, minimum konaklama kuralı.
5. **Adım 5 - İşletme & Resmi Evrak Doğrulama:** Şirket/şahıs bilgileri, yetkili kimliği, Türsab Belgesi / Turizm Ruhsatı / Vergi Levhası.
6. **Onay Aşaması:** İlan `pending_review` olarak kaydedilir; acente yöneticisine bildirim düşer.

### 3.2. Çift Alan Adı Vitrini (Dual-Domain Storefront)
Aynı ilan kataloğu, iki farklı alan adında hedeflenen kitleye göre vitrine çıkar:

| Özellik | `rezervasyonyap.com.tr` | `reservationinturkey.com` |
|---|---|---|
| **Hedef Kitle** | Türkiye içi yerli tatilciler | Uluslararası turistler (İngiltere, Avrupa, Körfez, BDT) |
| **Dil** | Türkçe (Varsayılan) | Çok Dilli (İngilizce, Almanca, Rusça, Fransızca, Arapça, Farsça) |
| **Para Birimi** | ₺ TRY (Taksitli seçenekler) | € EUR / $ USD / £ GBP |
| **Ödeme Yöntemi** | ParamPOS, yerli kredi kartı taksitleri, havale | Stripe, uluslararası kartlar, 3D Secure |
| **Öne Çıkanlar** | Hafta sonu villaları, erken rezervasyon otelleri | Havalimanı VIP transfer, rehberli turlar, mavi yolculuk yatları |
| **SEO & İçerik** | Türkçe yerel SEO kelimeleri ve bloglar | Çok dilli AI seyahat rehberleri ve destinasyon sayfaları |

### 3.3. Tedarikçi İçin "Hafif Portal" (Lightweight Supplier Portal)
İlanı onaylanan tedarikçinin erişebileceği sade ve mobil uyumlu yönetim ekranı:
- Canlı takvim (tarih kapatma/açma, iCal takvim senkronu).
- Fiyat güncelleme (sezonluk ve hafta sonu fiyatı).
- Gelen rezervasyon bildirimleri ve misafir check-in kartı.
- Hakediş ve ödeme takibi.

### 3.4. 4'lü AI Co-Pilot Entegrasyonu
- **Dinamik Fiyatlandırma:** Sezon ve doluluğa göre taban fiyat önerisi.
- **İtibar Yönetimi:** Misafir değerlendirmelerine çift alternatifli kurumsal yanıt.
- **Çapraz Satış:** Konaklama yanına tekne, transfer ve tur sepeti ekleme.
- **WhatsApp Destek:** Misafir sorularına tek tıkla WhatsApp Web'den yanıt verme.

---

## 4. Uygulama ve Üretim Yol Haritası

```
Aşama 1: Önyüz İlan Ekleme Sihirbazı (/ilan-ver) ve Veri Modeli
   │
   ├─► 17 kategoriye uyumlu çok adımlı ilan formu
   ├─► AI Fast-fill entegrasyonu
   └─► Belge yükleme ve pending_review durum makinesi
   │
Aşama 2: Çift Alan Adı (Multi-Domain) Vitrin Yönlendirmesi
   │
   ├─► Host header analizi (rezervasyonyap.com.tr vs reservationinturkey.com)
   ├─► Para birimi (TRY vs EUR/USD) ve locale motoru
   └─► Çok dilli SEO ve vitrin kartları
   │
Aşama 3: Tedarikçi Hafif Portalı (Supplier Mobile Portal)
   │
   ├─► Tedarikçi kimlik doğrulama ve rol yalıtımı
   ├─► Mobil uyumlu takvim ve fiyat düzenleyici
   └─► Gelen rezervasyon onay ekranı
   │
Aşama 4: NEXUS B2B & Resmi Bildirimler (PMS Entegrasyonları)
   │
   ├─► KBS / U-ETDS bildirim formatlayıcıları
   ├─► B2B acente dağıtım havuzu ve komisyon takası
   └─► QNB Dijital Köprü e-Fatura ve hakediş mutabakatı
```

---

## 5. Başarı Kriterleri
1. Dışarıdan bir villa veya otel sahibi, acenteyi aramadan `/ilan-ver` üzerinden 5 dakikada ilanını ekleyebilmelidir.
2. Acente panelinden onaylanan ilan hem `rezervasyonyap.com.tr` hem de `reservationinturkey.com` sitelerinde anında doğru para birimi ve dille yayına girmelidir.
3. Çift alan adı vitrininde çifte rezervasyon (overbooking) kilitleri ve yarış koşulu korumaları çalışmalıdır.
4. Tedarikçi kendi panelinden tarih kapattığında her iki vitrinde de takvim anında kilitlenmelidir.
