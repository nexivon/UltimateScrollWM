# UltimateScrollWM

macOS için **kaydırmalı (scrolling) pencere yöneticisi** — menü çubuğunda yaşayan bir
SwiftUI arayüzü, altında [Paneru](https://github.com/karinushka/paneru) motoru (MIT).

Pencereler yan yana bir şeritte durur. Yeni bir pencere açıldığında diğerleri
**küçülmez**; sıradaki boşluğa girer ve şerit, odaktaki pencereyi göstermek için kayar.

## İndirme

Hazır paket (Developer ID ile imzalı ve **notarize edilmiş** DMG, yalnızca Apple Silicon):

**[Son sürümü indir](https://github.com/nexivon/UltimateScrollWM/releases/latest)**

DMG'yi açıp `UltimateScrollWM.app`'i `Applications` klasörüne sürükle. Apple
doğrulamasından geçtiği için **Gatekeeper uyarısı çıkmaz**. Sonra **Aygıt Denetimi
ve Veri Erişimi** iznini ver.

## Kaynaktan derleme

```bash
make install
```

Bu komut release derlemesini yapar, `.app` paketini üretir, geçici dizinde
imzalar ve `/Applications/UltimateScrollWM.app` içine kurar.

İlk açılışta macOS **Aygıt Denetimi ve Veri Erişimi** izni ister (macOS 27'de
"Erişilebilirlik" bölümünün yeni adı):

```
Sistem Ayarları › Gizlilik ve Güvenlik › Aygıt Denetimi ve Veri Erişimi
```

> İzni verdikten birkaç saniye sonra motor **kendiliğinden** başlar; uygulamayı
> yeniden başlatman gerekmez. Ayrıntılı kurulum: [Docs/KURULUM.md](Docs/KURULUM.md)

Diğer komutlar:

```bash
make app      # sadece dist/UltimateScrollWM.app üretir (kurulum yapmaz)
make dmg      # dağıtılabilir DMG üretir (dist/UltimateScrollWM-<sürüm>.dmg)
make run      # kaynaktan doğrudan çalıştırır (geliştirme)
make clean    # derleme çıktılarını temizler
```

## Özellikler

- Menü çubuğu uygulaması (Dock'ta görünmez)
- Gömülü Paneru 0.5.2 motoru ile otomatik pencereleri yönetme
- Ayarlar penceresi: Genel Bakış / Pencere Düzeni / Kısayollar / Gelişmiş
- `⌥Tab` / `⌥⇧Tab` ile Alt-Tab benzeri pencere değiştirici (`⌥` basılı tut,
  `Tab` ile gez, `⌥` bırakınca seç; `Esc` iptal)
- Seçicide **gerçek pencere önizlemeleri** (ScreenCaptureKit; Ekran Kaydı izni
  gerektirir, izin yoksa uygulama simgesine düşer)
- Seçicide hücre başına `✕` ile pencere kapatma
- Erişilebilirlik izni yönlendirmesi
- Mac açılışında başlatma (login item)
- Motoru yeniden başlatma, yapılandırma dosyasını açma

## Varsayılan Kısayollar

Bunlar Paneru motoru tarafından doğrudan yakalanır:

| Kısayol | İşlev |
| --- | --- |
| `⌃⌥ ← / →` | Pencereler arasında geç |
| `⌃⌥⇧ ← / →` | Aktif pencereyi sola / sağa taşı |
| `⌃⌥ R` | Genişliği değiştir |
| `⌃⌥ F` | Tam genişlik |
| `⌃⌥ C` | Ortala |
| `⌃⌥ ] / ⇧]` | Stack'e al / çıkar |
| `⌃⌥ N` | Sonraki ekrana gönder |
| `⌥ Tab` | Pencere değiştirici (bu uygulama) |

## Mimari

Uygulama bir **Paneru sarmalayıcısıdır** (TileMyMac'in yaptığı gibi): asıl pencere
yönetimini gömülü `paneru` binary'si yapar, bu uygulama ona arayüz ve kolaylık sağlar.

```
UltimateScrollWMApp (SwiftUI)
├── MenuBarView / SettingsView / WindowSwitcherView   → arayüz
├── PaneruService        → gömülü paneru'yu başlatır, send-cmd ile komut gönderir
├── HotKeyManager        → ⌥Tab kısayolları (pencere değiştirici)
├── WindowSwitcherController → ⌥Tab panelini yönetir
├── WindowThumbnailProvider  → seçici için pencere görüntüleri (ScreenCaptureKit)
├── AccessibilityManager → pencere keşfi / AX izni
└── StripEngine          → native Swift motor (şu an PASİF, managesLayout = false)
```

Paneru yapılandırması: `~/Library/Application Support/UltimateScrollWM/config.toml`

## Durum ve Yol Haritası

Ayrıntılı inceleme ve önceliklendirilmiş yol haritası: **[`Docs/DURUM.md`](Docs/DURUM.md)**.

## Dağıtım

```bash
make dmg      # -> dist/UltimateScrollWM-<sürüm>.dmg
```

Uygulama ve gömülü `paneru` Developer ID ile imzalanır, DMG'nin kendisi de
imzalanır ve doğrulanır. Son kullanıcı kurulum kılavuzu (Gatekeeper, izin,
güncelleme, kaldırma): **[`Docs/KURULUM.md`](Docs/KURULUM.md)**.

**Kısıtlar**

- Paket yalnızca **`arm64`** (Apple Silicon). Intel Mac'lerde çalışmaz;
  evrensel derleme adımları `Docs/DURUM.md`'de (Not 1).
- Notarization tamamlandı: DMG imzalı **ve** damgalı, Gatekeeper uyarısı çıkmaz.
  Yeniden üretmek için `make notarize` (paneru LuaJIT kullandığı için hardened
  runtime altında `com.apple.security.cs.allow-jit` entitlement'ı gerekir;
  ayrıntı `Docs/DURUM.md` Not 2).

## Proje Yapısı

```
UltimateScrollWM/
├── Makefile
├── Package.swift
├── AppBundle/Info.plist            → .app paketleme şablonu
├── Scripts/build-app.sh            → .app üretici/kurucu
├── Scripts/package-dmg.sh          → imzalı DMG üretici
├── Docs/DURUM.md                   → durum + yol haritası
├── Docs/KURULUM.md                 → son kullanıcı kurulum kılavuzu
└── Sources/UltimateScrollWM/
    ├── App/UltimateScrollWMApp.swift
    ├── Engine/  (PaneruService, StripEngine, AccessibilityManager, HotKeyManager,
    │             WindowSwitcherController, WindowThumbnailProvider, LoginItemManager)
    ├── Models/  (StripState, WindowInfo)
    ├── Views/   (MenuBarView, SettingsView, WindowSwitcherView)
    ├── Utilities/Extensions.swift
    └── Resources/ (paneru binary, default-config.toml, lisans)
```

## Lisans

- **Bu proje:** MIT — bkz. [`LICENSE`](LICENSE).
- **Gömülü motor:** [Paneru](https://github.com/karinushka/paneru) 0.5.2, MIT
  (telif: Karinushka@github). Motor **olduğu gibi, değiştirilmeden** dağıtılır ve
  lisans metni ikilinin yanında taşınır:
  kaynakta `Sources/UltimateScrollWM/Resources/PANERU_LICENSE.txt`, dağıtılan
  pakette `UltimateScrollWM.app/Contents/Resources/…/Resources/PANERU_LICENSE.txt`.
- Uygulamanın geri kalanı (SwiftUI arayüzü, `⌥Tab` seçici, önizlemeler, ayarlar)
  bu projeye aittir.

> MIT lisansı, telif ve izin metninin dağıtılan kopyaya dahil edilmesini şart
> koşar; Paneru'nun metni bu yüzden her DMG'nin içinde bulunur.

## Notlar

- `XCODE_KURULUM.md` eski, elle Xcode kurulumunu anlatır; artık gerekmiyor (SwiftPM kullanılıyor).
