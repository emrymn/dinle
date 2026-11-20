import SwiftUI
import DinleCekirdek

struct AyarlarEkrani: View {
    @Environment(Oynatici.self) private var oynatici

    @AppStorage(Ayarlar.Anahtar.akilliGeriSarma) private var akilliGeriSarma = true
    @AppStorage(Ayarlar.Anahtar.sonrakiniCal) private var sonrakiniCal = true
    @AppStorage(Ayarlar.Anahtar.ileriAtlama) private var ileriAtlama: Double = 30
    @AppStorage(Ayarlar.Anahtar.geriAtlama) private var geriAtlama: Double = 15

    @State private var kullanilanAlan: Int64 = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Akıllı geri sarma", isOn: $akilliGeriSarma)
                    Toggle("Bölüm bitince sıradakini çal", isOn: $sonrakiniCal)
                    Picker("İleri atlama", selection: $ileriAtlama) {
                        ForEach(Ayarlar.ileriSecenekleri, id: \.self) { Text("\(Int($0)) sn").tag($0) }
                    }
                    Picker("Geri atlama", selection: $geriAtlama) {
                        ForEach(Ayarlar.geriSecenekleri, id: \.self) { Text("\(Int($0)) sn").tag($0) }
                    }
                } header: {
                    Text("Podcast")
                } footer: {
                    Text("Akıllı geri sarma: ara verdikten sonra devam ederken, verdiğin aranın uzunluğuna göre 3–30 sn geri sarar.")
                }

                Section {
                    Label("İki kez dokun: \(Int(ileriAtlama)) sn ileri", systemImage: "airpods")
                    Label("Üç kez dokun: \(Int(geriAtlama)) sn geri", systemImage: "airpods")
                    Label("Kulaktan çıkarınca durur, yerini kaydeder", systemImage: "ear")
                } header: {
                    Text("AirPods")
                } footer: {
                    Text("Müzikte iki/üç kez dokunmak sonraki/önceki şarkıya geçer.")
                }
                .foregroundStyle(.primary)

                Section("Depolama") {
                    LabeledContent("Eklenen dosyalar", value: Bicim.boyut(kullanilanAlan))
                }

                Section {
                    LabeledContent("Sürüm", value: surum)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.zemin)
            .navigationTitle("Ayarlar")
            .onAppear { kullanilanAlan = MedyaDeposu.kullanilanAlan() }
            .onChange(of: ileriAtlama) { oynatici.komutlariTureGoreAyarla() }
            .onChange(of: geriAtlama) { oynatici.komutlariTureGoreAyarla() }
        }
    }

    private var surum: String {
        let b = Bundle.main.infoDictionary
        let s = b?["CFBundleShortVersionString"] as? String ?? "?"
        let d = b?["CFBundleVersion"] as? String ?? "?"
        return "\(s) (\(d))"
    }
}
