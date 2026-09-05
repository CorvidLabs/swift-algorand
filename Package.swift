// swift-tools-version: 6.0
import Foundation
import PackageDescription

/// The DocC plugin is a build-time documentation tool, not a library dependency. Resolving it
/// costs every consumer a clone of swift-docc-plugin and swift-docc-symbolkit for a plugin they
/// never invoke, so it is included only when `ALGORAND_DOCC` is set in the environment:
///
///     ALGORAND_DOCC=1 swift package generate-documentation --target Algorand
///
/// The documentation workflow sets the variable before it builds; a plain `swift build` or
/// `swift test`, and every package that depends on this one, resolves without it.
let includesDocCPlugin = ProcessInfo.processInfo.environment["ALGORAND_DOCC"] != nil

var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
]

if includesDocCPlugin {
    dependencies.append(.package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"))
}

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
        )
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "Algorand",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .testTarget(
            name: "AlgorandTests",
            dependencies: ["Algorand"]
        ),
    ]
)
