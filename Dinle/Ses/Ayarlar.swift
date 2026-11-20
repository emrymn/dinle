import Foundation

/// Kullanıcı ayarlarının anahtarları ve varsayılanları. Ekranlarda aynı anahtarlar @AppStorage ile kullanılır.
enum Ayarlar {
    enum Anahtar {
        static let akilliGeriSarma = "akilliGeriSarma"
        static let ileriAtlama = "ileriAtlama"
        static let geriAtlama = "geriAtlama"
        static let sonrakiniCal = "sonrakiniCal"
        static let podcastHizi = "podcastHizi"
        static let sonTur = "sonTur"
    }

    static let ileriSecenekleri: [Double] = [15, 30, 45, 60]
    static let geriSecenekleri: [Double] = [10, 15, 30]
    static let hizSecenekleri: [Float] = [0.8, 1.0, 1.2, 1.5, 1.75, 2.0, 2.5]

    private static var d: UserDefaults { .standard }

    static var akilliGeriSarma: Bool { d.object(forKey: Anahtar.akilliGeriSarma) as? Bool ?? true }
    static var sonrakiniCal: Bool { d.object(forKey: Anahtar.sonrakiniCal) as? Bool ?? true }

    static var ileriAtlama: Double {
        let v = d.double(forKey: Anahtar.ileriAtlama)
        return v > 0 ? v : 30
    }

    static var geriAtlama: Double {
        let v = d.double(forKey: Anahtar.geriAtlama)
        return v > 0 ? v : 15
    }

    static var podcastHizi: Float {
        get {
            let v = d.float(forKey: Anahtar.podcastHizi)
            return v > 0 ? v : 1
        }
        set { d.set(newValue, forKey: Anahtar.podcastHizi) }
    }
}
