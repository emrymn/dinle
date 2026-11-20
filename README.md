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
- **Müzik:** Podcastlerden ayrı bir bölüm. Dosyalar'daki şarkıları ekler, sırayla, karışık ya da tekrar modunda çalar.
- **AirPods:**
  - Podcastte iki kez dokunmak ileri, üç kez dokunmak geri atlar. Müzikte sonraki/önceki şarkıya geçer.
  - Kulaktan çıkarınca ses durur ve yer kaydedilir.
- **Hız:** 0,8× – 2,5×.

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

1. ~~İskelet: arka planda çalma, kaldığın yerden devam, dosya ekleme, tasarım~~ **← şu an**
2. RSS / Substack akışları: link yapıştırarak abone ol, bölümleri indir, dosya + akış birleştirme
3. Müzik: albüm/sanatçı listeleri
4. AirPods: takınca devam, baş hareketleri, uyku zamanlayıcısı ve uyku algılama
5. Siri ile devam, Substack girişiyle abonelikleri otomatik çekme, ses iyileştirme, yedekleme
