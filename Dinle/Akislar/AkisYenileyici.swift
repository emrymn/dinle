import Foundation
import SwiftData
import DinleCekirdek

/// Substack / RSS akışlarını bulur, okur ve programlara uygular.
@MainActor
enum AkisYenileyici {

    enum Hata: LocalizedError {
        case gecersizLink
        case bulunamadi
        case sunucu(Int)

        var errorDescription: String? {
            switch self {
            case .gecersizLink: return "Bu bir link gibi görünmüyor."
            case .bulunamadi: return "Bu adreste bir podcast akışı bulunamadı. Ücretli bir abonelikse Substack'teki özel RSS linkini yapıştır."
            case .sunucu(let kod):
                if kod == 401 || kod == 403 { return "Akışa erişim izni yok (\(kod)). Özel RSS linkini yeniden kopyalamayı dene." }
                return "Sunucu hata verdi (\(kod))."
            }
        }
    }

    /// Ağdan akışı indirip ayrıştırır (ana iş parçacığı dışında).
    nonisolated static func oku(_ url: URL) async throws -> AkisBilgisi {
        var istek = URLRequest(url: url, timeoutInterval: 30)
        istek.setValue("Mozilla/5.0 (iPhone) Podcast", forHTTPHeaderField: "User-Agent")
        let (veri, yanit) = try await URLSession.shared.data(for: istek)
        if let h = yanit as? HTTPURLResponse, !(200..<300).contains(h.statusCode) {
            throw Hata.sunucu(h.statusCode)
        }
        do {
            return try RSSAyristirici.ayristir(veri)
        } catch {
            throw Hata.bulunamadi
        }
    }

    /// Kullanıcının yapıştırdığı linkten çalışan ilk akışı bulur.
    static func bul(_ girdi: String) async throws -> (URL, AkisBilgisi) {
        let adaylar = AkisAdresi.adaylar(girdi)
        guard !adaylar.isEmpty else { throw Hata.gecersizLink }
        var sonHata: Error = Hata.bulunamadi
        for url in adaylar {
            do {
                let akis = try await oku(url)
                if !akis.bolumler.isEmpty { return (url, akis) }
            } catch {
                sonHata = error
            }
        }
        throw sonHata
    }

    /// Yeni bir abonelik ekler ya da var olan (arşiv) programa akış bağlar.
    static func ekle(girdi: String, program mevcut: Program?, baglam: ModelContext) async throws -> Program {
        let (url, akis) = try await bul(girdi)
        let adres = url.absoluteString

        // Aynı akış zaten ekliyse onu kullan.
        if mevcut == nil {
            let tumu = (try? baglam.fetch(FetchDescriptor<Program>())) ?? []
            if let ayni = tumu.first(where: { $0.akisAdresi == adres }) {
                uygula(akis, program: ayni, baglam: baglam)
                return ayni
            }
        }

        let program: Program
        if let mevcut {
            program = mevcut
        } else {
            program = Program(ad: akis.baslik.isEmpty ? "Podcast" : akis.baslik)
            baglam.insert(program)
        }
        program.akisAdresi = adres
        if program.kapak == nil, let k = akis.kapakAdresi, let u = URL(string: k),
           let sonuc = try? await URLSession.shared.data(from: u) {
            program.kapak = DosyaIceAktarici.kucukKapak(sonuc.0)
        }
        uygula(akis, program: program, baglam: baglam)
        return program
    }

    /// Akışı programa uygular: eşleşen bölümleri günceller, yenileri ekler. Yeni eklenenleri döndürür.
    @discardableResult
    static func uygula(_ akis: AkisBilgisi, program: Program, baglam: ModelContext) -> [Bolum] {
        let mevcutlar = program.bolumler
        let bilgiler = mevcutlar.map {
            AkisEslestirici.Mevcut(akisKimligi: $0.akisKimligi, uzakAdres: $0.uzakAdres,
                                   baslik: $0.baslik, sure: $0.sure, yayinTarihi: $0.yayinTarihi)
        }
        let eslesme = AkisEslestirici.eslestir(mevcut: bilgiler, yeni: akis.bolumler)
        var yeniler: [Bolum] = []
        for (j, ab) in akis.bolumler.enumerated() {
            let b: Bolum
            if let i = eslesme[j] {
                b = mevcutlar[i]
            } else {
                b = Bolum(baslik: ab.baslik.isEmpty ? "Adsız bölüm" : ab.baslik)
                baglam.insert(b)
                b.program = program
                yeniler.append(b)
            }
            b.akisKimligi = ab.kimlik
            let arsivDosyasi = !b.kaynakAdi.isEmpty
            if AkisEslestirici.sesYenilendi(eskiAdres: b.uzakAdres, yeniAdres: ab.sesAdresi,
                                            eskiSure: b.sure, yeniSure: ab.sure, arsivDosyasi: arsivDosyasi) {
                // Önizleme yerine tam bölüm geldi (özel link): eski indirme ve önizlemedeki ilerleme geçersiz.
                if b.dosyaAdi != nil {
                    MedyaDeposu.sil(b.dosyaAdi)
                    b.dosyaAdi = nil
                }
                b.konum = 0
                b.bitti = false
                b.sure = 0
            }
            b.uzakAdres = ab.sesAdresi
            if let t = ab.yayinTarihi { b.yayinTarihi = t }
            // Akıştaki süre esas; yalnız arşiv dosyasında dosyanın kendi süresi korunur.
            if ab.sure > 0 && (!arsivDosyasi || b.sure <= 0) { b.sure = ab.sure }
            if let a = ab.aciklama { b.aciklama = a }
        }
        if program.yazar == nil { program.yazar = akis.yazar }
        program.sonYenileme = Date()
        try? baglam.save()
        return yeniler
    }

    /// Tek programı yeniler; açıksa yeni bölümleri indirir. Yeni bölüm sayısını döndürür.
    @discardableResult
    static func yenile(_ program: Program, baglam: ModelContext, indirici: Indirici) async throws -> Int {
        guard let adres = program.akisAdresi, let url = URL(string: adres) else { return 0 }
        let akis = try await oku(url)
        let yeniler = uygula(akis, program: program, baglam: baglam)
        if program.otomatikIndir {
            for b in yeniler.sorted(by: { $0.siralamaTarihi > $1.siralamaTarihi }).prefix(5) {
                indirici.indir(b)
            }
        }
        return yeniler.count
    }

    /// Bütün akışları yeniler (son yenilemeden bu yana `aralik` geçtiyse).
    static func hepsiniYenile(baglam: ModelContext, indirici: Indirici, aralik: TimeInterval = 3600) async {
        let programlar = (try? baglam.fetch(FetchDescriptor<Program>())) ?? []
        for p in programlar where p.akisAdresi != nil && Date().timeIntervalSince(p.sonYenileme) > aralik {
            _ = try? await yenile(p, baglam: baglam, indirici: indirici)
        }
    }
}
