// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VJApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "VJApp", targets: ["VJApp"])
    ],
    targets: [
        .executableTarget(
            name: "VJApp",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "VJAppTests",
            dependencies: ["VJApp"]
        )
    ]
)
