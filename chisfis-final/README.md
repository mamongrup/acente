# Chisfis — Static Site

`chisfis-nextjs.vercel.app`'den indirilmiş, React/Next.js bağımlılığı olmayan saf statik HTML+CSS+JS sitesi.

## Yayınlama (Netlify / Vercel)

Site tamamen statik — her iki platformda da derleme adımı gerekmez.

### Netlify

**Yöntem 1 — Sürükle-bırak (en hızlı):**
1. https://app.netlify.com/drop adresini açın
2. `chisfis-final` klasörünü tarayıcı penceresine sürükleyin
3. Site yayında — `_headers` dosyasındaki önbellek/güvenlik ayarları otomatik uygulanır

**Yöntem 2 — Git tabanlı (depodan otomatik deploy):**
1. Depoyu GitHub'a push edin (kök dizinde `netlify.toml` olmalı)
2. Netlify > "Add new site" > "Import an existing project"
3. Deploy ayarları `netlify.toml`'dan otomatik okunur (publish: `chisfis-final`)

### Vercel

```bash
npm i -g vercel
vercel --prod
```

Ayrlar `vercel.json`'dan okunur (`outputDirectory: chisfis-final`). `.vercelignore`, çalışma dosyalarının (`chisfis/`, `.freebuff/`, zip) deploy'a dahil olmasını engeller.

### Önemli notlar

- **Kök dizin değil, `chisfis-final` yayınlanır** — çalışma kopyası (`chisfis/`) ve araçlar (`tools/`) sitede görünmez (Vercel'de). Netlify drag-drop'ta zaten yalnızca bu klasörü yüklüyorsunuz.
- `404.html` bilinmeyen yollarda otomatik sunulur (her iki platformda).
- Tüm bağımlılıklar yerel (fontlar, görseller, ikonlar) — harici CDN isteği yok.

## SEO Dosyaları

- **`robots.txt`** — tüm tarayıcılara site genelinde izin verir; yayından sonra içine `Sitemap: https://alan-adiniz.com/sitemap.xml` satırını ekleyin.
- **`sitemap.xml`** — 404 hariç 29 sayfanın tamamını kapsar (anasayfa iki URL ile: `/` ve `index.html`). Yayından önce tüm `https://REPLACE-ME.example` adreslerini gerçek alan adınızla değiştirin (tek bul-değiştir yeterli).

## Kalite Kontrol (Link & Görsel Denetimi)

Tüm sayfalardaki kırık görsel ve ölü linkleri denetlemek için:

```bash
node tools/audit.js
```

Script harici bağımlılık gerektirmez (saf Node.js, Node 14+).
Şunları kontrol eder:

| Denetim | Kapsam |
|---|---|
| `<img src>` / `srcset` / `data-src` | Kırık görsel yolları |
| `<link href>` (`.css`) | Eksik stylesheet'ler |
| `<script src>` | Eksik JS dosyaları |
| CSS `url()` (inline style'lar) | Kırık asset yolları |
| `<a href="*.html">` | Ölü iç sayfa bağlantıları |

Örnek çıktı:

```
Pages scanned:   29
img refs:        365
css url()/link:  116
script refs:     29
anchor .html:    772
----------------------------------
ALL CLEAR — no broken images or dead links.
```

Sorun varsa `[IMG]`, `[HREF]`, `[LINK]`, `[JS]`, `[CSS]` etiketleriyle hangi sayfada ve hangi yolun bozuk olduğu listelenir.

Not: Script yalnızca **statik HTML** içindeki referansları denetler. JS tarafından dinamik oluşturulan bağlantıları (menü, arama modalı vb.) kapsamaz — bunlar `assets/js/main.js` çalıştırıldığında tarayıcıda doğrulanmalıdır.

## Çalıştırma

```bash
node .freebuff/server.js   # port 6291'de sunar
```

http://127.0.0.1:6291/index.html

## Derleme

Kaynak HTML'ler veya görseller değişirse:

```bash
node .freebuff/build.js
```

## Sayfalar (28 adet)

| Sayfa | İçerik |
|---|---|
| `index.html` | Ana sayfa — hero, arama formu, şehir sekmeleri, kartlar, yazarlar |
| `stay-categories.html` | Tüm konaklama kategorileri (144,000+ listings) |
| `flight-categories.html` | Tüm uçuş kategorileri (3,000+ flights) |
| `stay-map-london-uk.html` | London, UK — harita + konaklama (116,288) |
| `stay-map-new-york-usa.html` | New York, USA — harita + konaklama (5,000) |
| `stay-map-tokyo-japan.html` | Tokyo, Japan — harita + konaklama (5,000) |
| `stay-map-paris-france.html` | Paris, France — harita + konaklama (3,000) |
| `stay-map-singapore.html` | Singapore — harita + konaklama (2,500) |
| `stay-map-maldives.html` | Maldives — harita + konaklama (7,500) |
| `stay-map-roma-italy.html` | Roma, Italy — harita + konaklama (8,100) |
| `car.html` | Araba kiralama |
| `experiences.html` | Deneyimler |
| `flights.html` | Uçuş arama |
| `new-york.html` | New York konaklama |
| `listing.html` | Best Western Cedars Hotel detay |
| `real-estate.html` | Emlak (placeholder) |
| `authors.html` | Top 10 yazar |
| `author-truelock-alric.html` | Truelock Alric profil (4.9★, 100 reviews) |
| `author-birrell-chariot.html` | Birrell Chariot profil (4.8★, 120 reviews) |
| `author-foulcher-nathanil.html` | Foulcher Nathanil profil (4.7★, 120 reviews) |
| `author-falconar-agnes.html` | Falconar Agnes profil (4.6★, 111 reviews) |
| `author-tousy-vita.html` | Tousy Vita profil (4.5★, 23 reviews) |
| `author-friar-donna.html` | Friar Donna profil (4.4★, 12 reviews) |
| `author-royal-sergei.html` | Royal Sergei profil (4.3★, 11 reviews) |
| `author-sleite-claudetta.html` | Sleite Claudetta profil (4.2★, 10 reviews) |
| `author-pillifant-vern.html` | Pillifant Vern profil (4.2★, 32 reviews) |
| `author-fones-mimi.html` | Fones Mimi profil (4.2★, 33 reviews) |
| `account.html` | Hesap sayfası (placeholder) |

## Özellikler

- **Dark mode** toggle (localStorage kalıcı)
- **Mobil menü** — tüm sayfalara link veren hamburger menü
- **Mobil alt bar** — Explore, Wishlists, Account, Menu
- **Tema toggle** — masaüstü header'da güneş/ay ikonu
- **Tailwind CSS** — tüm utility sınıfları mevcut
- **Poppins fontu** — Google Fonts'tan indirilmiş
- **0 React/Next.js izi** — data-nimg, headlessui, __next temizlendi
