import Foundation

/// Uygulamaya eklenen ses dosyalarının durduğu klasör (Application Support/Medya).
/// Modelde yalnız dosya adı tutulur: uygulama güncellenince klasörün tam yolu değişebilir.
enum MedyaDeposu {

    static var klasor: URL {
        let destek = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let k = destek.appendingPathComponent("Medya", isDirectory: true)
        if !FileManager.default.fileExists(atPath: k.path) {
            try? FileManager.default.createDirectory(at: k, withIntermediateDirectories: true)
        }
        return k
    }

    static func url(_ ad: String) -> URL {
        klasor.appendingPathComponent(ad)
    }

    static func sil(_ ad: String?) {
        guard let ad, !ad.isEmpty else { return }
        try? FileManager.default.removeItem(at: url(ad))
    }

    /// Uygulamanın Finder/Dosyalar'da görünen "Belgeler" klasörü (Mac'ten kabloyla atılan dosyalar buraya gelir).
    static var belgeler: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Dosyayı klasöre benzersiz bir adla alır, yeni adı döndürür.
    /// Kaynak uygulamanın kendi Belgeler klasöründeyse kopyalamak yerine taşır (yer iki kez dolmasın).
    static func kopyala(_ kaynak: URL) throws -> String {
        let uzanti = kaynak.pathExtension.isEmpty ? "m4a" : kaynak.pathExtension.lowercased()
        let ad = UUID().uuidString + "." + uzanti
        let belgelerYolu = belgeler.standardizedFileURL.resolvingSymlinksInPath().path
        let kaynakYolu = kaynak.standardizedFileURL.resolvingSymlinksInPath().path
        if kaynakYolu.hasPrefix(belgelerYolu + "/") {
            try FileManager.default.moveItem(at: kaynak, to: url(ad))
        } else {
            try FileManager.default.copyItem(at: kaynak, to: url(ad))
        }
        return ad
    }

    static func kullanilanAlan() -> Int64 {
        let anahtarlar: [URLResourceKey] = [.fileSizeKey]
        guard let liste = try? FileManager.default.contentsOfDirectory(at: klasor, includingPropertiesForKeys: anahtarlar) else { return 0 }
        return liste.reduce(Int64(0)) { toplam, url in
            toplam + Int64((try? url.resourceValues(forKeys: Set(anahtarlar)))?.fileSize ?? 0)
        }
    }
}
