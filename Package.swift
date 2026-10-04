// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tidy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Tidy", targets: ["Tidy"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Tidy",
            dependencies: [],
            path: "Sources/Tidy"
        )
    ]
)
