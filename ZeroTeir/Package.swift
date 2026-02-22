// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ZeroTeir",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ZeroTeir",
            targets: ["ZeroTeir"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ZeroTeir",
            path: "Sources/ZeroTeir",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
