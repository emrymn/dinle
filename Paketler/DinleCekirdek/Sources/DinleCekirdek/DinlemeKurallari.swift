import Foundation

/// Kaldığın yerden devam, "Bitti" ve akıllı geri sarma kuralları.
public enum DinlemeKurallari {

    /// Bölüm dinlenmiş sayılır mı? %97'si dinlendiyse ya da (10 dk'dan uzun bölümlerde) sona 45 sn'den az kaldıysa.
    public static func bittiMi(konum: Double, sure: Double) -> Bool {
        guard sure > 0, konum > 0, konum.isFinite, sure.isFinite else { return false }
        if konum / sure >= 0.97 { return true }
        return sure >= 600 && sure - konum < 45
    }

    /// Ara verdikten sonra devam ederken kaç saniye geri sarılacağı.
    public static func akilliGeriSarma(ara: TimeInterval) -> TimeInterval {
        switch ara {
        case ..<3: return 0
        case ..<60: return 3
        case ..<600: return 10
        case ..<3600: return 20
        default: return 30
        }
    }

    /// Bir bölüm açılırken nereden başlanacağı: bitmişse ya da sona dayanmışsa baştan.
    public static func devamKonumu(kayitli: Double, sure: Double, bitti: Bool) -> Double {
        guard !bitti, kayitli.isFinite, kayitli > 0 else { return 0 }
        if sure > 0 && kayitli >= sure - 2 { return 0 }
        return kayitli
    }

    /// İlerleme oranı (0…1).
    public static func oran(konum: Double, sure: Double) -> Double {
        guard sure > 0, konum.isFinite, sure.isFinite else { return 0 }
        return min(max(konum / sure, 0), 1)
    }
}
