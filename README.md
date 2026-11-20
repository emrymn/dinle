# Dinle

Kendi podcast ve müzik uygulamam. Telefonda **Podcast** adıyla görünür (projenin adı Dinle). iPhone'da çalışan bir SwiftUI uygulaması. Görünümü Substack gibi sade: beyaz zemin, serif başlıklar, tek turuncu vurgu, gece modu.

- **Arka planda çalar.** Ekran kilitliyken ya da başka uygulamadayken ses kesilmez. Kilit ekranında ve Denetim Merkezi'nde kontroller ve kapak görünür.
- **Kaldığın yerden devam eder.** Konum 5 sn'de bir ve her duraklatmada kaydedilir. Uygulama kapanıp açılsa da aynı saniyeden başlar. Ara verdiysen, aranın uzunluğuna göre 3–30 sn geri sarar (akıllı geri sarma).
- **Ana Sayfa:** En üstte büyük **Devam et** kartı. Altında yarıda kalanlar ve sıradakiler.
- **Podcastler:** Bir program oluşturursun, arşivindeki dosyaları ya da bütün bir klasörü içine eklersin.
  - Bölümler **yayın tarihine göre** sıralanır. Tarih önce dosyanın içindeki bilgiden, yoksa dosya adından (`2023-05-14`, `14.05.2023`, `14 Mayıs 2023`…), o da yoksa dosya tarihinden alınır.
  - Biten bölüm **Bitti** olarak görünür. Bölümün %97'si dinlendiyse ya da sona 45 sn'den az kaldıysa bitmiş sayılır.
  - Satırı sağa kaydırarak bölümü elle Bitti/Bitmedi yapabilirsin.
  - Bölüm bitince sıradakine geçer.
- **Substack / RSS abonelikleri:** Podcastler'de **+ → Substack / RSS ile abone ol**. Yayının adresini (ya da yalnızca adını) yazman yeter. Ücretli abonelikler için Substack'teki **özel RSS linkini** yapıştır. Bölümler internetten hemen çalar. İstersen telefona indirirsin: satırı sağa kaydırıp **İndir**'e bas ya da programın menüsünden **Yeni bölümleri indir**'i aç. İndirmeler uygulama kapalıyken de sürer. Akışlar uygulama açılınca (en çok saatte bir) ya da sayfayı aşağı çekince yenilenir.
- **Ücretli Substack aboneliği (tam bölümler):** Herkese açık akışta ücretli bölümlerin yalnızca önizlemesi olur. Tam bölümler için programın **⋯ → Özel linkle değiştir**'e bas ve Substack'teki özel RSS linkini yapıştır. Önizlemeler tam bölümlerle değişir.
- **Arşiv + akış birleşir:** Dosyalardan oluşturduğun bir programa menüden **Substack / RSS bağla** dersen, akıştaki bölümler arşivdeki dosyalarla başlık ve süreye göre eşleşir. Aynı bölüm iki kez görünmez, dosyası olanlar indirilmiş sayılır.
- **Klasörler:** Podcastler'de **+ → Yeni klasör** ile adlandırdığın bir klasör aç (ör. "Yolda dinlenecekler"). Bir bölüme basılı tutup **Klasöre ekle**'yi seç ya da bölümü sola kaydırıp **Klasöre**'ye bas. Klasör kendi sırasıyla çalar. Sırayı **Düzenle** ile sürükleyerek değiştirebilirsin.
- **Müzik:** Podcastlerden ayrı bir bölüm. **+ → Albüm klasörü seç** ile bir klasördeki bütün şarkılar tek seferde bir albüm olur. Albüm adı dosyanın içindeki bilgiden alınır, yoksa klasörün adı kullanılır. **Albümler** görünümünde kapaklarıyla listelenir. Albüme dokununca sayfası açılır, oradan hepsini çalabilir ya da karışık çalabilirsin. **Şarkılar** görünümünde bütün şarkılar bir arada durur.
- **Kopyalar eklenmez:** Aynı dosya (aynı ad ve boyut) ya da aynı bölüm/şarkı (aynı başlık ve süre) ikinci kez eklenmez. Ekleme bitince kaç tanesinin atlandığı söylenir.
- **AirPods:**
  - Podcastte iki kez dokunmak ileri, üç kez dokunmak geri atlar. Müzikte iki kez dokunmak sonraki şarkıya, üç kez dokunmak önceki şarkıya geçer.
  - Kulaktan çıkarınca ses durur ve yer kaydedilir.
