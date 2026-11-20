import SwiftUI
import SwiftData

@main
struct DinleApp: App {
    private let kapsayici: ModelContainer
    @State private var oynatici: Oynatici

    init() {
        do {
            kapsayici = try ModelContainer(for: Program.self, Bolum.self, Sarki.self)
        } catch {
            fatalError("Veri deposu açılamadı: \(error)")
        }
        _oynatici = State(initialValue: Oynatici(baglam: kapsayici.mainContext))
        Tema.uiKitGorunumunuAyarla()
    }

    var body: some Scene {
        WindowGroup {
            KokGorunum()
                .environment(oynatici)
                .tint(Tema.vurgu)
        }
        .modelContainer(kapsayici)
    }
}
