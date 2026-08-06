// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RavelinCLI",
    products: [
        .executable(name: "RavelinCLI", targets: ["RavelinCLI"])
    ],
    dependencies: [
        .package(path: "../../Packages/RavelinCore")
    ],
    targets: [
        .executableTarget(
            name: "RavelinCLI",
            dependencies: [.product(name: "RavelinCore", package: "RavelinCore")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
