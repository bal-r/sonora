// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Sonora",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Sonora", targets: ["Sonora"])
    ],
    dependencies: [
        // Apache-2.0 speech stack. `traits: []` builds ASR + VAD only:
        // no TTS, no diarizer, no NeMo text engine. Smaller binary,
        // faster launch, less memory.
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            from: "0.17.7",
            traits: []
        )
    ],
    targets: [
        .executableTarget(
            name: "Sonora",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            path: "Sources/Sonora",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "SonoraTests",
            dependencies: ["Sonora"],
            path: "Tests/SonoraTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
