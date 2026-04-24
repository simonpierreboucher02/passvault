// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PassVault",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PassVault", targets: ["PassVault"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PassVault",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PassVaultTests",
            dependencies: ["PassVault"],
            path: "Tests/PassVaultTests"
        )
    ]
)
