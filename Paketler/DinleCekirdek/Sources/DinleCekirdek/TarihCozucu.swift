import Foundation

/// Arşivdeki bölümlerin yayın tarihini bulur: dosyanın içindeki bilgiden ya da dosya adından.
public enum TarihCozucu {

    /// Tarihler UTC gün ortasında (12:00) tutulur; saat dilimi farkı günü kaydırmasın.
    static let takvim: Calendar = {
        var t = Calendar(identifier: .gregorian)
        t.timeZone = TimeZone(identifier: "UTC")!
        return t
    }()

    public static func tarih(yil: Int, ay: Int, gun: Int) -> Date? {
        guard (1900...2100).contains(yil), (1...12).contains(ay), (1...31).contains(gun) else { return nil }
        var b = DateComponents()
        b.year = yil; b.month = ay; b.day = gun; b.hour = 12
        guard let d = takvim.date(from: b) else { return nil }
        // 31 Şubat gibi geçersiz günleri ele (Calendar onları sonraki aya taşır).
        let geri = takvim.dateComponents([.year, .month, .day], from: d)
        guard geri.year == yil, geri.month == ay, geri.day == gun else { return nil }
        return d
    }

    private static let aylar: [String: Int] = [
        "ocak": 1, "subat": 2, "mart": 3, "nisan": 4, "mayis": 5, "haziran": 6,
        "temmuz": 7, "agustos": 8, "eylul": 9, "ekim": 10, "kasim": 11, "aralik": 12,
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
        "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7, "aug": 8,
        "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12,
    ]

    /// "Mayıs" → "mayis": büyük/küçük harf ve Türkçe işaretler gözetilmez.
    static func sadelestir(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "ı", with: "i")
            .folding(options: [.diacriticInsensitive], locale: nil)
    }

    private static func eslesmeler(_ desen: String, _ metin: String) -> [[String]] {
        guard let ifade = try? NSRegularExpression(pattern: desen, options: [.caseInsensitive]) else { return [] }
        let ns = metin as NSString
        return ifade.matches(in: metin, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { i in
                let r = m.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
    }

    /// Dosya adındaki tarihi bulur.
    /// Tanınanlar: 2023-05-14, 2023_05_14, 2023.05.14, 2023 05 14, 20230514,
    /// 14.05.2023, 14-05-2023, 14_05_2023, "14 Mayıs 2023", "May 14, 2023".
    public static func dosyaAdindan(_ ad: String) -> Date? {
        let s = sadelestir(ad)
        let ayrac = "[-_. /]"

        // Yıl önce
        for g in eslesmeler("(?<!\\d)((?:19|20)\\d{2})\(ayrac)(\\d{1,2})\(ayrac)(\\d{1,2})(?!\\d)", s) {
            if let d = tarih(yil: Int(g[1])!, ay: Int(g[2])!, gun: Int(g[3])!) { return d }
        }
        // Gün önce
        for g in eslesmeler("(?<!\\d)(\\d{1,2})\(ayrac)(\\d{1,2})\(ayrac)((?:19|20)\\d{2})(?!\\d)", s) {
            if let d = tarih(yil: Int(g[3])!, ay: Int(g[2])!, gun: Int(g[1])!) { return d }
        }
        // Ay adıyla: "14 mayis 2023"
        for g in eslesmeler("(?<!\\d)(\\d{1,2})\\.?\\s+([a-z]+)\\.?,?\\s+((?:19|20)\\d{2})(?!\\d)", s) {
            if let ay = aylar[g[2]], let d = tarih(yil: Int(g[3])!, ay: ay, gun: Int(g[1])!) { return d }
        }
        // Ay adı önce: "may 14, 2023"
        for g in eslesmeler("(?<![a-z])([a-z]+)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+((?:19|20)\\d{2})(?!\\d)", s) {
            if let ay = aylar[g[1]], let d = tarih(yil: Int(g[3])!, ay: ay, gun: Int(g[2])!) { return d }
        }
        // Bitişik: 20230514
        for g in eslesmeler("(?<!\\d)((?:19|20)\\d{2})(\\d{2})(\\d{2})(?!\\d)", s) {
            if let d = tarih(yil: Int(g[1])!, ay: Int(g[2])!, gun: Int(g[3])!) { return d }
        }
        return nil
    }

    public struct MetaTarih: Equatable {
        public let tarih: Date
        /// false: yalnızca yıl biliniyor.
        public let tam: Bool
    }

    /// Dosyanın içindeki tarih bilgisini çözer ("2023-05-14T10:00:00Z", "2023-05-14", "2023").
    public static func metaTarih(_ metin: String) -> MetaTarih? {
        let s = metin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let d = dosyaAdindan(s) { return MetaTarih(tarih: d, tam: true) }
        if let g = eslesmeler("^((?:19|20)\\d{2})(?!\\d)", s).first,
           let d = tarih(yil: Int(g[1])!, ay: 1, gun: 1) {
            return MetaTarih(tarih: d, tam: false)
        }
        return nil
    }

    /// Sıra: dosya içindeki tam tarih → dosya adındaki tarih → dosya içindeki yıl → dosyanın kendi tarihi.
    public static func yayinTarihiBul(metaTarih metin: String?, dosyaAdi: String, dosyaTarihi: Date?) -> Date? {
        let meta = metin.flatMap(metaTarih)
        if let meta, meta.tam { return meta.tarih }
        if let d = dosyaAdindan(dosyaAdi) { return d }
        if let meta { return meta.tarih }
        return dosyaTarihi
    }
}
