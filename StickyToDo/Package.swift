// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "StickyToDo",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "StickyToDo", targets: ["StickyToDo"])
    ],
    targets: [
        .executableTarget(
            name: "StickyToDo",
            path: "Sources/StickyToDo",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "StickyToDoTests",
            dependencies: ["StickyToDo"],
            path: "Tests/StickyToDoTests"
        )
    ]
)
