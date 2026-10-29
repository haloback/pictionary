// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Colophon",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Colophon", targets: ["Colophon"])
    ],
    targets: [
        .executableTarget(
            name: "Colophon",
            path: "Sources/Colophon"
        ),
        .testTarget(
            name: "ColophonTests",
            dependencies: ["Colophon"],
            path: "Tests/ColophonTests"
        )
    ]
)
