#if DEBUG
import Foundation
import SwiftData
import DinleCekirdek

/// Yalnızca geliştirme sürümünde: GitHub'daki ekran görüntüsü işi uygulamayı
/// `-demo` ile açar. Veri bellekte tutulur, gerçek kütüphaneye dokunmaz.
///
/// Açılış argümanları:
///   -demo                 örnek programlar, bölümler ve şarkılar
///   -sekme <ad>           anaSayfa | podcastler | muzik | ayarlar
///   -programAc            Podcastler'de ilk programın sayfasını açar
enum DemoVerisi {

    static var acik: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    static func arguman(_ ad: String) -> String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: ad), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    static var baslangicSekmesi: Sekme {
        switch arguman("-sekme") {
        case "podcastler": return .podcastler
        case "muzik": return .muzik
        case "ayarlar": return .ayarlar
        default: return .anaSayfa
        }
    }

    static var programAc: Bool { ProcessInfo.processInfo.arguments.contains("-programAc") }

    @MainActor
    static func yukle(_ baglam: ModelContext) {
        let program = Program(ad: "Mercurophile Sohbetleri")
        program.eskidenYeniye = true
        baglam.insert(program)

        let basliklar = [
            "Bölüm 1: Başlangıçlar ve ilk sorular",
            "Bölüm 2: Rönesans'ta ışık ve gölge",
            "Bölüm 3: Konuk — Bir koleksiyoncunun hafızası",
            "Bölüm 4: Barok tiyatro, uzun bir sohbet",
            "Bölüm 5: Modernizmin eşiğinde",
            "Bölüm 6: Okur sorularına cevaplar",
        ]
        for (i, baslik) in basliklar.enumerated() {
            let b = Bolum(baslik: baslik)
            b.yayinTarihi = TarihCozucu.tarih(yil: 2023, ay: 3 + i, gun: 14)
            b.sure = Double(2400 + i * 600)
            b.uzakAdres = "https://example.com/bolum\(i + 1).mp3"
            b.program = program
            switch i {
            case 0, 1:
                b.bitti = true
            case 2:
                b.konum = 1260
                b.sonDinlenme = Date().addingTimeInterval(-3600)
            case 3:
                b.konum = 300
                b.sonDinlenme = Date().addingTimeInterval(-86_400)
            default:
                break
            }
            baglam.insert(b)
        }

        let ikinci = Program(ad: "The Antidote")
        baglam.insert(ikinci)
        let b = Bolum(baslik: "Kış özel bölümü")
        b.yayinTarihi = TarihCozucu.tarih(yil: 2024, ay: 12, gun: 1)
        b.sure = 3100
        b.program = ikinci
        baglam.insert(b)

        let sarkilar: [(String, String, String)] = [
            ("Clair de Lune", "Debussy", "Suite bergamasque"),
            ("Gymnopédie No. 1", "Satie", "Gymnopédies"),
            ("Ağır Roman", "Kardeş Türküler", ""),
            ("Nuvole Bianche", "Ludovico Einaudi", "Una Mattina"),
        ]
        for (ad, sanatci, album) in sarkilar {
            let s = Sarki(baslik: ad, sanatci: sanatci, album: album, dosyaAdi: "yok.mp3")
            s.sure = 240
            baglam.insert(s)
        }
        try? baglam.save()
    }
}
#endif
