<p align="center">
  <img src="Resources/AppIcon-preview.png" width="128" alt="Kâmus">
</p>

<h1 align="center">Kâmus</h1>

<p align="center">
  macOS menü çubuğundan anında Türkçe sözlük araması.<br>
  Aradığınız her kelimeyi yerel veritabanına kaydeder — zamanla kendi çevrimdışı sözlüğünüz oluşur.
</p>

---

## Özellikler

- **Menü çubuğundan anında erişim** — Dock'ta yer kaplamaz, `⌃⌘L` ile her yerden açılır.
- **Seçili kelimeyi otomatik arar** — herhangi bir uygulamada bir kelime seçip kısayola basın, tanımı doğrudan gelir.
- **Yerel sözlük veritabanı** — her başarılı arama SQLite'a kaydedilir. Kayıtlı kelimeler anında açılır ve **internet olmadan da** çalışır; arka planda sessizce güncellenir.
- **Değiştirilebilir kısayol** — ayarlar panelindeki kaydediciden istediğiniz kombinasyonu atayabilirsiniz.
- **Türkçeye doğru davranır** — büyük/küçük harf dönüşümü `tr_TR` kurallarıyla yapılır, "Işık" ile "ışık" aynı kayda düşer.
- **API anahtarı gerektirmez.**

## Kurulum

Gereksinimler: macOS 12+, Xcode komut satırı araçları.

```bash
git clone https://github.com/mapetek/kamus.git
cd kamus
./build.sh
cp -r Kamus.app /Applications/
open /Applications/Kamus.app
```

`build.sh`, sisteminizde bir "Apple Development" sertifikası varsa uygulamayı onunla imzalar. Bu önemli: imza sabit kaldığı için verdiğiniz sistem izinleri her yeniden derlemede sıfırlanmaz. Sertifika yoksa ad-hoc imzaya düşer ve izinleri her derlemeden sonra yeniden vermeniz gerekir.

## İzinler

Uygulama iki sistem izni ister; ikisi de **isteğe bağlıdır**, vermezseniz uygulama çalışmaya devam eder:

| İzin | Ne için | Verilmezse |
|---|---|---|
| Erişilebilirlik | Başka uygulamalardaki seçili kelimeyi okumak | Kelimeyi elle yazarsınız |
| Input Monitoring | Global kısayolu her uygulamada yakalamak | Kısayol yalnızca uygulama öndeyken çalışır |

İzinler System Settings → Privacy & Security altından verilir; ayarlar panelindeki **Ayarları Aç** düğmesi doğrudan oraya götürür.

> **İzni verdiğiniz hâlde "gerekli" görünüyorsa:** macOS izin kaydını uygulamanın kod imzasına bağlar. Uygulama farklı bir imzayla yeniden derlenip kurulduğunda eski kayıt geçersiz kalır ama listedeki anahtar açık görünmeye devam eder. Çözüm: listeden Kamus'u **"−" ile kaldırın**, uygulamayı yeniden başlatın ve izni bir kez daha verin.

## Kullanım

- `⌃⌘L` — pencereyi aç/kapat (ayarlardan değiştirilebilir).
- Bir kelime seçip kısayola basın — seçili kelime otomatik aranır.
- Menü çubuğundaki simgeye tıklayarak da açabilirsiniz.

## Yerel veritabanı

Her başarılı arama, TDK'dan gelen **ham yanıtla birlikte** şuraya kaydedilir:

```
~/Library/Application Support/Kamus/dictionary.sqlite
```

Ham yanıt saklandığı için uygulamanın bugün göstermediği alanlar da korunur. Biriktirdiklerinizi doğrudan sorgulayabilirsiniz:

```bash
sqlite3 ~/Library/Application\ Support/Kamus/dictionary.sqlite \
  "SELECT word, search_count, datetime(last_searched_at,'unixepoch','localtime') FROM words ORDER BY last_searched_at DESC LIMIT 20;"
```

## Geliştirme

```bash
swift build          # hızlı derleme kontrolü
./build.sh           # .app paketi üretir ve imzalar
python3 scripts/make_icon.py   # uygulama ikonunu yeniden üretir (Pillow gerekir)
```

Kaynaklar `Sources/Kamus/` altında: `KamusApp.swift` (uygulama yaşam döngüsü, global kısayol, seçili metin okuma, ayarlar), `SearchView.swift` (arayüz ve arama modeli), `TDKAPIClient.swift` (API istemcisi ve veri modelleri), `DictionaryStore.swift` (SQLite katmanı).

## Lisans ve kaynak

[MIT](LICENSE) lisansıyla dağıtılır. © 2026 BakedApps.

Kelime verileri Türk Dil Kurumu'nun herkese açık `sozluk.gov.tr` servisinden alınır. **Bu bir Türk Dil Kurumu ürünü değildir**; kurumla resmî bir bağı veya kurumun onayı yoktur. Tüm sözlük içeriğinin hakları Türk Dil Kurumu'na aittir.
