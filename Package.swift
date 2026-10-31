// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "farol-voice",
    // speech-swift needs macOS 15. Farol itself stays on 14, since voice is a separate install.
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/soniqo/speech-swift", exact: "0.0.29"),
    ],
    targets: [
        .target(name: "WakeWord", dependencies: [.product(name: "SpeechWakeWord", package: "speech-swift")]),
        .executableTarget(name: "farol-voice", dependencies: [
            "WakeWord",
            .product(name: "SpeechWakeWord", package: "speech-swift"),
            .product(name: "ParakeetASR", package: "speech-swift"),
            .product(name: "WhisperASR", package: "speech-swift"),
        ]),
        .testTarget(name: "WakeWordTests", dependencies: ["WakeWord"]),
    ],
    swiftLanguageModes: [.v5]
)
