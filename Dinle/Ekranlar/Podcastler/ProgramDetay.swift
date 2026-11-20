import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import DinleCekirdek

struct ProgramDetay: View {
    @Bindable var program: Program
    @Environment(\.modelContext) private var baglam
    @Environment(Oynatici.self) private var oynatici
    @Environment(\.dismiss) private var kapat

    @State private var iceAktarAcik = false
    @State private var klasorSec = false
    @State private var ekleniyor = false
    @State private var silmeOnayi = false

    private var bolumler: [Bolum] {
        let sira = program.siraliBolumler()
        return program.bitenleriGizle ? sira.filter { !$0.bitti } : sira
    }

    var body: some View {
        List {
            baslik
                .listRowSeparator(.hidden)
                .duzSatir()

            if program.bolumler.isEmpty {
                BosDurum(simge: "folder.badge.plus",
                         baslik: "Bölüm ekle",
                         aciklama: "Sağ üstteki menüden arşivindeki dosyaları ya da bütün bir klasörü seç. Yayın tarihini dosyanın içinden ya da adından bulurum.")
                    .listRowSeparator(.hidden)
                    .duzSatir()
            }

            ForEach(bolumler) { b in
                Button { oynatici.devamEt(b) } label: {
                    BolumSatiri(bolum: b)
                }
                .buttonStyle(.plain)
                .duzSatir()
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button { bittiDegistir(b) } label: {
                        Label(b.bitti ? "Bitmedi" : "Bitti", systemImage: b.bitti ? "arrow.uturn.backward" : "checkmark")
                    }
                    .tint(Tema.vurgu)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        ProgramSilici.sil(b, baglam: baglam, oynatici: oynatici)
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button { oynatici.cal(b, bastan: true) } label: {
                        Label("Baştan çal", systemImage: "backward.end")
                    }
                    Button { bittiDegistir(b) } label: {
                        Label(b.bitti ? "Bitmedi olarak işaretle" : "Bitti olarak işaretle",
                              systemImage: b.bitti ? "arrow.uturn.backward" : "checkmark")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Tema.zemin)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { menu }
        .fileImporter(isPresented: $iceAktarAcik,
                      allowedContentTypes: klasorSec ? [.folder] : [.audio],
                      allowsMultipleSelection: !klasorSec) { sonuc in
            iceAktar(sonuc)
        }
        .overlay {
            if ekleniyor {
                ProgressView("Ekleniyor…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .confirmationDialog("“\(program.ad)” ve bütün bölümleri silinsin mi?", isPresented: $silmeOnayi, titleVisibility: .visible) {
            Button("Programı sil", role: .destructive) {
                kapat()
                ProgramSilici.sil(program, baglam: baglam, oynatici: oynatici)
            }
        }
    }

    private var baslik: some View {
        HStack(alignment: .top, spacing: 16) {
            KapakGorseli(veri: program.kapak, boyut: 96, kose: 8)
            VStack(alignment: .leading, spacing: 6) {
                Text(program.ad)
                    .font(Tema.serif(.title2, .bold))
                Text(ozet)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var ozet: String {
        let toplam = program.bolumler.count
        let biten = program.bitenSayisi
        let yon = program.eskidenYeniye ? "Eskiden yeniye" : "Yeniden eskiye"
        return "\(toplam) bölüm · \(biten) bitti\n\(yon)"
    }

    private var menu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Ekle") {
                    Button {
                        klasorSec = false
                        iceAktarAcik = true
                    } label: {
                        Label("Dosya seç", systemImage: "doc.badge.plus")
                    }
                    Button {
                        klasorSec = true
                        iceAktarAcik = true
                    } label: {
                        Label("Klasör seç", systemImage: "folder.badge.plus")
                    }
                }
                Section("Sıralama") {
                    Picker("Sıralama", selection: $program.eskidenYeniye) {
                        Text("Eskiden yeniye").tag(true)
                        Text("Yeniden eskiye").tag(false)
                    }
                    Toggle("Bitenleri gizle", isOn: $program.bitenleriGizle)
                }
                Section {
                    Button(role: .destructive) { silmeOnayi = true } label: {
                        Label("Programı sil", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func bittiDegistir(_ b: Bolum) {
        b.bitti.toggle()
        if b.bitti { b.konum = 0 }
        try? baglam.save()
    }

    private func iceAktar(_ sonuc: Result<[URL], Error>) {
        guard case .success(let urller) = sonuc, !urller.isEmpty else { return }
        ekleniyor = true
        Task {
            let bilgiler = await DosyaIceAktarici.iceAktar(urller)
            if program.kapak == nil {
                program.kapak = bilgiler.first { $0.kapak != nil }?.kapak
            }
            for bilgi in bilgiler {
                let b = Bolum(baslik: bilgi.gorunenBaslik)
                b.sure = bilgi.sure
                b.dosyaAdi = bilgi.dosyaAdi
                b.yayinTarihi = TarihCozucu.yayinTarihiBul(metaTarih: bilgi.metaTarih,
                                                         dosyaAdi: bilgi.ozgunAd,
                                                         dosyaTarihi: bilgi.dosyaTarihi)
                if bilgi.kapak != program.kapak { b.kapak = bilgi.kapak }
                b.program = program
                baglam.insert(b)
            }
            try? baglam.save()
            ekleniyor = false
            if bilgiler.isEmpty {
                oynatici.hata = "Seçilenlerin içinde ses dosyası bulunamadı."
            }
        }
    }
}
