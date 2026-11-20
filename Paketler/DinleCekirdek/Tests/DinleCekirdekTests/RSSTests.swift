import XCTest
@testable import DinleCekirdek

final class RSSTests: XCTestCase {

    static let ornek = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:content="http://purl.org/rss/1.0/modules/content/">
      <channel>
        <title><![CDATA[Mercurophile]]></title>
        <description>Sanat üzerine sohbetler</description>
        <itunes:author>Mercurophile</itunes:author>
        <itunes:image href="https://ornek.com/kapak.jpg"/>
        <image><url>https://ornek.com/eski.jpg</url><title>Mercurophile</title></image>
        <item>
          <title><![CDATA[Bölüm 2: Rönesans]]></title>
          <guid isPermaLink="false">substack:post:222</guid>
          <pubDate>Sun, 14 May 2023 10:30:00 GMT</pubDate>
          <enclosure url="https://ornek.com/2.mp3" length="48000000" type="audio/mpeg"/>
          <itunes:duration>1:02:03</itunes:duration>
          <itunes:image href="https://ornek.com/b2.jpg"/>
          <description><![CDATA[<p>İkinci bölüm</p>]]></description>
        </item>
        <item>
          <title>Bölüm 1</title>
          <pubDate>Fri, 5 May 2023 08:00:00 +0300</pubDate>
          <enclosure url="https://ornek.com/1.mp3" length="1000" type="audio/mpeg"/>
          <itunes:duration>2520</itunes:duration>
        </item>
        <item>
          <title>Yalnız yazı (sesi yok)</title>
          <guid>substack:post:333</guid>
        </item>
      </channel>
    </rss>
    """

    func testAyristir() throws {
        let akis = try RSSAyristirici.ayristir(Data(Self.ornek.utf8))
        XCTAssertEqual(akis.baslik, "Mercurophile")
        XCTAssertEqual(akis.yazar, "Mercurophile")
        XCTAssertEqual(akis.kapakAdresi, "https://ornek.com/kapak.jpg")
        XCTAssertEqual(akis.bolumler.count, 2, "sesi olmayan yazı atlanmalı")

        let b2 = akis.bolumler[0]
        XCTAssertEqual(b2.baslik, "Bölüm 2: Rönesans")
        XCTAssertEqual(b2.kimlik, "substack:post:222")
        XCTAssertEqual(b2.sesAdresi, "https://ornek.com/2.mp3")
        XCTAssertEqual(b2.boyut, 48_000_000)
        XCTAssertEqual(b2.sure, 3723)
        XCTAssertEqual(b2.kapakAdresi, "https://ornek.com/b2.jpg")
        XCTAssertEqual(b2.aciklama, "<p>İkinci bölüm</p>")
        XCTAssertEqual(b2.yayinTarihi, ISO8601DateFormatter().date(from: "2023-05-14T10:30:00Z"))

        let b1 = akis.bolumler[1]
        XCTAssertEqual(b1.kimlik, "https://ornek.com/1.mp3", "guid yoksa ses adresi kimlik olur")
        XCTAssertEqual(b1.sure, 2520)
        XCTAssertEqual(b1.yayinTarihi, ISO8601DateFormatter().date(from: "2023-05-05T05:00:00Z"))
    }

    func testAkisDegil() {
        XCTAssertThrowsError(try RSSAyristirici.ayristir(Data("<html><body>merhaba</body></html>".utf8)))
        XCTAssertThrowsError(try RSSAyristirici.ayristir(Data("bozuk <".utf8)))
    }

    func testSure() {
        XCTAssertEqual(RSSAyristirici.sure("3600"), 3600)
        XCTAssertEqual(RSSAyristirici.sure("62:03"), 3723)
        XCTAssertEqual(RSSAyristirici.sure("01:02:03"), 3723)
        XCTAssertEqual(RSSAyristirici.sure(""), 0)
        XCTAssertEqual(RSSAyristirici.sure("abc"), 0)
    }

    func testTarih() {
        XCTAssertNotNil(RSSAyristirici.tarih("Tue, 14 Nov 2023 18:00:00 +0000"))
        XCTAssertNotNil(RSSAyristirici.tarih("14 Nov 2023 18:00:00 GMT"))
        XCTAssertNotNil(RSSAyristirici.tarih("2023-11-14T18:00:00Z"))
        XCTAssertNil(RSSAyristirici.tarih("dün"))
    }

    func testAdaylar() {
        XCTAssertEqual(AkisAdresi.adaylar("mercurophile").map(\.absoluteString),
                       ["https://mercurophile.substack.com/feed/podcast", "https://mercurophile.substack.com/feed"])
        XCTAssertEqual(AkisAdresi.adaylar("https://baaadbilly.substack.com/p/bir-yazi").map(\.absoluteString),
                       ["https://baaadbilly.substack.com/feed/podcast", "https://baaadbilly.substack.com/feed"])
        let ozel = "https://api.substack.com/feed/podcast/12345/private/abc-def.rss"
        XCTAssertEqual(AkisAdresi.adaylar(ozel).map(\.absoluteString), [ozel])
        XCTAssertEqual(AkisAdresi.adaylar("feeds.example.com/show.xml").map(\.absoluteString), ["https://feeds.example.com/show.xml"])
        XCTAssertEqual(AkisAdresi.adaylar("https://www.theantidote.co/").map(\.absoluteString),
                       ["https://www.theantidote.co/feed/podcast", "https://www.theantidote.co/feed"])
        // Podcast uygulaması linklerinin içinden akış adresi
        let oz = "https://api.substack.com/feed/podcast/123/private/abc.rss"
        XCTAssertEqual(AkisAdresi.adaylar("overcast://x-callback-url/add?url=https%3A%2F%2Fapi.substack.com%2Ffeed%2Fpodcast%2F123%2Fprivate%2Fabc.rss").map(\.absoluteString), [oz])
        XCTAssertEqual(AkisAdresi.adaylar("pktc://subscribe/api.substack.com/feed/podcast/123/private/abc.rss").map(\.absoluteString), [oz])
        XCTAssertEqual(AkisAdresi.adaylar("podcast://api.substack.com/feed/podcast/123/private/abc.rss").map(\.absoluteString), [oz])
        XCTAssertEqual(AkisAdresi.adaylar("itpc://api.substack.com/feed/podcast/123/private/abc.rss").map(\.absoluteString), [oz])
        XCTAssertEqual(AkisAdresi.adaylar("https://example.com/app/add?url=https://api.substack.com/feed/podcast/123/private/abc.rss").map(\.absoluteString), [oz])
        XCTAssertEqual(AkisAdresi.adaylar("  ").count, 0)
        XCTAssertEqual(AkisAdresi.adaylar("iki kelime").count, 0)
    }
}
