import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import DinleCekirdek

/// Müzik bölümü: podcastlerden ayrı, kendi sırası olan şarkı listesi.
struct MuzikEkrani: View {
    @Environment(\.modelContext) private var baglam
    @Environment(Oynatici.self) private var oynatici
    @Query private var tumu: [Sarki]

    @State private var iceAktarAcik = false
    @State private var klasorSec = false
    @State private var ekleniyor = false

    private var sarkilar: [Sarki] {
        tumu.sorted { $0.baslik.localizedStandardCompare($1.baslik) == .orderedAscending }
    }

    var body: some View {
        let liste = sarkilar
        NavigationStack {
            List {
                if !liste.isEmpty {
                    HStack(spacing: 12) {
                        Button {
                            oynatici.cal(sarkilar: liste, baslangic: 0)
                        } label: {
                            Label("Çal", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            oynatici.cal(sarkilar: liste, baslangic: 0, karisikBasla: true)
                        } label: {
                            Label("Karışık", systemImage: "shuffle").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.large)
                    .listRowSeparator(.hidden)
                    .duzSatir()
                }

                ForEach(Array(liste.enumerated()), id: \.element.id) { i, s in
                    Button {
                        oynatici.cal(sarkilar: liste, baslangic: i)
                    } label: {
                        SarkiSatiri(sarki: s)
                    }
                    .buttonStyle(.plain)
                    .duzSatir()
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { sil(s) } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Tema.zemin)
            .overlay {
                if liste.isEmpty {
                    BosDurum(simge: "music.note",
                             baslik: "Müzik yok",
                             aciklama: "Sağ üstteki + ile Dosyalar'daki şarkıları ya da bir klasörü ekle.")
                }
                if ekleniyor {
                    ProgressView("Ekleniyor…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .navigationTitle("Müzik")
            .toolbar {
                Menu {
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
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Müzik ekle")
            }
            .fileImporter(isPresented: $iceAktarAcik,
                          allowedContentTypes: klasorSec ? [.folder] : [.audio],
                          allowsMultipleSelection: !klasorSec) { sonuc in
                iceAktar(sonuc)
            }
        }
    }

    private func sil(_ s: Sarki) {
        oynatici.silinecek(sarki: s)
        MedyaDeposu.sil(s.dosyaAdi)
        baglam.delete(s)
        try? baglam.save()
    }

    private func iceAktar(_ sonuc: Result<[URL], Error>) {
        guard case .success(let urller) = sonuc, !urller.isEmpty else { return }
        ekleniyor = true
        Task {
            let bilgiler = await DosyaIceAktarici.iceAktar(urller)
            for bilgi in bilgiler {
                let s = Sarki(baslik: bilgi.gorunenBaslik,
                              sanatci: bilgi.sanatci?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? "Bilinmeyen sanatçı",
                              album: bilgi.album ?? "",
                              dosyaAdi: bilgi.dosyaAdi)
                s.sure = bilgi.sure
                s.kapak = bilgi.kapak
                baglam.insert(s)
            }
            try? baglam.save()
            ekleniyor = false
            if bilgiler.isEmpty {
                oynatici.hata = "Seçilenlerin içinde ses dosyası bulunamadı."
            }
        }
    }
}

struct SarkiSatiri: View {
    let sarki: Sarki
    @Environment(Oynatici.self) private var oynatici

    var body: some View {
        HStack(spacing: 12) {
            KapakGorseli(veri: sarki.kapak, boyut: 46, kose: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(sarki.baslik)
                    .font(.body)
                    .foregroundStyle(oynatici.sarki === sarki ? Tema.vurgu : .primary)
                    .lineLimit(1)
                Text(sarki.album.isEmpty ? sarki.sanatci : "\(sarki.sanatci) · \(sarki.album)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if oynatici.caliyorMu(sarki) {
                Image(systemName: "waveform")
                    .foregroundStyle(Tema.vurgu)
                    .symbolEffect(.variableColor.iterative)
            } else if sarki.sure > 0 {
                Text(Bicim.zaman(sarki.sure))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
