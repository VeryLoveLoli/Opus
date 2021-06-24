// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Opus",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Opus",
            targets: ["OpusSwift"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://gitee.com/cchsora/Print", .branch("master")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .binaryTarget(name: "Opus", path: "Sources/Opus/Opus.xcframework"),
        .target(name: "OpusSwift", dependencies: ["Opus", "Print"]),
        .testTarget(
            name: "OpusTests",
            dependencies: ["Opus", "OpusSwift"]),
    ]
)
