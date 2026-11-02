import FluidAudio
import Foundation
import ParakeetASR
import VoiceCore
import WhisperASR

/// Installs models and runs them, one at a time and in order, so the app's main thread never waits on speech.
public actor SpeechEngine {
    public static let defaultFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Farol Voice/models")

    private enum Loaded {
        case parakeet(ParakeetASRModel)
        case whisper(WhisperASRModel)
        case english(AsrManager)
    }

    private let folder: URL
    private var loaded: (model: VoiceModel, engine: Loaded)?

    public init(folder: URL) {
        self.folder = folder
    }

    public nonisolated func directory(of model: VoiceModel) -> URL {
        folder.appendingPathComponent(model.rawValue)
    }

    /// Written once a model has fully loaded, so a download that stopped halfway doesn't count as installed.
    private nonisolated func marker(of model: VoiceModel) -> URL {
        directory(of: model).appendingPathComponent(".installed")
    }

    public nonisolated func isInstalled(_ model: VoiceModel) -> Bool {
        FileManager.default.fileExists(atPath: marker(of: model).path)
    }

    /// `online` is only for installing. Once installed, a model loads with no network at all.
    public func load(_ model: VoiceModel, online: Bool, progress: @escaping (Double, String) -> Void) async throws {
        if loaded?.model == model { return }
        loaded = nil
        let directory = directory(of: model)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        switch model {
        case .parakeetV3:
            let engine = try await ParakeetASRModel.fromPretrained(cacheDir: directory, offlineMode: !online, progressHandler: progress)
            loaded = (model, .parakeet(engine))
        case .parakeetV2:
            let manager = AsrManager(config: .default)
            // FluidAudio puts the files in a folder of its own next to the path it's given.
            let models = online
                ? try await AsrModels.downloadAndLoad(to: directory.appendingPathComponent("models"), version: .v2) { update in
                    progress(update.fractionCompleted, "Downloading")
                }
                : try await AsrModels.loadLocal(from: directory.appendingPathComponent("parakeet-tdt-0.6b-v2"), version: .v2)
            try await manager.loadModels(models)
            loaded = (model, .english(manager))
        case .whisperTurbo:
            let engine = try await WhisperASRModel.fromPretrained(cacheDir: directory, offlineMode: !online, progressHandler: progress)
            loaded = (model, .whisper(engine))
        }
        if online { FileManager.default.createFile(atPath: marker(of: model).path, contents: nil) }
    }

    /// `language` holds the model to one language, for a model that can be.
    public func transcribe(_ samples: [Float], language: String? = nil) async throws -> String {
        switch loaded?.engine {
        case .parakeet(let engine):
            return try autoreleasepool { try engine.transcribeAudio(samples, sampleRate: 16000) }
        case .whisper(let engine):
            return try await engine.transcribeAudio(samples, sampleRate: 16000, language: language)
        case .english(let manager):
            // It refuses under a second of audio, and "yes" is shorter than that.
            let padded = samples + [Float](repeating: 0, count: max(0, 16000 - samples.count))
            var state = try TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
            return try await manager.transcribe(padded, decoderState: &state).text
        case nil:
            throw CocoaError(.featureUnsupported)
        }
    }

    /// Frees the model's memory between uses.
    public func unload() {
        loaded = nil
    }

    public func delete(_ model: VoiceModel) throws {
        if loaded?.model == model { loaded = nil }
        try FileManager.default.removeItem(at: directory(of: model))
    }
}
