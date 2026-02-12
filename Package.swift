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
    targets: [
        .executableTarget(
            name: "OCRS",
            path: "Sources/OCRS"
        )
    ]
)
