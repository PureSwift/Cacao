// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cacao",
    /*exclude: ["Resources"],*/
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Cacao",
            targets: ["Cacao"]
        ),
        .executable(
            name: "CacaoDemo",
            targets: ["CacaoDemo"]
        )
        ],
    dependencies: [
        .package(url: "https://github.com/PureSwift/CSDL2.git", .branch("master")),
        .package(url: "https://github.com/PureSwift/SDL.git", .branch("master")),
        .package(url: "https://github.com/PureSwift/Silica.git", .branch("master")),
        .package(url: "https://github.com/PureSwift/Cairo.git", .branch("master"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Cacao",
            dependencies: ["Cairo", "Silica", "SDL"]),
        .target(
            name: "CacaoDemo",
            dependencies: ["Cacao"]),
        .testTarget(
            name: "CacaoTests",
            dependencies: ["Cacao"])
        ]
)
