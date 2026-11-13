// swift-tools-version:6.4
import PackageDescription

/// Cacao: the SwiftUI API, implemented in Swift, for Linux and macOS.
///
/// See `Documentation/Plan.md` for the architecture. In short:
///
/// - `Cacao`: the public SwiftUI API, evaluation, layout and the display list.
///   No SDL and no GPU, so it builds and tests headless anywhere.
/// - `CacaoScrollPhysics`: velocity, deceleration, rubber band and spring-back.
/// - `CacaoCompositor`: the layer tree, drawn with Silica only when content
///   changes and composited on the GPU every frame.
/// - `CacaoSDL`: windows, the main loop, input and the SDL3 renderer backend.
/// - `SwiftUI` (Linux only): re-exports Cacao so `import SwiftUI` compiles.
let package = Package(
    name: "Cacao",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Cacao",
            targets: ["Cacao"]
        ),
        .library(
            name: "CacaoSDL",
            targets: ["CacaoSDL"]
        ),
        .library(
            name: "CacaoScrollPhysics",
            targets: ["CacaoScrollPhysics"]
        ),
        .executable(
            name: "CacaoDemo",
            targets: ["CacaoDemo"]
        )
    ] + swiftUIProducts,
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/Silica.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/PureSwift/SDL.git",
            branch: "master"
        )
    ],
    targets: [
        .target(
            name: "Cacao"
        ),
        .target(
            name: "CacaoScrollPhysics"
        ),
        .target(
            name: "CacaoCompositor",
            dependencies: [
                "Cacao",
                .product(
                    name: "Silica",
                    package: "Silica"
                ),
                .product(
                    name: "SilicaCoreGraphics",
                    package: "Silica",
                    condition: .when(platforms: [.macOS])
                ),
                .product(
                    name: "SilicaCairo",
                    package: "Silica",
                    condition: .when(platforms: [.linux])
                )
            ]
        ),
        .target(
            name: "CacaoSDL",
            dependencies: [
                "Cacao",
                "CacaoCompositor",
                "CacaoScrollPhysics",
                .product(
                    name: "SDL3Swift",
                    package: "SDL"
                )
            ]
        ),
        .executableTarget(
            name: "CacaoDemo",
            dependencies: [
                "Cacao",
                "CacaoSDL"
            ]
        ),
        .testTarget(
            name: "CacaoTests",
            dependencies: ["Cacao"]
        ),
        .testTarget(
            name: "CacaoScrollPhysicsTests",
            dependencies: ["CacaoScrollPhysics"]
        ),
        .testTarget(
            name: "CacaoCompositorTests",
            dependencies: ["CacaoCompositor"]
        ),
        .testTarget(
            name: "CacaoSDLTests",
            dependencies: ["CacaoSDL"]
        )
    ] + swiftUITargets
)

// MARK: - SwiftUI alias module

// On Linux, a `SwiftUI` module re-exports Cacao so unmodified sources that
// `import SwiftUI` compile. On macOS it would clash with Apple's SwiftUI.
#if os(Linux)
var swiftUIProducts: [Product] {
    [.library(name: "SwiftUI", targets: ["SwiftUI"])]
}
var swiftUITargets: [Target] {
    [.target(name: "SwiftUI", dependencies: ["Cacao", "CacaoSDL"])]
}
#else
var swiftUIProducts: [Product] { [] }
var swiftUITargets: [Target] { [] }
#endif
