import AppKit
import AVFoundation
import Combine
import VoiceCore
import VoiceEngine

/// Hold one key, talk, let go, and the words appear wherever you were typing. Hold the other, and you're telling Farol what to do.
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
    private let pill: Pill
    private let commander: Commander
    private let agentVoice: AgentVoice
    private let wake: WakeListener
    private var preferenceWatch: AnyCancellable?
    private var wakePausedByKey = false
    private var monitors: [Any] = []
    private var heldKey: TalkKey?
    private var heldIsCommand = false
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
        pill = Pill(preferences: preferences)
        let (commander, agentVoice, wake) = MainActor.assumeIsolated { [pill] in
            let commander = Commander(pill: pill)
            let wake = WakeListener(library: library, pill: pill, commander: commander)
            let voice = AgentVoice(library: library, preferences: preferences, pill: pill, commander: commander)
            voice.onBusyChange = { busy in if busy { wake.pause() } else { wake.resume() } }
            return (commander, voice, wake)
        }
        self.commander = commander
        self.agentVoice = agentVoice
        self.wake = wake
        if Commander.isDevBuild {
            preferenceWatch = preferences.$listensForWake.sink { on in
                DispatchQueue.main.async { MainActor.assumeIsolated { wake.setEnabled(on) } }
            }
        }
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
            // A key while one is held is a shortcut or a typed character, not someone talking.
            if heldKey != nil { cancel() }
            Task { @MainActor [commander, agentVoice] in
                commander.stopPendingSend()
                agentVoice.stopListening()
            }
            return
        }
        let keys = [preferences.talkKey, preferences.commandKey]
        guard let key = keys.first(where: { $0.keyCode == event.keyCode }) else { return }
        let down = key.isDown(in: event)
        if down, heldKey == nil {
            heldKey = key
            heldIsCommand = key == preferences.commandKey
            let start = DispatchWorkItem { [weak self] in self?.start() }
            pendingStart = start
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdDelay, execute: start)
        } else if !down, heldKey == key {
            heldKey = nil
            stop()
        }
    }

    private func start() {
        pendingStart = nil
        // Your own key always wins: it stops whatever Farol is saying or waiting to hear.
        MainActor.assumeIsolated {
            commander.stopPendingSend()
            agentVoice.yield()
        }
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
        MainActor.assumeIsolated {
            if !wakePausedByKey {
                wakePausedByKey = true
                wake.pause()
            }
        }
        let pill = pill
        let recording = Recording { level in DispatchQueue.main.async { pill.level = level } }
        do {
            try recording.start()
        } catch {
            pill.flash(error.localizedDescription)
            resumeAgentVoice()
            return
        }
        self.recording = recording
        targetApp = NSWorkspace.shared.frontmostApplication?.processIdentifier
        idle?.cancel()
        let later = DispatchWorkItem { [weak self] in
            self?.heldKey = nil
            self?.stop()
        }
        limit = later
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.longestHold, execute: later)
        pill.showListening(command: heldIsCommand)
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
        let isCommand = heldIsCommand
        let language = model.lockedLanguage(preferences.language)
        Task { [engine = library.engine, weak self] in
            do {
                // Usually loaded already, unless it was unloaded after a long break.
                try await engine.load(model, online: false) { _, _ in }
                let text = try await engine.transcribe(samples, language: language)
                await MainActor.run { self?.deliver(text, to: app, isCommand: isCommand) }
            } catch {
                await MainActor.run { self?.failed(error) }
            }
        }
    }

    /// Drops what was said so far. Nothing is typed.
    private func cancel() {
        heldKey = nil
        pendingStart?.cancel()
        pendingStart = nil
        limit?.cancel()
        guard let recording else { return }
        self.recording = nil
        _ = recording.finish()
        onListeningChange?(false)
        finish()
    }

    private func deliver(_ transcript: String, to app: pid_t?, isCommand: Bool) {
        working -= 1
        resumeAgentVoice()
        if isCommand {
            lastTranscript = transcript
            scheduleUnload()
            Task { @MainActor [commander] in await commander.run(transcript) }
            return
        }
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
        resumeAgentVoice()
        pill.flash("Couldn't transcribe that: \(error.localizedDescription)")
        scheduleUnload()
    }

    private func finish() {
        if recording == nil, working == 0 { pill.hide() }
        resumeAgentVoice()
        scheduleUnload()
    }

    private func resumeAgentVoice() {
        guard recording == nil, working == 0 else { return }
        Task { @MainActor [agentVoice, wake] in
            agentVoice.resume()
            if wakePausedByKey {
                wakePausedByKey = false
                wake.resume()
            }
        }
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
