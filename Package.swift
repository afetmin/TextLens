// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TextLens",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "TextLensCore",
            targets: ["TextLensCore"]
        ),
        .executable(
            name: "TextLens",
            targets: ["TextLensApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/jaywcjlove/PermissionFlow.git", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "TextLensCore"
        ),
        .executableTarget(
            name: "TextLensApp",
            dependencies: [
                "TextLensCore",
                .product(name: "PermissionFlow", package: "PermissionFlow")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Translation")
            ]
        ),
        .testTarget(
            name: "TextLensCoreTests",
            dependencies: ["TextLensCore"]
        )
    ]
)
