import SwiftUI
import SwiftData

struct PodcastlerEkrani: View {
    @Environment(\.modelContext) private var baglam
    @Environment(Oynatici.self) private var oynatici
    @Query(sort: [SortDescriptor(\Program.ad)]) private var programlar: [Program]
    @State private var yol: [Program] = []
    @State private var yeniAdSor = false
    @State private var yeniAd = ""

    var body: some View {
        NavigationStack(path: $yol) {
            List {
                ForEach(programlar) { p in
                    NavigationLink(value: p) { ProgramSatiri(program: p) }
                        .duzSatir()
                }
                .onDelete { sirala in
                    for i in sirala { ProgramSilici.sil(programlar[i], baglam: baglam, oynatici: oynatici) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Tema.zemin)
            .overlay {
                if programlar.isEmpty {
                    BosDurum(simge: "mic",
                             baslik: "Henüz program yok",
                             aciklama: "Sağ üstteki + ile bir program oluştur, sonra arşivindeki dosyaları içine ekle.")
                }
            }
            .navigationTitle("Podcastler")
            .navigationDestination(for: Program.self) { ProgramDetay(program: $0) }
            .toolbar {
                Button {
                    yeniAd = ""
                    yeniAdSor = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Yeni program")
            }
            .alert("Yeni program", isPresented: $yeniAdSor) {
                TextField("Programın adı", text: $yeniAd)
                Button("Oluştur") { olustur() }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Arşivindeki bölüm dosyalarını bu programın içine ekleyeceksin.")
            }
        }
    }

    private func olustur() {
        let ad = yeniAd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ad.isEmpty else { return }
        let p = Program(ad: ad)
        baglam.insert(p)
        try? baglam.save()
        yol.append(p)
    }
}

struct ProgramSatiri: View {
    let program: Program

    var body: some View {
        HStack(spacing: 14) {
            KapakGorseli(veri: program.kapak, boyut: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(program.ad)
                    .font(Tema.serif(.headline))
                    .lineLimit(2)
                Text(ozet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var ozet: String {
        let toplam = program.bolumler.count
        guard toplam > 0 else { return "Bölüm yok" }
        let biten = program.bitenSayisi
        return biten > 0 ? "\(toplam) bölüm · \(biten) bitti" : "\(toplam) bölüm"
    }
}

enum ProgramSilici {
    @MainActor
    static func sil(_ p: Program, baglam: ModelContext, oynatici: Oynatici) {
        for b in p.bolumler {
            oynatici.silinecek(bolum: b)
            MedyaDeposu.sil(b.dosyaAdi)
        }
        baglam.delete(p)
        try? baglam.save()
    }

    @MainActor
    static func sil(_ b: Bolum, baglam: ModelContext, oynatici: Oynatici) {
        oynatici.silinecek(bolum: b)
        MedyaDeposu.sil(b.dosyaAdi)
        baglam.delete(b)
        try? baglam.save()
    }
}
