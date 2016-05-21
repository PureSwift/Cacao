import PackageDescription

let package = Package(
    name: "Cacao",
    dependencies: [
        .Package(url: "https://github.com/PureSwift/Silica.git", majorVersion: 1),
        .Package(url: "https://github.com/PureSwift/CXCB.git", majorVersion: 1)
    ],
    targets: [
                 Target(
                    name: "X11Demo",
                    dependencies: [.Target(name: "Cacao")]),
                 Target(
                    name: "CacaoTests",
                    dependencies: [.Target(name: "Cacao")]),
                 Target(
                    name: "Cacao")
    ],
    exclude: ["Xcode"]
)