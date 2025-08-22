// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleASTM",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SimpleASTM",
            targets: ["SimpleASTM"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "SimpleASTM",
            dependencies: [],
            path: "Sources/SimpleASTM"
        ),
        .testTarget(
            name: "SimpleASTMTests",
            dependencies: ["SimpleASTM"],
            path: "Tests/SimpleASTMTests"
        ),
    ]
)