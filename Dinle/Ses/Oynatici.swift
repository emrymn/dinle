import AVFoundation
import MediaPlayer
import SwiftData
import UIKit
import DinleCekirdek

enum CalmaTuru {
    case podcast, muzik
}

/// Uyku zamanlayıcısı: belli bir saatte ya da çalan bölüm/şarkı bitince durdurur.
enum UykuModu: Equatable {
    case sure(bitis: Date)
    case parcaSonu
}

enum TekrarModu: CaseIterable {
    case kapali, hepsi, tek

    var simge: String {
        switch self {
        case .kapali, .hepsi: return "repeat"
        case .tek: return "repeat.1"
        }
    }

    var sonraki: TekrarModu {
        switch self {
        case .kapali: return .hepsi
        case .hepsi: return .tek
        case .tek: return .kapali
        }
    }
}

/// Uygulamanın tek ses motoru. Podcast ve müzik aynı anda çalmaz; birine geçince diğerinin yeri kaydedilir.
///
/// Arka planda çalma: Info.plist'te `UIBackgroundModes = audio` ve ses oturumu `.playback`.
/// Kaldığın yer: çalarken 5 sn'de bir, duraklatınca, kesintide, parça değişince ve uygulamadan çıkınca kaydedilir.
@MainActor
@Observable
final class Oynatici {

    // MARK: Görünen durum

    private(set) var bolum: Bolum?
    private(set) var sarki: Sarki?
    private(set) var caliyor = false
    private(set) var konum: Double = 0
    private(set) var sure: Double = 0
    private(set) var hiz: Float = Ayarlar.podcastHizi
    private(set) var muzikSirasi: [Sarki] = []
    private(set) var siraIndeksi = 0
    private(set) var karisik = false
    var tekrar: TekrarModu = .kapali
    private(set) var uyku: UykuModu?
    var hata: String?

    var tur: CalmaTuru? {
        if bolum != nil { return .podcast }
        if sarki != nil { return .muzik }
        return nil
    }

    var baslik: String { bolum?.baslik ?? sarki?.baslik ?? "" }

    var altBaslik: String {
        if let bolum { return bolum.program?.ad ?? "" }
        if let sarki { return sarki.sanatci }
        return ""
    }

    var kapak: Data? { bolum?.kapakVerisi ?? sarki?.kapak }

    var oran: Double { DinlemeKurallari.oran(konum: konum, sure: sure) }

    func caliyorMu(_ b: Bolum) -> Bool { bolum === b && caliyor }
    func caliyorMu(_ s: Sarki) -> Bool { sarki === s && caliyor }

    // MARK: İç durum

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private let baglam: ModelContext
    @ObservationIgnored private var zamanGozlemcisi: Any?
    @ObservationIgnored private var durumGozlemcisi: NSKeyValueObservation?
    @ObservationIgnored private var ogeDurumGozlemcisi: NSKeyValueObservation?
    @ObservationIgnored private var bitisGozlemcisi: NSObjectProtocol?
    @ObservationIgnored private var bildirimGozlemcileri: [NSObjectProtocol] = []
    @ObservationIgnored private var sonKayit = Date.distantPast
    /// Akıllı geri sarma için: en son ne zaman duraklatıldı.
    @ObservationIgnored private var duraklatmaAni: Date?
    /// Öğe hazır olmadan istenen konum.
    @ObservationIgnored private var bekleyenKonum: Double?
    /// Öğe hazır olunca çalmaya başla.
    @ObservationIgnored private var hazirOluncaCal = false
    @ObservationIgnored private var kesintideCaliyordu = false
    @ObservationIgnored private var asilSira: [Sarki] = []
    /// Bir klasörden çalınıyorsa o klasörün sırası; yoksa programın sırası kullanılır.
    @ObservationIgnored private var podcastSirasi: [Bolum]?
    @ObservationIgnored private var kapakSanati: MPMediaItemArtwork?

    init(baglam: ModelContext) {
        self.baglam = baglam
        player.automaticallyWaitsToMinimizeStalling = true
        zamanGozlemcisiniKur()
        bildirimleriKur()
        uzaktanKomutlariKur()
        sonCalinaniGeriYukle()
    }

    // MARK: Podcast

