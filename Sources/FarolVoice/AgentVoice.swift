import AppKit
import Combine
import VoiceCore
import VoiceEngine

/// Tells you what your agents ask, then listens for your answer without a key. Everything runs on this Mac.
/// While it's off, nothing runs and the mic stays closed.
@MainActor
final class AgentVoice {
    private static let watchSeconds = 25
    /// How long a closed Farol or a failed watch waits before trying again.
    private static let retrySeconds: UInt64 = 5
    /// A call may still be going on, so it looks again after this long.
    private static let busyRetry: TimeInterval = 3
    /// The speaker's last word shouldn't reach the mic as if it were you.
    private static let afterSpeaking: Duration = .milliseconds(250)

    private enum State {
        case quiet
        case speaking
        case listening(FarolSession, Recording, attempts: Int)
        case transcribing
    }

    private let library: ModelLibrary
    private let preferences: Preferences
    private let pill: Pill
    private let commander: Commander
    private let speaker = Speaker()
    private var state = State.quiet {
        didSet {
            let busy = if case .quiet = state { false } else { true }
            if busy != wasBusy { onBusyChange?(busy) }
            wasBusy = busy
        }
    }
    private var wasBusy = false
    /// While it's talking or listening, nothing else should be hearing the mic.
    var onBusyChange: ((Bool) -> Void)?
    private var queue = NewsQueue()
    private var sessions: [FarolSession] = []
    private var watcher: Task<Void, Never>?
    private var followUp: Task<Void, Never>?
    private var preference: AnyCancellable?
    /// You're dictating or giving a command, so it keeps quiet until you're done.
    private var yielded = false
    private var endpoint: SpeechEndpoint?
    private var toldToUpdate = false

    init(library: ModelLibrary, preferences: Preferences, pill: Pill, commander: Commander) {
        self.library = library
        self.preferences = preferences
        self.pill = pill
        self.commander = commander
        preference = preferences.$speaksAgents.sink { [weak self] on in
            Task { @MainActor in on ? self?.start() : self?.stop() }
        }
    }

    // MARK: Your keys come first

    func yield() {
        yielded = true
        speaker.stop()
        stopListening()
        if case .speaking = state { state = .quiet }
    }

    func resume() {
        yielded = false
        pump()
    }

    /// A key was pressed, so you're back at the keyboard. The question still waits on screen.
    func stopListening() {
        guard case .listening(_, let recording, _) = state else { return }
        _ = recording.finish()
        endpoint = nil
        state = .quiet
        pill.hide()
    }

    // MARK: Watching Farol

    private func start() {
        guard watcher == nil else { return }
        toldToUpdate = false
        watcher = Task { [weak self] in await self?.watch() }
    }

    private func stop() {
        watcher?.cancel()
        watcher = nil
        followUp?.cancel()
        speaker.stop()
        stopListening()
        state = .quiet
        queue = NewsQueue()
        sessions = []
    }

    private func watch() async {
        // Generations start at zero, so this first one answers at once with how things are.
        var generation = -1
        var seen = false
        while !Task.isCancelled {
            let after = generation
            let result = await Task.detached { () -> Result<FarolReply, Error> in
                guard let path = Commander.runningSocket() else { return .failure(FarolSocket.Failure.notRunning) }
                // Longer than Farol holds it, so its answer always comes first.
                return Result { try FarolSocket.send(.watch(after: after, timeout: TimeInterval(Self.watchSeconds)), to: path, waitingUpTo: Self.watchSeconds + 5) }
            }.value
            switch result {
            case .success(let reply) where reply.generation != nil:
                let now = reply.sessions ?? []
                if seen { receive(now) } else { sessions = now }
                seen = true
                generation = reply.generation ?? -1
            case .success, .failure:
                if case .failure(FarolSocket.Failure.tooOld) = result { sayUpdateFarol() }
                // Sessions may be gone when it comes back, so this starts over without announcing them.
                generation = -1
                seen = false
                try? await Task.sleep(nanoseconds: Self.retrySeconds * 1_000_000_000)
            }
        }
    }

    private func sayUpdateFarol() {
        guard !toldToUpdate else { return }
        toldToUpdate = true
        pill.flash("Update Farol to hear your agents", for: 5)
    }

    private func receive(_ now: [FarolSession]) {
        queue.add(AgentNews.changes(from: sessions, to: now))
        queue.drop(outdatedBy: now)
        sessions = now
        // Answered somewhere else, so there's nothing left to listen for.
        if case .listening(let session, _, _) = state, !isStillAsking(session) { stopListening() }
        pump()
    }

