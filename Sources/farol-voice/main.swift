import AVFoundation
import Foundation
import VoiceCore
import VoiceEngine

let usage = """
usage: farol-voice transcribe <file.wav>... [--model parakeet-v3|whisper-turbo] [--words "Farol, snowztech"]
       farol-voice understand <socket> <what you'd say>

Files are 16 kHz mono WAV. Use this to compare models on the same recordings.
understand shows how a sentence is read against Farol's real sessions, without doing anything.
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func readSamples(_ path: String) throws -> [Float] {
    let audio = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    guard audio.processingFormat.sampleRate == 16000, audio.processingFormat.channelCount == 1,
          let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: AVAudioFrameCount(audio.length)) else {
        fail("\(path) isn't 16 kHz mono. Convert it with: ffmpeg -i in -ar 16000 -ac 1 out.wav")
    }
    try audio.read(into: buffer)
    return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
}

func transcribe(_ arguments: [String]) async throws {
    var files: [String] = []
    var model = VoiceModel.parakeetV3
    var words: [String] = []
    var index = 0
    while index < arguments.count {
        switch arguments[index] {
        case "--model":
            guard index + 1 < arguments.count, let chosen = VoiceModel(rawValue: arguments[index + 1]) else { fail(usage) }
            model = chosen
            index += 1
        case "--words":
            guard index + 1 < arguments.count else { fail(usage) }
            words = DictationText.words(from: arguments[index + 1])
            index += 1
        default:
            files.append(arguments[index])
        }
        index += 1
    }
    guard !files.isEmpty else { fail(usage) }
    let engine = SpeechEngine(folder: SpeechEngine.defaultFolder)
    let loading = Date()
    try await engine.load(model, online: !engine.isInstalled(model)) { _, _ in }
    print(String(format: "loaded in %.0f ms", Date().timeIntervalSince(loading) * 1000))
    for file in files {
        let samples = try readSamples(file)
        let started = Date()
        let text = try await engine.transcribe(samples)
        print(String(format: "%5.0f ms  ", Date().timeIntervalSince(started) * 1000) + DictationText.clean(text, customWords: words))
    }
}

func understand(_ arguments: [String]) throws {
    guard arguments.count >= 2 else { fail(usage) }
    let sessions = try FarolSocket.send(.sessions, to: arguments[0]).sessions ?? []
    print(VoiceCommand.parse(arguments.dropFirst().joined(separator: " "), sessions: sessions.map(\.target)))
}

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    switch arguments.first {
    case "transcribe": try await transcribe(Array(arguments.dropFirst()))
    case "understand": try understand(Array(arguments.dropFirst()))
    default: fail(usage)
    }
} catch {
    fail("\(error)")
}
