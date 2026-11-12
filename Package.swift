// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Notatka",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Notatka", targets: ["Notatka"])
    ],
    targets: [
        .executableTarget(
            name: "Notatka",
            path: "Sources/Notatka",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "NotatkaTests",
            dependencies: ["Notatka"],
            path: "Tests/NotatkaTests"
        )
    ]
)
