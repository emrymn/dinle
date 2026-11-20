import SwiftUI
import SwiftData

/// Podcastler sekmesi: üstte kullanıcının klasörleri, altta programlar.
struct PodcastlerEkrani: View {
    @Environment(\.modelContext) private var baglam
    @Environment(Oynatici.self) private var oynatici
    @Query(sort: [SortDescriptor(\Program.ad)]) private var programlar: [Program]
    @Query(sort: [SortDescriptor(\Klasor.olusturma)]) private var klasorler: [Klasor]
    @State private var yol = NavigationPath()
    @State private var adSor: YeniTur?
    @State private var yeniAd = ""

    enum YeniTur: Identifiable {
        case program, klasor
        var id: Self { self }
        var baslik: String { self == .program ? "Yeni program" : "Yeni klasör" }
        var aciklama: String {
            self == .program
                ? "Arşivindeki bölüm dosyalarını bu programın içine ekleyeceksin."
                : "Farklı programlardan istediğin bölümleri bu klasörde toplayacaksın."
        }
    }

    var body: some View {
        NavigationStack(path: $yol) {
            List {
                if !klasorler.isEmpty {
                    Section {
                        ForEach(klasorler) { k in
                            NavigationLink(value: k) { KlasorSatiri(klasor: k) }
                                .duzSatir()
                        }
                        .onDelete { sirala in
                            for i in sirala { baglam.delete(klasorler[i]) }
                            try? baglam.save()
                        }
                    } header: {
                        BolumBasligi("Klasörler")
                    }
                }

                Section {
                    ForEach(programlar) { p in
                        NavigationLink(value: p) { ProgramSatiri(program: p) }
                            .duzSatir()
                    }
                    .onDelete { sirala in
                        for i in sirala { ProgramSilici.sil(programlar[i], baglam: baglam, oynatici: oynatici) }
                    }
                } header: {
                    if !klasorler.isEmpty && !programlar.isEmpty { BolumBasligi("Programlar") }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Tema.zemin)
            .overlay {
                if programlar.isEmpty && klasorler.isEmpty {
                    BosDurum(simge: "mic",
                             baslik: "Henüz program yok",
                             aciklama: "Sağ üstteki + ile bir program oluştur, sonra arşivindeki dosyaları içine ekle.")
                }
            }
            .navigationTitle("Podcastler")
            .navigationDestination(for: Program.self) { ProgramDetay(program: $0) }
            .navigationDestination(for: Klasor.self) { KlasorDetay(klasor: $0) }
            .toolbar {
                Menu {
                    Button { sor(.program) } label: { Label("Yeni program", systemImage: "mic.badge.plus") }
                    Button { sor(.klasor) } label: { Label("Yeni klasör", systemImage: "folder.badge.plus") }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Ekle")
            }
            .alert(adSor?.baslik ?? "", isPresented: Binding(get: { adSor != nil }, set: { if !$0 { adSor = nil } }), presenting: adSor) { tur in
                TextField("Adı", text: $yeniAd)
                Button("Oluştur") { olustur(tur) }
                Button("Vazgeç", role: .cancel) {}
            } message: { tur in
                Text(tur.aciklama)
            }
            .onAppear {
                #if DEBUG
                if yol.isEmpty {
                    if DemoVerisi.programAc, let ilk = programlar.first { yol.append(ilk) }
                    if DemoVerisi.klasorAc, let ilk = klasorler.first { yol.append(ilk) }
                }
                #endif
            }
        }
    }

    private func sor(_ tur: YeniTur) {
        yeniAd = ""
        adSor = tur
    }

    private func olustur(_ tur: YeniTur) {
        let ad = yeniAd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ad.isEmpty else { return }
        switch tur {
        case .program:
            let p = Program(ad: ad)
            baglam.insert(p)
            try? baglam.save()
            yol.append(p)
        case .klasor:
            let k = Klasor(ad: ad)
            baglam.insert(k)
            try? baglam.save()
            yol.append(k)
        }
    }
}

struct BolumBasligi: View {
    let metin: String
    init(_ metin: String) { self.metin = metin }

    var body: some View {
        Text(metin)
            .font(Tema.serif(.title3, .bold))
            .foregroundStyle(.primary)
            .textCase(nil)
            .padding(.top, 8)
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

struct KlasorSatiri: View {
    let klasor: Klasor

    var body: some View {
        HStack(spacing: 14) {
            KlasorSimgesi(boyut: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(klasor.ad)
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
        let bolumler = klasor.bolumler
        guard !bolumler.isEmpty else { return "Boş" }
        let kalan = bolumler.filter { !$0.bitti }.count
        return kalan < bolumler.count ? "\(bolumler.count) bölüm · \(kalan) dinlenecek" : "\(bolumler.count) bölüm"
    }
}

struct KlasorSimgesi: View {
    var boyut: CGFloat = 60

    var body: some View {
        ZStack {
            Tema.vurgu.opacity(0.12)
            Image(systemName: "folder.fill")
                .font(.system(size: boyut * 0.4))
                .foregroundStyle(Tema.vurgu)
        }
        .frame(width: boyut, height: boyut)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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

enum KlasorIslemleri {
    @MainActor
    static func ekle(_ b: Bolum, _ k: Klasor, baglam: ModelContext) {
        guard !k.icerir(b) else { return }
        let oge = KlasorOgesi(sira: k.sonrakiSira)
        baglam.insert(oge)
        oge.klasor = k
        oge.bolum = b
        try? baglam.save()
    }

    @MainActor
    static func cikar(_ b: Bolum, _ k: Klasor, baglam: ModelContext) {
        for oge in k.ogeler where oge.bolum === b { baglam.delete(oge) }
        try? baglam.save()
    }
}
