import SwiftUI
import DinleCekirdek

/// Bir bölüm satırı: tarih, başlık, durum (Bitti / kalan süre / toplam süre).
struct BolumSatiri: View {
    let bolum: Bolum
    var programAdiGoster = false
    @Environment(Oynatici.self) private var oynatici

    private var ustSatir: String {
        var parcalar: [String] = []
        if let t = bolum.yayinTarihi { parcalar.append(Bicim.tarih(t)) }
        if programAdiGoster, let ad = bolum.program?.ad { parcalar.append(ad) }
        return parcalar.joined(separator: " · ")
    }

    /// Çalan bölümde canlı konum, değilse kayıtlı konum.
    private var konum: Double { oynatici.bolum === bolum ? oynatici.konum : bolum.konum }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                if !ustSatir.isEmpty {
                    UstBaslik(ustSatir).lineLimit(1)
                }
                Text(bolum.baslik)
                    .font(Tema.serif(.body))
                    .foregroundStyle(bolum.bitti ? .secondary : .primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    durumSatiri
                    IndirmeGostergesi(bolum: bolum)
                }
            }
            Spacer(minLength: 0)
            OynatDugmesi(caliyor: oynatici.caliyorMu(bolum))
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var durumSatiri: some View {
        switch bolum.durum {
        case .bitti:
            Label("Bitti", systemImage: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        case .yarida:
            HStack(spacing: 8) {
                IlerlemeCizgisi(oran: DinlemeKurallari.oran(konum: konum, sure: bolum.sure))
                    .frame(width: 64)
                Text(Bicim.kalan(konum: konum, sure: bolum.sure))
                    .font(.caption)
                    .foregroundStyle(Tema.vurgu)
            }
        case .yeni:
            if bolum.sure > 0 {
                Text(Bicim.sure(bolum.sure))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
