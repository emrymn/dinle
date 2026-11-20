import Foundation

/// Akıştan gelen bölümleri kütüphanedekilerle eşleştirir:
/// aynı bölüm ikinci kez eklenmesin, arşivdeki dosya da akıştaki kaydıyla birleşsin.
public enum AkisEslestirici {

    /// Kütüphanede zaten olan bir bölümün eşleştirmede kullanılan bilgileri.
    public struct Mevcut: Sendable {
        public var akisKimligi: String
        public var uzakAdres: String?
        public var baslik: String
        public var sure: Double
        public var yayinTarihi: Date?

        public init(akisKimligi: String, uzakAdres: String?, baslik: String, sure: Double, yayinTarihi: Date?) {
            self.akisKimligi = akisKimligi
            self.uzakAdres = uzakAdres
            self.baslik = baslik
            self.sure = sure
            self.yayinTarihi = yayinTarihi
        }
    }

    /// Her akış bölümü için eşleşen mevcut bölümün sırası; yeni bölümse nil.
    /// Sıra: aynı akış kimliği → aynı ses adresi → aynı başlık + süre (arşiv dosyası).
    /// Bir mevcut bölüm en çok bir akış bölümüyle eşleşir.
    public static func eslestir(mevcut: [Mevcut], yeni: [AkisBolumu]) -> [Int?] {
        var kullanilan = Set<Int>()
        var kimlikDizini: [String: Int] = [:]
        var adresDizini: [String: Int] = [:]
        for (i, m) in mevcut.enumerated() {
            if !m.akisKimligi.isEmpty { kimlikDizini[m.akisKimligi] = i }
            if let a = m.uzakAdres, !a.isEmpty { adresDizini[a] = i }
        }

        func al(_ i: Int?) -> Int? {
            guard let i, !kullanilan.contains(i) else { return nil }
            kullanilan.insert(i)
            return i
        }

        // 1–2. tur: kimlik ve adres (kesin eşleşmeler önce, başlık eşleşmesi onları çalmasın).
        var sonuc: [Int?] = yeni.map { _ in nil }
        for (j, y) in yeni.enumerated() {
            if let i = al(kimlikDizini[y.kimlik]) ?? al(adresDizini[y.sesAdresi]) {
                sonuc[j] = i
            }
        }
        // 3. tur: başlık + süre; tarih ikisinde de varsa en çok 3 gün fark.
        for (j, y) in yeni.enumerated() where sonuc[j] == nil {
            let aday = mevcut.indices.first { i in
                guard !kullanilan.contains(i), mevcut[i].akisKimligi.isEmpty else { return false }
                let m = mevcut[i]
                guard KopyaDenetimi.ayniKayit(baslik: m.baslik, sure: m.sure, baslik: y.baslik, sure: y.sure) else { return false }
                if let a = m.yayinTarihi, let b = y.yayinTarihi, abs(a.timeIntervalSince(b)) > 3 * 86_400 { return false }
                return true
            }
            sonuc[j] = al(aday)
        }
        return sonuc
    }
}

extension AkisEslestirici {

    /// Önizleme yerine tam bölüm mü geldi (herkese açık akış → özel link)?
    /// Öyleyse eski indirme ve önizlemedeki ilerleme geçersizdir.
    /// Ölçüt süre: bölüm en az 1 dk uzamış olmalı. Yalnız adresin değişmesi yetmez
    /// (bazı sunucular adresleri yeniler; o zaman ilerleme silinmemeli).
    /// Kullanıcının arşivinden eklenmiş dosyalara dokunulmaz.
    public static func sesYenilendi(eskiAdres: String?, yeniAdres: String,
                                    eskiSure: Double, yeniSure: Double, arsivDosyasi: Bool) -> Bool {
        guard !arsivDosyasi, eskiAdres?.isEmpty == false else { return false }
        return eskiSure > 0 && yeniSure > eskiSure + 60
    }
}
