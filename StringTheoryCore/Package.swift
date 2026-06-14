// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StringTheoryCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14), // lets `swift test` run natively on the Mac host
    ],
    products: [
        .library(name: "StringTheoryCore", targets: ["StringTheoryCore"]),
    ],
    targets: [
        .target(
            name: "StringTheoryCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "StringTheoryCoreTests",
            dependencies: ["StringTheoryCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
