import SwiftUI

enum Sekme: Hashable {
    case anaSayfa, podcastler, muzik, ayarlar
}

struct KokGorunum: View {
    @Environment(Oynatici.self) private var oynatici
    @Environment(\.scenePhase) private var sahne
    @State private var sekme: Sekme = .anaSayfa
    @State private var oynaticiAcik = false

    var body: some View {
        TabView(selection: $sekme) {
            AnaSayfa(sekme: $sekme)
                .miniOynaticili($oynaticiAcik)
                .tabItem { Label("Ana Sayfa", systemImage: "house") }
                .tag(Sekme.anaSayfa)

            PodcastlerEkrani()
                .miniOynaticili($oynaticiAcik)
                .tabItem { Label("Podcastler", systemImage: "mic") }
                .tag(Sekme.podcastler)

            MuzikEkrani()
                .miniOynaticili($oynaticiAcik)
                .tabItem { Label("Müzik", systemImage: "music.note") }
                .tag(Sekme.muzik)

            AyarlarEkrani()
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
                .tag(Sekme.ayarlar)
        }
        .sheet(isPresented: $oynaticiAcik) {
            OynaticiEkrani()
                .presentationDragIndicator(.visible)
        }
        .onChange(of: sahne) { _, yeni in
            if yeni != .active { oynatici.konumuKaydet() }
        }
        .alert("Bir sorun var", isPresented: Binding(
            get: { oynatici.hata != nil },
            set: { if !$0 { oynatici.hata = nil } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(oynatici.hata ?? "")
        }
    }
}

extension View {
    /// Sekmenin altına, sekme çubuğunun hemen üstüne mini oynatıcıyı yerleştirir.
    func miniOynaticili(_ acik: Binding<Bool>) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            MiniOynatici(acik: acik)
        }
    }
}
