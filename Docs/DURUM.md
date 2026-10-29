# Durum ve Yol Haritası

Bu belge projenin 16 Ekim 2026'daki incelemesini ve önerilen sıradaki adımları özetler.

## Özet

UltimateScrollWM, **Paneru motorunu sarmalayan** bir macOS menü çubuğu uygulamasıdır.
Asıl pencere yönetimini gömülü `paneru` binary'si (0.5.2) yapar; uygulama arayüz,
pencere değiştirici, kısayol yönetimi ve paketleme sağlar. Bu, TileMyMac'in ticari
sürümünün izlediği mimarinin aynısıdır.

Uygulama çalışır durumda ve günlük kullanımda pencereleri yönetiyor.

## Mimari

| Katman | Dosya | Görev |
| --- | --- | --- |
| Arayüz | `Views/*` | Menü çubuğu, ayarlar, pencere değiştirici |
| Motor köprüsü | `Engine/PaneruService.swift` | `paneru launch` başlatır, `send-cmd` ile komut yollar |
| Kısayollar | `Engine/HotKeyManager.swift` | Yalnız `⌥Tab` (Carbon `RegisterEventHotKey`) |
| Değiştirici | `Engine/WindowSwitcherController.swift` | `⌥Tab` panelini yönetir |
| AX | `Engine/AccessibilityManager.swift` | Pencere keşfi, izin, taşıma |
| Native motor | `Engine/StripEngine.swift` | **Pasif** (`managesLayout = false`) |

Aktif yol: SwiftUI arayüz + `PaneruService` + `HotKeyManager`.
`StripEngine` ve `AccessibilityManager`'ın taşıma kısmı çalışmıyor; sadece pencere
listesini (değiştirici için) besliyor.

Paneru yapılandırması: `~/Library/Application Support/UltimateScrollWM/config.toml`

## Bugün tamamlanan iyileştirmeler

1. **Sürüm kontrolü**: `git` deposu kuruldu, başlangıç commit'i alındı.
2. **Bozuk derleme giderildi**: eski/karışık `.build` kalıntısı codesign hatası veriyordu;
   temiz yeniden derleme düzeltildi.
3. **Tekrarlanabilir paketleme**: `Makefile` + `Scripts/build-app.sh`.
   İmzalama geçici dizinde yapılıyor (proje `~/Documents` altında olduğu için
   iCloud/fileprovider dosyalara `com.apple.FinderInfo` ekliyor ve codesign bunu
   reddediyordu). Gömülü motora çalışan kurulumdaki kimlik
   (`com.local.UltimateScrollWM.engine`) veriliyor.
4. **README** gerçek SwiftPM akışına göre güncellendi.
5. **Ayarlar → `config.toml` köprüsü**: `PaneruConfig` (minimal TOML düzenleyici) +
   `SettingsStore` (tipli okuma/yazma). Arayüzdeki anahtarlar artık gerçekten paneru
   yapılandırmasına yazılıyor; paneru canlı yeniden yüklediği için değişiklikler
   anında uygulanıyor. Dosyanın geri kalanı (kısayollar, pencere kuralları, yorumlar)
   korunuyor. `PaneruConfig` gerçek `default-config.toml` üzerinde 17 testle doğrulandı.
6. **Zarif kapatma + akıllı açılış**: kapatırken paneru'ya `quit` komutu gönderiliyor
   (gerekirse SIGTERM/SIGINT ile zorlanıyor); ayarlar penceresi artık her açılışta
   değil, yalnızca ilk açılışta, `--settings` bayrağıyla veya izin eksikken açılıyor.
7. **Karartma anahtarı düzeltildi**: yalnızca gündüz değerini (`opacity`) yazıyordu;
   gece değeri (`opacity_night`) dokunulmadığı için gece modunda karartma geri
   geliyordu. Artık ikisi birlikte yazılıyor. Ayrıca `SettingsStore.batch()` ile
   boşluk kaydırıcısı 4 ayrı dosya yazımı yerine tek yazım yapıyor.
