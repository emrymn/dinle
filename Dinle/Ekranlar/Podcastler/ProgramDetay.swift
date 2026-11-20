import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import DinleCekirdek

struct ProgramDetay: View {
    @Bindable var program: Program
    @Environment(\.modelContext) private var baglam
    @Environment(Oynatici.self) private var oynatici
    @Environment(Indirici.self) private var indirici
    @Environment(\.dismiss) private var kapat

    @Query(sort: [SortDescriptor(\Klasor.olusturma)]) private var klasorler: [Klasor]

    @State private var iceAktarAcik = false
    @State private var klasorSec = false
    @State private var ekleniyor = false
    @State private var silmeOnayi = false
    @State private var bilgi: String?
    /// "Yeni klasör…" seçilince klasöre eklenecek bölüm.
    @State private var klasoreEklenecek: Bolum?
    @State private var yeniKlasorAdi = ""
    @State private var akisBagla = false
    /// Onay bekleyen toplu indirme.
    @State private var topluIndirme: TopluIndirme?

    struct TopluIndirme: Identifiable {
        let id = UUID()
        let bolumler: [Bolum]
        let boyut: Int64
    }

    /// Akıştan gelen, henüz inmemiş ve inmeyen bölümler.
    private func indirilebilir(yalnizBitmemis: Bool) -> [Bolum] {
        program.siraliBolumler().filter {
            $0.akistan && !$0.indirildi && indirici.oran($0) == nil && (!yalnizBitmemis || !$0.bitti)
        }
    }

    private func topluIndirmeHazirla(yalnizBitmemis: Bool) {
        let liste = indirilebilir(yalnizBitmemis: yalnizBitmemis)
        let boyut = IndirmeTahmini.toplam(liste.map { ($0.akisBoyutu, $0.sure) })
        topluIndirme = TopluIndirme(bolumler: liste, boyut: boyut)
    }

    private var bolumler: [Bolum] {
        let sira = program.siraliBolumler()
        return program.bitenleriGizle ? sira.filter { !$0.bitti } : sira
    }

