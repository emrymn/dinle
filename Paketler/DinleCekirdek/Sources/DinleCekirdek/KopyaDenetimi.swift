import Foundation

/// Aynı dosyanın ya da aynı bölümün/şarkının ikinci kez eklenmesini önler.
public enum KopyaDenetimi {

    /// Dosya kimliği: adı (büyük/küçük harf gözetmeden) + bayt cinsinden boyutu.
    public struct DosyaKimligi: Hashable, Sendable {
        public let ad: String
        public let boyut: Int64

        public init(ad: String, boyut: Int64) {
            self.ad = KopyaDenetimi.sadelestir(ad)
            self.boyut = boyut
        }
    }

    /// "  Bölüm 3 – Konuk " → "bolum 3 - konuk": karşılaştırma için sadeleştirir.
    public static func sadelestir(_ s: String) -> String {
        let kucuk = s.lowercased()
            .replacingOccurrences(of: "ı", with: "i")
            .folding(options: [.diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        return kucuk.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Başlığı aynı ve süresi (biliniyorsa) en çok 2 sn farklı ise aynı kayıt sayılır.
    public static func ayniKayit(baslik a: String, sure sa: Double, baslik b: String, sure sb: Double) -> Bool {
        guard sadelestir(a) == sadelestir(b), !sadelestir(a).isEmpty else { return false }
        if sa > 0 && sb > 0 { return abs(sa - sb) <= 2 }
        return true
    }
}
