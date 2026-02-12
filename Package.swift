// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OCRS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OCRS", targets: ["OCRS"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.3")
    ],
    targets: [
        .executableTarget(
            name: "OCRS",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/OCRS"
        )
    ]
)
