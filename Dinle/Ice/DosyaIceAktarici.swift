import AVFoundation
import UIKit
import DinleCekirdek

/// Files'tan seçilen bir ses dosyasının, uygulamaya kopyalandıktan sonraki bilgileri.
struct DosyaBilgisi: Sendable {
    var dosyaAdi: String
    /// Dosyanın asıl adı, uzantısız ("2023-05-14 Bölüm 12").
    var ozgunAd: String
    var baslik: String?
    var sanatci: String?
    var album: String?
    var metaTarih: String?
    var dosyaTarihi: Date?
    var sure: Double = 0
    var kapak: Data?
    /// Dosyanın asıl adı (uzantılı) ve boyutu: kopya denetimi için.
    var kaynakAdi: String = ""
    var kaynakBoyutu: Int64 = 0
    /// Klasör seçildiyse dosyanın içinde durduğu klasörün adı (albüm adı olarak kullanılır).
    var klasorAdi: String?

    /// Başlık yoksa dosya adı.
    var gorunenBaslik: String {
        if let b = baslik?.trimmingCharacters(in: .whitespacesAndNewlines), !b.isEmpty { return b }
        return ozgunAd
    }
}

/// Files'tan seçilen dosyaları ya da klasörleri uygulamanın içine kopyalar ve bilgilerini okur.
enum DosyaIceAktarici {

    static let sesUzantilari: Set<String> = ["mp3", "m4a", "m4b", "aac", "wav", "aif", "aiff", "caf", "flac", "mp4", "alac"]

    struct Sonuc: Sendable {
        var eklenenler: [DosyaBilgisi] = []
        /// Daha önce eklenmiş ya da seçimde iki kez geçen dosyalar.
        var atlanan = 0
    }

    /// `bilinenler`: uygulamada zaten olan dosyaların kimlikleri; bunlar kopyalanmadan atlanır.
    static func iceAktar(_ urller: [URL], bilinenler: Set<KopyaDenetimi.DosyaKimligi>) async -> Sonuc {
        var sonuc = Sonuc()
        var gorulenler = bilinenler
        for url in urller {
            let erisim = url.startAccessingSecurityScopedResource()
            let klasorMu = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            for dosya in sesDosyalari(url) {
                let boyut = Int64((try? dosya.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                let kimlik = KopyaDenetimi.DosyaKimligi(ad: dosya.lastPathComponent, boyut: boyut)
                if gorulenler.contains(kimlik) {
                    sonuc.atlanan += 1
                    continue
                }
                gorulenler.insert(kimlik)
                if var bilgi = await tekDosya(dosya) {
                    bilgi.kaynakAdi = dosya.lastPathComponent
                    bilgi.kaynakBoyutu = boyut
                    if klasorMu { bilgi.klasorAdi = dosya.deletingLastPathComponent().lastPathComponent }
                    sonuc.eklenenler.append(bilgi)
                }
            }
            if erisim { url.stopAccessingSecurityScopedResource() }
        }
        return sonuc
    }

    /// Tek dosyaysa kendisi; klasörse içindeki (alt klasörler dahil) ses dosyaları, ada göre sıralı.
    static func sesDosyalari(_ url: URL) -> [URL] {
        var klasorMu: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &klasorMu) else { return [url] }
        guard klasorMu.boolValue else { return [url] }
        guard let gezgin = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        var liste: [URL] = []
        while let oge = gezgin.nextObject() as? URL {
            if sesUzantilari.contains(oge.pathExtension.lowercased()) { liste.append(oge) }
        }
        return liste.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// iCloud'daki dosyaların inmesini bekleyerek kopyalar.
    private static func koordineliKopyala(_ kaynak: URL) -> String? {
        var ad: String?
        var hata: NSError?
        NSFileCoordinator().coordinate(readingItemAt: kaynak, options: [.withoutChanges], error: &hata) { okunacak in
            ad = try? MedyaDeposu.kopyala(okunacak)
        }
        return ad
    }

    static func tekDosya(_ kaynak: URL) async -> DosyaBilgisi? {
        let dosyaTarihi = (try? kaynak.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]))
            .flatMap { $0.creationDate ?? $0.contentModificationDate }
        guard let ad = koordineliKopyala(kaynak) else { return nil }

        var bilgi = DosyaBilgisi(dosyaAdi: ad, ozgunAd: kaynak.deletingPathExtension().lastPathComponent)
        bilgi.dosyaTarihi = dosyaTarihi

        let varlik = AVURLAsset(url: MedyaDeposu.url(ad))
        if let sure = try? await varlik.load(.duration) {
            let s = CMTimeGetSeconds(sure)
            if s.isFinite, s > 0 { bilgi.sure = s }
        }
        if let ortak = try? await varlik.load(.commonMetadata) {
            for oge in ortak {
                guard let anahtar = oge.commonKey else { continue }
                switch anahtar {
                case .commonKeyTitle: bilgi.baslik = try? await oge.load(.stringValue)
                case .commonKeyArtist: bilgi.sanatci = try? await oge.load(.stringValue)
                case .commonKeyAlbumName: bilgi.album = try? await oge.load(.stringValue)
                case .commonKeyCreationDate: bilgi.metaTarih = try? await oge.load(.stringValue)
                case .commonKeyArtwork:
                    if let veri = try? await oge.load(.dataValue) { bilgi.kapak = kucukKapak(veri) }
                default: break
                }
            }
        }
        if bilgi.metaTarih == nil, let tum = try? await varlik.load(.metadata) {
            let tarihKimlikleri: [AVMetadataIdentifier] = [
                .id3MetadataReleaseTime, .id3MetadataRecordingTime, .id3MetadataDate,
                .id3MetadataYear, .iTunesMetadataReleaseDate, .quickTimeMetadataCreationDate,
            ]
            for kimlik in tarihKimlikleri {
                if let oge = AVMetadataItem.metadataItems(from: tum, filteredByIdentifier: kimlik).first,
                   let metin = try? await oge.load(.stringValue), !metin.isEmpty {
                    bilgi.metaTarih = metin
                    break
                }
            }
        }
        return bilgi
    }

    /// Kapak resmini en çok 600 piksele küçültür (listeler hızlı kalsın).
    static func kucukKapak(_ veri: Data) -> Data? {
        guard let resim = UIImage(data: veri) else { return nil }
        let enBuyuk: CGFloat = 600
        let olcek = min(1, enBuyuk / max(resim.size.width, resim.size.height))
        let boyut = CGSize(width: resim.size.width * olcek, height: resim.size.height * olcek)
        let kucuk = resim.preparingThumbnail(of: boyut) ?? resim
        return kucuk.jpegData(compressionQuality: 0.85)
    }
}
