import PackageDescription

let package = Package(
    name: "Cacao",
    targets: [
                 Target(
                    name: "Demo",
                    dependencies: [.Target(name: "Cacao")]),
                 Target(
                    name: "CacaoTests",
                    dependencies: [.Target(name: "Cacao")]),
                 Target(
                    name: "Cacao")
    ],
    dependencies: [
        .Package(url: "https://github.com/PureSwift/Silica.git", majorVersion: 1),
        .Package(url: "https://github.com/PureSwift/CSDL2.git", majorVersion: 1)
    ],
    exclude: ["Xcode"]
)
