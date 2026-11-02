import Foundation
import OnnxRuntimeBindings

/// Listens for one phrase with openWakeWord's three small models: audio to a spectrogram, that to speech embeddings, and those to a score.
/// Not thread safe. Feed it from one queue.
public final class WakeDetector {
    /// Each step is 80 ms of audio, plus the little the spectrogram needs from before it.
    private static let stepSamples = 1280
    private static let contextSamples = 480
    private static let melWindow = 76
    private static let melBins = 32
    private static let embeddingSize = 96
    private static let embeddingWindow = 16

    private let env: ORTEnv
    private let spectrogram: ORTSession
    private let embedding: ORTSession
    private let classifier: ORTSession
    private var raw = [Float](repeating: 0, count: contextSamples)
    private var pending = 0
    private var mel: [[Float]] = []
    private var embeddings: [[Float]] = []

    public init(folder: URL, modelName: String) throws {
        let env = try ORTEnv(loggingLevel: .error)
        self.env = env
        let options = try ORTSessionOptions()
        // Most of the day this runs for nothing, so it shouldn't take more than a core for a moment.
        try options.setIntraOpNumThreads(1)
        let path = { (name: String) in folder.appendingPathComponent("\(name).onnx").path }
        spectrogram = try ORTSession(env: env, modelPath: path("melspectrogram"), sessionOptions: options)
        embedding = try ORTSession(env: env, modelPath: path("embedding_model"), sessionOptions: options)
        classifier = try ORTSession(env: env, modelPath: path(modelName), sessionOptions: options)
    }

    /// Samples from -1 to 1 at 16 kHz. Returns the score of each step that finished, from 0 to 1.
    public func feed(_ samples: [Float]) throws -> [Double] {
        var scores: [Double] = []
        // It was trained on 16-bit audio, so that's the scale it expects.
        raw += samples.map { $0 * 32767 }
        pending += samples.count
        while pending >= Self.stepSamples {
            let end = raw.count - (pending - Self.stepSamples)
            let window = Array(raw[(end - Self.stepSamples - Self.contextSamples)..<end])
            pending -= Self.stepSamples
            if let score = try step(window) { scores.append(score) }
        }
        raw.removeFirst(max(0, raw.count - pending - Self.contextSamples))
        return scores
    }

    private func step(_ audio: [Float]) throws -> Double? {
        let frames = try run(spectrogram, audio, shape: [1, audio.count])
        for start in stride(from: 0, to: frames.count, by: Self.melBins) {
            mel.append(frames[start..<(start + Self.melBins)].map { $0 / 10 + 2 })
        }
        guard mel.count >= Self.melWindow else { return nil }
        mel.removeFirst(mel.count - Self.melWindow)
        embeddings.append(try run(embedding, mel.flatMap { $0 }, shape: [1, Self.melWindow, Self.melBins, 1]))
        guard embeddings.count >= Self.embeddingWindow else { return nil }
        embeddings.removeFirst(embeddings.count - Self.embeddingWindow)
        let score = try run(classifier, embeddings.flatMap { $0 }, shape: [1, Self.embeddingWindow, Self.embeddingSize])
        return score.first.map(Double.init)
    }

    private func run(_ session: ORTSession, _ input: [Float], shape: [Int]) throws -> [Float] {
        let data = input.withUnsafeBytes { NSMutableData(bytes: $0.baseAddress, length: $0.count) }
        let value = try ORTValue(tensorData: data, elementType: .float, shape: shape.map { NSNumber(value: $0) })
        guard let inputName = try session.inputNames().first, let outputName = try session.outputNames().first else { return [] }
        let outputs = try session.run(withInputs: [inputName: value], outputNames: [outputName], runOptions: nil)
        guard let tensor = try outputs[outputName]?.tensorData() else { return [] }
        return (tensor as Data).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}
