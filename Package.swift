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
/// - `CacaoTokens`: the colors, gradients, radii, fonts and metrics of the
///   desktop's look, for an appearance. No SwiftUI, so other UI frameworks
///   can match Cacao's styles.
/// - `Cacao`: the public SwiftUI API, evaluation and layout, which builds
///   display lists. No SDL and no GPU, so it builds and tests headless anywhere.
/// - `CacaoMacros`: the `@Entry` macro.
/// - `CacaoScrollPhysics`: velocity, deceleration, rubber band and spring-back.
/// - `CacaoCompositor`: the layer tree, drawn with Silica only when content
///   changes and composited on the GPU every frame.
/// - `CacaoSDLRenderer`: the compositor's SDL3 renderer backend, and
///   `HostRenderer`, which draws display lists with a renderer that belongs
///   to a UI framework with windows of its own.
/// - `CacaoHost`: SDL3 windows, the main loop and frame clock and input,
///   showing whatever implements `HostScene`.
/// - `CacaoSDL`: SwiftUI on the host: a view graph as each window's scene.
/// - `CacaoWayland` (Linux): touchpad pinch rotations from Wayland, which SDL
///   doesn't report, layer-shell surfaces for panels and docks, popups as
///   surfaces of their own (`xdg_popup`, a layer surface's too), and the KDE
///   appmenu protocol, which ties windows to their menus. A C library, so
///   other UI frameworks can tie their windows to menus too.
/// - `CacaoDBus`: the desktop's services over D-Bus, with PureSwift/DBus:
///   the settings portal's appearance. No SwiftUI and no SDL; `CacaoHost`
///   uses it on Linux.
/// - `CacaoDBusMenu`: menus over `com.canonical.dbusmenu`: a model of menu
///   items, an exporter for apps and a reader for menu bars. Only
///   PureSwift/DBus, so Cacao apps, Perry and the shell share it.
/// - `SwiftUI` and `Combine` (Linux only): re-export Cacao so `import SwiftUI`
///   and `import Combine` compile.
let package = Package(
    name: "Cacao",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
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
            name: "CacaoTokens",
            targets: ["CacaoTokens"]
        ),
        .library(
            name: "CacaoCompositor",
            targets: ["CacaoCompositor"]
        ),
        .library(
            name: "CacaoSDLRenderer",
            targets: ["CacaoSDLRenderer"]
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
        .library(
            name: "CacaoWayland",
            targets: ["CacaoWayland"]
        ),
        .library(
            name: "CacaoDBus",
            targets: ["CacaoDBus"]
        ),
        .library(
            name: "CacaoDBusMenu",
            targets: ["CacaoDBusMenu"]
        ),
        .executable(
            name: "CacaoDemo",
            targets: ["CacaoDemo"]
        )
    ] + swiftUIProducts,
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/Silica.git",
            // SilicaQuartz was added after the 3.0.0 tag.
            branch: "master"
        ),
        .package(
            url: "https://github.com/PureSwift/SDL.git",
            exact: "3.3.0"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            // Silica's JavaScriptKit dependency requires SwiftSyntax below 604.
            "602.0.0"..<"604.0.0"
        ),
        .package(
            url: "https://github.com/PureSwift/DBus.git",
            exact: "0.3.1"
        )
    ],
    targets: [
        .target(
            name: "CacaoRender",
            exclude: ["CMakeLists.txt"]
        ),
        // The desktop's look as values: colors, gradients, radii, fonts and
        // metrics. Kept apart so other UI frameworks can read it without
        // SwiftUI.
        .target(
            name: "CacaoTokens",
            dependencies: ["CacaoRender"],
            exclude: ["CMakeLists.txt"]
        ),
        .target(
            name: "Cacao",
            dependencies: ["CacaoRender", "CacaoTokens", "CacaoMacros"],
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
                    name: "SilicaQuartz",
                    package: "Silica",
                    condition: .when(platforms: [.macOS, .iOS])
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
            name: "CacaoSDLRenderer",
            dependencies: [
                "CacaoRender",
                "CacaoCompositor",
                .product(
                    name: "SDL3Swift",
                    package: "SDL"
                )
            ],
            exclude: ["CMakeLists.txt"],
            // On iOS, SDL3 is a static library, so what it uses is linked
            // here: its package configuration's frameworks.
            linkerSettings: sdlFrameworks.map { .linkedFramework($0, .when(platforms: [.iOS])) }
        ),
        .target(
            name: "CacaoHost",
            dependencies: [
                "CacaoRender",
                "CacaoCompositor",
                "CacaoSDLRenderer",
                .target(
                    name: "CacaoWayland",
                    condition: .when(platforms: [.linux])
                ),
                .target(
                    name: "CacaoDBus",
                    condition: .when(platforms: [.linux])
                ),
                .product(
                    name: "SDL3Swift",
                    package: "SDL"
                )
            ],
            exclude: ["CMakeLists.txt"],
            // On iOS, SDL3 is a static library, so what it uses is linked
            // here: its package configuration's frameworks.
            linkerSettings: sdlFrameworks.map { .linkedFramework($0, .when(platforms: [.iOS])) }
        ),
        .target(
            name: "CacaoSDL",
            dependencies: [
                "Cacao",
                "CacaoTokens",
                "CacaoCompositor",
                "CacaoHost",
                "CacaoScrollPhysics",
                .target(
                    name: "CacaoDBusMenu",
                    condition: .when(platforms: [.linux])
                ),
                .product(
                    name: "DBus",
                    package: "DBus",
                    condition: .when(platforms: [.linux])
                ),
                .product(
                    name: "SDL3Swift",
                    package: "SDL"
                )
            ],
            exclude: ["CMakeLists.txt"]
        ),
        // Touchpad pinch rotations from Wayland compositors, which SDL
        // doesn't report, layer-shell surfaces for panels and docks, popups
        // as surfaces of their own, and the KDE appmenu protocol, which ties
        // windows to their menus.
        .target(
            name: "CacaoWayland",
            exclude: ["protocol", "CMakeLists.txt"],
            linkerSettings: [
                .linkedLibrary("wayland-client", .when(platforms: [.linux]))
            ]
        ),
        // The desktop's services over D-Bus: the settings portal's
        // appearance. Kept apart so `Cacao` stays free of D-Bus.
        .target(
            name: "CacaoDBus",
            dependencies: [
                "CacaoTokens",
                .product(
                    name: "DBus",
                    package: "DBus"
                ),
                .product(name: "FreedesktopPortal", package: "DBus")
            ],
            exclude: ["CMakeLists.txt"]
        ),
        // Menus over com.canonical.dbusmenu, for apps that export them and
        // menu bars that show them. Only D-Bus, so other UI frameworks and
        // the shell can use it.
        .target(
            name: "CacaoDBusMenu",
            dependencies: [
                .product(
                    name: "DBus",
                    package: "DBus"
                ),
                .product(name: "StatusNotifier", package: "DBus")
            ],
            exclude: ["CMakeLists.txt"]
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
            name: "CacaoTokensTests",
            dependencies: ["CacaoTokens"]
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
            name: "CacaoDBusTests",
            dependencies: [
                "CacaoDBus",
                "CacaoDBusMenu",
                "CacaoTokens",
                .product(
                    name: "DBus",
                    package: "DBus"
                )
            ]
        ),
        .testTarget(
            name: "CacaoSDLTests",
            dependencies: [
                "CacaoSDL",
                "CacaoSDLRenderer",
                .product(
                    name: "SDL3Swift",
                    package: "SDL"
                )
            ]
        )
    ] + swiftUITargets + waylandTestTargets + layoutParityTargets
)

// MARK: - SDL on iOS

var sdlFrameworks: [String] {
    [
        "AVFoundation", "AudioToolbox", "CoreAudio", "CoreBluetooth", "CoreGraphics", "CoreHaptics",
        "CoreMedia", "CoreMotion", "CoreVideo", "Foundation", "GameController", "Metal", "OpenGLES",
        "QuartzCore", "UIKit",
    ]
}

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
