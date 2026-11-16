// swift-tools-version:6.4
import PackageDescription

/// DarwinAppRuntime's SwiftUI renderer, `DarwinUI`, compiled and tested
/// against Cacao. `sync.sh` copies its sources and tests in: unmodified on
/// Linux, through Cacao's `SwiftUI` and `Combine` modules; on macOS with
/// `import Cacao` in place of `import SwiftUI`, which is Apple's there.
///
/// AppRuntime comes from `APPRUNTIME_PATH`, or a checkout beside Cacao's.
let appRuntime = Context.environment["APPRUNTIME_PATH"] ?? "../../../AppRuntime"

#if os(Linux)
let ui: [Target.Dependency] = [
    .product(name: "SwiftUI", package: "Cacao"),
    .product(name: "Combine", package: "Cacao"),
    .product(name: "Cacao", package: "Cacao"),
]
#else
let ui: [Target.Dependency] = [.product(name: "Cacao", package: "Cacao")]
#endif

/// DarwinAppRuntime's host code is Swift 5 language mode.
let host: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "DarwinUIOnCacao",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "Cacao", path: "../.."),
        .package(name: "AppRuntime", path: appRuntime),
    ],
    targets: [
        // The part of DarwinHost the renderer uses: its logger, bundle and
        // module protocol.
        .target(
            name: "DarwinHost",
            dependencies: [
                .product(name: "RuntimeCore", package: "AppRuntime"),
                .product(name: "RuntimeNative", package: "AppRuntime"),
                .product(name: "DynamicRuntime", package: "AppRuntime"),
            ],
            swiftSettings: host
        ),
        .target(
            name: "DarwinUI",
            dependencies: ["DarwinHost", .product(name: "DynamicUI", package: "AppRuntime")] + ui,
            swiftSettings: host
        ),
        // Shows the rendering tests' tree in a Cacao window.
        .executableTarget(
            name: "RendererDemo",
            dependencies: [
                "DarwinUI",
                .product(name: "Cacao", package: "Cacao"),
                .product(name: "CacaoSDL", package: "Cacao"),
                .product(name: "DynamicUI", package: "AppRuntime"),
                .product(name: "DynamicRuntime", package: "AppRuntime"),
            ],
            swiftSettings: host
        ),
        .testTarget(
            name: "DarwinUITests",
            dependencies: [
                "DarwinUI",
                .product(name: "DynamicUI", package: "AppRuntime"),
                .product(name: "DynamicRuntime", package: "AppRuntime"),
            ] + ui,
            swiftSettings: host
        ),
    ]
)
