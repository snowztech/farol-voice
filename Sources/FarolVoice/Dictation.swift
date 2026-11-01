import AppKit
import AVFoundation
import VoiceCore
import VoiceEngine

/// Hold the key, talk, let go, and the words appear wherever you were typing.
final class Dictation {
    /// Long enough that Right Option held for a typed accent never opens the mic.
    private static let holdDelay: TimeInterval = 0.15
    private static let shortestSpeech = 16000 / 4
    /// If the key's release is ever missed, the mic can't stay open forever.
    private static let longestHold: TimeInterval = 5 * 60
    /// Reloading takes about 0.2 seconds, so memory can be given back soon after you stop talking.
    private static let idleUnload: TimeInterval = 5 * 60

    /// The last words, in memory only, for when they couldn't be typed.
    private(set) var lastTranscript: String?
    var onListeningChange: ((Bool) -> Void)?

    private let library: ModelLibrary
    private let preferences: Preferences
    private let openSettings: () -> Void
    private let pill = Pill()
    private var monitors: [Any] = []
    private var heldKey = false
    private var pendingStart: DispatchWorkItem?
    private var recording: Recording?
    private var targetApp: pid_t?
    private var limit: DispatchWorkItem?
    private var idle: DispatchWorkItem?
    private var working = 0

    init(library: ModelLibrary, preferences: Preferences, openSettings: @escaping () -> Void) {
        self.library = library
        self.preferences = preferences
        self.openSettings = openSettings
    }

    func begin() {
        installMonitors()
        preload()
        guard !Permissions.accessibility else { return }
        // A global monitor set up before Accessibility was allowed may never receive anything, so it's set up again once it is.
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard Permissions.accessibility else { return }
            timer.invalidate()
            self?.installMonitors()
        }
    }

    /// Global events cover other apps. Local ones cover this app's own windows.
    private func installMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: { [weak self] in self?.handle($0) }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    /// The first load after installing compiles the model and takes seconds, so it happens ahead of the first press.
    private func preload() {
        guard library.isReady else { return }
        let model = library.chosen
        Task { [engine = library.engine] in try? await engine.load(model, online: false) { _, _ in } }
        scheduleUnload()
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown {
            // A key while this one is held is a shortcut or a typed character, not someone talking.
            if heldKey { cancel() }
            return
        }
        let key = preferences.talkKey
        guard event.keyCode == key.keyCode else { return }
        let down = event.modifierFlags.contains(key.flag)
        guard down != heldKey else { return }
        heldKey = down
        if down {
            let start = DispatchWorkItem { [weak self] in self?.start() }
            pendingStart = start
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdDelay, execute: start)
        } else {
            stop()
        }
    }

    private func start() {
        pendingStart = nil
        guard library.isReady else {
            pill.flash("Install a model first")
            openSettings()
            return
        }
        switch Permissions.microphone {
        case .authorized:
            break
        case .notDetermined:
            // Asking takes as long as you do, so this press only asks.
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
            return
        default:
            pill.flash("Allow the microphone in Settings")
            openSettings()
            return
        }
        let pill = pill
        let recording = Recording { level in DispatchQueue.main.async { pill.level = level } }
        do {
            try recording.start()
        } catch {
            pill.flash(error.localizedDescription)
            return
        }
        self.recording = recording
        targetApp = NSWorkspace.shared.frontmostApplication?.processIdentifier
        idle?.cancel()
        let later = DispatchWorkItem { [weak self] in
            self?.heldKey = false
            self?.stop()
        }
        limit = later
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.longestHold, execute: later)
        pill.showListening()
        onListeningChange?(true)
    }

    private func stop() {
        pendingStart?.cancel()
        pendingStart = nil
        limit?.cancel()
        guard let recording else { return }
        self.recording = nil
        let samples = recording.finish()
        onListeningChange?(false)
        guard samples.count >= Self.shortestSpeech else {
            finish()
            return
        }
        working += 1
        pill.showWorking()
        let model = library.chosen
        let app = targetApp
        Task { [engine = library.engine, weak self] in
            do {
                // Usually loaded already, unless it was unloaded after a long break.
                try await engine.load(model, online: false) { _, _ in }
                let text = try await engine.transcribe(samples)
                await MainActor.run { self?.deliver(text, to: app) }
            } catch {
                await MainActor.run { self?.failed(error) }
            }
        }
    }

    /// Drops what was said so far. Nothing is typed.
    private func cancel() {
        heldKey = false
        pendingStart?.cancel()
        pendingStart = nil
        limit?.cancel()
        guard let recording else { return }
        self.recording = nil
        _ = recording.finish()
        onListeningChange?(false)
        finish()
    }

    private func deliver(_ transcript: String, to app: pid_t?) {
        working -= 1
        let text = DictationText.clean(transcript, customWords: preferences.words)
        guard !text.isEmpty else {
            pill.flash("Didn't catch that")
            scheduleUnload()
            return
        }
        lastTranscript = text
        switch Typer.insert(text, into: app) {
        case .typed: finish()
        case .copied(let reason): pill.flash("\(reason). Copied to the clipboard.")
        case .refused: pill.flash("Not typed in a password field")
        }
        scheduleUnload()
    }

    private func failed(_ error: Error) {
        working -= 1
        pill.flash("Couldn't transcribe that: \(error.localizedDescription)")
        scheduleUnload()
    }

    private func finish() {
        if recording == nil, working == 0 { pill.hide() }
        scheduleUnload()
    }

    private func scheduleUnload() {
        idle?.cancel()
        let later = DispatchWorkItem { [weak self] in
            guard let self, recording == nil, working == 0 else { return }
            Task { [engine = library.engine] in await engine.unload() }
        }
        idle = later
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idleUnload, execute: later)
    }
}
