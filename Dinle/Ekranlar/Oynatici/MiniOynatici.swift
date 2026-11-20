import SwiftUI

struct MiniOynatici: View {
    @Environment(Oynatici.self) private var oynatici
    @Binding var acik: Bool

    var body: some View {
        if oynatici.tur != nil {
            VStack(spacing: 0) {
                IlerlemeCizgisi(oran: oynatici.oran, yukseklik: 2)
                HStack(spacing: 12) {
                    KapakGorseli(veri: oynatici.kapak, boyut: 42, kose: 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(oynatici.baslik)
                            .font(Tema.serif(.subheadline))
                            .lineLimit(1)
                        Text(oynatici.altBaslik)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Button {
                        oynatici.oynatDuraklat()
                    } label: {
                        Image(systemName: oynatici.caliyor ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(oynatici.caliyor ? "Duraklat" : "Oynat")

                    Button {
                        oynatici.tur == .podcast ? oynatici.ileriAtla() : oynatici.sonrakiSarki()
                    } label: {
                        Image(systemName: oynatici.tur == .podcast ? "goforward.\(Int(Ayarlar.ileriAtlama))" : "forward.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(oynatici.tur == .podcast ? "İleri atla" : "Sonraki şarkı")
                }
                .foregroundStyle(.primary)
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 6)
            }
            .background(.bar)
            .contentShape(Rectangle())
            .onTapGesture { acik = true }
            .overlay(alignment: .bottom) { Divider() }
        }
    }
}