- **Hız:** 0,8× – 2,5×.
- **Uyku zamanlayıcısı:** Oynatıcıdaki ay simgesinden 5–90 dakika ya da "bölüm/şarkı bitince" seçilir. Son saniyelerde ses yavaşça kısılır, sonra durur ve yerini kaydeder. Kalan süre oynatıcıda ve mini oynatıcıda görünür.

## Elindeki dosyaları aktarma

**iPhone'da Dosyalar'da ya da iCloud Drive'da duruyorsa:**
1. **Podcastler → + → Yeni program (dosyalardan)** ile programa bir ad ver.
2. Programın sayfasında sağ üstteki **⋯ → Klasör seç**'e bas ve bölümlerin durduğu klasörü seç. Alt klasörler de taranır.
3. Bölümler yayın tarihine göre dizilir. Aynı dosyayı tekrar seçersen tekrar eklenmez.

**Mac'te bir klasörde duruyorsa (kabloyla, iCloud gerekmez):**
1. iPhone'u kabloyla bağla. Finder'ın sol tarafında iPhone'una tıkla, sonra üstteki **Dosyalar** sekmesini aç.
2. Listede **Podcast** uygulamasını bul. Mac'teki klasörü sürükleyip onun üstüne bırak.
3. iPhone'da Podcast uygulamasında programı aç ve **⋯ → Klasör seç**'e bas. **iPhone'umda → Podcast** altındaki klasörü seç. Dosyalar uygulamanın içine taşınır, yer iki kez dolmaz.

Başka yollar: Mac'te klasörü **iCloud Drive**'a sürükleyebilir ya da **AirDrop** ile gönderebilirsin (iPhone'da Dosyalar → İndirilenler'e gelir). Sonra yukarıdaki iPhone adımlarını uygula.

Bu bölümler bir Substack yayınına aitse, programın menüsünden **Substack / RSS bağla**'yı da kullan. Dosyalar akıştaki bölümlerle eşleşir, yeni bölümler de kendiliğinden gelir.

## Mac'te ilk kurulum (bir kere)

1. Xcode 16 veya daha yenisi kurulu olsun.
2. Terminal'i aç ve depoyu indir:
   ```bash
   cd ~/Developer 2>/dev/null || cd ~
   git clone https://github.com/emrymn/dinle.git
   cd dinle
   ```
3. Xcode → **Settings → Accounts → +** → Apple ID ile giriş yap.
4. İmzalama ayarını yaz:
   ```bash
   ./kur.sh
   ```
   Bu betik Team ID'ni bulur ve `Config/Local.xcconfig`'i yazar. Bu dosya git'e girmez.
5. Projeyi aç:
   ```bash
   open Dinle.xcodeproj
   ```
6. iPhone'u kabloyla bağla. Xcode'un üstündeki cihaz seçiciden iPhone'unu seç ve **▶** bas.
7. İlk açılışta "Untrusted Developer / Güvenilmeyen Geliştirici" çıkarsa: **Ayarlar → Genel → VPN ve Aygıt Yönetimi** → "Apple Development: …" → **Güven**. iPhone'da Geliştirici Modu kapalıysa **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu**'nu aç ve telefonu yeniden başlat.

> Xcode'daki **Signing & Capabilities** sekmesinden takım seçme. Takım `kur.sh` ile ayarlanıyor. Orada değişiklik yaparsan `git pull` çakışma verebilir.

## Güncelleme (her yeni sürümde)

```bash
cd ~/Developer/dinle && git pull
```

Sonra Xcode'da **▶**. Bu kadar.

**Ücretsiz Apple ID ile:** Uygulama 7 gün sonra açılmaz. O zaman iPhone'u bağlayıp yine **▶**'a basman yeterli. Veriler (eklenen dosyalar, kaldığın yerler) silinmez.

## Telefonda deneme listesi

