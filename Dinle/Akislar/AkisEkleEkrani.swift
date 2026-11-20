import SwiftUI
import SwiftData

/// Substack ya da RSS linkiyle abone olma (ya da var olan arşiv programına akış bağlama).
struct AkisEkleEkrani: View {
    /// Verilirse yeni program açılmaz; akış bu programa bağlanır, arşivdeki dosyalarla birleşir.
    var program: Program?
    var eklendi: (Program) -> Void = { _ in }

    @Environment(\.dismiss) private var kapat
    @Environment(\.modelContext) private var baglam
    @State private var link = ""
    @State private var calisiyor = false
    @State private var hata: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ornek.substack.com ya da RSS linki", text: $link, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(1...4)
                    PasteButton(payloadType: String.self) { metinler in
                        if let ilk = metinler.first { link = ilk }
                    }
                } footer: {
                    Text("Substack yayınının adresini (ya da yalnızca adını) yazman yeter. Başka podcastler için RSS linkini yapıştır.")
                }

                Section {
                    Label("Substack'te yayının sayfasını aç.", systemImage: "1.circle")
                    Label("Podcast bölümünde **Listen on…** ya da **Podcast uygulamasında dinle**'ye dokun.", systemImage: "2.circle")
                    Label("**Copy private RSS link / Özel RSS linkini kopyala**'yı seç ve buraya yapıştır.", systemImage: "3.circle")
                } header: {
                    Text("Ücretli abonelikler")
                } footer: {
                    Text("Özel link sana aittir; ücretli bölümler onunla gelir. Kimseyle paylaşma.")
                }

                if let program {
                    Section {
                        Text("Akıştaki bölümler “\(program.ad)” programındaki dosyalarla başlık ve süreye göre eşleştirilir; aynı bölüm iki kez görünmez.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let hata {
                    Section {
                        Label(hata, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tema.zemin)
            .navigationTitle(program == nil ? "Abone ol" : "Akış bağla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { kapat() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(program == nil ? "Abone ol" : "Bağla") {
                        Task { await ekle() }
                    }
                    .disabled(link.trimmingCharacters(in: .whitespaces).isEmpty || calisiyor)
                }
            }
            .overlay {
                if calisiyor {
                    ProgressView("Akış okunuyor…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func ekle() async {
        calisiyor = true
        hata = nil
        do {
            let p = try await AkisYenileyici.ekle(girdi: link, program: program, baglam: baglam)
            calisiyor = false
            kapat()
            eklendi(p)
        } catch {
            calisiyor = false
            hata = (error as? LocalizedError)?.errorDescription ?? "Akış okunamadı: \(error.localizedDescription)"
        }
    }
}

/// Bölüm satırında küçük indirme göstergesi: iniyorsa yüzde halkası, indirilmemişse bulut.
struct IndirmeGostergesi: View {
    let bolum: Bolum
    @Environment(Indirici.self) private var indirici

    var body: some View {
        if let oran = indirici.oran(bolum) {
            ProgressView(value: max(oran, 0.02))
                .progressViewStyle(.circular)
                .controlSize(.mini)
                .tint(Tema.vurgu)
        } else if bolum.akistan && !bolum.indirildi {
            Image(systemName: "icloud")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("İndirilmedi")
        }
    }
}
