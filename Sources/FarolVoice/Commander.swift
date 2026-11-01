import AppKit
import VoiceCore
import VoiceEngine

/// Carries out what you tell Farol. Finds it, opening it if needed, and never guesses when a message could land in the wrong session.
@MainActor
final class Commander {
    /// How long a spoken "send it" can still be stopped by pressing a key. Nothing reaches the session before this.
    private static let sendDelay: TimeInterval = 2.5
    private static let launchLimit: TimeInterval = 10

    /// A dev build talks to Farol Dev first, so testing never touches the sessions in your installed Farol.
    private static var isDevBuild: Bool { Bundle.main.bundleIdentifier?.hasSuffix(".debug") == true }
    private static var appIDs: [String] { isDevBuild ? ["dev.farol.Farol.debug", "dev.farol.Farol"] : ["dev.farol.Farol"] }

    private let pill: Pill
    private var pendingSend: Task<Void, Never>?
    private var pendingText: String?
    private var lastStepped: String?
    /// Where a new task goes, since Farol doesn't say which session is in front: the last one you went to.
    private var lastFolder: String?

    init(pill: Pill) {
        self.pill = pill
    }

    func run(_ transcript: String) async {
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty else { return pill.flash("Didn't catch that") }
        // Nothing else to resolve here, and it should also work when Farol is closed or has no sessions.
        if VoiceCommand.parse(spoken, sessions: []) == .openFarol { return await bringFarolForward() }
        guard let path = await farolSocket() else { return }
        switch await request(.sessions, path: path) {
        case .failure(let message):
            keep(spoken, because: message)
        case .success(let reply):
            let sessions = reply.sessions ?? []
            await carryOut(VoiceCommand.parse(spoken, sessions: sessions.map(\.target)), spoken: spoken, sessions: sessions, path: path)
        }
    }

    /// A key pressed during the wait stops the send. Returns whether there was one to stop.
    func stopPendingSend() {
        guard let pendingSend else { return }
        pendingSend.cancel()
        self.pendingSend = nil
        if let pendingText { keep(pendingText, because: "Not sent") }
        pendingText = nil
    }

    private func carryOut(_ command: VoiceCommand, spoken: String, sessions: [FarolSession], path: String) async {
        switch command {
        case .openFarol:
            await bringFarolForward()
        case .session(let id, let text, let send, let focus):
            guard let session = sessions.first(where: { $0.id == id }) else { return }
            await go(to: session, text: text, send: send, focus: focus, path: path)
        case .choices(let ids):
            let next = ids.firstIndex(of: lastStepped ?? "").map { ($0 + 1) % ids.count } ?? 0
            guard let session = sessions.first(where: { $0.id == ids[next] }) else { return }
            lastStepped = session.id
            if await focus(session, path: path) {
                pill.flash("\(session.name), \(next + 1) of \(ids.count). Say it again for the next.")
            }
        case .newTask(let agent, let text):
            await startTask(text, agent: agent, sessions: sessions, path: path)
        case .ambiguous(let name, let names):
            let different = Array(Set(names))
            keep(spoken, because: different.count == 1
                ? "\(names.count) sessions match \"\(name)\". Say its branch"
                : "\"\(name)\" could be \(different.prefix(3).joined(separator: " or "))")
        case .noSession(let name):
            keep(spoken, because: "No session called \"\(name)\"")
        case .notUnderstood:
            // What it heard, so a mishearing can be told from a phrase it doesn't know.
            Typer.copy(spoken)
            pill.flash("Heard \"\(Self.shortened(spoken))\". Try \"go to\", \"tell\" or \"new task\".", for: 5)
        }
    }

