// swift-tools-version:3.0.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cacao",
    targets: [
                 Target(
                    name: "CacaoDemo",
                    dependencies: [.Target(name: "Cacao")]),
                 Target(
                    name: "Cacao"
					)
    ],
    dependencies: [
        .Package(url: "https://github.com/PureSwift/Silica.git", majorVersion: 1),
		.Package(url: "https://github.com/PureSwift/Cairo.git", majorVersion: 1),
		.Package(url: "https://github.com/PureSwift/SDL.git", majorVersion: 1),
        .Package(url: "https://github.com/PureSwift/CSDL2.git", majorVersion: 1)
    ],
    exclude: ["iOS", "Resources"]
)