    /// Bir bölümü kaldığı yerden çalar; zaten yüklüyse oynat/duraklat yapar.
    /// `sira` verilirse (klasör) bölüm bitince o sıradaki bir sonraki çalar.
    func devamEt(_ b: Bolum, sira: [Bolum]? = nil) {
        if bolum === b {
            if let sira { podcastSirasi = sira }
            oynatDuraklat()
            return
        }
        cal(b, sira: sira)
    }

    func cal(_ b: Bolum, bastan: Bool = false, sira: [Bolum]? = nil) {
        guard let url = b.calinabilirURL else {
            hata = "“\(b.baslik)” bulunamadı. Dosya silinmiş olabilir."
            return
        }
        mevcutuBirak()
        bolum = b
        sarki = nil
        muzikSirasi = []
        asilSira = []
        podcastSirasi = sira
        let baslangic = bastan ? 0 : DinlemeKurallari.devamKonumu(kayitli: b.konum, sure: b.sure, bitti: b.bitti)
        if b.bitti {
            b.bitti = false
            b.konum = 0
        }
        yukle(url: url, baslangic: baslangic, kayitliSure: b.sure, podcast: true)
        // Önceki dinlemeden bu yana geçen süreye göre oynat() biraz geri sarar.
        duraklatmaAni = baslangic > 0 && b.sonDinlenme > .distantPast ? b.sonDinlenme : nil
        oynat()
    }

    func hiziAyarla(_ yeni: Float) {
        hiz = yeni
        Ayarlar.podcastHizi = yeni
        guard tur == .podcast else { return }
        player.defaultRate = yeni
        if caliyor { player.rate = yeni }
        simdiCaliyorBilgisiniGuncelle()
    }

    // MARK: Müzik

    func cal(sarkilar: [Sarki], baslangic: Int, karisikBasla: Bool = false) {
        guard !sarkilar.isEmpty else { return }
        mevcutuBirak()
        asilSira = sarkilar
        if karisikBasla {
            karisik = true
            muzikSirasi = sarkilar.shuffled()
            siraIndeksi = 0
        } else {
            karisik = false
            muzikSirasi = sarkilar
            siraIndeksi = min(max(baslangic, 0), sarkilar.count - 1)
        }
        sarkiyiYukle(muzikSirasi[siraIndeksi], baslangic: 0, cal: true)
    }

    func karisikDegistir() {
        guard tur == .muzik, let mevcut = sarki else { karisik.toggle(); return }
        karisik.toggle()
        if karisik {
            var kalan = asilSira.filter { $0 !== mevcut }
            kalan.shuffle()
            muzikSirasi = [mevcut] + kalan
            siraIndeksi = 0
        } else {
            muzikSirasi = asilSira
            siraIndeksi = asilSira.firstIndex { $0 === mevcut } ?? 0
        }
    }

    func sonrakiSarki() {
        guard !muzikSirasi.isEmpty else { return }
        konumuKaydet()
        if siraIndeksi + 1 < muzikSirasi.count {
            siraIndeksi += 1
        } else if tekrar == .hepsi {
            siraIndeksi = 0
        } else {
            duraklat()
            atla(konuma: 0)
            return
        }
        sarkiyiYukle(muzikSirasi[siraIndeksi], baslangic: 0, cal: true)
    }

    /// `bastanAl`: şarkının 3. saniyesinden sonra basılırsa önce şarkıyı başa alır (ekrandaki düğme).
    /// AirPods'a üç dokunuş her zaman önceki şarkıya geçer.
    func oncekiSarki(bastanAl: Bool = true) {
        guard !muzikSirasi.isEmpty else { return }
        if (bastanAl && konum > 3) || siraIndeksi == 0 {
            atla(konuma: 0)
            return
        }
        konumuKaydet()
        siraIndeksi -= 1
        sarkiyiYukle(muzikSirasi[siraIndeksi], baslangic: 0, cal: true)
    }

    private func sarkiyiYukle(_ s: Sarki, baslangic: Double, cal: Bool) {
        guard let url = s.calinabilirURL else {
            hata = "“\(s.baslik)” bulunamadı."
            return
        }
        bolum = nil
        sarki = s
        yukle(url: url, baslangic: baslangic, kayitliSure: s.sure, podcast: false)
        if cal { oynat() }
    }

    // MARK: Ortak kontroller

    func oynatDuraklat() {
        caliyor ? duraklat() : oynat()
    }

