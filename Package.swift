// swift-tools-version:6.4
import PackageDescription
import CompilerPluginSupport

/// Cacao: the SwiftUI API, implemented in Swift, for Linux and macOS.
///
/// See `Documentation/Plan.md` for the architecture. In short:
///
/// - `CacaoRender`: the display list and the values it's made of (paths,
///   colors, text, images, effects). No SwiftUI, so other UI frameworks can
///   draw through the compositor too.
/// - `Cacao`: the public SwiftUI API, evaluation and layout, which builds
///   display lists. No SDL and no GPU, so it builds and tests headless anywhere.
/// - `CacaoMacros`: the `@Entry` macro.
/// - `CacaoScrollPhysics`: velocity, deceleration, rubber band and spring-back.
/// - `CacaoCompositor`: the layer tree, drawn with Silica only when content
///   changes and composited on the GPU every frame.
/// - `CacaoHost`: SDL3 windows, the main loop and frame clock, input and the
///   SDL3 renderer backend, showing whatever implements `HostScene`.
/// - `CacaoSDL`: SwiftUI on the host: a view graph as each window's scene.
/// - `CacaoWayland` (Linux): touchpad pinch rotations from Wayland, which SDL
///   doesn't report.
/// - `SwiftUI` and `Combine` (Linux only): re-export Cacao so `import SwiftUI`
///   and `import Combine` compile.
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
            name: "CacaoRender",
            targets: ["CacaoRender"]
        ),
        .library(
            name: "CacaoCompositor",
            targets: ["CacaoCompositor"]
        ),
        .library(
            name: "CacaoHost",
            targets: ["CacaoHost"]
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
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            "602.0.0"..<"605.0.0"
        )
    ],
    targets: [
        .target(
            name: "CacaoRender",
            exclude: ["CMakeLists.txt"]
        ),
        .target(
            name: "Cacao",
            dependencies: ["CacaoRender", "CacaoMacros"],
            exclude: ["CMakeLists.txt"]
        ),
        .macro(
            name: "CacaoMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax")
            ],
            exclude: ["CMakeLists.txt"]
        ),
        .target(
            name: "CacaoScrollPhysics",
            exclude: ["CMakeLists.txt"]
        ),
        .target(
            name: "CacaoCompositor",
            dependencies: [
                "CacaoRender",
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
            ],
            exclude: ["CMakeLists.txt"]
        ),
        .target(
            name: "CacaoHost",
            dependencies: [
                "CacaoRender",
                "CacaoCompositor",
                .target(
                    name: "CacaoWayland",
                    condition: .when(platforms: [.linux])
                ),
                .product(
                    name: "SDL3Swift",
                    package: "SDL"
                )
            ],
            exclude: ["CMakeLists.txt"]
        ),
        .target(
            name: "CacaoSDL",
            dependencies: [
                "Cacao",
                "CacaoCompositor",
                "CacaoHost",
                "CacaoScrollPhysics",
                .product(
                    name: "SDL3Swift",
                    package: "SDL"
                )
            ],
            exclude: ["CMakeLists.txt"]
        ),
        // Touchpad pinch rotations from Wayland compositors, which SDL
        // doesn't report.
        .target(
            name: "CacaoWayland",
            exclude: ["protocol", "CMakeLists.txt"],
            linkerSettings: [
                .linkedLibrary("wayland-client", .when(platforms: [.linux]))
            ]
        ),
        .executableTarget(
            name: "CacaoDemo",
            dependencies: [
                "Cacao",
                "CacaoSDL"
            ],
            exclude: ["CMakeLists.txt"]
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
            dependencies: ["Cacao", "CacaoCompositor"]
        ),
        .testTarget(
            name: "CacaoSDLTests",
            dependencies: ["CacaoSDL"]
        )
    ] + swiftUITargets + waylandTestTargets + layoutParityTargets
)

// MARK: - SwiftUI and Combine alias modules

// On Linux, `SwiftUI` and `Combine` modules re-export Cacao so unmodified
// sources that import them compile. On macOS they would clash with Apple's.
#if os(Linux)
var swiftUIProducts: [Product] {
    [
        .library(name: "SwiftUI", targets: ["SwiftUI"]),
        .library(name: "Combine", targets: ["Combine"]),
    ]
}
var swiftUITargets: [Target] {
    [
        .target(name: "SwiftUI", dependencies: ["Cacao", "CacaoSDL"], exclude: ["CMakeLists.txt"]),
        // `import Combine` for `ObservableObject` and publishers, which
        // Cacao provides where there's no Combine.
        .target(name: "Combine", dependencies: ["Cacao"], exclude: ["CMakeLists.txt"]),
    ]
}
#else
var swiftUIProducts: [Product] { [] }
var swiftUITargets: [Target] { [] }
#endif

// MARK: - Wayland tests

// On Linux, Cacao's Wayland gestures are tested against a minimal
// compositor made with libwayland-server.
#if os(Linux)
var waylandTestTargets: [Target] {
    [
        .target(
            name: "CacaoWaylandTestServer",
            dependencies: ["CacaoWayland"],
            path: "Tests/CacaoWaylandTestServer",
            exclude: ["protocol"],
            linkerSettings: [.linkedLibrary("wayland-server"), .linkedLibrary("wayland-client")]
        ),
        .testTarget(
            name: "CacaoWaylandTests",
            dependencies: ["CacaoWayland", "CacaoWaylandTestServer"]
        ),
    ]
}
#else
var waylandTestTargets: [Target] { [] }
#endif

// MARK: - Layout parity

// On macOS, the same corpus of layouts (Tests/LayoutParity/LayoutCorpus.swift)
// is compiled against Apple's SwiftUI and against Cacao, and a test expects
// the same frames from both.
#if os(macOS)
var layoutParityTargets: [Target] {
    [
        .target(
            name: "CacaoParityApple",
            path: "Tests/LayoutParity/Apple",
            swiftSettings: [.define("PARITY_APPLE")]
        ),
        .target(
            name: "CacaoParityCacao",
            dependencies: ["Cacao"],
            path: "Tests/LayoutParity/Cacao"
        ),
        .testTarget(
            name: "CacaoLayoutParityTests",
            dependencies: ["CacaoParityApple", "CacaoParityCacao"],
            path: "Tests/LayoutParity/Tests"
        )
    ]
}
#else
var layoutParityTargets: [Target] { [] }
#endif
