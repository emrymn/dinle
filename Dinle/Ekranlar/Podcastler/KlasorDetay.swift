import SwiftUI
import SwiftData

/// Bir bölüm klasörü: kendi sırasıyla çalınır; sürükleyerek sırası değişir.
struct KlasorDetay: View {
    @Bindable var klasor: Klasor
    @Environment(\.modelContext) private var baglam
    @Environment(Oynatici.self) private var oynatici
    @Environment(\.dismiss) private var kapat

    @State private var yeniAdSor = false
    @State private var yeniAd = ""
    @State private var silmeOnayi = false

    var body: some View {
        let bolumler = klasor.bolumler
        List {
            HStack(alignment: .top, spacing: 16) {
                KlasorSimgesi(boyut: 96)
                VStack(alignment: .leading, spacing: 6) {
                    Text(klasor.ad)
                        .font(Tema.serif(.title2, .bold))
                    Text("\(bolumler.count) bölüm")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let ilk = bolumler.first(where: { !$0.bitti }) {
                        Button {
                            oynatici.devamEt(ilk, sira: bolumler)
                        } label: {
                            Label("Çal", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
            .duzSatir()

            if bolumler.isEmpty {
                BosDurum(simge: "folder.badge.plus",
                         baslik: "Klasör boş",
                         aciklama: "Bir programın bölüm listesinde bölüme basılı tut ya da sola kaydır, sonra \"Klasöre ekle\"yi seç.")
                    .listRowSeparator(.hidden)
                    .duzSatir()
            }

            ForEach(bolumler) { b in
                Button { oynatici.devamEt(b, sira: bolumler) } label: {
                    BolumSatiri(bolum: b, programAdiGoster: true)
                }
                .buttonStyle(.plain)
                .duzSatir()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        KlasorIslemleri.cikar(b, klasor, baglam: baglam)
                    } label: {
                        Label("Çıkar", systemImage: "minus.circle")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        b.bitti.toggle()
                        if b.bitti { b.konum = 0 }
                        try? baglam.save()
                    } label: {
                        Label(b.bitti ? "Bitmedi" : "Bitti", systemImage: b.bitti ? "arrow.uturn.backward" : "checkmark")
                    }
                    .tint(Tema.vurgu)
                }
            }
            .onMove(perform: tasi)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Tema.zemin)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if bolumler.count > 1 { EditButton() }
                Menu {
                    Button {
                        yeniAd = klasor.ad
                        yeniAdSor = true
                    } label: {
                        Label("Yeniden adlandır", systemImage: "pencil")
                    }
                    Button(role: .destructive) { silmeOnayi = true } label: {
                        Label("Klasörü sil", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Klasörün adı", isPresented: $yeniAdSor) {
            TextField("Adı", text: $yeniAd)
            Button("Kaydet") {
                let ad = yeniAd.trimmingCharacters(in: .whitespacesAndNewlines)
                if !ad.isEmpty { klasor.ad = ad; try? baglam.save() }
            }
            Button("Vazgeç", role: .cancel) {}
        }
        .confirmationDialog("“\(klasor.ad)” silinsin mi? Bölümler programlarında kalır.", isPresented: $silmeOnayi, titleVisibility: .visible) {
            Button("Klasörü sil", role: .destructive) {
                kapat()
                baglam.delete(klasor)
                try? baglam.save()
            }
        }
    }

    private func tasi(_ kaynak: IndexSet, _ hedef: Int) {
        var sira = klasor.ogeler.sorted { $0.sira < $1.sira }.filter { $0.bolum != nil }
        sira.move(fromOffsets: kaynak, toOffset: hedef)
        for (i, oge) in sira.enumerated() { oge.sira = i }
        try? baglam.save()
    }
}

/// Bölümün bağlam menüsündeki "Klasöre ekle" alt menüsü.
struct KlasoreEkleMenusu: View {
    let bolum: Bolum
    let klasorler: [Klasor]
    let ekle: (Klasor) -> Void
    let yeniKlasor: () -> Void

    var body: some View {
        Menu {
            ForEach(klasorler) { k in
                Button { ekle(k) } label: {
                    if k.icerir(bolum) {
                        Label(k.ad, systemImage: "checkmark")
                    } else {
                        Text(k.ad)
                    }
                }
                .disabled(k.icerir(bolum))
            }
            Button(action: yeniKlasor) {
                Label("Yeni klasör…", systemImage: "folder.badge.plus")
            }
        } label: {
            Label("Klasöre ekle", systemImage: "folder")
        }
    }
}
