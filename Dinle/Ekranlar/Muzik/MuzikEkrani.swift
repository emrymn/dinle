import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import DinleCekirdek

/// Müzik bölümü: podcastlerden ayrı. Albümler (kapaklarıyla) ya da bütün şarkılar.
struct MuzikEkrani: View {
    enum Gorunum: Hashable { case albumler, sarkilar }

    @Environment(\.modelContext) private var baglam
    @Environment(Oynatici.self) private var oynatici
    @Query private var tumu: [Sarki]

    @State private var gorunum: Gorunum = .albumler
    @State private var yol = NavigationPath()
    @State private var iceAktarAcik = false
    @State private var klasorSec = false
    @State private var ekleniyor = false
    @State private var bilgi: String?

    private var sarkilar: [Sarki] {
        tumu.sorted { $0.baslik.localizedStandardCompare($1.baslik) == .orderedAscending }
    }

    var body: some View {
        NavigationStack(path: $yol) {
            Group {
                if tumu.isEmpty {
                    BosDurum(simge: "music.note",
                             baslik: "Müzik yok",
                             aciklama: "Sağ üstteki + ile şarkı ya da bir albüm klasörü ekle. Klasör seçersen içindekiler tek seferde bir albüm olur.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if gorunum == .albumler {
                    AlbumIzgarasi(albumler: Album.grupla(tumu))
                } else {
                    sarkiListesi
                }
            }
            .background(Tema.zemin)
            .safeAreaInset(edge: .top, spacing: 0) {
                if !tumu.isEmpty {
                    Picker("Görünüm", selection: $gorunum) {
                        Text("Albümler").tag(Gorunum.albumler)
                        Text("Şarkılar").tag(Gorunum.sarkilar)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Tema.zemin)
                }
            }
            .overlay {
                if ekleniyor {
                    ProgressView("Ekleniyor…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .navigationTitle("Müzik")
            .navigationDestination(for: Album.Anahtar.self) { AlbumDetay(anahtar: $0) }
            .toolbar {
                Menu {
                    Button {
                        klasorSec = true
                        iceAktarAcik = true
                    } label: {
                        Label("Albüm klasörü seç", systemImage: "folder.badge.plus")
                    }
                    Button {
                        klasorSec = false
                        iceAktarAcik = true
                    } label: {
                        Label("Şarkı seç", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Müzik ekle")
            }
            .fileImporter(isPresented: $iceAktarAcik,
                          allowedContentTypes: klasorSec ? [.folder] : [.audio],
                          allowsMultipleSelection: true) { sonuc in
                iceAktar(sonuc)
            }
            .alert("Ekleme tamamlandı", isPresented: Binding(get: { bilgi != nil }, set: { if !$0 { bilgi = nil } })) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(bilgi ?? "")
            }
            .onAppear {
                #if DEBUG
                if DemoVerisi.arguman("-muzik") == "sarkilar" { gorunum = .sarkilar }
                if DemoVerisi.albumAc, yol.isEmpty, let ilk = Album.grupla(tumu).first {
                    yol.append(ilk.anahtar)
                }
                #endif
            }
        }
    }

    private var sarkiListesi: some View {
        let liste = sarkilar
        return List {
            CalKarisikDugmeleri(sarkilar: liste)
                .listRowSeparator(.hidden)
                .duzSatir()

            ForEach(Array(liste.enumerated()), id: \.element.id) { i, s in
                Button {
                    oynatici.cal(sarkilar: liste, baslangic: i)
                } label: {
                    SarkiSatiri(sarki: s)
                }
                .buttonStyle(.plain)
                .duzSatir()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { SarkiSilici.sil(s, baglam: baglam, oynatici: oynatici) } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func iceAktar(_ sonuc: Result<[URL], Error>) {
        guard case .success(let urller) = sonuc, !urller.isEmpty else { return }
        ekleniyor = true
        let bilinenler = Set(tumu
            .filter { !$0.kaynakAdi.isEmpty }
            .map { KopyaDenetimi.DosyaKimligi(ad: $0.kaynakAdi, boyut: $0.kaynakBoyutu) })
        Task {
            let sonuc = await DosyaIceAktarici.iceAktar(urller, bilinenler: bilinenler)
            var atlanan = sonuc.atlanan
            var eklenenler: [Sarki] = []
            var mevcut = tumu
            for dosya in sonuc.eklenenler {
                let baslik = dosya.gorunenBaslik
                let sanatci = dosya.sanatci?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? "Bilinmeyen sanatçı"
                // Farklı adla kaydedilmiş aynı şarkı: başlık + sanatçı + süre aynıysa ekleme.
                if mevcut.contains(where: {
                    KopyaDenetimi.sadelestir($0.sanatci) == KopyaDenetimi.sadelestir(sanatci)
                        && KopyaDenetimi.ayniKayit(baslik: $0.baslik, sure: $0.sure, baslik: baslik, sure: dosya.sure)
                }) {
                    MedyaDeposu.sil(dosya.dosyaAdi)
                    atlanan += 1
                    continue
                }
                // Albüm adı: dosyanın içindeki bilgi, yoksa içinde durduğu klasörün adı.
                let album = dosya.album?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? dosya.klasorAdi ?? ""
                let s = Sarki(baslik: baslik, sanatci: sanatci, album: album, dosyaAdi: dosya.dosyaAdi)
                s.sure = dosya.sure
                s.kapak = dosya.kapak
                s.kaynakAdi = dosya.kaynakAdi
                s.kaynakBoyutu = dosya.kaynakBoyutu
                baglam.insert(s)
                mevcut.append(s)
                eklenenler.append(s)
            }
            // Kapağı olmayan şarkılar albümdeki ilk kapağı alsın.
            for album in Set(eklenenler.map(\.album)) where !album.isEmpty {
                let ayni = mevcut.filter { $0.album == album }
                if let kapak = ayni.first(where: { $0.kapak != nil })?.kapak {
                    for s in ayni where s.kapak == nil { s.kapak = kapak }
                }
            }
            try? baglam.save()
            ekleniyor = false
            if atlanan > 0 {
                bilgi = "\(eklenenler.count) şarkı eklendi. \(atlanan) şarkı zaten vardı, tekrar eklenmedi."
            } else if eklenenler.isEmpty {
                bilgi = "Seçilenlerin içinde ses dosyası bulunamadı."
            }
        }
    }
}

// MARK: - Albüm

/// Şarkılardan türetilen albüm (ayrı bir kayıt değil): aynı albüm adını taşıyan şarkılar.
struct Album: Identifiable {
    struct Anahtar: Hashable { let ad: String }

    let ad: String
    let sarkilar: [Sarki]

    var id: String { ad }
    var anahtar: Anahtar { Anahtar(ad: ad) }
    var gorunenAd: String { ad.isEmpty ? "Tekli şarkılar" : ad }
    var kapak: Data? { sarkilar.first { $0.kapak != nil }?.kapak }

    var sanatci: String {
        let sanatcilar = Set(sarkilar.map(\.sanatci))
        if sanatcilar.count == 1 { return sanatcilar.first ?? "" }
        return "Çeşitli sanatçılar"
    }

    /// Albümdeki sıra: dosya adına göre ("01 …", "02 …"), yoksa başlığa göre.
    static func sirala(_ liste: [Sarki]) -> [Sarki] {
        liste.sorted { a, b in
            let ka = a.kaynakAdi.isEmpty ? a.baslik : a.kaynakAdi
            let kb = b.kaynakAdi.isEmpty ? b.baslik : b.kaynakAdi
            return ka.localizedStandardCompare(kb) == .orderedAscending
        }
    }

    /// Albümler ada göre; "Tekli şarkılar" en sonda.
    static func grupla(_ sarkilar: [Sarki]) -> [Album] {
        Dictionary(grouping: sarkilar, by: \.album)
            .map { Album(ad: $0.key, sarkilar: sirala($0.value)) }
            .sorted { a, b in
                if a.ad.isEmpty != b.ad.isEmpty { return !a.ad.isEmpty }
                return a.ad.localizedStandardCompare(b.ad) == .orderedAscending
            }
    }
}

struct AlbumIzgarasi: View {
    let albumler: [Album]
    private let sutunlar = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: sutunlar, alignment: .leading, spacing: 22) {
                ForEach(albumler) { a in
                    NavigationLink(value: a.anahtar) {
                        VStack(alignment: .leading, spacing: 6) {
                            AlbumKapagi(veri: a.kapak)
                            Text(a.gorunenAd)
                                .font(Tema.serif(.subheadline))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("\(a.sanatci) · \(a.sarkilar.count) şarkı")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Kare, esnek boyutlu albüm kapağı.
struct AlbumKapagi: View {
    let veri: Data?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let veri, let resim = UIImage(data: veri) {
                    Image(uiImage: resim).resizable().scaledToFill()
                } else {
                    ZStack {
                        Tema.kart
                        Image(systemName: "music.note")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(Tema.vurgu.opacity(0.75))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Tema.cizgi, lineWidth: 0.5))
    }
}

struct AlbumDetay: View {
    let anahtar: Album.Anahtar
    @Environment(\.modelContext) private var baglam
    @Environment(Oynatici.self) private var oynatici
    @Environment(\.dismiss) private var kapat
    @Query private var tumu: [Sarki]
    @State private var silmeOnayi = false

    private var album: Album {
        Album(ad: anahtar.ad, sarkilar: Album.sirala(tumu.filter { $0.album == anahtar.ad }))
    }

    var body: some View {
        let a = album
        List {
            VStack(spacing: 10) {
                AlbumKapagi(veri: a.kapak)
                    .frame(width: 220)
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                Text(a.gorunenAd)
                    .font(Tema.serif(.title2, .bold))
                    .multilineTextAlignment(.center)
                Text(a.sanatci)
                    .font(.subheadline)
                    .foregroundStyle(Tema.vurgu)
                CalKarisikDugmeleri(sarkilar: a.sarkilar)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
            .duzSatir()

            ForEach(Array(a.sarkilar.enumerated()), id: \.element.id) { i, s in
                Button {
                    oynatici.cal(sarkilar: a.sarkilar, baslangic: i)
                } label: {
                    HStack(spacing: 14) {
                        Text("\(i + 1)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .trailing)
                        Text(s.baslik)
                            .foregroundStyle(oynatici.sarki === s ? Tema.vurgu : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if s.sure > 0 {
                            Text(Bicim.zaman(s.sure))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .duzSatir()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { SarkiSilici.sil(s, baglam: baglam, oynatici: oynatici) } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Tema.zemin)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu {
                Button(role: .destructive) { silmeOnayi = true } label: {
                    Label("Albümü sil", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .confirmationDialog("“\(a.gorunenAd)” ve içindeki \(a.sarkilar.count) şarkı silinsin mi?", isPresented: $silmeOnayi, titleVisibility: .visible) {
            Button("Albümü sil", role: .destructive) {
                kapat()
                for s in a.sarkilar { SarkiSilici.sil(s, baglam: baglam, oynatici: oynatici) }
            }
        }
    }
}

// MARK: - Ortak parçalar

struct CalKarisikDugmeleri: View {
    let sarkilar: [Sarki]
    @Environment(Oynatici.self) private var oynatici

    var body: some View {
        HStack(spacing: 12) {
            Button {
                oynatici.cal(sarkilar: sarkilar, baslangic: 0)
            } label: {
                Label("Çal", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                oynatici.cal(sarkilar: sarkilar, baslangic: 0, karisikBasla: true)
            } label: {
                Label("Karışık", systemImage: "shuffle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
    }
}

enum SarkiSilici {
    @MainActor
    static func sil(_ s: Sarki, baglam: ModelContext, oynatici: Oynatici) {
        oynatici.silinecek(sarki: s)
        MedyaDeposu.sil(s.dosyaAdi)
        baglam.delete(s)
        try? baglam.save()
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
