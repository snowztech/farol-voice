import AppKit
import AVFoundation
import VoiceCore
import VoiceEngine

/// Keeps the mic open for "OK Farol", then hears what you say after it. Only the audio around a wake goes further than the detector, and none of it is saved.
@MainActor
final class WakeListener {
    private static let modelName = "ok_farol"
    private static let wakeWindow = 16000 * 2
    /// Each wake holds the speech model for a moment, and one saying of it fires over several steps.
    private static let cooldown: TimeInterval = 2
    private static let longestCommand = 16000 * 15

    nonisolated static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Farol Voice/wake")
    }

    nonisolated static var isInstalled: Bool {
        ["melspectrogram", "embedding_model", modelName].allSatisfy {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent("\($0).onnx").path)
        }
    }

    private enum State {
        case off
        case waiting
        /// Heard it, and hearing what comes next while the speech model checks it.
        case hearing
        case understanding
    }

    private let library: ModelLibrary
    private let pill: Pill
    private let commander: Commander
    private let work = DispatchQueue(label: "dev.farol.voice.wake", qos: .userInitiated)
    /// Touched only on `work`.
    private nonisolated(unsafe) var detector: WakeDetector?
    private nonisolated(unsafe) var recent: [Float] = []
    private var mic: Microphone?
    private var state = State.off
    private var wanted = false
    private var paused = 0
    private var lastWake = Date.distantPast
    private var command: [Float] = []
    private var endpoint: SpeechEndpoint?
    private var confirmed = false

    init(library: ModelLibrary, pill: Pill, commander: Commander) {
        self.library = library
        self.pill = pill
        self.commander = commander
    }

    func setEnabled(_ on: Bool) {
        wanted = on
        update()
    }

    /// While you're dictating or Farol is talking, it isn't listening for this. The second is what keeps it from waking itself.
    func pause() {
        paused += 1
        update()
    }

    func resume() {
        paused = max(0, paused - 1)
        update()
    }

    private func update() {
        let should = wanted && paused == 0 && Self.isInstalled && library.isReady && Permissions.microphone == .authorized
        if should, mic == nil { start() } else if !should, mic != nil { stop() }
    }

    private func start() {
        let mic = Microphone()
        do {
            let folder = Self.folder
            let name = Self.modelName
            try work.sync { if detector == nil { detector = try WakeDetector(folder: folder, modelName: name) } }
            try mic.start { [weak self] samples in self?.heard(samples) }
        } catch {
            pill.flash("Couldn't listen for OK Farol: \(error.localizedDescription)")
            return
        }
        self.mic = mic
        state = .waiting
    }

    private func stop() {
        mic?.stop()
        mic = nil
        command = []
        endpoint = nil
        if state == .hearing { pill.hide() }
        state = .off
    }

    /// On the audio thread, which must never wait on a model.
    private nonisolated func heard(_ samples: [Float]) {
        work.async { [weak self] in
            guard let self else { return }
            recent = Array((recent + samples).suffix(Self.wakeWindow))
            let scores = (try? detector?.feed(samples)) ?? []
            let top = scores.max() ?? 0
            let window = recent
            let level = Recording.loudness(samples)
            DispatchQueue.main.async { MainActor.assumeIsolated { self.receive(samples, level: level, score: top, window: window) } }
        }
    }

    private func receive(_ samples: [Float], level: Double, score: Double, window: [Float]) {
        switch state {
        case .waiting:
            guard score >= threshold, Date().timeIntervalSince(lastWake) > Self.cooldown else { return }
            lastWake = Date()
            woke(window, score: score)
        case .hearing:
            command += samples
            pill.level = level
            guard var endpoint else { return }
            let now = endpoint.hear(level: level, at: ProcessInfo.processInfo.systemUptime)
            self.endpoint = endpoint
            if now == .nothing || now == .finished || command.count >= Self.longestCommand { finish(heardNothing: now == .nothing) }
        case .off, .understanding:
            break
        }
    }

    private var threshold: Double {
        let saved = UserDefaults.standard.double(forKey: "wakeThreshold")
        return saved > 0 ? saved : 0.1
    }

    private func woke(_ window: [Float], score: Double) {
        state = .hearing
        command = []
        confirmed = false
        endpoint = SpeechEndpoint(startingAt: ProcessInfo.processInfo.systemUptime, patience: 4)
        Task { [weak self] in
            guard let self else { return }
            let heard = await transcribe(window) ?? ""
            let passed = WakeCheck.confirms(heard)
            Self.log(score: score, heard: heard, passed: passed)
            guard state == .hearing else { return }
            guard passed else {
                state = .waiting
                command = []
                endpoint = nil
                return
            }
            confirmed = true
            // Quiet, so it isn't taken for the room's noise level by what decides you've finished talking.
            let sound = NSSound(named: "Tink")
            sound?.volume = 0.2
            sound?.play()
            pill.showListening(command: true)
        }
    }

    private func finish(heardNothing: Bool) {
        let samples = command
        command = []
        endpoint = nil
        state = .understanding
        guard confirmed else {
            state = .waiting
            return
        }
        guard !heardNothing else {
            pill.hide()
            state = .waiting
            return
        }
        pill.showWorking()
        Task { [weak self] in
            guard let self else { return }
            let text = await transcribe(samples) ?? ""
            pill.hide()
            if mic != nil { state = .waiting } else { state = .off }
            await commander.run(text)
        }
    }

    private func transcribe(_ samples: [Float]) async -> String? {
        let model = library.chosen
        do {
            try await library.engine.load(model, online: false) { _, _ in }
            return try await library.engine.transcribe(samples)
        } catch {
            return nil
        }
    }

    /// For the workday test in a dev build: how often it fired, and what the check made of it. Words are kept here only, on this Mac.
    private static func log(score: Double, heard: String, passed: Bool) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(String(format: "%.3f", score)) \(passed ? "woke" : "rejected") \(heard)\n"
        let file = folder.appendingPathComponent("wakes.log")
        if let handle = try? FileHandle(forWritingTo: file) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: file)
        }
    }
}
