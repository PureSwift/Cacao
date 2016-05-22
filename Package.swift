import PackageDescription

let package = Package(
    name: "Cacao",
    dependencies: [
        .Package(url: "https://github.com/PureSwift/Silica.git", majorVersion: 1),
        .Package(url: "https://github.com/PureSwift/CSDL2.git", majorVersion: 1)
    ],
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
    exclude: ["Xcode"]
)