- [ ] Bir bölüm çalarken ekranı kilitle, 10+ dk bekle. Ses kesilmemeli.
- [ ] Başka bir uygulamaya geç, Safari'de gez. Ses devam etmeli.
- [ ] Kilit ekranında oynat/duraklat, ±sn düğmeleri ve konum çubuğu çalışmalı.
- [ ] Uygulamayı yukarı kaydırıp tamamen kapat, sonra aç. Ana Sayfa'daki **Devam et** kartı aynı yerden başlamalı.
- [ ] Telefon araması gelsin. Arama bitince ses kendiliğinden devam etmeli.
- [ ] AirPods'u kulaktan çıkar. Ses durmalı. Tekrar takıp oynat; birkaç saniye geri sarılmış olmalı.
- [ ] AirPods'a iki kez dokun: 30 sn ileri. Üç kez dokun: 15 sn geri.
- [ ] Bir klasör dolusu dosya ekle. Bölümler tarih sırasıyla gelmeli.
- [ ] Bir bölümü sona kadar dinle. **Bitti** olmalı ve sıradakine geçmeli.
- [ ] Aynı klasörü ikinci kez ekle. "… zaten vardı, tekrar eklenmedi" demeli, liste aynı kalmalı.
- [ ] Bir klasör aç, farklı programlardan bölüm ekle, klasörden çal. Bölüm bitince klasördeki sıradaki çalmalı.
- [ ] Müzik'e bir albüm klasörü ekle. **Albümler**'de tek kart olarak görünmeli.
- [ ] Müzik çalarken AirPods'a üç kez dokun. Önceki şarkıya geçmeli (şarkının başına dönmemeli).
- [ ] Bir Substack yayınına abone ol (ör. yayının adı). Bölümler tarihleriyle gelmeli, dokununca internetten çalmalı.
- [ ] Ücretli bir abonelik için özel RSS linkini yapıştır. Ücretli bölümler de gelmeli.
- [ ] Bir bölümü sağa kaydırıp **İndir**'e bas. Halka dolmalı, bulut simgesi kaybolmalı. Uçak modunda da çalmalı.
- [ ] Arşiv programına aynı yayının akışını bağla. Bölümler iki kez görünmemeli.
- [ ] Uyku zamanlayıcısını 5 dk'ya kur, ekranı kilitle. Ses yavaşça kısılıp durmalı. Tekrar oynatınca kaldığı yerden (birkaç sn geri) devam etmeli.
- [ ] "Bölüm bitince" seç. Bölüm bitince sıradakine geçmeden durmalı.
- [ ] Ana Sayfa boşken içerik ekranın iki yanına kadar uzanmalı, yanlarda siyah şerit olmamalı.

## Geliştirme

```
Dinle.xcodeproj/          Xcode projesi (Dinle/ klasörü "senkronize": yeni dosyalar kendiliğinden projeye girer)
Config/                   Base.xcconfig, Info.plist (arka planda ses), Local.xcconfig (git'e girmez)
Dinle/                    Uygulama
  Uygulama/               Giriş noktası, sekmeler
  Tasarim/                Tema (renkler, serif yazı), ortak parçalar
  Model/                  SwiftData: Program, Bolum, Sarki
  Ses/                    Oynatici (AVPlayer, kilit ekranı, AirPods komutları), Ayarlar
  Ice/                    Dosyalar'dan içe aktarma, medya klasörü
  Ekranlar/               Ana Sayfa, Podcastler, Müzik, Oynatıcı, Ayarlar
Paketler/DinleCekirdek/   Arayüzden bağımsız mantık + testleri (Linux'ta da çalışır)
.github/workflows/        Her PR'da: çekirdek testleri + iOS Simulator derlemesi
```

Çekirdek testleri:

```bash
swift test --package-path Paketler/DinleCekirdek
```

## Yol haritası

1. ~~İskelet: arka planda çalma, kaldığın yerden devam, dosya ekleme, tasarım~~
2. ~~Bölüm klasörleri, müzik albümleri, kopya önleme, AirPods'la şarkı değiştirme, uyku zamanlayıcısı~~
3. ~~Substack / RSS abonelikleri, indirme, arşivle birleştirme~~ **← şu an**
4. AirPods: takınca devam, uyku algılama
5. Ses iyileştirme (konuşmayı netleştirme, sessizlik kısaltma) ve yedekleme