    var body: some View {
        List {
            baslik
                .listRowSeparator(.hidden)
                .duzSatir()

            if program.gorunurBolumler.isEmpty {
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
                    if b.akistan && !b.indirildi && indirici.oran(b) == nil {
                        Button { indirici.indir(b) } label: {
                            Label("İndir", systemImage: "arrow.down.circle")
                        }
                        .tint(.blue)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        ProgramSilici.sil(b, baglam: baglam, oynatici: oynatici)
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                    Button {
                        yeniKlasorAdi = ""
                        klasoreEklenecek = b
                    } label: {
                        Label("Klasöre", systemImage: "folder.badge.plus")
                    }
                    .tint(.gray)
                }
                .contextMenu {
                    KlasoreEkleMenusu(bolum: b, klasorler: klasorler,
                                      ekle: { KlasorIslemleri.ekle(b, $0, baglam: baglam) },
                                      yeniKlasor: { yeniKlasorAdi = ""; klasoreEklenecek = b })
                    Button { oynatici.cal(b, bastan: true) } label: {
                        Label("Baştan çal", systemImage: "backward.end")
                    }
                    if b.akistan {
                        if indirici.oran(b) != nil {
                            Button { indirici.iptal(b) } label: {
                                Label("İndirmeyi durdur", systemImage: "xmark.circle")
                            }
                        } else if b.indirildi {
                            Button { indirici.indirileniSil(b) } label: {
                                Label("İndirileni sil (internetten çalar)", systemImage: "icloud.slash")
                            }
                        } else {
                            Button { indirici.indir(b) } label: {
                                Label("İndir", systemImage: "arrow.down.circle")
                            }
                        }
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
        .refreshable {
            if program.akisAdresi != nil {
                _ = try? await AkisYenileyici.yenile(program, baglam: baglam, indirici: indirici)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { menu }
        .sheet(isPresented: $akisBagla) {
            AkisEkleEkrani(program: program)
        }
        .confirmationDialog(topluIndirmeBasligi, isPresented: Binding(get: { topluIndirme != nil }, set: { if !$0 { topluIndirme = nil } }),
                            titleVisibility: .visible, presenting: topluIndirme) { t in
            Button("İndir") { indirici.indir(t.bolumler) }
            Button("Vazgeç", role: .cancel) {}
        } message: { t in
            Text(topluIndirmeMesaji(t))
        }
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
        .alert("Klasöre ekle", isPresented: Binding(get: { klasoreEklenecek != nil }, set: { if !$0 { klasoreEklenecek = nil } })) {
            TextField("Yeni klasörün adı", text: $yeniKlasorAdi)
            Button("Yeni klasöre ekle") { yeniKlasoreEkle() }
            ForEach(klasorler.prefix(6)) { k in
                Button(k.ad) {
                    if let b = klasoreEklenecek { KlasorIslemleri.ekle(b, k, baglam: baglam) }
                }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text(klasorler.isEmpty ? "Yeni bir klasör oluştur." : "Var olan bir klasörü seç ya da yeni bir ad yaz.")
        }
        .alert("Ekleme tamamlandı", isPresented: Binding(get: { bilgi != nil }, set: { if !$0 { bilgi = nil } })) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(bilgi ?? "")
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
        let toplam = program.gorunurBolumler.count
        let biten = program.bitenSayisi
        let yon = program.eskidenYeniye ? "Eskiden yeniye" : "Yeniden eskiye"
        var satirlar = ["\(toplam) bölüm · \(biten) bitti", yon]
        let inen = indirici.iniyorSayisi(program.gorunurBolumler)
        if inen > 0 { satirlar.insert("\(inen) bölüm iniyor", at: 1) }
        if program.akisAdresi != nil {
            satirlar.append(program.otomatikIndir ? "Abone · yeni bölümler iner" : "Abone · aşağı çekince yenilenir")
        }
        return satirlar.joined(separator: "\n")
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
                Section("Abonelik") {
                    if program.akisAdresi == nil {
                        Button { akisBagla = true } label: {
                            Label("Substack / RSS bağla", systemImage: "dot.radiowaves.up.forward")
                        }
                    } else {
                        let bitmemis = indirilebilir(yalnizBitmemis: true).count
                        let hepsi = indirilebilir(yalnizBitmemis: false).count
                        if bitmemis > 0 {
                            Button { topluIndirmeHazirla(yalnizBitmemis: true) } label: {
                                Label("Bitmemişleri indir (\(bitmemis))", systemImage: "arrow.down.circle")
                            }
                        }
                        if hepsi > bitmemis {
                            Button { topluIndirmeHazirla(yalnizBitmemis: false) } label: {
                                Label("Hepsini indir (\(hepsi))", systemImage: "arrow.down.circle.fill")
                            }
                        }
                        if indirici.iniyorSayisi(program.gorunurBolumler) > 0 {
                            Button(role: .destructive) { indirici.iptal(program.gorunurBolumler) } label: {
                                Label("İndirmeleri durdur", systemImage: "stop.circle")
                            }
                        }
                        Toggle("Yeni bölümleri indir", isOn: $program.otomatikIndir)
                        Button {
                            Task { _ = try? await AkisYenileyici.yenile(program, baglam: baglam, indirici: indirici) }
                        } label: {
                            Label("Şimdi yenile", systemImage: "arrow.clockwise")
                        }
                        Button { akisBagla = true } label: {
                            Label("Özel linkle değiştir (ücretli abonelik)", systemImage: "key")
                        }
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

    private var topluIndirmeBasligi: String {
        guard let t = topluIndirme else { return "" }
        return "\(t.bolumler.count) bölüm, yaklaşık \(Bicim.boyut(t.boyut)) indirilsin mi?"
    }

    private func topluIndirmeMesaji(_ t: TopluIndirme) -> String {
        var m = "Bölümler sırayla iner; uygulama kapalıyken de sürer."
        if Ayarlar.yalnizcaWifi { m += " Yalnızca Wi-Fi'deyken iner." }
        if let bos = Indirici.bosYer {
            m += "\nTelefonda boş yer: \(Bicim.boyut(bos))."
            if t.boyut > bos { m += "\nUyarı: Yer yetmeyebilir; bir kısmı inmeyebilir." }
        }
        return m
    }

    private func yeniKlasoreEkle() {
        let ad = yeniKlasorAdi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ad.isEmpty, let b = klasoreEklenecek else { return }
        let k = Klasor(ad: ad)
        baglam.insert(k)
        KlasorIslemleri.ekle(b, k, baglam: baglam)
    }

    private func bittiDegistir(_ b: Bolum) {
        b.bitti.toggle()
        if b.bitti { b.konum = 0 }
        try? baglam.save()
    }

    private func iceAktar(_ sonuc: Result<[URL], Error>) {
        guard case .success(let urller) = sonuc, !urller.isEmpty else { return }
        ekleniyor = true
        let bilinenler = Set(program.bolumler
            .filter { !$0.kaynakAdi.isEmpty }
            .map { KopyaDenetimi.DosyaKimligi(ad: $0.kaynakAdi, boyut: $0.kaynakBoyutu) })
        Task {
            let sonuc = await DosyaIceAktarici.iceAktar(urller, bilinenler: bilinenler)
            var atlanan = sonuc.atlanan
            var eklenen = 0
            if program.kapak == nil {
                program.kapak = sonuc.eklenenler.first { $0.kapak != nil }?.kapak
            }
            var mevcut = program.bolumler
            for dosya in sonuc.eklenenler {
                // Farklı adla kaydedilmiş aynı bölüm: başlık + süre aynıysa ekleme.
                if let es = mevcut.first(where: { KopyaDenetimi.ayniKayit(baslik: $0.baslik, sure: $0.sure, baslik: dosya.gorunenBaslik, sure: dosya.sure) }) {
                    if es.akistan && !es.indirildi {
                        // Akıştaki bölümün dosyası arşivden geldi: indirilmiş say.
                        es.dosyaAdi = dosya.dosyaAdi
                        es.kaynakAdi = dosya.kaynakAdi
                        es.kaynakBoyutu = dosya.kaynakBoyutu
                        es.gizli = false
                        eklenen += 1
                    } else {
                        MedyaDeposu.sil(dosya.dosyaAdi)
                        atlanan += 1
                    }
                    continue
                }
                let b = Bolum(baslik: dosya.gorunenBaslik)
                b.sure = dosya.sure
                b.dosyaAdi = dosya.dosyaAdi
                b.kaynakAdi = dosya.kaynakAdi
                b.kaynakBoyutu = dosya.kaynakBoyutu
                b.yayinTarihi = TarihCozucu.yayinTarihiBul(metaTarih: dosya.metaTarih,
                                                         dosyaAdi: dosya.ozgunAd,
                                                         dosyaTarihi: dosya.dosyaTarihi)
                if dosya.kapak != program.kapak { b.kapak = dosya.kapak }
                b.program = program
                baglam.insert(b)
                mevcut.append(b)
                eklenen += 1
            }
            try? baglam.save()
            ekleniyor = false
            if atlanan > 0 {
                bilgi = "\(eklenen) bölüm eklendi. \(atlanan) dosya zaten vardı, tekrar eklenmedi."
            } else if eklenen == 0 {
                bilgi = "Seçilenlerin içinde ses dosyası bulunamadı."
            }
        }
    }
}
