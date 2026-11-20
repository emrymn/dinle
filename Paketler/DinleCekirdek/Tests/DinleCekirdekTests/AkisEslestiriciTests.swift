import XCTest
@testable import DinleCekirdek

final class AkisEslestiriciTests: XCTestCase {

    private func akis(_ kimlik: String, _ baslik: String, adres: String = "", sure: Double = 0, tarih: Date? = nil) -> AkisBolumu {
        var b = AkisBolumu()
        b.kimlik = kimlik; b.baslik = baslik; b.sesAdresi = adres; b.sure = sure; b.yayinTarihi = tarih
        return b
    }

    func testKimlikAdresVeBaslik() {
        let gun = TarihCozucu.tarih(yil: 2023, ay: 5, gun: 14)!
        let mevcut = [
            AkisEslestirici.Mevcut(akisKimligi: "p1", uzakAdres: "https://a/1.mp3", baslik: "Bölüm 1", sure: 100, yayinTarihi: nil),
            AkisEslestirici.Mevcut(akisKimligi: "", uzakAdres: "https://a/2.mp3", baslik: "Eski ad", sure: 0, yayinTarihi: nil),
            // Arşivden dosya: kimliği yok, başlık + süre ile eşleşmeli
            AkisEslestirici.Mevcut(akisKimligi: "", uzakAdres: nil, baslik: "bölüm 3 – konuk", sure: 3601, yayinTarihi: gun),
        ]
        let yeni = [
            akis("p1", "Bölüm 1 (yeni ad)", adres: "https://a/1.mp3"),
            akis("p2", "Bölüm 2", adres: "https://a/2.mp3"),
            akis("p3", "Bölüm 3 - Konuk", adres: "https://a/3.mp3", sure: 3600, tarih: gun.addingTimeInterval(3600)),
            akis("p4", "Bölüm 4", adres: "https://a/4.mp3"),
        ]
        XCTAssertEqual(AkisEslestirici.eslestir(mevcut: mevcut, yeni: yeni), [0, 1, 2, nil])
    }

    func testTarihCokFarkliysaEslesmez() {
        let a = TarihCozucu.tarih(yil: 2023, ay: 5, gun: 14)!
        let b = TarihCozucu.tarih(yil: 2024, ay: 5, gun: 14)!
        let mevcut = [AkisEslestirici.Mevcut(akisKimligi: "", uzakAdres: nil, baslik: "Soru-cevap", sure: 0, yayinTarihi: a)]
        XCTAssertEqual(AkisEslestirici.eslestir(mevcut: mevcut, yeni: [akis("x", "Soru-cevap", tarih: b)]), [nil])
    }

    func testBirMevcutTekEslesme() {
        let mevcut = [AkisEslestirici.Mevcut(akisKimligi: "", uzakAdres: nil, baslik: "Fragman", sure: 0, yayinTarihi: nil)]
        let yeni = [akis("a", "Fragman"), akis("b", "Fragman")]
        XCTAssertEqual(AkisEslestirici.eslestir(mevcut: mevcut, yeni: yeni), [0, nil])
    }

    func testKesinEslesmeOnceGelir() {
        // Başlığı aynı olan ilk akış bölümü, kimliği eşleşen ikinciden mevcut kaydı "çalmamalı".
        let mevcut = [AkisEslestirici.Mevcut(akisKimligi: "k2", uzakAdres: nil, baslik: "Özel", sure: 0, yayinTarihi: nil)]
        let yeni = [akis("k1", "Özel"), akis("k2", "Özel")]
        XCTAssertEqual(AkisEslestirici.eslestir(mevcut: mevcut, yeni: yeni), [nil, 0])
    }
}
