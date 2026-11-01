import Foundation

/// A sentence spoken to Farol itself, turned into something to do by plain rules, so it stays instant, local and predictable.
public enum VoiceCommand: Equatable, Sendable {
    /// `text` is nil to only go there. `focus` is false when you stay where you are.
    case session(id: String, text: String?, send: Bool, focus: Bool)
    case newTask(agent: String?, text: String)
    /// Going somewhere can't do harm, so several matches are stepped through by saying it again.
    case choices(ids: [String])
    /// Never guessed, since a message in the wrong session is the worst thing this can do.
    case ambiguous(spoken: String, names: [String])
    case noSession(String)
    case notUnderstood

    public struct Target: Equatable, Sendable {
        public let id: String
        public let name: String
        /// Other things a session is known by, like its branch and agent, for when names repeat.
        public let aliases: [String]

        public init(id: String, name: String, aliases: [String] = []) {
            self.id = id
            self.name = name
            self.aliases = aliases
        }
    }

    private static let goVerbs = [["take", "me", "to"], ["go", "to"], ["switch", "to"], ["jump", "to"], ["move", "to"], ["show", "me"], ["open"], ["show"]]
    /// Natural ways around a name: "the auth session", "session auth".
    private static let lead: Set<String> = ["the", "my", "session", "tab", "terminal", "pane"]
    private static let kinds: Set<String> = ["session", "tab", "terminal", "pane"]
    private static let tellVerbs = [["tell"], ["ask"]]
    private static let sendEndings = [["and", "send", "it"], ["and", "send"], ["send", "it"]]
    private static let joiningWords: Set<String> = ["and", "then", "to", "that"]
    private static let longestSpokenName = 5

    public static func parse(_ transcript: String, sessions: [Target]) -> VoiceCommand {
        let words = transcript.split(whereSeparator: \.isWhitespace).map(String.init)
        let plain = words.map(normalized)
        if plain.first == "new", let task = plain.firstIndex(of: "task"), task <= 3 {
            return newTask(words, plain, taskAt: task)
        }
        for verb in goVerbs where plain.starts(with: verb) {
            return session(Array(words.dropFirst(verb.count)), sessions: sessions, focus: true)
        }
        for verb in tellVerbs where plain.starts(with: verb) {
            let command = session(Array(words.dropFirst(verb.count)), sessions: sessions, focus: false)
            if case .session(_, nil, _, _) = command { return .notUnderstood }
            return command
        }
        return .notUnderstood
    }

    private static func newTask(_ words: [String], _ plain: [String], taskAt task: Int) -> VoiceCommand {
        let agent = plain[1..<task].joined(separator: " ")
        var rest = Array(words[(task + 1)...])
        while let first = rest.first, joiningWords.contains(normalized(first)) { rest.removeFirst() }
        let text = rest.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? .notUnderstood : .newTask(agent: agent.isEmpty ? nil : agent, text: text)
    }

    private static func session(_ spokenWords: [String], sessions: [Target], focus: Bool) -> VoiceCommand {
        var words = spokenWords
        while let first = words.first, lead.contains(normalized(first)) { words.removeFirst() }
        guard !words.isEmpty else { return .notUnderstood }
        // A name wins over a branch or agent that happens to sound the same.
        let found = bestMatch(words, sessions) { [$0.name] } ?? bestMatch(words, sessions) { $0.aliases }
        guard let best = found else { return .noSession(words.prefix(3).joined(separator: " ")) }
        var after = Array(words[best.length...])
        if let first = after.first, kinds.contains(normalized(first)) { after.removeFirst() }
        if best.targets.count > 1 {
            let onlyGoing = focus && after.isEmpty
            return onlyGoing
                ? .choices(ids: best.targets.map(\.id))
                : .ambiguous(spoken: words[..<best.length].joined(separator: " "), names: best.targets.map(\.name))
        }
        return finish(after, target: best.targets[0], focus: focus)
    }

    private static func bestMatch(_ words: [String], _ sessions: [Target], names: (Target) -> [String]) -> (length: Int, targets: [Target])? {
        var best: (distance: Int, length: Int, targets: [Target])?
        for length in 1...min(longestSpokenName, words.count) {
            let spoken = words[..<length].map(normalized).joined()
            let allowed = spoken.count / 4
            guard spoken.count >= 2 else { continue }
            for target in sessions {
                let distance = names(target).map { closeness(spoken, to: $0) }.min() ?? .max
                guard distance <= allowed else { continue }
                if let current = best, (current.distance, -current.length) < (distance, -length) { continue }
                if let current = best, current.distance == distance, current.length == length {
                    best?.targets.append(target)
                } else {
                    best = (distance, length, [target])
                }
            }
        }
        return best.map { ($0.length, $0.targets) }
    }

    private static func finish(_ after: [String], target: Target, focus: Bool) -> VoiceCommand {
        var rest = after
        while let first = rest.first, joiningWords.contains(normalized(first)) { rest.removeFirst() }
        var send = false
        for ending in sendEndings where rest.map(normalized).suffix(ending.count) == ending[...] {
            rest.removeLast(ending.count)
            send = true
            break
        }
        let text = rest.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
        return .session(id: target.id, text: text.isEmpty ? nil : text, send: send && !text.isEmpty, focus: focus)
    }

    /// How far what was said is from a name, or from any one word of it, since people say "auth" for "fix/auth-login".
    private static func closeness(_ spoken: String, to name: String) -> Int {
        let parts = name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let forms = [parts.joined()] + parts.filter { $0.count >= 3 }
        return forms.map { editDistance(spoken, $0) }.min() ?? .max
    }

    private static func normalized(_ word: String) -> String {
        word.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var row = Array(0...b.count)
        for i in 0..<a.count {
            var previous = row[0]
            row[0] = i + 1
            for j in 0..<b.count {
                let replaced = previous + (a[i] == b[j] ? 0 : 1)
                previous = row[j + 1]
                row[j + 1] = min(replaced, row[j] + 1, row[j + 1] + 1)
            }
        }
        return row[b.count]
    }
}
