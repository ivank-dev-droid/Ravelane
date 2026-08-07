// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RavelaneCLI",
    products: [
        .executable(name: "RavelaneCLI", targets: ["RavelaneCLI"])
    ],
    dependencies: [
        .package(path: "../../Packages/RavelaneCore")
    ],
    targets: [
        .executableTarget(
            name: "RavelaneCLI",
            dependencies: [.product(name: "RavelaneCore", package: "RavelaneCore")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
