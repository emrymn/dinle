import Foundation
import SwiftData
import UIKit

/// Akıştan gelen bölümleri telefona indirir.
/// Arka plan oturumu kullanır: uygulama kapansa da indirme sürer, iOS bitince uygulamayı uyandırır.
@MainActor
@Observable
final class Indirici {

    /// Bölüm kimliği → indirme oranı (0…1). Listede olan bölüm iniyor demektir.
    private(set) var ilerleme: [UUID: Double] = [:]

    @ObservationIgnored private let baglam: ModelContext
    @ObservationIgnored private var oturum: URLSession!
    @ObservationIgnored private let temsilci = IndirmeTemsilcisi()

    init(baglam: ModelContext) {
        self.baglam = baglam
        let kimlik = (Bundle.main.bundleIdentifier ?? "dinle") + ".indirme"
        let ayar = URLSessionConfiguration.background(withIdentifier: kimlik)
        ayar.sessionSendsLaunchEvents = true
        ayar.isDiscretionary = false
        temsilci.sahip = self
        oturum = URLSession(configuration: ayar, delegate: temsilci, delegateQueue: nil)

        // Uygulama kapanmadan önce başlamış indirmeleri listeye geri al.
        oturum.getAllTasks { gorevler in
            let kimlikler = gorevler.compactMap { IndirmeTemsilcisi.bolumKimligi($0) }
            Task { @MainActor [weak self] in
                for k in kimlikler where self?.ilerleme[k] == nil { self?.ilerleme[k] = 0 }
            }
        }
    }

    func oran(_ b: Bolum) -> Double? { ilerleme[b.kimlik] }

    func indir(_ b: Bolum) {
        guard !b.indirildi, ilerleme[b.kimlik] == nil,
              let adres = b.uzakAdres, let url = URL(string: adres) else { return }
        var istek = URLRequest(url: url)
        istek.allowsCellularAccess = !Ayarlar.yalnizcaWifi
        let gorev = oturum.downloadTask(with: istek)
        let uzanti = url.pathExtension.isEmpty ? "mp3" : url.pathExtension.lowercased()
        gorev.taskDescription = b.kimlik.uuidString + "|" + uzanti
        ilerleme[b.kimlik] = 0
        gorev.resume()
    }

    func iptal(_ b: Bolum) {
        let k = b.kimlik.uuidString
        oturum.getAllTasks { gorevler in
            for g in gorevler where g.taskDescription?.hasPrefix(k) == true { g.cancel() }
        }
        ilerleme[b.kimlik] = nil
    }

    /// İndirilen dosyayı siler; bölüm internetten çalınmaya devam eder.
    func indirileniSil(_ b: Bolum) {
        guard b.akistan else { return }
        MedyaDeposu.sil(b.dosyaAdi)
        b.dosyaAdi = nil
        try? baglam.save()
    }

    // MARK: Temsilciden

    fileprivate func ilerledi(_ kimlik: UUID, _ oran: Double) {
        ilerleme[kimlik] = oran
    }

    fileprivate func bitti(_ kimlik: UUID, dosyaAdi: String?) {
        ilerleme[kimlik] = nil
        guard let dosyaAdi else { return }
        var tanim = FetchDescriptor<Bolum>(predicate: #Predicate<Bolum> { b in b.kimlik == kimlik })
        tanim.fetchLimit = 1
        if let b = try? baglam.fetch(tanim).first {
            if b.dosyaAdi != dosyaAdi { MedyaDeposu.sil(b.dosyaAdi) }
            b.dosyaAdi = dosyaAdi
            try? baglam.save()
        } else {
            MedyaDeposu.sil(dosyaAdi)
        }
    }
}

/// URLSession arka plan olaylarını alır (kendi kuyruğunda), sonucu ana iş parçacığına iletir.
final class IndirmeTemsilcisi: NSObject, URLSessionDownloadDelegate {
    weak var sahip: Indirici?

    static func bolumKimligi(_ g: URLSessionTask) -> UUID? {
        guard let d = g.taskDescription, let k = d.split(separator: "|").first else { return nil }
        return UUID(uuidString: String(k))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0, let k = Self.bolumKimligi(downloadTask) else { return }
        let oran = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let sahip = self.sahip
        Task { @MainActor in sahip?.ilerledi(k, oran) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let k = Self.bolumKimligi(downloadTask) else { return }
        var ad: String?
        let basarili = (downloadTask.response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? true
        if basarili {
            let uzanti = downloadTask.taskDescription?.split(separator: "|").last.map(String.init) ?? "mp3"
            let yeniAd = UUID().uuidString + "." + uzanti
            // Geçici dosya bu fonksiyon dönünce silinir: hemen taşı.
            if (try? FileManager.default.moveItem(at: location, to: MedyaDeposu.url(yeniAd))) != nil {
                ad = yeniAd
            }
        }
        let sahip = self.sahip
        let sonuc = ad
        Task { @MainActor in sahip?.bitti(k, dosyaAdi: sonuc) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil, let k = Self.bolumKimligi(task) else { return }
        let sahip = self.sahip
        Task { @MainActor in sahip?.bitti(k, dosyaAdi: nil) }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            UygulamaTemsilcisi.arkaPlanTamamlayici?()
            UygulamaTemsilcisi.arkaPlanTamamlayici = nil
        }
    }
}

/// iOS, uygulama kapalıyken biten indirmeler için uygulamayı uyandırınca buraya haber verir.
final class UygulamaTemsilcisi: NSObject, UIApplicationDelegate {
    @MainActor static var arkaPlanTamamlayici: (() -> Void)?

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        UygulamaTemsilcisi.arkaPlanTamamlayici = completionHandler
    }
}
