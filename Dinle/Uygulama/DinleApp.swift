import SwiftUI
import SwiftData

@main
struct DinleApp: App {
    @UIApplicationDelegateAdaptor(UygulamaTemsilcisi.self) private var uygulamaTemsilcisi
    private let kapsayici: ModelContainer
    @State private var oynatici: Oynatici
    @State private var indirici: Indirici

    init() {
        do {
            #if DEBUG
            let bellekte = DemoVerisi.acik
            #else
            let bellekte = false
            #endif
            let ayar = ModelConfiguration(isStoredInMemoryOnly: bellekte)
            kapsayici = try ModelContainer(for: Program.self, Bolum.self, Sarki.self, Klasor.self, KlasorOgesi.self,
                                       configurations: ayar)
        } catch {
            fatalError("Veri deposu açılamadı: \(error)")
        }
        #if DEBUG
        if DemoVerisi.acik { DemoVerisi.yukle(kapsayici.mainContext) }
        #endif
        _oynatici = State(initialValue: Oynatici(baglam: kapsayici.mainContext))
        _indirici = State(initialValue: Indirici(baglam: kapsayici.mainContext))
        Tema.uiKitGorunumunuAyarla()
    }

    var body: some Scene {
        WindowGroup {
            KokGorunum()
                .environment(oynatici)
                .environment(indirici)
                .tint(Tema.vurgu)
        }
        .modelContainer(kapsayici)
    }
}
