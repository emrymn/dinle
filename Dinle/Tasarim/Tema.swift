import SwiftUI
import UIKit

/// Substack tarzı sade görünüm: beyaz zemin, siyah metin, serif başlıklar, tek turuncu vurgu.
enum Tema {
    static let vurgu = Color(red: 1.0, green: 0.404, blue: 0.098)

    static let zemin = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.075, alpha: 1) : .white
    })

    /// Kartlar ve kapak yer tutucuları: kırık beyaz / koyu gri.
    static let kart = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 0.13, alpha: 1)
            : UIColor(red: 0.973, green: 0.965, blue: 0.953, alpha: 1)
    })

    static let cizgi = Color.primary.opacity(0.1)

    static func serif(_ stil: Font.TextStyle, _ agirlik: Font.Weight = .semibold) -> Font {
        .system(stil, design: .serif, weight: agirlik)
    }

    /// Gezinti çubuğu başlıklarını serif yapar.
    static func uiKitGorunumunuAyarla() {
        func serifFont(_ boyut: CGFloat, _ agirlik: UIFont.Weight) -> UIFont {
            let temel = UIFont.systemFont(ofSize: boyut, weight: agirlik)
            guard let tanim = temel.fontDescriptor.withDesign(.serif) else { return temel }
            return UIFont(descriptor: tanim, size: boyut)
        }
        let cubuk = UINavigationBar.appearance()
        cubuk.largeTitleTextAttributes = [.font: serifFont(34, .bold)]
        cubuk.titleTextAttributes = [.font: serifFont(17, .semibold)]
    }
}

// MARK: - Ortak parçalar

/// Küçük, büyük harfli üst başlık ("DEVAM ET", "14 MAYIS 2023").
struct UstBaslik: View {
    let metin: String
    init(_ metin: String) { self.metin = metin }

    var body: some View {
        Text(metin.uppercased(with: Locale(identifier: "tr")))
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

struct KapakGorseli: View {
    let veri: Data?
    var boyut: CGFloat = 56
    var kose: CGFloat = 6

    var body: some View {
        Group {
            if let veri, let resim = UIImage(data: veri) {
                Image(uiImage: resim)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Tema.kart
                    Image(systemName: "waveform")
                        .font(.system(size: boyut * 0.32, weight: .medium))
                        .foregroundStyle(Tema.vurgu.opacity(0.75))
                }
            }
        }
        .frame(width: boyut, height: boyut)
        .clipShape(RoundedRectangle(cornerRadius: kose, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: kose, style: .continuous).strokeBorder(Tema.cizgi, lineWidth: 0.5))
    }
}

struct IlerlemeCizgisi: View {
    let oran: Double
    var yukseklik: CGFloat = 3

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Tema.cizgi)
                Capsule().fill(Tema.vurgu)
                    .frame(width: g.size.width * min(max(oran, 0), 1))
            }
        }
        .frame(height: yukseklik)
    }
}

struct BosDurum: View {
    let simge: String
    let baslik: String
    let aciklama: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: simge)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Tema.vurgu)
            Text(baslik)
                .font(Tema.serif(.title3))
            Text(aciklama)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// Oynat/duraklat yuvarlağı (satırlarda).
struct OynatDugmesi: View {
    let caliyor: Bool
    var boyut: CGFloat = 34

    var body: some View {
        Image(systemName: caliyor ? "pause.fill" : "play.fill")
            .font(.system(size: boyut * 0.38, weight: .semibold))
            .foregroundStyle(Tema.vurgu)
            .frame(width: boyut, height: boyut)
            .overlay(Circle().strokeBorder(Tema.vurgu.opacity(0.35), lineWidth: 1))
    }
}

extension View {
    /// Liste satırlarını zeminle aynı renge boyar.
    func duzSatir() -> some View {
        listRowBackground(Tema.zemin)
            .listRowSeparatorTint(Tema.cizgi)
    }
}
