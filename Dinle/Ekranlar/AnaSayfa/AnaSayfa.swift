import SwiftUI
import SwiftData
import DinleCekirdek

struct AnaSayfa: View {
    @Binding var sekme: Sekme
    @Environment(Oynatici.self) private var oynatici

    @Query(AnaSayfa.yarimKalanlarTanimi) private var yarimKalanlar: [Bolum]
    @Query(AnaSayfa.sonEklenenlerTanimi) private var sonEklenenler: [Bolum]
    @Query private var programlar: [Program]
    @Query private var sarkilar: [Sarki]

    static var yarimKalanlarTanimi: FetchDescriptor<Bolum> {
        let kosul = #Predicate<Bolum> { b in
            b.konum > 0.0 && b.bitti == false
        }
        let sira: [SortDescriptor<Bolum>] = [SortDescriptor(\Bolum.sonDinlenme, order: .reverse)]
        return FetchDescriptor<Bolum>(predicate: kosul, sortBy: sira)
    }

    static var sonEklenenlerTanimi: FetchDescriptor<Bolum> {
        let kosul = #Predicate<Bolum> { b in
            b.konum == 0.0 && b.bitti == false
        }
        let sira: [SortDescriptor<Bolum>] = [SortDescriptor(\Bolum.eklenmeTarihi, order: .reverse)]
        var t = FetchDescriptor<Bolum>(predicate: kosul, sortBy: sira)
        t.fetchLimit = 6
        return t
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    UstBaslik(Bicim.tarih(Date()))

                    if let devam = yarimKalanlar.first {
                        DevamKarti(bolum: devam)
                    } else if programlar.isEmpty && sarkilar.isEmpty {
                        hosGeldin
                    }

                    if yarimKalanlar.count > 1 {
                        bolumGrubu("Yarıda kalanlar", Array(yarimKalanlar.dropFirst().prefix(8)))
                    }
                    if !sonEklenenler.isEmpty {
                        bolumGrubu("Sıradakiler", sonEklenenler)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(Tema.zemin)
            .navigationTitle("Podcast")
        }
    }

    private func bolumGrubu(_ baslik: String, _ bolumler: [Bolum]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(baslik)
                .font(Tema.serif(.title3, .bold))
                .padding(.bottom, 6)
            ForEach(bolumler) { b in
                Button { oynatici.devamEt(b) } label: {
                    BolumSatiri(bolum: b, programAdiGoster: true)
                }
                .buttonStyle(.plain)
                if b !== bolumler.last { Divider() }
            }
        }
    }

    private var hosGeldin: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hoş geldin.")
                .font(Tema.serif(.largeTitle, .bold))
            Text("Podcast arşivini ya da müziklerini Dosyalar'dan ekleyerek başla. Nerede kaldığını her zaman hatırlarım.")
                .font(.body)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Podcast ekle") { sekme = .podcastler }
                    .buttonStyle(.borderedProminent)
                Button("Müzik ekle") { sekme = .muzik }
                    .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }
}

/// Ana sayfanın en üstündeki büyük "Devam et" kartı.
struct DevamKarti: View {
    let bolum: Bolum
    @Environment(Oynatici.self) private var oynatici

    private var konum: Double { oynatici.bolum === bolum ? oynatici.konum : bolum.konum }
    private var sure: Double { oynatici.bolum === bolum && oynatici.sure > 0 ? oynatici.sure : bolum.sure }

    var body: some View {
        Button { oynatici.devamEt(bolum) } label: {
            VStack(alignment: .leading, spacing: 16) {
                UstBaslik("Devam et")
                HStack(alignment: .top, spacing: 14) {
                    KapakGorseli(veri: bolum.kapakVerisi, boyut: 84)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(bolum.program?.ad ?? "")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(bolum.baslik)
                            .font(Tema.serif(.title3))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                HStack(spacing: 14) {
                    Image(systemName: oynatici.caliyorMu(bolum) ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Tema.vurgu)
                    VStack(alignment: .leading, spacing: 6) {
                        IlerlemeCizgisi(oran: DinlemeKurallari.oran(konum: konum, sure: sure))
                        Text(sure > 0 ? Bicim.kalan(konum: konum, sure: sure) : Bicim.zaman(konum))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.kart, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
