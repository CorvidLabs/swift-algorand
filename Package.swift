// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-algorand",
    platforms: [
        .iOS(.v15),
        .macOS(.v11),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Algorand",
            targets: ["Algorand"]
        ),
        .executable(
            name: "algorand-example",
            targets: ["AlgorandExample"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "Algorand",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .executableTarget(
            name: "AlgorandExample",
            dependencies: ["Algorand"],
            path: "Sources/AlgorandExample"
        ),
        .testTarget(
            name: "AlgorandTests",
            dependencies: ["Algorand"]
        ),
    ]
)
