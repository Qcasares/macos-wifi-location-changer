// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "LocationChanger",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LocationChangerCore",
            targets: ["LocationChangerCore"]
        ),
        .executable(
            name: "locationchanger",
            targets: ["locationchanger"]
        ),
        .executable(
            name: "LocationChangerApp",
            targets: ["LocationChangerApp"]
        ),
        .executable(
            name: "LocationChangerTests",
            targets: ["LocationChangerTests"]
        ),
    ],
    targets: [
        .target(
            name: "LocationChangerCore",
            path: "Sources/LocationChangerCore"
        ),
        .executableTarget(
            name: "locationchanger",
            dependencies: ["LocationChangerCore"],
            path: "Sources/locationchanger"
        ),
        .executableTarget(
            name: "LocationChangerApp",
            dependencies: ["LocationChangerCore"],
            path: "Sources/LocationChangerApp",
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "LocationChangerTests",
            dependencies: ["LocationChangerCore"],
            path: "Sources/LocationChangerTests"
        ),
    ]
)