8. **Tanılama + izin bekçisi**: `Engine/Diagnostics.swift` uygulamanın
   Erişilebilirlik durumunu `~/Library/Application Support/UltimateScrollWM/durum.txt`
   dosyasına yazar; motorun çıktısı `paneru.log`'a gider. İzin eksikse uygulama 3
   saniyede bir yoklar ve izin gelir gelmez motoru kendisi canlandırır — böylece
   Sistem Ayarları'ndan sonra yeniden başlatmak gerekmez.
9. **Varsayılan config'deki kısayol hatası**: `window_stack` / `window_unstack`
   için `]` yazıyordu; paneru'nun tuş adları arasında `]` yok, bu yüzden
   `invalid key ']'` hatası verip **iki kısayolu sessizce devre dışı bırakıyordu**.
   Doğru ad `rightbracket` (paneru `src/config.rs` sanal tuş haritasından
   doğrulandı). Şablon ve canlı yapılandırma düzeltildi.
10. **Pencere değiştirici düzeltmesi**: Seçici, son tuştan 0.9 sn sonra
    kendiliğinden onaylıyordu; bu yüzden "hemen kapanıyor" gibi görünüp
    gezmek imkânsızdı. Artık macOS `⌘Tab` mantığı var: `⌥` basılı tutulur,
    `Tab` ile gezilir, **`⌥` bırakılınca seçim uygulanır**; `Esc` iptal eder.
    (`⌥` bırakılışı global `flagsChanged` izleyicisiyle yakalanır; kaçırılırsa
    10 sn'lik emniyet zamanlayıcısı paneli kapatır.)
11. **DMG paketleme**: `Scripts/package-dmg.sh` + `make dmg`. Uygulama ve gömülü
    `paneru` Developer ID ile imzalanır, sürükle-bırak DMG üretilir, DMG'nin
    kendisi de imzalanır ve doğrulanır. Kurulum kılavuzu: `Docs/KURULUM.md`.
    Notarization yok (kişisel kullanım); paket yalnızca `arm64`.
12. **Pencere seçici düzeltmesi (⌥Tab)**: Seçici yalnızca iki pencere arasında
    gidip geliyordu ve en fazla 6 pencere gösteriyordu. İki neden vardı:
    (a) 0.8 sn'lik yoklama sayacı ile her basışta çağrılan `refreshWindows()`
    seçimi **gerçek odaktaki pencereye geri sıfırlıyordu** — `Tab` → o+1, sayaç
    sıfırla, `Tab` → yine o+1;
    (b) panelde `min(count, 6)` sınırı vardı.
    Artık liste **oturum başında bir kez** alınır (`beginSwitcherSession`),
    seçici açıkken `refreshWindows` hiç çalışmaz, panel ızgara hâlinde **tüm
    pencereleri** gösterir ve `⌘M` ile simge durumuna küçültülmüş pencereler de
    listelenir (⊖ işaretiyle) — seçilince `raiseWindow` önce uygulamayı öne
    getirip sonra minimize'i kaldırır. Seçicinin gördüğü liste, dışarıdan
    doğrulanabilsin diye `secici.txt` dosyasına yazılır.
13. **Masaüstü filtresi**: Finder'ın masaüstü "penceresi" (başlıksız, ekran
    boyutunda) `⌥Tab` listesinden çıkarıldı — 10 pencere 9'a indi. Filtre
    başlık + boyut + uygulama kimliği üçlüsünü **birlikte** arar, böylece
    gerçek Finder pencereleri yanlışlıkla elenmez. Boyut her ekranla **tek tek**
    karşılaştırılır: ekranların birleşik alanıyla karşılaştırılsaydı çok ekranlı
    kurulumda hiçbir masaüstü birleşik alanı kaplamadığı için filtre çalışmazdı.
    `WindowInfo`'ya `subrole` alanı eklendi ve `secici.txt`'e "rol" sütunu olarak
    yazılıyor (gözlem: hepsi `AXStandardWindow` — yani filtreyi role dayamak
    ayrım sağlamazdı).
