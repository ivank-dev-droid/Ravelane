// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RavelinCore",
    products: [
        .library(name: "RavelinCore", targets: ["RavelinCore"])
    ],
    targets: [
        .target(
            name: "RavelinCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "RavelinCoreTests",
            dependencies: ["RavelinCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
