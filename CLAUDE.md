# Dinle — Claude için notlar

Kişisel podcast + müzik uygulaması (iOS 17+, SwiftUI, SwiftData, AVFoundation). Tek kullanıcı: depo sahibi. Arayüz, yorumlar, commit ve PR metinleri **Türkçe**.

## Çalışma düzeni
- Kod bulut oturumunda (Linux) yazılır; iOS orada derlenemez. Derleme kontrolünü `.github/workflows/ios-derle.yml` yapar (macOS, iOS Simulator, imzasız). PR yeşil olmadan birleştirme yok.
- Kullanıcı Mac'te `git pull` + Xcode ▶ ile telefona yükler (ücretsiz Apple ID, 7 günlük imza).
- Her iş ayrı dal + PR. README'deki "Telefonda deneme listesi"ni değişikliğe göre güncel tut.

## Kurallar
- `Dinle/` klasörü Xcode 16 "senkronize klasör": yeni Swift dosyası eklemek için `project.pbxproj`'a dokunma. Pbxproj'u yalnızca hedef/paket/ayar değişikliğinde düzenle.
- İmzalama (`DEVELOPMENT_TEAM`, paket kimliği) `Config/Local.xcconfig`'te; pbxproj'a yazma.
- Arayüzden bağımsız mantık (tarih çözme, kurallar, biçimler, ileride RSS ayrıştırma) `Paketler/DinleCekirdek`'e girer ve test edilir. Yalnızca Foundation kullan (Linux'ta `swift test` çalışmalı; XMLParser için `#if canImport(FoundationXML)`).
- Swift dil modu 5 (uygulama). Ana aktör: `Oynatici` `@MainActor @Observable`.
- Tek ses motoru `Oynatici`: podcast ve müzik aynı anda çalmaz. Konum kaydı 5 sn'de bir + duraklat/kesinti/parça değişimi/arka plana geçiş.
- Medya dosyaları `Application Support/Medya/<uuid>.<uzantı>`; modelde yalnız dosya adı tutulur.
- Tasarım: `Tema` (beyaz zemin, `Tema.serif` başlıklar, tek vurgu `Tema.vurgu` #FF6719). Yeni ekranlar `Tema.zemin` arka planı ve `.duzSatir()` liste satırları kullanır.

## Test
```bash
swift test --package-path Paketler/DinleCekirdek
```
