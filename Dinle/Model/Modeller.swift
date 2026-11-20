import Foundation
import SwiftData
import DinleCekirdek

/// Bir podcast programı: dosyalardan oluşan arşiv ya da (2. aşamada) bir RSS/Substack akışı.
@Model
final class Program {
    var kimlik: UUID = UUID()
    var ad: String = ""
    var yazar: String?
    @Attribute(.externalStorage) var kapak: Data?
    var akisAdresi: String?
    var eklenmeTarihi: Date = Date()
    var eskidenYeniye: Bool = true
    var bitenleriGizle: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Bolum.program)
    var bolumler: [Bolum] = []

    init(ad: String) {
        self.ad = ad
    }

    /// Ekrandaki sıra: yayın tarihine göre (yoksa eklenme tarihine), aynı günse başlığa göre.
    func siraliBolumler() -> [Bolum] {
        let artan = eskidenYeniye
        return bolumler.sorted { a, b in
            let ta = a.siralamaTarihi, tb = b.siralamaTarihi
            if ta != tb { return artan ? ta < tb : ta > tb }
            let k = a.baslik.localizedStandardCompare(b.baslik)
            return artan ? k == .orderedAscending : k == .orderedDescending
        }
    }

    var bitenSayisi: Int { bolumler.filter(\.bitti).count }
}

enum BolumDurumu {
    case yeni, yarida, bitti
}

@Model
final class Bolum {
    var kimlik: UUID = UUID()
    var baslik: String = ""
    var aciklama: String?
    var yayinTarihi: Date?
    /// Saniye; bilinmiyorsa 0.
    var sure: Double = 0
    /// Kaldığın yer (saniye).
    var konum: Double = 0
    var bitti: Bool = false
    /// En son ne zaman dinlendi; hiç dinlenmediyse distantPast.
    var sonDinlenme: Date = Date.distantPast
    var eklenmeTarihi: Date = Date()
    /// Uygulamanın içindeki dosya (Application Support/Medya).
    var dosyaAdi: String?
    /// Akıştan gelen bölümün internet adresi (2. aşama).
    var uzakAdres: String?
    @Attribute(.externalStorage) var kapak: Data?
    var program: Program?

    init(baslik: String) {
        self.baslik = baslik
    }

    var durum: BolumDurumu {
        if bitti { return .bitti }
        return konum > 1 ? .yarida : .yeni
    }

    var siralamaTarihi: Date { yayinTarihi ?? eklenmeTarihi }

    var kapakVerisi: Data? { kapak ?? program?.kapak }

    /// Çalınabilecek adres: önce telefondaki dosya, yoksa internetteki.
    var calinabilirURL: URL? {
        if let dosyaAdi {
            let url = MedyaDeposu.url(dosyaAdi)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        if let uzakAdres { return URL(string: uzakAdres) }
        return nil
    }
}

@Model
final class Sarki {
    var kimlik: UUID = UUID()
    var baslik: String = ""
    var sanatci: String = ""
    var album: String = ""
    var sure: Double = 0
    var konum: Double = 0
    var dosyaAdi: String = ""
    @Attribute(.externalStorage) var kapak: Data?
    var sonCalinma: Date = Date.distantPast
    var eklenmeTarihi: Date = Date()

    init(baslik: String, sanatci: String, album: String, dosyaAdi: String) {
        self.baslik = baslik
        self.sanatci = sanatci
        self.album = album
        self.dosyaAdi = dosyaAdi
    }

    var calinabilirURL: URL? {
        let url = MedyaDeposu.url(dosyaAdi)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
