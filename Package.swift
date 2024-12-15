// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Cacao",
    products: [
        .library(
            name: "Cacao",
            targets: ["Cacao"]
        ),
        .executable(
            name: "CacaoDemo",
            targets: ["CacaoDemo"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/Silica.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/PureSwift/Cairo.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/PureSwift/SDL.git",
            branch: "master"
        )
    ],
    targets: [
        .target(
            name: "Cacao",
            dependencies: [
                "Silica",
                "Cairo",
                "SDL"
            ]
        ),
        .executableTarget(
            name: "CacaoDemo",
            dependencies: [
                "Cacao"
            ]
        )
    ]
)
