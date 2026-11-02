// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "farol-voice",
    // speech-swift needs macOS 15.
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/soniqo/speech-swift", exact: "0.0.29"),
        // For Parakeet V2, the English-only model, which speech-swift doesn't offer.
        .package(url: "https://github.com/FluidInference/FluidAudio", exact: "0.18.2"),
        // Runs the wake word's models.
        .package(url: "https://github.com/microsoft/onnxruntime-swift-package-manager", exact: "1.24.2"),
        // Exact, since scripts/appcast.sh downloads the signing tools of this same version.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        // What can be wrong without a microphone: models, text clean-up. No audio, and tested.
        .target(name: "VoiceCore"),
        .target(name: "VoiceEngine", dependencies: [
            "VoiceCore",
            .product(name: "ParakeetASR", package: "speech-swift"),
            .product(name: "WhisperASR", package: "speech-swift"),
            .product(name: "FluidAudio", package: "FluidAudio"),
            .product(name: "onnxruntime", package: "onnxruntime-swift-package-manager"),
        ]),
        // The menu bar app.
        .executableTarget(name: "FarolVoice", dependencies: ["VoiceCore", "VoiceEngine", .product(name: "Sparkle", package: "Sparkle")], linkerSettings: [.linkedFramework("Carbon")]),
        // For measuring models from the terminal.
        .executableTarget(name: "farol-voice", dependencies: ["VoiceCore", "VoiceEngine"]),
        .testTarget(name: "VoiceCoreTests", dependencies: ["VoiceCore"]),
    ],
    swiftLanguageModes: [.v5]
)
