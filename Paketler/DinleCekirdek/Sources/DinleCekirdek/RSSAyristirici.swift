import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Bir podcast akışının (RSS) bilgisi.
public struct AkisBilgisi: Equatable, Sendable {
    public var baslik: String = ""
    public var yazar: String?
    public var aciklama: String?
    public var kapakAdresi: String?
    public var bolumler: [AkisBolumu] = []
}

public struct AkisBolumu: Equatable, Sendable {
    /// Akıştaki kalıcı kimlik (guid); yoksa ses adresi.
    public var kimlik: String = ""
    public var baslik: String = ""
    public var aciklama: String?
    public var yayinTarihi: Date?
    public var sesAdresi: String = ""
    public var sure: Double = 0
    public var boyut: Int64 = 0
    public var kapakAdresi: String?
}

public enum RSSHatasi: Error, Equatable {
    case okunamadi(String)
    case akisDegil
}

/// RSS 2.0 + iTunes etiketlerini okur (Substack, Apple Podcasts uyumlu akışlar).
public enum RSSAyristirici {

    public static func ayristir(_ veri: Data) throws -> AkisBilgisi {
        let temsilci = Temsilci()
        let ayristirici = XMLParser(data: veri)
        ayristirici.delegate = temsilci
        ayristirici.shouldProcessNamespaces = false
        guard ayristirici.parse() else {
            throw RSSHatasi.okunamadi(ayristirici.parserError?.localizedDescription ?? "bilinmeyen")
        }
        guard temsilci.kanalVar else { throw RSSHatasi.akisDegil }
        // Ses dosyası olmayan yazıları (yalnız metin) at.
        temsilci.akis.bolumler.removeAll { $0.sesAdresi.isEmpty }
        return temsilci.akis
    }

    // MARK: Süre ve tarih

    /// itunes:duration → saniye. "3600", "1:02:03", "62:03", "3600.5".
    public static func sure(_ metin: String) -> Double {
        let s = metin.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return 0 }
        let parcalar = s.split(separator: ":").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard !parcalar.contains(where: { $0 == nil }) else { return 0 }
        return parcalar.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
    }

    private static let tarihBicimleri: [DateFormatter] = {
        let bicimler = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, d MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, d MMM yyyy HH:mm:ss zzz",
            "EEE, dd MMM yyyy HH:mm Z",
            "dd MMM yyyy HH:mm:ss Z",
            "d MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd",
        ]
        return bicimler.map { b in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = b
            return f
        }
    }()

    /// RFC 822 (RSS pubDate) ve ISO 8601 tarihleri.
    public static func tarih(_ metin: String) -> Date? {
        let s = metin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        for f in tarihBicimleri {
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    // MARK: XMLParser temsilcisi

    private final class Temsilci: NSObject, XMLParserDelegate {
        var akis = AkisBilgisi()
        var kanalVar = false
        private var bolum: AkisBolumu?
        private var guid: String?
        private var metin = ""
        private var yol: [String] = []

        func parser(_ parser: XMLParser, didStartElement ad: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String] = [:]) {
            yol.append(ad)
            metin = ""
            switch ad {
            case "channel":
                kanalVar = true
            case "item", "entry":
                bolum = AkisBolumu()
                guid = nil
            case "enclosure":
                if var b = bolum, let url = attributes["url"], (attributes["type"] ?? "audio").contains("audio") || b.sesAdresi.isEmpty {
                    b.sesAdresi = url
                    b.boyut = Int64(attributes["length"] ?? "") ?? 0
                    bolum = b
                }
            case "itunes:image":
                if let href = attributes["href"] {
                    if bolum != nil { bolum?.kapakAdresi = href } else { akis.kapakAdresi = href }
                }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            metin += string
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            metin += String(decoding: CDATABlock, as: UTF8.self)
        }

        func parser(_ parser: XMLParser, didEndElement ad: String, namespaceURI: String?, qualifiedName: String?) {
            let deger = metin.trimmingCharacters(in: .whitespacesAndNewlines)
            let ust = yol.dropLast().last
            defer {
                yol.removeLast()
                metin = ""
            }

            if var b = bolum {
                switch ad {
                case "title" where ust == "item" || ust == "entry":
                    b.baslik = deger
                case "guid", "id":
                    guid = deger
                case "pubDate", "published":
                    b.yayinTarihi = RSSAyristirici.tarih(deger)
                case "itunes:duration":
                    b.sure = RSSAyristirici.sure(deger)
                case "description", "itunes:summary", "content:encoded":
                    if b.aciklama == nil || ad == "description", !deger.isEmpty { b.aciklama = deger }
                case "item", "entry":
                    b.kimlik = (guid?.isEmpty == false ? guid! : b.sesAdresi)
                    akis.bolumler.append(b)
                    bolum = nil
                    return
                default:
                    break
                }
                bolum = b
                return
            }

            guard ust == "channel" else {
                if ad == "url", ust == "image", akis.kapakAdresi == nil { akis.kapakAdresi = deger }
                return
            }
            switch ad {
            case "title": akis.baslik = deger
            case "itunes:author": akis.yazar = deger
            case "description": akis.aciklama = deger
            default: break
            }
        }
    }
}

/// Kullanıcının yapıştırdığı Substack ya da podcast linkinden denenecek akış adreslerini çıkarır.
public enum AkisAdresi {

    /// "mercurophile", "mercurophile.substack.com", "https://x.substack.com/p/yazi",
    /// özel RSS linki ("…/feed/podcast/123/abc.rss") ya da herhangi bir RSS adresi.
    public static func adaylar(_ girdi: String) -> [URL] {
        var s = girdi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.contains(" ") else { return [] }

        // Yalnızca yayın adı yazıldıysa Substack adresi say.
        if !s.contains(".") && !s.contains("/") {
            s = "\(s.lowercased()).substack.com"
        }
        if s.hasPrefix("feed://") { s = "https://" + s.dropFirst("feed://".count) }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "https://" + s
        }
        guard let url = URL(string: s), let host = url.host, !host.isEmpty else { return [] }

        let yol = url.path.lowercased()
        // Zaten bir akış adresi (özel Substack linki dahil): olduğu gibi kullan.
        if yol.contains("/feed") || yol.hasSuffix(".rss") || yol.hasSuffix(".xml") || url.query?.contains("format=rss") == true {
            return [url]
        }

        var kok = URLComponents()
        kok.scheme = "https"
        kok.host = host
        var sonuc: [URL] = []
        for ek in ["/feed/podcast", "/feed"] {
            kok.path = ek
            if let u = kok.url { sonuc.append(u) }
        }
        // Substack dışı bir site: verilen adresin kendisi de bir akış olabilir.
        if !host.hasSuffix("substack.com") && !yol.isEmpty && yol != "/" {
            sonuc.append(url)
        }
        return sonuc
    }
}