    func oynat() {
        guard player.currentItem != nil else { return }
        Oynatici.oturumuEtkinlestir()

        if tur == .podcast, Ayarlar.akilliGeriSarma, let an = duraklatmaAni {
            let geri = DinlemeKurallari.akilliGeriSarma(ara: Date().timeIntervalSince(an))
            if geri > 0 { atla(konuma: max(0, konum - geri)) }
        }
        duraklatmaAni = nil
        // Duraklatılmışken süresi dolan zamanlayıcı, yeniden oynatınca hemen durdurmasın.
        if let kalan = uykuKalan, kalan <= 0 { uykuIptal() }

        player.defaultRate = tur == .podcast ? hiz : 1
        caliyor = true
        if player.currentItem?.status == .readyToPlay, bekleyenKonum == nil {
            player.play()
        } else {
            hazirOluncaCal = true
        }
        simdiCaliyorBilgisiniGuncelle()
    }

    /// Ses oturumunu ana iş parçacığını bekletmeden açar (Xcode'un "Hang Risk" uyarısı).
    /// AVPlayer çalmaya başlarken oturum zaten açılır; bu yalnızca erkenden hazırlar.
    nonisolated private static let oturumKuyrugu = DispatchQueue(label: "dinle.ses-oturumu", qos: .userInitiated)

    nonisolated private static func oturumuEtkinlestir() {
        oturumKuyrugu.async {
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    func duraklat() {
        hazirOluncaCal = false
        player.pause()
        let caliyordu = caliyor
        caliyor = false
        if caliyordu { duraklatmaAni = Date() }
        konumuKaydet(dinlemeAniniGuncelle: caliyordu)
        simdiCaliyorBilgisiniGuncelle()
    }

    func ileriAtla() { atla(konuma: konum + Ayarlar.ileriAtlama) }
    func geriAtla() { atla(konuma: konum - Ayarlar.geriAtlama) }

    func atla(konuma k: Double) {
        var hedef = max(0, k)
        if sure > 0 { hedef = min(hedef, max(sure - 0.5, 0)) }
        konum = hedef
        if player.currentItem?.status == .readyToPlay {
            player.seek(to: CMTime(seconds: hedef, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor in self?.simdiCaliyorBilgisiniGuncelle() }
            }
        } else {
            bekleyenKonum = hedef
        }
        simdiCaliyorBilgisiniGuncelle()
    }

    /// Silinecek bir bölüm/şarkı çalıyorsa oynatıcıyı boşaltır.
    func silinecek(bolum b: Bolum) {
        if bolum === b { bosalt() }
    }

    func silinecek(sarki s: Sarki) {
        muzikSirasi.removeAll { $0 === s }
        asilSira.removeAll { $0 === s }
        if sarki === s { bosalt() }
    }

    private func bosalt() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        bolum = nil
        sarki = nil
        caliyor = false
        konum = 0
        sure = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: Uyku zamanlayıcısı

    static let uykuSecenekleri = [5, 10, 15, 30, 45, 60, 90]
    /// Son bu kadar saniyede ses yavaşça kısılır.
    private static let kismaSuresi: TimeInterval = 12

    func uykuKur(dakika: Int) {
        uyku = .sure(bitis: Date().addingTimeInterval(TimeInterval(dakika * 60)))
        player.volume = 1
    }

    func uykuParcaSonunda() {
        uyku = .parcaSonu
        player.volume = 1
    }

    func uykuIptal() {
        uyku = nil
        player.volume = 1
    }

    /// Kalan süre (saniye); süreli zamanlayıcı yoksa nil.
    var uykuKalan: TimeInterval? {
        guard case .sure(let bitis) = uyku else { return nil }
        return max(0, bitis.timeIntervalSinceNow)
    }

    /// Çalarken her saniye çağrılır: sona yaklaşınca sesi kısar, süre dolunca durdurur.
    private func uykuyuDenetle() {
        guard let kalan = uykuKalan else { return }
        if kalan <= 0 {
            uyku = nil
            duraklat()
            player.volume = 1
        } else if kalan < Oynatici.kismaSuresi {
            player.volume = Float(kalan / Oynatici.kismaSuresi)
        } else if player.volume < 1 {
            player.volume = 1
        }
    }

    // MARK: Kaydetme

    /// Kaldığın yeri modele yazar. `dinlemeAniniGuncelle` yalnız gerçekten dinlerken/duraklatırken açılır;
    /// böylece akıllı geri sarma "ne kadar ara verdin"i doğru ölçer.
    func konumuKaydet(dinlemeAniniGuncelle: Bool = false) {
        sonKayit = Date()
        if bekleyenKonum == nil, player.currentItem != nil {
            let k = player.currentTime().seconds
            if k.isFinite { konum = k }
        }
        let simdi = Date()
        let dinleniyor = caliyor || dinlemeAniniGuncelle
        if let b = bolum {
            b.konum = konum
            if sure > 0 { b.sure = sure }
            if dinleniyor { b.sonDinlenme = simdi }
            if !b.bitti, DinlemeKurallari.bittiMi(konum: konum, sure: sure) { b.bitti = true }
        } else if let s = sarki {
            s.konum = konum
            if sure > 0 { s.sure = sure }
            if dinleniyor { s.sonCalinma = simdi }
        }
        try? baglam.save()
    }

    private func mevcutuBirak() {
        guard tur != nil else { return }
        player.pause()
        konumuKaydet(dinlemeAniniGuncelle: caliyor)
        caliyor = false
        hazirOluncaCal = false
    }

    // MARK: Yükleme

    private func yukle(url: URL, baslangic: Double, kayitliSure: Double, podcast: Bool) {
        let oge = AVPlayerItem(url: url)
        oge.audioTimePitchAlgorithm = podcast ? .timeDomain : .spectral

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: podcast ? .spokenAudio : .default, policy: .longFormAudio)

        hazirOluncaCal = false
        bekleyenKonum = baslangic > 0 ? baslangic : nil
        konum = baslangic
        sure = kayitliSure
        player.replaceCurrentItem(with: oge)

        ogeDurumGozlemcisi = oge.observe(\.status, options: [.initial, .new]) { [weak self] oge, _ in
            Task { @MainActor in self?.ogeDurumuDegisti(oge) }
        }
        if let bitisGozlemcisi { NotificationCenter.default.removeObserver(bitisGozlemcisi) }
        bitisGozlemcisi = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: oge, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.ogeBitti() }
        }

