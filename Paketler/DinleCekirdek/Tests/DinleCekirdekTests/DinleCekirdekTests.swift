import XCTest
@testable import DinleCekirdek

final class TarihCozucuTests: XCTestCase {

    private func gun(_ d: Date?) -> String? {
        guard let d else { return nil }
        let b = TarihCozucu.takvim.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", b.year!, b.month!, b.day!)
    }

    func testDosyaAdiYilOnce() {
        XCTAssertEqual(gun(TarihCozucu.dosyaAdindan("2023-05-14 Bölüm 12")), "2023-05-14")
        XCTAssertEqual(gun(TarihCozucu.dosyaAdindan("program_2023_5_4_son")), "2023-05-04")
        XCTAssertEqual(gun(TarihCozucu.dosyaAdindan("2021.12.31")), "2021-12-31")
    }

    func testDosyaAdiGunOnce() {
        XCTAssertEqual(gun(TarihCozucu.dosyaAdindan("Sohbet 14.05.2023")), "2023-05-14")
        XCTAssertEqual(gun(TarihCozucu.dosyaAdindan("03-11-2019 kayıt")), "2019-11-03")
    }

    func testDosyaAdiAyAdiyla() {
        XCTAssertEqual(gun(TarihCozucu.dosyaAdindan("14 Mayıs 2023 - Konuk")), "2023-05-14")
        XCTAssertEqual(gun(TarihCozucu.dosyaAdindan("1 AĞUSTOS 2020")), "2020-08-01")
        XCTAssertEqual(gun(TarihCozucu.dosyaAdindan("Episode - May 14, 2023")), "2023-05-14")
        XCTAssertEqual(gun(TarihCozucu.dosyaAdindan("2 Şubat 2024")), "2024-02-02")
    }

    func testDosyaAdiBitisik() {
        XCTAssertEqual(gun(TarihCozucu.dosyaAdindan("ep20230514")), "2023-05-14")
    }

    func testGecersizVeTarihsiz() {
        XCTAssertNil(TarihCozucu.dosyaAdindan("Bölüm 12 - Konuk"))
        XCTAssertNil(TarihCozucu.dosyaAdindan("2023-02-31"))
        XCTAssertNil(TarihCozucu.dosyaAdindan("123456789"))
    }

    func testMetaTarih() {
        XCTAssertEqual(gun(TarihCozucu.metaTarih("2023-05-14T10:00:00Z")?.tarih), "2023-05-14")
        XCTAssertEqual(TarihCozucu.metaTarih("2023-05-14")?.tam, true)
        let yil = TarihCozucu.metaTarih("2019")
        XCTAssertEqual(yil?.tam, false)
        XCTAssertEqual(gun(yil?.tarih), "2019-01-01")
        XCTAssertNil(TarihCozucu.metaTarih("  "))
    }

    func testYayinTarihiSirasi() {
        let dosyaTarihi = TarihCozucu.tarih(yil: 2024, ay: 1, gun: 1)
        // Tam meta tarih önce gelir
        XCTAssertEqual(gun(TarihCozucu.yayinTarihiBul(metaTarih: "2020-03-03", dosyaAdi: "2021-04-04", dosyaTarihi: dosyaTarihi)), "2020-03-03")
        // Meta yalnız yılsa dosya adı kazanır
        XCTAssertEqual(gun(TarihCozucu.yayinTarihiBul(metaTarih: "2020", dosyaAdi: "2021-04-04 x", dosyaTarihi: dosyaTarihi)), "2021-04-04")
        // Dosya adında yoksa yıl
        XCTAssertEqual(gun(TarihCozucu.yayinTarihiBul(metaTarih: "2020", dosyaAdi: "Bölüm 1", dosyaTarihi: dosyaTarihi)), "2020-01-01")
        // Hiçbiri yoksa dosyanın kendi tarihi
        XCTAssertEqual(gun(TarihCozucu.yayinTarihiBul(metaTarih: nil, dosyaAdi: "Bölüm 1", dosyaTarihi: dosyaTarihi)), "2024-01-01")
        XCTAssertNil(TarihCozucu.yayinTarihiBul(metaTarih: nil, dosyaAdi: "Bölüm 1", dosyaTarihi: nil))
    }
}

final class DinlemeKurallariTests: XCTestCase {

    func testBitti() {
        XCTAssertFalse(DinlemeKurallari.bittiMi(konum: 0, sure: 3600))
        XCTAssertFalse(DinlemeKurallari.bittiMi(konum: 1800, sure: 3600))
        XCTAssertTrue(DinlemeKurallari.bittiMi(konum: 3560, sure: 3600))   // 40 sn kaldı
        XCTAssertFalse(DinlemeKurallari.bittiMi(konum: 3400, sure: 3600))  // 200 sn kaldı
        XCTAssertTrue(DinlemeKurallari.bittiMi(konum: 98, sure: 100))      // %98
        XCTAssertFalse(DinlemeKurallari.bittiMi(konum: 60, sure: 100))     // kısa dosyada 45 sn kuralı yok
        XCTAssertFalse(DinlemeKurallari.bittiMi(konum: 10, sure: 0))
    }

