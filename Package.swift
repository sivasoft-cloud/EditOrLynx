// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EditOrLynx",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "EditOrLynx", targets: ["EditOrLynx"]),
        .library(name: "PounceCore", targets: ["PounceCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/aptabase/aptabase-swift", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "PounceCore",
            path: "Sources/PounceCore"
        ),
        .executableTarget(
            name: "EditOrLynx",
            dependencies: [
                "PounceCore",
                .product(name: "Aptabase", package: "aptabase-swift")
            ],
            path: "Sources/Pounce",
            exclude: [
                "SuperIsland/Resources/Assets.xcassets",
                "SuperIsland/Onboarding/Hello.json"
            ],
            resources: [
                .process("Resources"),
                .copy("SuperIsland/Resources")
            ]
        ),
        .executableTarget(
            name: "PounceChecks",
            dependencies: ["PounceCore"],
            path: "Sources/PounceChecks"
        )
    ]
)
