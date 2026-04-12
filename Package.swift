// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Winduz",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Winduz", targets: ["Winduz"]),
        .executable(name: "wz", targets: ["WinduzCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(name: "WinduzCore", path: "Sources/WinduzCore"),
        .executableTarget(
            name: "Winduz",
            dependencies: ["WinduzCore"],
            path: "Sources/Winduz"
        ),
        .executableTarget(
            name: "WinduzCLI",
            dependencies: [
                "WinduzCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/WinduzCLI"
        ),
    ]
)