    private func go(to session: FarolSession, text: String?, send: Bool, focus shouldFocus: Bool, path: String) async {
        // Typing into a question nobody read could answer a menu. So you get taken to it, and your words wait on the clipboard.
        if session.isWaiting, let text {
            _ = await focus(session, path: path)
            return keep(text, because: "\(session.name) is asking you something")
        }
        if shouldFocus, !(await focus(session, path: path)) { return }
        guard let text else { return pill.flash("Now in \(session.name)", for: 1.5) }
        let line = DictationText.clean(text)
        guard !line.isEmpty else { return pill.flash("Didn't catch that") }
        guard send else {
            if await type(line, into: session, submit: false, path: path) { pill.flash("Typed in \(session.name). Not sent.") }
            return
        }
        pill.flash("Sending to \(session.name). Press any key to stop.", for: Self.sendDelay)
        let sentence = line.trimmingCharacters(in: .whitespaces)
        pendingText = sentence
        pendingSend = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.sendDelay))
            guard !Task.isCancelled, let self else { return }
            self.pendingSend = nil
            self.pendingText = nil
            if await self.type(sentence, into: session, submit: true, path: path) { self.pill.flash("Sent to \(session.name)", for: 1.5) }
        }
    }

    private func focus(_ session: FarolSession, path: String) async -> Bool {
        switch await request(.focus(session: session.id), path: path) {
        case .failure(let message):
            pill.flash(message)
            return false
        case .success:
            lastFolder = session.folder
            return true
        }
    }

    private func type(_ text: String, into session: FarolSession, submit: Bool, path: String) async -> Bool {
        switch await request(.type(session: session.id, text: text, submit: submit, asking: nil), path: path) {
        case .failure(let message):
            keep(text, because: message)
            return false
        case .success:
            return true
        }
    }

    private func startTask(_ text: String, agent: String?, sessions: [FarolSession], path: String) async {
        let folders = Set(sessions.map(\.folder))
        guard let folder = lastFolder ?? (folders.count == 1 ? folders.first : nil) else {
            return keep(text, because: "Go to a session in that project first")
        }
        switch await request(.task(text: text, repo: folder, agent: agent), path: path) {
        case .failure(let message): keep(text, because: message)
        case .success: pill.flash("Started the task")
        }
    }

    private static func shortened(_ text: String) -> String {
        text.count > 48 ? String(text.prefix(48)) + "…" : text
    }

    private func bringFarolForward() async {
        let running = Self.appIDs.first { FarolSocket.isRunning(at: Self.socketPath(of: $0)) }
        let installed = Self.appIDs.first { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
        guard let id = running ?? installed, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return pill.flash("Farol isn't installed. Get it at farol.sh.")
        }
        pill.flash("Opening Farol", for: 1.5)
        _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Reaching Farol

    private enum Answer {
        case success(FarolReply)
        case failure(String)
    }

    private func request(_ action: FarolAction, path: String) async -> Answer {
        let result = await Task.detached { () -> Result<FarolReply, Error> in
            Result { try FarolSocket.send(action, to: path) }
        }.value
        switch result {
        case .success(let reply):
            if let error = reply.error { return .failure(error) }
            return .success(reply)
        case .failure(FarolSocket.Failure.tooOld):
            return .failure("Update Farol to use this")
        case .failure:
            return .failure("Couldn't reach Farol")
        }
    }

    /// The socket of a running Farol, opening it first when it's closed.
    private func farolSocket() async -> String? {
        for id in Self.appIDs where FarolSocket.isRunning(at: Self.socketPath(of: id)) {
            return Self.socketPath(of: id)
        }
        guard let id = Self.appIDs.first(where: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }),
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            pill.flash("Farol isn't installed. Get it at farol.sh.")
            return nil
        }
        pill.flash("Opening Farol", for: Self.launchLimit)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        let path = Self.socketPath(of: id)
        let deadline = Date().addingTimeInterval(Self.launchLimit)
        while Date() < deadline {
            if FarolSocket.isRunning(at: path) { return path }
            try? await Task.sleep(for: .milliseconds(200))
        }
        pill.flash("Farol didn't open in time")
        return nil
    }

    private static func socketPath(of id: String) -> String {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Farol/\(id).sock").path
    }

    /// The words are still yours when they can't go where they were meant to.
    private func keep(_ text: String, because reason: String) {
        Typer.copy(text)
        pill.flash("\(reason). Copied to the clipboard.")
    }
}
