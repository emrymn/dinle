import AVKit
import SwiftUI
import DinleCekirdek

/// Tam ekran oynatıcı.
struct OynaticiEkrani: View {
    @Environment(Oynatici.self) private var oynatici
    @State private var surukleme: Double?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            KapakGorseli(veri: oynatici.kapak, boyut: 290, kose: 10)
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)

            VStack(spacing: 8) {
                UstBaslik(oynatici.altBaslik)
                    .lineLimit(1)
                Text(oynatici.baslik)
                    .font(Tema.serif(.title2, .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .padding(.top, 32)

            konumCubugu
                .padding(.top, 28)

            kontroller
                .padding(.top, 20)

            altSatir
                .padding(.top, 28)

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tema.zemin)
    }

    private var gosterilenKonum: Double { surukleme ?? oynatici.konum }

    private var konumCubugu: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(get: { gosterilenKonum }, set: { surukleme = $0 }),
                in: 0...max(oynatici.sure, 1),
                onEditingChanged: { basladi in
                    if !basladi, let s = surukleme {
                        oynatici.atla(konuma: s)
                        surukleme = nil
                    }
                }
            )
            HStack {
                Text(Bicim.zaman(gosterilenKonum))
                Spacer()
                Text("-" + Bicim.zaman(max(oynatici.sure - gosterilenKonum, 0)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var kontroller: some View {
        HStack(spacing: 44) {
            if oynatici.tur == .podcast {
                Button { oynatici.geriAtla() } label: {
                    Image(systemName: "gobackward.\(Int(Ayarlar.geriAtlama))").font(.system(size: 30))
                }
                .accessibilityLabel("Geri atla")
            } else {
                Button { oynatici.oncekiSarki() } label: {
                    Image(systemName: "backward.fill").font(.system(size: 28))
                }
                .accessibilityLabel("Önceki")
            }

            Button { oynatici.oynatDuraklat() } label: {
                Image(systemName: oynatici.caliyor ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Tema.vurgu)
            }
            .accessibilityLabel(oynatici.caliyor ? "Duraklat" : "Oynat")

            if oynatici.tur == .podcast {
                Button { oynatici.ileriAtla() } label: {
                    Image(systemName: "goforward.\(Int(Ayarlar.ileriAtlama))").font(.system(size: 30))
                }
                .accessibilityLabel("İleri atla")
            } else {
                Button { oynatici.sonrakiSarki() } label: {
                    Image(systemName: "forward.fill").font(.system(size: 28))
                }
                .accessibilityLabel("Sonraki")
            }
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var altSatir: some View {
        HStack {
            if oynatici.tur == .podcast {
                Menu {
                    ForEach(Ayarlar.hizSecenekleri, id: \.self) { h in
                        Button {
                            oynatici.hiziAyarla(h)
                        } label: {
                            if h == oynatici.hiz {
                                Label(Bicim.hiz(h), systemImage: "checkmark")
                            } else {
                                Text(Bicim.hiz(h))
                            }
                        }
                    }
                } label: {
                    Text(Bicim.hiz(oynatici.hiz))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(Tema.cizgi))
                }
                .accessibilityLabel("Hız")
            } else {
                Button { oynatici.karisikDegistir() } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(oynatici.karisik ? Tema.vurgu : .secondary)
                }
                .accessibilityLabel("Karışık çal")
                Spacer().frame(width: 28)
                Button { oynatici.tekrar = oynatici.tekrar.sonraki } label: {
                    Image(systemName: oynatici.tekrar.simge)
                        .foregroundStyle(oynatici.tekrar == .kapali ? .secondary : Tema.vurgu)
                }
                .accessibilityLabel("Tekrar")
            }
            Spacer()
            YonlendirmeSecici()
                .frame(width: 32, height: 32)
                .accessibilityLabel("Ses çıkışı")
        }
        .font(.title3)
        .foregroundStyle(.primary)
    }
}

/// AirPods / hoparlör / AirPlay seçimi.
struct YonlendirmeSecici: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.activeTintColor = UIColor(Tema.vurgu)
        v.tintColor = .secondaryLabel
        v.prioritizesVideoDevices = false
        return v
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
