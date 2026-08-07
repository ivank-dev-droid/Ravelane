// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RavelaneCore",
    products: [
        .library(name: "RavelaneCore", targets: ["RavelaneCore"])
    ],
    targets: [
        .target(
            name: "RavelaneCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "RavelaneCoreTests",
            dependencies: ["RavelaneCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