    func testAkilliGeriSarma() {
        XCTAssertEqual(DinlemeKurallari.akilliGeriSarma(ara: 1), 0)
        XCTAssertEqual(DinlemeKurallari.akilliGeriSarma(ara: 30), 3)
        XCTAssertEqual(DinlemeKurallari.akilliGeriSarma(ara: 300), 10)
        XCTAssertEqual(DinlemeKurallari.akilliGeriSarma(ara: 1800), 20)
        XCTAssertEqual(DinlemeKurallari.akilliGeriSarma(ara: 86_400), 30)
    }

    func testDevamKonumu() {
        XCTAssertEqual(DinlemeKurallari.devamKonumu(kayitli: 754, sure: 3600, bitti: false), 754)
        XCTAssertEqual(DinlemeKurallari.devamKonumu(kayitli: 754, sure: 3600, bitti: true), 0)
        XCTAssertEqual(DinlemeKurallari.devamKonumu(kayitli: 3599, sure: 3600, bitti: false), 0)
        XCTAssertEqual(DinlemeKurallari.devamKonumu(kayitli: -5, sure: 3600, bitti: false), 0)
        XCTAssertEqual(DinlemeKurallari.devamKonumu(kayitli: .nan, sure: 3600, bitti: false), 0)
    }

    func testOran() {
        XCTAssertEqual(DinlemeKurallari.oran(konum: 30, sure: 60), 0.5)
        XCTAssertEqual(DinlemeKurallari.oran(konum: 90, sure: 60), 1)
        XCTAssertEqual(DinlemeKurallari.oran(konum: 30, sure: 0), 0)
    }
}

final class BicimTests: XCTestCase {

    func testZaman() {
        XCTAssertEqual(Bicim.zaman(5), "0:05")
        XCTAssertEqual(Bicim.zaman(725), "12:05")
        XCTAssertEqual(Bicim.zaman(3725), "1:02:05")
        XCTAssertEqual(Bicim.zaman(.nan), "0:00")
    }

    func testSure() {
        XCTAssertEqual(Bicim.sure(20), "1 dk")
        XCTAssertEqual(Bicim.sure(45 * 60), "45 dk")
        XCTAssertEqual(Bicim.sure(72 * 60), "1 sa 12 dk")
        XCTAssertEqual(Bicim.sure(7200), "2 sa")
        XCTAssertEqual(Bicim.sure(0), "")
        XCTAssertEqual(Bicim.kalan(konum: 600, sure: 1320), "12 dk kaldı")
    }

    func testTarih() {
        let d = TarihCozucu.tarih(yil: 2023, ay: 5, gun: 14)!
        XCTAssertEqual(Bicim.tarih(d, takvim: TarihCozucu.takvim), "14 Mayıs 2023")
    }

    func testHiz() {
        XCTAssertEqual(Bicim.hiz(1), "1×")
        XCTAssertEqual(Bicim.hiz(1.5), "1,5×")
        XCTAssertEqual(Bicim.hiz(1.75), "1,75×")
    }

    func testBoyut() {
        XCTAssertEqual(Bicim.boyut(512 * 1_048_576), "512 MB")
        XCTAssertEqual(Bicim.boyut(Int64(1.2 * 1024 * 1_048_576)), "1,2 GB")
    }
}

final class KopyaDenetimiTests: XCTestCase {

    func testDosyaKimligi() {
        let a = KopyaDenetimi.DosyaKimligi(ad: "Bölüm 3.MP3", boyut: 1000)
        let b = KopyaDenetimi.DosyaKimligi(ad: "bölüm 3.mp3", boyut: 1000)
        let c = KopyaDenetimi.DosyaKimligi(ad: "bölüm 3.mp3", boyut: 1001)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(Set([a, b, c]).count, 2)
    }

    func testAyniKayit() {
        XCTAssertTrue(KopyaDenetimi.ayniKayit(baslik: "Bölüm 3 – Konuk", sure: 3600, baslik: "  bolum 3 - KONUK ", sure: 3601))
        XCTAssertFalse(KopyaDenetimi.ayniKayit(baslik: "Bölüm 3", sure: 3600, baslik: "Bölüm 3", sure: 3700))
        XCTAssertTrue(KopyaDenetimi.ayniKayit(baslik: "Bölüm 3", sure: 0, baslik: "Bölüm 3", sure: 3700))
        XCTAssertFalse(KopyaDenetimi.ayniKayit(baslik: "Bölüm 3", sure: 10, baslik: "Bölüm 4", sure: 10))
        XCTAssertFalse(KopyaDenetimi.ayniKayit(baslik: "", sure: 10, baslik: "", sure: 10))
        XCTAssertTrue(KopyaDenetimi.ayniKayit(baslik: "Işık", sure: 10, baslik: "ışık", sure: 10))
    }
}
