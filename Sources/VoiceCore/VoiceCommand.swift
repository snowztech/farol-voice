import Foundation

/// A sentence spoken to Farol itself, turned into something to do by plain rules, so it stays instant, local and predictable.
/// Holding the command key means it's a command, so these look for one anywhere in the sentence, and match names by how they sound.
public enum VoiceCommand: Equatable, Sendable {
    /// The app itself, from wherever you are. Sessions are often called farol too, so "go to" is what means a session.
    case openFarol
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

    private enum Intent {
        case go, tell
    }

    /// Includes how speech recognition tends to write them, like "got to" and "goto" for "go to".
    private static let verbs: [(words: [String], intent: Intent)] = [
        (["take", "me", "to"], .go), (["bring", "me", "to"], .go), (["switch", "over", "to"], .go), (["go", "over", "to"], .go),
        (["go", "back", "to"], .go), (["go", "to"], .go), (["got", "to"], .go), (["go", "too"], .go), (["go", "two"], .go), (["go", "into"], .go),
        (["switch", "to"], .go), (["jump", "to"], .go), (["move", "to"], .go), (["show", "me"], .go), (["open", "up"], .go), (["bring", "up"], .go),
        (["goto"], .go), (["gotta"], .go), (["open"], .go), (["show"], .go), (["launch"], .go), (["start"], .go),
        (["tell"], .tell), (["tel"], .tell), (["ask"], .tell), (["message"], .tell),
    ]
    /// Natural ways around a name: "the auth session", "session auth".
    private static let lead: Set<String> = ["the", "my", "session", "tab", "terminal", "pane", "window"]
    private static let kinds: Set<String> = ["session", "tab", "terminal", "pane", "window"]
    private static let sendEndings = [["and", "send", "it"], ["and", "send"], ["send", "it"]]
    private static let joiningWords: Set<String> = ["and", "then", "to", "that"]
    private static let taskWords: Set<String> = ["new", "start", "create", "make", "add", "a", "an", "the", "another"]
    private static let agents = ["claude", "codex", "opencode", "pi"]
    private static let longestSpokenName = 5
    /// Sound-alikes the sound rule can't catch, for the one name everyone says.
    private static let farolMisheard: Set<String> = ["pharaoh", "pharoah", "farrow", "parole", "fairall"]

    public static func parse(_ transcript: String, sessions: [Target]) -> VoiceCommand {
        var words = transcript.split(whereSeparator: \.isWhitespace).map(String.init)
        if let last = words.last, normalized(last) == "please", words.count > 1 { words.removeLast() }
        let plain = words.map(normalized)
        if isFarol(plain.filter { !$0.isEmpty }) { return .openFarol }
        if let task = newTask(words, plain) { return task }
        guard let (start, verb) = firstVerb(in: plain) else { return .notUnderstood }
        let rest = Array(words[(start + verb.words.count)...])
        let afterVerb = rest.map(normalized).filter { $0 != "the" && $0 != "app" }
        if verb.intent == .go, isFarol(afterVerb), plain[start] != "go", plain[start] != "got", plain[start] != "goto" { return .openFarol }
        switch verb.intent {
        case .go:
            return session(rest, sessions: sessions, focus: true)
        case .tell:
            let command = session(rest, sessions: sessions, focus: false)
            if case .session(_, nil, _, _) = command { return .notUnderstood }
            return command
        }
    }

    private static func isFarol(_ words: [String]) -> Bool {
        guard (1...2).contains(words.count) else { return false }
        let name = words.joined()
        return farolMisheard.contains(name) || sound(of: name) == sound(of: "farol")
    }

    /// The earliest command in the sentence, and at that spot the longest, so "can you try to go to dev" finds "go to".
    private static func firstVerb(in plain: [String]) -> (Int, (words: [String], intent: Intent))? {
        for start in plain.indices {
            let found = verbs.filter { plain[start...].starts(with: $0.words) }.max { $0.words.count < $1.words.count }
            if let found { return (start, found) }
        }
        return nil
    }

    private static func newTask(_ words: [String], _ plain: [String]) -> VoiceCommand? {
        guard let task = plain.firstIndex(where: { $0 == "task" || $0 == "tasks" }), task > 0 else { return nil }
        let before = plain[..<task].suffix(4)
        guard before.contains(where: { ["new", "start", "create", "make", "add"].contains($0) }) else { return nil }
        let named = before.drop { !["new", "start", "create", "make", "add"].contains($0) }.filter { !taskWords.contains($0) }
        var rest = Array(words[(task + 1)...])
        while let first = rest.first, joiningWords.contains(normalized(first)) { rest.removeFirst() }
        let text = rest.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " ,:"))
        guard !text.isEmpty else { return .notUnderstood }
        return .newTask(agent: named.isEmpty ? nil : agent(named.joined()), text: text)
    }

    /// "Clod" and "code x" still mean the agents they sound like.
    private static func agent(_ spoken: String) -> String {
        agents.first { sound(of: $0) == sound(of: spoken) } ?? spoken
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
            let onlyGoing = focus && after.allSatisfy { normalized($0).isEmpty }
            return onlyGoing
                ? .choices(ids: best.targets.map(\.id))
                : .ambiguous(spoken: words[..<best.length].joined(separator: " "), names: best.targets.map(\.name))
        }
        return finish(after, target: best.targets[0], focus: focus)
    }

    private static func bestMatch(_ words: [String], _ sessions: [Target], names: (Target) -> [String]) -> (length: Int, targets: [Target])? {
        var best: (distance: Int, length: Int, targets: [Target])?
        for length in 1...min(longestSpokenName, words.count) {
            var spoken = words[..<length].map(normalized).joined()
            if farolMisheard.contains(spoken) { spoken = "farol" }
            guard spoken.count >= 2 else { continue }
            for target in sessions {
                guard let distance = names(target).compactMap({ closeness(spoken, to: $0) }).min() else { continue }
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
        let hasWords = text.contains { $0.isLetter || $0.isNumber }
        return .session(id: target.id, text: hasWords ? text : nil, send: send && hasWords, focus: focus)
    }

    /// How far what was said is from a name, or from any one word of it, since people say "auth" for "fix/auth-login". Nil if it's neither close in spelling nor in sound.
    private static func closeness(_ spoken: String, to name: String) -> Int? {
        let parts = name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let forms = [parts.joined()] + parts.filter { $0.count >= 3 }
        let allowed = spoken.count / 4
        // The first letter has to match, so "carol" isn't taken for "farol".
        if let spelled = forms.filter({ $0.first == spoken.first }).map({ editDistance(spoken, $0) }).min(), spelled <= allowed { return spelled }
        // Just behind any match in spelling. Two letters are too few to say two words sound the same.
        let heard = sound(of: spoken)
        return heard.count >= 3 && forms.contains { sound(of: $0) == heard } ? allowed + 1 : nil
    }

    /// A word by its consonants, the part speech recognition gets right: "for all", "farrell" and "feral" all sound like "farol".
    static func sound(of word: String) -> String {
        var letters = word.lowercased().replacingOccurrences(of: "ph", with: "f").replacingOccurrences(of: "ck", with: "k")
        letters = String(letters.map { character -> Character in
            switch character {
            case "c", "q": "k"
            case "z": "s"
            default: character
            }
        })
        var result = ""
        for letter in letters where letter.isLetter && !"aeiouyhw".contains(letter) && result.last != letter {
            result.append(letter)
        }
        return result
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
