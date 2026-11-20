// swift-tools-version:5.9
// Dinle'nin arayüzden bağımsız mantığı: tarih çözme, dinleme kuralları, biçimlendirme.
// Linux'ta da derlenir; `swift test` ile Mac olmadan sınanabilir.
import PackageDescription

let package = Package(
    name: "DinleCekirdek",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DinleCekirdek", targets: ["DinleCekirdek"]),
    ],
    targets: [
        .target(name: "DinleCekirdek"),
        .testTarget(name: "DinleCekirdekTests", dependencies: ["DinleCekirdek"]),
    ]
)
