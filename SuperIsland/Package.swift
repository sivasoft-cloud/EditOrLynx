// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuperIsland",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SuperIsland", targets: ["SuperIsland"])
    ],
    dependencies: [
        .package(url: "https://github.com/aptabase/aptabase-swift", from: "0.3.0")
    ],
    targets: [
        .executableTarget(
            name: "SuperIsland",
            dependencies: [
                .product(name: "Aptabase", package: "aptabase-swift")
            ],
            path: "Sources/SuperIsland",
            exclude: [
                "Resources/Assets.xcassets"
            ],
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
