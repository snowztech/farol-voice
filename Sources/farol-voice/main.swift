import AVFoundation
import Foundation
import SpeechWakeWord
import WakeWord

let sampleRate = 16000.0
let chunkFrames: AVAudioFrameCount = 1600

let usage = """
usage:
  farol-voice listen [--threshold 0.05] [--boost 1]
  farol-voice score <corpus> [--threshold 0.05] [--boost 1]

A corpus has positive/ and negative/ folders of 16 kHz mono WAV files.
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func option(_ name: String, default fallback: Double, in arguments: [String]) -> Double {
    guard let index = arguments.firstIndex(of: name) else { return fallback }
    guard index + 1 < arguments.count, let value = Double(arguments[index + 1]) else {
        fail("\(name) needs a number")
    }
    return value
}

/// CoreML's temporary buffers are autoreleased. A long-running loop never drains them by itself and crashes out of IOSurface memory.
func push(_ samples: [Float], to session: WakeWordSession) throws -> [KeywordDetection] {
    try autoreleasepool { try session.pushAudio(samples) }
}

func loadDetector(_ arguments: [String]) async throws -> WakeWordDetector {
    try await WakeWordDetector.fromPretrained(keywords: HeyFarol.keywords(
        threshold: option("--threshold", default: 0.05, in: arguments),
        boost: option("--boost", default: 1, in: arguments)
    ))
}

/// Mic audio as 16 kHz mono. The model runs outside the tap, because blocking a real-time audio thread drops audio.
func microphone() throws -> AsyncStream<[Float]> {
    let engine = AVAudioEngine()
    let input = engine.inputNode.outputFormat(forBus: 0)
    guard input.sampleRate > 0 else { fail("No microphone available, or macOS denied access to it.") }
    guard let output = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
          let converter = AVAudioConverter(from: input, to: output) else { fail("Can't convert the microphone's format.") }

    let (stream, continuation) = AsyncStream.makeStream(of: [Float].self, bufferingPolicy: .bufferingNewest(100))
    engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: input) { buffer, _ in
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * sampleRate / input.sampleRate) + 1
        guard let converted = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else { return }
        var delivered = false
        converter.convert(to: converted, error: nil) { _, status in
            if delivered {
                status.pointee = .noDataNow
                return nil
            }
            delivered = true
            status.pointee = .haveData
            return buffer
        }
        guard let samples = converted.floatChannelData?[0], converted.frameLength > 0 else { return }
        continuation.yield(Array(UnsafeBufferPointer(start: samples, count: Int(converted.frameLength))))
    }
    continuation.onTermination = { _ in engine.stop() }
    try engine.start()
    return stream
}

func listen(_ arguments: [String]) async throws {
    if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
        print("Waiting for microphone permission. Check for a macOS prompt.")
    }
    guard await AVCaptureDevice.requestAccess(for: .audio) else {
        fail("Microphone access is off. Allow your terminal in System Settings, Privacy & Security, Microphone.")
    }
    let detector = try await loadDetector(arguments)
    let session = try detector.createSession()
    var gate = WakeGate()
    var pushed = 0.0
    let stream = try microphone()
    print("Listening. Say \"\(HeyFarol.phrase)\". Ctrl-C stops.")
    for await chunk in stream {
        pushed += Double(chunk.count) / sampleRate
        for _ in try push(chunk, to: session) where gate.accept(at: pushed) {
            print("\(ISO8601DateFormatter().string(from: Date())) wake")
        }
    }
}

/// Counts wakes through the same streaming path the mic uses, reading in chunks so a whole day of audio fits in memory.
func wakes(in file: URL, session: WakeWordSession) throws -> (count: Int, seconds: Double) {
    let audio = try AVAudioFile(forReading: file)
    let format = audio.processingFormat
    guard format.sampleRate == sampleRate, format.channelCount == 1 else {
        fail("\(file.lastPathComponent) isn't 16 kHz mono. Convert it with: ffmpeg -i in -ar 16000 -ac 1 out.wav")
    }
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else { fail("Can't allocate audio buffer.") }
    try session.reset()
    var gate = WakeGate()
    var count = 0
    var seconds = 0.0
    func tally(_ detections: [KeywordDetection]) {
        for _ in detections where gate.accept(at: seconds) { count += 1 }
    }
    while audio.framePosition < audio.length {
        try audio.read(into: buffer, frameCount: chunkFrames)
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { break }
        seconds += Double(buffer.frameLength) / sampleRate
        tally(try push(Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength))), to: session))
    }
    tally(try session.finalize())
    return (count, seconds)
}

func wavFiles(in folder: URL) -> [URL] {
    let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    return files.filter { $0.pathExtension.lowercased() == "wav" }.sorted { $0.path < $1.path }
}

func score(_ arguments: [String]) async throws {
    guard let path = arguments.first, !path.hasPrefix("--") else { fail(usage) }
    let corpus = URL(fileURLWithPath: path)
    let positives = wavFiles(in: corpus.appendingPathComponent("positive"))
    let negatives = wavFiles(in: corpus.appendingPathComponent("negative"))
    guard !positives.isEmpty || !negatives.isEmpty else { fail("No WAV files in \(path)/positive or \(path)/negative.") }

    let detector = try await loadDetector(arguments)
    let session = try detector.createSession()
    var score = Score()
    var audioSeconds = 0.0
    let started = Date()
    for file in positives {
        let result = try wakes(in: file, session: session)
        score.attempts += 1
        audioSeconds += result.seconds
        if result.count > 0 { score.caught += 1 } else { print("missed  \(file.lastPathComponent)") }
    }
    for file in negatives {
        let result = try wakes(in: file, session: session)
        score.falseWakes += result.count
        score.negativeSeconds += result.seconds
        audioSeconds += result.seconds
        if result.count > 0 { print("false   \(file.lastPathComponent): \(result.count)") }
    }
    let elapsed = Date().timeIntervalSince(started)

    print(String(format: "caught       %d/%d (%.1f%%, need %.0f%%)", score.caught, score.attempts, score.recall * 100, Score.requiredRecall * 100))
    print(String(format: "false wakes  %d in %.2f h (%.1f per workday, allow %.0f)", score.falseWakes, score.negativeSeconds / 3600, score.falseWakesPerWorkday, Score.allowedFalseWakesPerWorkday))
    print(String(format: "speed        %.0fx real time", audioSeconds / max(elapsed, 0.001)))
    if !score.hasEnoughAudio {
        print("verdict      not enough audio (need \(Score.minimumAttempts) attempts and 8 h of negatives)")
    } else {
        print("verdict      \(score.passes ? "pass" : "fail")")
    }
}

// Keeps wakes appearing live when the output is piped to a log.
setvbuf(stdout, nil, _IOLBF, 0)

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    switch arguments.first {
    case "listen": try await listen(Array(arguments.dropFirst()))
    case "score": try await score(Array(arguments.dropFirst()))
    default: fail(usage)
    }
} catch {
    fail("\(error)")
}