    private func isStillAsking(_ session: FarolSession) -> Bool {
        sessions.first { $0.id == session.id }.map { $0.isWaiting && $0.asking == session.asking } ?? false
    }

    // MARK: Speaking

    private func pump() {
        guard preferences.speaksAgents, !yielded, case .quiet = state, !queue.isEmpty else { return }
        // Never over a call. The mic being busy is the sign, and only something else can be holding it here.
        guard !Microphone.isInUse else {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.busyRetry) { [weak self] in MainActor.assumeIsolated { self?.pump() } }
            return
        }
        guard let news = queue.next() else { return }
        speak(news.sentence) { [weak self] in
            guard let self else { return }
            if case .question(let session) = news, session.canAnswerAloud, self.library.isReady {
                self.listen(for: session, attempts: 0)
            } else {
                self.pump()
            }
        }
    }

    private func speak(_ sentence: String, then finished: @escaping () -> Void) {
        state = .speaking
        pill.flash(sentence, for: max(3, Double(sentence.count) / 12))
        speaker.say(sentence) { [weak self] in
            self?.state = .quiet
            finished()
        }
    }

    // MARK: Listening

    private func listen(for session: FarolSession, attempts: Int) {
        guard !yielded, isStillAsking(session), Permissions.microphone == .authorized else { return pump() }
        followUp?.cancel()
        followUp = Task { [weak self] in
            try? await Task.sleep(for: Self.afterSpeaking)
            guard !Task.isCancelled else { return }
            self?.openMic(for: session, attempts: attempts)
        }
    }

    private func openMic(for session: FarolSession, attempts: Int) {
        guard !yielded, case .quiet = state else { return }
        let recording = Recording { [weak self] level in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.heard(level: level) } }
        }
        do {
            try recording.start()
        } catch {
            pill.flash(error.localizedDescription)
            return pump()
        }
        endpoint = SpeechEndpoint(startingAt: ProcessInfo.processInfo.systemUptime)
        state = .listening(session, recording, attempts: attempts)
        pill.showListening(command: true)
    }

    private func heard(level: Double) {
        guard case .listening(let session, let recording, let attempts) = state, var endpoint else { return }
        pill.level = level
        let now = endpoint.hear(level: level, at: ProcessInfo.processInfo.systemUptime)
        self.endpoint = endpoint
        switch now {
        case .listening, .speaking:
            break
        case .nothing:
            // It still waits on screen, and on your phone.
            _ = recording.finish()
            self.endpoint = nil
            state = .quiet
            pill.hide()
            pump()
        case .finished:
            self.endpoint = nil
            state = .transcribing
            pill.showWorking()
            let samples = recording.finish()
            Task { [weak self] in await self?.understand(samples, for: session, attempts: attempts) }
        }
    }

    private func understand(_ samples: [Float], for session: FarolSession, attempts: Int) async {
        let model = library.chosen
        let language = model.lockedLanguage(preferences.language)
        let text: String
        do {
            try await library.engine.load(model, online: false) { _, _ in }
            text = try await library.engine.transcribe(samples, language: language)
        } catch {
            state = .quiet
            pill.flash("Couldn't transcribe that: \(error.localizedDescription)")
            return pump()
        }
        state = .quiet
        pill.hide()
        guard !yielded else { return }
        // "Go to auth" still works here, so you can look before you answer.
        if VoiceCommand.parse(text, sessions: sessions.map(\.target)) != .notUnderstood {
            await commander.run(text)
            return pump()
        }
        guard let asking = session.asking, let choices = session.choices else { return pump() }
        switch AgentAnswer.parse(text, choices: choices) {
        case .choice(let number):
            confirm(await commander.answer(session, asking: asking, choice: number), for: session)
        case .unclear:
            guard attempts == 0, isStillAsking(session) else {
                return speak("It's still waiting on screen.") { [weak self] in self?.pump() }
            }
            speak(session.yesOrNoPrompt) { [weak self] in self?.listen(for: session, attempts: 1) }
        }
    }

    private func confirm(_ problem: String?, for session: FarolSession) {
        speak(problem ?? "Told \(session.name).") { [weak self] in self?.pump() }
    }
}

extension FarolSession {
    fileprivate var yesOrNoPrompt: String {
        guard let choices else { return "Sorry, say that again?" }
        return choices.count <= 3 ? "Sorry, say: \(choices.joined(separator: ", or "))." : "Sorry, say the option's number."
    }
}
