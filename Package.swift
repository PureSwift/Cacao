// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Cacao",
    products: [
        .library(
            name: "Cacao",
            type: .dynamic,
            targets: ["Cacao"]
        ),
        .executable(
            name: "CacaoDemo",
            targets: ["CacaoDemo"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/SDL.git",
            .branch("master")
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
        .target(
            name: "CacaoDemo",
            dependencies: [
                "Cacao"
            ]
        ),
    ]
)
