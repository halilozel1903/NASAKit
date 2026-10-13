// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NASAKit",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        // macOS so `swift test` runs on CI and the client works in Mac apps and tools.
        .macOS(.v14),
    ],
    products: [
        .library(name: "NASAKit", targets: ["NASAKit"]),
    ],
    targets: [
        .target(name: "NASAKit"),
        .testTarget(
            name: "NASAKitTests",
            dependencies: ["NASAKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