14. **Olay tabanlı tazeleme**: 0.8 sn'lik yoklama sayacı kaldırıldı. Pencere
    düzenini paneru yaptığı için (`managesLayout = false`) bu motorun pencere
    listesi **yalnızca arayüzü** besliyordu (menü çubuğundaki pencere sayısı,
    seçici) — buna rağmen her 0.8 sn'de tüm uygulamaların pencereleri
    Erişilebilirlik API'siyle taranıyordu. Artık tazeleme yalnızca:
    `NSWorkspace` bildirimleri (uygulama açıldı/kapandı/ön plana geldi,
    gizlendi/gösterildi, çalışma alanı değişti), menü her açıldığında
    (`onAppear`) ve seçici oturumu başında. Bildirimler 0.35 sn'de birleştirilir.
    **Ölçüm**: uygulama boşta 15 saniyede **0.00 s** CPU harcadı (öncesinde
    sürekli tarama vardı).
15. **Gerçek pencere önizlemeleri (⌥Tab)**: Her hücrede pencerenin gerçek
    görüntüsü. `CGWindowListCreateImage` macOS 15'te **kaldırıldı** — macOS 27
    SDK'sında artık derlenmiyor ("Please use ScreenCaptureKit instead"), bu
    yüzden önizleme **ScreenCaptureKit** ile yapılıyor:
    `SCShareableContent` → `SCContentFilter(desktopIndependentWindow:)` →
    `SCScreenshotManager.captureImage`.
    - AX penceresiyle `SCWindow`, önce **konum + boyut** (ikisi de sol-üst
      orijinli ekran koordinatı kullanır), olmazsa aynı uygulama + **aynı
      başlık** ile eşleştirilir. Bu ikinci deneme minimize pencereler için.
    - Yakalamalar **sırayla** yapılır (`serialized`): 20 hücre aynı anda isterse
      pencere sunucusu boğulur ve panel geç açılır. Sırayla yapınca hücreler
      tek tek dolar, panel hemen tepki verir.
    - Görüntüler önbellekte tutulur (64 kayıt sınırı), aynı pencere tekrar
      yakalanmaz.
    - **Yeni izin gereği:** Ekran Kaydı. İzin yoksa önizleme **sessizce**
      uygulama simgesine düşer — seçici hiçbir durumda bozulmaz. Menü çubuğu
      menüsünde "İzin İste" ve "Ayarları Aç" düğmeleri var. İzin verildikten
      sonra **uygulama yeniden başlatılmalı** (macOS'un kuralı).
16. **Seçicide `✕` ile pencere kapatma**: Her hücrenin sağ üst köşesinde
    kapatma düğmesi; pencerenin `kAXCloseButtonAttribute` düğmesine `AXPress`
    gönderir. Pencere listeden **anında** düşürülür (AX kapatması asenkron
    çalışır), seçim ve panel boyutu buna göre düzeltilir. Kaydedilmemiş
    değişiklik varsa uygulama kendi onay penceresini gösterir.
    - Panel `isFloatingPanel` + `becomesKeyOnlyIfNeeded` + `acceptsFirstMouse`
      ile kuruldu: düğme **tek tıklamayla** çalışır ama uygulama öne gelmez.
    - Tıklama paneli anahtar pencere yapabildiği için `⌥` bırakılışını yakalayan
      **yerel** izleyici de eklendi (yoksa oturum takılı kalırdı).
    - Yerel tuş izleyicisi `Esc`'i **tüketir**: panel anahtar pencereyken Esc
      arkadaki uygulamaya gitmez.
17. **Notarization**: Uygulama ve gömülü `paneru` artık **hardened runtime** ile
    imzalanıyor; DMG Apple'a gönderilip bileti damgalanıyor. Başka bir Mac'te
    Gatekeeper uyarısı çıkmaz. paneru LuaJIT kullandığı için
    `AppBundle/paneru.entitlements` ile JIT entitlement'ları verilir.
    - `make notarize` (gönder + bekle + damgala + `spctl` ile doğrula).
    - Erişilebilirlik izni ve *Designated Requirement* değişmedi: izin
      güncellemede korunuyor.
18. **Boş liste ile `⌥Tab` hatası (0.7.1)**: `beginSwitcherSession()` oturum
    bayrağını pencere listesini almadan **önce** açıyordu. Liste boş döndüğünde
    (ekran kilitli, uyku sonrası ilk saniyeler) seçici erken dönüyor, bayrak ise
    açık kalıyordu. `refreshWindows()` bu bayrak açıkken çalışmadığı için pencere
    listesi **uygulama yeniden başlatılana kadar** donuyordu; ekranda da boş bir
    panel kalabiliyordu.
    - Düzeltme: bayrak yalnızca liste **doluysa** açılıyor; `beginSwitcherSession()`
      `Bool` döndürüyor ve çağıran temizlik yapıyor (`endSession()`).
    - Ek emniyet: panel boyutu ekran alanıyla sınırlandı — içerik ölçümü
      beklenmedik bir değer döndürürse ekranı kaplayan boş panel oluşamaz.
    - Teşhis: boş liste durumu da `secici.txt`'e `pencereSayisi: 0` olarak yazılır.
19. **Seçici kapanış sırası**: `commit()` önce seçimi uyguluyor
    (`activateSwitcherSelection()` → `raiseWindow()`), sonra paneli kapatıyordu.
    Bu Erişilebilirlik çağrısı yavaşlarsa veya bloklanırsa `endSession()`
    hiç çalışmıyor ve panel ekranda takılı kalıyordu. Artık **panel önce
    kapanıyor**, seçim sonra uygulanıyor (seçim bilgisi oturum verisinde
    durduğu için sıra değişimi güvenli).

### Not: "içi boş mavi çerçeve" bir hata değil

Ekranda penceresiz bir alanda duran mavi, yuvarlatılmış çerçeve **paneru'nun
`[decorations.active.border]`** özelliğidir (varsayılan: `#5E9CFF`, 3 px).
Paneru ekran boyutunda görünmez bir kaplama penceresi açıp odaktaki pencerenin
etrafına çizer; odakta görünür pencere yoksa (başka çalışma alanı, küçültülmüş,
masaüstü) geriye sadece çerçeve kalır. Paneru duraklatılınca kaplama penceresi
de kapandığı için çerçeve kaybolur — arıza sanılmasın.
Kapatma: **Ayarlar → Pencere Düzeni → "Odaktaki pencereyi renkli çerçeveyle
göster"** veya `config.toml`'da `enabled = false`.

## Tespit edilen sorunlar

### Yüksek öncelik

| # | Sorun | Yer |
| --- | --- | --- |
| ✅ | ~~`@AppStorage` anahtarları işlevsizdi~~ → `SettingsStore` ile `config.toml`'a bağlandı | çözüldü |
| ✅ | ~~Gap kaydırıcısı etkisizdi~~ → `[padding]` değerlerine yazıyor | çözüldü |
| ✅ | ~~`stop()` SIGINT gönderiyordu~~ → önce `send-cmd quit`, gerekirse SIGTERM/SIGINT | çözüldü |
| 4 | Motor her **0.8 sn**'de tüm pencereleri AX ile tarıyor, sadece değiştirici paneli için → gereksiz maliyet | `StripEngine.swift:38` |

### Orta öncelik

| # | Sorun | Yer |
| --- | --- | --- |
| ✅ | ~~Her açılışta ayarlar penceresi otomatik açılıyordu~~ → yalnızca ilk açılış / `--settings` / izin eksikse | çözüldü |
| 6 | `⌥Tab` global olarak çalınıyor → diğer uygulamalarda `⌥Tab` işlevi eziliyor | `HotKeyManager.swift` |
| 7 | Değiştirici, son tuştan **0.9 sn** sonra sabit gecikmeyle onaylıyor; "⌥ bırakınca seç" yok | `WindowSwitcherController.swift:69` |
| 8 | `focusedWindow()` `unsafeBitCast` kullanıyor (kırılgan) | `AccessibilityManager.swift:106` |
| 9 | Yinelenen minimized kontrolü (`isWindowVisible` + `isMinimized`) | `AccessibilityManager.swift:133` |
| 10 | Sürüm metni arayüzde sabit yazılı | `SettingsView.swift` |
| 11 | `default-config.toml` pencere kuralları Paneru şemasına göre doğrulanmalı | `Resources/default-config.toml` |
| 12 | `XCODE_KURULUM.md` güncelliğini yitirmiş | kök |

### Düşük öncelik

- Güncelleme kontrolü yok.
- Paneru sürümü elle gömülü; yükseltme akışı yok.
- Native `StripEngine`'in geleceği belirsiz (bitirilsin mi, kaldırılsın mı?).

## İmzalama ve Erişilebilirlik izni

`make install` uygulamayı makinede bulunan **Developer ID** kimliğiyle imzalar
(`Makefile` içindeki `SIGN_IDENTITY`). Ad-hoc'a dönmek için `make install SIGN_IDENTITY=-`.

Bu önemli, çünkü ad-hoc imzada (`codesign --sign -`) macOS Erişilebilirlik iznini
ikili dosyanın parmak izine (CDHash) bağlar; kod her derlendiğinde parmak izi
değişir ve izni elle yeniden vermek gerekir. Sabit bir kimlikte macOS izni
sertifikaya bağlar ve izin yeniden derlemelerde korunur.
(`Scripts/build-app.sh` `CODE_SIGN_IDENTITY` değişkenini okur.)

### İzin verirken dikkat

- **macOS 27**, "Erişilebilirlik" bölümünü **"Aygıt Denetimi ve Veri Erişimi"**
  olarak yeniden adlandırdı. Aynı izin, aynı anahtar — sadece adı değişti.
  paneru da hatasında bu yeni adı kullanır.
- İmza kimliği değiştiğinde (ör. ad-hoc → Developer ID) izin bir kez daha
  istenir; macOS `AXIsProcessTrusted` yanıtını **süreç başına önbelleğe** aldığı
  için bayat kaydı **`−` ile silip uygulamanın kendi isteğiyle** yeniden
  eklemek gerekebilir. Anahtarı kapat-aç tek başına yetmeyebilir.
- Sorun çıkarsa tek bakılacak yer: `durum.txt` ve `paneru.log`.

## Dağıtım (DMG) ve bilinen kısıtlar

`make dmg` → `dist/UltimateScrollWM-<sürüm>.dmg`; `make notarize` aynısını üretip
Apple'a gönderir ve bileti damgalar. Uygulama ve gömülü `paneru` Developer ID ile
**hardened runtime** altında imzalanır, DMG'nin kendisi de imzalanır ve doğrulanır.
DMG'deki uygulamanın *Designated Requirement*'ı kurulu sürümle birebir aynı
olduğu için **Erişilebilirlik izni güncellemede korunur**.
Son kullanıcı kılavuzu: `Docs/KURULUM.md`.

### Not 1 — Paket yalnızca `arm64` (Intel Mac'lerde çalışmaz)

Hem uygulama hem gömülü `paneru` `arm64` olarak derleniyor. Evrensel (universal)
paket gerekirse:

1. Rust hedefini ekle: `rustup target add x86_64-apple-darwin`
2. paneru'yu iki mimari için derle:
   `cargo build --release --target aarch64-apple-darwin` ve
   `cargo build --release --target x86_64-apple-darwin`
3. İkisini birleştir:
   `lipo -create -output paneru <arm64>/paneru <x86_64>/paneru`
4. Uygulamayı evrensel derle: `swift build -c release --arch arm64 --arch x86_64`
5. `Scripts/build-app.sh` kopyalama adımı evrensel ikiliyle olduğu gibi çalışır.

### Not 2 — Notarization (tamamlandı)

Uygulama ve gömülü `paneru` **hardened runtime** ile imzalanır
(`--options runtime --timestamp`), DMG Apple'a gönderilir ve bilet damgalanır.
Sonuç: başka bir Mac'te indirilip açıldığında **Gatekeeper uyarısı çıkmaz**.

```bash
# bir kez: kimliği anahtarlığa kaydet (şifre güvenli istemde sorulur)
xcrun notarytool store-credentials UltimateScrollWM \
  --apple-id "APPLE_ID" --team-id Z54BS9LRA2

make notarize     # gönder + bekle + damgala + Gatekeeper ile doğrula
```

Akışın tamamı `Scripts/package-dmg.sh --notarize` içinde; imzalama bayrakları
`Scripts/build-app.sh`.

> ⚠️ **Tuzak:** paneru **LuaJIT** ile derlenmiştir ve LuaJIT arm64'te JIT belleğini
> `mmap(MAP_JIT)` ile ayırır — hardened runtime bunu engeller. Bu yüzden paneru'ya
> `AppBundle/paneru.entitlements` ile `com.apple.security.cs.allow-jit` ve
> `com.apple.security.cs.allow-unsigned-executable-memory` verilir. İkisi de
> Apple'ın notarization için kabul ettiği entitlement'lardır.
>
> Doğrulandı: paneru hardened runtime altında sorunsuz çalışıyor (şerit düzeni
> sağlam), erişilebilirlik izni ve Designated Requirement değişmiyor.

### Lisans

- Bu proje **MIT** (`LICENSE`).
- Gömülü **paneru** 0.5.2 **MIT** (telif: Karinushka@github), değiştirilmeden
  dağıtılır. MIT, telif ve izin metninin dağıtılan kopyaya dahil edilmesini şart
  koştuğu için metin ikilinin yanında taşınır:
  `Sources/UltimateScrollWM/Resources/PANERU_LICENSE.txt` (SwiftPM
  `resources: [.copy("Resources")]` sayesinde pakete kendiliğinden girer).
- Doğrulandı: metin paneru'nun orijinaliyle **birebir** aynı ve hem kurulu
  pakette hem GitHub'daki DMG'de mevcut.
- Ticari kullanım kısıtı yok (MIT "sell copies" iznini açıkça verir); uygulama
  yine de kişisel/ücretsiz kalmak üzere tasarlandı.

## Önerilen yol haritası

1. ✅ **Ayarlar → `config.toml` köprüsü.** Tamamlandı (bkz. yukarı). Genişletilebilir:
   kısayol düzenleyici, pencere kuralları (per-app), ileri düzey paneru seçenekleri.
2. ✅ **Zarif kapatma.** Çıkışta `send-cmd quit` gönderiliyor.
3. ✅ **Açılış davranışı.** Ayarlar penceresi yalnızca ilk açılışta (veya `--settings`
   bayrağıyla) gösteriliyor.
4. ✅ **Pencere değiştirici.** `⌥` bırakılınca onaylama yapıldı (bkz. 10. madde).
   Gerçek pencere önizlemeleri ScreenCaptureKit ile eklendi (bkz. 15. madde),
   hücre başına `✕` kapatma düğmesi eklendi (bkz. 16. madde).
5. ✅ **Olay tabanlı tazeleme.** 0.8 sn'lik yoklama kaldırıldı; `NSWorkspace`
   bildirimleri + menü açılışı (bkz. 14. madde).
6. **İlk kurulum sihirbazı.** İzin/eksik ayar kontrolü ("Mac Setup check").
7. **Karar**: `StripEngine` bitirilecek mi (paneru'suz çalışma) yoksa kaldırılacak mı?
