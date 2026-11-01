// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "farol-voice",
    // speech-swift needs macOS 15.
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/soniqo/speech-swift", exact: "0.0.29"),
    ],
    targets: [
        // What can be wrong without a microphone: models, text clean-up. No audio, and tested.
        .target(name: "VoiceCore"),
        .target(name: "VoiceEngine", dependencies: [
            "VoiceCore",
            .product(name: "ParakeetASR", package: "speech-swift"),
            .product(name: "WhisperASR", package: "speech-swift"),
        ]),
        // The menu bar app.
        .executableTarget(name: "FarolVoice", dependencies: ["VoiceCore", "VoiceEngine"], linkerSettings: [.linkedFramework("Carbon")]),
        // For measuring models from the terminal.
        .executableTarget(name: "farol-voice", dependencies: ["VoiceCore", "VoiceEngine"]),
        .testTarget(name: "VoiceCoreTests", dependencies: ["VoiceCore"]),
    ],
    swiftLanguageModes: [.v5]
)
