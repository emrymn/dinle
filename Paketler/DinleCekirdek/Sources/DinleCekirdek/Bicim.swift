import Foundation

/// Ekranda gösterilen süre, tarih ve hız metinleri (Türkçe).
public enum Bicim {

    /// Oynatıcı saati: "0:05", "12:05", "1:02:05".
    public static func zaman(_ saniye: Double) -> String {
        let t = saniye.isFinite ? max(0, Int(saniye.rounded(.down))) : 0
        let sa = t / 3600, dk = (t % 3600) / 60, sn = t % 60
        if sa > 0 { return String(format: "%d:%02d:%02d", sa, dk, sn) }
        return String(format: "%d:%02d", dk, sn)
    }

    /// Kısa süre: "45 dk", "1 sa 12 dk", "2 sa". Bir dakikadan kısa her şey "1 dk".
    public static func sure(_ saniye: Double) -> String {
        guard saniye.isFinite, saniye > 0 else { return "" }
        let dakika = max(1, Int((saniye / 60).rounded()))
        let sa = dakika / 60, dk = dakika % 60
        if sa == 0 { return "\(dk) dk" }
        if dk == 0 { return "\(sa) sa" }
        return "\(sa) sa \(dk) dk"
    }

    /// "12 dk kaldı".
    public static func kalan(konum: Double, sure: Double) -> String {
        guard sure > 0 else { return "" }
        return Bicim.sure(max(sure - konum, 1)) + " kaldı"
    }

    public static let aylar = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
                               "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

    /// "14 Mayıs 2023".
    public static func tarih(_ d: Date, takvim: Calendar = .current) -> String {
        let b = takvim.dateComponents([.year, .month, .day], from: d)
        guard let y = b.year, let a = b.month, let g = b.day else { return "" }
        return "\(g) \(aylar[a - 1]) \(y)"
    }

    /// "1×", "1,5×", "1,75×".
    public static func hiz(_ h: Float) -> String {
        var s = String(format: "%.2f", h)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s.replacingOccurrences(of: ".", with: ",") + "×"
    }

    /// Dosya boyutu: "512 MB", "1,2 GB".
    public static func boyut(_ bayt: Int64) -> String {
        let mb = Double(bayt) / 1_048_576
        if mb < 1024 { return "\(Int(mb.rounded())) MB" }
        return String(format: "%.1f GB", mb / 1024).replacingOccurrences(of: ".", with: ",")
    }
}
