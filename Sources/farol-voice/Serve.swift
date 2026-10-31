import AVFoundation
import Foundation
import ParakeetASR
import WhisperASR

// Farol talks to this process in lines of JSON over stdin and stdout.
// It sends start, stop and cancel. Closing stdin ends this process, so it can't outlive Farol.

private let protocolVersion = 1
private let minimumSamples = 16000 / 4
private let outputLock = NSLock()

private func emit(_ fields: [String: Any]) {
    guard let line = try? JSONSerialization.data(withJSONObject: fields) else { return }
    outputLock.lock()
    defer { outputLock.unlock() }
    FileHandle.standardOutput.write(line + Data("\n".utf8))
}

private enum Transcriber {
    case parakeet(ParakeetASRModel)
    case whisper(WhisperASRModel)

    static func load(_ name: String, into folder: URL) async throws -> Transcriber {
        let directory = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Downloads report far more often than a progress line can change.
        var lastPercent = -1
        let progress: (Double, String) -> Void = { fraction, status in
            let percent = Int(fraction * 100)
            guard percent != lastPercent else { return }
            lastPercent = percent
            emit(["type": "loading", "progress": fraction, "status": status])
        }
        switch name {
        case "parakeet-v3":
            return .parakeet(try await ParakeetASRModel.fromPretrained(cacheDir: directory, progressHandler: progress))
        case "whisper-turbo":
            return .whisper(try await WhisperASRModel.fromPretrained(cacheDir: directory, progressHandler: progress))
        default:
            fail("Unknown model \(name).")
        }
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        switch self {
        case .parakeet(let model):
            return try autoreleasepool { try model.transcribeAudio(samples, sampleRate: 16000) }
        case .whisper(let model):
            return try await model.transcribeAudio(samples, sampleRate: 16000)
        }
    }
}

/// Audio arrives on the audio thread and is read on the command loop.
private final class Recording {
    private let lock = NSLock()
    private var samples: [Float] = []
    let mic = Microphone()

    func append(_ more: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        samples += more
    }

    func finish() -> [Float] {
        mic.stop()
        lock.lock()
        defer { lock.unlock() }
        return samples
    }
}

private func stringOption(_ name: String, in arguments: [String]) -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { fail(usage) }
    return arguments[index + 1]
}

/// The mic can open while the model is still loading, so a first press doesn't lose your words.
private func startRecording() -> Recording? {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
        let recording = Recording()
        do {
            try recording.mic.start { recording.append($0) }
            return recording
        } catch {
            emit(["type": "error", "message": error.localizedDescription])
            return nil
        }
    case .notDetermined:
        // Asking takes as long as the person does, so this press only asks. They hold the key again after allowing it.
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted { emit(["type": "error", "message": "Farol isn't allowed to use the microphone."]) }
        }
        return nil
    default:
        emit(["type": "error", "message": "Farol isn't allowed to use the microphone. Change it in System Settings, Privacy & Security, Microphone."])
        return nil
    }
}

func serve(_ arguments: [String]) async throws {
    let name = stringOption("--model", in: arguments)
    let folder = URL(fileURLWithPath: stringOption("--models", in: arguments))
    let model = Task { () -> Transcriber in
        do {
            let loaded = try await Transcriber.load(name, into: folder)
            emit(["type": "ready", "protocol": protocolVersion])
            return loaded
        } catch {
            emit(["type": "error", "message": "Couldn't load the model: \(error.localizedDescription)"])
            exit(1)
        }
    }

    var recording: Recording?
    var lastTranscription: Task<Void, Never>?
    for try await line in FileHandle.standardInput.bytes.lines {
        guard let data = line.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = message["type"] as? String else { continue }
        switch type {
        case "start":
            _ = recording?.finish()
            recording = startRecording()
        case "cancel":
            _ = recording?.finish()
            recording = nil
        case "stop":
            let samples = recording?.finish() ?? []
            recording = nil
            let previous = lastTranscription
            // One at a time and in order, so text lands in the session each press was aimed at.
            lastTranscription = Task {
                await previous?.value
                guard samples.count >= minimumSamples else {
                    emit(["type": "text", "text": ""])
                    return
                }
                do {
                    emit(["type": "text", "text": try await model.value.transcribe(samples)])
                } catch {
                    emit(["type": "error", "message": "Couldn't transcribe that: \(error.localizedDescription)"])
                    emit(["type": "text", "text": ""])
                }
            }
        default:
            break
        }
    }
    exit(0)
}
