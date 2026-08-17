# Hızlı Başlangıç

Ayrıntılar için [README](README.md).

## 1. Derle ve kur

```bash
./build.sh
cp -r Kamus.app /Applications/
open /Applications/Kamus.app
```

Uygulama menü çubuğunda 📖 simgesiyle belirir; Dock'ta görünmez.

## 2. Ara

Simgeye tıklayın ya da `⌃⌘L` kısayolunu kullanın, bir kelime yazıp Enter'a basın.

Herhangi bir uygulamada bir kelime **seçip** kısayola basarsanız o kelime doğrudan aranır — bunun için Erişilebilirlik izni gerekir.

## 3. İzinleri ver

Ayarlar panelini açın (alt sağdaki dişli) ve **Ayarları Aç** ile System Settings → Privacy & Security'e gidin:

- **Accessibility** — seçili kelimeyi okuyabilmek için
- **Input Monitoring** — kısayolun her uygulamada çalışması için

İkisi de isteğe bağlıdır; vermezseniz uygulama çalışır, yalnızca ilgili kolaylık devre dışı kalır.

> İzni verdiğiniz hâlde uygulama "gerekli" diyorsa, izin kaydı eskimiş demektir. README'deki [İzinler](README.md#i̇zinler) bölümüne bakın.

## Sorun giderme

**"Uygulama zarar görmüş" hatası** — indirilen sürümlerde karantina özniteliğini kaldırın:

```bash
xattr -rd com.apple.quarantine /Applications/Kamus.app
```

**Sonuç gelmiyor** — internet bağlantınızı kontrol edin. Daha önce aradığınız kelimeler çevrimdışı da açılır; ilk kez aranan bir kelime için bağlantı gerekir.