        kapakSanati = kapak.flatMap { UIImage(data: $0) }.map(Oynatici.sanatYap)
        UserDefaults.standard.set(podcast ? "podcast" : "muzik", forKey: Ayarlar.Anahtar.sonTur)
        komutlariTureGoreAyarla()
        simdiCaliyorBilgisiniGuncelle()
    }

    private func ogeDurumuDegisti(_ oge: AVPlayerItem) {
        guard oge === player.currentItem else { return }
        switch oge.status {
        case .readyToPlay:
            let d = oge.duration.seconds
            if d.isFinite, d > 0 { sure = d }
            if let k = bekleyenKonum {
                bekleyenKonum = nil
                player.seek(to: CMTime(seconds: k, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    Task { @MainActor in self?.hazirsaBasla() }
                }
            } else {
                hazirsaBasla()
            }
        case .failed:
            // Açılışta sessizce hazırlanan öğe açılamadıysa uyarı gösterme; yalnız çalmak istenince.
            if caliyor || hazirOluncaCal { hata = "Bu dosya çalınamadı." }
            caliyor = false
            hazirOluncaCal = false
            simdiCaliyorBilgisiniGuncelle()
        default:
            break
        }
    }

    private func hazirsaBasla() {
        if hazirOluncaCal {
            hazirOluncaCal = false
            player.play()
        }
        simdiCaliyorBilgisiniGuncelle()
    }

    private func ogeBitti() {
        // "Bölüm/şarkı sonunda" zamanlayıcısı: sıradakine geçmeden dur.
        let uykuVakti = uyku == .parcaSonu
        if uykuVakti { uyku = nil }

        if let b = bolum {
            b.bitti = true
            b.konum = 0
            b.sonDinlenme = Date()
            try? baglam.save()
            if !uykuVakti, Ayarlar.sonrakiniCal, let sonraki = sonrakiBolum(b) {
                cal(sonraki, bastan: false, sira: podcastSirasi)
            } else {
                caliyor = false
                konum = 0
                player.seek(to: .zero)
                simdiCaliyorBilgisiniGuncelle()
            }
        } else if sarki != nil {
            if uykuVakti {
                caliyor = false
                atla(konuma: 0)
                konumuKaydet()
            } else if tekrar == .tek {
                atla(konuma: 0)
                player.play()
            } else {
                sonrakiSarki()
            }
        }
    }

    /// Klasörden çalınıyorsa klasörün, yoksa programın ekrandaki sırasında
    /// bu bölümden sonra gelen, bitmemiş ilk bölüm.
    private func sonrakiBolum(_ b: Bolum) -> Bolum? {
        let sira: [Bolum]
        if let podcastSirasi {
            sira = podcastSirasi
        } else if let program = b.program {
            sira = program.siraliBolumler()
        } else {
            return nil
        }
        guard let i = sira.firstIndex(where: { $0 === b }) else { return nil }
        return sira[(i + 1)...].first { !$0.bitti && $0.calinabilirURL != nil }
    }

    // MARK: Açılışta son çalınanı hazırla (çalmadan)

    private func sonCalinaniGeriYukle() {
        if UserDefaults.standard.string(forKey: Ayarlar.Anahtar.sonTur) == "muzik" {
            var tanim = FetchDescriptor<Sarki>(sortBy: [SortDescriptor(\.sonCalinma, order: .reverse)])
            tanim.fetchLimit = 1
            guard let s = try? baglam.fetch(tanim).first, s.sonCalinma > .distantPast else { return }
            let tumu = ((try? baglam.fetch(FetchDescriptor<Sarki>())) ?? [])
                .sorted { $0.baslik.localizedStandardCompare($1.baslik) == .orderedAscending }
            asilSira = tumu
            muzikSirasi = tumu
            siraIndeksi = tumu.firstIndex { $0 === s } ?? 0
            sarkiyiYukle(s, baslangic: s.konum, cal: false)
        } else {
            var tanim = FetchDescriptor<Bolum>(sortBy: [SortDescriptor(\.sonDinlenme, order: .reverse)])
            tanim.fetchLimit = 1
            guard let b = try? baglam.fetch(tanim).first, b.sonDinlenme > .distantPast, !b.bitti,
                  let url = b.calinabilirURL else { return }
            bolum = b
            yukle(url: url, baslangic: DinlemeKurallari.devamKonumu(kayitli: b.konum, sure: b.sure, bitti: b.bitti),
                  kayitliSure: b.sure, podcast: true)
            duraklatmaAni = b.sonDinlenme
        }
    }

    // MARK: Gözlemciler

    private func zamanGozlemcisiniKur() {
        zamanGozlemcisi = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] zaman in
            MainActor.assumeIsolated { self?.zamanIlerledi(zaman.seconds) }
        }
        durumGozlemcisi = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.calmaDurumuDegisti() }
        }
    }

    private func zamanIlerledi(_ s: Double) {
        guard s.isFinite, bekleyenKonum == nil, player.timeControlStatus == .playing else { return }
        konum = s
        if Date().timeIntervalSince(sonKayit) >= 5 { konumuKaydet() }
        uykuyuDenetle()
    }

    /// Sistem dışarıdan durdurduysa (kulaklık çıktı, başka uygulama sesi aldı) durumu eşitle.
    private func calmaDurumuDegisti() {
        let sistemCaliyor = player.timeControlStatus != .paused
        if caliyor, !sistemCaliyor, !hazirOluncaCal, bekleyenKonum == nil, player.currentItem?.status == .readyToPlay {
            caliyor = false
            duraklatmaAni = Date()
            konumuKaydet(dinlemeAniniGuncelle: true)
            simdiCaliyorBilgisiniGuncelle()
        } else if !caliyor, sistemCaliyor {
            caliyor = true
            simdiCaliyorBilgisiniGuncelle()
        }
    }

    private func bildirimleriKur() {
        let merkez = NotificationCenter.default
        let oturum = AVAudioSession.sharedInstance()

        bildirimGozlemcileri.append(merkez.addObserver(forName: AVAudioSession.interruptionNotification, object: oturum, queue: .main) { [weak self] n in
            let bilgi = n.userInfo
            guard let tipDegeri = bilgi?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let tip = AVAudioSession.InterruptionType(rawValue: tipDegeri) else { return }
            let secenekler = AVAudioSession.InterruptionOptions(rawValue: bilgi?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            MainActor.assumeIsolated { self?.kesinti(tip, devamEdilebilir: secenekler.contains(.shouldResume)) }
        })

        bildirimGozlemcileri.append(merkez.addObserver(forName: AVAudioSession.routeChangeNotification, object: oturum, queue: .main) { [weak self] n in
            guard let neden = (n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init) else { return }
            MainActor.assumeIsolated { self?.yolDegisti(neden) }
        })

        bildirimGozlemcileri.append(merkez.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.konumuKaydet() }
        })
        bildirimGozlemcileri.append(merkez.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.konumuKaydet() }
        })
    }

    /// Telefon araması, alarm, Siri…
    private func kesinti(_ tip: AVAudioSession.InterruptionType, devamEdilebilir: Bool) {
        switch tip {
        case .began:
            kesintideCaliyordu = caliyor
            if caliyor {
                caliyor = false
                duraklatmaAni = Date()
                konumuKaydet(dinlemeAniniGuncelle: true)
                simdiCaliyorBilgisiniGuncelle()
            }
        case .ended:
            if kesintideCaliyordu, devamEdilebilir { oynat() }
            kesintideCaliyordu = false
        @unknown default:
            break
        }
    }

    /// Kulaklık çıkınca/bağlantı kopunca durdur (sesin hoparlörden patlamasın).
    private func yolDegisti(_ neden: AVAudioSession.RouteChangeReason) {
        if neden == .oldDeviceUnavailable, caliyor {
            duraklat()
        }
    }

    // MARK: Kilit ekranı ve AirPods

    nonisolated private static func sanatYap(_ resim: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: resim.size) { _ in resim }
    }

    private func simdiCaliyorBilgisiniGuncelle() {
        guard tur != nil else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var bilgi: [String: Any] = [
            MPMediaItemPropertyTitle: baslik,
            MPMediaItemPropertyArtist: altBaslik,
            MPMediaItemPropertyPlaybackDuration: sure,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: konum,
            MPNowPlayingInfoPropertyPlaybackRate: caliyor ? Double(tur == .podcast ? hiz : 1) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let bolum {
            bilgi[MPMediaItemPropertyAlbumTitle] = bolum.program?.ad ?? ""
        } else if let sarki, !sarki.album.isEmpty {
            bilgi[MPMediaItemPropertyAlbumTitle] = sarki.album
        }
        if let kapakSanati { bilgi[MPMediaItemPropertyArtwork] = kapakSanati }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = bilgi
    }

    private func uzaktanKomutlariKur() {
        let m = MPRemoteCommandCenter.shared()

        m.playCommand.addTarget { [weak self] _ in
            self?.oynat(); return .success
        }
        m.pauseCommand.addTarget { [weak self] _ in
            self?.duraklat(); return .success
        }
        m.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.oynatDuraklat(); return .success
        }
        m.changePlaybackPositionCommand.addTarget { [weak self] olay in
            guard let olay = olay as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.atla(konuma: olay.positionTime); return .success
        }
        m.skipForwardCommand.addTarget { [weak self] _ in
            self?.ileriAtla(); return .success
        }
        m.skipBackwardCommand.addTarget { [weak self] _ in
            self?.geriAtla(); return .success
        }
        // AirPods'a iki kez dokunma "sonraki", üç kez dokunma "önceki" komutunu gönderir.
        // Podcastte bunları ileri/geri atlamaya çeviriyoruz.
        m.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.tur == .podcast ? self.ileriAtla() : self.sonrakiSarki()
            return .success
        }
        m.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.tur == .podcast ? self.geriAtla() : self.oncekiSarki(bastanAl: false)
            return .success
        }
        komutlariTureGoreAyarla()
    }

    /// Kilit ekranında podcastte ±sn düğmeleri, müzikte önceki/sonraki görünür.
    func komutlariTureGoreAyarla() {
        let m = MPRemoteCommandCenter.shared()
        let podcast = tur == .podcast
        m.skipForwardCommand.preferredIntervals = [NSNumber(value: Ayarlar.ileriAtlama)]
        m.skipBackwardCommand.preferredIntervals = [NSNumber(value: Ayarlar.geriAtlama)]
        m.skipForwardCommand.isEnabled = podcast
        m.skipBackwardCommand.isEnabled = podcast
        m.nextTrackCommand.isEnabled = tur != nil
        m.previousTrackCommand.isEnabled = tur != nil
        m.changePlaybackPositionCommand.isEnabled = tur != nil
    }
}
